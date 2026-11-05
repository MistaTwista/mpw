import Foundation

/// The config file shared with the Go CLI:
///
///     {
///       "FULL_NAME": "Robert Lee Mitchell",
///       "sites": [{"name": "github.com", "counter": 2, "type": "Long"}]
///     }
///
/// Keys this version does not know are kept in `extra` and written back unchanged.
public struct Config: Equatable, Sendable, Codable {
    public var fullName: String?
    public var sites: [Site]
    public var extra: [String: JSONValue]

    public init(fullName: String? = nil, sites: [Site] = [], extra: [String: JSONValue] = [:]) {
        self.fullName = fullName
        self.sites = sites
        self.extra = extra
    }

    public func site(named name: String) -> Site? {
        sites.first { $0.name == name }
    }

    static let fullNameKey = "FULL_NAME", sitesKey = "sites"

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        fullName = try c.decodeIfPresent(String.self, forKey: AnyKey(Self.fullNameKey))
        sites = try c.decodeIfPresent([Site].self, forKey: AnyKey(Self.sitesKey)) ?? []
        extra = [:]
        for key in c.allKeys where key.stringValue != Self.fullNameKey && key.stringValue != Self.sitesKey {
            extra[key.stringValue] = try c.decode(JSONValue.self, forKey: key)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        for (key, value) in extra { try c.encode(value, forKey: AnyKey(key)) }
        try c.encodeIfPresent(fullName, forKey: AnyKey(Self.fullNameKey))
        try c.encode(sites, forKey: AnyKey(Self.sitesKey))
    }

    /// Parses the file contents. Throws on invalid JSON.
    public static func decode(_ data: Data) throws -> Config {
        try JSONDecoder().decode(Config.self, from: data)
    }

    /// Pretty-printed with sorted keys, so diffs of the file stay readable.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}

public struct Site: Equatable, Sendable, Codable, Identifiable {
    public var name: String
    /// As stored. Missing or 0 means 1, like in the CLI.
    public var storedCounter: UInt32?
    /// As stored. Missing means Long; an unknown value makes the site unusable.
    public var storedType: String?
    public var extra: [String: JSONValue]

    public var id: String { name }

    public init(name: String, counter: UInt32 = 1, type: ResultType = .long) {
        self.name = name
        storedCounter = counter
        storedType = type.rawValue
        extra = [:]
    }

    public var counter: UInt32 {
        get { storedCounter.flatMap { $0 == 0 ? nil : $0 } ?? 1 }
        set { storedCounter = newValue }
    }

    /// nil when the stored type is not one of the known types.
    public var type: ResultType? {
        guard let storedType else { return .long }
        return ResultType(rawValue: storedType)
    }

    public mutating func setType(_ type: ResultType) { storedType = type.rawValue }

    static let nameKey = "name", counterKey = "counter", typeKey = "type"

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        name = try c.decode(String.self, forKey: AnyKey(Self.nameKey))
        storedCounter = try c.decodeIfPresent(UInt32.self, forKey: AnyKey(Self.counterKey))
        storedType = try c.decodeIfPresent(String.self, forKey: AnyKey(Self.typeKey))
        extra = [:]
        let known: Set = [Self.nameKey, Self.counterKey, Self.typeKey]
        for key in c.allKeys where !known.contains(key.stringValue) {
            extra[key.stringValue] = try c.decode(JSONValue.self, forKey: key)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        for (key, value) in extra { try c.encode(value, forKey: AnyKey(key)) }
        try c.encode(name, forKey: AnyKey(Self.nameKey))
        try c.encodeIfPresent(storedCounter, forKey: AnyKey(Self.counterKey))
        try c.encodeIfPresent(storedType, forKey: AnyKey(Self.typeKey))
    }
}
