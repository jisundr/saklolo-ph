import SwiftUI
import SwiftData

/// The one chat screen the red button opens (F1 to F3, F5). The voice orb sits
/// at the bottom; the transcript becomes the person's bubble; fixed replies
/// say who and what happened; the first-aid guide opens as a sheet over it.
/// Nothing is sent at the tap. Classification only picks the script and mode.
///
/// Kept the `ListeningView` name and init so Home does not change (plan flag 7).
struct ListeningView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [ChatMessage] = [.saklolo(ChatReplies.opening)]
    @State private var stage: Stage = .listening(.waiting)
    @State private var level: Float = 0
    @State private var startedAt = Date.now
    @State private var incident: Incident?
    @State private var script: FirstAidScript?
    @State private var showGuide = false
    @State private var cancelled = false

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
    /// Called once, when the session ends (Done), with the saved incident.
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
                GuideView(script: script)
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
            if let incident {
                Button("Done") { onClassified(incident) }
                    .font(.body.bold())
                    .frame(minHeight: Metrics.minTarget)
            } else {
                Button {
                    cancel()
                } label: {
                    Label("Cancel", systemImage: "xmark")
                }
                .font(.body)
                .foregroundStyle(Palette.textDim)
                .frame(minHeight: Metrics.minTarget)
                .accessibilityHint("Stops listening. Nothing is saved or sent.")
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
            if script != nil, !showGuide {
                Button("Start first aid") { showGuide = true }
                    .buttonStyle(SaklaloActionStyle())
                    .padding(Metrics.gutter)
            }
        }
    }

    // MARK: - Session

    private func cancel() {
        // The view's task is cancelled when it goes away, which stops the
        // recorder; the flag makes sure nothing is saved even if Whisper or
        // the classifier is already past its last cancellation point.
        cancelled = true
        dismiss()
    }

    private var isStopped: Bool { cancelled || Task.isCancelled }

    private func runSession() async {
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
        script = Self.script(id: result.scriptID)
        stage = .done

        for reply in ChatReplies.replies(for: result) {
            try? await Task.sleep(for: .milliseconds(400))
            guard !isStopped else { return }
            messages.append(.saklolo(reply))
        }

        // Guide and alone both open the steps after a short pause (F3 to H1).
        try? await Task.sleep(for: .seconds(2))
        guard !isStopped, script != nil else { return }
        showGuide = true
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
