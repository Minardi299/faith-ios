import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @Query(sort: \ChatMessage.createdAt, order: .forward) private var messages: [ChatMessage]
    @State private var draft: String = ""
    @State private var isSending = false
    @FocusState private var composerFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                teacherHeader
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            timestamp
                            if messages.isEmpty {
                                teacherBubble("Welcome. What arises in you this morning — what would you like to sit with?")
                            }
                            ForEach(messages) { message in
                                if message.roleValue == .user {
                                    userBubble(message.content).id(message.id)
                                } else {
                                    teacherBubble(message.content).id(message.id)
                                }
                            }
                            if isSending {
                                HStack {
                                    ProgressView().tint(theme.accent)
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }
                    .onChange(of: messages.count) {
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }
            .background(theme.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { EmptyView() } }
            .safeAreaInset(edge: .bottom) {
                composer
            }
            .profileToolbar()
        }
    }

    private var teacherHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(theme.cardSoft)
                    .overlay(Circle().stroke(theme.border, lineWidth: 0.5))
                Image(systemName: "circle")
                    .font(.title3.weight(.light))
                    .foregroundStyle(theme.secondary)
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Ācāriya")
                    .font(.system(size: 17, design: .serif))
                    .foregroundStyle(theme.ink)
                HStack(spacing: 6) {
                    Circle().fill(theme.accent).frame(width: 5, height: 5)
                    Text("your teacher · listening")
                        .font(.caption)
                        .foregroundStyle(theme.inkMute)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.border)
                .frame(height: 0.5)
                .padding(.horizontal, 24)
        }
    }

    private var timestamp: some View {
        Text(Date.now.formatted(.dateTime.hour().minute()).uppercased())
            .font(.caption2)
            .tracking(1.4)
            .foregroundStyle(theme.inkMute)
            .padding(.vertical, 6)
    }

    private func teacherBubble(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 14.5, design: .serif))
                .foregroundStyle(theme.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 4,
                        bottomLeadingRadius: 18,
                        bottomTrailingRadius: 18,
                        topTrailingRadius: 18
                    )
                    .fill(theme.card)
                )
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 4,
                        bottomLeadingRadius: 18,
                        bottomTrailingRadius: 18,
                        topTrailingRadius: 18
                    )
                    .stroke(theme.border, lineWidth: 0.5)
                )
            Spacer(minLength: 40)
        }
    }

    private func userBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 40)
            Text(text)
                .font(.system(size: 14.5, design: .serif))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 18,
                        bottomLeadingRadius: 18,
                        bottomTrailingRadius: 18,
                        topTrailingRadius: 4
                    )
                    .fill(theme.accent)
                )
                .shadow(color: theme.accent.opacity(0.3), radius: 4, y: 2)
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Speak your mind…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14, design: .serif))
                .italic()
                .lineLimit(1...5)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(theme.cardSoft, in: Capsule())
                .overlay(Capsule().stroke(theme.border, lineWidth: 0.5))
                .focused($composerFocused)
            Button {
                Task { await send() }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(theme.accent, in: Circle())
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(theme.bg)
    }

    private func send() async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let userMessage = ChatMessage(role: .user, content: trimmed)
        context.insert(userMessage)
        draft = ""
        isSending = true
        defer { isSending = false }

        let history = messages + [userMessage]
        do {
            let reply = try await AIService.shared.reply(to: history)
            context.insert(ChatMessage(role: .assistant, content: reply))
        } catch {
            context.insert(ChatMessage(
                role: .assistant,
                content: "Resistance is not the obstacle — it is the doorway. Sit with it for three breaths, then return."
            ))
        }
    }
}
