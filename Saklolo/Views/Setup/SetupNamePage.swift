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

            TextField("Your name", text: $draft)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .submitLabel(.next)
                .focused($focused)
                .onSubmit(next)
                .setupFieldStyle()

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

/// Large question plus one line of reason, shared by the setup pages.
struct SetupPageTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(Typography.body)
                    .foregroundStyle(Palette.textDim)
            }
        }
        .padding(.top, Metrics.gap)
    }
}

extension View {
    /// Bordered text field on the raised ground, at least the minimum target height.
    func setupFieldStyle() -> some View {
        padding(.horizontal, 14)
            .frame(minHeight: Metrics.minTarget + 8)
            .background(
                RoundedRectangle(cornerRadius: Metrics.chipRadius, style: .continuous)
                    .fill(Palette.groundRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.chipRadius, style: .continuous)
                    .strokeBorder(Palette.line, lineWidth: 1.5)
            )
    }
}

#Preview {
    SetupNamePage {}
        .padding()
        .saklaloGround()
}
