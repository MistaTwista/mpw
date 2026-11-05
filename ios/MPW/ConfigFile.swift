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

/// Calls `onChange` when another process (iCloud sync, the Files app) changes the file.
final class ConfigFilePresenter: NSObject, NSFilePresenter, @unchecked Sendable {
    let presentedItemURL: URL?
    let presentedItemOperationQueue = OperationQueue()
    private let onChange: @Sendable () -> Void

    init(url: URL, onChange: @escaping @Sendable () -> Void) {
        presentedItemURL = url
        self.onChange = onChange
        presentedItemOperationQueue.maxConcurrentOperationCount = 1
    }

    func presentedItemDidChange() { onChange() }
}
