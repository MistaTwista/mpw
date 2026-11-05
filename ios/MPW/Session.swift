import Foundation
import MPWCore
import Observation

/// Holds the master key between unlock and lock and decides when to lock.
@MainActor @Observable
final class Session {
    /// How long the key survives while the app is in the background.
    static let backgroundTimeout: TimeInterval = 120

    private(set) var fullName: String?
    /// Changes on every lock, so an unlock that started before it can be dropped.
    @ObservationIgnored private(set) var epoch = 0
    @ObservationIgnored private var key: MasterKey?
    @ObservationIgnored private var backgroundedAt: Date?
    @ObservationIgnored private var isInBackground = false
    @ObservationIgnored private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    var isUnlocked: Bool { fullName != nil }

    func unlock(fullName: String, key: MasterKey) {
        self.key = key
        self.fullName = fullName
        // Unlocked while in the background: the timeout starts now.
        backgroundedAt = isInBackground ? now() : nil
    }

    /// Unlocks only if nothing locked the session since `epoch` was read; otherwise drops `key`.
    @discardableResult
    func unlock(fullName: String, key: MasterKey, ifEpochIs epoch: Int) -> Bool {
        guard epoch == self.epoch else { return false }
        unlock(fullName: fullName, key: key)
        return true
    }

    func lock() {
        key = nil
        fullName = nil
        backgroundedAt = nil
        epoch += 1
    }

    func didEnterBackground() {
        isInBackground = true
        if isUnlocked { backgroundedAt = now() }
    }

    func didBecomeActive() {
        isInBackground = false
        if let since = backgroundedAt, now().timeIntervalSince(since) > Self.backgroundTimeout {
            lock()
        }
        backgroundedAt = nil
    }

    /// The device is about to lock: drop the key at once.
    func deviceWillLock() {
        lock()
    }

    /// nil when locked.
    func password(siteName: String, counter: UInt32, type: ResultType) -> String? {
        key?.password(siteName: siteName, counter: counter, type: type)
    }
}
