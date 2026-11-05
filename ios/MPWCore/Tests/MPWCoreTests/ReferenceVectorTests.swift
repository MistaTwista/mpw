import Foundation
import Testing
@testable import MPWCore

/// One <case> of testcases.xml. Empty fields inherit from the parent case.
private struct Case {
    var id = "", parent = ""
    var fields: [String: String] = [:]

    func value(_ key: String, _ all: [String: Case]) -> String {
        if let v = fields[key], !v.isEmpty { return v }
        guard !parent.isEmpty, let p = all[parent] else { return "" }
        return p.value(key, all)
    }
}

private final class CaseParser: NSObject, XMLParserDelegate {
    var cases: [Case] = []
    private var current: Case?
    private var element = ""
    private var text = ""

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        if name == "case" {
            current = Case(id: attributes["id"] ?? "", parent: attributes["parent"] ?? "")
        }
        element = name
        text = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if name == "case", let c = current {
            cases.append(c)
            current = nil
        } else if current != nil {
            current!.fields[name] = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

/// Algorithm v3 login passwords from the reference implementation's test suite, filtered like
/// the Go test: algorithm 3, Authentication purpose, no key context.
@Test func referenceVectors() throws {
    let parser = XMLParser(contentsOf: TestData.url("testcases.xml"))!
    let delegate = CaseParser()
    parser.delegate = delegate
    #expect(parser.parse())
    let all = Dictionary(uniqueKeysWithValues: delegate.cases.map { ($0.id, $0) })

    var checked = 0
    for c in delegate.cases {
        let v = { (key: String) in c.value(key, all) }
        guard v("algorithm") == "3", v("keyPurpose") == "Authentication", v("keyContext").isEmpty else { continue }
        let key = try MasterKey(fullName: v("fullName"), masterPassword: v("masterPassword"))
        let type = try #require(ResultType(rawValue: v("resultType")))
        let counter = try #require(UInt32(v("siteCounter")))
        #expect(key.password(siteName: v("siteName"), counter: counter, type: type) == v("result"), "\(c.id)")
        #expect(Identicon(fullName: v("fullName"), masterPassword: v("masterPassword")).text == v("identicon"), "\(c.id)")
        checked += 1
    }
    #expect(checked == 12)
}

@Test func parseResultType() {
    #expect(ResultType(parsing: "x") == .maximum)
    #expect(ResultType(parsing: "long") == .long)
    #expect(ResultType(parsing: "L") == .long)
    #expect(ResultType(parsing: "pin") == .pin)
    #expect(ResultType(parsing: "i") == .pin)
    #expect(ResultType(parsing: "q") == nil)
}
