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
                .containerBackground(entry.theme(for: .light).bg, for: .widget)
        }
        .configurationDisplayName("Daily Dhammapada")
        .description("Today's verse and your streak.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
    }
}

// MARK: - Theme (mirrored from app, minimal subset)

enum WidgetPalette: String {
    case moss, saffron, lotus

    func theme(for scheme: ColorScheme) -> WidgetTheme {
        switch (self, scheme) {
        case (.moss, .dark):     return .mossDusk
        case (.moss, .light):    return .mossDay
        case (.saffron, .dark):  return .saffronDusk
        case (.saffron, .light): return .saffronDay
        case (.lotus, .dark):    return .lotusDusk
        case (.lotus, .light):   return .lotusDay
        @unknown default:        return .mossDusk
        }
    }
}

struct WidgetTheme {
    let bg: Color
    let card: Color
    let ink: Color
    let inkSoft: Color
    let inkMute: Color
    let accent: Color
    let secondary: Color

    static let mossDusk = WidgetTheme(
        bg: .hex(0x1E2A22), card: .hex(0x2C3A2F),
        ink: .hex(0xEAEDD8), inkSoft: .hex(0xBFC4A8), inkMute: .hex(0x888E72),
        accent: .hex(0x9DBE7C), secondary: .hex(0xD8553D))
    static let mossDay = WidgetTheme(
        bg: .hex(0xEFEAD2), card: .hex(0xF8F2D8),
        ink: .hex(0x243018), inkSoft: .hex(0x4F5A3A), inkMute: .hex(0x838868),
        accent: .hex(0x5A7A3E), secondary: .hex(0xB33A24))
    static let saffronDusk = WidgetTheme(
        bg: .hex(0x1A1F38), card: .hex(0x2A3258),
        ink: .hex(0xF4E8CE), inkSoft: .hex(0xC9BC9C), inkMute: .hex(0x8A8270),
        accent: .hex(0xE89A3C), secondary: .hex(0x7DB099))
    static let saffronDay = WidgetTheme(
        bg: .hex(0xF1E4C8), card: .hex(0xFAEED2),
        ink: .hex(0x1F2447), inkSoft: .hex(0x4D5478), inkMute: .hex(0x8A8567),
        accent: .hex(0xC97320), secondary: .hex(0x3E6B5B))
    static let lotusDusk = WidgetTheme(
        bg: .hex(0x2C1E2C), card: .hex(0x3F2B40),
        ink: .hex(0xF2E2DA), inkSoft: .hex(0xCDB8B5), inkMute: .hex(0x8E7B82),
        accent: .hex(0xE07AA0), secondary: .hex(0x5BA8A8))
    static let lotusDay = WidgetTheme(
        bg: .hex(0xF4E6E0), card: .hex(0xFBEEE9),
        ink: .hex(0x3A1F2F), inkSoft: .hex(0x6E4458), inkMute: .hex(0xA07882),
        accent: .hex(0xB84878), secondary: .hex(0x2E7878))
}

extension Color {
    static func hex(_ value: UInt32, opacity: Double = 1.0) -> Color {
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: opacity)
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
    let palette: WidgetPalette
    let appearance: String

    func theme(for systemScheme: ColorScheme) -> WidgetTheme {
        let scheme: ColorScheme
        switch appearance {
        case "light": scheme = .light
        case "dark":  scheme = .dark
        default:      scheme = systemScheme
        }
        return palette.theme(for: scheme)
    }
}

// MARK: - Provider

struct FaithProvider: TimelineProvider {
    private let appGroupID = "group.minh.faith-ios"

    func placeholder(in context: Context) -> FaithEntry {
        FaithEntry(date: .now, verse: Self.sample, progress: 0.4, streak: 3, palette: .moss, appearance: "system")
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
        let paletteRaw = defaults?.string(forKey: "palette") ?? "moss"
        let appearance = defaults?.string(forKey: "appearance") ?? "system"
        let palette = WidgetPalette(rawValue: paletteRaw) ?? .moss
        return FaithEntry(date: date, verse: verse, progress: progress, streak: streak, palette: palette, appearance: appearance)
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
        number: 274,
        chapter: 20,
        chapterPali: "Maggavagga",
        chapterTitle: "The Path",
        storyTitle: "The Story of the Five Hundred Bhikkhus",
        storyPaliName: "",
        story: "",
        text: "This is the only Path; there is none other for the purity of vision."
    )
}

// MARK: - Root view

struct FaithWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var systemScheme
    let entry: FaithEntry

    var body: some View {
        let theme = entry.theme(for: systemScheme)
        Group {
            switch family {
            case .systemSmall: SmallView(entry: entry, theme: theme)
            case .systemMedium: MediumView(entry: entry, theme: theme)
            case .systemLarge: LargeView(entry: entry, theme: theme)
            case .accessoryCircular: AccessoryCircularView(entry: entry)
            case .accessoryRectangular: AccessoryRectangularView(entry: entry)
            case .accessoryInline: AccessoryInlineView(entry: entry)
            default: Text("Unsupported")
            }
        }
        .containerBackground(theme.bg, for: .widget)
    }
}

// MARK: - Home screen sizes

private struct SmallView: View {
    let entry: FaithEntry
    let theme: WidgetTheme

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.accent.opacity(0.18), lineWidth: 10)
            Circle()
                .trim(from: 0, to: max(entry.progress, 0.001))
                .stroke(theme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: -2) {
                Text("\(entry.streak)")
                    .font(.system(size: 40, weight: .regular, design: .serif).monospacedDigit())
                    .foregroundStyle(theme.ink)
                Text("day streak")
                    .font(.caption2)
                    .foregroundStyle(theme.inkMute)
            }
        }
        .padding(8)
    }
}

private struct MediumView: View {
    let entry: FaithEntry
    let theme: WidgetTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VERSE FOR TODAY")
                .font(.caption2.weight(.semibold))
                .tracking(1.8)
                .foregroundStyle(theme.accent)
            if let verse = entry.verse {
                Text(verse.text)
                    .font(.system(size: 14, design: .serif))
                    .italic()
                    .foregroundStyle(theme.ink)
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                Text("Verse \(verse.number) · \(verse.chapterTitle)")
                    .font(.caption2)
                    .foregroundStyle(theme.inkMute)
            }
        }
    }
}

private struct LargeView: View {
    let entry: FaithEntry
    let theme: WidgetTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VERSE FOR TODAY")
                .font(.caption2.weight(.semibold))
                .tracking(1.8)
                .foregroundStyle(theme.accent)

            if let verse = entry.verse {
                Text(verse.text)
                    .font(.system(size: 15, design: .serif))
                    .italic()
                    .foregroundStyle(theme.ink)
                    .lineLimit(8)

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 4) {
                    Text(verse.storyTitle)
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                    Text("Verse \(verse.number) · \(verse.chapterTitle)")
                        .font(.caption2)
                        .foregroundStyle(theme.inkMute)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: entry.progress)
                    .tint(theme.accent)
                HStack {
                    Text("Today")
                        .font(.caption2)
                        .foregroundStyle(theme.inkMute)
                    Spacer()
                    Text(entry.progress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(theme.inkMute)
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
                Image(systemName: "leaf.fill").font(.caption2)
                Text("\(entry.streak)").font(.headline.monospacedDigit())
            }
        }
    }
}

private struct AccessoryRectangularView: View {
    let entry: FaithEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Day \(entry.streak)", systemImage: "leaf.fill")
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
            Label("Day \(entry.streak) · Verse \(verse.number)", systemImage: "leaf.fill")
        } else {
            Label("Day \(entry.streak)", systemImage: "leaf.fill")
        }
    }
}
