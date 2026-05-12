import SwiftUI

struct SplashView: View {
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Tradition.secular.substrateGradient,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            VStack(spacing: 24) {
                Lotus(bloom: 1.0)
                    .frame(width: 120, height: 120)
                Text("Faith")
                    .font(.system(size: 48, weight: .ultraLight, design: .serif))
                    .foregroundStyle(.white)
                Text("a daily companion to the canon")
                    .font(.system(size: 13))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.2))
            onComplete()
        }
    }
}
