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
                SetupProgressHeader(
                    step: step.rawValue + 1,
                    of: Step.allCases.count,
                    onBack: step == .name ? nil : { goBack() },
                    onClose: isEditing ? { dismiss() } : nil
                )

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
            // The system bar's Back capsule pushed the header down from step 2 on;
            // Back and Close live in the header row instead so it never moves.
            .toolbar(.hidden, for: .navigationBar)
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

/// B1 to B5 header (mockup `.prep` + `.prog`): Back (space reserved on step 1 so nothing moves),
/// the listening model's state while it prepares, "Step 1 of 3" and Close when editing on the
/// right, a thin progress track under the row.
private struct SetupProgressHeader: View {
    let step: Int
    let of: Int
    var onBack: (() -> Void)?
    var onClose: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                HeaderTextButton(title: "Back", action: onBack ?? {})
                    .opacity(onBack == nil ? 0 : 1)
                    .disabled(onBack == nil)
                    .accessibilityHidden(onBack == nil)
                ModelStateLabel(compact: true)
                Spacer(minLength: 0)
                Text("Step \(step) of \(of)")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textDim)
                    .accessibilityLabel("Setup step \(step) of \(of)")
                if let onClose {
                    HeaderTextButton(title: "Close", action: onClose)
                }
            }
            .frame(minHeight: Metrics.minTarget)
            SaklaloProgressBar(value: Double(step) / Double(max(of, 1)))
                .accessibilityHidden(true)
        }
    }
}

/// Small text button for the setup header row with a full 44 pt target.
private struct HeaderTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Palette.text)
                .frame(minWidth: Metrics.minTarget, minHeight: Metrics.minTarget, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SetupView()
        .modelContainer(for: Contact.self, inMemory: true)
        .environmentObject(ModelLoader())
}
