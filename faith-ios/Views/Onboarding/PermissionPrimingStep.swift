import SwiftUI
import UserNotifications
import Speech
import AVFAudio

struct PermissionPrimingStep: View {
    @Binding var draft: AppUser
    let onComplete: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: draft.tradition.substrateGradient,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    Text("A few permissions")
                        .font(.system(size: 32, weight: .light, design: .serif))
                        .foregroundStyle(.white)
                    Text("Each one is optional. You can change them later in Settings.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 60)
                .padding(.horizontal, 32)

                VStack(spacing: 14) {
                    permissionRow(
                        title: "Daily passage reminder",
                        subtitle: "A gentle nudge each morning.",
                        action: requestNotifications
                    )
                    permissionRow(
                        title: "Speak to the Teacher",
                        subtitle: "Tap-to-dictate questions on-device.",
                        action: requestSpeech
                    )
                }
                .padding(.horizontal, 24)

                Spacer()

                Button(action: onComplete) {
                    Text("Skip for now")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func permissionRow(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .light, design: .serif))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func requestNotifications() {
        Task {
            let granted = (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            draft.notificationsAllowed = granted
            onComplete()
        }
    }

    private func requestSpeech() {
        Task {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                SFSpeechRecognizer.requestAuthorization { _ in cont.resume() }
            }
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                AVAudioApplication.requestRecordPermission { _ in cont.resume() }
            }
            onComplete()
        }
    }
}
