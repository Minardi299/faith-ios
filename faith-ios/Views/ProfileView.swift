import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @AppStorage("palette") private var paletteRaw: String = Palette.moss.rawValue
    @AppStorage("appearance") private var appearanceRaw: String = AppearanceMode.system.rawValue
    @Query private var completions: [DayCompletion]

    private var progress: ProgressStore { ProgressStore(context: context) }
    private var totalCompleted: Int { completions.filter(\.isComplete).count }
    private var palette: Palette { Palette(rawValue: paletteRaw) ?? .moss }
    private var appearance: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceRaw) ?? .system }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                statsRow
                section("Appearance") { appearanceSection }
                section("Palette") { paletteSection }
                section("Practice") { practiceSection }
                section("Reading") { readingSection }
                section("About") { aboutSection }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(theme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Profile")
                    .font(.system(size: 17, design: .serif))
                    .foregroundStyle(theme.ink)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            statTile("Now", "\(progress.currentStreak())", "days", isAccent: true)
            statTile("In total", "\(totalCompleted)", "days", isAccent: false)
        }
        .padding(.top, 8)
    }

    private func statTile(_ label: String, _ value: String, _ sub: String, isAccent: Bool) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(theme.inkMute)
            Text(value)
                .font(.system(size: 28, weight: .regular, design: .serif).monospacedDigit())
                .foregroundStyle(isAccent ? theme.accent : theme.ink)
            Text(sub)
                .font(.system(size: 11, design: .serif))
                .italic()
                .foregroundStyle(theme.inkMute)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(theme.border, lineWidth: 0.5)
        )
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1.8)
                .foregroundStyle(theme.inkMute)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                content()
            }
            .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(theme.border, lineWidth: 0.5)
            )
        }
    }

    private var appearanceSection: some View {
        HStack(spacing: 8) {
            ForEach(AppearanceMode.allCases) { mode in
                Button {
                    withAnimation(.snappy) { appearanceRaw = mode.rawValue }
                } label: {
                    Text(mode.label)
                        .font(.system(size: 14, design: .serif))
                        .foregroundStyle(mode.rawValue == appearanceRaw ? .white : theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            mode.rawValue == appearanceRaw
                            ? AnyShapeStyle(theme.accent)
                            : AnyShapeStyle(Color.clear),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
    }

    private var paletteSection: some View {
        ForEach(Array(Palette.allCases.enumerated()), id: \.element.id) { index, p in
            Button {
                withAnimation(.snappy) { paletteRaw = p.rawValue }
            } label: {
                HStack(spacing: 12) {
                    paletteSwatch(p)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.displayName)
                            .font(.system(size: 15, design: .serif))
                            .foregroundStyle(theme.ink)
                        Text(p.tagline)
                            .font(.caption)
                            .foregroundStyle(theme.inkMute)
                    }
                    Spacer()
                    if p.rawValue == paletteRaw {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.accent)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if index < Palette.allCases.count - 1 {
                Divider().background(theme.border).padding(.leading, 56)
            }
        }
    }

    private var practiceSection: some View {
        VStack(spacing: 0) {
            settingsRow("Reminder time", detail: "6:30 am")
            Divider().background(theme.border).padding(.leading, 18)
            settingsRow("Daily verse", detail: "On")
            Divider().background(theme.border).padding(.leading, 18)
            settingsRow("Tradition", detail: "Theravāda")
        }
    }

    private var readingSection: some View {
        VStack(spacing: 0) {
            settingsRow("Text size", detail: "Medium")
        }
    }

    private var aboutSection: some View {
        settingsRow("Version", detail: appVersion, showsChevron: false)
    }

    private func settingsRow(_ label: String, detail: String, showsChevron: Bool = true) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, design: .serif))
                .foregroundStyle(theme.ink)
            Spacer()
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(theme.inkMute)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.inkFaint)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func paletteSwatch(_ p: Palette) -> some View {
        let dusk = p.theme(for: .dark)
        return HStack(spacing: -6) {
            Circle().fill(dusk.accent).frame(width: 18, height: 18)
                .overlay(Circle().stroke(theme.bg, lineWidth: 1))
            Circle().fill(dusk.secondary).frame(width: 18, height: 18)
                .overlay(Circle().stroke(theme.bg, lineWidth: 1))
            Circle().fill(dusk.tertiary).frame(width: 18, height: 18)
                .overlay(Circle().stroke(theme.bg, lineWidth: 1))
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
