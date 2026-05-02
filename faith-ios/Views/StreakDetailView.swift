import SwiftUI
import SwiftData

struct StreakDetailView: View {
    @Environment(\.modelContext) private var context
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
            VStack(spacing: 20) {
                statsRow
                monthCalendar
            }
            .padding()
        }
        .navigationTitle("Streak")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatTile(value: currentStreak, label: "Current", systemImage: "flame.fill", tint: .orange)
            StatTile(value: longestStreak, label: "Longest", systemImage: "trophy.fill", tint: .yellow)
            StatTile(value: totalDays, label: "Total", systemImage: "checkmark.seal.fill", tint: .green)
        }
    }

    private var monthCalendar: some View {
        VStack(spacing: 14) {
            HStack {
                Button { changeMonth(-1) } label: {
                    Image(systemName: "chevron.left").font(.headline)
                }
                Spacer()
                Text(displayedMonth, format: .dateTime.month(.wide).year())
                    .font(.headline)
                Spacer()
                Button { changeMonth(1) } label: {
                    Image(systemName: "chevron.right").font(.headline)
                }
                .disabled(isCurrentOrFutureMonth)
                .opacity(isCurrentOrFutureMonth ? 0.3 : 1)
            }
            HStack(spacing: 0) {
                ForEach(Array(weekdayHeader.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            VStack(spacing: 6) {
                ForEach(weeks.indices, id: \.self) { wIdx in
                    let week = weeks[wIdx]
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { dIdx in
                            let date = week[dIdx]
                            let completed = isCellCompleted(date)
                            DayCell(
                                date: date,
                                isCompleted: completed,
                                leftConnected: completed && dIdx > 0 && isCellCompleted(week[dIdx - 1]),
                                rightConnected: completed && dIdx < 6 && isCellCompleted(week[dIdx + 1]),
                                isToday: date.map { calendar.isDateInToday($0) } ?? false
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var weekdayHeader: [String] {
        ["S", "M", "T", "W", "T", "F", "S"]
    }

    private var weeks: [[Date?]] {
        let cells = daysInGrid
        var rows: [[Date?]] = []
        for i in stride(from: 0, to: cells.count, by: 7) {
            var row = Array(cells[i..<min(i + 7, cells.count)])
            while row.count < 7 { row.append(nil) }
            rows.append(row)
        }
        return rows
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

    private func isCellCompleted(_ date: Date?) -> Bool {
        guard let date else { return false }
        return completedKeys.contains(DayCompletion.key(for: date))
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
    let value: Int
    let label: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
            Text("\(value)")
                .font(.title.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct DayCell: View {
    let date: Date?
    let isCompleted: Bool
    let leftConnected: Bool
    let rightConnected: Bool
    let isToday: Bool

    var body: some View {
        ZStack {
            if isCompleted {
                UnevenRoundedRectangle(
                    topLeadingRadius: leftConnected ? 0 : 22,
                    bottomLeadingRadius: leftConnected ? 0 : 22,
                    bottomTrailingRadius: rightConnected ? 0 : 22,
                    topTrailingRadius: rightConnected ? 0 : 22
                )
                .fill(Color.pink.opacity(0.25))
            } else if isToday {
                Circle().stroke(Color.accentColor, lineWidth: 1.5)
                    .padding(2)
            }
            if let date {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(isToday ? Color.accentColor : .primary)
            }
        }
        .frame(height: 38)
    }
}

#Preview {
    NavigationStack { StreakDetailView() }
        .modelContainer(for: [DayCompletion.self, ChatMessage.self], inMemory: true)
}
