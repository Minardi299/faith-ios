import SwiftUI

struct SendBlessingFlow: View {
    @Environment(\.theme) private var theme

    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var step: Int = 0
    @State private var recipient: String = ""
    @State private var passage: SuttaPassage = CanonStore.shared.passage(byID: "dhp1-20")
                                ?? CanonStore.shared.entries.first
                                ?? SuttaPassage(id: "x", code: "—", title: "—", englishTitle: "—",
                                                tradition: .zen, collection: "—", collectionID: "—",
                                                lines: [], isStub: true)
    @State private var aesthetic: Aesthetic = .stone
    @State private var note: String = ""

    /// A small curated list shown in the picker — full canon is too large to scroll.
    private var pickableSuttas: [SuttaPassage] {
        let store = CanonStore.shared
        let ids = ["mn21", "mn10", "dhp1-20", "snp1.8", "ud1.10",
                   "MH_HEART", "MH_DIAM_KEY", "VJ_37_1", "ZEN_MUMON_7"]
        return ids.compactMap { store.passage(byID: $0) }
    }

    enum Aesthetic: String, CaseIterable, Identifiable {
        case stone, washi, ink
        var id: String { rawValue }
        var label: String {
            switch self {
            case .stone: "Stone"; case .washi: "Washi"; case .ink: "Ink"
            }
        }
    }

    var body: some View {
        ZStack {
            NatureSubstrate(tradition: session.user.tradition, dimming: 0.2)

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Send a blessing").eyebrow()
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(theme.ink)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular, in: Circle())
                }

                Group {
                    switch step {
                    case 0: recipientStep
                    case 1: passageStep
                    case 2: noteStep
                    case 3: aestheticStep
                    default: previewStep
                    }
                }
                .id(step)
                .transition(.opacity)

                Spacer()

                navBar
                    .padding(.bottom, 22)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .animation(.easeInOut(duration: 0.4), value: step)
        }
        .presentationDetents([.large])
        .presentationBackground(.clear)
    }

    @ViewBuilder
    private var navBar: some View {
        HStack {
            if step > 0 {
                Button { step -= 1 } label: {
                    Text("Back")
                        .font(BTFont.serif(13, weight: .light, italic: true))
                        .foregroundStyle(theme.inkMute)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if step >= 4 {
                let card = BlessingCardPreview(
                    passage: passage,
                    aesthetic: aesthetic,
                    recipient: recipient,
                    note: note
                )
                .frame(width: 340, height: 480)

                let renderer = ImageRenderer(content: card)
                let _ = (renderer.scale = 3)
                if let uiImage = renderer.uiImage {
                    let image = Image(uiImage: uiImage)
                    ShareLink(
                        item: image,
                        preview: SharePreview("A blessing for \(recipient.isEmpty ? "you" : recipient)",
                                              image: image)
                    ) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 13, weight: .light))
                            Text("Send")
                                .font(BTFont.ui(14, weight: .regular))
                        }
                        .foregroundStyle(theme.ink)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .glassEffect(.regular, in: Capsule())
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        // dismiss after share — but only after the user actually shares.
                    })
                }
            } else {
                Button { step += 1 } label: {
                    Text("Continue")
                        .font(BTFont.ui(14, weight: .regular))
                        .foregroundStyle(theme.ink)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 14)
                        .frame(minHeight: 48)
                        .contentShape(Capsule())
                        .glassEffect(.regular, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(step == 0 && recipient.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var recipientStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Who is this for?")
                .font(BTFont.serif(24, weight: .light))
                .foregroundStyle(theme.ink)
            TextField("A name", text: $recipient)
                .font(BTFont.serif(18, weight: .light))
                .foregroundStyle(theme.ink)
                .padding(14)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var passageStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a passage")
                .font(BTFont.serif(22, weight: .light))
                .foregroundStyle(theme.ink)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(pickableSuttas) { p in
                        Button { passage = p } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(p.code + " · " + p.englishTitle)
                                    .font(BTFont.serif(13.5, weight: .light, italic: true))
                                    .foregroundStyle(theme.inkSoft)
                                Text(p.lines.first?.text ?? "")
                                    .font(BTFont.serif(15, weight: .light))
                                    .foregroundStyle(theme.ink)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .topTrailing) {
                            if passage.id == p.id {
                                Circle().fill(p.tradition.accent).frame(width: 6, height: 6)
                                    .padding(8)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 360)
        }
    }

    private var noteStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("A small note")
                .font(BTFont.serif(22, weight: .light))
                .foregroundStyle(theme.ink)
            ZStack(alignment: .topLeading) {
                if note.isEmpty {
                    Text("Optional. A line, not an essay.")
                        .font(BTFont.serif(15, weight: .light, italic: true))
                        .foregroundStyle(theme.inkMute)
                        .padding(14)
                }
                TextEditor(text: $note)
                    .scrollContentBackground(.hidden)
                    .font(BTFont.serif(15, weight: .light))
                    .foregroundStyle(theme.ink)
                    .padding(8)
            }
            .frame(minHeight: 140)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var aestheticStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a card")
                .font(BTFont.serif(22, weight: .light))
                .foregroundStyle(theme.ink)
            HStack(spacing: 10) {
                ForEach(Aesthetic.allCases) { a in
                    Button { aesthetic = a } label: {
                        VStack(spacing: 6) {
                            cardPreview(a)
                                .frame(height: 120)
                            Text(a.label)
                                .font(BTFont.serif(12, weight: .light, italic: true))
                                .foregroundStyle(.white.opacity(aesthetic == a ? 0.9 : 0.55))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var previewStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(BTFont.serif(22, weight: .light))
                .foregroundStyle(theme.ink)
            BlessingCardPreview(passage: passage, aesthetic: aesthetic, recipient: recipient, note: note)
                .frame(maxWidth: .infinity)
                .frame(height: 360)
        }
    }

    @ViewBuilder
    private func cardPreview(_ a: Aesthetic) -> some View {
        switch a {
        case .stone:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x1F2025), Color(hex: 0x0A0A0A)], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.border, lineWidth: 0.5))
        case .washi:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: 0xF5F0E8))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.inkMute, lineWidth: 0.5))
        case .ink:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black)
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.inkFaint, lineWidth: 0.5))
        }
    }
}

struct BlessingCardPreview: View {
    @Environment(\.theme) private var theme

    let passage: SuttaPassage
    let aesthetic: SendBlessingFlow.Aesthetic
    let recipient: String
    let note: String

    var body: some View {
        ZStack {
            switch aesthetic {
            case .stone:
                LinearGradient(colors: [Color(hex: 0x1F2025), Color(hex: 0x0A0A0A)], startPoint: .top, endPoint: .bottom)
            case .washi:
                Color(hex: 0xF5F0E8)
            case .ink:
                Color.black
            }
            VStack(alignment: .leading, spacing: 14) {
                Text("FOR " + recipient.uppercased())
                    .font(BTFont.ui(10.5, weight: .light))
                    .tracking(2)
                    .foregroundStyle(textColor.opacity(0.55))
                Text(passage.lines.first?.text ?? "")
                    .font(BTFont.serif(20, weight: .light))
                    .foregroundStyle(textColor.opacity(0.95))
                    .lineSpacing(5)
                Spacer()
                if !note.isEmpty {
                    Text(note)
                        .font(BTFont.serif(13, weight: .light, italic: true))
                        .foregroundStyle(textColor.opacity(0.65))
                }
                Text(passage.code + " · " + passage.englishTitle)
                    .font(BTFont.serif(11.5, weight: .light, italic: true))
                    .foregroundStyle(textColor.opacity(0.5))
            }
            .padding(22)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(theme.border, lineWidth: 0.5))
    }

    private var textColor: Color {
        aesthetic == .washi ? .black : .white
    }
}
