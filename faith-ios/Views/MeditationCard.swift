import SwiftUI

struct MeditationCard: View {
    let isDone: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Label("MEDITATION · 5 MIN", systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .labelStyle(.titleAndIcon)
                Text("Take a quiet moment to settle.")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                HStack {
                    Spacer()
                    Image(systemName: isDone ? "checkmark" : "arrow.up.right")
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 36, height: 36)
                        .background(.white, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
