import SwiftUI
import SwiftData
import AVFAudio
import CoreLocation

/// B3: microphone first, then location (When In Use). Each row gives its reason before the
/// system prompt. Denied permissions never block finishing setup.
struct SetupPermissionsPage: View {
    var finishTitle: String = "Continue"
    var onFinish: () -> Void

    @StateObject private var location = LocationService()
    @Query private var contacts: [Contact]
    @State private var microphone: AVAudioApplication.recordPermission = AVAudioApplication.shared.recordPermission
    @State private var isAsking = false
    @Environment(\.scenePhase) private var scenePhase

    private var needsAsking: Bool {
        microphone == .undetermined || location.authorizationStatus == .notDetermined
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.gap) {
            // Title and rows scroll so nothing truncates at the largest text sizes;
            // the readiness line and buttons stay pinned at the bottom.
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.gap) {
                    SetupPageTitle(title: "Allow what we need")

                    PermissionRow(
                        symbol: "mic",
                        title: "Microphone",
                        reason: "To hear what happened.",
                        deniedNote: "Voice won’t work. The red button still does.",
                        state: PermissionState(microphone)
                    )
                    PermissionRow(
                        symbol: "mappin.and.ellipse",
                        title: "Location",
                        reason: "To send your GPS to your contacts.",
                        deniedNote: "The text goes without a map link.",
                        state: PermissionState(location.authorizationStatus)
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)

            if !needsAsking {
                ReadinessLine(items: readiness)
            }

            if needsAsking {
                Button("Allow") { Task { await askAll() } }
                    .buttonStyle(SaklaloActionStyle())
                    .disabled(isAsking)
                Button(action: onFinish) {
                    Text("Not now")
                        .foregroundStyle(Palette.textDim)
                        .frame(maxWidth: .infinity, minHeight: Metrics.minTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Button(finishTitle, action: onFinish)
                    .buttonStyle(SaklaloActionStyle())
            }
            Text("You can change this later in Settings.")
                .font(Typography.finePrint)
                .foregroundStyle(Palette.textDim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
        .onChange(of: scenePhase) { _, phase in
            // Back from Settings: show the current microphone state.
            if phase == .active { microphone = AVAudioApplication.shared.recordPermission }
        }
    }

    /// B5: what will work once setup ends.
    private var readiness: [ReadinessItem] {
        [
            ReadinessItem(label: "Mic", isOK: PermissionState(microphone) == .on),
            ReadinessItem(label: "GPS", isOK: PermissionState(location.authorizationStatus) == .on),
            ReadinessItem(
                label: contacts.count == 1 ? "1 contact ready" : "\(contacts.count) contacts ready",
                isOK: !contacts.isEmpty
            ),
        ]
    }

    /// Microphone, then location, one system prompt at a time.
    private func askAll() async {
        isAsking = true
        defer { isAsking = false }
        if microphone == .undetermined {
            _ = await AVAudioApplication.requestRecordPermission()
            microphone = AVAudioApplication.shared.recordPermission
        }
        if location.authorizationStatus == .notDetermined {
            location.requestPermission()
        }
    }
}

enum PermissionState: Equatable {
    case notAsked, on, off

    init(_ microphone: AVAudioApplication.recordPermission) {
        switch microphone {
        case .granted: self = .on
        case .denied: self = .off
        default: self = .notAsked
        }
    }

    init(_ location: CLAuthorizationStatus) {
        switch location {
        case .authorizedWhenInUse, .authorizedAlways: self = .on
        case .denied, .restricted: self = .off
        default: self = .notAsked
        }
    }
}

/// One B3 row (mockup `.rowbox`): a dim symbol, the name, its state once asked, and the reason.
/// "Off" is alarm text with the denied note and a Settings link; "On" is plain text.
private struct PermissionRow: View {
    let symbol: String
    let title: String
    let reason: String
    let deniedNote: String
    let state: PermissionState

    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.gap) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Palette.textDim)
                .frame(width: 26)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 10) {
                    Text(title)
                        .font(.body.weight(.bold))
                        .foregroundStyle(Palette.text)
                    switch state {
                    case .on:
                        Text("On").font(.body.weight(.bold)).foregroundStyle(Palette.text)
                    case .off:
                        Text("Off").font(.body.weight(.bold)).foregroundStyle(Palette.alarmText)
                    case .notAsked:
                        EmptyView()
                    }
                }
                if state != .on {
                    Text(state == .off ? deniedNote : reason)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if state == .off, let settings = URL(string: UIApplication.openSettingsURLString) {
                    Button { openURL(settings) } label: {
                        Text("Open Settings")
                            .font(.subheadline.weight(.bold))
                            .underline()
                            .foregroundStyle(Palette.text)
                            .frame(minHeight: Metrics.minTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, -6)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                .fill(Palette.groundRaised)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SetupPermissionsPage {}
        .padding()
        .saklaloGround()
        .modelContainer(for: Contact.self, inMemory: true)
}
