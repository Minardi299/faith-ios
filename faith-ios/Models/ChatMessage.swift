import Foundation
import SwiftData

@Model
final class ChatMessage {
    var role: String
    var content: String
    var createdAt: Date

    init(role: Role, content: String, createdAt: Date = .now) {
        self.role = role.rawValue
        self.content = content
        self.createdAt = createdAt
    }

    var roleValue: Role { Role(rawValue: role) ?? .assistant }

    enum Role: String, Codable {
        case user
        case assistant
        case system
    }
}
