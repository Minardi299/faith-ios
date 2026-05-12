import SwiftUI

struct MiniPlayerBar: View {
    @ObservedObject private var queue = ListenQueueStore.shared
    @State private var showQueue = false
    @Environment(\.theme) private var theme

    var body: some View {
        if let current = queue.current {
            HStack(spacing: 12) {
                Button { queue.togglePlayPause() } label: {
                    Image(systemName: queue.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(theme.ink)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(queue.isPlaying ? "Pause" : "Play")

                VStack(alignment: .leading, spacing: 1) {
                    Text(current.displayTitle)
                        .font(.system(size: 13, design: .serif))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                    Text(current.displaySubtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.inkMute)
                        .lineLimit(1)
                }
                Spacer()
                Button { showQueue = true } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.inkSoft)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Queue")
                Button { queue.stop() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.inkMute)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: Capsule())
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            .sheet(isPresented: $showQueue) {
                QueueSheet().presentationDragIndicator(.visible)
            }
        }
    }
}
