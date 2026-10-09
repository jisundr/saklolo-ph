import SwiftUI

/// Alone mode's dock at the bottom of the chat (G1). Nothing is sent at
/// understanding in alone mode; the alert goes when the person says so.
///
/// Minimal for now: one "I need help" button that fires at once. The
/// countdown bar and the "I'm okay" slide replace it with the alone mode
/// dock work, through these same two callbacks.
struct AloneDock: View {
    /// Send the alert now.
    var onFire: () -> Void
    /// The person is okay: end without sending (G5). Not offered yet.
    var onOkay: () -> Void = {}

    var body: some View {
        Button("I need help", action: onFire)
            .buttonStyle(SaklaloActionStyle())
            .padding(Metrics.gutter)
            .accessibilityHint("Sends the alert text to your contacts now.")
    }
}

#Preview {
    VStack {
        Spacer()
        AloneDock(onFire: {})
    }
    .saklaloGround()
}
