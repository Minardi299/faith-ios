import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @AppStorage("palette") private var paletteRaw: String = Palette.moss.rawValue
    @Query private var completions: [DayCompletion]

    private var progress: ProgressStore { ProgressStore(context: context) }
    private var totalCompleted: Int { completions.filter(\.isComplete).count }

    var body: some View {
        Form {
            Section {
                LabeledContent("Now") {
                    HStack(spacing: 6) {
                        Lotus(size: 18, bloom: 1, color: theme.accent, dim: theme.inkFaint)
                        Text("\(progress.currentStreak()) days")
                            .foregroundStyle(theme.accent)
                    }
                }
                LabeledContent("In total", value: "\(totalCompleted) days")
            }

            Section("Palette") {
                ForEach(Palette.allCases) { palette in
                    Button {
                        paletteRaw = palette.rawValue
                    } label: {
                        HStack(spacing: 12) {
                            paletteSwatch(palette)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(palette.displayName)
                                    .font(.system(size: 15, design: .serif))
                                    .foregroundStyle(.primary)
                                Text(palette.tagline)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if palette.rawValue == paletteRaw {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(theme.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Practice") {
                NavigationLink("Reminder time") { Text("Reminder time settings") }
                NavigationLink("Daily verse") { Text("Daily verse settings") }
                NavigationLink("Tradition") { Text("Tradition settings") }
            }

            Section("Reading") {
                NavigationLink("Appearance") { Text("Appearance settings") }
                NavigationLink("Text size") { Text("Text size settings") }
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
    }

    private func paletteSwatch(_ palette: Palette) -> some View {
        let dusk = palette.theme(for: .dark)
        return HStack(spacing: -6) {
            Circle().fill(dusk.accent).frame(width: 18, height: 18)
            Circle().fill(dusk.secondary).frame(width: 18, height: 18)
            Circle().fill(dusk.tertiary).frame(width: 18, height: 18)
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
