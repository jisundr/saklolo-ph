import SwiftUI

/// A1: the plain splash shown on every open. It never waits for the model;
/// `RootView` moves on to Home after about a second.
struct SplashView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            ZStack {
                Circle().strokeBorder(Palette.signalOrange, lineWidth: 8)
                Circle().strokeBorder(Palette.signalYellow, lineWidth: 8).padding(24)
                Circle().strokeBorder(Palette.signalBlue, lineWidth: 8).padding(48)
                Circle().fill(Palette.signalRed.opacity(0.9)).padding(72)
            }
            .frame(width: 200, height: 200)
            .accessibilityHidden(true)

            Text("SAKLOLO")
                .font(Typography.signage(46, relativeTo: .largeTitle))
                .tracking(1.2)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(Metrics.gutter)
        .saklaloGround()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Saklolo")
    }
}

#Preview {
    SplashView()
}
