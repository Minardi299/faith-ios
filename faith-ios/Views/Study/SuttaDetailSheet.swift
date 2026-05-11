import SwiftUI
import SwiftData

/// Optional context passed to `SuttaDetailSheet` when a passage is opened
/// as part of a curated reading pathway. Drives the breadcrumb under the
/// top context strip and the "Next in this pathway" card at the bottom.
struct PathwayContext: Hashable {
    let pathwayID: String
    let pathwayTitle: String
    let stepIndex: Int   // 0-based
    let totalSteps: Int
}

struct SuttaDetailSheet: View {
    @Environment(\.theme) private var theme

    let passage: SuttaPassage
    let pathwayContext: PathwayContext?

    init(passage: SuttaPassage, pathwayContext: PathwayContext? = nil) {
        self.passage = passage
        self.pathwayContext = pathwayContext
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var audio = LiveAudioService.shared
    @StateObject private var listen = ListenQueueStore.shared
    @State private var glossTerm: GlossTerm? = nil
    @State private var showJournal: Bool = false
    @State private var showShare: Bool = false
    @State private var showQueue: Bool = false
    @State private var nextPassage: SuttaPassage? = nil

    var body: some View {
        ZStack(alignment: .top) {
            NatureSubstrate(tradition: passage.tradition, dimming: 0.18)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // Top strip occupies ~64pt; reserve scrollable space below it
                    Color.clear.frame(height: topStripReservedHeight)

                    if !leadInChips.isEmpty {
                        teachesRow
                    }

                    titleBlock

                    Divider().background(theme.border)
                        .padding(.horizontal, 22)

                    bodyBlock

                    if let nextRecommendation {
                        NextStepCard(
                            kind: nextRecommendation.kind,
                            title: nextRecommendation.passage.englishTitle,
                            code: nextRecommendation.passage.code,
                            tradition: passage.tradition
                        ) {
                            nextPassage = nextRecommendation.passage
                        }
                        .padding(.horizontal, 22)
                    }

                    Color.clear.frame(height: 110)
                }
            }
            .scrollIndicators(.hidden)

            TopContextStrip(
                tradition: passage.tradition,
                lengthLabel: lengthLabel,
                pathwayCrumb: pathwayCrumb,
                onClose: closeAction
            )

            VStack {
                Spacer()
                ReadingRail(
                    tradition: passage.tradition,
                    isPlayingThis: listen.isPlaying && listen.current?.passageID == passage.id,
                    hasQueue: listen.current != nil,
                    onListen: listenAction,
                    onPause: { listen.togglePlayPause() },
                    onStop:  { listen.stop() },
                    onQueue: { showQueue = true },
                    onNote:  { showJournal = true },
                    onShare: { showShare = true }
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 22)
            }
        }
        .presentationBackground(.clear)
        .sheet(item: $glossTerm) { term in
            GlossSheet(term: term, tradition: passage.tradition)
                .presentationDetents([.height(180)])
                .presentationBackground(.thinMaterial)
                .presentationBackgroundInteraction(.enabled)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showJournal) {
            JournalComposer(prefillSuttaID: passage.id) { text, suttaID in
                JournalStore.add(
                    text: text,
                    suttaID: suttaID,
                    in: context
                )
            }
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [shareString])
                .presentationDetents([.medium])
        }
        .sheet(item: $nextPassage) { p in
            SuttaDetailSheet(passage: p, pathwayContext: nextPathwayContext)
        }
        .sheet(isPresented: $showQueue) {
            QueueSheet().presentationDragIndicator(.visible)
        }
        .onDisappear {
            audio.stop()
            markPathwayRead()
        }
    }

    // MARK: - Reading body sections

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(passage.title)
                .font(BTFont.serif(28, weight: .light))
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(passage.englishTitle)
                .font(BTFont.serif(16, weight: .light, italic: true))
                .foregroundStyle(theme.inkSoft)
        }
        .padding(.horizontal, 22)
    }

    private var bodyBlock: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(passage.lines.enumerated()), id: \.offset) { _, line in
                SuttaLineView(line: line) { term in glossTerm = term }
            }
        }
        .padding(.horizontal, 22)
    }

    private var teachesRow: some View {
        HStack(spacing: 8) {
            Text("Teaches")
                .font(BTFont.ui(10.5, weight: .light))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(theme.inkMute)
            ForEach(Array(leadInChips.enumerated()), id: \.offset) { idx, chip in
                Text("·").foregroundStyle(theme.inkFaint)
                Text(chip)
                    .font(BTFont.ui(11.5, weight: .light))
                    .foregroundStyle(theme.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
    }

    // MARK: - Computed labels

    private var topStripReservedHeight: CGFloat {
        pathwayContext == nil ? 60 : 78
    }

    private var lengthLabel: String {
        let mins = max(1, passage.readingMinutes)
        switch passage.lengthTier {
        case .short:  return "Short · ~\(mins) min"
        case .medium: return "Medium · ~\(mins) min"
        case .long:   return "Long · ~\(mins) min"
        case .book:   return "Book · ~\(mins) min"
        }
    }

    private var pathwayCrumb: String? {
        guard let ctx = pathwayContext else { return nil }
        return "\(ctx.pathwayTitle) · \(ctx.stepIndex + 1) of \(ctx.totalSteps)"
    }

    private var leadInChips: [String] {
        let known: [(String, String)] = [
            ("core", "core"),
            ("intro", "intro"),
            ("verse", "verse"),
            ("koan", "kōan"),
            ("lojong", "lojong"),
            ("practice", "practice"),
        ]
        return known.compactMap { tag, label in
            passage.tags.contains(tag) ? label : nil
        }
    }

    // MARK: - Next-step recommendation

    fileprivate var nextRecommendation: NextRecommendation? {
        if let ctx = pathwayContext,
           let pathway = PathwayStore.shared.pathway(byID: ctx.pathwayID),
           ctx.stepIndex + 1 < pathway.steps.count,
           let nextPassage = CanonStore.shared.passage(byID: pathway.steps[ctx.stepIndex + 1].suttaID) {
            return NextRecommendation(kind: .pathway, passage: nextPassage)
        }
        if passage.isCore {
            let core = CanonStore.shared.coreReads()
            if let idx = core.firstIndex(where: { $0.id == passage.id }),
               idx + 1 < core.count {
                return NextRecommendation(kind: .core, passage: core[idx + 1])
            }
        }
        return nil
    }

    private var nextPathwayContext: PathwayContext? {
        guard let ctx = pathwayContext,
              let pathway = PathwayStore.shared.pathway(byID: ctx.pathwayID),
              ctx.stepIndex + 1 < pathway.steps.count
        else { return nil }
        return PathwayContext(
            pathwayID: pathway.id,
            pathwayTitle: pathway.title,
            stepIndex: ctx.stepIndex + 1,
            totalSteps: pathway.steps.count
        )
    }

    // MARK: - Actions

    private func closeAction() {
        audio.stop()
        markPathwayRead()
        dismiss()
    }

    private func markPathwayRead() {
        guard let ctx = pathwayContext else { return }
        PathwayProgressStore.shared.markRead(
            pathwayID: ctx.pathwayID,
            suttaID: passage.id
        )
    }

    private func listenAction() {
        if listen.isPlaying && listen.current?.passageID == passage.id {
            listen.togglePlayPause()
        } else {
            // Single-item queue so chat citations / pathway readers don't get
            // surprised by auto-advance to the next stage item.
            listen.play(passage: passage)
            // Mini-player will appear above the tab bar; no in-sheet sheet expansion.
        }
    }

    private var shareString: String {
        let head = "\(passage.code) — \(passage.englishTitle)"
        let body = passage.lines.prefix(3).map(\.text).joined(separator: " ")
        return "\(head)\n\n\(body)\n\nFrom Faith."
    }
}

// MARK: - Next-step recommendation (file-scope so the rail card can name the type)

enum NextStepKind { case pathway, core }

struct NextRecommendation {
    let kind: NextStepKind
    let passage: SuttaPassage
}

// MARK: - Top context strip

private struct TopContextStrip: View {
    @Environment(\.theme) private var theme

    let tradition: Tradition
    let lengthLabel: String
    let pathwayCrumb: String?
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(tradition.accent)
                            .frame(width: 7, height: 7)
                        Text(tradition.name)
                            .font(BTFont.ui(12, weight: .regular))
                            .foregroundStyle(theme.inkSoft)
                        Text("·").foregroundStyle(theme.inkFaint)
                        Text(lengthLabel)
                            .font(BTFont.ui(12, weight: .light))
                            .foregroundStyle(theme.inkMute)
                    }
                    if let pathwayCrumb {
                        Text(pathwayCrumb)
                            .font(BTFont.ui(11, weight: .light))
                            .foregroundStyle(theme.inkMute)
                    }
                }
                Spacer(minLength: 12)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(theme.inkSoft)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                        .background(Circle().fill(theme.border))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close reading")
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 10)

            Rectangle()
                .fill(theme.border)
                .frame(height: 0.5)
        }
        .background(
            LinearGradient(
                colors: [.black.opacity(0.32), .black.opacity(0.05), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(.container, edges: .top)
        )
    }
}

// MARK: - Reading rail (single bar; morphs between idle and audio states)

private struct ReadingRail: View {
    @Environment(\.theme) private var theme

    let tradition: Tradition
    let isPlayingThis: Bool
    let hasQueue: Bool
    let onListen: () -> Void
    let onPause: () -> Void
    let onStop:  () -> Void
    let onQueue: () -> Void
    let onNote:  () -> Void
    let onShare: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                if isPlayingThis {
                    pauseButton
                    stopButton
                } else {
                    listenButton
                }
                if hasQueue {
                    queueButton
                }
            }

            Spacer(minLength: 18)

            RailItem(icon: "square.and.pencil",
                     label: "Note this",
                     primary: false,
                     tradition: tradition,
                     action: onNote)

            Spacer(minLength: 14)

            RailItem(icon: "square.and.arrow.up",
                     label: "Share",
                     primary: false,
                     tradition: tradition,
                     action: onShare)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .glassEffect(.regular, in: Capsule())
        .animation(.easeOut(duration: 0.22), value: isPlayingThis)
    }

    private var listenButton: some View {
        RailItem(icon: "play.fill",
                 label: "Listen",
                 primary: true,
                 tradition: tradition,
                 action: onListen)
    }

    private var pauseButton: some View {
        RailItem(icon: "pause.fill",
                 label: "Pause",
                 primary: true,
                 tradition: tradition,
                 action: onPause)
    }

    private var stopButton: some View {
        Button(action: onStop) {
            Image(systemName: "stop.fill")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(theme.inkMute)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop")
    }

    private var queueButton: some View {
        Button(action: onQueue) {
            Image(systemName: "list.bullet")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(theme.inkSoft)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show queue")
    }
}

private struct RailItem: View {
    @Environment(\.theme) private var theme

    let icon: String
    let label: String
    let primary: Bool
    let tradition: Tradition
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: primary ? 13 : 13,
                                  weight: primary ? .medium : .light))
                Text(label)
                    .font(BTFont.ui(13, weight: primary ? .medium : .light))
            }
            .foregroundStyle(primary ? AnyShapeStyle(tradition.accent)
                                     : AnyShapeStyle(theme.inkSoft))
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reading line

private struct SuttaLineView: View {
    @Environment(\.theme) private var theme

    let line: SuttaLine
    let onGloss: (GlossTerm) -> Void

    var body: some View {
        Text(attributed)
            .font(BTFont.serif(18, weight: .light))
            .foregroundStyle(theme.ink)
            .lineSpacing(11)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var attributed: AttributedString {
        var s = AttributedString()
        if let n = line.number {
            var prefix = AttributedString("\(n)  ")
            prefix.font = BTFont.mono(10, weight: .light)
            prefix.foregroundColor = theme.inkFaint
            prefix.baselineOffset = 2
            s.append(prefix)
        }
        var body = AttributedString(line.text)
        for term in line.glossTerms {
            if let r = body.range(of: term.term) {
                body[r].font = BTFont.serif(18, weight: .light, italic: true)
            }
        }
        s.append(body)
        return s
    }
}

// MARK: - Glossary sheet (replaces dark-blur popover)

private struct GlossSheet: View {
    let term: GlossTerm
    let tradition: Tradition

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle().fill(tradition.accent).frame(width: 6, height: 6)
                Text(term.term)
                    .font(BTFont.serif(22, weight: .light, italic: true))
                    .foregroundStyle(.primary)
            }
            Text(term.gloss)
                .font(BTFont.ui(14, weight: .regular))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
    }
}

// MARK: - Next step card

private struct NextStepCard: View {
    @Environment(\.theme) private var theme

    let kind: NextStepKind
    let title: String
    let code: String
    let tradition: Tradition
    let onTap: () -> Void

    private var label: String {
        switch kind {
        case .pathway: return "Next in this pathway"
        case .core:    return "Next core read"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle().fill(tradition.accent).frame(width: 5, height: 5)
                        Text(label.uppercased())
                            .font(BTFont.ui(10.5, weight: .light))
                            .tracking(1.5)
                            .foregroundStyle(theme.inkMute)
                    }
                    Text(title)
                        .font(BTFont.serif(17, weight: .light))
                        .foregroundStyle(theme.ink)
                        .multilineTextAlignment(.leading)
                    Text(code)
                        .font(BTFont.mono(11, weight: .light))
                        .foregroundStyle(theme.inkMute)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(tradition.accent.opacity(0.85))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Share sheet bridge

/// UIKit share sheet bridge.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension GlossTerm: Identifiable {
    var id: String { term }
}
