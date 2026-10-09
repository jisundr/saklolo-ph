import SwiftUI
import SwiftData
import AVFAudio

/// Home (mockup E1 to E7): the red SAKLOLO button, a pill that says whether the phone can take
/// speech, at most one banner for the most severe problem, and a readiness line for the alert.
/// The button always works, whatever the status says.
struct HomeView: View {
    @EnvironmentObject private var loader: ModelLoader
    @Query private var contacts: [Contact]
    @StateObject private var location = LocationService()
    @State private var microphone = PermissionState(AVAudioApplication.shared.recordPermission)

    @State private var isListening = false
    @State private var showMenu = false
    @State private var showSetup = false
    @State private var showLog = false
    @State private var incident: Incident?
    /// Where the menu leads, acted on once the menu sheet has gone so two sheets never overlap.
    @State private var menuChoice: MenuChoice?

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    private func status(elapsed: TimeInterval = 0) -> HomeStatus {
        HomeStatus(
            model: loader.phase,
            microphone: microphone,
            location: PermissionState(location.authorizationStatus),
            contacts: contacts.count,
            elapsed: elapsed
        )
    }

    var body: some View {
        let status = status()
        NavigationStack {
            VStack(spacing: Metrics.gap) {
                topBar

                pill
                if let banner = status.banner {
                    InlineNotice(
                        banner.text,
                        systemImage: "xmark",
                        tone: .failure,
                        actionTitle: banner.actionTitle
                    ) { fix(banner.fix) }
                }

                Spacer(minLength: 64)

                SaklaloButton(isDimmed: status.ringsDimmed) {
                    // TODO: check-in prompt (TTS) and the Shortcut SMS + call, per brief step 1-3.
                    isListening = true
                }

                Spacer(minLength: 64)

                Text(status.lead)
                    .font(.body)
                    .foregroundStyle(Palette.textDim)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                ReadinessLine(items: status.readiness)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 8)
            .saklaloGround()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showMenu, onDismiss: openMenuChoice) {
                HomeMenu { choice in
                    menuChoice = choice
                    showMenu = false
                }
            }
            .sheet(isPresented: $showSetup) {
                SetupView()
            }
            .fullScreenCover(isPresented: $isListening) {
                ListeningView(fallbackTranscript: Self.cannedTranscript) { saved in
                    incident = saved
                    isListening = false
                }
            }
            .navigationDestination(item: $incident) { saved in
                IncidentView(incident: saved)
            }
            .navigationDestination(isPresented: $showLog) {
                IncidentLogView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Back from Settings: show what the person just changed.
            if phase == .active { refreshMicrophone() }
        }
        .onChange(of: showSetup) { _, isShown in
            if !isShown { refreshMicrophone() }
        }
    }

    /// Wordmark left, menu right (mockup `.bar-top`). Drawn here rather than in the navigation
    /// bar so the system does not wrap the wordmark in a toolbar background.
    private var topBar: some View {
        HStack {
            SaklaloWordmark()
                .foregroundStyle(Palette.text)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { showMenu = true } label: {
                Image(systemName: "gearshape")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Palette.textDim)
                    .frame(minWidth: Metrics.minTarget, minHeight: Metrics.minTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Menu")
        }
        .frame(minHeight: Metrics.minTarget)
    }

    /// The pill ticks each second while the model loads, so the clock moves.
    @ViewBuilder
    private var pill: some View {
        if loader.phase == .ready {
            pillView(status().pill)
        } else {
            TimelineView(.periodic(from: loader.startedAt, by: 1)) { context in
                pillView(status(elapsed: context.date.timeIntervalSince(loader.startedAt)).pill)
            }
        }
    }

    private func pillView(_ pill: HomeStatus.Pill) -> some View {
        StatusPill(pill.text, systemImage: pill.systemImage, tone: pill.tone)
            .monospacedDigit()
    }

    private func refreshMicrophone() {
        microphone = PermissionState(AVAudioApplication.shared.recordPermission)
    }

    private func fix(_ fix: HomeStatus.Fix) {
        switch fix {
        case .retryModel:
            Task { await loader.start() }
        case .openSettings:
            if let settings = URL(string: UIApplication.openSettingsURLString) { openURL(settings) }
        case .addContact:
            showSetup = true
        }
    }

    private func openMenuChoice() {
        switch menuChoice {
        case .contacts: showSetup = true
        case .incidents: showLog = true
        case nil: break
        }
        menuChoice = nil
    }

    /// The simulator has no microphone, so the chat runs on a fixed transcript.
    /// DEBUG builds read it from the `cannedTranscript` default (launch argument
    /// `-cannedTranscript "..."`) so other paths, such as alone mode, can be driven.
    // TODO: drop the canned transcript once WhisperKit works (spike 004).
    private static var cannedTranscript: String {
        let fallback = "Tulong! May sunog sa bahay namin"
        #if DEBUG
        if let override = UserDefaults.standard.string(forKey: "cannedTranscript"), !override.isEmpty {
            return override
        }
        #endif
        return fallback
    }
}

private enum MenuChoice {
    case contacts, incidents
}

/// E7: everything that is not the red button, in a bottom sheet sized to its rows.
/// Only Contacts and Past incidents exist so far; the mockup's other rows are deferred.
private struct HomeMenu: View {
    var onChoose: (MenuChoice) -> Void

    @State private var height: CGFloat = 220

    var body: some View {
        VStack(spacing: 0) {
            Text("Menu")
                .font(.title3.bold())
                .foregroundStyle(Palette.text)
                .padding(.top, 22)
                .padding(.bottom, 10)
                .accessibilityAddTraits(.isHeader)
            row("Contacts") { onChoose(.contacts) }
            Rectangle().fill(Palette.line).frame(height: 1)
            row("Past incidents") { onChoose(.incidents) }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 12)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
        .saklaloSheet()
    }

    private func row(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.textDim)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Palette.text)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
        .environmentObject(ModelLoader())
        .modelContainer(for: [Contact.self, Incident.self, Alert.self, FirstAidScript.self], inMemory: true)
}
