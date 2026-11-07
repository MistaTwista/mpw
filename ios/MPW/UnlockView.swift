import MPWCore
import SwiftUI

struct UnlockView: View {
    let session: Session
    let store: ConfigStore

    @State private var fullName = ""
    @State private var masterPassword = ""
    @State private var rememberName = true
    @State private var isDeriving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Full name", text: $fullName)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("fullName")
                    SecureField("Master password", text: $masterPassword)
                        .accessibilityIdentifier("masterPassword")
                        .onSubmit(unlock)
                    if offersToRememberName {
                        Toggle("Remember name", isOn: $rememberName)
                            .accessibilityIdentifier("rememberName")
                    }
                } footer: {
                    if !fullName.isEmpty && !masterPassword.isEmpty {
                        HStack {
                            Spacer()
                            IdenticonView(identicon: Identicon(fullName: fullName, masterPassword: masterPassword))
                            Spacer()
                        }
                        .padding(.top)
                    }
                }
                Section {
                    Button(action: unlock) {
                        if isDeriving { ProgressView() } else { Text("Unlock") }
                    }
                    .disabled(fullName.isEmpty || masterPassword.isEmpty || isDeriving)
                    .accessibilityIdentifier("unlock")
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("mpw")
            .onAppear { fullName = store.config.fullName ?? fullName }
            .onChange(of: store.config.fullName) { old, new in
                // Follow a name changed elsewhere unless the user is typing a different one.
                if fullName.isEmpty || fullName == old { fullName = new ?? "" }
            }
        }
    }

    /// The typed name is not the one in the config, so it can be saved as the new default.
    private var offersToRememberName: Bool {
        !fullName.isEmpty && fullName != store.config.fullName && !store.isReadOnly
    }

    private func unlock() {
        guard !fullName.isEmpty, !masterPassword.isEmpty, !isDeriving else { return }
        let name = fullName, password = masterPassword
        let saveName = rememberName && offersToRememberName
        let epoch = session.epoch
        isDeriving = true
        error = nil
        Task {
            defer { isDeriving = false }
            do {
                let key = try await Task.detached(priority: .userInitiated) {
                    try MasterKey(fullName: name, masterPassword: password)
                }.value
                if saveName {
                    try? await store.setFullName(name)
                }
                masterPassword = ""
                // The device locked while the key was derived: drop it.
                if !session.unlock(fullName: name, key: key, ifEpochIs: epoch) {
                    self.error = "The device locked during unlock. Try again."
                }
            } catch {
                self.error = "Could not derive the master key."
            }
        }
    }
}
