import Foundation
import ActivityKit

/// Live Activity / Dynamic Island state for an active sit.
///
/// Single source of truth for both the `faith-ios` app target and the
/// `FaithWidgetExtension` target. The widget target includes this file via an
/// explicit PBXFileReference + PBXBuildFile in the pbxproj, so no mirror copy
/// is needed. Do not add a second copy of this file in the FaithWidget folder.
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
