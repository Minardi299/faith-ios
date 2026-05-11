import SwiftUI

enum AppTab: Hashable {
    case today, practice, library, chat
}

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("palette") private var paletteRaw: String = Palette.moss.rawValue
    @AppStorage("appearance") private var appearanceRaw: String = AppearanceMode.system.rawValue
    @State private var selection: AppTab = .today
    @State private var deepLinkPassageID: String?
    @State private var showSplash: Bool = true

    private var palette: Palette { Palette(rawValue: paletteRaw) ?? .moss }
    private var appearance: AppearanceMode { AppearanceMode(rawValue: appearanceRaw) ?? .system }
    private var effectiveScheme: ColorScheme { appearance.preferredScheme ?? colorScheme }
    private var theme: Theme { palette.theme(for: effectiveScheme) }

    var body: some View {
        ZStack {
            mainTabs
            if showSplash {
                SplashView { showSplash = false }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 0.3), value: showSplash)
        .dynamicTypeSize(.xSmall ... .accessibility5)
        .tint(theme.accent)
        .environment(\.theme, theme)
        .preferredColorScheme(appearance.preferredScheme)
        .task(id: paletteRaw + appearanceRaw) {
            SharedProgress.writeAppearance(palette: paletteRaw, appearance: appearanceRaw)
        }
        .onOpenURL { url in
            guard url.scheme == "faith" else { return }
            switch url.host {
            case "today":    selection = .today
            case "practice": selection = .practice
            case "library":  selection = .library
            case "chat":     selection = .chat
            case "passage":
                if let id = url.pathComponents.dropFirst().first {
                    deepLinkPassageID = id
                    selection = .library
                }
            default: selection = .today
            }
        }
    }

    private var mainTabs: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "house.fill", value: AppTab.today) {
                TodayView(selectedTab: $selection)
            }
            Tab("Practice", systemImage: "sun.max.fill", value: AppTab.practice) {
                MeditateView()
            }
            Tab("Library", systemImage: "book.fill", value: AppTab.library) {
                LibraryView(deepLinkPassageID: $deepLinkPassageID)
            }
            Tab("Teacher", systemImage: "bubble.left.fill", value: AppTab.chat, role: .search) {
                ChatView()
            }
        }
        .overlay(alignment: .bottom) {
            MiniPlayerBar()
                .padding(.bottom, 64)
                .environment(\.theme, theme)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PersistenceContainer.shared)
}
