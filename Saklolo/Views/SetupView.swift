import SwiftUI
import SwiftData

/// Setup: user name, 1-5 contacts with priority order, per the brief's MVP scope.
struct SetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Contact.priority) private var contacts: [Contact]

    @State private var userName: String = ""
    @State private var newContactName = ""
    @State private var newContactPhone = ""
    @State private var newContactRelation = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Pangalan mo") {
                    TextField("Name", text: $userName)
                }

                Section("Mga kontak (priority order)") {
                    ForEach(contacts) { contact in
                        VStack(alignment: .leading) {
                            Text(contact.name).bold()
                            Text("\(contact.relation) · \(contact.phone)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete(perform: deleteContacts)

                    if contacts.count < 5 {
                        TextField("Name", text: $newContactName)
                        TextField("Phone", text: $newContactPhone)
                        TextField("Relation (e.g. Anak, Kapitbahay)", text: $newContactRelation)
                        Button("Add contact") { addContact() }
                            .disabled(newContactName.isEmpty || newContactPhone.isEmpty)
                    } else {
                        Text("Max 5 contacts (MVP limit).").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Setup")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func addContact() {
        let contact = Contact(
            name: newContactName,
            phone: newContactPhone,
            relation: newContactRelation,
            priority: contacts.count
        )
        modelContext.insert(contact)
        newContactName = ""
        newContactPhone = ""
        newContactRelation = ""
    }

    private func deleteContacts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(contacts[index])
        }
    }
}

#Preview {
    SetupView()
}
