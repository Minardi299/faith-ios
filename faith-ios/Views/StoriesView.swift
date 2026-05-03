import SwiftUI

struct StoriesView: View {
    @Environment(VerseStore.self) private var verseStore
    @Environment(\.theme) private var theme

    private var todaysVerse: Verse? { verseStore.verse(for: .now) }

    private var library: [Verse] {
        var seen = Set<String>()
        return verseStore.verses.filter { seen.insert($0.storyTitle).inserted }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    headerBlock
                    if let verse = todaysVerse {
                        NavigationLink(value: verse) {
                            featuredCard(verse)
                        }
                        .buttonStyle(.plain)
                    }
                    libraryList
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(theme.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { EmptyView() } }
            .navigationDestination(for: Verse.self) { verse in
                StoryDetailView(verse: verse)
            }
            .profileToolbar()
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LIBRARY")
                .font(.caption2.weight(.semibold))
                .tracking(2.4)
                .foregroundStyle(theme.inkMute)
            (Text("Stories of\n")
                + Text("the verses")
                .italic()
                .foregroundColor(theme.secondary))
                .font(.system(size: 32, weight: .regular, design: .serif))
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 4)
    }

    private func featuredCard(_ verse: Verse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(theme.tertiary).frame(width: 5, height: 5)
                Text("TODAY'S TALE")
                    .font(.caption2.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(theme.tertiary)
            }
            Text(verse.storyTitle)
                .font(.system(size: 22, weight: .regular, design: .serif))
                .foregroundStyle(theme.ink)
            Text(verse.story)
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(theme.inkSoft)
                .lineLimit(3)
                .lineSpacing(2)
            HStack {
                Text("Verse \(verse.number) · \(verse.chapterTitle)")
                    .font(.caption)
                    .foregroundStyle(theme.inkMute)
                Spacer()
                Text("Read →")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.accent)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardSoft, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(theme.borderStrong, lineWidth: 0.5)
        )
    }

    private var libraryList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("LIBRARY")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(theme.inkMute)
                Spacer()
                Text("\(verseStore.verses.count) verses")
                    .font(.caption)
                    .foregroundStyle(theme.inkMute)
            }
            .padding(.bottom, 6)
            .padding(.leading, 4)

            ForEach(library) { verse in
                NavigationLink(value: verse) {
                    libraryRow(verse)
                }
                .buttonStyle(.plain)
                if verse.id != library.last?.id {
                    Divider().background(theme.border)
                }
            }
        }
    }

    private func libraryRow(_ verse: Verse) -> some View {
        HStack(spacing: 14) {
            Text(String(format: "%02d", verse.number))
                .font(.system(size: 14, design: .serif))
                .italic()
                .foregroundStyle(theme.inkMute)
                .frame(width: 28, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(verse.storyTitle)
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(theme.ink)
                Text([verse.chapterTitle, verse.storyPaliName].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(theme.inkMute)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.inkFaint)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }
}

private extension Theme {
    var borderStrong: Color { border.opacity(2.0) }
}
