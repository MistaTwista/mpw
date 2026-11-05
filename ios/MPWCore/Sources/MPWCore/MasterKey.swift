import CScrypt
import Foundation

public enum MPWError: Error, Equatable {
    /// scrypt failed: invalid parameters or out of memory.
    case keyDerivationFailed
}

/// The 64-byte master key derived from the full name and master password.
///
/// Phase 1 of the algorithm:
///
///     masterKey = SCRYPT( <master password>, scope . LEN(<name>) . <name>, N = 32768, r = 8, p = 2, 64 )
///
/// Held only in memory. The buffer is zeroed when the key is released; Swift may have made
/// copies, so this is hygiene, not a guarantee.
public final class MasterKey: @unchecked Sendable {
    // Immutable after init, so sharing across threads is safe.
    private let storage: UnsafeMutableBufferPointer<UInt8>

    /// Runs scrypt, which takes a noticeable fraction of a second: call it off the main actor.
    public init(fullName: String, masterPassword: String) throws {
        let salt = scoped(fullName)
        let password = Array(masterPassword.utf8)
        let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: 64)
        let rc = mpw_scrypt(password, password.count, salt, salt.count, 32768, 8, 2, buffer.baseAddress, buffer.count)
        guard rc == 0 else {
            buffer.deallocate()
            throw MPWError.keyDerivationFailed
        }
        storage = buffer
    }

    deinit {
        _ = memset_s(storage.baseAddress, storage.count, 0, storage.count)
        storage.deallocate()
    }

    func withBytes<R>(_ body: (UnsafeBufferPointer<UInt8>) throws -> R) rethrows -> R {
        try body(UnsafeBufferPointer(storage))
    }
}

let scope = "com.lyndir.masterpassword"

/// `scope . UInt32BE(LEN(s)) . s`, where LEN counts UTF-8 bytes.
func scoped(_ s: String) -> [UInt8] {
    let bytes = Array(s.utf8)
    return Array(scope.utf8) + bigEndian(UInt32(bytes.count)) + bytes
}

func bigEndian(_ value: UInt32) -> [UInt8] {
    withUnsafeBytes(of: value.bigEndian) { Array($0) }
}
