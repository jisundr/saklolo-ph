import SwiftUI

/// Guide: one big first-aid step at a time, Next/Repeat, "Na-text na..." banner.
/// Per the brief's Screens table and MVP "Guide mode" requirement.
struct GuideView: View {
    let script: FirstAidScript
    @State private var stepIndex = 0
    @State private var contactsNotifiedBanner = true

    var body: some View {
        VStack(spacing: 24) {
            if contactsNotifiedBanner {
                Text("Na-text na sina Kuya at Tita")
                    .font(.caption)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
            }

            Spacer()

            Text(script.steps.indices.contains(stepIndex) ? script.steps[stepIndex] : "Tapos na ang mga hakbang.")
                .font(.system(size: 28, weight: .semibold))
                .multilineTextAlignment(.center)
                .padding()

            Spacer()

            HStack(spacing: 16) {
                Button("Ulitin") {
                    // TODO: re-speak current step via AVSpeechSynthesizer
                }
                .buttonStyle(.bordered)

                Button("Next") {
                    if stepIndex < script.steps.count - 1 {
                        stepIndex += 1
                        // TODO: speak next step via AVSpeechSynthesizer
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .font(.title3)
        }
        .padding()
        .task {
            // TODO: listen for voice "okay"/"tapos na" (advance) or "ulitin" (repeat)
            // as an alternative to the buttons, per brief's Guide mode.
        }
    }
}

#Preview {
    GuideView(script: FirstAidScript(
        id: "fall",
        title: "Fall, can't move",
        keywords: ["nahulog", "nadulas"],
        steps: ["Huwag galawin.", "Panatilihing tahimik ang ulo.", "Painitin.", "Bantayan ang paghinga."],
        source: "Philippine Red Cross — Basic First Aid"
    ))
}
