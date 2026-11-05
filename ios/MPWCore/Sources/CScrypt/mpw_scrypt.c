// scrypt as specified in RFC 7914. Salsa20/8 core is the reference code from
// RFC 7914 section 3; PBKDF2-HMAC-SHA256 comes from CommonCrypto.

#include "mpw_scrypt.h"

#include <CommonCrypto/CommonCryptoError.h>
#include <CommonCrypto/CommonKeyDerivation.h>
#include <stdlib.h>
#include <string.h>

#define R(a, b) (((a) << (b)) | ((a) >> (32 - (b))))

static void salsa20_8(uint32_t B[16]) {
    uint32_t x[16];
    memcpy(x, B, sizeof(x));
    for (int i = 8; i > 0; i -= 2) {
        x[ 4] ^= R(x[ 0]+x[12], 7);  x[ 8] ^= R(x[ 4]+x[ 0], 9);
        x[12] ^= R(x[ 8]+x[ 4],13);  x[ 0] ^= R(x[12]+x[ 8],18);
        x[ 9] ^= R(x[ 5]+x[ 1], 7);  x[13] ^= R(x[ 9]+x[ 5], 9);
        x[ 1] ^= R(x[13]+x[ 9],13);  x[ 5] ^= R(x[ 1]+x[13],18);
        x[14] ^= R(x[10]+x[ 6], 7);  x[ 2] ^= R(x[14]+x[10], 9);
        x[ 6] ^= R(x[ 2]+x[14],13);  x[10] ^= R(x[ 6]+x[ 2],18);
        x[ 3] ^= R(x[15]+x[11], 7);  x[ 7] ^= R(x[ 3]+x[15], 9);
        x[11] ^= R(x[ 7]+x[ 3],13);  x[15] ^= R(x[11]+x[ 7],18);
        x[ 1] ^= R(x[ 0]+x[ 3], 7);  x[ 2] ^= R(x[ 1]+x[ 0], 9);
        x[ 3] ^= R(x[ 2]+x[ 1],13);  x[ 0] ^= R(x[ 3]+x[ 2],18);
        x[ 6] ^= R(x[ 5]+x[ 4], 7);  x[ 7] ^= R(x[ 6]+x[ 5], 9);
        x[ 4] ^= R(x[ 7]+x[ 6],13);  x[ 5] ^= R(x[ 4]+x[ 7],18);
        x[11] ^= R(x[10]+x[ 9], 7);  x[ 8] ^= R(x[11]+x[10], 9);
        x[ 9] ^= R(x[ 8]+x[11],13);  x[10] ^= R(x[ 9]+x[ 8],18);
        x[12] ^= R(x[15]+x[14], 7);  x[13] ^= R(x[12]+x[15], 9);
        x[14] ^= R(x[13]+x[12],13);  x[15] ^= R(x[14]+x[13],18);
    }
    for (int i = 0; i < 16; i++) B[i] += x[i];
}

static uint32_t le32dec(const uint8_t *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static void le32enc(uint8_t *p, uint32_t x) {
    p[0] = (uint8_t)x; p[1] = (uint8_t)(x >> 8); p[2] = (uint8_t)(x >> 16); p[3] = (uint8_t)(x >> 24);
}

// scryptBlockMix: B and Y are 32*r words each. Output replaces B.
static void block_mix(uint32_t *B, uint32_t *Y, uint32_t r) {
    uint32_t X[16];
    memcpy(X, &B[(2 * r - 1) * 16], sizeof(X));
    for (uint32_t i = 0; i < 2 * r; i++) {
        for (int k = 0; k < 16; k++) X[k] ^= B[i * 16 + k];
        salsa20_8(X);
        // Even blocks go to the first half, odd blocks to the second half.
        uint32_t dst = (i / 2 + (i & 1) * r) * 16;
        memcpy(&Y[dst], X, sizeof(X));
    }
    memcpy(B, Y, 32 * r * sizeof(uint32_t));
}

// scryptROMix on one 128*r byte block.
static void ro_mix(uint8_t *block, uint64_t n, uint32_t r, uint32_t *X, uint32_t *Y, uint32_t *V) {
    size_t words = 32 * (size_t)r;
    for (size_t k = 0; k < words; k++) X[k] = le32dec(&block[4 * k]);
    for (uint64_t i = 0; i < n; i++) {
        memcpy(&V[i * words], X, words * sizeof(uint32_t));
        block_mix(X, Y, r);
    }
    for (uint64_t i = 0; i < n; i++) {
        uint64_t j = X[(2 * r - 1) * 16] & (n - 1); // Integerify mod n
        for (size_t k = 0; k < words; k++) X[k] ^= V[j * words + k];
        block_mix(X, Y, r);
    }
    for (size_t k = 0; k < words; k++) le32enc(&block[4 * k], X[k]);
}

int mpw_scrypt(const uint8_t *password, size_t password_len,
               const uint8_t *salt, size_t salt_len,
               uint64_t n, uint32_t r, uint32_t p,
               uint8_t *dk, size_t dklen) {
    if (n < 2 || (n & (n - 1)) != 0 || r == 0 || p == 0) return -1;
    if ((uint64_t)r * p >= (1u << 30)) return -1;
    if (n > SIZE_MAX / 128 / r) return -1;

    size_t block_len = 128 * (size_t)r;
    uint8_t *B = malloc(block_len * p);
    uint32_t *XY = malloc(2 * block_len);
    uint32_t *V = malloc(block_len * (size_t)n);
    int rc = -1;
    if (B == NULL || XY == NULL || V == NULL) goto out;

    if (CCKeyDerivationPBKDF(kCCPBKDF2, (const char *)password, password_len, salt, salt_len,
                             kCCPRFHmacAlgSHA256, 1, B, block_len * p) != kCCSuccess) goto out;
    for (uint32_t i = 0; i < p; i++) {
        ro_mix(&B[i * block_len], n, r, XY, XY + 32 * r, V);
    }
    if (CCKeyDerivationPBKDF(kCCPBKDF2, (const char *)password, password_len, B, block_len * p,
                             kCCPRFHmacAlgSHA256, 1, dk, dklen) != kCCSuccess) goto out;
    rc = 0;

out:
    if (B) { memset_s(B, block_len * p, 0, block_len * p); free(B); }
    if (XY) { memset_s(XY, 2 * block_len, 0, 2 * block_len); free(XY); }
    if (V) { memset_s(V, block_len * (size_t)n, 0, block_len * (size_t)n); free(V); }
    return rc;
}
