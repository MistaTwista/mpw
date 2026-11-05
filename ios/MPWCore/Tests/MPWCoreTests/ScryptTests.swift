import CScrypt
import Foundation
import Testing

private func scrypt(_ password: String, _ salt: String, n: UInt64, r: UInt32, p: UInt32, length: Int) -> String? {
    var out = [UInt8](repeating: 0, count: length)
    let pw = Array(password.utf8), s = Array(salt.utf8)
    let rc = mpw_scrypt(pw, pw.count, s, s.count, n, r, p, &out, out.count)
    guard rc == 0 else { return nil }
    return out.map { String(format: "%02x", $0) }.joined()
}

/// Test vectors from RFC 7914 section 12 (the N = 1048576 vector is too slow for unit tests).
@Test func rfc7914Vectors() {
    #expect(scrypt("", "", n: 16, r: 1, p: 1, length: 64) ==
        "77d6576238657b203b19ca42c18a0497f16b4844e3074ae8dfdffa3fede21442fcd0069ded0948f8326a753a0fc81f17e8d3e0fb2e0d3628cf35e20c38d18906")
    #expect(scrypt("password", "NaCl", n: 1024, r: 8, p: 16, length: 64) ==
        "fdbabe1c9d3472007856e7190d01e9fe7c6ad7cbc8237830e77376634b3731622eaf30d92e22a3886ff109279d9830dac727afb94a83ee6d8360cbdfa2cc0640")
    #expect(scrypt("pleaseletmein", "SodiumChloride", n: 16384, r: 8, p: 1, length: 64) ==
        "7023bdcb3afd7348461c06cd81fd38ebfda8fbba904f8e3ea9b543f6545da1f2d5432955613f0fcf62d49705242a9af9e61e85dc0d651e40dfcf017b45575887")
}

@Test func rejectsInvalidParameters() {
    #expect(scrypt("a", "b", n: 15, r: 1, p: 1, length: 16) == nil)
    #expect(scrypt("a", "b", n: 16, r: 0, p: 1, length: 16) == nil)
    #expect(scrypt("a", "b", n: 16, r: 1, p: 0, length: 16) == nil)
}
