import Foundation

struct ChatMessage: Identifiable, Hashable {
    enum Role: Hashable { case user, assistant, system }
    enum Kind: Hashable { case normal, gentleReminder }

    let id: UUID
    let role: Role
    let kind: Kind
    let segments: [MessageSegment]
    let timestamp: Date

    init(id: UUID = UUID(),
         role: Role,
         kind: Kind = .normal,
         segments: [MessageSegment],
         timestamp: Date = .now) {
        self.id = id
        self.role = role
        self.kind = kind
        self.segments = segments
        self.timestamp = timestamp
    }

    static func user(_ text: String) -> ChatMessage {
        ChatMessage(role: .user, segments: [.text(text)])
    }
}

enum MessageSegment: Hashable {
    case text(String)
    case italic(String)
    case citation(SuttaCite)

    var plainText: String {
        switch self {
        case .text(let s), .italic(let s): return s
        case .citation(let c): return c.code
        }
    }
}

struct SuttaCite: Hashable {
    let code: String          // "MN 21"
    let englishTitle: String  // "Simile of the Saw"
    let suttaID: String       // matches SuttaPassage.id
}
