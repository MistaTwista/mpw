import Foundation
import Testing
@testable import MPWCore

@Test func decodesCLIConfig() throws {
    let json = #"{"FULL_NAME": "Robert", "sites": [{"name": "github.com", "counter": 3}, {"name": "old.com"}]}"#
    let config = try Config.decode(Data(json.utf8))
    #expect(config.fullName == "Robert")
    #expect(config.site(named: "github.com")?.counter == 3)
    #expect(config.site(named: "github.com")?.type == .long)
    #expect(config.site(named: "old.com")?.counter == 1)
    #expect(config.site(named: "nope.com") == nil)
}

@Test func zeroCounterMeansOne() throws {
    let config = try Config.decode(Data(#"{"sites": [{"name": "a", "counter": 0}]}"#.utf8))
    #expect(config.sites[0].counter == 1)
}

@Test func unknownTypeIsNil() throws {
    let config = try Config.decode(Data(#"{"sites": [{"name": "a", "type": "Huge"}]}"#.utf8))
    #expect(config.sites[0].type == nil)
}

@Test func emptyObjectIsEmptyConfig() throws {
    #expect(try Config.decode(Data("{}".utf8)) == Config())
}

@Test func keepsUnknownKeys() throws {
    let json = #"{"FULL_NAME": "R", "theme": {"dark": true}, "sites": [{"name": "a", "login": "me", "counter": 2}]}"#
    var config = try Config.decode(Data(json.utf8))
    config.sites[0].counter = 5
    let reread = try Config.decode(config.encoded())
    #expect(reread.extra["theme"] == .object(["dark": .bool(true)]))
    #expect(reread.sites[0].extra["login"] == .string("me"))
    #expect(reread.sites[0].counter == 5)
}

@Test func doesNotAddDefaultsToUntouchedSites() throws {
    let config = try Config.decode(Data(#"{"sites": [{"name": "a"}]}"#.utf8))
    let text = String(decoding: try config.encoded(), as: UTF8.self)
    #expect(!text.contains("counter"))
    #expect(!text.contains("type"))
}

@Test func encodesStableReadableJSON() throws {
    var site = Site(name: "github.com", counter: 2, type: .pin)
    site.extra = [:]
    let config = Config(fullName: "R", sites: [site])
    let text = String(decoding: try config.encoded(), as: UTF8.self)
    #expect(text == """
    {
      "FULL_NAME" : "R",
      "sites" : [
        {
          "counter" : 2,
          "name" : "github.com",
          "type" : "PIN"
        }
      ]
    }
    """)
}

@Test func invalidJSONThrows() {
    #expect(throws: (any Error).self) { try Config.decode(Data("{".utf8)) }
}
