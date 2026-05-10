import SwiftUI
import SwiftData
@preconcurrency import ActivityKit

/// The Meditate tab. Two states:
/// 1. **Configuring** — pick duration, optional background, optional chant.
///    Tapping a background or chant row also previews it (auto-plays). Pick
///    None to stop. Hit "Begin sit" to commit.
/// 2. **Sitting** — countdown ring + "End sit". Background and chant just
///    keep looping from the preview into the session — no audio gap at start.
struct MeditateView: View {
    @Environment(\.theme) private var theme

    @EnvironmentObject private var session: SessionStore
    @Environment(\.modelContext) private var context
    @StateObject private var chants = ChantPlayer.shared
    @StateObject private var bg = BackgroundPlayer.shared

    @State private var minutes: Int = 10
    @State private var pickedBackground: MeditationBackground? = nil
    @State private var pickedChant: Chant? = nil
    @State private var showChantPicker: Bool = false
    @State private var sitting: Bool = false
    @State private var remaining: Int = 0
    @State private var timer: Timer?
    @State private var sitActivity: Activity<SitActivityAttributes>?

    var body: some View {
        PageScaffold(title: nil) {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    if sitting {
                        activeSitView
                    } else {
                        configCard
                    }
                }
                .padding(.top, 18)
                .padding(.bottom, 80)
            }
        }
        .sheet(isPresented: $showChantPicker) {
            ChantPickerSheet(picked: $pickedChant)
                .environmentObject(session)
        }
        .onDisappear {
            // Stop any preview playback when the user navigates away.
            if !sitting {
                bg.stop()
                chants.stop()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(sitting ? "Sitting" : "Sit").eyebrow()
            Text(.init(sitting ? "Breath. *Quiet.*" : "Breath. Bell. *Quiet.*"))
                .font(BTFont.serif(22, weight: .light))
                .foregroundStyle(theme.ink)
        }
    }

    // MARK: - Configuring

    private var configCard: some View {
        VStack(spacing: 22) {
            durationSection
            if !MeditationBackground.all.isEmpty {
                backgroundSection
            }
            chantSection
            beginButton
        }
        .padding(.horizontal, 18)
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Duration").eyebrow().padding(.horizontal, 4)
            HStack(spacing: 8) {
                ForEach([5, 10, 20, 30], id: \.self) { m in
                    Button {
                        minutes = m
                    } label: {
                        Text("\(m)m")
                            .font(BTFont.ui(13.5, weight: minutes == m ? .regular : .light))
                            .foregroundStyle(minutes == m ? .white : theme.inkSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .glassEffect(minutes == m ? .regular.tint(theme.border) : .regular,
                                          in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Background").eyebrow().padding(.horizontal, 4)
            VStack(spacing: 6) {
                noneRow(isOn: pickedBackground == nil) {
                    pickedBackground = nil
                    bg.stop()
                }
                ForEach(MeditationBackground.all) { b in
                    backgroundRow(b)
                }
            }
        }
    }

    private func backgroundRow(_ b: MeditationBackground) -> some View {
        let isOn = pickedBackground?.id == b.id
        let isPreviewing = bg.currentID == b.id && bg.isPlaying
        return Button {
            if isOn {
                pickedBackground = nil
                bg.stop()
            } else {
                pickedBackground = b
                bg.play(b)
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(b.title)
                        .font(BTFont.serif(16, weight: isOn ? .regular : .light))
                        .foregroundStyle(isOn ? .white : theme.ink)
                    if let r = b.romanised {
                        Text(r)
                            .font(BTFont.serif(11.5, weight: .light, italic: true))
                            .foregroundStyle(theme.inkMute)
                    }
                }
                Spacer()
                if isPreviewing {
                    Image(systemName: "waveform")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(theme.ink)
                        .symbolEffect(.variableColor.iterative)
                }
                checkmark(on: isOn)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(isOn ? .regular.tint(theme.border) : .regular,
                          in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var chantSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Chant").eyebrow().padding(.horizontal, 4)
            Button {
                showChantPicker = true
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pickedChant?.title ?? "None")
                            .font(BTFont.serif(16, weight: pickedChant == nil ? .light : .regular))
                            .foregroundStyle(pickedChant == nil ? theme.inkSoft : .white)
                        Text(pickedChant.map { c in
                            [c.language, c.romanised].compactMap { $0 }.joined(separator: " · ")
                        } ?? "Pick a chant")
                            .font(BTFont.serif(11.5, weight: .light, italic: true))
                            .foregroundStyle(theme.inkMute)
                            .lineLimit(1)
                    }
                    Spacer()
                    if let c = pickedChant, chants.currentID == c.id, chants.isPlaying {
                        Image(systemName: "waveform")
                            .font(.system(size: 13, weight: .light))
                            .foregroundStyle(theme.ink)
                            .symbolEffect(.variableColor.iterative)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(theme.inkMute)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular,
                              in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func noneRow(isOn: Bool, tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            HStack(spacing: 12) {
                Text("None")
                    .font(BTFont.serif(16, weight: isOn ? .regular : .light, italic: !isOn))
                    .foregroundStyle(isOn ? .white : theme.inkSoft)
                Spacer()
                checkmark(on: isOn)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(isOn ? .regular.tint(theme.border) : .regular,
                          in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func checkmark(on: Bool) -> some View {
        if on {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(theme.ink)
        }
    }

    private var beginButton: some View {
        Button(action: beginSit) {
            Text("Begin sit")
                .font(BTFont.ui(14, weight: .regular))
                .tracking(1.5)
                .foregroundStyle(theme.ink)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .glassEffect(.regular.tint(theme.border),
                              in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    // MARK: - Sitting

    private var activeSitView: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle().stroke(theme.border, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: progressFraction)
                    .stroke(theme.ink,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: remaining)
                VStack(spacing: 4) {
                    Text(timeString)
                        .font(BTFont.serif(44, weight: .ultraLight))
                        .foregroundStyle(theme.ink)
                        .monospacedDigit()
                    Text("breathing")
                        .font(BTFont.ui(10, weight: .light))
                        .tracking(2.2)
                        .foregroundStyle(theme.inkMute)
                }
            }
            .frame(width: 220, height: 220)

            VStack(spacing: 4) {
                if let bg = pickedBackground {
                    HStack(spacing: 6) {
                        Image(systemName: bg.icon)
                            .font(.system(size: 10, weight: .light))
                            .foregroundStyle(theme.inkMute)
                        Text(bg.title)
                            .font(BTFont.serif(13, weight: .light, italic: true))
                            .foregroundStyle(theme.inkMute)
                    }
                }
                if let chant = pickedChant {
                    Text(chant.title)
                        .font(BTFont.serif(13, weight: .light, italic: true))
                        .foregroundStyle(theme.inkMute)
                }
                if pickedBackground == nil, pickedChant == nil {
                    Text("silence")
                        .font(BTFont.serif(13, weight: .light, italic: true))
                        .foregroundStyle(theme.inkMute)
                }
            }

            Button(action: endSit) {
                Text("End sit")
                    .font(BTFont.ui(14, weight: .regular))
                    .tracking(1.4)
                    .foregroundStyle(theme.ink)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 13)
                    .glassEffect(.regular, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var progressFraction: Double {
        let total = max(1, minutes * 60)
        let elapsed = Double(total) - Double(remaining)
        return max(0, min(1, elapsed / Double(total)))
    }

    private var timeString: String {
        let secs = max(0, remaining)
        return String(format: "%d:%02d", secs / 60, secs % 60)
    }

    // MARK: - Lifecycle

    private func beginSit() {
        remaining = minutes * 60
        sitting = true
        LiveAudioService.shared.playBell()
        // Background and chant are already previewing if picked; nothing to
        // restart. If they're not picked, no audio. If they're picked but
        // user paused, kick them off.
        if let bg = pickedBackground, !BackgroundPlayer.shared.isPlaying {
            BackgroundPlayer.shared.play(bg)
        }
        if let chant = pickedChant, !ChantPlayer.shared.isPlaying {
            ChantPlayer.shared.play(chant, loop: true)
        }
        startLiveActivity()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in tick() }
        }
    }

    /// Request a Dynamic Island / lock-screen Live Activity for this sit.
    /// Uses `Text(timerInterval:)` on the widget side so the countdown ticks
    /// natively without per-second push updates from the app.
    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let now = Date()
        let endsAt = now.addingTimeInterval(TimeInterval(minutes * 60))
        let state = SitActivityAttributes.State(
            startedAt: now,
            endsAt: endsAt,
            background: pickedBackground?.title,
            chant: pickedChant?.title
        )
        do {
            let activity = try Activity.request(
                attributes: SitActivityAttributes(),
                content: .init(state: state, staleDate: endsAt),
                pushType: nil
            )
            sitActivity = activity
        } catch {
            print("⚠️ Sit live activity failed: \(error)")
        }
    }

    private func endLiveActivity() {
        guard let activity = sitActivity else { return }
        sitActivity = nil
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func tick() {
        guard sitting else { return }
        remaining -= 1
        if remaining <= 0 {
            LiveAudioService.shared.playBell()
            let completed = minutes
            endSit()
            PracticeQueries.recordSit(minutes: completed, in: context)
        }
    }

    private func endSit() {
        let wasSitting = sitting
        timer?.invalidate()
        timer = nil
        sitting = false
        remaining = 0
        BackgroundPlayer.shared.stop()
        ChantPlayer.shared.stop()
        endLiveActivity()
        if wasSitting {
            let progress = ProgressStore(context: context)
            progress.markMeditationDone()
            progress.pushToWidget()
        }
    }
}

// MARK: - ChantPickerSheet

private struct ChantPickerSheet: View {
    @Environment(\.theme) private var theme

    @Binding var picked: Chant?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var chants = ChantPlayer.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14, pinnedViews: []) {
                    noneRow

                    ForEach(groupedChants, id: \.0) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.0.uppercased())
                                .font(BTFont.ui(9.5, weight: .light))
                                .tracking(2)
                                .foregroundStyle(theme.inkMute)
                                .padding(.horizontal, 22)
                                .padding(.top, 6)
                            VStack(spacing: 6) {
                                ForEach(group.1) { chant in
                                    chantRow(chant)
                                }
                            }
                            .padding(.horizontal, 18)
                        }
                    }
                }
                .padding(.top, 14)
                .padding(.bottom, 60)
            }
            .background(Color.black.opacity(0.001))
            .navigationTitle("Chant")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        chants.stop()
                        dismiss()
                    }
                    .font(BTFont.ui(13, weight: .regular))
                    .foregroundStyle(theme.ink)
                }
            }
        }
        .presentationBackground(.thinMaterial)
    }

    private var noneRow: some View {
        Button {
            picked = nil
            chants.stop()
        } label: {
            HStack(spacing: 12) {
                Text("None")
                    .font(BTFont.serif(16, weight: picked == nil ? .regular : .light, italic: picked != nil))
                    .foregroundStyle(picked == nil ? .white : theme.inkSoft)
                Spacer()
                if picked == nil {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(theme.ink)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(picked == nil ? .regular.tint(theme.border) : .regular,
                          in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
    }

    private func chantRow(_ chant: Chant) -> some View {
        let isOn = picked?.id == chant.id
        let isPreviewing = chants.currentID == chant.id && chants.isPlaying
        return Button {
            if isOn {
                picked = nil
                chants.stop()
            } else {
                picked = chant
                chants.play(chant, loop: false)
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(chant.title)
                        .font(BTFont.serif(16, weight: isOn ? .regular : .light))
                        .foregroundStyle(isOn ? .white : theme.ink)
                    if let r = chant.romanised {
                        Text(r)
                            .font(BTFont.serif(11.5, weight: .light, italic: true))
                            .foregroundStyle(theme.inkMute)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if isPreviewing {
                    Image(systemName: "waveform")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(theme.ink)
                        .symbolEffect(.variableColor.iterative)
                }
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(theme.ink)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(isOn ? .regular.tint(theme.border) : .regular,
                          in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var groupedChants: [(String, [Chant])] {
        var seen: [String] = []
        var byLang: [String: [Chant]] = [:]
        for c in Chant.all {
            if byLang[c.language] == nil { seen.append(c.language) }
            byLang[c.language, default: []].append(c)
        }
        return seen.map { ($0, byLang[$0] ?? []) }
    }
}
