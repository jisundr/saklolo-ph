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

/// "Step 1 of 3" with a thin progress bar, as in B1 to B3.
private struct SetupProgressHeader: View {
    let step: Int
    let of: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("Step \(step) of \(of)")
                .font(Typography.finePrint)
                .foregroundStyle(Palette.textDim)
            ProgressView(value: Double(step), total: Double(of))
                .tint(Palette.action)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Setup step \(step) of \(of)")
    }
}

#Preview {
    SetupView()
        .modelContainer(for: Contact.self, inMemory: true)
}
