#if DEBUG
import SwiftUI

/// Every mockup component on one scrolling page, for checking against docs/mockup by eye.
struct ThemeGallery: View {
    var body: some View {
        ScrollView {
            ThemeGalleryContent()
        }
        .saklaloGround()
    }
}

/// The gallery without the scroll view, so it can also be rendered to an image.
struct ThemeGalleryContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.gap) {
            HStack {
                SaklaloWordmark()
                Spacer()
                Image(systemName: "gearshape").font(.title2)
            }
            HStack(spacing: 10) {
                SaklaloMark(size: 64)
                SaklaloWordmark(size: 40)
            }

            section("Pills")
            HStack {
                StatusPill("Ready", systemImage: "checkmark")
                StatusPill("Microphone off", systemImage: "xmark", tone: .fail)
            }
            StatusPill("Text sent", systemImage: "checkmark", tone: .done)

            section("Readiness")
            ReadinessLine(items: [
                ReadinessItem(label: "Mic", isOK: false),
                ReadinessItem(label: "GPS", isOK: true),
                ReadinessItem(label: "3 contacts ready", isOK: true),
            ])

            section("Notices")
            InlineNotice("Listening isn\u{2019}t ready.", systemImage: "xmark", tone: .failure, actionTitle: "Try again") {}
            InlineNotice("The phone can\u{2019}t hear you right now.", systemImage: "xmark", tone: .failure)
            InlineNotice("Kuya Ben gets the call. Tita Lina gets a text.", systemImage: "info.circle", tone: .info)
            DeliveredBanner("I\u{2019}ve told Kuya Ben, Tita Lina and Ruel \u{00B7} 7:42 PM")
            SentTextBox("SAKLOLO: Papa fell, his head is bleeding, he is awake. 7:42pm.")

            section("Chat")
            ChatBubble("What happened?", role: .incoming)
            ChatBubble("Papa fell, his head is bleeding", role: .outgoing, large: true)
            TypingDots()

            section("Contacts")
            ForEach(1...5, id: \.self) { position in
                ContactChip(
                    position: position,
                    name: ["Kuya Ben", "Tita Lina", "Ruel", "Ate Joy", "Lolo"][position - 1],
                    caption: position == 1 ? "gets the call + text" : "text",
                    relation: "Brother",
                    trailing: position == 1 ? AnyView(Image(systemName: "line.3.horizontal").foregroundStyle(Palette.textDim)) : nil
                )
            }

            section("Fields and cards")
            Text("Maria Santos").saklaloField(label: "Name")
            SectionCard(title: "Summary") {
                Text("Papa fell and his head is bleeding.")
            }
            SaklaloProgressBar(value: 0.35)
            SaklaloProgressBar(value: 0.6, thick: true)
            Text(ModelStateText.text(for: .compiling, elapsed: 72, compact: true) ?? "")
                .font(.subheadline).foregroundStyle(Palette.textDim)

            section("Buttons")
            Button("Start first aid") {}.buttonStyle(SaklaloActionStyle())
            HStack {
                Button("Back") {}.buttonStyle(SaklaloActionStyle(kind: .secondary, size: .small))
                Button("Repeat") {}.buttonStyle(SaklaloActionStyle(kind: .secondary, size: .small))
            }
            HStack(spacing: 80) {
                SaklaloButton {}.scaleEffect(0.5).frame(width: 120, height: 160)
                SaklaloButton(isDimmed: true) {}.scaleEffect(0.5).frame(width: 120, height: 160)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(Metrics.gutter)
        .saklaloGround()
    }

    private func section(_ title: String) -> some View {
        Text(title)
            .font(Typography.signage(20, weight: .bold, relativeTo: .headline))
            .textCase(.uppercase)
            .foregroundStyle(Palette.textDim)
            .padding(.top, 8)
    }
}

#Preview("Components, dark") {
    ThemeGallery().preferredColorScheme(.dark)
}

#Preview("Components, light") {
    ThemeGallery().preferredColorScheme(.light)
}
#endif
