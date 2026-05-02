import SwiftUI
import SwiftData

struct DailyView: View {
    @Environment(VerseStore.self) private var verseStore
    @Environment(\.modelContext) private var context
    @Query private var completions: [DayCompletion]
    @State private var showingTimer = false

    private var progress: ProgressStore { ProgressStore(context: context) }
    private var verse: Verse? { verseStore.verse(for: .now) }
    private var todayKey: String { DayCompletion.key(for: .now) }
    private var today: DayCompletion? { completions.first { $0.dayKey == todayKey } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
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
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("Daily")
            .navigationBarTitleDisplayMode(.large)
            .profileToolbar()
            .sheet(isPresented: $showingTimer) {
                NavigationStack { MeditationTimerView() }
            }
            .onAppear { progress.ensureToday() }
            .task(id: today?.doneCount) { progress.pushToWidget() }
        }
    }

    private func verseCard(_ verse: Verse) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "sun.max.fill")
                .font(.title)
                .foregroundStyle(.yellow)
                .symbolRenderingMode(.hierarchical)
            Text(verse.text)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Text("Verse \(verse.number) · \(verse.chapterTitle)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func storySection(_ verse: Verse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verse.storyTitle)
                .font(.title2.weight(.bold))
            if !verse.storyPaliName.isEmpty {
                Text(verse.storyPaliName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(verse.story)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }

    private func practiceChecklist(_ today: DayCompletion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Practice")
                .font(.title3.weight(.bold))
            VStack(spacing: 0) {
                CheckRow(
                    title: "Morning prayer",
                    systemImage: "sunrise",
                    isOn: Binding(
                        get: { today.morningPrayerDone },
                        set: { today.morningPrayerDone = $0 }
                    )
                )
                Divider().padding(.leading, 52)
                CheckRow(
                    title: "Read today's story",
                    systemImage: "book",
                    isOn: Binding(
                        get: { today.storyReadDone },
                        set: { today.storyReadDone = $0 }
                    )
                )
                Divider().padding(.leading, 52)
                CheckRow(
                    title: "Journal one gratitude",
                    systemImage: "heart",
                    isOn: Binding(
                        get: { today.gratitudeDone },
                        set: { today.gratitudeDone = $0 }
                    )
                )
                Divider().padding(.leading, 52)
                CheckRow(
                    title: "Evening reflection",
                    systemImage: "moon.stars",
                    isOn: Binding(
                        get: { today.eveningReflectionDone },
                        set: { today.eveningReflectionDone = $0 }
                    )
                )
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var meditationRow: some View {
        Button {
            showingTimer = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: today?.meditationDone == true ? "checkmark.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Meditate")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("5 min · guided silence")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct CheckRow: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.snappy) { isOn.toggle() }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? Color.accentColor : .secondary)
                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(title)
                    .strikethrough(isOn, color: .secondary)
                    .foregroundStyle(isOn ? .secondary : .primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
