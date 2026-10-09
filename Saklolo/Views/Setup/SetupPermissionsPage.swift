import SwiftUI
import AVFAudio
import CoreLocation

/// B3: microphone first, then location (When In Use). Each row gives its reason before the
/// system prompt. Denied permissions never block finishing setup.
struct SetupPermissionsPage: View {
    var finishTitle: String = "Continue"
    var onFinish: () -> Void

    @StateObject private var location = LocationService()
    @State private var microphone: AVAudioApplication.recordPermission = AVAudioApplication.shared.recordPermission
    @State private var isAsking = false
    @Environment(\.scenePhase) private var scenePhase

    private var needsAsking: Bool {
        microphone == .undetermined || location.authorizationStatus == .notDetermined
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.gap) {
            SetupPageTitle(title: "Allow what we need")

            PermissionRow(
                symbol: "mic.fill",
                title: "Microphone",
                reason: "To hear what happened.",
                deniedNote: "Voice won't work. The red button still does.",
                state: PermissionState(microphone)
            )
            PermissionRow(
                symbol: "location.fill",
                title: "Location",
                reason: "To send your GPS to your contacts.",
                deniedNote: "The text goes without a map link.",
                state: PermissionState(location.authorizationStatus)
            )

            Spacer()

            if needsAsking {
                Button("Allow") { Task { await askAll() } }
                    .buttonStyle(SaklaloActionStyle())
                    .disabled(isAsking)
                Button("Not now", action: onFinish)
                    .frame(maxWidth: .infinity, minHeight: Metrics.minTarget)
                    .foregroundStyle(Palette.textDim)
            } else {
                Button(finishTitle, action: onFinish)
                    .buttonStyle(SaklaloActionStyle())
            }
            Text("You can change this later in Settings.")
                .font(Typography.finePrint)
                .foregroundStyle(Palette.textDim)
                .frame(maxWidth: .infinity)
        }
        .onChange(of: scenePhase) { _, phase in
            // Back from Settings: show the current microphone state.
            if phase == .active { microphone = AVAudioApplication.shared.recordPermission }
        }
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
                .foregroundStyle(Palette.alarmText)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title).font(.headline)
                    switch state {
                    case .on: Text("On").font(.headline).foregroundStyle(Palette.delivered)
                    case .off: Text("Off").font(.headline).foregroundStyle(Palette.alarmText)
                    case .notAsked: EmptyView()
                    }
                }
                Text(state == .off ? deniedNote : reason)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textDim)
                if state == .off, let settings = URL(string: UIApplication.openSettingsURLString) {
                    Button("Open Settings") { openURL(settings) }
                        .font(.subheadline.bold())
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Metrics.chipRadius, style: .continuous)
                .fill(Palette.groundRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.chipRadius, style: .continuous)
                .strokeBorder(Palette.line, lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SetupPermissionsPage {}
        .padding()
        .saklaloGround()
}
