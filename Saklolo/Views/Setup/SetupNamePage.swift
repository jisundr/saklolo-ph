import SwiftUI

/// B1: "What's your name?" Required; Next stays disabled until a name is entered.
struct SetupNamePage: View {
    var onNext: () -> Void

    @AppStorage("userName") private var storedName = ""
    @State private var draft = ""
    @FocusState private var focused: Bool

    private var trimmed: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.gap) {
            SetupPageTitle(title: "What's your name?", subtitle: "Used in the text your contacts receive.")

            TextField("Name", text: $draft, prompt: Text("Your name"))
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .submitLabel(.next)
                .focused($focused)
                .accessibilityLabel("Your name")
                .onSubmit(next)
                .saklaloField(label: "Name")
                .contentShape(Rectangle())
                .onTapGesture { focused = true }

            Spacer()

            Button("Next", action: next)
                .buttonStyle(SaklaloActionStyle())
                .disabled(trimmed.isEmpty)
                .opacity(trimmed.isEmpty ? 0.4 : 1)
        }
        .onAppear {
            draft = storedName
            focused = storedName.isEmpty
        }
    }

    private func next() {
        guard !trimmed.isEmpty else { return }
        storedName = trimmed
        onNext()
    }
}

/// Large question plus one line of reason, shared by the setup pages (mockup `.t` + `.lead`).
struct SetupPageTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Typography.title)
                .foregroundStyle(Palette.text)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(Typography.body)
                    .foregroundStyle(Palette.textDim)
            }
        }
        .padding(.top, 8)
    }
}

#Preview {
    SetupNamePage {}
        .padding()
        .saklaloGround()
}
