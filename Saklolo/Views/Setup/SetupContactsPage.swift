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
            SetupPageTitle(title: "Who should we alert?", subtitle: "1 to 5 people. #1 gets the call.")

            List {
                if contacts.isEmpty {
                    Text("No contacts yet")
                        .foregroundStyle(Palette.textDim)
                        .listRowBackground(Palette.groundRaised)
                }
                ForEach(Array(contacts.enumerated()), id: \.element.id) { index, contact in
                    ContactRow(position: index + 1, contact: contact)
                        .listRowBackground(Palette.groundRaised)
                }
                .onMove(perform: move)
                .onDelete(perform: delete)

                if contacts.count < Self.maxContacts {
                    Button {
                        showAddContact = true
                    } label: {
                        Label("Add contact", systemImage: "plus")
                            .frame(maxWidth: .infinity, minHeight: Metrics.minTarget)
                    }
                    .listRowBackground(Palette.groundRaised)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(contacts.count > 1 ? .active : .inactive))

            Text(footnote)
                .font(Typography.finePrint)
                .foregroundStyle(Palette.textDim)

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

    private var footnote: String {
        guard let first = contacts.first else {
            return "Add at least one person. We recommend 3."
        }
        if contacts.count == 1 {
            return "\(first.name) gets the call and a text. Drag to change who is #1."
        }
        return "\(first.name) gets the call. Everyone gets a text. Drag to change who is #1."
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

private struct ContactRow: View {
    let position: Int
    let contact: Contact

    var body: some View {
        HStack(spacing: Metrics.gap) {
            Text("\(position)")
                .font(Typography.signage(18, relativeTo: .headline))
                .foregroundStyle(Palette.onAction)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Palette.action))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(contact.name) · \(contact.phone)")
                    .font(.headline)
                Text(position == 1 ? "\(contact.relation) · gets the call + text" : "\(contact.relation) · text")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textDim)
            }
        }
        .frame(minHeight: Metrics.minTarget)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Number \(position), \(contact.name), \(contact.relation), \(contact.phone)")
    }
}

/// B4 (typed entry only; "Import from Contacts" is not built).
struct AddContactSheet: View {
    static let relations = ["Parent", "Sibling", "Child", "Partner", "Friend", "Neighbor", "Other"]

    var onSave: (_ name: String, _ phone: String, _ relation: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var phone = ""
    @State private var relation = "Sibling"

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedPhone: String { phone.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool {
        !trimmedName.isEmpty && trimmedPhone.filter(\.isNumber).count >= 7
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                TextField("Phone", text: $phone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                Picker("Relation", selection: $relation) {
                    ForEach(Self.relations, id: \.self) { Text($0) }
                }
            }
            .navigationTitle("New contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(trimmedName, trimmedPhone, relation)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    SetupContactsPage {}
        .padding()
        .saklaloGround()
        .modelContainer(for: Contact.self, inMemory: true)
}
