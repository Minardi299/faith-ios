import SwiftUI

/// Self-contained sit timer with a circular ring countdown, configurable
/// minutes, and bell at start + end via the existing `LiveAudioService`.
/// Used by both Meditate (full-screen) and Today (compact) once hoisted.
struct SitTimer: View {
    @State private var minutes: Int
    @State private var remaining: Int = 0
    @State private var isRunning: Bool = false
    @State private var startedAt: Date?
    @State private var timer: Timer?

    @Environment(\.theme) private var theme
    private let audio = LiveAudioService.shared
    private let allowMinuteEdit: Bool
    private let onCompleted: ((Int) -> Void)?

    /// - Parameter minutes: starting duration. Defaults to 10.
    /// - Parameter allowMinuteEdit: when true (Meditate tab), the user can
    ///   pick 5/10/20/30 before starting. When false (Plan day), the
    ///   minutes are fixed by the plan.
    /// - Parameter onCompleted: fires when the timer reaches 0 (not on End).
    init(minutes: Int = 10,
         allowMinuteEdit: Bool = true,
         onCompleted: ((Int) -> Void)? = nil) {
        self._minutes = State(initialValue: minutes)
        self.allowMinuteEdit = allowMinuteEdit
        self.onCompleted = onCompleted
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(theme.border, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: progressFraction)
                    .stroke(theme.ink, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: remaining)

                VStack(spacing: 4) {
                    Text(timeString)
                        .font(BTFont.serif(40, weight: .light))
                        .foregroundStyle(theme.ink)
                        .monospacedDigit()
                    Text(isRunning ? "sitting" : "ready")
                        .font(BTFont.ui(10, weight: .light))
                        .tracking(2)
                        .foregroundStyle(theme.inkMute)
                }
            }
            .frame(width: 180, height: 180)

            if !isRunning, allowMinuteEdit {
                HStack(spacing: 8) {
                    ForEach([5, 10, 20, 30], id: \.self) { m in
                        Button {
                            minutes = m
                        } label: {
                            Text("\(m)m")
                                .font(BTFont.ui(13, weight: minutes == m ? .regular : .light))
                                .foregroundStyle(minutes == m ? .white : theme.inkMute)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .glassEffect(minutes == m ? .regular.tint(theme.border) : .regular,
                                             in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button(action: toggle) {
                Text(isRunning ? "End sit" : "Begin sit")
                    .font(BTFont.ui(14, weight: .regular))
                    .tracking(1.4)
                    .foregroundStyle(theme.ink)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .glassEffect(.regular, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .onDisappear { teardown() }
    }

    private var progressFraction: Double {
        let total = max(1, minutes * 60)
        let elapsed = Double(total) - Double(remaining)
        return max(0, min(1, elapsed / Double(total)))
    }

    private var timeString: String {
        let secs = max(0, isRunning ? remaining : minutes * 60)
        let m = secs / 60
        let s = secs % 60
        return String(format: "%d:%02d", m, s)
    }

    private func toggle() {
        if isRunning { teardown() } else { begin() }
    }

    private func begin() {
        remaining = minutes * 60
        startedAt = Date()
        isRunning = true
        audio.playBell()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in tick() }
        }
    }

    private func tick() {
        guard isRunning else { return }
        remaining -= 1
        if remaining <= 0 {
            audio.playBell()
            let completed = minutes
            teardown()
            onCompleted?(completed)
        }
    }

    private func teardown() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        remaining = 0
    }
}
