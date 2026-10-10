import SwiftUI

/// Fixed guide wording. One place, so the disclaimer can be swapped (Taglish later) in one line.
enum GuideCopy {
    /// Always visible on the guide, at every height (DESIGN.md). English for now.
    static let disclaimer = "This is a guide only. It does not replace a doctor or rescuer."
    /// End state (H7). The mockup's "Your contacts have been alerted" is not always true, so it is not used.
    static let endSentence = "Stay with them and watch their breathing until help arrives."
    static let allStepsDone = "All steps done"
}

/// Guide: first-aid steps as a bottom sheet over the chat (mockup H1 to H3, H6, H7).
///
/// Present it as `.sheet` content; it sets its own detents: peek (H2), half (H1, the
/// default) and full (H3). The chat behind stays visible and usable, and the sheet never
/// closes fully. The general script (H6) uses the same layout. After the last step the
/// sheet shows an end state (H7) whose Done button calls `onDone`.
struct GuideView: View {
    /// Peek, half and full on the mockup's 868pt phone: 300, 540 and 760pt.
    static let peek = PresentationDetent.fraction(0.35)
    static let half = PresentationDetent.fraction(0.62)
    /// Peek at accessibility text sizes: tall enough for the step, both actions and the disclaimer.
    static let largeTextPeek = PresentationDetent.fraction(0.55)

    let script: FirstAidScript
    let onDone: () -> Void

    @State private var detent: PresentationDetent
    /// Index into `script.steps`; equal to `steps.count` once every step is done (H7).
    @State private var stepIndex: Int
    @State private var callFailed = false
    @Environment(\.dynamicTypeSize) private var typeSize

    init(script: FirstAidScript, onDone: @escaping () -> Void = {}) {
        self.init(script: script, initialDetent: Self.half, onDone: onDone)
    }

    /// `initialDetent` exists for previews; the app always opens at half height.
    init(script: FirstAidScript, initialDetent: PresentationDetent, onDone: @escaping () -> Void = {}) {
        self.init(script: script, initialDetent: initialDetent, initialStep: 0, onDone: onDone)
    }

    /// For previews of a later step or the end state (`initialStep == steps.count`).
    init(script: FirstAidScript, initialDetent: PresentationDetent, initialStep: Int, onDone: @escaping () -> Void = {}) {
        self.script = script
        self.onDone = onDone
        _detent = State(initialValue: initialDetent)
        _stepIndex = State(initialValue: min(max(initialStep, 0), script.steps.count))
    }

    private var steps: [String] { script.steps }
    private var isFinished: Bool { stepIndex >= steps.count }
    private var isPeek: Bool { detent == Self.peek || detent == Self.largeTextPeek }
    private var isFull: Bool { detent == .large }
    /// Accessibility text sizes get their own layout (`largeTextBody`); every other size keeps `regularBody`.
    private var isLargeText: Bool { typeSize.isAccessibilitySize }
    private var peekDetent: PresentationDetent { isLargeText ? Self.largeTextPeek : Self.peek }

    var body: some View {
        Group {
            if isLargeText { largeTextBody } else { regularBody }
        }
        .foregroundStyle(Palette.text)
        .saklaloSheet()
        .presentationDetents([peekDetent, Self.half, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled)
        .interactiveDismissDisabled()
        .onChange(of: isLargeText) {
            // Keep the sheet at peek when the text size crosses into (or out of) the accessibility sizes.
            if isPeek { detent = peekDetent }
        }
    }

    private var regularBody: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    header
                    if isFull {
                        stepList
                        if isFinished { endSentence }
                    } else if isFinished {
                        endSentence
                    } else {
                        currentStep
                    }
                    Spacer(minLength: 12)
                    if isFull { callButton }
                    actions(width: proxy.size.width)
                    footer
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 22)
                .padding(.bottom, 12)
                // Fill the sheet so the actions sit in the thumb zone; scroll when large type overflows.
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    /// Accessibility sizes: the step scrolls; the actions and the disclaimer are pinned below it,
    /// so both stay on screen at every height (GuideCopy.disclaimer).
    private var largeTextBody: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    header
                    if isFull {
                        stepList
                        if isFinished { endSentence }
                    } else if isFinished {
                        endSentence
                    } else {
                        currentStep
                    }
                    if isFull { callButton }
                    sourceLine
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 10) {
                actions(width: 0)
                Text(GuideCopy.disclaimer)
                    .font(Typography.finePrint)
                    .foregroundStyle(Palette.textDim)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 12)
            .padding(.bottom, 4)
            // A rule between the scrolling step and the pinned actions shows where the scroll ends.
            .overlay(alignment: .top) {
                Rectangle().fill(Palette.line).frame(height: 1)
            }
        }
    }

    // MARK: Header

    private var headerLabel: String {
        isFinished
            ? "\(script.title) · \(GuideCopy.allStepsDone)"
            : "\(script.title) · Step \(stepIndex + 1) of \(steps.count)"
    }

    /// The step label alone ("Step 1 of 4"), for the accessibility-size header.
    private var stepLabel: String {
        isFinished ? GuideCopy.allStepsDone : "Step \(stepIndex + 1) of \(steps.count)"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isLargeText {
                largeTextHeading
            } else {
                regularHeading
            }
            if !steps.isEmpty {
                // Past the last step every segment reads done. The label above says the same for VoiceOver.
                StepStrand(count: steps.count, current: stepIndex)
                    .accessibilityHidden(true)
            }
        }
    }

    private var regularHeading: some View {
        Text(headerLabel)
            .font(Typography.signage(20, weight: .bold, relativeTo: .headline))
            .textCase(.uppercase)
            .tracking(Typography.wordmarkTracking(20))
            .foregroundStyle(Palette.textDim)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    /// The step label leads; the script title is a smaller line under it at full height only,
    /// so at peek and half the step itself stays in view.
    private var largeTextHeading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stepLabel)
                .font(Typography.signage(20, weight: .bold, relativeTo: .headline))
                .textCase(.uppercase)
                .tracking(Typography.wordmarkTracking(20))
                .foregroundStyle(Palette.textDim)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(headerLabel)
                .accessibilityAddTraits(.isHeader)
            if isFull {
                Text(script.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textDim)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: Step (H1, H2, H6)

    private var currentStep: some View {
        Text(steps[stepIndex])
            .font(isPeek ? .title2.bold() : Typography.step)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, isPeek ? 0 : 4)
    }

    // MARK: End state (H7)

    private var endSentence: some View {
        Text(GuideCopy.endSentence)
            .font(Typography.title)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }

    // MARK: Full (H3)

    private var stepList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                stepRow(index: index, step: step)
            }
        }
    }

    private func stepRow(index: Int, step: String) -> some View {
        let isDone = index < stepIndex
        let isCurrent = index == stepIndex
        return Button {
            stepIndex = index
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                if isDone {
                    Image(systemName: "checkmark")
                        .fontWeight(.bold)
                        .accessibilityHidden(true)
                }
                Text("\(index + 1). \(step)")
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .font(isCurrent ? .title3.bold() : .body)
            .foregroundStyle(isCurrent ? Palette.text : Palette.textDim)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .padding(.leading, isCurrent ? 5 : 0)
            .frame(minHeight: Metrics.minTarget)
            .background(Palette.ground)
            .overlay(alignment: .leading) {
                if isCurrent {
                    Rectangle().fill(Palette.alarmText).frame(width: 5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Step \(index + 1)\(isDone ? ", done" : ""): \(step)")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    /// A plain phone call for a panicking companion (H3). Secondary: red is reserved.
    private var callButton: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack {
                Spacer(minLength: 0)
                Button {
                    do {
                        try ShortcutSMSService().call(phone: "911")
                        callFailed = false
                    } catch {
                        callFailed = true
                    }
                } label: {
                    Text("Call 911")
                        .padding(.horizontal, 16)
                }
                .buttonStyle(SaklaloActionStyle(kind: .secondary, size: .small))
                .fixedSize()
            }
            if callFailed {
                Text("This phone can't place the call. Dial 911 from the Phone app.")
                    .font(Typography.finePrint)
                    .foregroundStyle(Palette.alarmText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: Actions

    @ViewBuilder
    private func actions(width: CGFloat) -> some View {
        if isPeek && isLargeText {
            // H2 at accessibility sizes: Next, then Repeat under it at full width, so neither label shrinks.
            VStack(spacing: 10) {
                primaryButton
                repeatButton(size: .regular)
            }
        } else if isPeek {
            // H2: Repeat and Next (Next 1.6x wide).
            HStack(spacing: 10) {
                repeatButton(size: .regular)
                    .frame(width: peekRepeatWidth(width))
                primaryButton
            }
        } else {
            // H1, H3, H6, H7: primary on top, then Back and Repeat.
            VStack(spacing: 10) {
                primaryButton
                HStack(spacing: 10) {
                    backButton
                    repeatButton(size: .small)
                }
            }
        }
    }

    /// Next while there are steps left; Done in the end state (H7).
    @ViewBuilder
    private var primaryButton: some View {
        if isFinished {
            Button("Done") { onDone() }
                .buttonStyle(SaklaloActionStyle())
        } else {
            Button { next() } label: { iconLabel("Next", systemImage: "chevron.right") }
                .buttonStyle(SaklaloActionStyle())
        }
    }

    private var backButton: some View {
        Button { back() } label: { iconLabel("Back", systemImage: "chevron.left") }
            .buttonStyle(SaklaloActionStyle(kind: .secondary, size: .small))
            .disabled(stepIndex == 0)
            .opacity(stepIndex == 0 ? 0.4 : 1)
    }

    /// "Repeat" re-reads the current step; in the end state "Repeat all" starts over.
    private func repeatButton(size: SaklaloActionStyle.Size) -> some View {
        Button {
            if isFinished { repeatAll() } else { repeatStep() }
        } label: {
            iconLabel(isFinished ? "Repeat all" : "Repeat", systemImage: "arrow.clockwise")
        }
        .buttonStyle(SaklaloActionStyle(kind: .secondary, size: size))
    }

    /// The peek row splits the width 1 : 1.6 between Repeat and Next.
    private func peekRepeatWidth(_ sheetWidth: CGFloat) -> CGFloat {
        max((sheetWidth - Metrics.gutter * 2 - 10) / 2.6, 0)
    }

    private func iconLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .fontWeight(.bold)
                .imageScale(.small)
                .accessibilityHidden(true)
            Text(title)
                // Half-width buttons: shrink a long word at the largest sizes instead of breaking it.
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private func next() {
        stepIndex = min(stepIndex + 1, steps.count)
        // TODO: speak next step via AVSpeechSynthesizer
    }

    private func back() {
        stepIndex = max(stepIndex - 1, 0)
    }

    private func repeatStep() {
        // TODO: re-speak current step via AVSpeechSynthesizer
    }

    private func repeatAll() {
        stepIndex = 0
        // TODO: speak the first step via AVSpeechSynthesizer
    }

    // MARK: Footer

    /// The source alone; at accessibility sizes it scrolls with the step and the disclaimer is pinned.
    private var sourceLine: some View {
        Text("Source: \(script.source)")
            .font(Typography.finePrint)
            .foregroundStyle(Palette.textDim)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var footer: some View {
        Text("Source: \(script.source) · \(GuideCopy.disclaimer)")
            .font(Typography.finePrint)
            .foregroundStyle(Palette.textDim)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Previews

private func previewScript(general: Bool = false) -> FirstAidScript {
    general
        ? FirstAidScript(
            id: "general",
            title: "General",
            keywords: [],
            steps: ["Make sure help is on the way. Call 911 if no one has.", "Stay calm. Check that they are breathing normally.", "Don't move them unless you have to.", "Stay with them until help arrives."],
            source: "IFRC International First Aid, Resuscitation, and Education Guidelines 2020 (Red Cross Red Crescent)"
        )
        : FirstAidScript(
            id: "fall",
            title: "Fall, can't move",
            keywords: ["nahulog", "nadulas"],
            steps: ["Make sure help is on the way. Call 911 if no one has.", "Don't move them.", "Keep their head and neck still.", "Watch their breathing until help arrives."],
            source: "IFRC International First Aid, Resuscitation, and Education Guidelines 2020 (Red Cross Red Crescent)"
        )
}

/// Stands in for the chat so the sheet is shown over something.
private struct GuidePreviewHost: View {
    var detent: PresentationDetent
    var general = false
    var step = 0

    var body: some View {
        Text("Chat thread")
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding()
            .saklaloGround()
            .sheet(isPresented: .constant(true)) {
                GuideView(script: previewScript(general: general), initialDetent: detent, initialStep: step)
            }
    }
}

#Preview("Peek (H2)") { GuidePreviewHost(detent: GuideView.peek, step: 1) }
#Preview("Half (H1)") { GuidePreviewHost(detent: GuideView.half, step: 1) }
#Preview("Full (H3)") { GuidePreviewHost(detent: .large, step: 1) }
#Preview("General (H6)") { GuidePreviewHost(detent: GuideView.half, general: true) }
#Preview("End (H7)") { GuidePreviewHost(detent: GuideView.half, step: 4) }
#Preview("Peek, large text") { GuidePreviewHost(detent: GuideView.largeTextPeek, step: 1).dynamicTypeSize(.accessibility3) }
#Preview("Half, large text") { GuidePreviewHost(detent: GuideView.half, general: true).dynamicTypeSize(.accessibility3) }
