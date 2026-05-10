import Foundation
import ActivityKit

/// Live Activity / Dynamic Island state for an active sit.
///
/// MIRROR — these two files (faith-ios/Models/SitActivityAttributes.swift and
/// FaithWidget/SitActivityAttributes.swift) MUST stay byte-identical. Any field
/// change here must be applied to BOTH files in the same commit, otherwise
/// ActivityKit's Codable round-trip between app and widget will silently
/// produce garbled state. See Phase 7 of the UX-fixes plan for the permanent
/// fix (cross-target file membership or shared Swift Package).
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
