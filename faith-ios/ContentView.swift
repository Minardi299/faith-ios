import SwiftUI

enum AppTab: Hashable {
    case home, daily, stories, chat
}

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("palette") private var paletteRaw: String = Palette.moss.rawValue
    @State private var selection: AppTab = .home
    @State private var verseStore = VerseStore()

    private var palette: Palette { Palette(rawValue: paletteRaw) ?? .moss }
    private var theme: Theme { palette.theme(for: colorScheme) }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "house.fill", value: AppTab.home) {
                HomeView(selectedTab: $selection)
            }
            Tab("Practice", systemImage: "sun.max.fill", value: AppTab.daily) {
                DailyView()
            }
            Tab("Stories", systemImage: "book.fill", value: AppTab.stories) {
                StoriesView()
            }
            Tab("Teacher", systemImage: "bubble.left.fill", value: AppTab.chat, role: .search) {
                ChatView()
            }
        }
        .tint(theme.accent)
        .environment(verseStore)
        .environment(\.theme, theme)
        .onOpenURL { url in
            guard url.scheme == "faith" else { return }
            switch url.host {
            case "daily": selection = .daily
            case "stories": selection = .stories
            case "chat": selection = .chat
            default: selection = .home
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [DayCompletion.self, ChatMessage.self], inMemory: true)
}
