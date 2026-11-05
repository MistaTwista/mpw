import CryptoKit
import Foundation

extension MasterKey {
    /// Phase 2: the site key.
    ///
    ///     siteKey = HMAC-SHA-256( <master key>, scope . LEN(<site name>) . <site name> . <counter> )
    public func siteKey(siteName: String, counter: UInt32) -> [UInt8] {
        let seed = scoped(siteName) + bigEndian(counter)
        return withBytes { key in
            Array(HMAC<SHA256>.authenticationCode(for: seed, using: SymmetricKey(data: key)))
        }
    }

    /// Phases 2 and 3: the password for a site.
    public func password(siteName: String, counter: UInt32, type: ResultType) -> String {
        sitePassword(siteKey: siteKey(siteName: siteName, counter: counter), type: type)
    }
}

/// Phase 3: render the site key with a template of the given type.
///
///     template = templates[ <site key>[0] % LEN( templates ) ]
///     passWord[i] = templateChars[ template[i] ][ <site key>[i+1] % LEN( passChars ) ]
public func sitePassword(siteKey: [UInt8], type: ResultType) -> String {
    let templates = type.templates
    let template = templates[Int(siteKey[0]) % templates.count]
    var out = [UInt8]()
    out.reserveCapacity(template.count)
    for (i, cls) in template.enumerated() {
        let chars = templateCharacters[cls]!
        out.append(chars[Int(siteKey[i + 1]) % chars.count])
    }
    return String(decoding: out, as: UTF8.self)
}
