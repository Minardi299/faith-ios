import Foundation
import SwiftData

@Model
final class StoredChatThread {
    var createdAt: Date
    var traditionRaw: String
    @Relationship(deleteRule: .cascade, inverse: \StoredChatMessage.thread)
    var messages: [StoredChatMessage] = []

    init(createdAt: Date = .now, traditionRaw: String) {
        self.createdAt = createdAt
        self.traditionRaw = traditionRaw
    }
}

@Model
final class StoredChatMessage {
    var roleRaw: String        // "user" | "assistant" | "system"
    var kindRaw: String        // "normal" | "gentleReminder"
    var segmentsJSON: String   // encoded [SegmentDTO]
    var timestamp: Date
    var thread: StoredChatThread?

    init(roleRaw: String,
         kindRaw: String,
         segmentsJSON: String,
         timestamp: Date = .now,
         thread: StoredChatThread? = nil) {
        self.roleRaw = roleRaw
        self.kindRaw = kindRaw
        self.segmentsJSON = segmentsJSON
        self.timestamp = timestamp
        self.thread = thread
    }
}

/// Wire format for serializing MessageSegment values into a single JSON column.
struct SegmentDTO: Codable {
    var kind: String          // "text" | "italic" | "citation"
    var text: String?
    var citeCode: String?
    var citeTitle: String?
    var citeID: String?

    static func encode(_ segments: [MessageSegment]) -> String {
        let dtos = segments.map { seg -> SegmentDTO in
            switch seg {
            case .text(let s):     return .init(kind: "text", text: s)
            case .italic(let s):   return .init(kind: "italic", text: s)
            case .citation(let c): return .init(kind: "citation",
                                                citeCode: c.code,
                                                citeTitle: c.englishTitle,
                                                citeID: c.suttaID)
            }
        }
        let data = (try? JSONEncoder().encode(dtos)) ?? Data()
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    static func decode(_ json: String) -> [MessageSegment] {
        guard let data = json.data(using: .utf8),
              let dtos = try? JSONDecoder().decode([SegmentDTO].self, from: data) else {
            return []
        }
        return dtos.compactMap { dto in
            switch dto.kind {
            case "text":     return dto.text.map { MessageSegment.text($0) }
            case "italic":   return dto.text.map { MessageSegment.italic($0) }
            case "citation":
                guard let c = dto.citeCode, let t = dto.citeTitle, let id = dto.citeID else {
                    return nil
                }
                return .citation(SuttaCite(code: c, englishTitle: t, suttaID: id))
            default: return nil
            }
        }
    }
}

extension StoredChatMessage {
    var asChatMessage: ChatMessage {
        let role: ChatMessage.Role
        switch roleRaw {
        case "user":      role = .user
        case "assistant": role = .assistant
        default:          role = .system
        }
        let kind: ChatMessage.Kind = kindRaw == "gentleReminder" ? .gentleReminder : .normal
        return ChatMessage(role: role,
                           kind: kind,
                           segments: SegmentDTO.decode(segmentsJSON),
                           timestamp: timestamp)
    }

    static func from(_ msg: ChatMessage, in thread: StoredChatThread) -> StoredChatMessage {
        let roleRaw: String
        switch msg.role {
        case .user:      roleRaw = "user"
        case .assistant: roleRaw = "assistant"
        case .system:    roleRaw = "system"
        }
        let kindRaw = msg.kind == .gentleReminder ? "gentleReminder" : "normal"
        return StoredChatMessage(
            roleRaw: roleRaw,
            kindRaw: kindRaw,
            segmentsJSON: SegmentDTO.encode(msg.segments),
            timestamp: msg.timestamp,
            thread: thread
        )
    }
}
