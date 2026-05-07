# Faith iOS

A daily Dhammapada companion: one verse a day, the story behind it, a small practice checklist, a meditation timer, and an AI companion to talk things through.

## Features

- **Today's Journey** — daily verse picked deterministically by date, week-strip streak indicators, progress bar driven by the practice checklist.
- **Daily** — full verse, the story behind it, a five-item practice checklist (morning prayer, read today's story, journal one gratitude, evening reflection, meditation).
- **Stories** — the full library of stories from the Dhammapada, indexed by verse number.
- **Streak** — Strava-style calendar with current/longest/total stats; consecutive completed days connect into a single pill.
- **Meditation timer** — duration picker (10s through 30m), circular countdown, placeholder ambient audio, auto-marks the task done on completion.
- **Chat** — AI companion (OpenAI-compatible API, currently stubbed against `ai.starb.ca`).
- **Profile** — accessible from the top-right of every screen, like Apple Music.

## Tech stack

- SwiftUI, iOS 18.2+ (uses iOS 26 Liquid Glass tab bar with `Tab(role: .search)` for the detached chat bubble)
- SwiftData for persistence (`DayCompletion`, `ChatMessage`)
- `@Observable` stores for in-memory state
- All UI built from native components — no third-party UI dependencies
- `PBXFileSystemSynchronizedRootGroup` Xcode project — files dropped into `faith-ios/` are auto-discovered, no project.pbxproj edits required

## Project layout

```
faith-ios/
├── faith_iosApp.swift        # App entry, ModelContainer, --seed launch arg
├── ContentView.swift         # TabView with 4 tabs (Home, Daily, Stories, Chat-as-search)
├── data.json                 # 423 Dhammapada verses with stories
├── Models/
│   ├── Verse.swift           # Codable, loaded from data.json
│   ├── DayCompletion.swift   # @Model, 5 task flags + dayKey unique
│   └── ChatMessage.swift     # @Model, role + content
├── Stores/
│   ├── VerseStore.swift      # Loads JSON, picks today's verse by epoch day
│   └── ProgressStore.swift   # SwiftData wrapper for streak / week / mark-done
├── Services/
│   ├── AIService.swift       # OpenAI-shaped POST to ai.starb.ca/v1/chat/completions
│   └── MeditationAudio.swift # AVAudioPlayer wrapper for meditation.mp3
└── Views/
    ├── HomeView.swift
    ├── DailyView.swift
    ├── StoriesView.swift, StoryDetailView.swift
    ├── ChatView.swift
    ├── ProfileView.swift, ProfileToolbar.swift
    ├── StreakDetailView.swift
    ├── MeditationTimerView.swift
    └── MeditationCard.swift
```

## Getting started

Requires Xcode 16+ and an iOS 18.2+ simulator or device.

```bash
git clone https://github.com/Minardi299/faith-ios.git
cd faith-ios
open faith-ios.xcodeproj
```

Then `⌘R` to build and run.

### Seeding test data

The app accepts a `--seed` launch argument that wipes existing `DayCompletion` records and inserts a handful of completed days centered on today, so the streak page has something to render. From Xcode: edit the scheme → Run → Arguments → add `--seed`. From the CLI:

```bash
xcrun simctl launch booted minh.faith-ios --seed
```

## TODO

- Drop a real `meditation.mp3` into the bundle to enable timer audio (currently silent — `MeditationAudio.play()` no-ops if the file is missing).
- Wire a real API key into `AIService.apiKey` to enable the chat companion. Without it, `ChatView` falls back to a placeholder reply.
- Local notifications for the daily reminder.

## Content

The Dhammapada verses and stories in `data.json` are public-domain translations.
