import SwiftUI

/// Guide: first-aid steps as a bottom sheet over the chat (wireframes H1 to H3, H6, H7).
///
/// Present it as `.sheet` content; it sets its own detents: peek (H2), half (H1, the
/// default) and full (H3). The chat behind stays visible and usable, and the sheet never
/// closes fully. The general script (H6) uses the same layout. After the last step the
/// sheet shows an end state (H7) whose Done button calls `onDone`.
struct GuideView: View {
    static let peekHeight: CGFloat = 110
    static let peek = PresentationDetent.height(peekHeight)

    let script: FirstAidScript
    let onDone: () -> Void

    @State private var detent: PresentationDetent
    /// Index into `script.steps`; equal to `steps.count` once every step is done (H7).
    @State private var stepIndex = 0
    @State private var callFailed = false

    init(script: FirstAidScript, onDone: @escaping () -> Void = {}) {
        self.init(script: script, initialDetent: .medium, onDone: onDone)
    }

    /// `initialDetent` exists for previews; the app always opens at half height.
    init(script: FirstAidScript, initialDetent: PresentationDetent, onDone: @escaping () -> Void = {}) {
        self.script = script
        self.onDone = onDone
        _detent = State(initialValue: initialDetent)
    }

    private var steps: [String] { script.steps }
    private var isFinished: Bool { stepIndex >= steps.count }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .saklaloGround()
            .presentationDetents([Self.peek, .medium, .large], selection: $detent)
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled)
            .interactiveDismissDisabled()
    }

    @ViewBuilder
    private var content: some View {
        if detent == Self.peek {
            peekContent
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if isFinished { endState } else { currentStep }
                    if detent == .large {
                        allSteps
                        callButton
                        footer
                    }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 24)
                .padding(.bottom, Metrics.gutter)
            }
        }
    }

    // MARK: Peek (H2)

    private var peekContent: some View {
        HStack(alignment: .center, spacing: Metrics.gap) {
            Text(isFinished ? "Done" : "\(stepIndex + 1)/\(steps.count)")
                .font(Typography.signage(24, relativeTo: .headline))
                .foregroundStyle(Palette.alarmText)
            Text(isFinished ? "All steps done." : steps[stepIndex])
                .font(.headline)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 28)
        .contentShape(Rectangle())
        .onTapGesture { detent = .medium }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Shows the first-aid step in full.")
    }

    // MARK: Half (H1)

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(script.title)
                .font(Typography.signage(22, weight: .bold, relativeTo: .headline))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(Palette.textDim)
            if !steps.isEmpty {
                StepStrand(count: steps.count, current: min(stepIndex, steps.count - 1))
            }
        }
    }

    private var currentStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Step \(stepIndex + 1) of \(steps.count)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textDim)
            Text(steps[stepIndex])
                .font(Typography.step)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Metrics.gap) {
                Button("Repeat") {
                    // TODO: re-speak current step via AVSpeechSynthesizer
                }
                .buttonStyle(SaklaloActionStyle(kind: .secondary))

                Button("Next") {
                    stepIndex += 1
                    // TODO: speak next step via AVSpeechSynthesizer
                }
                .buttonStyle(SaklaloActionStyle())
            }
        }
    }

    // MARK: End state (H7)

    private var endState: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("That's all the steps.")
                .font(Typography.step)
            Text("Stay with them and watch their breathing until help arrives.")
                .font(Typography.body)
                .foregroundStyle(Palette.textDim)
            HStack(spacing: Metrics.gap) {
                Button("Start over") { stepIndex = 0 }
                    .buttonStyle(SaklaloActionStyle(kind: .secondary))
                Button("Done", action: onDone)
                    .buttonStyle(SaklaloActionStyle())
            }
        }
    }

    // MARK: Full (H3)

    private var allSteps: some View {
        VStack(alignment: .leading, spacing: Metrics.gap) {
            Text("All steps")
                .font(.headline)
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                Button {
                    stepIndex = index
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: Metrics.gap) {
                        Text("\(index + 1)")
                            .font(Typography.signage(22, relativeTo: .body))
                            .foregroundStyle(index == stepIndex ? Palette.alarmText : Palette.textDim)
                            .frame(minWidth: 24)
                        Text(step)
                            .font(Typography.body.weight(index == stepIndex ? .semibold : .regular))
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: Metrics.minTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Step \(index + 1): \(step)")
                .accessibilityAddTraits(index == stepIndex ? .isSelected : [])
            }
        }
    }

    private var callButton: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                do {
                    try ShortcutSMSService().call(phone: "911")
                    callFailed = false
                } catch {
                    callFailed = true
                }
            } label: {
                Label("Call 911", systemImage: "phone.fill")
                    .font(Typography.signage(28, relativeTo: .title2))
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity, minHeight: Metrics.primaryActionHeight)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous)
                            .fill(Palette.signalRed)
                    )
            }
            .buttonStyle(.plain)
            if callFailed {
                Text("This phone can't place the call. Dial 911 from the Phone app.")
                    .font(Typography.finePrint)
                    .foregroundStyle(Palette.alarmText)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Source: \(script.source)")
            Text("These steps are general first aid, not a diagnosis. Call 911 if the person is in danger.")
        }
        .font(Typography.finePrint)
        .foregroundStyle(Palette.textDim)
        .padding(.top, 8)
    }
}

// MARK: - Previews

private func previewScript(general: Bool = false) -> FirstAidScript {
    general
        ? FirstAidScript(
            id: "general",
            title: "General (no specific match)",
            keywords: [],
            steps: ["Stay calm.", "Check that they are breathing normally.", "Don't move them unless you have to.", "Your contacts have been alerted."],
            source: "Philippine Red Cross — Basic First Aid"
        )
        : FirstAidScript(
            id: "fall",
            title: "Fall, can't move",
            keywords: ["nahulog", "nadulas"],
            steps: ["Don't move them.", "Keep the head still.", "Keep them warm.", "Watch their breathing."],
            source: "Philippine Red Cross — Basic First Aid"
        )
}

/// Stands in for the chat so the sheet is shown over something.
private struct GuidePreviewHost: View {
    var detent: PresentationDetent
    var general = false

    var body: some View {
        Text("Chat thread")
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding()
            .saklaloGround()
            .sheet(isPresented: .constant(true)) {
                GuideView(script: previewScript(general: general), initialDetent: detent)
            }
    }
}

#Preview("Peek (H2)") { GuidePreviewHost(detent: GuideView.peek) }
#Preview("Half (H1)") { GuidePreviewHost(detent: .medium) }
#Preview("Full (H3)") { GuidePreviewHost(detent: .large) }
#Preview("General (H6)") { GuidePreviewHost(detent: .medium, general: true) }
