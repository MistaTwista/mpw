import MPWCore
import SwiftUI

struct SiteEditorView: View {
    let store: ConfigStore
    let originalName: String?

    @State private var site: Site
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    init(store: ConfigStore, site: Site, originalName: String?) {
        self.store = store
        self.originalName = originalName
        _site = State(initialValue: site)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Site", text: $site.name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .accessibilityIdentifier("siteName")
                Stepper("Counter: \(site.counter)", value: $site.counter, in: 1...UInt32.max)
                Picker("Type", selection: Binding(get: { site.type ?? .long }, set: { site.setType($0) })) {
                    ForEach(ResultType.allCases, id: \.self) { type in
                        Text("\(type.rawValue) — \(type.summary)").tag(type)
                    }
                }
                if let error {
                    Text(error).foregroundStyle(.red)
                }
            }
            .navigationTitle(originalName == nil ? "New site" : "Edit site")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try store.save(site, replacing: originalName)
                            dismiss()
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                }
            }
        }
    }
}
