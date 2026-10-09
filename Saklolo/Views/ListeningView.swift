import SwiftUI
import SwiftData

/// The one chat screen the red button opens (F1 to F3, F5). The voice orb sits
/// at the bottom; the transcript becomes the person's bubble; fixed replies
/// say who and what happened; the first-aid guide opens as a sheet over it.
/// Nothing is sent at the tap: the one alert text goes out when understanding
/// finishes, or with the general text at `AlertPolicy.deadline` (step 4).
/// Alone mode holds it for the person's dock instead (G1).
///
/// Kept the `ListeningView` name and init so Home does not change (plan flag 7).
struct ListeningView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Contact.priority) private var contacts: [Contact]
    @StateObject private var location = LocationService()

    @State private var messages: [ChatMessage] = [.saklolo(ChatReplies.opening)]
    @State private var stage: Stage = .listening(.waiting)
    @State private var level: Float = 0
    @State private var startedAt = Date.now
    @State private var incident: Incident?
    @State private var script: FirstAidScript?
    @State private var showGuide = false
    /// Set by Cancel or Done: the session is over, nothing new is shown.
    @State private var stopped = false
    @State private var alerts: AlertCoordinator<ContinuousClock>?
    @State private var alertOutcome: AlertOutcome?
    @State private var understood: SituationClassification?
    /// Alone mode, alert not sent yet: the dock decides.
    @State private var awaitingPerson = false
    /// The alert has started going out; Cancel can no longer unsend it.
    @State private var alertFired = false

    private enum Stage: Equatable {
        /// Recording or transcribing; the orb shows.
        case listening(VoiceOrb.Phase)
        /// Transcript in; the classifier is choosing.
        case understanding
        /// Incident saved; replies shown.
        case done
    }

    /// "button" or "voice", stored on the Incident.
    var trigger = "button"
    /// Used when transcription fails or hears nothing, so the rest of the flow
    /// can still be exercised (and in the simulator, where there is no mic).
    var fallbackTranscript = ""
    /// Called once, when the session ends (Done, or Cancel after the alert
    /// went out), with the saved incident.
    var onClassified: (Incident) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            header
            thread
            footer
        }
        .saklaloGround()
        .task { await runSession() }
        .sheet(isPresented: $showGuide) {
            if let script {
                GuideView(script: script, onDone: endSession)
            }
        }
    }

    // MARK: - Layout

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Saklolo")
                .font(.title2.bold())
            Spacer()
            Text(startedAt, format: .dateTime.hour().minute())
                .font(Typography.finePrint)
                .foregroundStyle(Palette.textDim)
            Spacer()
            let headerExit = SessionExit.header(
                incidentSaved: incident != nil,
                awaitingPerson: awaitingPerson,
                alertFired: alertFired
            )
            if headerExit == .done {
                Button("Done", action: endSession)
                    .font(.body.bold())
                    .frame(minHeight: Metrics.minTarget)
                    .accessibilityHint(headerExit.hint)
            } else {
                Button {
                    cancel()
                } label: {
                    Label("Cancel", systemImage: "xmark")
                }
                .font(.body)
                .foregroundStyle(Palette.textDim)
                .frame(minHeight: Metrics.minTarget)
                .accessibilityHint(headerExit.hint)
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 8)
    }

    private var thread: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Metrics.gap) {
                    ForEach(messages) { message in
                        ChatMessageRow(message: message)
                            .id(message.id)
                    }
                    if stage == .listening(.transcribing) || stage == .understanding {
                        TypingBubble().id("typing")
                    }
                }
                .padding(Metrics.gutter)
            }
            .onChange(of: messages) {
                withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch stage {
        case .listening(let phase):
            VoiceOrb(phase: phase, level: level)
                .padding(.bottom, Metrics.gutter)
        case .understanding:
            EmptyView()
        case .done:
            if awaitingPerson {
                AloneDock(onFire: fireFromDock, onOkay: personIsOkay)
            } else if script != nil, !showGuide {
                Button("Start first aid") { showGuide = true }
                    .buttonStyle(SaklaloActionStyle())
                    .padding(Metrics.gutter)
            }
        }
    }

    // MARK: - Session

    private func cancel() {
        // Once the alert is out (or going out) it cannot be taken back, so
        // Cancel keeps the record of it, like Done.
        if alerts?.hasFired == true {
            endSession()
            return
        }
        // The view's task is cancelled when it goes away, which stops the
        // recorder; the flag makes sure nothing is saved even if Whisper or
        // the classifier is already past its last cancellation point.
        stopped = true
        alerts?.cancel()
        // Alone mode's dock: the incident is in but nothing was sent.
        if let incident { modelContext.delete(incident) }
        dismiss()
    }

    /// Done, the guide's last step, "I'm okay", or Cancel after the alert
    /// went out: the session ends with the incident and its alert rows. A
    /// send still in its location wait is waited for, so its rows are kept.
    private func endSession() {
        guard !stopped else { return }
        stopped = true
        alerts?.cancel()
        Task {
            let outcome = await alerts?.settledOutcome()
            let kept = incident ?? saveIncidentSoFar()
            if alertOutcome == nil, let outcome {
                alertOutcome = outcome
                record(outcome, on: kept)
            }
            onClassified(kept)
        }
    }

    /// The incident when the session ends before understanding finished
    /// (Cancel after the deadline alert): what was heard, if anything.
    private func saveIncidentSoFar() -> Incident {
        let heard = messages.last { $0.role == .user }.flatMap { message -> String? in
            if case .text(let text) = message.kind { text } else { nil }
        }
        let saved = Incident(trigger: trigger, mode: .guide, transcript: heard ?? "", startedAt: startedAt)
        modelContext.insert(saved)
        incident = saved
        if let alertOutcome { record(alertOutcome, on: saved) }
        return saved
    }

    private var isStopped: Bool { stopped || Task.isCancelled }

    private func runSession() async {
        // The deadline starts at the tap; at 10 s the general text goes out
        // if nothing was understood by then.
        let coordinator = AlertCoordinator(location: location)
        alerts = coordinator
        coordinator.onFire = { alertFired = true }
        coordinator.begin(at: startedAt, recipients: contacts.map(AlertRecipient.init)) { outcome in
            show(outcome)
        }

        var heard = ""
        var failure = ""
        do {
            heard = try await SpeechTranscriptionService.shared.transcribe { event in
                Task { @MainActor in
                    switch event {
                    case .level(let value): level = value
                    case .speechDetected: stage = .listening(.hearing)
                    case .transcribing:
                        stage = .listening(.transcribing)
                        level = 0
                    }
                }
            }
        } catch {
            failure = " (\(error))"
        }
        guard !isStopped else { return }
        print("[004] \(heard.isEmpty ? "canned fallback\(failure)" : "heard") | transcript: \(heard.debugDescription)")

        // Empty or failed: say so, carry on with the fallback text (F5).
        let transcript: String
        if heard.isEmpty {
            messages.append(.saklolo(ChatReplies.couldNotUnderstand))
            transcript = fallbackTranscript
        } else {
            transcript = heard
        }
        if !transcript.isEmpty {
            messages.append(.user(transcript))
        }
        stage = .understanding

        // Keyword result is computed first inside classify(); the LLM can
        // refine it but never delays it past its timeout.
        let result = await SituationClassifierService().classify(transcript: transcript)
        guard !isStopped else { return }

        let saved = Incident(
            trigger: trigger,
            mode: result.mode,
            transcript: transcript,
            summary: result.summary,
            scriptID: result.scriptID
        )
        modelContext.insert(saved)
        incident = saved
        understood = result
        script = Self.script(id: result.scriptID)
        if let alertOutcome { record(alertOutcome, on: saved) }

        // Guide mode sends now, alongside the replies so they never delay it.
        // Alone mode sends nothing at understanding; the dock fires it.
        var sending: Task<AlertOutcome?, Never>?
        switch result.mode {
        case .guide:
            sending = Task { await coordinator.send(classification: result) }
        case .alone:
            coordinator.hold()
            awaitingPerson = !coordinator.hasFired
        }
        stage = .done

        for reply in ChatReplies.replies(for: result) {
            try? await Task.sleep(for: .milliseconds(400))
            guard !isStopped else { return }
            messages.append(.saklolo(reply))
        }
        if let outcome = await sending?.value {
            show(outcome)
        }

        // The steps open after a short pause (F3 to H1); in alone mode only
        // once the alert has gone (G2).
        try? await Task.sleep(for: .seconds(2))
        guard !isStopped, script != nil, !awaitingPerson else { return }
        showGuide = true
    }

    /// "I need help" in alone mode: send now, then the steps follow (G2).
    private func fireFromDock() {
        awaitingPerson = false
        Task {
            if let outcome = await alerts?.send(classification: understood) {
                show(outcome)
            }
            guard !isStopped, script != nil else { return }
            showGuide = true
        }
    }

    /// "I'm okay" in alone mode: nothing is sent (G5).
    private func personIsOkay() {
        awaitingPerson = false
        endSession()
    }

    /// Puts the alert in the thread and on the incident, once.
    private func show(_ outcome: AlertOutcome) {
        guard !stopped, alertOutcome == nil else { return }
        alertOutcome = outcome
        messages.append(contentsOf: outcome.chatMessages)
        if let incident { record(outcome, on: incident) }
    }

    private func record(_ outcome: AlertOutcome, on incident: Incident) {
        for alert in outcome.alerts(for: incident) { modelContext.insert(alert) }
        incident.lat = outcome.location?.lat
        incident.lng = outcome.location?.lng
    }

    /// The bundled script for the classifier's pick, else the general one.
    private static func script(id: String) -> FirstAidScript? {
        let scripts = (try? ScriptLoader().loadBundledScripts()) ?? []
        return scripts.first { $0.id == id } ?? scripts.first { $0.id == "general" }
    }
}

#Preview {
    ListeningView(fallbackTranscript: "Help! Papa fell, his head is bleeding.")
        .modelContainer(for: [Incident.self, Alert.self, Contact.self, FirstAidScript.self], inMemory: true)
}
