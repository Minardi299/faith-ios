import Foundation
import ActivityKit

/// Live Activity / Dynamic Island state for an active sit.
/// Lives in `faith-ios/Models/` and is compiled into BOTH the main app and
/// the widget extension so the same type drives `Activity.request()` on the
/// app side and the SwiftUI shape on the widget side.
public struct SitActivityAttributes: ActivityAttributes {
    public typealias ContentState = State

    public struct State: Codable, Hashable {
        public var startedAt: Date
        public var endsAt: Date
        public var background: String?
        public var chant: String?

        public init(startedAt: Date, endsAt: Date, background: String? = nil, chant: String? = nil) {
            self.startedAt = startedAt
            self.endsAt = endsAt
            self.background = background
            self.chant = chant
        }
    }

    public init() {}
}
