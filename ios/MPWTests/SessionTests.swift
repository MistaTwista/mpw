import Foundation
import MPWCore
import Testing
@testable import MPW

@MainActor
struct SessionTests {
    private final class Clock {
        var now = Date(timeIntervalSince1970: 0)
    }

    private static let key = try! MasterKey(fullName: "Robert Lee Mitchell", masterPassword: "banana colored duckling")

    private func unlocked() -> (Session, Clock) {
        let clock = Clock()
        let session = Session(now: { clock.now })
        session.unlock(fullName: "Robert Lee Mitchell", key: Self.key)
        return (session, clock)
    }

    @Test func generatesPasswordsWhileUnlocked() {
        let (session, _) = unlocked()
        #expect(session.password(siteName: "masterpasswordapp.com", counter: 1, type: .long) == "Jejr5[RepuSosp")
    }

    @Test func keepsKeyWithinTimeout() {
        let (session, clock) = unlocked()
        session.didEnterBackground()
        clock.now += 119
        session.didBecomeActive()
        #expect(session.isUnlocked)
    }

    @Test func locksAfterTimeout() {
        let (session, clock) = unlocked()
        session.didEnterBackground()
        clock.now += 121
        session.didBecomeActive()
        #expect(!session.isUnlocked)
        #expect(session.password(siteName: "a", counter: 1, type: .long) == nil)
    }

    @Test func timeoutStartsAgainAfterEachBackground() {
        let (session, clock) = unlocked()
        session.didEnterBackground()
        clock.now += 100
        session.didBecomeActive()
        clock.now += 100
        session.didEnterBackground()
        clock.now += 100
        session.didBecomeActive()
        #expect(session.isUnlocked)
    }

    @Test func locksAtOnceWhenDeviceLocks() {
        let (session, _) = unlocked()
        session.deviceWillLock()
        #expect(!session.isUnlocked)
    }

    @Test func lockButtonLocks() {
        let (session, _) = unlocked()
        session.lock()
        #expect(!session.isUnlocked)
        #expect(session.fullName == nil)
    }
}
