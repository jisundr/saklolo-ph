import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Opens the system import screen for the shared "Saklolo" Shortcut.
///
/// iOS has no API to add a Shortcut silently: the person always sees the
/// system "Add Shortcut" screen and confirms it, and confirms the Send
/// Message permission on its first run. The shared Shortcut holds no
/// contacts; it reads them from the input (`AlertCallback.shortcutInput`).
enum ShortcutInstaller {
    /// The iCloud share link of the signed Shortcut (Shortcuts, Share, Copy
    /// iCloud Link). Nil until it is published; setup then shows no button
    /// and the README steps are the way.
    static let shareURL: URL? = nil

    static var isAvailable: Bool { shareURL != nil }

    /// Opens the import screen. False if there is no link or iOS refused.
    @MainActor
    @discardableResult
    static func presentImport() -> Bool {
        #if canImport(UIKit)
        guard let shareURL else { return false }
        UIApplication.shared.open(shareURL)
        return true
        #else
        return false
        #endif
    }
}
