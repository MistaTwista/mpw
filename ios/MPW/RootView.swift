import SwiftUI
import UIKit

/// Switches between unlock and the site list, and applies the session lock rules.
struct RootView: View {
    let session: Session
    let store: ConfigStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if session.isUnlocked {
                SiteListView(session: session, store: store)
            } else {
                UnlockView(session: session, store: store)
            }
        }
        .overlay {
            // Hides passwords in the app switcher snapshot.
            if scenePhase != .active { PrivacyCover() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: session.didEnterBackground()
            case .active:
                session.didBecomeActive()
                Task { await store.reload() }
            default: break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
            session.deviceWillLock()
        }
    }
}

struct PrivacyCover: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.background)
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
        }
        .ignoresSafeArea()
    }
}
