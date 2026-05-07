import SwiftUI

struct QuizView: View {
    @Environment(\.theme) private var theme

    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var questions: [QuizQuestion] = []
    @State private var currentIndex: Int = 0
    @State private var revealed: Bool = false
    @State private var pickedIndex: Int? = nil
    @State private var score: Int = 0
    @State private var openSutta: SuttaPassage?
    @State private var traditionFilter: Tradition? = nil
    @State private var phase: Phase = .intro

    enum Phase { case intro, playing, finished }

    var body: some View {
        ZStack(alignment: .top) {
            NatureSubstrate(tradition: traditionFilter ?? session.user.tradition, dimming: 0.18)

            VStack(spacing: 0) {
                header
                Group {
                    switch phase {
                    case .intro:    intro
                    case .playing:  playing
                    case .finished: finished
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 22)
            }
        }
        .presentationDetents([.large])
        .presentationBackground(.clear)
        .sheet(item: $openSutta) { p in
            SuttaDetailSheet(passage: p)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Quiz").eyebrow()
                Text(headerTitle)
                    .font(BTFont.serif(28, weight: .light))
                    .foregroundStyle(theme.ink)
            }
            Spacer()
            if phase == .playing {
                Text("\(currentIndex + 1) / \(questions.count)")
                    .font(BTFont.mono(12, weight: .light))
                    .foregroundStyle(theme.inkMute)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: Capsule())
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(theme.ink)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular, in: Circle())
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
    }

    private var headerTitle: String {
        switch phase {
        case .intro:    "Test what you know"
        case .playing:  "Question"
        case .finished: "Result"
        }
    }

    private var intro: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("Ten questions, drawn from across the canon.")
                .font(BTFont.serif(18, weight: .light, italic: true))
                .foregroundStyle(theme.inkSoft)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                questions = QuizStore.shared.pickRound(10, tradition: traditionFilter)
                currentIndex = 0
                score = 0
                revealed = false
                pickedIndex = nil
                phase = .playing
            } label: {
                Text("Begin")
                    .font(BTFont.ui(15, weight: .regular))
                    .foregroundStyle(theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 22)
        }
    }

    private var playing: some View {
        let q = (questions.indices.contains(currentIndex) ? questions[currentIndex] : nil) ?? questions.first!
        return VStack(alignment: .leading, spacing: 18) {
            Spacer().frame(height: 4)

            Text(q.prompt)
                .font(BTFont.serif(20, weight: .light))
                .foregroundStyle(theme.ink)
                .lineSpacing(5)

            VStack(spacing: 8) {
                ForEach(Array(q.choices.enumerated()), id: \.offset) { idx, choice in
                    choiceRow(choice: choice, index: idx, q: q)
                }
            }

            Spacer()

            if revealed {
                VStack(alignment: .leading, spacing: 12) {
                    Text(q.explanation)
                        .font(BTFont.serif(14, weight: .light, italic: true))
                        .foregroundStyle(theme.inkSoft)
                        .lineSpacing(4)

                    if let p = CanonStore.shared.passage(byID: q.passageID) {
                        CitationPill(cite: SuttaCite(code: p.code,
                                                     englishTitle: p.englishTitle,
                                                     suttaID: p.id),
                                     onTap: { _ in openSutta = p })
                    }

                    Button {
                        if currentIndex == questions.count - 1 {
                            phase = .finished
                        } else {
                            currentIndex += 1
                            revealed = false
                            pickedIndex = nil
                        }
                    } label: {
                        Text(currentIndex == questions.count - 1 ? "Finish" : "Next")
                            .font(BTFont.ui(15, weight: .regular))
                            .foregroundStyle(theme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.bottom, 22)
            }
        }
    }

    private var finished: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("\(score) / \(questions.count)")
                .font(BTFont.serif(72, weight: .ultraLight))
                .foregroundStyle(theme.ink)
                .contentTransition(.numericText())
            Text(scoreBlurb)
                .font(BTFont.serif(15, weight: .light, italic: true))
                .foregroundStyle(theme.inkSoft)
                .multilineTextAlignment(.center)
            Spacer()

            HStack(spacing: 10) {
                Button {
                    phase = .intro
                } label: {
                    Text("Choose again")
                        .font(BTFont.ui(13, weight: .light))
                        .foregroundStyle(theme.ink)
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .glassEffect(.regular, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    questions = QuizStore.shared.pickRound(10, tradition: traditionFilter)
                    currentIndex = 0
                    score = 0
                    revealed = false
                    pickedIndex = nil
                    phase = .playing
                } label: {
                    Text("Play again")
                        .font(BTFont.ui(13, weight: .regular))
                        .foregroundStyle(theme.ink)
                        .padding(.horizontal, 22).padding(.vertical, 12)
                        .glassEffect(.regular, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 22)
        }
    }

    private var scoreBlurb: String {
        let pct = Double(score) / Double(max(1, questions.count))
        if pct >= 0.9 { return "Mastery — the texts have entered you." }
        if pct >= 0.7 { return "Steady — much is held." }
        if pct >= 0.5 { return "Good ground — keep returning." }
        return "Beginner's mind — return to the readings."
    }

    @ViewBuilder
    private func choiceRow(choice: String, index: Int, q: QuizQuestion) -> some View {
        let isCorrect = index == q.correctIndex
        let highlighted = revealed && (isCorrect || pickedIndex == index)
        let accent = q.traditionEnum?.accent ?? .white
        Button {
            guard !revealed else { return }
            pickedIndex = index
            revealed = true
            if isCorrect { score += 1 }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Circle()
                    .strokeBorder(theme.inkMute, lineWidth: 0.5)
                    .background(
                        Circle().fill(highlighted ? (isCorrect ? accent : theme.border)
                                                   : Color.clear)
                    )
                    .frame(width: 12, height: 12)
                Text(choice)
                    .font(BTFont.serif(15, weight: .light))
                    .foregroundStyle(.white.opacity(highlighted ? 0.95 : 0.85))
                    .multilineTextAlignment(.leading)
                Spacer()
                if revealed && isCorrect {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(accent.opacity(0.95))
                }
            }
            .padding(14)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func pill(label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(BTFont.ui(11.5, weight: .light))
                .foregroundStyle(.white.opacity(isOn ? 0.95 : 0.55))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .glassEffect(.regular, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
