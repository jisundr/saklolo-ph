import SwiftUI

/// E2: a thin strip under Home that says how the listening model is doing.
/// The alert never waits on the model, so this only informs; it hides itself
/// once the model is ready.
struct ModelStatusStrip: View {
    @EnvironmentObject private var loader: ModelLoader

    var body: some View {
        if loader.phase != .ready {
            HStack(spacing: Metrics.gap) {
                icon
                    .frame(width: 20, height: 20)
                Text(message)
                    .font(Typography.finePrint)
                    .foregroundStyle(loader.phase == .failed ? Palette.alarmText : Palette.textDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if loader.phase == .failed {
                    Button("Try again") { Task { await loader.start() } }
                        .font(Typography.finePrint.weight(.semibold))
                        .frame(minHeight: Metrics.minTarget)
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: Metrics.minTarget)
            .background(Palette.groundRaised)
            .overlay(alignment: .top) {
                Rectangle().fill(Palette.line).frame(height: 1)
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch loader.phase {
        case .downloading(let fraction):
            ProgressView(value: fraction)
                .progressViewStyle(.circular)
                .tint(Palette.signalBlue)
        case .compiling, .testing:
            ProgressView()
                .controlSize(.small)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Palette.alarmText)
        case .ready:
            EmptyView()
        }
    }

    private var message: String {
        switch loader.phase {
        case .downloading(let fraction):
            "Getting the listening model, \(Int(fraction * 100))%. The alert already works."
        case .compiling, .testing:
            "Preparing the listening model. The alert already works."
        case .failed:
            "The listening model isn't ready. The alert still works."
        case .ready:
            ""
        }
    }
}

#Preview {
    VStack {
        Spacer()
        ModelStatusStrip()
    }
    .environmentObject(ModelLoader())
}
