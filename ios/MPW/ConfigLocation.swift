import Foundation

/// Where config.json lives: the app's iCloud container when available, otherwise local.
struct ConfigLocation: Sendable {
    static let containerIdentifier = "iCloud.io.github.mistatwista.mpw"
    /// UI tests point the app at a temporary folder through this environment variable.
    static let overrideEnvironmentKey = "MPW_CONFIG_DIR"

    let fileURL: URL
    let isSynced: Bool

    static func local(directory: URL) -> ConfigLocation {
        ConfigLocation(fileURL: directory.appendingPathComponent("config.json"), isSynced: false)
    }

    /// Looking up the iCloud container can block, so this runs off the main actor.
    static func resolve() async -> ConfigLocation {
        if let dir = ProcessInfo.processInfo.environment[overrideEnvironmentKey] {
            return local(directory: URL(fileURLWithPath: dir))
        }
        let container = await Task.detached {
            FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier)
        }.value
        if let container {
            return ConfigLocation(
                fileURL: container.appendingPathComponent("Documents/config.json"),
                isSynced: true
            )
        }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return local(directory: documents)
    }
}
