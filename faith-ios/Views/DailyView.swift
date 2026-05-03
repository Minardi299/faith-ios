import SwiftUI
import SwiftData

struct DailyView: View {
    @Environment(VerseStore.self) private var verseStore
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @Query private var completions: [DayCompletion]
    @State private var showingTimer = false

    private var progress: ProgressStore { ProgressStore(context: context) }
    private var verse: Verse? { verseStore.verse(for: .now) }
    private var todayKey: String { DayCompletion.key(for: .now) }
    private var today: DayCompletion? { completions.first { $0.dayKey == todayKey } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    headerBlock
                    if let verse {
                        verseCard(verse)
                        storySection(verse)
                    } else {
                        ContentUnavailableView("No verse for today", systemImage: "book.closed")
                    }
                    if let today {
                        practiceChecklist(today)
                    }
                    meditationRow
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
        let chapter = verse?.chapterTitle ?? "The Path"
        let split = chapter.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let prefix = split.count > 1 ? String(split[0]) + " " : ""
        let rest = split.count > 1 ? String(split[1]) : chapter
        return VStack(alignment: .leading, spacing: 6) {
            Text("PRACTICE · \(Date.now.formatted(.dateTime.month(.abbreviated).day()).uppercased())")
                .font(.caption2.weight(.semibold))
                .tracking(2.4)
                .foregroundStyle(theme.inkMute)
            (Text(prefix)
                + Text(rest)
                .italic()
                .foregroundColor(theme.secondary))
                .font(.system(size: 32, weight: .regular, design: .serif))
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 4)
    }

    private func verseCard(_ verse: Verse) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "mountain.2.fill")
                .font(.title2)
                .foregroundStyle(theme.secondary.opacity(0.7))
            Text(verse.text)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .italic()
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity)
            Text("VERSE \(verse.number)")
                .font(.caption2)
                .tracking(1.4)
                .foregroundStyle(theme.inkMute)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(theme.cardSoft, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(theme.border, lineWidth: 0.5)
        )
    }

    private func storySection(_ verse: Verse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verse.storyTitle)
                .font(.system(size: 22, weight: .regular, design: .serif))
                .foregroundStyle(theme.ink)
            if !verse.storyPaliName.isEmpty {
                Text(verse.storyPaliName)
                    .font(.system(.subheadline, design: .serif))
                    .italic()
                    .foregroundStyle(theme.inkSoft)
            }
            Text(verse.story)
                .font(.system(size: 15, design: .serif))
                .foregroundStyle(theme.inkSoft)
                .lineSpacing(2)
        }
    }

    private func practiceChecklist(_ today: DayCompletion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TODAY'S OFFERING")
                .font(.caption2.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(theme.inkMute)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                CheckRow(
                    title: "Morning intention",
                    systemImage: "sunrise",
                    isOn: Binding(
                        get: { today.morningPrayerDone },
                        set: { today.morningPrayerDone = $0 }
                    )
                )
                Divider().background(theme.border).padding(.leading, 52)
                CheckRow(
                    title: "Read today's story",
                    systemImage: "book",
                    isOn: Binding(
                        get: { today.storyReadDone },
                        set: { today.storyReadDone = $0 }
                    )
                )
                Divider().background(theme.border).padding(.leading, 52)
                CheckRow(
                    title: "Note one gratitude",
                    systemImage: "leaf",
                    isOn: Binding(
                        get: { today.gratitudeDone },
                        set: { today.gratitudeDone = $0 }
                    )
                )
                Divider().background(theme.border).padding(.leading, 52)
                CheckRow(
                    title: "Evening reflection",
                    systemImage: "moon.stars",
                    isOn: Binding(
                        get: { today.eveningReflectionDone },
                        set: { today.eveningReflectionDone = $0 }
                    )
                )
            }
            .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(theme.border, lineWidth: 0.5)
            )
        }
    }

    private var meditationRow: some View {
        Button {
            showingTimer = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: today?.meditationDone == true ? "checkmark.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sit · 5 min")
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundStyle(theme.ink)
                    Text("Settle into stillness")
                        .font(.caption)
                        .italic()
                        .foregroundStyle(theme.inkMute)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.inkFaint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(theme.border, lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct CheckRow: View {
    @Environment(\.theme) private var theme
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.snappy) { isOn.toggle() }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(isOn ? theme.tertiary : theme.inkFaint, lineWidth: 1.3)
                        .background(Circle().fill(isOn ? theme.tertiary : Color.clear))
                        .frame(width: 22, height: 22)
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(isOn ? theme.inkMute : theme.inkSoft)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 15, design: .serif))
                    .strikethrough(isOn, color: theme.inkFaint)
                    .foregroundStyle(isOn ? theme.inkMute : theme.ink)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
