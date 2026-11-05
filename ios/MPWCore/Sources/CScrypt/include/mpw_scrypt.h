#ifndef MPW_SCRYPT_H
#define MPW_SCRYPT_H

#include <stddef.h>
#include <stdint.h>

/// scrypt (RFC 7914). Writes `dklen` bytes to `dk`.
/// `n` must be a power of two greater than 1.
/// Returns 0 on success, -1 on invalid parameters or allocation failure.
int mpw_scrypt(const uint8_t *password, size_t password_len,
               const uint8_t *salt, size_t salt_len,
               uint64_t n, uint32_t r, uint32_t p,
               uint8_t *dk, size_t dklen);

#endif
