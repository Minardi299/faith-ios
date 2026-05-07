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

    static let all: [MeditationBackground] = [
        MeditationBackground(
            id: "mokugyo",
            title: "Wooden fish",
            romanised: "Mõ · Mokugyo",
            filename: "mokugyo",
            icon: "drum.fill",
            loopGapSeconds: 1.5
        ),
        MeditationBackground(
            id: "singing-bowl",
            title: "Singing bowl",
            romanised: nil,
            filename: "singing-bowl",
            icon: "circle.dotted",
            loopGapSeconds: 4.0
        ),
        MeditationBackground(
            id: "tingsha",
            title: "Tingsha",
            romanised: "Tibetan bells",
            filename: "tingsha",
            icon: "bell.fill",
            loopGapSeconds: 3.0
        ),
        MeditationBackground(
            id: "temple-drum",
            title: "Temple drum",
            romanised: nil,
            filename: "temple-drum",
            icon: "drum",
            loopGapSeconds: 2.5
        ),
        MeditationBackground(
            id: "rain",
            title: "Rain",
            romanised: nil,
            filename: "rain",
            icon: "cloud.rain.fill",
            loopGapSeconds: 0.0
        ),
        MeditationBackground(
            id: "stream",
            title: "Stream",
            romanised: nil,
            filename: "stream",
            icon: "water.waves",
            loopGapSeconds: 0.0
        ),
    ]
}
