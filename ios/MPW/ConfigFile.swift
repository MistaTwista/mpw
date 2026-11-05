import Foundation
import MPWCore

/// Coordinated reads and writes of config.json, so iCloud and other processes see whole files.
enum ConfigFile {
    /// nil when the file does not exist.
    static func read(_ url: URL) throws -> Config? {
        var coordinationError: NSError?
        var result: Result<Config?, Error> = .success(nil)
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordinationError) { url in
            result = Result {
                guard FileManager.default.fileExists(atPath: url.path) else { return nil }
                return try Config.decode(Data(contentsOf: url))
            }
        }
        if let coordinationError { throw coordinationError }
        return try result.get()
    }

    /// `presenter` is excluded from change notifications caused by this write.
    static func write(_ config: Config, to url: URL, presenter: NSFilePresenter?) throws {
        let data = try config.encoded()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var coordinationError: NSError?
        var result: Result<Void, Error> = .success(())
        NSFileCoordinator(filePresenter: presenter).coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { url in
            result = Result { try data.write(to: url, options: .atomic) }
        }
        if let coordinationError { throw coordinationError }
        try result.get()
    }
}

extension ConfigFile {
    /// Reads, changes and writes the file inside one coordinated write, so no change made
    /// elsewhere is lost. A file that does not parse is left untouched and the error is thrown.
    /// Returns the written config.
    static func update(
        _ url: URL,
        isSynced: Bool,
        presenter: NSFilePresenter?,
        _ change: (inout Config) throws -> Void
    ) throws -> Config {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var coordinationError: NSError?
        var result: Result<Config, Error>?
        NSFileCoordinator(filePresenter: presenter).coordinate(writingItemAt: url, options: [], error: &coordinationError) { url in
            result = Result {
                var config = Config()
                if FileManager.default.fileExists(atPath: url.path) {
                    config = try Config.decode(Data(contentsOf: url))
                } else if isSynced && isWaitingForDownload(url) {
                    throw ConfigStoreError.waitingForICloud
                }
                try change(&config)
                try config.encoded().write(to: url, options: .atomic)
                return config
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileWriteUnknown) }
        return try result.get()
    }

    /// For a missing file: true when iCloud has it but has not downloaded it yet.
    static func isWaitingForDownload(_ url: URL) -> Bool {
        let placeholder = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).icloud")
        if FileManager.default.fileExists(atPath: placeholder.path) { return true }
        guard FileManager.default.isUbiquitousItem(at: url) else { return false }
        let status = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]).ubiquitousItemDownloadingStatus
        return status != .current
    }
}

/// Calls `onChange` when another process (iCloud sync, the Files app) changes the file.
/// Presents the folder rather than the file, so it also hears about a file that does not exist yet
/// (a fresh install, or iCloud replacing its placeholder with the downloaded file).
final class ConfigFilePresenter: NSObject, NSFilePresenter, @unchecked Sendable {
    let presentedItemURL: URL?
    let presentedItemOperationQueue = OperationQueue()
    private let onChange: @Sendable () -> Void

    init(url: URL, onChange: @escaping @Sendable () -> Void) {
        presentedItemURL = url.deletingLastPathComponent()
        self.onChange = onChange
        presentedItemOperationQueue.maxConcurrentOperationCount = 1
    }

    func presentedSubitemDidChange(at url: URL) { onChange() }
    func presentedSubitemDidAppear(at url: URL) { onChange() }
    func presentedSubitem(at oldURL: URL, didMoveTo newURL: URL) { onChange() }
}
