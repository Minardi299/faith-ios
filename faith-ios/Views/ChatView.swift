import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ChatMessage.createdAt, order: .forward) private var messages: [ChatMessage]
    @State private var draft: String = ""
    @State private var isSending = false
    @FocusState private var composerFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if messages.isEmpty {
                            greeting
                        }
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        if isSending {
                            HStack {
                                ProgressView()
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .top, spacing: 0) {
                Text("AI companion")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }
            .safeAreaInset(edge: .bottom) {
                composer
            }
            .profileToolbar()
        }
    }

    private var greeting: some View {
        HStack {
            Text("Hi, I'm here to listen and walk with you. What's on your heart today?")
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                .frame(maxWidth: .infinity * 0.8, alignment: .leading)
            Spacer(minLength: 40)
        }
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("Message", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground), in: Capsule())
                .focused($composerFocused)
            Button {
                Task { await send() }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor, in: Circle())
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
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
                content: "(placeholder) I'd offer a reflection here once the AI is wired up."
            ))
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.roleValue == .user { Spacer(minLength: 40) }
            Text(message.content)
                .padding(12)
                .background(
                    message.roleValue == .user ? Color.accentColor : Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 18)
                )
                .foregroundStyle(message.roleValue == .user ? .white : .primary)
            if message.roleValue != .user { Spacer(minLength: 40) }
        }
    }
}
