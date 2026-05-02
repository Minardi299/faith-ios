import SwiftUI

struct StoryDetailView: View {
    let verse: Verse

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verse.storyTitle)
                        .font(.largeTitle.weight(.bold))
                    if !verse.storyPaliName.isEmpty {
                        Text(verse.storyPaliName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                GroupBox {
                    Text(verse.text)
                        .font(.body.weight(.semibold))
                } label: {
                    Label("Verse \(verse.number) · \(verse.chapterTitle)", systemImage: "book")
                        .font(.footnote)
                }
                Text(verse.story)
                    .font(.body)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .navigationTitle("Story")
        .navigationBarTitleDisplayMode(.inline)
    }
}
