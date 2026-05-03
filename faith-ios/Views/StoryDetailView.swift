import SwiftUI

struct StoryDetailView: View {
    @Environment(\.theme) private var theme
    let verse: Verse

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                verseCard
                storyBody
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(theme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Story")
                    .font(.system(size: 17, design: .serif))
                    .foregroundStyle(theme.ink)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CHAPTER \(verse.chapter) · VERSE \(verse.number)")
                .font(.caption2.weight(.semibold))
                .tracking(2)
                .foregroundStyle(theme.inkMute)
            Text(verse.storyTitle)
                .font(.system(size: 28, weight: .regular, design: .serif))
                .foregroundStyle(theme.ink)
                .lineSpacing(2)
            if !verse.storyPaliName.isEmpty {
                Text(verse.storyPaliName)
                    .font(.system(.subheadline, design: .serif))
                    .italic()
                    .foregroundStyle(theme.inkSoft)
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var verseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(theme.tertiary).frame(width: 5, height: 5)
                Text("THE VERSE")
                    .font(.caption2.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(theme.tertiary)
            }
            Text(verse.text)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(theme.ink)
                .lineSpacing(3)
            HStack {
                Spacer()
                Text("Verse \(verse.number) · \(verse.chapterTitle)")
                    .font(.caption)
                    .foregroundStyle(theme.inkMute)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardSoft, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(theme.border, lineWidth: 0.5)
        )
    }

    private var storyBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THE STORY")
                .font(.caption2.weight(.semibold))
                .tracking(1.8)
                .foregroundStyle(theme.inkMute)
                .padding(.leading, 4)
            Text(verse.story)
                .font(.system(size: 15, design: .serif))
                .foregroundStyle(theme.inkSoft)
                .lineSpacing(4)
        }
    }
}
