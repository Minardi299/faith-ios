import SwiftUI

struct StoriesView: View {
    @Environment(VerseStore.self) private var verseStore

    private var todaysVerse: Verse? { verseStore.verse(for: .now) }

    private var library: [Verse] {
        var seen = Set<String>()
        return verseStore.verses.filter { seen.insert($0.storyTitle).inserted }
    }

    var body: some View {
        NavigationStack {
            List {
                if let verse = todaysVerse {
                    Section {
                        NavigationLink(value: verse) {
                            featuredCard(verse)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                Section("Library") {
                    ForEach(library) { verse in
                        NavigationLink(value: verse) {
                            libraryRow(verse)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Stories")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .top, spacing: 0) {
                Text("Tales behind the verses of the Dhammapada")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }
            .navigationDestination(for: Verse.self) { verse in
                StoryDetailView(verse: verse)
            }
            .profileToolbar()
        }
    }

    private func featuredCard(_ verse: Verse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TODAY")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(verse.storyTitle)
                .font(.title2.weight(.bold))
            Text(verse.story)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Label("Verse \(verse.number) · \(verse.chapterTitle)", systemImage: "book")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func libraryRow(_ verse: Verse) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(verse.number)")
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(verse.storyTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text([verse.chapterTitle, verse.storyPaliName].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
