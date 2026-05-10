import Foundation

struct AppUser: Codable, Hashable {
    var id: String
    var displayName: String?
    var tradition: Tradition
    var experience: Experience
    var dailyMinutes: Int        // 5/10/20/30
    var topics: Set<Topic>
    var notificationsAllowed: Bool

    static let sample = AppUser(
        id: "local",
        displayName: nil,
        tradition: .secular,
        experience: .someSitting,
        dailyMinutes: 10,
        topics: [],
        notificationsAllowed: false
    )
}

enum Experience: String, Codable, CaseIterable, Hashable, Identifiable {
    case new
    case someSitting
    case longRoad

    var id: String { rawValue }

    var title: String {
        switch self {
        case .new:          "New"
        case .someSitting:  "I sit sometimes"
        case .longRoad:     "A long road"
        }
    }

    var blurb: String {
        switch self {
        case .new:          "First time here. Take it gently."
        case .someSitting:  "Familiar with the breath, building a rhythm."
        case .longRoad:     "Years on the cushion. You know the territory."
        }
    }
}

enum Topic: String, Codable, CaseIterable, Hashable, Identifiable {
    case peace, grief, anger, sleep, focus, relationships, fear, gratitude

    var id: String { rawValue }

    var label: String {
        switch self {
        case .peace:         "peace"
        case .grief:         "grief"
        case .anger:         "anger"
        case .sleep:         "sleep"
        case .focus:         "focus"
        case .relationships: "relationships"
        case .fear:          "fear"
        case .gratitude:     "gratitude"
        }
    }
}
