import Foundation
import Testing
@testable import MPWCore

private struct Golden: Decodable {
    struct Password: Decodable {
        let fullName, siteName: String
        let counter: UInt32
        let type: String
        let result: String
    }
    struct Icon: Decodable {
        let fullName, text: String
        let color: Int
    }
    let masterPassword: String
    let passwords: [Password]
    let identicons: [Icon]
}

private func loadGolden() throws -> Golden {
    try JSONDecoder().decode(Golden.self, from: Data(contentsOf: TestData.url("golden.json")))
}

@Test func goldenPasswords() throws {
    let golden = try loadGolden()
    #expect(golden.passwords.count == 144)
    var keys: [String: MasterKey] = [:]
    for v in golden.passwords {
        let key = try keys[v.fullName] ?? MasterKey(fullName: v.fullName, masterPassword: golden.masterPassword)
        keys[v.fullName] = key
        let type = try #require(ResultType(rawValue: v.type))
        #expect(key.password(siteName: v.siteName, counter: v.counter, type: type) == v.result,
                "\(v.fullName) / \(v.siteName) / \(v.counter) / \(v.type)")
    }
}

@Test func goldenIdenticons() throws {
    let golden = try loadGolden()
    for v in golden.identicons {
        #expect(Identicon(fullName: v.fullName, masterPassword: golden.masterPassword)
            == Identicon(text: v.text, color: v.color))
    }
}

@Test func identiconKeepsEveryAccessory() {
    #expect(Identicon.accessories.count == 57)
    #expect(!Identicon.accessories.contains(""))
    #expect(Identicon.accessories[10] == "☄")
}
