import SwiftUI

struct QueueSheet: View {
    @StateObject private var store = ListenQueueStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            List {
                if let current = store.current {
                    Section("Now playing") {
                        QueueRow(item: current, isPlaying: true) { /* tap = no-op for current */ }
                    }
                }
                if !store.queue.isEmpty {
                    Section("Up next") {
                        ForEach(Array(store.queue.enumerated()), id: \.offset) { _, item in
                            QueueRow(item: item, isPlaying: false) { /* tap-to-skip not yet exposed by ListenQueueStore */ }
                        }
                    }
                }
                if !store.history.isEmpty {
                    Section("Recently played") {
                        ForEach(Array(store.history.enumerated()), id: \.offset) { _, item in
                            QueueRow(item: item, isPlaying: false) { /* tap-to-replay not yet exposed by ListenQueueStore */ }
                        }
                    }
                }
            }
            .navigationTitle("Listen queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct QueueRow: View {
    let item: PlayableItem
    let isPlaying: Bool
    let onTap: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isPlaying ? "speaker.wave.2.fill" : "play.fill")
                .font(.system(size: 12))
                .foregroundStyle(isPlaying ? theme.accent : theme.inkMute)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayTitle).font(.system(size: 14, design: .serif))
                Text(item.displaySubtitle).font(.system(size: 11)).foregroundStyle(theme.inkMute)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
