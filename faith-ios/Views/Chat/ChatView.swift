import SwiftUI
import SwiftData
import UIKit

struct ChatView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme

    @State private var messages: [ChatMessage] = []
    @State private var draft: String = ""
    @State private var isAwaitingFirstToken: Bool = false
    @State private var isStreaming: Bool = false
    @State private var openSutta: SuttaPassage?
    @State private var thread: StoredChatThread?
    @State private var showClearConfirm: Bool = false
    @State private var streamTask: Task<Void, Never>? = nil

    private var usedFallback: Bool {
        (session.llm as? FoundationModelsRuntime)?.lastReplyUsedFallback ?? false
    }

    var body: some View {
        PageScaffold(title: nil, trailing: clearChatButton) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 22) {
                        if messages.isEmpty {
                            EmptyChatPrompt()
                                .padding(.top, 40)
                        }
                        ForEach(messages) { msg in
                            MessageRow(
                                message: msg,
                                onCite: { cite in
                                    if let p = CanonStore.shared.passage(byID: cite.suttaID) {
                                        openSutta = p
                                    } else if let p = SeedContent.sutta(byID: cite.suttaID) {
                                        openSutta = p
                                    }
                                },
                                onContinue: { interceptedID in
                                    continueAfterIntercept(interceptedMessageID: interceptedID)
                                },
                                onEnd: endConversation
                            )
                            .id(msg.id)
                        }
                        if isAwaitingFirstToken {
                            HStack { ThinkingDot(); Spacer() }
                                .padding(.horizontal, 22)
                        } else if isStreaming {
                            HStack { StreamingCaret(); Spacer() }
                        }
                    }
                    .padding(.top, 14)
                    .padding(.bottom, 120)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation(.easeOut(duration: 0.5)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            if usedFallback, !messages.isEmpty {
                Text("Showing canon excerpts — Apple Intelligence not available on this device.")
                    .font(BTFont.ui(11))
                    .tracking(0.6)
                    .foregroundStyle(theme.inkMute)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 8)
            }
            Composer(text: $draft, onSend: send)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
        }
        .sheet(item: $openSutta) { passage in
            SuttaDetailSheet(passage: passage)
                .presentationDragIndicator(.visible)
        }
        .alert("Clear conversation?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) { clearChat() }
        } message: {
            Text("This deletes every message in this thread. The chat starts fresh.")
        }
        .onAppear {
            loadThreadIfNeeded()
        }
    }

    private var clearChatButton: AnyView {
        AnyView(
            Button {
                showClearConfirm = true
            } label: {
                Image(systemName: "eraser")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(.white.opacity(messages.isEmpty ? 0.25 : 0.7))
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(messages.isEmpty)
        )
    }

    private func clearChat() {
        streamTask?.cancel()
        streamTask = nil
        isAwaitingFirstToken = false
        isStreaming = false
        if let t = thread {
            ChatStore.clear(t, in: context)
        }
        messages = []
    }

    private func continueAfterIntercept(interceptedMessageID: UUID) {
        guard let interceptIdx = messages.firstIndex(where: { $0.id == interceptedMessageID }) else { return }
        let userMessage = messages[..<interceptIdx].last(where: { $0.role == .user })
        guard let originalText = userMessage?.segments.first?.plainText else { return }

        // Remove the intercept card from in-memory list AND from the persisted
        // thread, so the LLM doesn't see it in `history` and the user doesn't
        // see it linger in the transcript.
        let intercept = messages[interceptIdx]
        messages.remove(at: interceptIdx)
        if let t = thread,
           let stored = t.messages.first(where: { $0.messageID == intercept.id }) {
            context.delete(stored)
            try? context.save()
        }

        // Stream a fresh reply using the original user prompt. History is
        // already correct (intercept card was just removed; original user
        // message is the last entry).
        streamReply(to: originalText)
    }

    private func endConversation() {
        streamTask?.cancel()
        streamTask = nil
        isAwaitingFirstToken = false
        isStreaming = false
        if let t = thread {
            ChatStore.clear(t, in: context)
        }
        messages = []
    }

    private func loadThreadIfNeeded() {
        guard thread == nil else { return }
        let t = ChatStore.currentThread(in: context)
        thread = t
        messages = ChatStore.sortedMessages(t).map(\.asChatMessage)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let user = ChatMessage.user(text)
        messages.append(user)
        draft = ""
        if let t = thread {
            ChatStore.append(user, to: t, in: context)
        }

        if CrisisClassifier.detects(in: text) {
            let reminder = ChatMessage(role: .assistant,
                                       kind: .gentleReminder,
                                       segments: [.text(CrisisClassifier.interceptMessage)])
            messages.append(reminder)
            if let t = thread {
                ChatStore.append(reminder, to: t, in: context)
            }
            return
        }

        streamReply(to: text)
    }

    private func streamReply(to text: String) {
        streamTask?.cancel()
        streamTask = Task {
            isAwaitingFirstToken = true
            isStreaming = false
            // Stream the assistant message — first emission appends a new
            // message; subsequent emissions update its segments in place.
            // Persist only the FINAL emission to SwiftData.
            var assistantID: UUID? = nil
            var lastSegments: [MessageSegment] = []
            for await segments in session.llm.streamReply(
                to: text,
                tradition: .secular,
                history: messages
            ) {
                if Task.isCancelled {
                    isAwaitingFirstToken = false
                    isStreaming = false
                    return
                }
                if isAwaitingFirstToken {
                    isAwaitingFirstToken = false
                    isStreaming = true
                }
                lastSegments = segments
                if let id = assistantID, let idx = messages.firstIndex(where: { $0.id == id }) {
                    messages[idx] = ChatMessage(id: id, role: .assistant, segments: segments)
                } else {
                    let msg = ChatMessage(role: .assistant, segments: segments)
                    assistantID = msg.id
                    messages.append(msg)
                }
            }
            // If the stream finished without ever yielding (e.g. an error
            // path that just calls finish), still flip both indicators off.
            isAwaitingFirstToken = false
            isStreaming = false
            guard !Task.isCancelled else { return }
            if let id = assistantID, let t = thread,
               let final = messages.first(where: { $0.id == id }) {
                ChatStore.append(final, to: t, in: context)
            } else if !lastSegments.isEmpty, let t = thread {
                let msg = ChatMessage(role: .assistant, segments: lastSegments)
                ChatStore.append(msg, to: t, in: context)
            }
        }
    }
}

private struct MessageRow: View {
    @Environment(\.theme) private var theme

    let message: ChatMessage
    let onCite: (SuttaCite) -> Void
    let onContinue: (UUID) -> Void
    let onEnd: () -> Void

    private func plainText(of segments: [MessageSegment]) -> String {
        segments.map { seg -> String in
            switch seg {
            case .text(let s): return s
            case .italic(let s): return s
            case .citation(let cite): return "(\(cite.code))"
            }
        }.joined()
    }

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 60)
                Text(message.segments.map(\.plainText).joined())
                    .font(BTFont.ui(14, weight: .light))
                    .foregroundStyle(theme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(.horizontal, 22)
            .contextMenu {
                let text = plainText(of: message.segments)
                Button {
                    UIPasteboard.general.string = text
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                ShareLink(item: text) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }

        case .assistant:
            if message.kind == .gentleReminder {
                CrisisInterceptCard(
                    text: message.segments.first?.plainText ?? CrisisClassifier.interceptMessage,
                    onContinue: { onContinue(message.id) },
                    onEnd: onEnd
                )
            } else {
                AssistantBlock(segments: message.segments, onCite: onCite)
                    .contextMenu {
                        let text = plainText(of: message.segments)
                        Button {
                            UIPasteboard.general.string = text
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        ShareLink(item: text) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
            }

        case .system:
            EmptyView()
        }
    }
}

private struct AssistantBlock: View {
    @Environment(\.theme) private var theme

    let segments: [MessageSegment]
    let onCite: (SuttaCite) -> Void

    var body: some View {
        FlowLayout(spacing: 4, runSpacing: 6) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                switch seg {
                case .text(let s):
                    ForEach(Array(s.split(separator: " ", omittingEmptySubsequences: false).enumerated()), id: \.offset) { _, word in
                        Text(String(word) + " ")
                            .font(BTFont.serif(17, weight: .light))
                            .foregroundStyle(theme.ink)
                    }
                case .italic(let s):
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Rectangle()
                            .fill(theme.accent.opacity(0.4))
                            .frame(width: 1.5)
                            .accessibilityHidden(true)
                        Text(s)
                            .font(BTFont.serif(17, weight: .light, italic: true))
                            .foregroundStyle(theme.ink)
                    }
                case .citation(let cite):
                    CitationPill(cite: cite, onTap: onCite)
                }
            }
        }
        .padding(.horizontal, 22)
    }
}

private struct CrisisInterceptCard: View {
    @Environment(\.theme) private var theme

    let text: String
    let onContinue: () -> Void
    let onEnd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(text)
                .font(BTFont.serif(15.5, weight: .light, italic: true))
                .foregroundStyle(theme.inkSoft)
                .lineSpacing(5)

            VStack(spacing: 8) {
                Link(destination: CrisisClassifier.helplineURL) {
                    Label("Get help now", systemImage: "phone.fill")
                        .font(BTFont.ui(13, weight: .medium))
                        .foregroundStyle(theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .glassEffect(.regular, in: Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onContinue) {
                    Text("I'm OK, continue")
                        .font(BTFont.ui(13))
                        .foregroundStyle(theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .glassEffect(.regular, in: Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onEnd) {
                    Text("End conversation")
                        .font(BTFont.ui(13))
                        .foregroundStyle(theme.inkMute)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 22)
    }
}

private struct ThinkingDot: View {
    @State private var pulse: Double = 0.5
    var body: some View {
        Circle()
            .fill(.white.opacity(pulse))
            .frame(width: 8, height: 8)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever()) {
                    pulse = 1.0
                }
            }
    }
}

private struct StreamingCaret: View {
    @State private var opacity: Double = 0.3
    @Environment(\.theme) private var theme
    var body: some View {
        Rectangle()
            .fill(theme.inkSoft)
            .frame(width: 8, height: 2)
            .opacity(opacity)
            .padding(.horizontal, 22)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                    opacity = 0.9
                }
            }
            .accessibilityHidden(true)
    }
}

private struct EmptyChatPrompt: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ask a question").eyebrow()
            Text(.init("Ask a question. The Teacher will reply with a single sentence of framing and *verbatim quotes from the canon* — never a paraphrase."))
                .font(BTFont.serif(22, weight: .light))
                .lineSpacing(5)
                .foregroundStyle(theme.ink)
            Text("Try: 'how do I sit with anger?', 'what does the Buddha say about grief?'")
                .font(BTFont.ui(12, weight: .light))
                .foregroundStyle(theme.inkMute)
                .padding(.top, 8)
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Composer: View {
    @Environment(\.theme) private var theme

    @Binding var text: String
    let onSend: () -> Void
    @FocusState private var focused: Bool
    @ObservedObject private var asr = SpeechRecognizer.shared

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                TextField("Ask…", text: $text, axis: .vertical)
                    .focused($focused)
                    .font(BTFont.ui(15, weight: .light))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1...4)
                    .submitLabel(.send)
                    .onSubmit(onSend)
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(.white.opacity(text.isEmpty ? 0.3 : 0.95))
                }
                .disabled(text.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            Button {
                if asr.isListening {
                    asr.stop()
                } else {
                    asr.reset()
                    Task { await asr.start() }
                }
            } label: {
                Image(systemName: asr.isListening ? "waveform.circle.fill" : "waveform")
                    .font(.system(size: asr.isListening ? 22 : 16,
                                   weight: .light))
                    .foregroundStyle(asr.isListening ? .white : theme.ink)
                    .symbolEffect(.variableColor.iterative, isActive: asr.isListening)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular, in: Circle())
            .accessibilityLabel(asr.isListening ? "Stop dictating" : "Start dictating")
            .accessibilityHint("Speak your question to the Teacher")
            .onChange(of: asr.transcript) { _, newValue in
                // Stream the live transcription into the text field.
                if asr.isListening, !newValue.isEmpty {
                    text = newValue
                }
            }
        }
    }
}
