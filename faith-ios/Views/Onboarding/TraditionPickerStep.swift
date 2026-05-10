import SwiftUI

struct TraditionPickerStep: View {
    @Binding var draft: AppUser
    let onContinue: () -> Void

    @Environment(\.theme) private var theme
    @State private var picked: Tradition?

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: (picked ?? .secular).substrateGradient,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: picked)

            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Begin where you are")
                        .font(.system(size: 32, weight: .light, design: .serif))
                        .foregroundStyle(.white)
                    Text("Pick a tradition to shape today's reading. You can change this any time.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 60)
                .padding(.horizontal, 32)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Tradition.allCases) { t in
                            traditionRow(t)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Button {
                    if let p = picked {
                        draft.tradition = p
                        onContinue()
                    }
                } label: {
                    Text("Continue")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(picked == nil ? .white.opacity(0.5) : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(picked == nil ? Color.white.opacity(0.15) : Color.white.opacity(0.25), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(picked == nil)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func traditionRow(_ t: Tradition) -> some View {
        Button { picked = t } label: {
            HStack(spacing: 12) {
                Circle().fill(t.accent).frame(width: 12, height: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.name)
                        .font(.system(size: 17, weight: .light, design: .serif))
                        .foregroundStyle(.white)
                    Text(t.pali)
                        .font(.system(size: 12).italic())
                        .foregroundStyle(.white.opacity(0.7))
                    Text(t.blurb)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: picked == t ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(picked == t ? .white : .white.opacity(0.4))
            }
            .padding(14)
            .background(
                picked == t ? Color.white.opacity(0.18) : Color.white.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}
