import SwiftUI
import SwiftData

struct MeditationTimerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var durationMinutes: Int = 5
    @State private var remainingSeconds: Int? = nil
    @State private var isRunning = false
    @State private var didComplete = false
    @State private var showingDurationPicker = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var totalSeconds: Int { durationMinutes * 60 }

    private var progress: Double {
        guard let r = remainingSeconds else { return 0 }
        return 1.0 - (Double(r) / Double(totalSeconds))
    }

    private var displayTime: String {
        let secs = remainingSeconds ?? totalSeconds
        return String(format: "%d:%02d", secs / 60, secs % 60)
    }

    var body: some View {
        VStack(spacing: 28) {
            header
            countdownRing
            controls
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
        .presentationBackground(theme.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Sit")
                    .font(.system(size: 17, design: .serif))
                    .foregroundStyle(theme.ink)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { finishAndDismiss() }
                    .foregroundStyle(theme.accent)
            }
        }
        .onReceive(ticker) { _ in tick() }
        .onDisappear { stopAudio() }
        .alert("Settled.", isPresented: $didComplete) {
            Button("Done") { dismiss() }
        } message: {
            Text("Your sit is marked for today.")
        }
        .sheet(isPresented: $showingDurationPicker) {
            durationPickerSheet
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.bg)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text(remainingSeconds == nil ? "CHOOSE YOUR DURATION" : "BREATHE")
                .font(.caption2.weight(.semibold))
                .tracking(2.4)
                .foregroundStyle(theme.inkMute)
            if remainingSeconds == nil {
                Button {
                    showingDurationPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Text("\(durationMinutes) min")
                            .font(.system(size: 36, weight: .regular, design: .serif))
                            .foregroundStyle(theme.accent)
                        Image(systemName: "chevron.down")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.accent.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
                Text("Tap to adjust")
                    .font(.caption)
                    .italic()
                    .foregroundStyle(theme.inkMute)
            } else {
                Text("Settle into stillness")
                    .font(.system(size: 17, design: .serif))
                    .italic()
                    .foregroundStyle(theme.inkSoft)
            }
        }
        .padding(.top, 8)
    }

    private var countdownRing: some View {
        ZStack {
            Circle()
                .stroke(theme.cardSoft, lineWidth: 14)
            Circle()
                .trim(from: 0, to: max(progress, 0.0001))
                .stroke(theme.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
            Text(displayTime)
                .font(.system(size: 56, weight: .regular, design: .serif).monospacedDigit())
                .foregroundStyle(theme.ink)
                .contentTransition(.numericText())
        }
        .frame(width: 240, height: 240)
        .padding(.vertical, 8)
    }

    private var controls: some View {
        HStack(spacing: 24) {
            Button {
                stop()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title3)
                    .foregroundStyle(theme.ink)
                    .frame(width: 56, height: 56)
                    .background(theme.cardSoft, in: Circle())
                    .overlay(Circle().stroke(theme.border, lineWidth: 0.5))
            }
            .disabled(remainingSeconds == nil)
            .opacity(remainingSeconds == nil ? 0.4 : 1)

            Button {
                toggle()
            } label: {
                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(theme.accent, in: Circle())
                    .shadow(color: theme.accent.opacity(0.35), radius: 10, y: 4)
            }
        }
    }

    private var durationPickerSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Duration")
                    .font(.system(size: 17, design: .serif))
                    .foregroundStyle(theme.ink)
                Spacer()
                Button("Done") { showingDurationPicker = false }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.accent)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            Picker("Minutes", selection: $durationMinutes) {
                ForEach(1...60, id: \.self) { m in
                    Text("\(m) min")
                        .font(.system(size: 22, design: .serif))
                        .foregroundStyle(theme.ink)
                        .tag(m)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            Spacer(minLength: 0)
        }
        .background(theme.bg)
    }

    private func toggle() {
        if remainingSeconds == nil {
            remainingSeconds = totalSeconds
        }
        isRunning.toggle()
        if isRunning {
            MeditationAudio.shared.play()
        } else {
            MeditationAudio.shared.pause()
        }
    }

    private func tick() {
        guard isRunning, var r = remainingSeconds else { return }
        r -= 1
        if r <= 0 {
            remainingSeconds = 0
            complete()
        } else {
            remainingSeconds = r
        }
    }

    private func stop() {
        isRunning = false
        remainingSeconds = nil
        stopAudio()
    }

    private func complete() {
        isRunning = false
        stopAudio()
        ProgressStore(context: context).markMeditationDone()
        didComplete = true
    }

    private func finishAndDismiss() {
        stopAudio()
        dismiss()
    }

    private func stopAudio() {
        MeditationAudio.shared.stop()
    }
}

#Preview {
    NavigationStack {
        MeditationTimerView()
    }
    .modelContainer(for: [DayCompletion.self, ChatMessage.self], inMemory: true)
    .environment(\.theme, .mossDusk)
}
