import Foundation
import MPWCore
import Observation

enum ConfigStoreError: LocalizedError, Equatable {
    case readOnly
    case emptyName
    case duplicateName(String)
    case waitingForICloud

    var errorDescription: String? {
        switch self {
        case .readOnly: "The config file is broken. Fix it before making changes."
        case .emptyName: "Site name must not be empty."
        case .duplicateName(let name): "\(name) is already in the list."
        case .waitingForICloud: "Waiting for iCloud to download config.json."
        }
    }
}

/// Owns config.json: loads it, saves edits, and reloads when it changes elsewhere.
@MainActor @Observable
final class ConfigStore {
    let location: ConfigLocation
    private(set) var config = Config()
    /// Set when the file exists but cannot be parsed. The store is read-only until it parses again.
    private(set) var loadError: String?
    /// iCloud has config.json but has not downloaded it yet. The store is read-only until it has.
    private(set) var isWaitingForICloud = false
    @ObservationIgnored private var presenter: ConfigFilePresenter?
    @ObservationIgnored private var isStarted = false
    /// Bumped by every reload and save, so a late result does not replace a newer one.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var appliedGeneration = 0

    init(location: ConfigLocation) {
        self.location = location
    }

    var isReadOnly: Bool { loadError != nil || isWaitingForICloud }

    /// Loads the file and watches it until `stop()`. Calling it again only reloads.
    func start() async {
        isStarted = true
        await reload()
        guard isStarted, presenter == nil else { return }
        let presenter = ConfigFilePresenter(url: location.fileURL) { [weak self] in
            Task { @MainActor in await self?.reload() }
        }
        NSFileCoordinator.addFilePresenter(presenter)
        self.presenter = presenter
    }

    func stop() {
        isStarted = false
        if let presenter { NSFileCoordinator.removeFilePresenter(presenter) }
        presenter = nil
    }

    private enum Loaded: Sendable {
        case config(Config)
        case waitingForICloud
    }

    func reload() async {
        generation += 1
        let generation = generation
        let url = location.fileURL, isSynced = location.isSynced
        let result = await Task.detached {
            Result { () throws -> Loaded in
                if let config = try ConfigFile.read(url) { return .config(config) }
                guard isSynced, ConfigFile.isWaitingForDownload(url) else { return .config(Config()) }
                try? FileManager.default.startDownloadingUbiquitousItem(at: url)
                return .waitingForICloud
            }
        }.value
        // A newer reload or save started meanwhile: its result wins.
        guard generation == self.generation else { return }
        appliedGeneration = generation
        switch result {
        case .success(.config(let loaded)):
            config = loaded
            loadError = nil
            isWaitingForICloud = false
        case .success(.waitingForICloud):
            loadError = nil
            isWaitingForICloud = true
        case .failure(let error):
            loadError = error.localizedDescription
        }
    }

    func setFullName(_ name: String) async throws {
        try await update { $0.fullName = name }
    }

    /// Adds `site`, or replaces the site called `originalName`.
    func save(_ site: Site, replacing originalName: String? = nil) async throws {
        let name = site.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ConfigStoreError.emptyName }
        var site = site
        site.name = name
        try await update { [site] config in
            // Checked against the file as it is now, not against the cached list.
            if name != originalName, config.site(named: name) != nil {
                throw ConfigStoreError.duplicateName(name)
            }
            if let originalName, let index = config.sites.firstIndex(where: { $0.name == originalName }) {
                config.sites[index] = site
            } else {
                config.sites.append(site)
            }
        }
    }

    func delete(siteNamed name: String) async throws {
        try await update { $0.sites.removeAll { $0.name == name } }
    }

    /// Reads, changes and writes the file in one coordinated write off the main actor,
    /// then adopts what was written.
    private func update(_ change: @escaping @Sendable (inout Config) throws -> Void) async throws {
        guard loadError == nil else { throw ConfigStoreError.readOnly }
        guard !isWaitingForICloud else { throw ConfigStoreError.waitingForICloud }
        generation += 1
        let generation = generation
        let url = location.fileURL, isSynced = location.isSynced, presenter = presenter
        let result = await Task.detached {
            Result { try ConfigFile.update(url, isSynced: isSynced, presenter: presenter, change) }
        }.value
        switch result {
        case .success(let written):
            // Skip only if something newer has already been applied.
            guard generation > appliedGeneration else { return }
            appliedGeneration = generation
            config = written
        case .failure(ConfigStoreError.waitingForICloud):
            await reload()
            throw ConfigStoreError.waitingForICloud
        case .failure(let error as ConfigStoreError):
            throw error
        case .failure(let error):
            // The file may have changed under us (for example it no longer parses): show what is there.
            await reload()
            throw error
        }
    }
}
