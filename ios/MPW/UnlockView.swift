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
                        .textContentType(.name)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("fullName")
                    SecureField("Master password", text: $masterPassword)
                        .textContentType(.password)
                        .accessibilityIdentifier("masterPassword")
                        .onSubmit(unlock)
                    if store.config.fullName == nil && !store.isReadOnly {
                        Toggle("Remember name", isOn: $rememberName)
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
        }
    }

    private func unlock() {
        guard !fullName.isEmpty, !masterPassword.isEmpty, !isDeriving else { return }
        let name = fullName, password = masterPassword
        isDeriving = true
        error = nil
        Task {
            defer { isDeriving = false }
            do {
                let key = try await Task.detached(priority: .userInitiated) {
                    try MasterKey(fullName: name, masterPassword: password)
                }.value
                if rememberName && store.config.fullName == nil && !store.isReadOnly {
                    try? store.setFullName(name)
                }
                masterPassword = ""
                session.unlock(fullName: name, key: key)
            } catch {
                self.error = "Could not derive the master key."
            }
        }
    }
}
