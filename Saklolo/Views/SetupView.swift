import SwiftUI

/// First-launch setup (B1 to B3): one question per screen, name, contacts, permissions.
/// Also used from Home as an edit sheet; finishing always marks setup complete and closes.
struct SetupView: View {
    enum Step: Int, CaseIterable {
        case name, contacts, permissions
    }

    @Environment(\.dismiss) private var dismiss
    @AppStorage("setupCompleted") private var setupCompleted = false

    @State private var step: Step = .name
    /// Captured once so the Close button does not appear the moment the first run finishes.
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Metrics.gap) {
                SetupProgressHeader(step: step.rawValue + 1, of: Step.allCases.count)

                Group {
                    switch step {
                    case .name:
                        SetupNamePage { step = .contacts }
                    case .contacts:
                        SetupContactsPage { step = .permissions }
                    case .permissions:
                        SetupPermissionsPage(finishTitle: isEditing ? "Done" : "Continue") { finish() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, Metrics.gutter)
            .saklaloGround()
            .toolbar {
                if step != .name {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back") { goBack() }
                    }
                }
                if isEditing {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") { dismiss() }
                    }
                }
            }
        }
        .onAppear { isEditing = setupCompleted }
    }

    private func goBack() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    private func finish() {
        setupCompleted = true
        dismiss()
    }
}

/// B1 to B5 header (mockup `.prep` + `.prog`): the listening model's state on the left while it
/// prepares, "Step 1 of 3" on the right, a thin progress track under both.
private struct SetupProgressHeader: View {
    let step: Int
    let of: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                ModelStateLabel(compact: true)
                Spacer(minLength: 0)
                Text("Step \(step) of \(of)")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textDim)
                    .accessibilityLabel("Setup step \(step) of \(of)")
            }
            SaklaloProgressBar(value: Double(step) / Double(max(of, 1)))
                .accessibilityHidden(true)
        }
        .padding(.top, 4)
    }
}

#Preview {
    SetupView()
        .modelContainer(for: Contact.self, inMemory: true)
        .environmentObject(ModelLoader())
}
