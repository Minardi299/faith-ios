# Remove User-Facing Tradition Picker — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove every UI that lets the user pick/see a tradition, while keeping `Tradition` as content metadata (passage tradition, Library tradition browse, per-question Quiz substrate).

**Architecture:** Eleven small forward-only commits. Each task leaves the build green and is reversible. The order is leaves-first: introduce a default that lets callers drop the argument, then strip callers, then strip the field/state itself. No SwiftData migrations — schema fields (`StoredChatThread.traditionRaw`) stay; `AppUser.tradition` removal leans on `JSONDecoder`'s default "ignore unknown keys" behavior.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, iOS 26.0+, Xcode 26+. Branch: `feature-hoang`. Build scheme: `faith-ios`. Repo: `/Users/ggix/faith-ios` (NO worktree — work directly on the branch).

**Spec:** [docs/superpowers/specs/2026-05-11-remove-user-tradition.md](../specs/2026-05-11-remove-user-tradition.md)

**Note on TDD:** This is a pure deletion/refactor. There is no new behavior to test-drive. The acceptance signal for each task is a clean build + the spec's verification list still passing at the end. Add a Swift Testing case only where a small invariant could regress silently (one such case in Task 11).

---

## File Structure

| File | Disposition |
|---|---|
| `faith-ios/Views/Onboarding/OnboardingFlow.swift` | **delete** |
| `faith-ios/Views/Onboarding/TraditionPickerStep.swift` | **delete** |
| `faith-ios/Views/Onboarding/PermissionPrimingStep.swift` | **delete** |
| `faith-ios/Views/Onboarding/SplashView.swift` | **move** → `faith-ios/Views/SplashView.swift` |
| `faith-ios/Views/Onboarding/` | **remove dir** (empty after the above) |
| `faith-ios/ContentView.swift` | modify (local splash state; drop phase switch) |
| `faith-ios/Services/SessionStore.swift` | modify (delete `AppPhase`, `phase`, `completeOnboarding`, `advanceFromSplash`, `setTradition`) |
| `faith-ios/Services/UserRepository.swift` | modify (delete `hasCompletedOnboarding`) |
| `faith-ios/Models/AppUser.swift` | modify (delete `tradition` field) |
| `faith-ios/Views/ProfileView.swift` | modify (delete Tradition row + `TraditionPickerSheet`) |
| `faith-ios/Services/ChatStore.swift` | modify (drop tradition predicate; signature change) |
| `faith-ios/Views/Chat/ChatView.swift` | modify (drop `.onChange(of: tradition)`; update call sites) |
| `faith-ios/Views/Calendar/HolyCalendarView.swift` | modify (`eraLabel` → year string) |
| `faith-ios/Views/Meditate/MeditateView.swift` | modify (chant picker groups by `language` only) |
| `faith-ios/Views/TodayView.swift` | modify (`NatureSubstrate()` default) |
| `faith-ios/Views/LibraryView.swift` | modify (`NatureSubstrate()` default; pathways natural order) |
| `faith-ios/Views/StreakDetailView.swift` | modify (`NatureSubstrate()` default) |
| `faith-ios/Views/Study/PathwaysView.swift` | modify (pathways natural order) |
| `faith-ios/Views/Components/NatureSubstrate.swift` | modify (default `tradition: Tradition = .secular`) |
| `faith-ios/FaithApp.swift` | modify (only if it currently reads `SessionStore.phase` — verify) |
| `faith-iosTests/AppUserCodableTests.swift` | **create** (one regression test for legacy-blob decode) |

---

## Task 1: Default `NatureSubstrate.tradition` to `.secular`

**Why first:** callers can drop the explicit `session.user.tradition` argument once the parameter has a default. This is a non-breaking change.

**Files:**
- Modify: `faith-ios/Views/Components/NatureSubstrate.swift`

- [ ] **Step 1: Read the current signature**

```bash
sed -n '1,30p' faith-ios/Views/Components/NatureSubstrate.swift
```

The current signature is approximately `struct NatureSubstrate { let tradition: Tradition; var dimming: Double = 0.0; ... }` or via an `init`.

- [ ] **Step 2: Add a default value to `tradition`**

Change the property/initializer to default to `.secular`. Two forms depending on whether the property is a stored `let` or set via `init`:

```swift
// If it's a stored property used positionally:
struct NatureSubstrate: View {
    var tradition: Tradition = .secular
    var dimming: Double = 0.0
    // ... existing body ...
}
```

If there's an explicit `init`, change it to:

```swift
init(tradition: Tradition = .secular, dimming: Double = 0.0) {
    self.tradition = tradition
    self.dimming = dimming
}
```

Do not touch `Tradition.substrateGradient` or the body — only the default value of the constructor parameter.

- [ ] **Step 3: Build**

```bash
cd /Users/ggix/faith-ios
xcodebuild -project faith-ios.xcodeproj -scheme faith-ios -destination 'platform=iOS Simulator,name=iPhone 17' -quiet build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`. Existing callers (still passing `tradition:`) keep working.

- [ ] **Step 4: Commit**

```bash
git add faith-ios/Views/Components/NatureSubstrate.swift
git commit -m "$(cat <<'EOF'
refactor(substrate): default NatureSubstrate tradition to .secular

Enables call-site simplification — callers that don't need a specific
tradition can drop the argument. Behavior unchanged for callers that
still pass an explicit tradition (e.g. Quiz uses the question's
tradition, Library tradition-browse uses the section's).

Task 1 of docs/superpowers/plans/2026-05-11-remove-user-tradition.md
EOF
)"
```

---

## Task 2: Stop passing user tradition to NatureSubstrate

**Files:**
- Modify: `faith-ios/Views/TodayView.swift`
- Modify: `faith-ios/Views/LibraryView.swift` (only the top-level substrate call; the TraditionBrowseView substrate per tradition keeps its arg)
- Modify: `faith-ios/Views/StreakDetailView.swift`

- [ ] **Step 1: Find all call sites that pass user tradition**

```bash
cd /Users/ggix/faith-ios
grep -rn "NatureSubstrate" faith-ios/Views/ | grep "session.user.tradition"
```

Expected matches: roughly TodayView, LibraryView, StreakDetailView. Possibly ProfileView and others added during the recent design-unification pass.

- [ ] **Step 2: For each call site, replace the argument with the default**

Pattern:

```swift
// before
NatureSubstrate(tradition: session.user.tradition)
    .ignoresSafeArea()

// after
NatureSubstrate()
    .ignoresSafeArea()
```

If a call passed `dimming:` alongside, keep that arg:

```swift
// before
NatureSubstrate(tradition: session.user.tradition, dimming: 0.2)

// after
NatureSubstrate(dimming: 0.2)
```

**Do NOT touch** these intentional callers:
- The Quiz substrate (`NatureSubstrate(tradition: current?.tradition ?? .secular)` or similar — keeps the question's tradition)
- The `TraditionBrowseView` substrate (uses the section's tradition, not the user's)
- The Pathway-section row substrate, if any uses the pathway's tradition

In other words: leave calls that pass a *content-driven* tradition alone; remove only the calls that pass `session.user.tradition`.

- [ ] **Step 3: Build**

```bash
xcodebuild -project faith-ios.xcodeproj -scheme faith-ios -destination 'platform=iOS Simulator,name=iPhone 17' -quiet build 2>&1 | tail -3
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add faith-ios/Views/
git commit -m "$(cat <<'EOF'
refactor: stop passing user tradition to NatureSubstrate

Today, Library top-level, and StreakDetail substrates now use the
NatureSubstrate default (.secular). Content-driven substrates
(Quiz per-question, TraditionBrowseView per-tradition) keep their
explicit arguments.

Task 2 of docs/superpowers/plans/2026-05-11-remove-user-tradition.md
EOF
)"
```

---

## Task 3: One global chat thread (revert tradition scoping)

**Files:**
- Modify: `faith-ios/Services/ChatStore.swift`
- Modify: `faith-ios/Views/Chat/ChatView.swift`

- [ ] **Step 1: Simplify `ChatStore.currentThread`**

Open `faith-ios/Services/ChatStore.swift`. Replace the `currentThread(traditionRaw:in:)` function with one that takes no `traditionRaw` and writes `"secular"` to new threads:

```swift
@MainActor
enum ChatStore {
    /// Returns the most recent thread, creating one if none exists.
    /// New threads write traditionRaw = "secular" — the field is kept in
    /// the schema for compatibility but no longer scopes anything.
    static func currentThread(in context: ModelContext) -> StoredChatThread {
        let descriptor = FetchDescriptor<StoredChatThread>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        let new = StoredChatThread(traditionRaw: "secular")
        context.insert(new)
        try? context.save()
        return new
    }

    static func append(_ message: ChatMessage, to thread: StoredChatThread, in context: ModelContext) {
        let stored = StoredChatMessage.from(message, in: thread)
        context.insert(stored)
        try? context.save()
    }

    static func sortedMessages(_ thread: StoredChatThread) -> [StoredChatMessage] {
        thread.messages.sorted { $0.timestamp < $1.timestamp }
    }

    static func clear(_ thread: StoredChatThread, in context: ModelContext) {
        for msg in thread.messages {
            context.delete(msg)
        }
        thread.messages.removeAll()
        try? context.save()
    }
}
```

(Keep `append`, `sortedMessages`, `clear` exactly as they are — only `currentThread` changes.)

- [ ] **Step 2: Update ChatView's call sites**

```bash
grep -n "currentThread" faith-ios/Views/Chat/ChatView.swift
```

Expected: 2-3 hits. For each, drop the `traditionRaw:` argument:

```swift
// before
thread = ChatStore.currentThread(traditionRaw: session.user.tradition.rawValue, in: context)

// after
thread = ChatStore.currentThread(in: context)
```

- [ ] **Step 3: Remove the `onChange(of: session.user.tradition)` modifier**

```bash
grep -n "onChange.*tradition" faith-ios/Views/Chat/ChatView.swift
```

Delete the entire `.onChange(of: session.user.tradition) { ... }` block — it was the Phase 3.1 watcher that reset the thread on tradition change.

- [ ] **Step 4: Build**

```bash
xcodebuild -project faith-ios.xcodeproj -scheme faith-ios -destination 'platform=iOS Simulator,name=iPhone 17' -quiet build 2>&1 | tail -3
```

- [ ] **Step 5: Commit**

```bash
git add faith-ios/Services/ChatStore.swift faith-ios/Views/Chat/ChatView.swift
git commit -m "$(cat <<'EOF'
revert(chat): one global thread (no tradition scoping)

ChatStore.currentThread drops the traditionRaw parameter and always
returns the most recent thread. New threads still write
traditionRaw = "secular" because the SwiftData column stays in the
schema (avoiding a migration). ChatView's onChange-of-tradition watcher
is removed.

Task 3 of docs/superpowers/plans/2026-05-11-remove-user-tradition.md
EOF
)"
```

---

## Task 4: Revert chant picker tradition sorting

**Files:**
- Modify: `faith-ios/Views/Meditate/MeditateView.swift`

- [ ] **Step 1: Read the `ChantPickerSheet` body**

```bash
grep -n "orderedLanguageGroups\|ChantPickerSheet\|@EnvironmentObject" faith-ios/Views/Meditate/MeditateView.swift | head -20
```

`ChantPickerSheet` was modified in Phase 4.7 to prioritize the user's tradition. We're reverting that.

- [ ] **Step 2: Replace `orderedLanguageGroups` with simple language grouping**

Find the `orderedLanguageGroups` computed property inside `ChantPickerSheet`. Replace with a property that groups by language alone, sorted by the order languages first appear in `Chant.all`:

```swift
private var orderedLanguageGroups: [(language: String, chants: [Chant])] {
    var seen: [String] = []
    var byLanguage: [String: [Chant]] = [:]
    for chant in Chant.all {
        if byLanguage[chant.language] == nil {
            seen.append(chant.language)
        }
        byLanguage[chant.language, default: []].append(chant)
    }
    return seen.map { ($0, byLanguage[$0] ?? []) }
}
```

This preserves the order chants appear in the model file (English, Pali, Sanskrit, Vietnamese, Tibetan, Chinese, Japanese — the original Phase 4.7 ordering).

- [ ] **Step 3: Remove `@EnvironmentObject session` from `ChantPickerSheet`**

If `ChantPickerSheet` has `@EnvironmentObject private var session: SessionStore` and it's no longer used in the struct, delete that line. (Verify by grepping for `session.` within the struct after the edit.)

- [ ] **Step 4: Build**

```bash
xcodebuild -project faith-ios.xcodeproj -scheme faith-ios -destination 'platform=iOS Simulator,name=iPhone 17' -quiet build 2>&1 | tail -3
```

- [ ] **Step 5: Commit**

```bash
git add faith-ios/Views/Meditate/MeditateView.swift
git commit -m "$(cat <<'EOF'
revert(chants): group picker by language only

ChantPickerSheet no longer prioritizes the user's tradition. Chants
group by language in the order they first appear in Chant.all
(English, Pali, Sanskrit, Vietnamese, Tibetan, Chinese, Japanese).
Chant.traditions metadata stays on the model.

Task 4 of docs/superpowers/plans/2026-05-11-remove-user-tradition.md
EOF
)"
```

---

## Task 5: Calendar header → Gregorian year

**Files:**
- Modify: `faith-ios/Views/Calendar/HolyCalendarView.swift`

- [ ] **Step 1: Find the era label**

```bash
grep -n "eraLabel\|BE \\\\(\|BE 2569\|month.year" faith-ios/Views/Calendar/HolyCalendarView.swift | head -10
```

Phase 4.4 added a `private var eraLabel: String { switch session.user.tradition { ... } }`. The header uses `Text(eraLabel)`.

- [ ] **Step 2: Delete the `eraLabel` computed property; inline `String(month.year)`**

Remove the `eraLabel` switch entirely. In the header view that previously rendered `Text(eraLabel)`, replace with:

```swift
Text(String(month.year))
```

- [ ] **Step 3: Remove `@EnvironmentObject session` from HolyCalendarView if no other reader needs it**

```bash
grep -n "session\\." faith-ios/Views/Calendar/HolyCalendarView.swift
```

If the only remaining reference is to a removed line, remove `@EnvironmentObject private var session: SessionStore` from the struct.

- [ ] **Step 4: Build**

```bash
xcodebuild -project faith-ios.xcodeproj -scheme faith-ios -destination 'platform=iOS Simulator,name=iPhone 17' -quiet build 2>&1 | tail -3
```

- [ ] **Step 5: Commit**

```bash
git add faith-ios/Views/Calendar/HolyCalendarView.swift
git commit -m "$(cat <<'EOF'
revert(calendar): always show Gregorian year (no BE/Tibetan switch)

Phase 4.4 made the header tradition-aware. With no user tradition,
the header just shows the year (e.g. 2026). The eraLabel switch
property is removed.

Task 5 of docs/superpowers/plans/2026-05-11-remove-user-tradition.md
EOF
)"
```

---

## Task 6: Revert pathways tradition prioritization

**Files:**
- Modify: `faith-ios/Views/LibraryView.swift`
- Modify: `faith-ios/Views/Study/PathwaysView.swift`

- [ ] **Step 1: Find pathway prioritization call sites**

```bash
grep -rn "prioritizing\|pathways(prioritizing" faith-ios/Views/
```

Expected: LibraryView's PATHWAYS section + PathwaysView's sort. Both use `PathwayStore.pathways(prioritizing: session.user.tradition)`.

- [ ] **Step 2: Replace each with the unsorted `pathways` array**

In LibraryView, find the section iteration:

```swift
// before
ForEach(pathwayStore.pathways(prioritizing: session.user.tradition).prefix(3)) { pathway in

// after
ForEach(pathwayStore.pathways.prefix(3)) { pathway in
```

Same in PathwaysView — iterate `store.pathways` directly. The `prioritizing:` helper can stay in `PathwayStore` (might be useful later); just don't call it.

- [ ] **Step 3: Build**

```bash
xcodebuild -project faith-ios.xcodeproj -scheme faith-ios -destination 'platform=iOS Simulator,name=iPhone 17' -quiet build 2>&1 | tail -3
```

- [ ] **Step 4: Commit**

```bash
git add faith-ios/Views/LibraryView.swift faith-ios/Views/Study/PathwaysView.swift
git commit -m "$(cat <<'EOF'
revert(pathways): show in natural order (no user-tradition prioritization)

LibraryView's PATHWAYS section and PathwaysView both iterate
PathwayStore.pathways directly. The prioritizing(by:) helper stays in
the store (unused) for future flexibility.

Task 6 of docs/superpowers/plans/2026-05-11-remove-user-tradition.md
EOF
)"
```

---

## Task 7: Delete Profile Tradition row + picker sheet

**Files:**
- Modify: `faith-ios/Views/ProfileView.swift`

- [ ] **Step 1: Find the Tradition row + picker**

```bash
grep -n "TraditionPickerSheet\|showingTraditionPicker\|setTradition\|\"Tradition\"" faith-ios/Views/ProfileView.swift
```

Expected hits:
- `@State private var showingTraditionPicker = false`
- The Tradition row inside `practiceSection` (or wherever) wrapped in a `Button { showingTraditionPicker = true }`
- The `.sheet(isPresented: $showingTraditionPicker) { TraditionPickerSheet(...) }`
- The private `TraditionPickerSheet` struct definition at the bottom of the file

- [ ] **Step 2: Delete all four**

Remove:
- The `@State` line
- The `Button { showingTraditionPicker = true } label: { settingsRow(label: "Tradition", ...) }` block in the practice section
- The `.sheet(isPresented: $showingTraditionPicker)` modifier
- The entire `private struct TraditionPickerSheet: View { ... }` definition

The Practice section's other rows (Reminder time, Daily passage) are unaffected. The Reading section, About section, palette, appearance, Sign out, Delete account all stay.

- [ ] **Step 3: Build**

```bash
xcodebuild -project faith-ios.xcodeproj -scheme faith-ios -destination 'platform=iOS Simulator,name=iPhone 17' -quiet build 2>&1 | tail -3
```

If it fails because something else referenced `TraditionPickerSheet` or `showingTraditionPicker`, grep more broadly and clean those up.

- [ ] **Step 4: Commit**

```bash
git add faith-ios/Views/ProfileView.swift
git commit -m "$(cat <<'EOF'
feat(profile): remove Tradition row + picker sheet

The Tradition setting row, its picker sheet, and the showingTraditionPicker
state are deleted. All other Profile rows stay (palette, appearance,
text size, reminder time, daily passage, sign out, delete account).

Task 7 of docs/superpowers/plans/2026-05-11-remove-user-tradition.md
EOF
)"
```

---

## Task 8: Splash → main (delete onboarding step files, move SplashView, simplify ContentView)

**Files:**
- Move: `faith-ios/Views/Onboarding/SplashView.swift` → `faith-ios/Views/SplashView.swift`
- Delete: `faith-ios/Views/Onboarding/OnboardingFlow.swift`
- Delete: `faith-ios/Views/Onboarding/TraditionPickerStep.swift`
- Delete: `faith-ios/Views/Onboarding/PermissionPrimingStep.swift`
- Modify: `faith-ios/ContentView.swift`

- [ ] **Step 1: Move SplashView up**

```bash
cd /Users/ggix/faith-ios
git mv faith-ios/Views/Onboarding/SplashView.swift faith-ios/Views/SplashView.swift
```

- [ ] **Step 2: Update SplashView's body so it no longer calls `session.advanceFromSplash()`**

`SplashView.swift` currently calls `session.advanceFromSplash()` after a 1.2s sleep. That method is going away in Task 9. Replace the splash's `.task` with an explicit callback:

```swift
import SwiftUI

struct SplashView: View {
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(gradient: Tradition.secular.substrateGradient,
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                Lotus(bloom: 1.0)
                    .frame(width: 120, height: 120)
                    .foregroundStyle(.white)
                Text("Faith")
                    .font(.system(size: 48, weight: .ultraLight, design: .serif))
                    .foregroundStyle(.white)
                Text("a daily companion to the canon")
                    .font(.system(size: 13))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.2))
            onComplete()
        }
    }
}
```

The earlier version may have used `NatureSubstrate(tradition: .secular)` — either form is fine, but a direct `LinearGradient` avoids any dependency on the substrate component for the launch screen.

- [ ] **Step 3: Delete the three onboarding step files**

```bash
git rm faith-ios/Views/Onboarding/OnboardingFlow.swift
git rm faith-ios/Views/Onboarding/TraditionPickerStep.swift
git rm faith-ios/Views/Onboarding/PermissionPrimingStep.swift
```

The `faith-ios/Views/Onboarding/` directory should now be empty. Remove it:

```bash
rmdir faith-ios/Views/Onboarding 2>/dev/null || true
```

- [ ] **Step 4: Update ContentView to drop the phase switch and use a local splash overlay**

Open `faith-ios/ContentView.swift`. Find the body that currently does `switch session.phase { case .splash: SplashView() ... }`.

Replace with:

```swift
struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("palette") private var paletteRaw: String = Palette.moss.rawValue
    @AppStorage("appearance") private var appearanceRaw: String = AppearanceMode.system.rawValue
    @State private var selection: AppTab = .today
    @State private var deepLinkPassageID: String?
    @State private var showSplash: Bool = true

    private var palette: Palette { Palette(rawValue: paletteRaw) ?? .moss }
    private var appearance: AppearanceMode { AppearanceMode(rawValue: appearanceRaw) ?? .system }
    private var effectiveScheme: ColorScheme { appearance.preferredScheme ?? colorScheme }
    private var theme: Theme { palette.theme(for: effectiveScheme) }

    var body: some View {
        ZStack {
            mainTabs
            if showSplash {
                SplashView { showSplash = false }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 0.3), value: showSplash)
        .dynamicTypeSize(.xSmall ... .accessibility5)
        .tint(theme.accent)
        .environment(\.theme, theme)
        .preferredColorScheme(appearance.preferredScheme)
        .task(id: paletteRaw + appearanceRaw) {
            SharedProgress.writeAppearance(palette: paletteRaw, appearance: appearanceRaw)
        }
        .onOpenURL { url in
            guard url.scheme == "faith" else { return }
            switch url.host {
            case "today":    selection = .today
            case "practice": selection = .practice
            case "library":  selection = .library
            case "chat":     selection = .chat
            case "passage":
                if let id = url.pathComponents.dropFirst().first {
                    deepLinkPassageID = id
                    selection = .library
                }
            default: selection = .today
            }
        }
    }

    private var mainTabs: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "house.fill", value: AppTab.today) {
                TodayView(selectedTab: $selection)
            }
            Tab("Practice", systemImage: "sun.max.fill", value: AppTab.practice) {
                MeditateView()
            }
            Tab("Library", systemImage: "book.fill", value: AppTab.library) {
                LibraryView(deepLinkPassageID: $deepLinkPassageID)
            }
            Tab("Teacher", systemImage: "bubble.left.fill", value: AppTab.chat, role: .search) {
                ChatView()
            }
        }
        .overlay(alignment: .bottom) {
            MiniPlayerBar()
                .padding(.bottom, 64)
        }
    }
}
```

(The `mainTabs` private view is the same as today's, with the existing mini-player overlay preserved. The only structural change is the `ZStack` wrapper + splash overlay + `showSplash` state.)

**Remove** `@EnvironmentObject private var session: SessionStore` from ContentView if it's no longer used after the phase switch is gone. The `.onOpenURL` block and the rest of the view don't read `session.phase` anymore.

- [ ] **Step 5: Build**

```bash
xcodebuild -project faith-ios.xcodeproj -scheme faith-ios -destination 'platform=iOS Simulator,name=iPhone 17' -quiet build 2>&1 | tail -10
```

Build may fail in Task 9-territory references — those will be cleaned up in Task 9. If the only failures are in `SessionStore.advanceFromSplash` / `phase` / `completeOnboarding`, that's expected — proceed if they're isolated to SessionStore. If they're elsewhere, address them before moving on.

(If the build is fully green here it means none of those are referenced anywhere — Task 9 will still delete them.)

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat: splash → main directly (no onboarding flow)

OnboardingFlow, TraditionPickerStep, PermissionPrimingStep deleted.
SplashView moved out of Views/Onboarding/ to Views/. ContentView now
shows SplashView for 1.2s via a local @State overlay, then the tab
view. session.phase is no longer read; SessionStore cleanup follows
in the next task.

Task 8 of docs/superpowers/plans/2026-05-11-remove-user-tradition.md
EOF
)"
```

---

## Task 9: Strip SessionStore phase machinery

**Files:**
- Modify: `faith-ios/Services/SessionStore.swift`

- [ ] **Step 1: Read the current SessionStore**

```bash
sed -n '1,100p' faith-ios/Services/SessionStore.swift
```

- [ ] **Step 2: Delete the phase-related properties and methods**

Remove:
- `enum AppPhase { case splash, onboarding, main }`
- `@Published var phase: AppPhase`
- The `self.phase = resolvedUsers.hasCompletedOnboarding ? .main : .splash` line in `init`
- `func completeOnboarding(with user: AppUser)`
- `func advanceFromSplash()`
- `func setTradition(_ t: Tradition)`
- The `phase = .splash` line inside `signOut()` and `deleteAccount()` and any `resetForDev()`

After the edits, `SessionStore.swift` should retain:
- `auth`, `users`, `llm`, `modelContext` properties
- `@Published var user: AppUser` (the field stays; the .tradition removal comes in Task 11)
- `@Published var streakDays`, `todayPracticed`, `minutesSatToday`
- `static func defaultLLM()`
- `init(modelContext:auth:users:llm:)` (without the phase line)
- `func signOut()` (without the phase line)
- `func deleteAccount()` (without the phase line)
- `func markPracticed(_:)`
- `func refreshDerivedStats()`

- [ ] **Step 3: Build**

```bash
xcodebuild -project faith-ios.xcodeproj -scheme faith-ios -destination 'platform=iOS Simulator,name=iPhone 17' -quiet build 2>&1 | tail -10
```

If the build fails on a reference to `phase` / `completeOnboarding` / `advanceFromSplash` / `setTradition` somewhere outside SessionStore, grep for the symbol and remove the caller:

```bash
grep -rn "session\\.phase\\|completeOnboarding\\|advanceFromSplash\\|setTradition" faith-ios/
```

The caller cleanup should already be done by Tasks 7 & 8; this grep is the safety net.

- [ ] **Step 4: Commit**

```bash
git add faith-ios/Services/SessionStore.swift
git commit -m "$(cat <<'EOF'
refactor(session): remove phase state machine

AppPhase enum, phase property, completeOnboarding, advanceFromSplash,
and setTradition are deleted. SessionStore now only does auth, derived
stats, sign-out / delete-account, and practice marking.

Task 9 of docs/superpowers/plans/2026-05-11-remove-user-tradition.md
EOF
)"
```

---

## Task 10: Strip `UserRepository.hasCompletedOnboarding`

**Files:**
- Modify: `faith-ios/Services/UserRepository.swift`

- [ ] **Step 1: Read the current protocol + implementation**

```bash
sed -n '1,50p' faith-ios/Services/UserRepository.swift
```

- [ ] **Step 2: Remove the property from the protocol**

```swift
@MainActor
protocol UserRepository: AnyObject {
    func load() -> AppUser?
    func save(_ user: AppUser)
    func clear()
    // hasCompletedOnboarding deleted
}
```

- [ ] **Step 3: Remove the property from `LocalUserRepository`**

```swift
@MainActor
final class LocalUserRepository: UserRepository {
    private let userKey = "faith.user"
    private let onboardingKey = "faith.onboardingComplete"
    private let defaults = UserDefaults.standard

    func load() -> AppUser? {
        guard let data = defaults.data(forKey: userKey),
              let user = try? JSONDecoder().decode(AppUser.self, from: data) else {
            return nil
        }
        return user
    }

    func save(_ user: AppUser) {
        if let data = try? JSONEncoder().encode(user) {
            defaults.set(data, forKey: userKey)
        }
    }

    func clear() {
        defaults.removeObject(forKey: userKey)
        defaults.removeObject(forKey: onboardingKey)
    }
}
```

Keep `onboardingKey` and `defaults.removeObject(forKey: onboardingKey)` inside `clear()`. Legacy installs may have stored a value under that key; on sign-out / delete-account we still clean it up. This is the only remaining reference to `onboardingKey`.

- [ ] **Step 4: Build**

```bash
xcodebuild -project faith-ios.xcodeproj -scheme faith-ios -destination 'platform=iOS Simulator,name=iPhone 17' -quiet build 2>&1 | tail -3
```

If there's a residual caller (e.g., a test, a preview, or another service), grep:

```bash
grep -rn "hasCompletedOnboarding" faith-ios/ faith-iosTests/ FaithWidget/
```

Should be zero matches. Remove any stragglers.

- [ ] **Step 5: Commit**

```bash
git add faith-ios/Services/UserRepository.swift
git commit -m "$(cat <<'EOF'
refactor(user-repo): remove hasCompletedOnboarding

UserRepository protocol no longer exposes hasCompletedOnboarding;
LocalUserRepository drops the getter/setter. The onboardingKey is still
cleaned up in clear() because legacy installs may have stored a value
there.

Task 10 of docs/superpowers/plans/2026-05-11-remove-user-tradition.md
EOF
)"
```

---

## Task 11: Remove `AppUser.tradition` field + regression test

**Files:**
- Modify: `faith-ios/Models/AppUser.swift`
- Create: `faith-iosTests/AppUserCodableTests.swift`

- [ ] **Step 1: Remove the field**

Open `faith-ios/Models/AppUser.swift`:

```swift
import Foundation

struct AppUser: Codable, Hashable {
    var id: String
    var displayName: String?
    var experience: Experience
    var dailyMinutes: Int        // 5/10/20/30
    var topics: Set<Topic>
    var notificationsAllowed: Bool

    static let sample = AppUser(
        id: "local",
        displayName: nil,
        experience: .someSitting,
        dailyMinutes: 10,
        topics: [],
        notificationsAllowed: false
    )
}

enum Experience: String, Codable, CaseIterable, Hashable, Identifiable {
    // ... existing cases ...
}

enum Topic: String, Codable, CaseIterable, Hashable, Identifiable {
    // ... existing cases ...
}
```

Just delete the `var tradition: Tradition` line and the `tradition: .secular` argument inside `AppUser.sample`.

- [ ] **Step 2: Write the regression test**

Create `faith-iosTests/AppUserCodableTests.swift`:

```swift
import Testing
import Foundation
@testable import faith_ios

@MainActor
struct AppUserCodableTests {
    /// Legacy AppUser blobs in UserDefaults still contain a `tradition`
    /// field — decoding must ignore it instead of failing, so users
    /// upgrading don't lose their saved preferences.
    @Test
    func decodesLegacyBlobWithTraditionField() throws {
        let legacyJSON = """
        {
          "id": "local",
          "displayName": "Hoang",
          "tradition": "theravada",
          "experience": "someSitting",
          "dailyMinutes": 10,
          "topics": [],
          "notificationsAllowed": true
        }
        """
        let data = Data(legacyJSON.utf8)
        let user = try JSONDecoder().decode(AppUser.self, from: data)
        #expect(user.id == "local")
        #expect(user.displayName == "Hoang")
        #expect(user.dailyMinutes == 10)
        #expect(user.notificationsAllowed == true)
    }

    /// Round-trips a fresh-installed user (without tradition) through
    /// encode/decode without loss.
    @Test
    func roundTripsFreshUser() throws {
        let original = AppUser.sample
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppUser.self, from: encoded)
        #expect(decoded == original)
    }
}
```

- [ ] **Step 3: Run the test**

```bash
xcodebuild test -project faith-ios.xcodeproj -scheme faith-ios -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:faith-iosTests/AppUserCodableTests 2>&1 | tail -15
```

Expected: 2 passing.

- [ ] **Step 4: Full build**

```bash
xcodebuild -project faith-ios.xcodeproj -scheme faith-ios -destination 'platform=iOS Simulator,name=iPhone 17' -quiet build 2>&1 | tail -3
```

If the build fails because some view still references `user.tradition`, grep:

```bash
grep -rn "user\\.tradition\\|session\\.user\\.tradition" faith-ios/
```

Should be zero matches (Tasks 2-7 should have cleaned them all). Fix any stragglers.

- [ ] **Step 5: Commit**

```bash
git add faith-ios/Models/AppUser.swift faith-iosTests/AppUserCodableTests.swift
git commit -m "$(cat <<'EOF'
refactor(user): remove AppUser.tradition field

The field is gone from the struct and AppUser.sample. JSONDecoder's
default ignore-unknown-keys behavior means legacy UserDefaults blobs
(stored under faith.user) still decode — a regression test
(AppUserCodableTests) locks this in.

Task 11 of docs/superpowers/plans/2026-05-11-remove-user-tradition.md
EOF
)"
```

---

## Verification (run after Task 11)

```bash
# 1. Build is green on the scheme used throughout
xcodebuild -project faith-ios.xcodeproj -scheme faith-ios -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | grep -E "BUILD|error:" | tail -3

# 2. No code reads session.user.tradition or user.tradition
grep -rn "user\\.tradition" faith-ios/ FaithWidget/ faith-iosTests/

# 3. No code references the deleted SessionStore symbols
grep -rn "AppPhase\\|\\.advanceFromSplash\\|completeOnboarding\\|setTradition\\b" faith-ios/

# 4. Onboarding directory is gone
ls faith-ios/Views/Onboarding 2>&1

# 5. SplashView lives at Views/SplashView.swift
ls faith-ios/Views/SplashView.swift

# 6. Tests pass (at minimum the new AppUserCodableTests + any existing)
xcodebuild test -project faith-ios.xcodeproj -scheme faith-ios -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```

Expected:
1. `** BUILD SUCCEEDED **`
2. Zero matches (besides comments / docstrings)
3. Zero matches
4. `No such file or directory` (the directory is gone)
5. The file exists
6. All tests pass

## Manual on-device checks

1. **Cold launch**: app shows splash for ~1.2s → Today.
2. **No tradition prompt** appears anywhere on first launch.
3. **Profile** has no Tradition row.
4. **Library** shows the TRADITIONS section with 5 entries (browse by tradition still works).
5. **Quiz** still shows the active question's tradition in its substrate.
6. **Calendar** header reads `2026` (not `BE 2569`).
7. **Chat** uses a single thread — no fork between threads.
8. **Chant picker** orders by language (English, Pali, Sanskrit, …) regardless of who's signed in.
9. **Sign-out / delete-account** still work; legacy users (who have a stored `tradition` blob) sign in cleanly without crashing.

## Out-of-scope for this plan

- Removing `Tradition` enum or `Tradition.substrateGradient` (still used by Quiz / TraditionBrowseView / content metadata).
- Restructuring the Library TRADITIONS section.
- Renaming `Chant.traditions` or `SuttaPassage.tradition`.
- Touching the Phase 0–7 commits (forward-only simplification).
- Anything related to the PR-to-main divergent-history problem (separate concern).
