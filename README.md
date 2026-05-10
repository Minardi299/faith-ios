# Faith iOS

A multi-tradition Buddhist canon companion. Daily passages from the Pāli, Mahāyāna, Vajrayāna, Zen, and secular paths; meditation timer with looping chants; an on-device AI teacher that quotes scripture verbatim instead of paraphrasing it.

## Features

- **Today** — daily passage picked deterministically by date, week-strip streak indicators, progress driven by a five-item practice checklist (morning prayer, read today's story, journal one gratitude, evening reflection, meditation).
- **Practice** — meditation timer (10 s through 30 m) with duration picker and circular countdown, paired with a chant library of 19 mp3s spanning Pāli, Sanskrit, Vietnamese, Chinese, and Japanese liturgy. Loops gaplessly via `AVQueuePlayer` + `AVPlayerLooper`.
- **Library** — full canon browse across five traditions (Theravāda, Mahāyāna, Vajrayāna, Zen, Secular). Curated cross-tradition "core reads", per-tradition collections, full-text search, and detail sheets with citations.
- **Teacher** — on-device retrieval-augmented chat. Apple's Foundation Models framework (iOS 26) selects which canonical passages answer a question; verbatim quotes are pulled from the bundled canon — never paraphrased. Falls back to a retrieval-only path on Simulator and pre-iOS-26 devices.
- **Streak / Calendar** — Strava-style heatmap with current/longest/total stats; consecutive completed days connect into a single pill. Holy-day calendar tracks uposatha and lunar phases.
- **Journal** — gratitude and reflection entries persisted with SwiftData.
- **Quiz** — short canon-literacy questions (`quiz.json`).
- **Anniversaries** — track significant dates and surface gentle reminders.
- **Blessing** — share a daily passage with someone.
- **Profile / Theme** — five tradition-tinted palettes (saffron, indigo, crimson, washi, sage), system / light / dark appearance toggle, accessible from the top-right of every screen.
- **Widget** — daily-passage Lock Screen / Home Screen widget (`FaithWidget`), kept in sync with the app via App Group `group.com.faith.app`.
- **Deep links** — `faith://today`, `faith://practice`, `faith://library`, `faith://chat`, `faith://passage/<id>`.
- **Voice input** — `SFSpeechRecognizer` is wired up for chat dictation.
- **Crisis-aware chat** — a small classifier (`GentleReminder`) intercepts crisis language and replaces the AI response with a fixed grounding message.

## Tech stack

- SwiftUI, **iOS 26.0+**. Liquid Glass tab bar with `Tab(role: .search)` for the detached "Teacher" bubble.
- SwiftData for persistence (`DayCompletion`, `ChatMessage`, `Anniversary`, `JournalEntry`, `PracticeRecord`, `StoredChatThread`).
- `@Observable` / `ObservableObject` stores for in-memory state.
- **Apple Foundation Models** (`SystemLanguageModel`) for on-device chat framing — the model only picks passage IDs and writes a single sentence of context; quotes are pulled verbatim by `CanonQuoteExtractor`.
- **`NaturalLanguage`** word embeddings for canon retrieval. `embeddings.bin` is built at compile time by `tools/build_embeddings.swift` from `canon.json` + sidecars; runtime falls back to rebuilding into Application Support if the bundled file is missing or stale.
- **`AVFoundation`** for chant playback (looping queue player + per-clip preview).
- **`Speech`** for voice input in chat.
- **`WidgetKit`** for the daily-passage widget; **App Group** `group.com.faith.app` shares state between app and widget.
- All UI built from native components — no third-party UI dependencies.
- `PBXFileSystemSynchronizedRootGroup` Xcode project — files dropped under `faith-ios/` are auto-discovered, no `project.pbxproj` edits required.

## Project layout

```
faith-ios/
├── FaithApp.swift                # @main, ModelContainer, --seed launch arg, embedding warm-up
├── ContentView.swift             # 4-tab Liquid Glass shell + faith:// deep links
├── Models/
│   ├── Sutta.swift               # SuttaPassage, SuttaCite, MessageSegment, LengthTier, PassageKind
│   ├── Tradition.swift           # 5 traditions + tinted accents and substrate gradients
│   ├── DayCompletion.swift       # @Model — 5 task flags, dayKey unique
│   ├── ChatMessage.swift         # @Model — role + content
│   ├── Chant.swift               # bundled chant metadata (19 entries)
│   ├── Quiz.swift, ReadingPathway.swift, StudyTrack.swift
│   ├── HolyDay.swift, HolyDayCalendar.swift
│   ├── Theme.swift, AppearanceMode.swift, MeditationBackground.swift
│   ├── AppUser.swift, Reflection.swift, SeedContent.swift, SitActivityAttributes.swift
│   ├── Listen/PlayableItem.swift
│   └── Persistence/{Anniversary,JournalEntry,PracticeRecord,StoredChatThread}.swift
├── Stores/
│   └── ProgressStore.swift       # SwiftData wrapper for streak / week / mark-done
├── Services/
│   ├── CanonStore.swift          # loads canon.json + sidecars; lookup by id, collection, tradition
│   ├── DailyPassageStore.swift   # deterministic daily pick
│   ├── ChantPlayer.swift, AudioService.swift, BackgroundPlayer.swift
│   ├── LLMRuntime.swift          # protocol + MockLLMRuntime
│   ├── ChatStore.swift, JournalStore.swift, AnniversaryStore.swift
│   ├── PathwayStore.swift, PathwayProgressStore.swift, StudyTrackStore.swift
│   ├── SessionStore.swift, AuthService.swift, UserRepository.swift
│   ├── PersistenceContainer.swift, SharedProgress.swift, PracticeQueries.swift
│   ├── GentleReminder.swift      # crisis classifier — not a notification scheduler
│   ├── LunarPhase.swift, SpeechRecognizer.swift
│   ├── Listen/                   # AudioSource, ListenQueueStore, ListenProgressStore, LegacyMigrator
│   └── RAG/
│       ├── EmbeddingIndex.swift          # bundled .bin → Application Support → runtime rebuild
│       ├── FoundationModelsRuntime.swift # iOS 26 Apple LLM, structured passage selection
│       ├── RetrievalOnlyRuntime.swift    # Simulator / pre-iOS-26 fallback
│       ├── CanonQuoteExtractor.swift     # verbatim quotes — never paraphrase
│       └── CitationParser.swift
├── ViewModels/ChatViewModel.swift
├── Theme/{NatureSubstrate,Typography}.swift
├── Views/
│   ├── TodayView.swift, StreakDetailView.swift
│   ├── LibraryView.swift, Lotus.swift
│   ├── ProfileView.swift, ProfileToolbar.swift
│   ├── Anniversaries/, Blessing/, Calendar/, Chat/, Journal/, Meditate/, Quiz/, Study/
│   └── Components/{GlassCard,CitationPill,FlowLayout,HitArea,PageScaffold,SettingsRow,SitTimer,ThemeRow,TraditionGlyph}.swift
└── Resources/
    ├── canon.json                        # ~10 MB — SuttaCentral bilara-data + curated entries
    ├── study-stories.json (~2 MB), study-introductions.json, study-tracks.json
    ├── pathways.json, quiz.json
    ├── embeddings.bin                    # precomputed word-vector index
    └── chants/*.mp3                      # 19 chants

FaithWidget/                              # daily-passage widget extension
faith-ios.xcodeproj/                      # Xcode project (use this one)
faith-iosTests/, faith-iosUITests/
tools/build_embeddings.swift              # rebuilds Resources/embeddings.bin
```

## Getting started

Requires **Xcode 26+** and an **iOS 26+** simulator or device. The Foundation Models chat path needs a device that ships with Apple Intelligence; on Simulator and unsupported hardware the app falls back to retrieval-only chat (still verbatim, no paraphrase).

```bash
git clone https://github.com/Minardi299/faith-ios.git
cd faith-ios
open faith-ios.xcodeproj
```

Then `⌘R` to build and run. Bundle id is `com.faith.app`.

### Rebuilding the embeddings index

`Resources/embeddings.bin` is checked in. To regenerate it after editing the canon:

```bash
swift tools/build_embeddings.swift \
  faith-ios/Resources/embeddings.bin \
  faith-ios/Resources/canon.json \
  faith-ios/Resources/study-stories.json \
  faith-ios/Resources/study-introductions.json
```

### Seeding test data

The app accepts a `--seed` launch argument that wipes existing `DayCompletion` records and inserts a handful of completed days centered on today, so the streak page has something to render. From Xcode: edit the scheme → Run → Arguments → add `--seed`. From the CLI:

```bash
xcrun simctl launch booted com.faith.app --seed
```

## TODO

- Local notifications for the daily reminder. `GentleReminder` despite its name is the crisis classifier — there's no notification scheduler yet.

## Content

Pāli canon entries are derived from SuttaCentral's [bilara-data](https://github.com/suttacentral/bilara-data) (CC0). Mahāyāna, Vajrayāna, Zen, and Dhammapada-story entries are curated public-domain translations.
