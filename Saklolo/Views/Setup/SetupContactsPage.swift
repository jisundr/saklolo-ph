import SwiftUI
import SwiftData

/// B2: "Who should we alert?" 1 to 5 contacts in priority order; #1 (priority 0) gets the call.
struct SetupContactsPage: View {
    static let maxContacts = 5

    var onNext: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Contact.priority) private var contacts: [Contact]
    @State private var showAddContact = false

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.gap) {
            SetupPageTitle(title: "Who should we alert?")

            List {
                if contacts.isEmpty {
                    Text("No contacts yet")
                        .font(Typography.body)
                        .foregroundStyle(Palette.textDim)
                        .setupListRow()
                }
                ForEach(Array(contacts.enumerated()), id: \.element.id) { index, contact in
                    ContactRow(
                        position: index + 1,
                        contact: contact,
                        count: contacts.count,
                        onMove: { move(from: IndexSet(integer: index), to: $0) },
                        onDelete: { delete(at: IndexSet(integer: index)) }
                    )
                    .setupListRow()
                }
                .onMove(perform: move)
                .onDelete(perform: delete)

                if contacts.count < Self.maxContacts {
                    AddContactButton { showAddContact = true }
                        .setupListRow()
                }

                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(Palette.textDim)
                    .setupListRow()
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            if let notice = Self.whoGetsWhat(contacts.map(\.name)) {
                InlineNotice(notice, systemImage: "info.circle", tone: .info)
            }

            Button("Next", action: onNext)
                .buttonStyle(SaklaloActionStyle())
                .disabled(contacts.isEmpty)
                .opacity(contacts.isEmpty ? 0.4 : 1)
        }
        .sheet(isPresented: $showAddContact) {
            AddContactSheet { name, phone, relation in
                modelContext.insert(Contact(name: name, phone: phone, relation: relation, priority: contacts.count))
            }
        }
    }

    private var hint: String {
        switch contacts.count {
        case 0: "Add at least one person. We recommend 3 contacts."
        case 1: "We recommend 3 contacts."
        case 2: "Drag to change who is #1. We recommend 3 contacts."
        default: "Drag to change who is #1."
        }
    }

    /// The B2 notice, from the real contacts in priority order: #1 gets the call, the rest a text.
    static func whoGetsWhat(_ names: [String]) -> String? {
        guard let first = names.first else { return nil }
        switch names.count {
        case 1: return "\(first) gets the call and a text."
        case 2: return "\(first) gets the call. \(names[1]) gets a text."
        default:
            let others = names.count - 2
            return "\(first) gets the call. \(names[1]) and \(others) more get a text."
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = contacts
        ordered.move(fromOffsets: source, toOffset: destination)
        renumber(ordered)
    }

    private func delete(at offsets: IndexSet) {
        var ordered = contacts
        for index in offsets { modelContext.delete(ordered[index]) }
        ordered.remove(atOffsets: offsets)
        renumber(ordered)
    }

    /// Priorities stay 0...n-1 in list order so priority 0 is always #1.
    private func renumber(_ ordered: [Contact]) {
        for (index, contact) in ordered.enumerated() where contact.priority != index {
            contact.priority = index
        }
    }
}

/// One B2 row: the contact's chip (mockup `.chip.tall`) with a drag handle. Long-press drags to
/// reorder and a swipe deletes (the list's own gestures); VoiceOver gets the same as named actions.
private struct ContactRow: View {
    /// Mockup `.chip.tall`. `ContactChip` has no tall option, so the handle carries the extra height.
    static let tallHeight: CGFloat = 58

    let position: Int
    let contact: Contact
    let count: Int
    /// Moves this row to a list offset, with `List.onMove`'s destination semantics.
    let onMove: (Int) -> Void
    let onDelete: () -> Void

    var body: some View {
        ContactChip(
            position: position,
            name: contact.name,
            caption: position == 1 ? "gets the call + text" : "text",
            relation: contact.relation,
            trailing: AnyView(handle)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Number \(position), \(contact.name), \(contact.relation), \(contact.phone)")
        .accessibilityValue(position == 1 ? "Gets the call and a text" : "Gets a text")
        .accessibilityActions {
            if position > 1 {
                Button("Move up") { onMove(position - 2) }
            }
            if position < count {
                Button("Move down") { onMove(position + 1) }
            }
            Button("Delete") { onDelete() }
        }
    }

    private var handle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.body.weight(.semibold))
            .foregroundStyle(Palette.textDim)
            // Chip padding is 6 top and bottom: this makes the chip 58pt tall.
            .frame(minHeight: Self.tallHeight - 12)
            .accessibilityHidden(true)
    }
}

/// The dashed "Add contact" field under the list (mockup `.field.dash`).
private struct AddContactButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .fontWeight(.semibold)
                Text("Add contact")
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(Palette.textDim)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                    .fill(Palette.groundRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                    .strokeBorder(Palette.line, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    /// A `List` row with the list's chrome removed, so rows sit on the page ground like the mockup.
    func setupListRow() -> some View {
        listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
    }
}

/// B4: "Import from Contacts" fills Name and Phone from one card; typing works the same as before.
/// Nothing is saved until the person taps Save.
struct AddContactSheet: View {
    static let relations = ["Parent", "Sibling", "Child", "Partner", "Friend", "Neighbor", "Other"]

    var onSave: (_ name: String, _ phone: String, _ relation: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var phone = ""
    @State private var relation = "Sibling"
    @State private var showContactPicker = false
    @FocusState private var focus: Field?

    private enum Field { case name, phone }

    private var trimmedName: String { ContactEntry.normalisedName(name) }
    private var trimmedPhone: String { ContactEntry.normalisedPhone(phone) }
    private var canSave: Bool { ContactEntry.canSave(name: name, phone: phone) }

    var body: some View {
        ScrollView {
            VStack(spacing: Metrics.gap) {
                header

                Button {
                    focus = nil
                    showContactPicker = true
                } label: {
                    Text("Import from Contacts")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(SaklaloActionStyle(kind: .secondary, size: .small))
                .accessibilityLabel("Import from Contacts")
                .accessibilityHint("Opens your phone's contacts to fill in the name and number.")
                .background(ContactPicker(isPresented: $showContactPicker, onPick: fill))

                Text("or type it")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textDim)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)

                TextField("Name", text: $name, prompt: Text(""))
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .focused($focus, equals: .name)
                    .accessibilityLabel("Name")
                    .saklaloField(label: "Name")
                    .contentShape(Rectangle())
                    .onTapGesture { focus = .name }
                TextField("Phone", text: $phone, prompt: Text(""))
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                    .focused($focus, equals: .phone)
                    .accessibilityLabel("Phone")
                    .saklaloField(label: "Phone")
                    .contentShape(Rectangle())
                    .onTapGesture { focus = .phone }
                Menu {
                    Picker("Relation", selection: $relation) {
                        ForEach(Self.relations, id: \.self) { Text($0) }
                    }
                } label: {
                    // The whole field box opens the picker, not just the value line.
                    HStack {
                        Text(relation)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.down")
                            .fontWeight(.semibold)
                    }
                    .saklaloField(label: "Relation")
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Relation")
                .accessibilityValue(relation)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
        .saklaloSheet()
    }

    /// Prefills from a picked card, keeping whatever the card leaves empty. The person checks the
    /// relation and saves.
    private func fill(_ draft: ContactEntry.Draft) {
        if !draft.name.isEmpty { name = draft.name }
        if !draft.phone.isEmpty { phone = draft.phone }
    }

    /// Cancel, title, Save in one row (mockup `.shead`).
    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Text("Cancel")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textDim)
                    .frame(minWidth: Metrics.minTarget, minHeight: Metrics.minTarget, alignment: .leading)
                    .contentShape(Rectangle())
            }
            Spacer(minLength: 0)
            Text("New contact")
                .font(.headline)
                .foregroundStyle(Palette.text)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button {
                onSave(trimmedName, trimmedPhone, relation)
                dismiss()
            } label: {
                Text("Save")
                    .font(.headline)
                    .foregroundStyle(canSave ? Palette.text : Palette.textDim)
                    .frame(minWidth: Metrics.minTarget, minHeight: Metrics.minTarget, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .disabled(!canSave)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SetupContactsPage {}
        .padding()
        .saklaloGround()
        .modelContainer(for: Contact.self, inMemory: true)
}

#Preview("Add contact") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            AddContactSheet { _, _, _ in }
        }
        .saklaloGround()
}
