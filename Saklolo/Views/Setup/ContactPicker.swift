import ContactsUI
import SwiftUI

/// Presents the system Contacts picker while `isPresented` is true. The picker runs out of
/// process, so the app reads only the one card and number the person picks and needs no
/// Contacts permission.
///
/// Contacts without a phone number are greyed out. A card with one number returns on tap; a
/// card with several opens so the person taps the number they mean. Cancel calls nothing.
///
/// `CNContactPickerViewController` misbehaves when SwiftUI hosts it directly in a sheet, so this
/// is an invisible controller that presents the picker modally from itself.
struct ContactPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    /// The picked card's name and number, ready to prefill the sheet. Not called on cancel.
    var onPick: (ContactEntry.Draft) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIViewController {
        let host = UIViewController()
        host.view.isHidden = true
        return host
    }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        context.coordinator.parent = self
        guard isPresented, host.presentedViewController == nil else { return }

        let picker = CNContactPickerViewController()
        let coordinator = context.coordinator
        picker.delegate = coordinator
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        picker.predicateForSelectionOfContact = NSPredicate(format: "phoneNumbers.@count == 1")
        picker.predicateForSelectionOfProperty = NSPredicate(format: "key == %@", CNContactPhoneNumbersKey)
        // Present after this update pass so the host is in the window.
        DispatchQueue.main.async {
            guard host.presentedViewController == nil else { return }
            guard host.view.window != nil else {
                coordinator.finish(with: nil)
                return
            }
            host.present(picker, animated: true)
        }
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency CNContactPickerDelegate {
        var parent: ContactPicker

        init(_ parent: ContactPicker) { self.parent = parent }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            finish(with: nil)
        }

        /// A card with exactly one number.
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            finish(with: Self.draft(from: contact, chosen: nil))
        }

        /// A number tapped on a card with several.
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
            let chosen = (contactProperty.value as? CNPhoneNumber)?.stringValue
            finish(with: Self.draft(from: contactProperty.contact, chosen: chosen))
        }

        func finish(with draft: ContactEntry.Draft?) {
            parent.isPresented = false
            if let draft { parent.onPick(draft) }
        }

        private static func draft(from contact: CNContact, chosen: String?) -> ContactEntry.Draft? {
            func string(_ key: String, _ value: () -> String) -> String {
                contact.isKeyAvailable(key) ? value() : ""
            }
            let numbers = contact.isKeyAvailable(CNContactPhoneNumbersKey)
                ? contact.phoneNumbers.map(\.value.stringValue)
                : []
            return ContactEntry.draft(
                given: string(CNContactGivenNameKey) { contact.givenName },
                family: string(CNContactFamilyNameKey) { contact.familyName },
                organization: string(CNContactOrganizationNameKey) { contact.organizationName },
                numbers: numbers,
                chosen: chosen
            )
        }
    }
}
