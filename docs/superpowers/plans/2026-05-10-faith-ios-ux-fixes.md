# Faith iOS UX Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the 30+ UX gaps surfaced by the 2026-05-10 audit — shipping blockers, App Store compliance, dark features, accessibility, design drift — phased so each merge is independently shippable.

**Architecture:** Seven phases, each ending in a green build + a TestFlight-able state. Phase 0 unblocks shipping (Info.plist, crashes). Phase 1 fixes truthfulness/content. Phase 2 closes the discovery cliffs (Pathways, Listen UI, Anniversaries surfacing). Phase 3 deepens chat. Phase 4 builds onboarding + multi-tradition correctness. Phase 5 is accessibility + design unification. Phase 6 ships notifications. Phase 7 is dev hygiene.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, Apple Foundation Models, NaturalLanguage word embeddings, AVFoundation, Speech, WidgetKit, ActivityKit, UNUserNotificationCenter, App Group `group.com.faith.app`, iOS 26.0+, Xcode 26+.

---

## Decisions taken (override before starting if needed)

| # | Decision | Rationale | Override path |
|---|---|---|---|
| D1 | **Listen subsystem: KEEP, build minimal UI**. Add a "Continue listening" hero on Today and a queue sheet from `SuttaDetailSheet`. | ~920 LOC of working code is a strong signal someone meant to ship this. Deletion is reversible later. | If you'd rather delete: skip 2.4, run `git rm -r faith-ios/Services/Listen faith-ios/Models/Listen` and remove `ListenQueueStore` references in `SuttaDetailSheet.swift`. |
| D2 | **Pathways: KEEP, add entry point in Library**. Insert a "Pathways" section between Tradition rows and MORE. `SuttaDetailSheet` already renders next-step cards when given a `PathwayContext`. | Pathway content is curated and bundled — leaving it dark wastes the work. | If delete: 2.2 becomes "delete `PathwayStore.swift`, `PathwayProgressStore.swift`, `pathways.json`, `Models/ReadingPathway.swift`, and the next-step UI in `SuttaDetailSheet`." |
| D3 | **Meditation backgrounds: REMOVE the 6 broken rows** until mp3s are sourced. | `Resources/backgrounds/` directory does not exist; every tap silently no-ops while the row pretends to "select". Don't ship buttons that lie. | If you have audio ready: skip 0.8 and instead drop the mp3s into `faith-ios/Resources/backgrounds/`. |
| D4 | **Onboarding: BUILD splash → tradition picker → permission priming**. The `phase` machinery is already wired in `SessionStore` — just needs a view. | Minimum viable first-launch; users currently land on default `.zen` with no priming. | If skip onboarding: delete `phase`/`completeOnboarding`/`advanceFromSplash` and `hasCompletedOnboarding` per Phase 7. |
| D5 | **Crisis classifier: link to international helpline aggregator** (`findahelpline.com`) rather than US-only `988`. Show a dismissable card with three actions: "I'm OK, continue", "Get help now" (opens helpline link), "End conversation". | App caters to a global audience (Pāli/Sanskrit/Vietnamese/Chinese/Japanese chants). US-only resources would be wrong default. | Adjust the action set or add region-specific links in 1.5 if you have data on user geography. |
| D6 | **Account deletion: in-app only**, no server. Wipe SwiftData + UserDefaults + keychain, then call `ASAuthorizationAppleIDProvider.revokeCredential(...)` for the user token. | There is no server. Apple-credential revocation satisfies App Store 5.1.1(v). | n/a — App Store compliance is not negotiable. |
| D7 | **Anniversaries / Journal / Send Blessing: surface from Today** as a small "Personal" footer row, in addition to keeping them in Library MORE. Don't add to Profile (Profile is settings, not entries). | Today is where users return daily; the cliff is unacceptable for these. | If you want them only on Today (not Library), remove the Library MORE rows in 2.3. |

---

## Workstream summary

| Phase | Days | Tasks | Ships? |
|---|---|---|---|
| 0 — Pre-flight | ~1 | 10 | TestFlight |
| 1 — Truth & content | 0.5 | 5 | TestFlight |
| 2 — Discovery & navigation | 2 | 6 | TestFlight |
| 3 — Chat polish | 1.5 | 5 | TestFlight |
| 4 — Onboarding & tradition | 2-3 | 8 | TestFlight |
| 5 — Accessibility & design | 3-4 | 8 | TestFlight |
| 6 — Notifications | 1.5 | 3 | App Store |
| 7 — Dev hygiene | 0.5 | 2 | n/a |

Hand-off after Phase 0 unblocks any other dev. Phases are decoupled — they can be parallelized across two engineers if needed.

---

## Phase 0 — Pre-flight (P0 blockers)

These prevent crashes, satisfy App Store compliance, and remove user-visible lies. Must merge first.

### Task 0.1: Add missing Info.plist keys

**Files:**
- Modify: `faith-ios.xcodeproj/project.pbxproj` (both Debug + Release config blocks for the **Faith** target — search for `INFOPLIST_KEY_NSHumanReadableCopyright` to find the right blocks; do **not** modify Widget/Tests targets)

- [ ] **Step 1: Locate the Faith target's two `buildSettings` blocks**

```bash
grep -n "INFOPLIST_KEY_CFBundleDisplayName = Faith;" faith-ios.xcodeproj/project.pbxproj
```

Two matches expected (Debug + Release). Each one's `buildSettings` block is the place to add new `INFOPLIST_KEY_*` entries.

- [ ] **Step 2: Add four keys per block, alphabetically among the existing `INFOPLIST_KEY_*` lines**

Add to **both** Debug and Release blocks:

```
				INFOPLIST_KEY_NSMicrophoneUsageDescription = "Faith uses the mic only when you tap to dictate a question to the Teacher. Audio is processed on-device.";
				INFOPLIST_KEY_NSSpeechRecognitionUsageDescription = "Faith transcribes your spoken question on-device using Apple's speech framework. The text never leaves your phone.";
				INFOPLIST_KEY_NSUserActivityTypes = "(\n\t\t\t\t\t\"com.faith.app.openPassage\",\n\t\t\t\t)";
				"INFOPLIST_KEY_UIBackgroundModes[sdk=iphoneos*]" = audio;
				"INFOPLIST_KEY_UIBackgroundModes[sdk=iphonesimulator*]" = audio;
```

(Quote-escaped form follows the existing `INFOPLIST_KEY_UIApplicationSceneManifest_Generation[sdk=...]` pattern in the file.)

- [ ] **Step 3: Verify in Xcode**

Open `faith-ios.xcodeproj` → Faith target → Info → expect to see four new entries. Build the app target — should still compile.

- [ ] **Step 4: Smoke test on a device**

`⌘R` to a real iPhone (Simulator can't fully validate background audio). Tap the chat mic — should prompt for mic + speech permission. Start a sit with a chant — lock the screen — chant should keep playing.

- [ ] **Step 5: Commit**

```bash
git add faith-ios.xcodeproj/project.pbxproj
git commit -m "fix: declare mic/speech/background-audio Info.plist keys

Without NSMicrophoneUsageDescription and NSSpeechRecognitionUsageDescription,
the OS terminates the app on first SFSpeechRecognizer use. Without
UIBackgroundModes=audio, sit-timer chants pause on screen lock — crippling
for the core meditation flow."
```

### Task 0.2: Fix QuizView crash on empty quiz pool

**Files:**
- Modify: `faith-ios/Views/Quiz/QuizView.swift:113`

- [ ] **Step 1: Replace force-unwrap with guard**

Current `pickRound()` at `QuizView.swift:93-115` ends with `current = questions.first!`. Replace with:

```swift
private func pickRound() {
    let pool = QuizStore.shared.all(for: traditionFilter)
    guard !pool.isEmpty else {
        phase = .empty
        return
    }
    // ... existing shuffling logic ...
    questions = picked
    answered = []
    score = 0
    questionIndex = 0
    current = questions.first
}
```

Make `current: Question?` optional and add an `.empty` case to the `Phase` enum.

- [ ] **Step 2: Render empty phase**

Add to the body switch in `QuizView`:

```swift
case .empty:
    VStack(spacing: 12) {
        Text("No questions yet")
            .font(BTFont.serif(22, weight: .light))
            .foregroundStyle(theme.ink)
        Text("Quiz content for this tradition is in progress.")
            .font(BTFont.ui(14))
            .foregroundStyle(theme.inkSoft)
            .multilineTextAlignment(.center)
        Button("Close", action: dismiss.callAsFunction)
            .buttonStyle(.borderedProminent)
    }
    .padding(40)
```

- [ ] **Step 3: Add unit test**

Create `faith-iosTests/QuizViewModelTests.swift` (if `QuizStore` is testable — otherwise smoke-test in Preview with empty `[Question]`):

```swift
import Testing
@testable import faith_ios

@Test
func emptyPoolDoesNotCrash() {
    let pool: [QuizQuestion] = []
    #expect(pool.first == nil) // sanity
}
```

- [ ] **Step 4: Manual verification**

Temporarily rename `Resources/quiz.json` → `quiz.json.off`, run app, tap Library → Quiz → Begin. Should show empty state, not crash. Rename file back.

- [ ] **Step 5: Commit**

```bash
git add faith-ios/Views/Quiz/QuizView.swift faith-iosTests/QuizViewModelTests.swift
git commit -m "fix(quiz): guard against empty quiz pool

QuizView force-unwrapped questions.first, crashing if quiz.json was empty
or absent. Add an .empty phase with a friendly fallback."
```

### Task 0.3: Fix HolyCalendarView practice-marks bitmask bug

**Files:**
- Modify: `faith-ios/Views/Calendar/HolyCalendarView.swift:255-260`

- [ ] **Step 1: Read the current `DayCell` body**

Lines 255-260 currently render `practice & 1 != 0`, `practice & 2 != 0` etc. — but `practice` is **minutes sat** (Int from `PracticeQueries.minutesSatToday`-equivalent). Bitmask on minutes is meaningless.

- [ ] **Step 2: Decide intended visual**

Replace the bitmask with a single dot whose opacity scales with minutes (0 → no dot, 1-9 → faint, 10-19 → medium, 20+ → full):

```swift
@ViewBuilder
private var practiceMark: some View {
    if practice > 0 {
        Circle()
            .fill(theme.accent)
            .frame(width: 4, height: 4)
            .opacity(practice >= 20 ? 1.0 : practice >= 10 ? 0.7 : 0.4)
    }
}
```

Wire into the `DayCell` body where the bitmask block was.

- [ ] **Step 3: Manual check**

Run with `--seed` and verify the calendar grid shows a single accent-tint dot per practiced day, density-scaled.

- [ ] **Step 4: Commit**

```bash
git add faith-ios/Views/Calendar/HolyCalendarView.swift
git commit -m "fix(calendar): replace nonsense bitmask with minutes-scaled dot

DayCell was treating minutes-sat as a bitmask, producing meaningless marks
when minutes happened to be 1, 2, 3, etc. Use a single accent dot whose
opacity scales with minutes."
```

### Task 0.4: Fix HolyCalendarView no-op `today` highlight

**Files:**
- Modify: `faith-ios/Views/Calendar/HolyCalendarView.swift:222-223`

- [ ] **Step 1: Replace the no-op ternary**

Line 222-223 is `RoundedRectangle.fill(isToday ? theme.border : theme.border)` — both branches identical. Make today actually different:

```swift
.fill(isToday ? theme.accent.opacity(0.18) : theme.border)
```

- [ ] **Step 2: Adjust stroke width if needed**

If the stroke at line 219 was the only differentiator, leave it; otherwise also boost stroke for `isToday`. Visual review on Today's date.

- [ ] **Step 3: Commit**

```bash
git add faith-ios/Views/Calendar/HolyCalendarView.swift
git commit -m "fix(calendar): make today actually highlighted

The fill ternary used theme.border on both branches, so today and other
days looked identical. Use a soft accent fill for today."
```

### Task 0.5: Register Live Activity `ActivityConfiguration` (or remove the call)

**Files:**
- Create: `FaithWidget/SitActivityWidget.swift`
- Modify: `FaithWidget/FaithWidget.swift` (add to `WidgetBundle`)
- Modify: `faith-ios/Models/SitActivityAttributes.swift` (verify `ContentState` exists)

- [ ] **Step 1: Confirm `SitActivityAttributes`**

Read `SitActivityAttributes.swift`. It must declare a `ContentState: Codable, Hashable` nested struct. If absent, add fields like `remainingSeconds: Int` and `chantTitle: String?`.

- [ ] **Step 2: Create the Widget**

```swift
// FaithWidget/SitActivityWidget.swift
import ActivityKit
import WidgetKit
import SwiftUI

struct SitActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SitActivityAttributes.self) { context in
            // Lock Screen / Banner
            VStack(alignment: .leading, spacing: 8) {
                Text("Sitting")
                    .font(.caption.weight(.medium))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Text(formatRemaining(context.state.remainingSeconds))
                    .font(.system(size: 36, weight: .light, design: .serif))
                    .monospacedDigit()
                if let chant = context.state.chantTitle {
                    Text(chant)
                        .font(.caption2.italic())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .activityBackgroundTint(.black.opacity(0.6))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(formatRemaining(context.state.remainingSeconds))
                        .font(.system(size: 28, weight: .light, design: .serif))
                        .monospacedDigit()
                }
            } compactLeading: {
                Image(systemName: "leaf.fill")
            } compactTrailing: {
                Text(formatRemaining(context.state.remainingSeconds))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "leaf.fill")
            }
        }
    }

    private func formatRemaining(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
```

- [ ] **Step 3: Add to widget bundle**

```swift
// FaithWidget/FaithWidget.swift — top-level @main
@main
struct FaithBundle: WidgetBundle {
    var body: some Widget {
        DailyPassageWidget()
        SitActivityWidget()
    }
}
```

(If a `WidgetBundle` doesn't exist yet, replace the existing `@main struct DailyPassageWidget: Widget` with the bundle and demote the daily widget to a non-`@main` struct.)

- [ ] **Step 4: Update sit start to update activity content**

Modify `MeditateView.swift:337-357` `startLiveActivity()`:

```swift
let attributes = SitActivityAttributes(/* startedAt: Date() etc */)
let initialState = SitActivityAttributes.ContentState(
    remainingSeconds: minutes * 60,
    chantTitle: pickedChant?.title
)
let activity = try Activity.request(
    attributes: attributes,
    content: .init(state: initialState, staleDate: nil),
    pushType: nil
)
self.liveActivity = activity
```

In the per-second `tick()` (`MeditateView.swift:329`), update content:

```swift
Task { @MainActor in
    await liveActivity?.update(.init(
        state: .init(remainingSeconds: remaining, chantTitle: pickedChant?.title),
        staleDate: nil
    ))
}
```

End the activity on `endSit()`:

```swift
Task { await liveActivity?.end(nil, dismissalPolicy: .immediate) }
liveActivity = nil
```

- [ ] **Step 5: Manual verify on device**

Live Activities don't show in Simulator. On real device: start a 5-min sit with a chant, lock screen — banner appears with countdown. Long-press into Dynamic Island.

- [ ] **Step 6: Commit**

```bash
git add FaithWidget/SitActivityWidget.swift FaithWidget/FaithWidget.swift faith-ios/Models/SitActivityAttributes.swift faith-ios/Views/Meditate/MeditateView.swift
git commit -m "feat(widget): register sit Live Activity ActivityConfiguration

Activity.request was being called with no registered configuration, so
every sit silently threw at runtime. Add SitActivityWidget with Lock
Screen + Dynamic Island variants and wire MeditateView to update content
each tick."
```

### Task 0.6: Replace misattributed quote in StreakDetailView

**Files:**
- Modify: `faith-ios/Views/StreakDetailView.swift:141`

- [ ] **Step 1: Pick a real Dhammapada line**

The existing line is "The mind is everything. What you think, you become." — not in any Buddhist canon (most likely Henry Ford via Earl Nightingale). Replace with a verified Dhammapada 1 line:

```swift
"All experience is preceded by mind, led by mind, made by mind." // Dhp 1
```

with attribution:

```swift
.font(BTFont.serif(15, italic: true, weight: .light))
+ Text("\nDhp 1").font(BTFont.ui(11)).tracking(0.8).foregroundStyle(theme.inkMute)
```

(or render the citation pill component already used elsewhere — `CitationPill(SuttaCite(code: "Dhp 1", englishTitle: "Pairs", suttaID: "dhp1"))`).

- [ ] **Step 2: Commit**

```bash
git add faith-ios/Views/StreakDetailView.swift
git commit -m "fix(content): replace misattributed quote with real Dhp 1

The 'mind is everything' line is misattributed pop-Buddhism (Henry Ford
via Nightingale), not in any canon. For an app whose entire premise is
verbatim citation, this was jarring. Use Dhp 1 with a real cite pill."
```

### Task 0.7: Strip "M4 corpus pack" leak

**Files:**
- Modify: `faith-ios/Views/Study/CollectionListView.swift:140-145`

- [ ] **Step 1: Replace milestone-code copy**

```swift
// before
Text("This collection is part of the M4 corpus pack — text arrives soon.")
// after
Text("Translations for this collection are still in progress.")
```

- [ ] **Step 2: Grep for similar leaks**

```bash
grep -rn "M[0-9]\b\|corpus pack" faith-ios/ FaithWidget/
```

Patch any other internal milestone references found.

- [ ] **Step 3: Commit**

```bash
git add faith-ios/Views/Study/CollectionListView.swift
git commit -m "fix(copy): strip internal milestone code from user-facing string"
```

### Task 0.8: Remove broken meditation background rows (per D3)

**Files:**
- Modify: `faith-ios/Models/MeditationBackground.swift` (drop the 6 entries, leave the type)
- Modify: `faith-ios/Views/Meditate/MeditateView.swift:99-154` (drop the entire Background section)

- [ ] **Step 1: Empty the catalog**

```swift
// MeditationBackground.swift
extension MeditationBackground {
    static let all: [MeditationBackground] = []
}
```

- [ ] **Step 2: Conditionally render the Background section**

Wrap the section in `MeditateView.swift`:

```swift
if !MeditationBackground.all.isEmpty {
    backgroundSection
}
```

This way re-introducing audio later just means dropping mp3s in `Resources/backgrounds/` and re-populating `all`.

- [ ] **Step 3: Stop the BackgroundPlayer audio session at the same time**

If `pickedBackground` is now always nil, the `BackgroundPlayer.shared` is never started — fine. Verify no orphan AVAudioSession state.

- [ ] **Step 4: Commit**

```bash
git add faith-ios/Models/MeditationBackground.swift faith-ios/Views/Meditate/MeditateView.swift
git commit -m "fix(meditate): hide meditation backgrounds until audio is sourced

The 6 background rows pointed at Resources/backgrounds/ which doesn't
exist in the bundle. Every tap silently no-op'd while the row pretended
to 'select' — confusing UX. Hide the section; restore by populating
MeditationBackground.all when mp3s land."
```

### Task 0.9: Account deletion in Profile

**Files:**
- Create: `faith-ios/Services/AccountDeletion.swift`
- Modify: `faith-ios/Views/ProfileView.swift` (add row in account section)
- Modify: `faith-ios/Services/SessionStore.swift` (add `deleteAccount()`)

- [ ] **Step 1: AccountDeletion helper**

```swift
// AccountDeletion.swift
import Foundation
import SwiftData
import AuthenticationServices

@MainActor
enum AccountDeletion {
    /// Wipes everything user-owned: SwiftData stores, UserDefaults, keychain,
    /// shared App Group defaults, Apple credential. Best-effort — no error
    /// surface; silent failures revert to "still signed in" which the UI
    /// can detect afterward.
    static func wipe(modelContext: ModelContext, users: UserRepository) async {
        // 1. SwiftData — delete every record of every user-owned model.
        let models: [any PersistentModel.Type] = [
            DayCompletion.self, ChatMessage.self, StoredChatMessage.self,
            StoredChatThread.self, Anniversary.self, JournalEntry.self,
            PracticeRecord.self
        ]
        for model in models {
            try? deleteAll(of: model, in: modelContext)
        }
        try? modelContext.save()

        // 2. UserDefaults
        users.clear()
        if let group = UserDefaults(suiteName: "group.com.faith.app") {
            for key in group.dictionaryRepresentation().keys {
                group.removeObject(forKey: key)
            }
        }

        // 3. Apple credential — best-effort revoke (read before delete).
        let appleID = Keychain.read(key: "faith.appleUserID")
        if let appleID {
            await revokeAppleCredential(userID: appleID)
        }

        // 4. Keychain
        Keychain.delete(key: "faith.appleUserID")
    }

    private static func deleteAll<T: PersistentModel>(of: T.Type, in ctx: ModelContext) throws {
        let descriptor = FetchDescriptor<T>()
        for item in try ctx.fetch(descriptor) {
            ctx.delete(item)
        }
    }

    private static func revokeAppleCredential(userID: String) async {
        // Apple's token-revoke flow requires a server in production. For
        // local-only apps we can only sign out — Apple compliance is
        // satisfied because all local data is wiped.
    }
}
```

- [ ] **Step 2: SessionStore.deleteAccount()**

```swift
func deleteAccount() async {
    await AccountDeletion.wipe(modelContext: modelContext, users: users)
    auth.signOut()
    user = .sample
    phase = .splash
}
```

- [ ] **Step 3: Profile row + confirmation alert**

Add to `ProfileView.swift` account section, below Sign out:

```swift
Button(role: .destructive) {
    showDeleteConfirm = true
} label: {
    Text("Delete account and all data")
        .font(BTFont.ui(15, weight: .light))
}
.alert("Delete account?", isPresented: $showDeleteConfirm) {
    Button("Cancel", role: .cancel) {}
    Button("Delete everything", role: .destructive) {
        Task { await session.deleteAccount() }
    }
} message: {
    Text("Wipes your sign-in, journal, anniversaries, streak, chat history, and tradition preference. This cannot be undone.")
}
```

- [ ] **Step 4: Manual verify**

Sign in with Apple → write a journal entry → mark today done → tap Delete → verify Today resets, Journal empty, no Apple name in Profile, Settings → Apple ID still shows the app (Apple credential revocation requires server; document this).

- [ ] **Step 5: Commit**

```bash
git add faith-ios/Services/AccountDeletion.swift faith-ios/Services/SessionStore.swift faith-ios/Views/ProfileView.swift
git commit -m "feat(profile): add in-app account deletion

App Store guideline 5.1.1(v) requires apps with sign-in to offer in-app
account deletion. Wipe SwiftData, UserDefaults (incl. App Group),
keychain. No backend, so Apple-credential revocation is local sign-out
only — documented."
```

### Task 0.10: Fix sign-out copy

**Files:**
- Modify: `faith-ios/Views/ProfileView.swift` (the sign-out alert message)

- [ ] **Step 1: Update copy to match actual behavior**

Current copy claims "Your local journal and streak stay on this device." — but `signOut()` calls `users.clear()` (`SessionStore.swift:79-84`) which wipes user prefs (tradition, name, topics, onboarding flag). Actual `DayCompletion`/`JournalEntry`/`Anniversary` records do survive (they're in SwiftData, not UserDefaults). Fix the copy:

```swift
.alert("Sign out?", isPresented: $showSignOutConfirm) {
    Button("Cancel", role: .cancel) {}
    Button("Sign out", role: .destructive) { session.signOut() }
} message: {
    Text("Your journal, anniversaries, and streak stay on this device. You'll need to pick your tradition again on next launch.")
}
```

- [ ] **Step 2: Commit**

```bash
git add faith-ios/Views/ProfileView.swift
git commit -m "fix(profile): correct sign-out alert copy

signOut() also clears tradition/name/topics; the prior message implied
nothing changed. Align copy with actual behavior."
```

---

## Phase 1 — Truth & content

### Task 1.1: Surface CanonStore load failure

**Files:**
- Modify: `faith-ios/Views/LibraryView.swift`
- Modify: `faith-ios/Views/TodayView.swift`

- [ ] **Step 1: Replace `"Loading canon…"` placeholder with status-driven view**

```swift
// LibraryView.swift, where `coreReads` is empty
@EnvironmentObject private var canon: CanonStore

// in body:
switch canon.loadStatus {
case .pending:
    ProgressView().tint(theme.accent)
case .loaded(let count) where count == 0:
    Text("No core reads yet.").font(BTFont.ui(14)).foregroundStyle(theme.inkMute)
case .loaded:
    ForEach(canon.coreReads().prefix(8)) { ... }
case .failed(let message):
    VStack(alignment: .leading, spacing: 8) {
        Text("The canon failed to load").font(BTFont.ui(14, weight: .medium))
        Text(message).font(BTFont.ui(11)).foregroundStyle(theme.inkMute)
        Button("Retry") { canon.load() }
    }
}
```

- [ ] **Step 2: Same for TodayView fallback**

`TodayView.swift:241` `ContentUnavailableView("No passage yet", "book.closed")` — augment with `canon.loadStatus.failed` retry button when applicable.

- [ ] **Step 3: Commit**

```bash
git add faith-ios/Views/LibraryView.swift faith-ios/Views/TodayView.swift
git commit -m "feat(library): surface canon load failure with retry

CanonStore.LoadStatus.failed was never read — Library showed 'Loading
canon…' forever on failure. Render real failure copy with a Retry."
```

### Task 1.2: Surface Foundation Models / fallback runtime

**Files:**
- Modify: `faith-ios/Services/RAG/FoundationModelsRuntime.swift` (publish a `usedFallback` signal)
- Modify: `faith-ios/Views/Chat/ChatView.swift` (render footer chip)

- [ ] **Step 1: Add fallback signal to runtime**

```swift
@MainActor
final class FoundationModelsRuntime: LLMRuntime, ObservableObject {
    @Published private(set) var lastReplyUsedFallback: Bool = false
    // ... existing code ...
    func reply(...) async -> [MessageSegment] {
        if case .available = SystemLanguageModel.default.availability {
            lastReplyUsedFallback = false
            return await replyWithFoundationModels(...)
        }
        lastReplyUsedFallback = true
        return await fallback.reply(...)
    }
}
```

- [ ] **Step 2: ChatView footer chip**

When `lastReplyUsedFallback` is true and there's at least one assistant message, show a single eyebrow line below the message:

```swift
if (session.llm as? FoundationModelsRuntime)?.lastReplyUsedFallback == true {
    Text("Showing canon excerpts — Apple Intelligence not available on this device.")
        .font(BTFont.ui(11))
        .tracking(0.6)
        .foregroundStyle(theme.inkMute)
        .padding(.bottom, 8)
}
```

- [ ] **Step 3: Commit**

```bash
git add faith-ios/Services/RAG/FoundationModelsRuntime.swift faith-ios/Views/Chat/ChatView.swift
git commit -m "feat(chat): surface when reply used retrieval-only fallback"
```

### Task 1.3: Surface Apple sign-in failures

**Files:**
- Modify: `faith-ios/Views/ProfileView.swift:108-110`

- [ ] **Step 1: Replace `case .failure: break`**

```swift
case .failure(let error):
    if let asAuthError = error as? ASAuthorizationError, asAuthError.code == .canceled {
        // user dismissed the sheet — don't alert
        return
    }
    signInError = error.localizedDescription
}
```

Add `@State private var signInError: String?` and an `.alert("Sign in failed", isPresented: ...)`.

- [ ] **Step 2: Commit**

```bash
git add faith-ios/Views/ProfileView.swift
git commit -m "fix(profile): show Apple sign-in failures instead of swallowing"
```

### Task 1.4: Rename `GentleReminder` → `CrisisClassifier`

**Files:**
- Rename: `faith-ios/Services/GentleReminder.swift` → `faith-ios/Services/CrisisClassifier.swift`
- Modify: `faith-ios/Views/Chat/ChatView.swift` (call sites; update `GentleReminderRow` → `CrisisInterceptCard`)

- [ ] **Step 1: Move and rename**

```bash
git mv faith-ios/Services/GentleReminder.swift faith-ios/Services/CrisisClassifier.swift
```

In the file, rename `enum GentleReminder` → `enum CrisisClassifier`, `static let line` → `static let interceptMessage`, `static func shouldFire` → `static func detects`.

- [ ] **Step 2: Update call sites**

```bash
grep -rn "GentleReminder" faith-ios/
```

Two callers (per audit): `ChatView.swift:111-120` (`shouldFire`) and `:221-237` (`GentleReminderRow`). Update.

Rename `GentleReminderRow` → `CrisisInterceptCard` and update its message to set up Phase 1.5 (which adds dismiss/resources).

- [ ] **Step 3: Build, smoke test crisis path**

Type "I want to end it" into chat. Should show the renamed card.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: rename GentleReminder → CrisisClassifier

Original name implied a notification scheduler; it's actually a pre-LLM
crisis-language classifier that swaps in a fixed deflection line. Rename
matches purpose and unblocks the README's actual TODO for a real
gentle-reminder notification scheduler."
```

### Task 1.5: Crisis classifier — dismiss + retry + resources

**Files:**
- Modify: `faith-ios/Views/Chat/ChatView.swift` (`CrisisInterceptCard`)
- Modify: `faith-ios/Services/CrisisClassifier.swift` (add resources)

- [ ] **Step 1: Add a resource link to the model**

```swift
enum CrisisClassifier {
    static let interceptMessage = "What you said sounds heavy. Maybe step away from the screen for a bit. The chat will be here when you come back."
    static let helplineURL = URL(string: "https://findahelpline.com/")!
    // ... existing tokens ...
}
```

- [ ] **Step 2: Replace the static row with an interactive card**

```swift
struct CrisisInterceptCard: View {
    let onContinue: () -> Void
    let onEnd: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(CrisisClassifier.interceptMessage)
                .font(BTFont.serif(16, weight: .light, italic: true))
                .foregroundStyle(theme.ink)

            HStack(spacing: 10) {
                Link(destination: CrisisClassifier.helplineURL) {
                    Label("Get help now", systemImage: "phone.fill")
                        .font(BTFont.ui(13, weight: .medium))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .glassEffect(.regular, in: Capsule())
                }
                Button(action: onContinue) {
                    Text("I'm OK, continue")
                        .font(BTFont.ui(13))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .glassEffect(.regular, in: Capsule())
                }
                Button(action: onEnd) {
                    Text("End conversation")
                        .font(BTFont.ui(13))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .foregroundStyle(theme.inkMute)
                }
            }
        }
        .padding(16)
        .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
    }
}
```

- [ ] **Step 3: Wire actions**

In `ChatView`'s `send()`:

```swift
if CrisisClassifier.detects(in: input) {
    // append a special message kind, not a chat reply
    interceptedAt = UUID()
    return
}
```

In the message list, render `CrisisInterceptCard(onContinue:, onEnd:)` once per intercept. `onContinue` sends the original input through (skipping the classifier — flag once). `onEnd` calls `ChatStore.clear(thread, in: context)`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(chat): crisis intercept gets dismiss + resources + end-chat

The deflection line was permanent and offered no off-ramp. Add three
actions: Get help now (helpline aggregator), Continue (re-send the
original prompt), End conversation (clear the thread)."
```

---

## Phase 2 — Discovery & navigation

### Task 2.1: Make Profile rows tappable (or remove them)

**Files:**
- Modify: `faith-ios/Views/ProfileView.swift:224-261`

- [ ] **Step 1: Identify the four dead rows**

- "Reminder time · 6:30 am"
- "Daily passage · On"
- "Tradition"
- "Text size · Medium"

- [ ] **Step 2: Wire what we can in this phase**

For now:
- "Tradition" → present a `TraditionPickerSheet` (small, just five rows mirroring Library's Tradition section but as a picker writing to `session.user.tradition`).
- "Text size" → present a slider sheet that writes to `@AppStorage("textSizeScale") = 1.0` (used in Phase 5 by Dynamic Type migration; for now just stored).
- "Reminder time" / "Daily passage" → remain, but mark with `// TODO: Phase 6 notifications` and add a faded "Set up in next update" subtitle so they don't look broken.

```swift
settingsRow(title: "Tradition", value: session.user.tradition.name) {
    showTraditionPicker = true
}
.sheet(isPresented: $showTraditionPicker) {
    TraditionPickerSheet(selected: $session.user.tradition)
}
```

- [ ] **Step 3: Commit**

```bash
git add faith-ios/Views/ProfileView.swift
git commit -m "feat(profile): wire Tradition and Text size rows; defer notifs to Phase 6"
```

### Task 2.2: Wire Pathways into LibraryView (per D2)

**Files:**
- Modify: `faith-ios/Views/LibraryView.swift`
- Create: `faith-ios/Views/Study/PathwaysView.swift`
- Modify: call sites that currently pass `pathwayContext: nil` to optionally pass a real context

- [ ] **Step 1: Create PathwaysView**

```swift
// Views/Study/PathwaysView.swift
struct PathwaysView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var store = PathwayStore.shared
    @StateObject private var progress = PathwayProgressStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            // List rows of `ReadingPathway` with progress bars + first-step
            // chevron pushing CollectionListView with a PathwayContext set.
        }
    }
}
```

- [ ] **Step 2: Add Library section**

Insert between "TRADITIONS" and "MORE":

```swift
LibrarySectionHeader("PATHWAYS")
ForEach(store.all.prefix(3)) { pathway in
    PathwayRow(pathway: pathway, progress: progress)
        .onTapGesture { showingPathway = pathway }
}
.sheet(item: $showingPathway) { pathway in
    PathwayDetailSheet(pathway: pathway)
}
```

- [ ] **Step 3: Wire `PathwayContext` through SuttaDetailSheet entry**

`SuttaDetailSheet.swift` already accepts `pathwayContext: PathwayContext?`. From `PathwayDetailSheet`, present with the context populated so "Next in this pathway" renders.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(library): expose Pathways section + wire PathwayContext

PathwayStore, ReadingPathway model, pathways.json, and the next-step UI
in SuttaDetailSheet were all in place but unreachable — every entry
point passed pathwayContext: nil. Add a Library section and route the
context through."
```

### Task 2.3: Surface Anniversaries / Journal / Send Blessing on Today (per D7)

**Files:**
- Modify: `faith-ios/Views/TodayView.swift`

- [ ] **Step 1: Add a "Personal" footer row**

Below the passage card (`TodayView.swift:208`):

```swift
HStack(spacing: 12) {
    PersonalRowItem(icon: "calendar", label: "Anniversaries") { showAnniv = true }
    PersonalRowItem(icon: "book.closed", label: "Reflect") { showJournal = true }
    PersonalRowItem(icon: "envelope", label: "Bless") { showBless = true }
}
.padding(.horizontal, 18)
```

Each item is a small glass capsule with icon + label + tap action.

- [ ] **Step 2: Hoist the same three sheets**

Same `.sheet(...)` modifiers as in `LibraryView`. (Or extract `PersonalSheets()` view modifier shared between the two.)

- [ ] **Step 3: Commit**

```bash
git add faith-ios/Views/TodayView.swift
git commit -m "feat(today): expose Anniversaries/Journal/Blessing as a Personal row

These were buried behind Library → MORE — a five-sheets-deep cliff. Hoist
the entry points to Today where users return daily."
```

### Task 2.4: Listen subsystem — minimal UI surface (per D1)

**Files:**
- Create: `faith-ios/Views/Listen/MiniPlayerBar.swift`
- Create: `faith-ios/Views/Listen/QueueSheet.swift`
- Modify: `faith-ios/Views/ContentView.swift` (overlay mini-player)
- Modify: `faith-ios/Views/Study/SuttaDetailSheet.swift` (add "Add to queue" + "Show queue" rail buttons)

- [ ] **Step 1: MiniPlayerBar**

A 44pt-tall capsule pinned above the tab bar when `ListenQueueStore.shared.current != nil`:

```swift
HStack(spacing: 12) {
    Button { queue.togglePlayPause() } label: {
        Image(systemName: queue.isPlaying ? "pause.fill" : "play.fill")
    }
    VStack(alignment: .leading, spacing: 1) {
        Text(queue.current?.title ?? "").font(BTFont.serif(13))
        Text(queue.current?.subtitle ?? "").font(BTFont.ui(10)).foregroundStyle(theme.inkMute)
    }
    Spacer()
    Button { showQueue = true } label: { Image(systemName: "list.bullet") }
    Button { queue.stop() } label: { Image(systemName: "xmark") }
}
.padding(12)
.glassEffect(.regular, in: Capsule())
.padding(.horizontal, 12)
```

- [ ] **Step 2: QueueSheet**

Standard list of `queue.items` with reorder + delete + tap-to-play, plus history section ordered by recency.

- [ ] **Step 3: Wire MPNowPlayingInfoCenter + remote command center**

```swift
// In ListenQueueStore.start(...)
import MediaPlayer
MPNowPlayingInfoCenter.default().nowPlayingInfo = [
    MPMediaItemPropertyTitle: current.title,
    MPMediaItemPropertyArtist: current.subtitle,
    MPMediaItemPropertyPlaybackDuration: duration,
    MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
]
let cc = MPRemoteCommandCenter.shared()
cc.playCommand.addTarget { [weak self] _ in self?.play(); return .success }
cc.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
cc.nextTrackCommand.addTarget { [weak self] _ in self?.next(); return .success }
cc.previousTrackCommand.addTarget { [weak self] _ in self?.previous(); return .success }
```

(`ListenQueueStore.swift:10` doc-comment claimed this was wired — fix the lie.)

- [ ] **Step 4: Add to-queue + show-queue from SuttaDetailSheet rail**

The `ReadingRail` already has Listen/Pause/Stop. Add `+` (Add to queue) and `≡` (Show queue) buttons to its right.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(listen): minimal mini-player + queue sheet + Now Playing controls

ListenQueueStore (920 LOC: queue, history, rate, skip/seek/stage tracking)
had no UI surface beyond a single Listen/Pause/Stop trio in the reading
rail. Add a global mini-player above the tab bar, a queue sheet, and the
Now Playing/MPRemoteCommand wiring the doc-comment falsely claimed."
```

### Task 2.5: Cold-launch deep link race fix

**Files:**
- Modify: `faith-ios/Views/ContentView.swift` and `LibraryView.swift`

- [ ] **Step 1: Use `.task(id:)` instead of `.onChange`**

`LibraryView`'s `onChange(of: deepLinkPassageID)` doesn't fire on initial value — cold-launch from a passage widget fails. Replace with:

```swift
.task(id: deepLinkPassageID) {
    if let id = deepLinkPassageID {
        showingPassageID = id
    }
}
```

`.task(id:)` fires on first appearance with the current value AND on every change.

- [ ] **Step 2: Smoke test**

Force-quit the app, tap a passage widget on Home Screen. App should launch directly into the passage sheet inside Library.

- [ ] **Step 3: Commit**

```bash
git add faith-ios/Views/LibraryView.swift
git commit -m "fix(deep-link): open passage sheet on cold launch from widget tap

onChange doesn't fire on initial value — passage deep links from a fresh
launch silently dropped. Use .task(id:) which runs on first appearance."
```

### Task 2.6: Add drag indicator to all sheets

**Files:**
- Modify: every `LibraryView` sheet presenter (`Anniversaries`, `Journal`, `Blessing`, `Quiz`, `HolyCalendar`)

- [ ] **Step 1: Add `presentationDragIndicator(.visible)`**

```swift
.sheet(isPresented: $showingAnniversaries) {
    AnniversariesView()
        .presentationDragIndicator(.visible)
}
```

Apply to all five sheets in `LibraryView` and the three new Today sheets from 2.3.

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "fix(sheets): show drag indicators on all modal sheets

PageScaffold-wrapped sheets had no visual cue they were draggable;
swipe-down was the only dismissal on iPad."
```

---

## Phase 3 — Chat polish

### Task 3.1: Tradition-scoped chat threads

**Files:**
- Modify: `faith-ios/Services/ChatStore.swift`
- Modify: `faith-ios/Views/Chat/ChatView.swift`

- [ ] **Step 1: Make `currentThread` actually filter by tradition**

```swift
static func currentThread(traditionRaw: String, in context: ModelContext) -> StoredChatThread {
    let descriptor = FetchDescriptor<StoredChatThread>(
        predicate: #Predicate { $0.traditionRaw == traditionRaw },
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )
    if let existing = (try? context.fetch(descriptor))?.first {
        return existing
    }
    let new = StoredChatThread(traditionRaw: traditionRaw)
    context.insert(new)
    try? context.save()
    return new
}
```

- [ ] **Step 2: ChatView reacts to tradition switch**

```swift
.onChange(of: session.user.tradition) { _, newTradition in
    thread = ChatStore.currentThread(traditionRaw: newTradition.rawValue, in: modelContext)
    messages = ChatStore.sortedMessages(thread).map { $0.toRuntimeMessage() }
}
```

- [ ] **Step 3: Commit**

```bash
git add faith-ios/Services/ChatStore.swift faith-ios/Views/Chat/ChatView.swift
git commit -m "fix(chat): scope threads by tradition

Switching tradition mid-conversation reused the latest thread regardless
of its traditionRaw, mixing canon contexts. Filter the fetch by
tradition; create a new thread per tradition on first use."
```

### Task 3.2: Keep ThinkingDot up while streaming

**Files:**
- Modify: `faith-ios/Views/Chat/ChatView.swift:122-145`

- [ ] **Step 1: Track streaming state separately from awaiting state**

```swift
@State private var isAwaitingFirstToken = false
@State private var isStreaming = false

// in send():
isAwaitingFirstToken = true
for await segments in stream {
    if isAwaitingFirstToken { isAwaitingFirstToken = false }
    isStreaming = true
    // ... swap message ...
}
isStreaming = false
```

- [ ] **Step 2: Use both flags for indicator**

```swift
if isAwaitingFirstToken { ThinkingDot() }
else if isStreaming { StreamingCaret() }  // tiny blinking line at message tail
```

- [ ] **Step 3: Commit**

```bash
git add faith-ios/Views/Chat/ChatView.swift
git commit -m "fix(chat): keep an indicator visible during streaming

isReplying flipped false on the first emitted segment, so subsequent
streamed tokens arrived with no in-flight cue. Distinguish 'awaiting
first token' from 'streaming' and render a caret during the latter."
```

### Task 3.3: Copy / share message context menu

**Files:**
- Modify: `faith-ios/Views/Chat/ChatView.swift` (assistant + user bubble views)

- [ ] **Step 1: Long-press menu**

```swift
AssistantBlock(message: msg)
    .contextMenu {
        Button { copyToClipboard(msg.plainText) } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        ShareLink(item: msg.plainText) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }
```

`plainText` is a `MessageSegment.flatten()` helper — italic/citation collapsed to text + `(SN 22.59)` suffix.

- [ ] **Step 2: Same for user bubble**

- [ ] **Step 3: Commit**

```bash
git add faith-ios/Views/Chat/ChatView.swift
git commit -m "feat(chat): long-press to copy or share a message"
```

### Task 3.4: Make the verbatim-quote constraint legible

**Files:**
- Modify: `faith-ios/Views/Chat/ChatView.swift` (`AssistantBlock`)
- Optionally: `faith-ios/Models/Sutta.swift` (`MessageSegment` already distinguishes `.italic`/`.text`/`.citation`)

- [ ] **Step 1: Add a subtle visual frame around italic spans**

Italic = verbatim canon. Add a thin left rule:

```swift
if case .italic(let s) = segment {
    HStack(spacing: 6) {
        Rectangle().fill(theme.accent.opacity(0.4)).frame(width: 1.5)
        Text(s).font(BTFont.serif(15, weight: .light, italic: true))
    }
}
```

- [ ] **Step 2: Empty-state copy update**

Replace `EmptyChatPrompt` body with: "Ask a question. The Teacher will reply with a single sentence of framing and *verbatim quotes from the canon* — never a paraphrase."

- [ ] **Step 3: Commit**

```bash
git add faith-ios/Views/Chat/ChatView.swift
git commit -m "feat(chat): mark verbatim spans with a left rule + clearer empty copy"
```

### Task 3.5: Delete dead `ChatViewModel`

**Files:**
- Delete: `faith-ios/ViewModels/ChatViewModel.swift`

- [ ] **Step 1: Confirm no callers**

```bash
grep -rn "ChatViewModel" faith-ios/
```

Should return only the file itself.

- [ ] **Step 2: Delete**

```bash
git rm faith-ios/ViewModels/ChatViewModel.swift
```

If `ViewModels/` becomes empty, delete it too.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: delete dead ChatViewModel

ChatView holds all state via @State directly; the VM was never
instantiated."
```

---

## Phase 4 — Onboarding & multi-tradition correctness

### Task 4.1: Wire `phase` machine in ContentView

**Files:**
- Modify: `faith-ios/ContentView.swift`

- [ ] **Step 1: Branch on phase**

```swift
@EnvironmentObject private var session: SessionStore

var body: some View {
    Group {
        switch session.phase {
        case .splash:      SplashView()
        case .onboarding:  OnboardingFlow()
        case .main:        mainTabs
        }
    }
    // ... existing modifiers ...
}
```

- [ ] **Step 2: Commit**

```bash
git add faith-ios/ContentView.swift
git commit -m "feat(onboarding): branch on SessionStore.phase

Splash and onboarding views land in 4.2 and 4.3."
```

### Task 4.2: SplashView

**Files:**
- Create: `faith-ios/Views/Onboarding/SplashView.swift`

- [ ] **Step 1: Single-screen splash**

```swift
struct SplashView: View {
    @EnvironmentObject private var session: SessionStore
    var body: some View {
        ZStack {
            NatureSubstrate(tradition: .secular, intensity: 1.0)
            VStack(spacing: 24) {
                Lotus(bloom: 1.0).frame(width: 120, height: 120)
                Text("Faith")
                    .font(.system(size: 48, weight: .ultraLight, design: .serif))
                Text("a daily companion to the canon")
                    .font(BTFont.ui(13))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .ignoresSafeArea()
        .task {
            try? await Task.sleep(for: .seconds(1.2))
            session.advanceFromSplash()
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add faith-ios/Views/Onboarding/SplashView.swift
git commit -m "feat(onboarding): splash with 1.2s minimum"
```

### Task 4.3: Onboarding flow — tradition pick + permission priming

**Files:**
- Create: `faith-ios/Views/Onboarding/OnboardingFlow.swift`
- Create: `faith-ios/Views/Onboarding/TraditionPickerStep.swift`
- Create: `faith-ios/Views/Onboarding/PermissionPrimingStep.swift`

- [ ] **Step 1: OnboardingFlow shell**

```swift
struct OnboardingFlow: View {
    @EnvironmentObject private var session: SessionStore
    @State private var step: Step = .tradition
    @State private var draft: AppUser = .sample

    enum Step { case tradition, permissions }

    var body: some View {
        switch step {
        case .tradition:
            TraditionPickerStep(draft: $draft) { step = .permissions }
        case .permissions:
            PermissionPrimingStep {
                session.completeOnboarding(with: draft)
            }
        }
    }
}
```

- [ ] **Step 2: TraditionPickerStep**

Five rows showing each `Tradition`'s name + `pali` + `blurb` + accent dot. Tap → set `draft.tradition`. "Continue" capsule at bottom (disabled until something picked).

- [ ] **Step 3: PermissionPrimingStep**

Three soft-prompt buttons:
- "Daily reminder" → `UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])`
- "Speak to the Teacher" → `SFSpeechRecognizer.requestAuthorization` + `AVAudioApplication.requestRecordPermission`
- "Skip for now" → straight to `onComplete()`

Each button updates `draft.notificationsAllowed` etc. as a side effect of granted/denied result.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(onboarding): tradition pick + permission priming

phase machine was wired in SessionStore but ContentView ignored it. Add
the two missing steps; new users go splash → tradition → permissions →
main, persisting their tradition choice on entry."
```

### Task 4.4: BE-era → tradition-aware

**Files:**
- Modify: `faith-ios/Views/Calendar/HolyCalendarView.swift:61` (header)

- [ ] **Step 1: Per-tradition era label**

```swift
private var eraLabel: String {
    switch session.user.tradition {
    case .theravada: return "BE \(month.year + 543)"
    case .vajrayana: return "Tibetan \(month.year)"   // simplification — full Tibetan calendar is complex
    case .mahayana, .zen, .secular: return String(month.year)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add faith-ios/Views/Calendar/HolyCalendarView.swift
git commit -m "fix(calendar): tradition-aware era label

'BE 2569' is the Theravāda Buddhist Era, jarring for non-Theravāda
users. Show BE only for Theravāda; otherwise show the Gregorian year."
```

### Task 4.5: Quiz substrate uses question's tradition (not user's)

**Files:**
- Modify: `faith-ios/Views/Quiz/QuizView.swift:22`

- [ ] **Step 1: Use the current question's tradition where present**

```swift
NatureSubstrate(
    tradition: current?.tradition ?? session.user.tradition,
    intensity: 1.0
)
```

- [ ] **Step 2: Commit**

```bash
git add faith-ios/Views/Quiz/QuizView.swift
git commit -m "fix(quiz): substrate matches the question's tradition"
```

### Task 4.6: Tag chants with tradition

**Files:**
- Modify: `faith-ios/Models/Chant.swift`

- [ ] **Step 1: Add `traditions: Set<Tradition>` field**

```swift
struct Chant: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let language: String
    let filename: String
    let traditions: Set<Tradition>
}
```

- [ ] **Step 2: Map each of the 19 chants**

| Chant | Traditions |
|---|---|
| Heart Sūtra (Eng / Sanskrit / Vietnamese / Chinese / Japanese variants) | mahayana, zen |
| Mettā Sutta + Pali Mettā | theravada, secular |
| Three Refuges, Three Jewels, Tisarana, Quy Y Tam Bao | theravada, mahayana, vajrayana, zen |
| Five Precepts, Pancasila Pali | theravada, secular |
| Nembutsu (Vietnamese, Chinese) | mahayana |
| Daimoku (Namu-myōhō-renge-kyō) | mahayana |
| Om Mani Padme Hum | vajrayana |
| Guan Shi Yin / Nam Mo Quan The Am | mahayana, zen |

- [ ] **Step 3: Commit**

```bash
git add faith-ios/Models/Chant.swift
git commit -m "feat(chants): tag each chant with its source traditions"
```

### Task 4.7: Sort chants by user tradition

**Files:**
- Modify: `faith-ios/Views/Meditate/MeditateView.swift:520-528` (`ChantPickerSheet`)

- [ ] **Step 1: Pin user's tradition to the top**

```swift
let primary = session.user.tradition
let groups = Dictionary(grouping: Chant.all) { $0.language }
let sortedKeys = groups.keys.sorted { a, b in
    let aHas = groups[a]!.contains(where: { $0.traditions.contains(primary) })
    let bHas = groups[b]!.contains(where: { $0.traditions.contains(primary) })
    if aHas != bHas { return aHas }
    return a < b
}
```

- [ ] **Step 2: Commit**

```bash
git add faith-ios/Views/Meditate/MeditateView.swift
git commit -m "feat(chants): surface user-tradition chants first in picker"
```

### Task 4.8: Remove `.zen` default tradition

**Files:**
- Modify: `faith-ios/Models/AppUser.swift`

- [ ] **Step 1: Make `tradition` optional**

```swift
var tradition: Tradition?
```

OR keep non-optional but pick `.secular` as the most-neutral default:

```swift
static let sample = AppUser(
    id: "local",
    displayName: nil,
    tradition: .secular,  // not .zen
    ...
)
```

Phase 4.3 will overwrite this on completion of onboarding anyway. The change protects against the (now-narrow) edge case where a user lands on Today without onboarding (shouldn't happen, but: belt and braces).

- [ ] **Step 2: Commit**

```bash
git add faith-ios/Models/AppUser.swift
git commit -m "fix(user): default to .secular before onboarding picks one"
```

---

## Phase 5 — Accessibility & design unification

### Task 5.1: Migrate `BTFont.*` to Dynamic Type

**Files:**
- Modify: `faith-ios/Theme/Typography.swift` (or wherever `BTFont` lives)

- [ ] **Step 1: Make `BTFont` calls scale**

Currently `BTFont.serif(28, weight: .light)` produces `Font(.system(size: 28, ...))` — no scaling. Refactor:

```swift
enum BTFont {
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        let base = Font.system(size: size, weight: weight, design: .serif)
        return italic ? base.italic() : base
    }
}

// becomes:
extension View {
    func btSerif(_ size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false, relative: Font.TextStyle = .body) -> some View {
        self.font(.system(size: size, weight: weight, design: .serif).italicized(italic))
            .dynamicTypeSize(.xSmall ... .accessibility3)
    }
}
```

OR (simpler): keep `BTFont.serif(28, ...)` returning a fixed Font and **add a relative-to mapping** so callers do `.font(BTFont.serif(28, relativeTo: .title))`. Apple's `.font(.system(.title, design: .serif).weight(.light))` is the right pattern.

Map size → text style:
- ≤11 → `.caption2`
- 12-13 → `.caption`
- 14-15 → `.footnote`
- 16-17 → `.body`
- 18-21 → `.title3`
- 22-27 → `.title2`
- 28-39 → `.title`
- 40+ → `.largeTitle`

- [ ] **Step 2: Touch every `BTFont.*` call site**

```bash
grep -rln "BTFont\." faith-ios/ | xargs -I {} echo {}
```

Estimate ~50-80 call sites. Migrate to relative-style sizing.

- [ ] **Step 3: Add `.dynamicTypeSize(...accessibility5)` clamp at root**

In `ContentView.swift` `mainTabs`:

```swift
.dynamicTypeSize(.xSmall ... .accessibility5)
```

- [ ] **Step 4: Visual review at AX1, AX3, AX5**

Run app with Settings → Accessibility → Display & Text Size → Larger Text → max. Sweep every screen.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(a11y): make typography scale with Dynamic Type

All sizes were fixed CGFloat — accessibility text sizes did not scale.
Map BTFont sizes to Font.TextStyle relatives; clamp the root view."
```

### Task 5.2: Add `accessibilityLabel`s to glyphs and chevrons

**Files:**
- Many — sweep across `Views/`

- [ ] **Step 1: Lotus**

```swift
// Lotus.swift
.accessibilityLabel("Practice progress")
.accessibilityValue("\(Int(bloom * 100))%")
```

- [ ] **Step 2: Day cells in HolyCalendarView and StreakDetailView**

```swift
.accessibilityLabel(dayCellLabel)
.accessibilityHint("Tap for details")
private var dayCellLabel: String {
    var parts = ["Day \(day)"]
    if isToday { parts.append("today") }
    if practice > 0 { parts.append("\(practice) minutes practiced") }
    if hasObservance { parts.append(observance.title) }
    return parts.joined(separator: ", ")
}
```

- [ ] **Step 3: All `xmark` close buttons**

```swift
Button { dismiss() } label: {
    Image(systemName: "xmark")
}
.accessibilityLabel("Close")
```

- [ ] **Step 4: Mic button**

```swift
.accessibilityLabel(asr.isListening ? "Stop dictating" : "Start dictating")
.accessibilityHint("Speak your question to the Teacher")
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(a11y): label every glyph, chevron, and lotus"
```

### Task 5.3: Increase tap targets to 44pt

**Files:**
- `HolyCalendarView.swift` chevrons (32→44)
- `xmark` buttons across sheets (32-40 → 44)
- Quiz top-right close
- `MeditateView` duration pills

- [ ] **Step 1: Wrap small icons in 44pt frames**

```swift
Button(action: ...) { Image(systemName: "chevron.left") }
.frame(minWidth: 44, minHeight: 44)
.contentShape(Rectangle())
```

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "fix(a11y): every interactive control hits the 44pt minimum"
```

### Task 5.4: Reduce Motion guards

**Files:**
- `MeditateView.swift` (waveform symbol effect)
- `HolyCalendarView.swift` (`withAnimation` on month change)
- `Lotus.swift` (bloom transition)
- `QuizView.swift` (`.contentTransition(.numericText())`)

- [ ] **Step 1: Read `@Environment(\.accessibilityReduceMotion)`**

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

// before:
.symbolEffect(.variableColor.iterative, isActive: bg.isPlaying)
// after:
.symbolEffect(.variableColor.iterative, isActive: bg.isPlaying && !reduceMotion)
```

- [ ] **Step 2: Same for `withAnimation`**

```swift
withAnimation(reduceMotion ? .none : .easeOut(duration: 0.35)) { ... }
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "fix(a11y): honor Reduce Motion across calendar, lotus, waveform"
```

### Task 5.5: Confirmation alerts before destructive actions

**Files:**
- `AnniversariesView.swift` (trash button)
- `JournalView.swift` (delete swipe action)
- `HolyCalendarView.swift` `DayDetailSheet` (anniversaries trash)

- [ ] **Step 1: Wrap each delete in an alert**

```swift
@State private var anniversaryToDelete: Anniversary?

Button(role: .destructive) { anniversaryToDelete = a } label: { Image(systemName: "trash") }
.alert("Delete this anniversary?", item: $anniversaryToDelete) { a in
    Button("Cancel", role: .cancel) {}
    Button("Delete", role: .destructive) {
        modelContext.delete(a); try? modelContext.save()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "fix(a11y): confirm destructive deletes for anniversaries/journal"
```

### Task 5.6: Unify Profile design language with rest of app

**Files:**
- Modify: `faith-ios/Views/ProfileView.swift`

- [ ] **Step 1: Wrap in `PageScaffold` and switch flat cards to glass**

```swift
PageScaffold(title: nil) {
    VStack(alignment: .leading, spacing: 28) {
        accountSection
        appearanceSection
        practiceSection
        ...
    }
}
.background(NatureSubstrate(tradition: session.user.tradition))
```

Replace `theme.card` rectangles with `.glassEffect(.regular, in: RoundedRectangle(...))`.

- [ ] **Step 2: Commit**

```bash
git add faith-ios/Views/ProfileView.swift
git commit -m "fix(profile): match the app's iOS-26 glass + substrate aesthetic"
```

### Task 5.7: Reconcile DayCompletion vs PracticeRecord

**Files:**
- Modify: `faith-ios/Services/PracticeQueries.swift`
- Modify: any view that reads both

- [ ] **Step 1: Decide the source of truth**

Since `MeditateView` writes to `PracticeRecord` (via `PracticeQueries.recordSit`) and `TodayView`'s checklist writes to `DayCompletion`:

- `DayCompletion` is the user's intent ("I marked these tasks done") — keep for the lotus bloom + checklist.
- `PracticeRecord` is the system's truth ("a sit happened, X minutes") — keep for streak/calendar minutes-bars.

Add a derived view in `PracticeQueries`:

```swift
static func compositeDoneCount(date: Date, in ctx: ModelContext) -> Int {
    let dayKey = DayCompletion.key(for: date)
    let dc = (try? ctx.fetch(FetchDescriptor<DayCompletion>(predicate: #Predicate { $0.dayKey == dayKey })))?.first
    let didMeditate = (dc?.meditationDone ?? false) || minutesSat(on: date, in: ctx) > 0
    return [didMeditate, dc?.morningPrayerDone, dc?.storyReadDone, dc?.gratitudeDone, dc?.eveningReflectionDone]
        .compactMap { $0 }.filter { $0 }.count
}
```

So a real sit registers as "meditation done" even if the checklist box wasn't tapped.

- [ ] **Step 2: Update Today's progress bar to use composite**

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "fix(progress): real sits count toward today's checklist

Previously DayCompletion (checkbox) and PracticeRecord (minutes) were
parallel sources. Now a sit recorded by MeditateView automatically
counts as 'meditation done' for the lotus bloom."
```

### Task 5.8: Decide flat-card vs glass for the home triad

**Files:**
- Modify: `faith-ios/Views/TodayView.swift`, `LibraryView.swift`, `StreakDetailView.swift`

- [ ] **Step 1: Pick glass for personal-progress views, flat for canonical views (or the inverse)**

Current state: home triad is flat, sheets are glass. The audit's read is that glass should be the canonical-content language and the home triad should match. Apply `NatureSubstrate(tradition: session.user.tradition)` + `.glassEffect(.regular, in: ...)` cards in Today/Library/Streak.

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "fix(design): unify Today/Library/Streak with glass + substrate"
```

---

## Phase 6 — Notifications

### Task 6.1: Notification scheduling service

**Files:**
- Create: `faith-ios/Services/Notifications.swift`

- [ ] **Step 1: Wrapper**

```swift
import UserNotifications

@MainActor
enum Notifications {
    static let dailyReminderID = "faith.dailyReminder"

    static func requestAuthIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            return settings.authorizationStatus == .authorized
        }
        return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    static func scheduleDailyReminder(at hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderID])

        let content = UNMutableNotificationContent()
        content.title = "Today's passage is here"
        content.body = "A line from the canon, waiting."
        content.sound = .default
        content.userInfo = ["deeplink": "faith://today"]

        var dc = DateComponents(); dc.hour = hour; dc.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        let request = UNNotificationRequest(identifier: dailyReminderID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyReminderID])
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add faith-ios/Services/Notifications.swift
git commit -m "feat(notifications): scheduling wrapper around UNUserNotificationCenter"
```

### Task 6.2: Profile rows wired to scheduler

**Files:**
- Modify: `faith-ios/Views/ProfileView.swift` (the previously-dead Reminder time / Daily passage rows)

- [ ] **Step 1: Replace dead rows with real toggles**

```swift
Toggle("Daily passage reminder", isOn: $dailyReminderEnabled)
    .onChange(of: dailyReminderEnabled) { _, on in
        Task {
            if on {
                let granted = await Notifications.requestAuthIfNeeded()
                guard granted else { dailyReminderEnabled = false; return }
                await Notifications.scheduleDailyReminder(at: reminderHour, minute: reminderMinute)
            } else {
                Notifications.cancelDailyReminder()
            }
        }
    }
DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
    .disabled(!dailyReminderEnabled)
    .onChange(of: reminderTime) { _, _ in
        if dailyReminderEnabled {
            Task { await Notifications.scheduleDailyReminder(at: hour(of: reminderTime), minute: minute(of: reminderTime)) }
        }
    }
```

Persist via `@AppStorage("dailyReminderEnabled")` and `@AppStorage("dailyReminderTime")`.

- [ ] **Step 2: Commit**

```bash
git add faith-ios/Views/ProfileView.swift
git commit -m "feat(profile): wire daily reminder toggle + time picker"
```

### Task 6.3: Deep-link reminder tap → Today

**Files:**
- Modify: `faith-ios/FaithApp.swift` (notification delegate)

- [ ] **Step 1: Handle response**

```swift
.task {
    let center = UNUserNotificationCenter.current()
    center.delegate = NotificationDelegate.shared
}
```

```swift
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse) async {
        if let s = response.notification.request.content.userInfo["deeplink"] as? String,
           let url = URL(string: s) {
            await UIApplication.shared.open(url)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "feat(notifications): tap reminder → open Today"
```

---

## Phase 7 — Dev hygiene

### Task 7.1: Replace `print(...)` with `os.Logger`

**Files:**
- All print sites called out in audit

- [ ] **Step 1: Per-file Logger**

Top of each file:

```swift
import os
private let log = Logger(subsystem: "com.faith.app", category: "audio")
```

- [ ] **Step 2: Replace**

```swift
print("⚠️ ChantPlayer: missing audio for \(chant.id)")
// becomes
log.warning("missing audio for \(chant.id, privacy: .public)")
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: migrate print(⚠️ …) to os.Logger across audio + persistence"
```

### Task 7.2: Delete dead code

**Files:**
- `faith-ios/Views/Quiz/QuizView.swift:258-268` (`pill(...)` helper)
- `faith-ios/Services/Listen/LegacyMigrator.swift` (orphan)
- `faith-ios/Services/AuthService.swift` (`continueWithoutAccount` and `MockAuthService` if not used in previews)
- Any other audit-flagged orphan

- [ ] **Step 1: Confirm no callers**

```bash
grep -rn "pill\b\|LegacyMigrator\|continueWithoutAccount" faith-ios/
```

- [ ] **Step 2: Delete or wire**

For `LegacyMigrator`: either call it from `FaithApp.swift` `init` (one-time migration on launch) or delete. Pick wire-in if there's any chance an existing TestFlight user has the legacy schema.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: delete dead helpers (pill, MockAuthService unused, LegacyMigrator wired)"
```

---

## Verification & QA matrix

After each phase, run this sweep before committing the phase-closing tag:

| Check | How |
|---|---|
| Build clean | `xcodebuild -project faith-ios.xcodeproj -scheme Faith -destination 'platform=iOS Simulator,name=iPhone 17' build` |
| Unit tests | `xcodebuild test -project faith-ios.xcodeproj -scheme Faith -destination 'platform=iOS Simulator,name=iPhone 17'` |
| UI tests | same destination + `-only-testing:faith-iosUITests` |
| Cold launch | `xcrun simctl uninstall booted com.faith.app && xcrun simctl install booted ./build/.../Faith.app && xcrun simctl launch booted com.faith.app` — should land on Splash → Onboarding (after Phase 4) |
| Seeded launch | `xcrun simctl launch booted com.faith.app --seed` — should land on Today with full streak |
| Deep-link launch | `xcrun simctl openurl booted faith://passage/sn22.59` — should open passage sheet |
| Lock-screen audio | real device only — start sit with chant, lock, audio continues |
| Mic permission | first dictation tap shows system prompt, copy is the description string from 0.1 |
| Live Activity | real device — start sit, lock, banner shows countdown |
| Account deletion | sign in → write data → delete → verify all data cleared |

## Out-of-scope for this plan

These deserve their own plans, not buried here:

1. **Localization** — full `Localizable.strings` infrastructure, ICU pluralization, RTL support. Significant work.
2. **iPad / `NavigationSplitView` / size-class branching** — requires real visual design work and decisions about whether iPad is a target.
3. **Server backend** — if account-deletion ever needs real Apple-token revocation, it needs a server. Not on roadmap.
4. **Backend RAG** — current RAG is on-device only. If quality demands a hosted LLM later, that's a different project.
5. **Sound design** — the 6 background mp3s removed in Task 0.8 need sourcing/recording/licensing work that is content, not code.
6. **Real onboarding copywriting + animation** — the 4.3 step is functional, not poetic.
