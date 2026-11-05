import SwiftUI

@main
struct MPWApp: App {
    @State private var session = Session()
    @State private var store: ConfigStore?

    var body: some Scene {
        WindowGroup {
            Group {
                if let store {
                    RootView(session: session, store: store)
                } else {
                    ProgressView()
                }
            }
            .task {
                guard store == nil else { return }
                let store = ConfigStore(location: await ConfigLocation.resolve())
                await store.start()
                self.store = store
            }
        }
    }
}
