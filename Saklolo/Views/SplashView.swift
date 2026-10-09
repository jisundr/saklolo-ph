import SwiftUI

/// A1: the plain splash shown on every open. Only the mark and the name: no
/// progress, timer or buttons, so it can never block an alert. It never waits
/// for the model; `RootView` moves on to Home after about a second.
/// The ground is `Palette.ground`, the same colour as the launch screen's `LaunchGround`.
struct SplashView: View {
    var body: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            SaklaloMark(size: 190)
            SaklaloWordmark(size: 64)
                // The wordmark is a fixed-size logo at 64pt; past accessibility1 it
                // would run off a 375pt-wide screen. VoiceOver still reads "Saklolo".
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(Metrics.gutter)
        .saklaloGround()
        // The mark is decorative; the screen reads as one element named "Saklolo".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Saklolo")
    }
}

#Preview("Dark") {
    SplashView()
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    SplashView()
        .preferredColorScheme(.light)
}
