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
                    .textSelection(.enabled)
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
