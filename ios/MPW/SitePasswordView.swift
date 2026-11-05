import MPWCore
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SitePasswordView: View {
    let session: Session
    let siteName: String
    let counter: UInt32
    let type: ResultType

    @State private var isRevealed = false
    @State private var copied = false

    var body: some View {
        let password = session.password(siteName: siteName, counter: counter, type: type) ?? ""
        Form {
            Section {
                Text(isRevealed ? password : String(repeating: "•", count: password.count))
                    .font(.system(.title2, design: .monospaced))
                    .accessibilityIdentifier("password")
            } footer: {
                Text("\(type.rawValue) · counter \(counter)")
            }
            Section {
                Button(isRevealed ? "Hide" : "Show") { isRevealed.toggle() }
                    .accessibilityIdentifier("show")
                Button(copied ? "Copied for 60 seconds" : "Copy") {
                    Clipboard.copy(password)
                    copied = true
                }
                .accessibilityIdentifier("copy")
            }
        }
        .navigationTitle(siteName)
    }
}

/// The password of a saved site, kept in step with the store, so edits show at once.
struct SavedSitePasswordView: View {
    let session: Session
    let store: ConfigStore
    let siteName: String
    let onEdit: (Site) -> Void

    var body: some View {
        if let site = store.config.site(named: siteName), let type = site.type {
            SitePasswordView(session: session, siteName: site.name, counter: site.counter, type: type)
                .toolbar {
                    if !store.isReadOnly {
                        Button("Edit") { onEdit(site) }
                            .accessibilityIdentifier("edit")
                    }
                }
        } else {
            ContentUnavailableView("Site removed", systemImage: "trash", description: Text("\(siteName) is no longer in the list."))
        }
    }
}

enum Clipboard {
    /// How long a copied password stays on the pasteboard.
    static let lifetime: TimeInterval = 60

    /// Local only, so it does not reach other devices through Universal Clipboard.
    static func copy(_ text: String) {
        UIPasteboard.general.setItems(
            [[UTType.plainText.identifier: text]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(lifetime)]
        )
    }
}
