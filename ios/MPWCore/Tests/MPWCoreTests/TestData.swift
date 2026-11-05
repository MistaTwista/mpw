import Foundation

/// Locates internal/mpw/testdata in the repository. The files are shared with the Go tests and
/// live outside this package, so they cannot be bundled as SwiftPM resources.
enum TestData {
    static func url(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // MPWCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // MPWCore
            .deletingLastPathComponent() // ios
            .deletingLastPathComponent() // repository root
            .appendingPathComponent("internal/mpw/testdata")
            .appendingPathComponent(name)
    }
}
