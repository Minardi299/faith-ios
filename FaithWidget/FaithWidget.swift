import WidgetKit
import SwiftUI

// MARK: - Bundle

@main
struct FaithWidgetBundle: WidgetBundle {
    var body: some Widget {
        FaithWidget()
    }
}

struct FaithWidget: Widget {
    let kind = "FaithWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FaithProvider()) { entry in
            FaithWidgetView(entry: entry)
                .widgetURL(URL(string: "faith://daily"))
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Daily Dhammapada")
        .description("Today's verse and your streak.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
    }
}

// MARK: - Data

struct WidgetVerse: Codable, Hashable {
    let number: Int
    let chapter: Int
    let chapterPali: String
    let chapterTitle: String
    let storyTitle: String
    let storyPaliName: String
    let story: String
    let text: String
}

struct FaithEntry: TimelineEntry {
    let date: Date
    let verse: WidgetVerse?
    let progress: Double
    let streak: Int
}

// MARK: - Provider

struct FaithProvider: TimelineProvider {
    private let appGroupID = "group.minh.faith-ios"

    func placeholder(in context: Context) -> FaithEntry {
        FaithEntry(date: .now, verse: Self.sample, progress: 0.4, streak: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (FaithEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FaithEntry>) -> Void) {
        let now = Date.now
        let calendar = Calendar.current
        let nextRefresh = calendar.date(
            byAdding: .day, value: 1,
            to: calendar.startOfDay(for: now)
        ) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [makeEntry(date: now)], policy: .after(nextRefresh)))
    }

    private func makeEntry(date: Date = .now) -> FaithEntry {
        let verses = loadVerses()
        let verse = pickVerse(from: verses, for: date)
        let defaults = UserDefaults(suiteName: appGroupID)
        let progress = defaults?.double(forKey: "todayProgress") ?? 0
        let streak = defaults?.integer(forKey: "currentStreak") ?? 0
        return FaithEntry(date: date, verse: verse, progress: progress, streak: streak)
    }

    private func loadVerses() -> [WidgetVerse] {
        guard let url = Bundle.main.url(forResource: "data", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([WidgetVerse].self, from: data)) ?? []
    }

    private func pickVerse(from verses: [WidgetVerse], for date: Date) -> WidgetVerse? {
        guard !verses.isEmpty else { return nil }
        let day = Calendar.current.startOfDay(for: date)
        let epoch = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 0))
        let days = Calendar.current.dateComponents([.day], from: epoch, to: day).day ?? 0
        let index = ((days % verses.count) + verses.count) % verses.count
        return verses[index]
    }

    static let sample = WidgetVerse(
        number: 1,
        chapter: 1,
        chapterPali: "Yamakavagga",
        chapterTitle: "The Pairs",
        storyTitle: "The Story of Thera Cakkhupala",
        storyPaliName: "Cakkhupalatthera Vatthu",
        story: "",
        text: "All mental phenomena have mind as their forerunner; they have mind as their chief; they are mind-made."
    )
}

// MARK: - Root view

struct FaithWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FaithEntry

    var body: some View {
        switch family {
        case .systemSmall: SmallView(entry: entry)
        case .systemMedium: MediumView(entry: entry)
        case .systemLarge: LargeView(entry: entry)
        case .accessoryCircular: AccessoryCircularView(entry: entry)
        case .accessoryRectangular: AccessoryRectangularView(entry: entry)
        case .accessoryInline: AccessoryInlineView(entry: entry)
        default: Text("Unsupported")
        }
    }
}

// MARK: - Home screen sizes

private struct SmallView: View {
    let entry: FaithEntry

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.orange.opacity(0.18), lineWidth: 10)
            Circle()
                .trim(from: 0, to: max(entry.progress, 0.001))
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: -2) {
                Text("\(entry.streak)")
                    .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                Text("day streak")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
    }
}

private struct MediumView: View {
    let entry: FaithEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Today's Dhammapada", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
            if let verse = entry.verse {
                Text(verse.text)
                    .font(.callout)
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                Text("Verse \(verse.number) · \(verse.chapterTitle)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct LargeView: View {
    let entry: FaithEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Today's Dhammapada", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)

            if let verse = entry.verse {
                Text(verse.text)
                    .font(.body)
                    .lineLimit(8)

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 4) {
                    Text(verse.storyTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text("Verse \(verse.number) · \(verse.chapterTitle)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: entry.progress)
                    .tint(.orange)
                HStack {
                    Text("Today")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(entry.progress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Lock screen accessories

private struct AccessoryCircularView: View {
    let entry: FaithEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: -2) {
                Image(systemName: "flame.fill").font(.caption2)
                Text("\(entry.streak)").font(.headline.monospacedDigit())
            }
        }
    }
}

private struct AccessoryRectangularView: View {
    let entry: FaithEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Day \(entry.streak)", systemImage: "flame.fill")
                .font(.headline)
                .labelStyle(.titleAndIcon)
            if let verse = entry.verse {
                Text(verse.text)
                    .font(.caption2)
                    .lineLimit(2)
            }
        }
    }
}

private struct AccessoryInlineView: View {
    let entry: FaithEntry

    var body: some View {
        if let verse = entry.verse {
            Label("Day \(entry.streak) · Verse \(verse.number)", systemImage: "flame.fill")
        } else {
            Label("Day \(entry.streak)", systemImage: "flame.fill")
        }
    }
}
