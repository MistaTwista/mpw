import Foundation
import MPWCore
import Testing
@testable import MPW

@MainActor
struct ConfigStoreTests {
    let directory: URL
    let store: ConfigStore

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = ConfigStore(location: .local(directory: directory))
    }

    private var file: URL { store.location.fileURL }

    private func write(_ text: String) throws {
        try Data(text.utf8).write(to: file)
    }

    @Test func missingFileIsEmptyAndNotCreated() async {
        await store.reload()
        #expect(store.config == Config())
        #expect(!store.isReadOnly)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func loadsCLIConfig() async throws {
        try write(#"{"FULL_NAME": "Robert", "sites": [{"name": "github.com", "counter": 2}]}"#)
        await store.reload()
        #expect(store.config.fullName == "Robert")
        #expect(store.config.site(named: "github.com")?.counter == 2)
    }

    @Test func savesAndKeepsUnknownKeys() async throws {
        try write(#"{"future": 1, "sites": []}"#)
        await store.reload()
        try store.save(Site(name: " github.com ", counter: 3, type: .pin))
        let saved = try Config.decode(Data(contentsOf: file))
        #expect(saved.site(named: "github.com") == Site(name: "github.com", counter: 3, type: .pin))
        #expect(saved.extra["future"] == .number(1))
    }

    @Test func replacesRenamedSite() async throws {
        try store.save(Site(name: "a.com"))
        try store.save(Site(name: "b.com", counter: 2), replacing: "a.com")
        #expect(store.config.sites.map(\.name) == ["b.com"])
    }

    @Test func rejectsEmptyAndDuplicateNames() async throws {
        try store.save(Site(name: "a.com"))
        #expect(throws: ConfigStoreError.emptyName) { try store.save(Site(name: "  ")) }
        #expect(throws: ConfigStoreError.duplicateName("a.com")) { try store.save(Site(name: "a.com")) }
    }

    @Test func deletesSite() async throws {
        try store.save(Site(name: "a.com"))
        try store.delete(siteNamed: "a.com")
        #expect(store.config.sites.isEmpty)
    }

    @Test func brokenFileIsReadOnlyAndUntouched() async throws {
        try write("{ broken")
        await store.reload()
        #expect(store.isReadOnly)
        #expect(throws: ConfigStoreError.readOnly) { try store.save(Site(name: "a.com")) }
        #expect(try String(contentsOf: file, encoding: .utf8) == "{ broken")
    }

    @Test func recoversWhenFileIsFixed() async throws {
        try write("{ broken")
        await store.reload()
        try write(#"{"sites": [{"name": "a.com"}]}"#)
        await store.reload()
        #expect(!store.isReadOnly)
        #expect(store.config.sites.count == 1)
    }

    @Test func refreshesWhenFileChangesElsewhere() async throws {
        try store.save(Site(name: "a.com"))
        await store.start()
        defer { store.stop() }
        // A coordinated write without our presenter counts as an edit from elsewhere.
        try ConfigFile.write(Config(sites: [Site(name: "a.com"), Site(name: "b.com")]), to: file, presenter: nil)
        for _ in 0..<100 where store.config.sites.count != 2 {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(store.config.sites.count == 2)
    }
}
