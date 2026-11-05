import MPWCore
import SwiftUI

struct SiteListView: View {
    let session: Session
    let store: ConfigStore

    @State private var search = ""
    @State private var editing: EditorRequest?
    @State private var error: String?

    private var filtered: [Site] {
        let sites = store.config.sites.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let query = search.trimmingCharacters(in: .whitespaces)
        return query.isEmpty ? sites : sites.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    /// The search text when it names a site that is not in the list.
    private var unknownSite: String? {
        let query = search.trimmingCharacters(in: .whitespaces)
        return query.isEmpty || store.config.site(named: query) != nil ? nil : query
    }

    var body: some View {
        NavigationStack {
            List {
                if !store.location.isSynced {
                    Label("Sync is off: the site list is stored on this device only.", systemImage: "icloud.slash")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if store.isWaitingForICloud {
                    Label("Waiting for iCloud to download config.json…", systemImage: "icloud.and.arrow.down")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let loadError = store.loadError {
                    Label("config.json is broken, the list is read-only: \(loadError)", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                if let unknownSite {
                    Section {
                        NavigationLink("Password for “\(unknownSite)”") {
                            SitePasswordView(session: session, siteName: unknownSite, counter: 1, type: .long)
                        }
                        .accessibilityIdentifier("oneOff")
                        if !store.isReadOnly {
                            Button("Add “\(unknownSite)”") {
                                editing = EditorRequest(site: Site(name: unknownSite), originalName: nil)
                            }
                            .accessibilityIdentifier("addSearched")
                        }
                    }
                }
                Section {
                    ForEach(filtered) { site in
                        row(site)
                    }
                    .onDelete(perform: deleteAction)
                }
            }
            .searchable(text: $search, prompt: "Site")
            .navigationTitle(session.fullName ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { listToolbar }
            .sheet(item: $editing) { request in
                SiteEditorView(store: store, site: request.site, originalName: request.originalName)
            }
            .alert("Could not save", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
        }
        // Site names are case-sensitive, so the search field must not change what is typed.
        // The search bar belongs to the navigation stack, so these are set outside it.
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
    }

    @ToolbarContentBuilder
    private var listToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Lock", systemImage: "lock") { session.lock() }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Add", systemImage: "plus") {
                editing = EditorRequest(site: Site(name: ""), originalName: nil)
            }
            .disabled(store.isReadOnly)
        }
    }

    @ViewBuilder
    private func row(_ site: Site) -> some View {
        if let type = site.type {
            NavigationLink {
                SavedSitePasswordView(session: session, store: store, siteName: site.name) { site in
                    editing = EditorRequest(site: site, originalName: site.name)
                }
            } label: {
                SiteRow(site: site, typeName: type.rawValue)
            }
            .accessibilityIdentifier("site:\(site.name)")
        } else {
            SiteRow(site: site, typeName: "Unknown type “\(site.storedType ?? "")”")
                .foregroundStyle(.red)
        }
    }

    /// nil disables swipe to delete.
    private var deleteAction: ((IndexSet) -> Void)? {
        store.isReadOnly ? nil : { delete(at: $0) }
    }

    private func delete(at offsets: IndexSet) {
        let names = offsets.map { filtered[$0].name }
        Task {
            do {
                for name in names {
                    try await store.delete(siteNamed: name)
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

struct EditorRequest: Identifiable {
    let id = UUID()
    let site: Site
    let originalName: String?
}

private struct SiteRow: View {
    let site: Site
    let typeName: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(site.name)
            Text("\(typeName) · counter \(site.counter)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
