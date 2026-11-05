import Foundation
import MPWCore
import Observation

enum ConfigStoreError: LocalizedError, Equatable {
    case readOnly
    case emptyName
    case duplicateName(String)

    var errorDescription: String? {
        switch self {
        case .readOnly: "The config file is broken. Fix it before making changes."
        case .emptyName: "Site name must not be empty."
        case .duplicateName(let name): "\(name) is already in the list."
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
    @ObservationIgnored private var presenter: ConfigFilePresenter?

    init(location: ConfigLocation) {
        self.location = location
    }

    var isReadOnly: Bool { loadError != nil }

    /// Loads the file and starts watching it.
    func start() async {
        await reload()
        guard presenter == nil else { return }
        let presenter = ConfigFilePresenter(url: location.fileURL) { [weak self] in
            Task { @MainActor in await self?.reload() }
        }
        NSFileCoordinator.addFilePresenter(presenter)
        self.presenter = presenter
    }

    func stop() {
        if let presenter { NSFileCoordinator.removeFilePresenter(presenter) }
        presenter = nil
    }

    func reload() async {
        let url = location.fileURL
        let result = await Task.detached { Result { try ConfigFile.read(url) } }.value
        switch result {
        case .success(let loaded):
            config = loaded ?? Config()
            loadError = nil
        case .failure(let error):
            loadError = error.localizedDescription
        }
    }

    func setFullName(_ name: String) throws {
        try update { $0.fullName = name }
    }

    /// Adds `site`, or replaces the site called `originalName`.
    func save(_ site: Site, replacing originalName: String? = nil) throws {
        let name = site.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ConfigStoreError.emptyName }
        if name != originalName, config.site(named: name) != nil {
            throw ConfigStoreError.duplicateName(name)
        }
        var site = site
        site.name = name
        try update { config in
            if let originalName, let index = config.sites.firstIndex(where: { $0.name == originalName }) {
                config.sites[index] = site
            } else {
                config.sites.append(site)
            }
        }
    }

    func delete(siteNamed name: String) throws {
        try update { $0.sites.removeAll { $0.name == name } }
    }

    private func update(_ change: (inout Config) -> Void) throws {
        guard !isReadOnly else { throw ConfigStoreError.readOnly }
        var updated = config
        change(&updated)
        try ConfigFile.write(updated, to: location.fileURL, presenter: presenter)
        config = updated
    }
}
