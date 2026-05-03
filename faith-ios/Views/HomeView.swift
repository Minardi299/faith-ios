import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(VerseStore.self) private var verseStore
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @Query private var completions: [DayCompletion]
    @Binding var selectedTab: AppTab
    @State private var showingTimer = false

    private var progress: ProgressStore { ProgressStore(context: context) }
    private var todayKey: String { DayCompletion.key(for: .now) }
    private var today: DayCompletion? { completions.first { $0.dayKey == todayKey } }
    private var verse: Verse? { verseStore.verse(for: .now) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerBlock
                    weekStripLink
                    progressSection
                    sitCard
                    verseCard
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(theme.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { EmptyView() } }
            .profileToolbar()
            .sheet(isPresented: $showingTimer) {
                NavigationStack { MeditationTimerView() }
            }
            .onAppear { progress.ensureToday() }
            .task(id: today?.doneCount) { progress.pushToWidget() }
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrowText)
                .font(.caption2.weight(.semibold))
                .tracking(2.4)
                .textCase(.uppercase)
                .foregroundStyle(theme.inkMute)
            (Text("May the day\n")
                + Text("arrive gently.")
                .italic()
                .foregroundColor(theme.secondary))
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
            showingTimer = true
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

    private var verseCard: some View {
        Button {
            selectedTab = .daily
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Text("VERSE FOR TODAY")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.8)
                    .foregroundStyle(theme.inkMute)
                if let verse {
                    (Text("\u{201C}").foregroundColor(theme.accent).font(.system(size: 26, design: .serif))
                        + Text(verse.text)
                        .font(.system(size: 17, weight: .regular, design: .serif))
                        .foregroundColor(theme.ink))
                        .lineLimit(6)
                        .multilineTextAlignment(.leading)
                    Divider().background(theme.border)
                    HStack {
                        Text("Verse \(verse.number)")
                            .font(.system(size: 12, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(theme.inkSoft)
                        Spacer()
                        Text("· \(verse.chapterTitle)")
                            .font(.caption)
                            .foregroundStyle(theme.inkMute)
                    }
                } else {
                    ContentUnavailableView("No verse loaded", systemImage: "book.closed")
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
