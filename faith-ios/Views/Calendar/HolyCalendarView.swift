import SwiftUI
import SwiftData

struct HolyCalendarView: View {
    @Environment(\.theme) private var theme

    @EnvironmentObject private var session: SessionStore
    @Environment(\.modelContext) private var context

    @State private var month: MonthSpec = .currentOrSeed
    @State private var selectedDay: Int? = nil

    @Query private var anniversaries: [Anniversary]

    var body: some View {
        PageScaffold(title: nil) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    todayCard
                    weekdayLabels
                    grid
                    streakChain
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
                .padding(.bottom, 110)
            }
        }
        .sheet(isPresented: Binding(get: { selectedDay != nil }, set: { if !$0 { selectedDay = nil } })) {
            if let d = selectedDay {
                DayDetailSheet(day: d, month: month)
            }
        }
    }

    // MARK: -

    private var observances: [HolyDay] {
        HolyDayCalendar.observances(year: month.year, month: month.month)
    }

    private var lunar: [Int: LunarPhase] {
        HolyDayCalendar.lunarPhases(year: month.year, month: month.month)
    }

    private var practice: [Int: Int] {
        PracticeQueries.practiceDepths(year: month.year, month: month.month, in: context)
    }

    private var todayDay: Int? {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: .now)
        guard comps.year == month.year, comps.month == month.month else { return nil }
        return comps.day
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("BE \(month.year + 543)")
                .font(BTFont.ui(10.5, weight: .light))
                .tracking(2.2)
                .foregroundStyle(theme.inkMute)
            HStack(spacing: 8) {
                Text("\(month.label) \(String(month.year))")
                    .font(BTFont.serif(28, weight: .light))
                    .foregroundStyle(theme.ink)
                Spacer()
                Button { withAnimation(.easeOut(duration: 0.35)) { month = month.previous } } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(theme.ink)
                        .frame(width: 32, height: 32)
                        .glassEffect(.regular, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                Button { withAnimation(.easeOut(duration: 0.35)) { month = month.next } } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(theme.ink)
                        .frame(width: 32, height: 32)
                        .glassEffect(.regular, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }

    private var todayCard: some View {
        let day = todayDay ?? 1
        let observance = observances.first { $0.day == day && ($0.kind == .major || $0.kind == .observance) }
        let phase = lunar[day] ?? .none
        return HStack(spacing: 14) {
            ZStack {
                Circle().strokeBorder(theme.border, lineWidth: 1)
                    .frame(width: 52, height: 52)
                Text("\(day)")
                    .font(BTFont.serif(22, weight: .light))
                    .foregroundStyle(theme.ink)
            }
            VStack(alignment: .leading, spacing: 3) {
                if let o = observance {
                    Text(o.label)
                        .font(BTFont.serif(15, weight: .light))
                        .foregroundStyle(theme.ink)
                    if let s = o.subtitle {
                        Text(s)
                            .font(BTFont.serif(12, weight: .light, italic: true))
                            .foregroundStyle(theme.inkMute)
                    }
                } else {
                    Text(todayDay == nil ? month.label : "Today")
                        .font(BTFont.serif(15, weight: .light, italic: true))
                        .foregroundStyle(theme.inkSoft)
                }
                if phase != .none {
                    HStack(spacing: 6) {
                        Image(systemName: phase.glyph)
                            .font(.system(size: 11, weight: .light))
                            .foregroundStyle(theme.inkSoft)
                        Text(phaseLabel(phase))
                            .font(BTFont.ui(11, weight: .light))
                            .foregroundStyle(theme.inkMute)
                    }
                }
            }
            Spacer()
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var weekdayLabels: some View {
        HStack {
            ForEach(Array(["S","M","T","W","T","F","S"].enumerated()), id: \.offset) { _, d in
                Text(d)
                    .font(BTFont.ui(10.5, weight: .light))
                    .tracking(1.5)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(theme.inkMute)
            }
        }
    }

    private var grid: some View {
        let days = month.gridDays
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(0..<days.count, id: \.self) { i in
                if let day = days[i] {
                    DayCell(day: day,
                            isToday: day == todayDay,
                            observance: observances.first { $0.day == day },
                            anniversary: anniversariesFor(day),
                            lunar: lunar[day] ?? .none,
                            practice: practice[day] ?? 0)
                        .onTapGesture { selectedDay = day }
                } else {
                    Color.clear.frame(height: 56)
                }
            }
        }
    }

    private func anniversariesFor(_ day: Int) -> Anniversary? {
        anniversaries.first { $0.matches(day: day, month: month.month, year: month.year) }
    }

    private var streakChain: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(1...month.daysInMonth, id: \.self) { d in
                    let depth = practice[d] ?? 0
                    Capsule()
                        .fill(theme.ink)
                        .frame(width: 4, height: barHeight(depth))
                        .opacity(depth == 0 ? 0.18 : 0.85)
                }
            }
            Text("\(practice.count) of \(month.daysInMonth) days marked")
                .font(BTFont.serif(12, weight: .light, italic: true))
                .foregroundStyle(theme.inkMute)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func barHeight(_ depth: Int) -> CGFloat {
        switch depth { case 3: 28; case 2: 18; case 1: 12; default: 5 }
    }

    private func phaseLabel(_ p: LunarPhase) -> String {
        switch p {
        case .newMoon:      "New moon"
        case .firstQuarter: "First quarter"
        case .fullMoon:     "Full moon"
        case .lastQuarter:  "Last quarter"
        case .none:         ""
        }
    }
}

private struct DayCell: View {
    @Environment(\.theme) private var theme

    let day: Int
    let isToday: Bool
    let observance: HolyDay?
    let anniversary: Anniversary?
    let lunar: LunarPhase
    let practice: Int

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isToday ? theme.inkMute : theme.border, lineWidth: 0.5)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isToday ? theme.border : theme.border)
                )
                .frame(height: 56)

            // observance dot top-left
            if let o = observance, let t = o.tradition {
                Circle().fill(t.accent).frame(width: 5, height: 5)
                    .padding(6)
            } else if anniversary != nil {
                Circle().strokeBorder(theme.inkSoft, lineWidth: 0.5)
                    .frame(width: 5, height: 5)
                    .padding(6)
            }

            // lunar glyph top-right
            if lunar != .none {
                HStack { Spacer()
                    Image(systemName: lunar.glyph)
                        .font(.system(size: 9, weight: .light))
                        .foregroundStyle(theme.inkSoft)
                        .padding(.top, 5)
                        .padding(.trailing, 6)
                }
            }

            VStack {
                Spacer()
                Text("\(day)")
                    .font(BTFont.serif(15, weight: isToday ? .regular : .light))
                    .foregroundStyle(.white.opacity(isToday ? 0.95 : 0.78))
                Spacer().frame(height: 3)
                // practice mark bottom-center
                practiceMark
                    .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var practiceMark: some View {
        if practice > 0 {
            Circle()
                .fill(theme.accent)
                .frame(width: 4, height: 4)
                .opacity(practice >= 20 ? 1.0 : practice >= 10 ? 0.7 : 0.4)
        }
    }
}

private struct DayDetailSheet: View {
    @Environment(\.theme) private var theme

    let day: Int
    let month: MonthSpec
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var session: SessionStore

    @State private var showAddAnniversary: Bool = false
    @State private var showAddJournal: Bool = false

    private var observance: HolyDay? {
        HolyDayCalendar.observances(year: month.year, month: month.month)
            .first { $0.day == day }
    }

    private var anniversariesForDay: [Anniversary] {
        AnniversaryStore.matches(day: day, month: month.month, year: month.year, in: context)
    }

    private var journalForDay: [JournalEntry] {
        var comps = DateComponents()
        comps.year = month.year; comps.month = month.month; comps.day = day
        guard let date = Calendar.current.date(from: comps) else { return [] }
        return JournalStore.entries(on: date, in: context)
    }

    var body: some View {
        ZStack(alignment: .top) {
            NatureSubstrate(tradition: observance?.tradition ?? session.user.tradition, dimming: 0.18)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(month.label) \(day) · \(String(month.year))")
                                .font(BTFont.serif(22, weight: .light))
                                .foregroundStyle(theme.ink)
                            if let o = observance {
                                Text(o.label)
                                    .font(BTFont.serif(15, weight: .light, italic: true))
                                    .foregroundStyle(theme.inkSoft)
                            }
                        }
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

                    Divider().background(theme.border)

                    if let s = observance?.subtitle {
                        Text(s)
                            .font(BTFont.serif(15, weight: .light))
                            .foregroundStyle(theme.ink)
                    }

                    if !anniversariesForDay.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Anniversaries").eyebrow()
                            ForEach(anniversariesForDay) { ann in
                                HStack {
                                    Circle().strokeBorder(theme.inkSoft, lineWidth: 0.5)
                                        .frame(width: 5, height: 5)
                                    Text(ann.label)
                                        .font(BTFont.serif(15, weight: .light))
                                        .foregroundStyle(theme.ink)
                                    Spacer()
                                    Button(role: .destructive) {
                                        AnniversaryStore.delete(ann, in: context)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11, weight: .light))
                                            .foregroundStyle(theme.inkMute)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    if !journalForDay.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Journal").eyebrow()
                            ForEach(journalForDay) { j in
                                Text(j.text)
                                    .font(BTFont.serif(14, weight: .light))
                                    .foregroundStyle(theme.ink)
                                    .lineSpacing(4)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Button { showAddAnniversary = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text("Add anniversary").font(BTFont.ui(12, weight: .light))
                            }
                            .foregroundStyle(theme.ink)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .glassEffect(.regular, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button { showAddJournal = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.pencil")
                                Text("Note this day").font(BTFont.ui(12, weight: .light))
                            }
                            .foregroundStyle(theme.ink)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .glassEffect(.regular, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
            }
        }
        .presentationDetents([.large])
        .presentationBackground(.clear)
        .sheet(isPresented: $showAddAnniversary) {
            AnniversaryComposer(initialDay: day,
                                initialMonth: month.month,
                                initialYear: month.year)
        }
        .sheet(isPresented: $showAddJournal) {
            JournalComposer(prefillSuttaID: nil) { text, _ in
                JournalStore.add(
                    text: text,
                    tradition: session.user.tradition,
                    suttaID: nil,
                    in: context
                )
            }
        }
    }
}

struct MonthSpec: Hashable {
    let year: Int
    let month: Int

    var label: String {
        DateFormatter().monthSymbols[month - 1]
    }

    var daysInMonth: Int {
        var comps = DateComponents(); comps.year = year; comps.month = month; comps.day = 1
        let cal = Calendar(identifier: .gregorian)
        let firstDate = cal.date(from: comps) ?? .now
        return cal.range(of: .day, in: .month, for: firstDate)?.count ?? 30
    }

    /// 7 columns × n rows, with leading nils until weekday of day 1.
    var gridDays: [Int?] {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = 1
        let cal = Calendar(identifier: .gregorian)
        let firstDate = cal.date(from: comps)!
        let weekday = cal.component(.weekday, from: firstDate) - 1   // 0=Sun
        let range = cal.range(of: .day, in: .month, for: firstDate)!.count
        var days: [Int?] = Array(repeating: nil, count: weekday)
        for d in 1...range { days.append(d) }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    var previous: MonthSpec {
        if month == 1 { return MonthSpec(year: year - 1, month: 12) }
        return MonthSpec(year: year, month: month - 1)
    }

    var next: MonthSpec {
        if month == 12 { return MonthSpec(year: year + 1, month: 1) }
        return MonthSpec(year: year, month: month + 1)
    }

    static var currentOrSeed: MonthSpec {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: .now)
        return MonthSpec(year: comps.year ?? 2026, month: comps.month ?? 11)
    }
}
