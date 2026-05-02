import SwiftUI

enum AppTab: Hashable {
    case home, daily, stories, chat
}

struct ContentView: View {
    @State private var selection: AppTab = .home
    @State private var verseStore = VerseStore()

    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                HomeView(selectedTab: $selection)
            }
            Tab("Daily", systemImage: "sun.max.fill", value: AppTab.daily) {
                DailyView()
            }
            Tab("Stories", systemImage: "book.fill", value: AppTab.stories) {
                StoriesView()
            }
            Tab("Chat", systemImage: "bubble.left.fill", value: AppTab.chat, role: .search) {
                ChatView()
            }
        }
        .environment(verseStore)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [DayCompletion.self, ChatMessage.self], inMemory: true)
}
