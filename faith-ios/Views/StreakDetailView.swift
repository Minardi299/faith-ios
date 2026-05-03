import SwiftUI
import SwiftData

struct StreakDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @Query private var completions: [DayCompletion]
    @State private var displayedMonth: Date = Calendar.current.startOfDay(for: .now)

    private var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 1
        return c
    }

    private var completedKeys: Set<String> {
        Set(completions.filter(\.isComplete).map(\.dayKey))
    }

    private var bloomByKey: [String: Double] {
        Dictionary(uniqueKeysWithValues: completions.map { ($0.dayKey, $0.progress) })
    }

    private var currentStreak: Int {
        ProgressStore(context: context).currentStreak()
    }

    private var longestStreak: Int {
        let days = completions.filter(\.isComplete)
            .map { calendar.startOfDay(for: $0.date) }
            .sorted()
        guard !days.isEmpty else { return 0 }
        var longest = 1
        var run = 1
        for i in 1..<days.count {
            if let prev = calendar.date(byAdding: .day, value: 1, to: days[i - 1]),
               calendar.isDate(prev, inSameDayAs: days[i]) {
                run += 1
                longest = max(longest, run)
            } else {
                run = 1
            }
        }
        return longest
    }

    private var totalDays: Int { completions.filter(\.isComplete).count }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                headerBlock
                statsRow
                monthCalendar
                footerVerse
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(theme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YOUR GARDEN")
                .font(.caption2.weight(.semibold))
                .tracking(2.4)
                .foregroundStyle(theme.inkMute)
            (Text("\(currentStreak.spelled.capitalized) \(currentStreak == 1 ? "day" : "days")\n")
                + Text("in bloom")
                .italic()
                .foregroundColor(theme.secondary))
                .font(.system(size: 32, weight: .regular, design: .serif))
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 4)
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatTile(label: "Now", value: currentStreak, sub: "days", isAccent: true)
            StatTile(label: "Longest", value: longestStreak, sub: "days", isAccent: false)
            StatTile(label: "In total", value: totalDays, sub: "days", isAccent: false)
        }
    }

    private var monthCalendar: some View {
        VStack(spacing: 14) {
            HStack {
                Button { changeMonth(-1) } label: {
                    Image(systemName: "chevron.left").font(.subheadline.weight(.medium))
                }
                .foregroundStyle(theme.inkMute)
                Spacer()
                Text(displayedMonth, format: .dateTime.month(.wide).year())
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(theme.ink)
                Spacer()
                Button { changeMonth(1) } label: {
                    Image(systemName: "chevron.right").font(.subheadline.weight(.medium))
                }
                .foregroundStyle(theme.inkMute)
                .disabled(isCurrentOrFutureMonth)
                .opacity(isCurrentOrFutureMonth ? 0.3 : 1)
            }
            HStack(spacing: 8) {
                ForEach(weekdayHeader, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(theme.inkMute)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 10) {
                ForEach(Array(daysInGrid.enumerated()), id: \.offset) { _, day in
                    if let day {
                        DayCell(
                            date: day,
                            bloom: bloomByKey[DayCompletion.key(for: day)] ?? 0,
                            isCompleted: completedKeys.contains(DayCompletion.key(for: day)),
                            isToday: calendar.isDateInToday(day)
                        )
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding(18)
        .background(theme.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(theme.border, lineWidth: 0.5)
        )
    }

    private var footerVerse: some View {
        Text("\u{201C}The mind is everything. What you think, you become.\u{201D}")
            .font(.system(size: 13, design: .serif))
            .italic()
            .foregroundStyle(theme.inkSoft)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }

    private var weekdayHeader: [String] {
        ["S", "M", "T", "W", "T", "F", "S"]
    }

    private var daysInGrid: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        let dayCount = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30
        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<dayCount {
            cells.append(calendar.date(byAdding: .day, value: offset, to: interval.start))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private var isCurrentOrFutureMonth: Bool {
        let now = calendar.startOfDay(for: .now)
        guard let nowMonth = calendar.dateInterval(of: .month, for: now)?.start,
              let displayedStart = calendar.dateInterval(of: .month, for: displayedMonth)?.start
        else { return true }
        return displayedStart >= nowMonth
    }

    private func changeMonth(_ delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = next
        }
    }
}

private struct StatTile: View {
    @Environment(\.theme) private var theme
    let label: String
    let value: Int
    let sub: String
    let isAccent: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(theme.inkMute)
            Text("\(value)")
                .font(.system(size: 28, weight: .regular, design: .serif).monospacedDigit())
                .foregroundStyle(isAccent ? theme.accent : theme.ink)
            Text(sub)
                .font(.system(size: 11, design: .serif))
                .italic()
                .foregroundStyle(theme.inkMute)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(theme.border, lineWidth: 0.5)
        )
    }
}

private struct DayCell: View {
    @Environment(\.theme) private var theme
    let date: Date
    let bloom: Double
    let isCompleted: Bool
    let isToday: Bool

    private var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }

    var body: some View {
        VStack(spacing: 2) {
            Lotus(
                size: 26,
                bloom: isCompleted ? 1.0 : bloom,
                color: isCompleted ? theme.accent : (isToday ? theme.accentInk : theme.inkFaint),
                dim: theme.inkFaint,
                strokeWidth: isToday ? 1.6 : 1.2
            )
            Text("\(dayNumber)")
                .font(.system(size: 9, weight: isToday ? .semibold : .regular).monospacedDigit())
                .foregroundStyle(isToday ? theme.accent : theme.inkMute)
        }
        .frame(height: 44)
    }
}

private extension Int {
    var spelled: String {
        let names = [
            "zero","one","two","three","four","five","six","seven","eight","nine",
            "ten","eleven","twelve","thirteen","fourteen","fifteen","sixteen",
            "seventeen","eighteen","nineteen","twenty"
        ]
        return self < names.count ? names[self] : "\(self)"
    }
}

#Preview {
    NavigationStack { StreakDetailView() }
        .modelContainer(for: [DayCompletion.self, ChatMessage.self], inMemory: true)
        .environment(\.theme, .mossDusk)
}
