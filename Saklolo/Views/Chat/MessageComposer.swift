import MessageUI
import UIKit

/// The system message composer, pre-filled (I2): one tap on Send. It goes as
/// one group message, since the composer cannot send separate texts in one
/// tap.
///
/// Presented with UIKit from the top-most screen rather than as a SwiftUI
/// sheet, because the guide is already a sheet over the chat and a second
/// sheet from the chat would not show.
@MainActor
enum MessageComposer {
    /// False on phones that cannot send texts (no SIM, iPad, simulator).
    static var canSendText: Bool { MFMessageComposeViewController.canSendText() }

    /// Opens the composer. `onSent` runs only when the person tapped Send.
    static func present(recipients: [String], body: String, onSent: @escaping @MainActor () -> Void) {
        guard canSendText, let top = topViewController() else { return }
        let composer = MFMessageComposeViewController()
        composer.recipients = recipients
        composer.body = body
        let delegate = Delegate(onSent: onSent)
        composer.messageComposeDelegate = delegate
        current = delegate
        top.present(composer, animated: true)
    }

    /// The composer holds its delegate weakly; this keeps it alive.
    private static var current: Delegate?

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }

    @MainActor
    private final class Delegate: NSObject, @preconcurrency MFMessageComposeViewControllerDelegate {
        let onSent: @MainActor () -> Void

        init(onSent: @escaping @MainActor () -> Void) {
            self.onSent = onSent
        }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true)
            if result == .sent { onSent() }
            MessageComposer.current = nil
        }
    }
}
