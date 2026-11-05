/// A family of password templates. Raw values and abbreviations match the Go CLI.
public enum ResultType: String, CaseIterable, Sendable, Codable {
    case maximum = "Maximum"
    case long = "Long"
    case medium = "Medium"
    case basic = "Basic"
    case short = "Short"
    case pin = "PIN"
    case name = "Name"
    case phrase = "Phrase"

    /// One-letter abbreviation used by `mpw -t`.
    public var abbreviation: String {
        switch self {
        case .maximum: "x"
        case .long: "l"
        case .medium: "m"
        case .basic: "b"
        case .short: "s"
        case .pin: "i"
        case .name: "n"
        case .phrase: "p"
        }
    }

    /// Human readable description, as in the CLI help.
    public var summary: String {
        switch self {
        case .maximum: "20 characters, contains symbols"
        case .long: "Copy-friendly, 14 characters, symbols"
        case .medium: "Copy-friendly, 8 characters, symbols"
        case .basic: "8 characters, no symbols"
        case .short: "Copy-friendly, 4 characters, no symbols"
        case .pin: "4 numbers"
        case .name: "9 letter name"
        case .phrase: "20 character sentence"
        }
    }

    /// Accepts a full name or a one-letter abbreviation, case-insensitively.
    public init?(parsing text: String) {
        let lower = text.lowercased()
        guard let match = Self.allCases.first(where: {
            $0.abbreviation == lower || $0.rawValue.lowercased() == lower
        }) else { return nil }
        self = match
    }

    var templates: [String] {
        switch self {
        case .maximum: ["anoxxxxxxxxxxxxxxxxx", "axxxxxxxxxxxxxxxxxno"]
        case .long: [
            "CvcvnoCvcvCvcv", "CvcvCvcvnoCvcv", "CvcvCvcvCvcvno",
            "CvccnoCvcvCvcv", "CvccCvcvnoCvcv", "CvccCvcvCvcvno",
            "CvcvnoCvccCvcv", "CvcvCvccnoCvcv", "CvcvCvccCvcvno",
            "CvcvnoCvcvCvcc", "CvcvCvcvnoCvcc", "CvcvCvcvCvccno",
            "CvccnoCvccCvcv", "CvccCvccnoCvcv", "CvccCvccCvcvno",
            "CvcvnoCvccCvcc", "CvcvCvccnoCvcc", "CvcvCvccCvccno",
            "CvccnoCvcvCvcc", "CvccCvcvnoCvcc", "CvccCvcvCvccno",
        ]
        case .medium: ["CvcnoCvc", "CvcCvcno"]
        case .basic: ["aaanaaan", "aannaaan", "aaannaaa"]
        case .short: ["Cvcn"]
        case .pin: ["nnnn"]
        case .name: ["cvccvcvcv"]
        case .phrase: ["cvcc cvc cvccvcv cvc", "cvc cvccvcvcv cvcv", "cv cvccv cvc cvcvccv"]
        }
    }
}

/// Characters each template class can produce. All ASCII.
let templateCharacters: [Character: [UInt8]] = [
    "V": Array("AEIOU".utf8),
    "C": Array("BCDFGHJKLMNPQRSTVWXYZ".utf8),
    "v": Array("aeiou".utf8),
    "c": Array("bcdfghjklmnpqrstvwxyz".utf8),
    "A": Array("AEIOUBCDFGHJKLMNPQRSTVWXYZ".utf8),
    "a": Array("AEIOUaeiouBCDFGHJKLMNPQRSTVWXYZbcdfghjklmnpqrstvwxyz".utf8),
    "n": Array("0123456789".utf8),
    "o": Array("@&%?,=[]_:-+*$#!'^~;()/.".utf8),
    "x": Array("AEIOUaeiouBCDFGHJKLMNPQRSTVWXYZbcdfghjklmnpqrstvwxyz0123456789!@#$%^&*()".utf8),
    " ": Array(" ".utf8),
]
