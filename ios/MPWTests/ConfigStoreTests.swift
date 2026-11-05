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
        try await store.save(Site(name: " github.com ", counter: 3, type: .pin))
        let saved = try Config.decode(Data(contentsOf: file))
        #expect(saved.site(named: "github.com") == Site(name: "github.com", counter: 3, type: .pin))
        #expect(saved.extra["future"] == .number(1))
    }

    @Test func replacesRenamedSite() async throws {
        try await store.save(Site(name: "a.com"))
        try await store.save(Site(name: "b.com", counter: 2), replacing: "a.com")
        #expect(store.config.sites.map(\.name) == ["b.com"])
    }

    @Test func rejectsEmptyAndDuplicateNames() async throws {
        try await store.save(Site(name: "a.com"))
        await #expect(throws: ConfigStoreError.emptyName) { try await store.save(Site(name: "  ")) }
        await #expect(throws: ConfigStoreError.duplicateName("a.com")) { try await store.save(Site(name: "a.com")) }
    }

    @Test func deletesSite() async throws {
        try await store.save(Site(name: "a.com"))
        try await store.delete(siteNamed: "a.com")
        #expect(store.config.sites.isEmpty)
    }

    @Test func brokenFileIsReadOnlyAndUntouched() async throws {
        try write("{ broken")
        await store.reload()
        #expect(store.isReadOnly)
        await #expect(throws: ConfigStoreError.readOnly) { try await store.save(Site(name: "a.com")) }
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
        try await store.save(Site(name: "a.com"))
        await store.start()
        defer { store.stop() }
        // A coordinated write without our presenter counts as an edit from elsewhere.
        try ConfigFile.write(Config(sites: [Site(name: "a.com"), Site(name: "b.com")]), to: file, presenter: nil)
        for _ in 0..<100 where store.config.sites.count != 2 {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(store.config.sites.count == 2)
    }

    @Test func saveKeepsChangesMadeElsewhereSinceLastReload() async throws {
        try await store.save(Site(name: "a.com"))
        await store.reload()
        // Written elsewhere, and this store has not reloaded since.
        try write(#"{"future": true, "sites": [{"name": "a.com"}, {"name": "b.com", "counter": 4}]}"#)
        try await store.save(Site(name: "c.com"))
        let saved = try Config.decode(Data(contentsOf: file))
        #expect(saved.sites.map(\.name) == ["a.com", "b.com", "c.com"])
        #expect(saved.extra["future"] == .bool(true))
        #expect(store.config == saved)
    }

    @Test func duplicateCheckUsesTheFileNotTheCache() async throws {
        await store.reload()
        try write(#"{"sites": [{"name": "a.com"}]}"#)
        await #expect(throws: ConfigStoreError.duplicateName("a.com")) { try await store.save(Site(name: "a.com")) }
    }

    @Test func brokenFileFoundOnSaveIsUntouched() async throws {
        await store.reload()
        try write("{ broken")
        await #expect(throws: (any Error).self) { try await store.save(Site(name: "a.com")) }
        #expect(try String(contentsOf: file, encoding: .utf8) == "{ broken")
    }

    @Test func localStoreWithMissingFileAllowsFirstSave() async throws {
        await store.reload()
        #expect(!store.isWaitingForICloud)
        try await store.save(Site(name: "a.com"))
        #expect(try Config.decode(Data(contentsOf: file)).sites.map(\.name) == ["a.com"])
    }

    @Test func syncedStoreWaitsForICloudPlaceholder() async throws {
        let synced = ConfigStore(location: ConfigLocation(fileURL: file, isSynced: true))
        try Data().write(to: directory.appendingPathComponent(".config.json.icloud"))
        await synced.reload()
        #expect(synced.isWaitingForICloud)
        #expect(synced.isReadOnly)
        await #expect(throws: ConfigStoreError.waitingForICloud) { try await synced.save(Site(name: "a.com")) }
        #expect(!FileManager.default.fileExists(atPath: file.path))

        // The download finished.
        try FileManager.default.removeItem(at: directory.appendingPathComponent(".config.json.icloud"))
        try write(#"{"sites": [{"name": "a.com"}]}"#)
        await synced.reload()
        #expect(!synced.isWaitingForICloud)
        try await synced.save(Site(name: "b.com"))
        #expect(synced.config.sites.map(\.name) == ["a.com", "b.com"])
    }

    @Test func syncedStoreWithoutPlaceholderStartsEmpty() async throws {
        let synced = ConfigStore(location: ConfigLocation(fileURL: file, isSynced: true))
        await synced.reload()
        #expect(!synced.isWaitingForICloud)
        try await synced.save(Site(name: "a.com"))
        #expect(synced.config.sites.count == 1)
    }

    @Test func startCanRestartAfterStop() async throws {
        await store.start()
        store.stop()
        await store.start()
        defer { store.stop() }
        try ConfigFile.write(Config(sites: [Site(name: "b.com")]), to: file, presenter: nil)
        for _ in 0..<100 where store.config.sites.map(\.name) != ["b.com"] {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(store.config.sites.map(\.name) == ["b.com"])
    }

    @Test func refreshesWhenFileAppearsElsewhere() async throws {
        await store.start()
        defer { store.stop() }
        try ConfigFile.write(Config(sites: [Site(name: "b.com")]), to: file, presenter: nil)
        for _ in 0..<100 where store.config.sites.map(\.name) != ["b.com"] {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(store.config.sites.map(\.name) == ["b.com"])
    }
}
