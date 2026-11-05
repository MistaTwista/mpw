import MPWCore
import SwiftUI

struct IdenticonView: View {
    let identicon: Identicon

    var body: some View {
        Text(identicon.text)
            .font(.system(.title, design: .monospaced))
            .foregroundStyle(Self.color(identicon.color))
            .accessibilityLabel("Identicon \(identicon.text)")
            .accessibilityIdentifier("identicon")
    }

    /// ANSI color numbers 1…7. White becomes gray so it stays visible on a light background.
    static func color(_ ansi: Int) -> Color {
        switch ansi {
        case 1: .red
        case 2: .green
        case 3: .yellow
        case 4: .blue
        case 5: .purple
        case 6: .cyan
        default: .gray
        }
    }
}
