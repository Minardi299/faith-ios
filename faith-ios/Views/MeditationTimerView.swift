import SwiftUI
import SwiftData

struct MeditationTimerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var durationSeconds: Int = 300
    @State private var remainingSeconds: Int? = nil
    @State private var isRunning = false
    @State private var didComplete = false

    private let durationOptions: [Int] = [10, 60, 300, 600, 900, 1200, 1800]
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var totalSeconds: Int { durationSeconds }

    private func label(for seconds: Int) -> String {
        seconds < 60 ? "\(seconds)s" : "\(seconds / 60)m"
    }

    private var progress: Double {
        guard let r = remainingSeconds else { return 0 }
        return 1.0 - (Double(r) / Double(totalSeconds))
    }

    private var displayTime: String {
        let secs = remainingSeconds ?? totalSeconds
        return String(format: "%d:%02d", secs / 60, secs % 60)
    }

    var body: some View {
        VStack(spacing: 32) {
            if remainingSeconds == nil {
                durationPicker
            } else {
                Text("Settle in")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            countdownRing

            controls

            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.top, 24)
        .navigationTitle("Meditation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { finishAndDismiss() }
            }
        }
        .onReceive(ticker) { _ in tick() }
        .onDisappear { stopAudio() }
        .alert("Meditation complete", isPresented: $didComplete) {
            Button("Done") { dismiss() }
        } message: {
            Text("Marked as done for today.")
        }
    }

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Duration")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Picker("Duration", selection: $durationSeconds) {
                ForEach(durationOptions, id: \.self) { d in
                    Text(label(for: d)).tag(d)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var countdownRing: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 14)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
            Text(displayTime)
                .font(.system(size: 56, weight: .light, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())
        }
        .frame(width: 240, height: 240)
        .padding(.vertical, 12)
    }

    private var controls: some View {
        HStack(spacing: 24) {
            Button {
                stop()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .frame(width: 56, height: 56)
                    .background(Color(.secondarySystemBackground), in: Circle())
            }
            .disabled(remainingSeconds == nil)

            Button {
                toggle()
            } label: {
                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(Color.accentColor, in: Circle())
            }
        }
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
}
