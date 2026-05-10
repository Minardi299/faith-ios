import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(DailyPassageStore.self) private var dailyPassage
    @EnvironmentObject private var canon: CanonStore
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @Query private var completions: [DayCompletion]
    @Binding var selectedTab: AppTab
    @State private var showingPassage: SuttaPassage?

    private var progress: ProgressStore { ProgressStore(context: context) }
    private var todayKey: String { DayCompletion.key(for: .now) }
    private var today: DayCompletion? { completions.first { $0.dayKey == todayKey } }
    private var passage: SuttaPassage? { dailyPassage.passage(for: .now) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerBlock
                    weekStripLink
                    progressSection
                    sitCard
                    passageCard
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(theme.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { EmptyView() } }
            .profileToolbar()
            .sheet(item: $showingPassage) { p in
                NavigationStack { SuttaDetailSheet(passage: p) }
            }
            .onAppear { progress.ensureToday() }
            .task(id: today?.doneCount) { progress.pushToWidget() }
            .task(id: passage?.id) {
                if let p = passage {
                    let snippet = p.lines.first?.text ?? p.englishTitle
                    SharedProgress.writePassage(
                        id: p.id, code: p.code, title: p.englishTitle, snippet: snippet
                    )
                }
            }
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrowText)
                .font(.caption2.weight(.semibold))
                .tracking(2.4)
                .textCase(.uppercase)
                .foregroundStyle(theme.inkMute)
            Text("\(Text("May the day\n").foregroundStyle(theme.ink))\(Text("arrive gently.").italic().foregroundColor(theme.secondary))")
                .font(.system(size: 36, weight: .regular, design: .serif))
                .lineSpacing(-2)
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 4)
    }

    private var eyebrowText: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        let day = f.string(from: .now)
        let hour = Calendar.current.component(.hour, from: .now)
        let part: String
        switch hour {
        case 0..<12: part = "Morning"
        case 12..<17: part = "Afternoon"
        default: part = "Evening"
        }
        return "\(day) · \(part)"
    }

    private var weekStripLink: some View {
        NavigationLink {
            StreakDetailView()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("This week")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.6)
                        .textCase(.uppercase)
                        .foregroundStyle(theme.inkMute)
                    Spacer()
                    Text("\(weekDoneCount) of 7 days")
                        .font(.caption2)
                        .foregroundStyle(theme.inkMute)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.inkMute)
                }
                weekStrip
                    .padding(.vertical, 14)
                    .padding(.horizontal, 6)
                    .background(theme.card, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(theme.border, lineWidth: 0.5)
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var weekDoneCount: Int {
        progress.week().filter { $0.completion?.isComplete == true }.count
    }

    private var weekStrip: some View {
        let week = progress.week()
        let symbols = ["M", "T", "W", "T", "F", "S", "S"]
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        return HStack(spacing: 0) {
            ForEach(Array(week.enumerated()), id: \.offset) { index, day in
                let isToday = calendar.isDate(day.date, inSameDayAs: todayStart)
                let bloom = day.completion.map { $0.progress } ?? 0
                let done = day.completion?.isComplete == true
                VStack(spacing: 6) {
                    Lotus(
                        size: 26,
                        bloom: done ? 1.0 : bloom,
                        color: done ? theme.accent : (isToday ? theme.accentInk : theme.inkFaint),
                        dim: theme.inkFaint,
                        strokeWidth: isToday ? 1.6 : 1.3
                    )
                    Text(symbols[index])
                        .font(.system(size: 10, weight: .medium))
                        .tracking(0.5)
                        .foregroundStyle(isToday ? theme.accent : theme.inkMute)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var progressSection: some View {
        let value = today?.progress ?? 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Progress today")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.inkMute)
                Spacer()
                Text(value, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(theme.accent)
                    .contentTransition(.numericText())
            }
            ProgressView(value: value)
                .tint(theme.accent)
        }
    }

    private var sitCard: some View {
        Button {
            selectedTab = .practice
        } label: {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("MORNING SIT · 5 MIN")
                        .font(.caption2.weight(.bold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Settle into stillness.")
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 8) {
                        Image(systemName: today?.meditationDone == true ? "checkmark" : "play.fill")
                            .font(.caption.weight(.semibold))
                        Text(today?.meditationDone == true ? "Done" : "Begin")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.22), in: Capsule())
                    .padding(.top, 6)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(
                LinearGradient(
                    colors: [theme.secondary, theme.secondary.opacity(0.85)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 18)
            )
        }
        .buttonStyle(.plain)
    }

    private var passageCard: some View {
        Button {
            if let p = passage {
                showingPassage = p
            } else {
                selectedTab = .practice
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Text("PASSAGE FOR TODAY")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.8)
                    .foregroundStyle(theme.inkMute)
                if let passage {
                    let body = passage.lines.first?.text ?? passage.englishTitle
                    Text("\(Text("\u{201C}").foregroundColor(theme.accent).font(.system(size: 26, design: .serif)))\(Text(body).font(.system(size: 17, weight: .regular, design: .serif)).foregroundColor(theme.ink))")
                        .lineLimit(6)
                        .multilineTextAlignment(.leading)
                    Divider().background(theme.border)
                    HStack {
                        Text(passage.code)
                            .font(.system(size: 12, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(theme.inkSoft)
                        Spacer()
                        Text("· \(passage.englishTitle)")
                            .font(.caption)
                            .foregroundStyle(theme.inkMute)
                    }
                } else {
                    if case .failed(let message) = canon.loadStatus {
                        VStack(spacing: 8) {
                            Text("The canon failed to load")
                                .font(BTFont.ui(14))
                            Text(message)
                                .font(BTFont.ui(11))
                                .foregroundStyle(theme.inkMute)
                            Button("Retry") { canon.load() }
                                .font(BTFont.ui(12, weight: .medium))
                                .foregroundStyle(theme.accent)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ContentUnavailableView("No passage yet", systemImage: "book.closed")
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.card, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(theme.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
