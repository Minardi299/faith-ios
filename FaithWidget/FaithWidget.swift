import WidgetKit
import SwiftUI

/// Daily passage widget. Reads the day's passage id + snippet from a shared
/// `UserDefaults` suite written by the main app's TodayView. Falls back to a
/// deterministic date-seeded pick from a small core list if the shared
/// values are missing — so the widget renders something reasonable on first
/// install before the app has run.
struct DailyPassageEntry: TimelineEntry {
    let date: Date
    let id: String
    let code: String
    let title: String
    let snippet: String
}

struct DailyPassageProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyPassageEntry {
        DailyPassageEntry(
            date: Date(),
            id: "MH_HEART",
            code: "Heart Sūtra",
            title: "Heart of Perfect Wisdom",
            snippet: "Form is no other than emptiness; emptiness no other than form."
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyPassageEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyPassageEntry>) -> Void) {
        let entry = currentEntry()
        let cal = Calendar.current
        let tomorrow = cal.nextDate(after: Date(),
                                    matching: DateComponents(hour: 0, minute: 5),
                                    matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600 * 6)
        completion(Timeline(entries: [entry], policy: .after(tomorrow)))
    }

    private func currentEntry() -> DailyPassageEntry {
        let defaults = UserDefaults(suiteName: "group.com.faith.app")
        if let id = defaults?.string(forKey: "dailyPassageID"),
           let code = defaults?.string(forKey: "dailyPassageCode"),
           let title = defaults?.string(forKey: "dailyPassageTitle"),
           let snippet = defaults?.string(forKey: "dailyPassageSnippet") {
            return DailyPassageEntry(date: Date(), id: id, code: code, title: title, snippet: snippet)
        }
        let fallback: [(String, String, String, String)] = [
            ("sn56.11", "SN 56.11", "First Sermon",
             "There is suffering. There is the origin of suffering. There is the cessation of suffering. There is the path."),
            ("sn22.59", "SN 22.59", "Non-self",
             "Form is not self. Were form self, then this form would not lead to affliction."),
            ("snp1.8", "Snp 1.8", "Karaṇīya Mettā Sutta",
             "Even as a mother protects with her life her child, her only child, so let one cultivate boundless love towards all beings."),
            ("an3.65", "AN 3.65", "Kālāma Sutta",
             "Do not believe in anything because you have heard it. When you yourselves know — these things are wholesome — enter on and abide in them."),
            ("mn10", "MN 10", "Satipaṭṭhāna",
             "Breathing in long, he discerns 'I am breathing in long.' Breathing out short, he discerns 'I am breathing out short.'"),
            ("dn22", "DN 22", "Mahāsatipaṭṭhāna",
             "There is the case where a monk remains focused on the body in and of itself — ardent, alert, and mindful."),
            ("dhp1-20", "Dhp · Pairs", "Yamakavagga",
             "Hatred is never appeased by hatred; by non-hatred alone is hatred appeased. This is an eternal law."),
            ("MH_HEART", "Heart Sūtra", "Heart of Perfect Wisdom",
             "Form is no other than emptiness; emptiness no other than form."),
        ]
        let groupDefaults = UserDefaults(suiteName: "group.com.faith.app")
        let offset = groupDefaults?.integer(forKey: "dailyPassageOffset") ?? 0
        let dayOfYear = (Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1) + offset
        let pick = fallback[((dayOfYear % fallback.count) + fallback.count) % fallback.count]
        return DailyPassageEntry(date: Date(), id: pick.0, code: pick.1, title: pick.2, snippet: pick.3)
    }
}

struct DailyPassageEntryView: View {
    let entry: DailyPassageEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.code.uppercased())
                .font(.system(size: 9, weight: .light))
                .tracking(1.8)
                .foregroundStyle(.white.opacity(0.55))
            Text(entry.title)
                .font(.system(size: titleSize, weight: .light, design: .serif))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(2)
                .lineSpacing(2)
            Text(entry.snippet)
                .font(.system(size: snippetSize, weight: .light, design: .serif).italic())
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(snippetLines)
                .lineSpacing(2)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.07, blue: 0.09),
                    Color(red: 0.02, green: 0.02, blue: 0.03),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .widgetURL(URL(string: "faith://passage/\(entry.id)"))
    }

    private var titleSize: CGFloat {
        switch family {
        case .systemSmall: return 16
        case .systemMedium: return 18
        default: return 22
        }
    }

    private var snippetSize: CGFloat {
        switch family {
        case .systemSmall: return 11
        default: return 13
        }
    }

    private var snippetLines: Int {
        switch family {
        case .systemSmall: return 3
        case .systemMedium: return 3
        default: return 6
        }
    }
}

struct DailyPassageWidget: Widget {
    let kind: String = "DailyPassageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyPassageProvider()) { entry in
            DailyPassageEntryView(entry: entry)
        }
        .configurationDisplayName("Daily Passage")
        .description("A passage from the Buddhist canon, refreshed each day.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct FaithWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyPassageWidget()
    }
}
