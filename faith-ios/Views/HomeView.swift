import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(VerseStore.self) private var verseStore
    @Environment(\.modelContext) private var context
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
                    weekStripLink
                    progressSection
                    MeditationCard(isDone: today?.meditationDone == true) {
                        showingTimer = true
                    }
                    verseCard
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("Today's Journey")
            .navigationBarTitleDisplayMode(.large)
            .profileToolbar()
            .safeAreaInset(edge: .top, spacing: 0) {
                Text("Daily Dhammapada")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }
            .sheet(isPresented: $showingTimer) {
                NavigationStack { MeditationTimerView() }
            }
            .onAppear { progress.ensureToday() }
            .task(id: today?.doneCount) { progress.pushToWidget() }
        }
    }

    private var weekStripLink: some View {
        NavigationLink {
            StreakDetailView()
        } label: {
            HStack(spacing: 8) {
                weekStrip
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var weekStrip: some View {
        let week = progress.week()
        let symbols = ["M", "T", "W", "T", "F", "S", "S"]
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        return HStack(spacing: 12) {
            ForEach(Array(week.enumerated()), id: \.offset) { index, day in
                let isToday = calendar.isDate(day.date, inSameDayAs: todayStart)
                let done = day.completion?.isComplete == true
                VStack(spacing: 8) {
                    Text(symbols[index])
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isToday ? Color.accentColor : .secondary)
                    Image(systemName: done ? "flame.circle.fill" : "flame.circle")
                        .font(.title2)
                        .foregroundStyle(done ? .orange : .secondary.opacity(0.5))
                        .symbolRenderingMode(.hierarchical)
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
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .contentTransition(.numericText())
            }
            ProgressView(value: value)
                .tint(Color.accentColor)
        }
    }

    private var verseCard: some View {
        Button {
            selectedTab = .daily
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Label("Today's verse", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let verse {
                    Text(verse.text)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(6)
                    Text("Verse \(verse.number) · \(verse.chapterTitle)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ContentUnavailableView("No verse loaded", systemImage: "book.closed")
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
