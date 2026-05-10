import Foundation
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var draft: String = ""
    @Published var isReplying: Bool = false

    private weak var session: SessionStore?

    init(session: SessionStore) {
        self.session = session
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let session else { return }

        let userMsg = ChatMessage.user(text)
        messages.append(userMsg)
        draft = ""

        // Crisis intercept check (M3d)
        if CrisisClassifier.detects(in: text) {
            let reminder = ChatMessage(role: .assistant,
                                       kind: .gentleReminder,
                                       segments: [.text(CrisisClassifier.interceptMessage)])
            messages.append(reminder)
            return
        }

        isReplying = true
        let segments = await session.llm.reply(to: text,
                                               tradition: session.user.tradition,
                                               history: messages)
        let response = ChatMessage(role: .assistant, segments: segments)
        messages.append(response)
        isReplying = false
    }
}
