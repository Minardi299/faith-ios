import Foundation

/// A continuous-loop ambient sound the user can pick to play behind a sit.
/// Audio files live in `faith-ios/Resources/backgrounds/<filename>.mp3`.
/// When a file is missing, `BackgroundPlayer.play(_:)` is a graceful no-op.
struct MeditationBackground: Identifiable, Hashable {
    let id: String
    let title: String
    let romanised: String?       // optional traditional name
    let filename: String         // extension is .mp3 in the bundle
    let icon: String             // SF Symbol shown on the row
    /// Silence between the end of one loop and the start of the next, in
    /// seconds. Gives percussive sounds a natural breathing pause; ambient
    /// textures use 0 for a seamless join.
    let loopGapSeconds: TimeInterval

}

extension MeditationBackground {
    /// Empty until ambient mp3s are sourced and dropped into Resources/backgrounds/.
    /// Phase 0.8 of the UX-fixes plan: shown rows pointed at missing audio,
    /// producing silent no-op taps that confused users.
    static let all: [MeditationBackground] = []
}
