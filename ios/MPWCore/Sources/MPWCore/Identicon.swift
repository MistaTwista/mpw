import CryptoKit
import Foundation

/// A short picture derived from the full name and master password. It lets the user spot a
/// mistyped master password; it does not take part in password derivation.
///
///     seed  = HMAC-SHA-256( <master password>, <name> )
///     text  = leftArm[seed[0]] . body[seed[1]] . rightArm[seed[2]] . accessory[seed[3]]
///     color = seed[4] % 7 + 1
public struct Identicon: Equatable, Sendable {
    public let text: String
    /// ANSI color number: 1 red, 2 green, 3 yellow, 4 blue, 5 magenta, 6 cyan, 7 white.
    public let color: Int

    public init(text: String, color: Int) {
        self.text = text
        self.color = color
    }

    public init(fullName: String, masterPassword: String) {
        let seed = Array(HMAC<SHA256>.authenticationCode(
            for: Array(fullName.utf8),
            using: SymmetricKey(data: Array(masterPassword.utf8))
        ))
        func pick(_ list: [String], _ byte: UInt8) -> String { list[Int(byte) % list.count] }
        text = pick(Self.leftArms, seed[0]) + pick(Self.bodies, seed[1])
            + pick(Self.rightArms, seed[2]) + pick(Self.accessories, seed[3])
        color = Int(seed[4]) % 7 + 1
    }

    static let leftArms = ["╔", "╚", "╰", "═"]
    static let bodies = ["█", "░", "▒", "▓", "☺", "☻"]
    static let rightArms = ["╗", "╝", "╯", "═"]
    static let accessories = [
        "◈", "◎", "◐", "◑", "◒", "◓", "☀", "☁", "☂", "☃", "☄", "★",
        "☆", "☎", "☏", "⎈", "⌂", "☘", "☢", "☣", "☕", "⌚", "⌛", "⏰",
        "⚡", "⛄", "⛅", "☔", "♔", "♕", "♖", "♗", "♘", "♙", "♚", "♛",
        "♜", "♝", "♞", "♟", "♨", "♩", "♪", "♫", "⚐", "⚑", "⚔", "⚖",
        "⚙", "⚠", "⌘", "⏎", "✄", "✆", "✈", "✉", "✌",
    ]
}
