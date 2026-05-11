# Remove user-facing tradition picker

## Context

After landing the 51-commit UX overhaul on `feature-hoang`, the user decided that forcing the reader to pick a Buddhist tradition is unjustified. The canon is multi-tradition by design; making the user commit to one creates an arbitrary preference that doesn't pay back enough in the UI to justify the friction. Onboarding's tradition picker, the Profile Tradition row, and every UI that filters/scopes by `session.user.tradition` should go away.

Tradition stays as **content metadata** — each `SuttaPassage` has a tradition, the Library "TRADITIONS" section browses the canon by tradition — but it stops being a **user setting**.

## What goes

| Surface | What changes |
|---|---|
| Onboarding | Reduced to splash → main. `OnboardingFlow.swift`, `TraditionPickerStep.swift`, `PermissionPrimingStep.swift` deleted. Permissions get prompted lazily on first feature use (mic on first dictation tap, notifications on toggle enable). |
| Splash | Stays as the launch screen, then auto-advances to main. |
| `SessionStore.phase` / `AppPhase` enum / `completeOnboarding(with:)` / `advanceFromSplash()` / `setTradition(_:)` | All removed. ContentView always renders the main tabs. |
| `UserRepository.hasCompletedOnboarding` | Removed. |
| `AppUser.tradition` field | Removed. (Codable decoder ignores unknown keys, so old saved blobs decode fine.) |
| Profile Tradition row + `TraditionPickerSheet` | Deleted. The Profile's other rows stay (sign in/out, account deletion, palette, appearance, text size, reminder time, daily passage). |
| Chat thread scoping by tradition (Phase 3.1) | Reverted. `ChatStore.currentThread(traditionRaw:in:)` returns the latest thread regardless. The `StoredChatThread.traditionRaw` SwiftData property stays (avoiding a migration); new threads write `"secular"` to it. `.onChange(of: session.user.tradition)` in ChatView removed. |
| Chant picker sorting by user tradition (Phase 4.7) | Reverted. `ChantPickerSheet` groups by `language` in declaration order. `Chant.traditions` tag metadata stays on the model. |
| Calendar BE-era label (Phase 4.4) | Always show Gregorian year. The `eraLabel` switch is deleted; the header just shows `String(month.year)`. |
| `NatureSubstrate` callers using `session.user.tradition` | Changed to use the default (`.secular`). The component's signature becomes `NatureSubstrate(tradition: Tradition = .secular, dimming: Double = 0.0)`. Most callers stop passing the argument. |
| Quiz substrate (Phase 4.5) | Stays as `current?.tradition ?? .secular` — i.e., the active question's tradition, falling back to secular. No longer reads `session.user.tradition`. |
| `Lotus`, `BackgroundPlayer`, sit Live Activity, etc. | Continue to work; they didn't read `session.user.tradition`. |

## What stays

- **`Tradition` enum** with all five cases — used by content (each passage's tradition, each chant's tradition tags) and by the Library TRADITIONS browse section.
- **`SuttaPassage.tradition`** — content metadata, unchanged.
- **`Chant.traditions: Set<Tradition>`** — metadata; useful if filtering is ever surfaced again, but not used for sorting now.
- **Library TRADITIONS section** — five rows (Theravāda, Mahāyāna, Vajrayāna, Zen, Secular) leading to `TraditionBrowseView`. This is canon navigation, not user personalization.
- **Per-tradition substrate gradients** (`Tradition.substrateGradient`) — still used by `TraditionBrowseView` to tint a particular tradition's browse view, and by `Quiz` to tint the active question.
- **Pathway tradition** — pathways are still tagged by tradition. `PathwaysView` shows them in their natural order from `pathways.json` (the user-tradition prioritization is reverted).

(The "stays" list is everything the radical-simplification message NEEDS to leave untouched. Anything that read `session.user.tradition` gets refactored.)

## File-level inventory

**Delete:**
- `faith-ios/Views/Onboarding/OnboardingFlow.swift`
- `faith-ios/Views/Onboarding/TraditionPickerStep.swift`
- `faith-ios/Views/Onboarding/PermissionPrimingStep.swift`

**Move:**
- `faith-ios/Views/Onboarding/SplashView.swift` → `faith-ios/Views/SplashView.swift`. The "Onboarding" directory is removed once SplashView is moved out and the three step files are deleted.

**Modify:**
- `faith-ios/Services/SessionStore.swift` — remove `AppPhase` enum, `phase` property, `completeOnboarding`, `advanceFromSplash`, `setTradition`, and the `phase` line in `init`. Keep `signOut`, `deleteAccount`, `markPracticed`, `refreshDerivedStats`.
- `faith-ios/Services/UserRepository.swift` — remove `hasCompletedOnboarding` from protocol and `LocalUserRepository`. `clear()` no longer needs to remove `faith.onboardingComplete` (leave the cleanup line for safety since legacy installs may have it).
- `faith-ios/Models/AppUser.swift` — remove `tradition: Tradition` field. Update `AppUser.sample`. Update `Codable` synthesis (automatic on field removal).
- `faith-ios/ContentView.swift` — body shows the splash overlay for 1.2s then renders `mainTabs` unconditionally. Wire via a local `@State private var showSplash: Bool = true` and a `.task` that sleeps 1.2s then sets it false. The `switch session.phase` block is removed.
- `faith-ios/Views/ProfileView.swift` — delete the Tradition row + `TraditionPickerSheet` struct + `showingTraditionPicker` state. Keep all other rows.
- `faith-ios/Services/ChatStore.swift` — revert `currentThread(traditionRaw:in:)` to fetch the latest thread without the tradition predicate. Callers can still pass `traditionRaw` but it's only used when creating a new thread (set to `"secular"`).
- `faith-ios/Views/Chat/ChatView.swift` — remove `.onChange(of: session.user.tradition)`. Use `.secular` (or just nothing) wherever `session.user.tradition` was used.
- `faith-ios/Views/Calendar/HolyCalendarView.swift` — replace `eraLabel` switch with `String(month.year)`. Remove `@EnvironmentObject session` if no other reader needs it.
- `faith-ios/Views/Meditate/MeditateView.swift` — `ChantPickerSheet`'s `orderedLanguageGroups` reverts to grouping by `language` (declaration order). Remove `@EnvironmentObject session` from `ChantPickerSheet` if no longer needed.
- `faith-ios/Views/TodayView.swift` — substrate uses `NatureSubstrate()` (default). Remove `@EnvironmentObject session` if no other reader needs it.
- `faith-ios/Views/LibraryView.swift` — substrate uses `NatureSubstrate()`. Remove the Library Pathways section's `prioritizing: session.user.tradition` call; show pathways in natural order.
- `faith-ios/Views/StreakDetailView.swift` — substrate uses `NatureSubstrate()`.
- `faith-ios/Views/Study/PathwaysView.swift` — show pathways in natural order; remove `prioritizing: session.user.tradition` if present.
- `faith-ios/Views/Components/NatureSubstrate.swift` — change `tradition: Tradition` to `tradition: Tradition = .secular`.
- `faith-ios/FaithApp.swift` — `SessionStore.init(...)` no longer needs to set phase. Confirm nothing else breaks.

**Keep unchanged:**
- `faith-ios/Models/Tradition.swift`, `faith-ios/Models/Chant.swift`, `faith-ios/Models/Sutta.swift`
- `faith-ios/Services/PathwayStore.swift` — `pathways(prioritizing:)` can stay as a helper, just no longer called by views
- Quiz substrate logic (Phase 4.5) — reads question's tradition, not user's

## Migration / data concerns

- **`UserDefaults` key `faith.user`** — old user blobs decoded by `JSONDecoder` will silently drop the removed `tradition` field. Default behavior, no migration needed.
- **`UserDefaults` key `faith.onboardingComplete`** — orphaned for legacy installs. `LocalUserRepository.clear()` still removes it on sign-out / delete-account for cleanliness.
- **`StoredChatThread.traditionRaw` SwiftData column** — stays in the schema. Avoids a migration. New threads set `"secular"`. Legacy threads keep whatever value they had.
- **`@AppStorage("dailyReminderEnabled")` etc.** — unaffected.

## Verification

After implementation, the cold-launch experience is:

1. App icon tap → splash (1.2s) → Today.
2. No tradition prompt anywhere.
3. Profile has no Tradition row.
4. Library's "TRADITIONS" section still browses canon by tradition.
5. Quiz renders the active question's tradition in the substrate.
6. Chants in the picker group by language; nothing pinned to user-tradition.
7. Calendar header shows `2026` (year), not `BE 2569` or `Tibetan 2026`.
8. Chat thread is one thread; switching content (no longer possible from a Profile picker anyway) doesn't fork the conversation.
9. App still compiles clean against scheme `faith-ios`.

## Out-of-scope

- Renaming the `Tradition` enum or restructuring `SuttaPassage`.
- Re-tinting the rest of the UI to a single palette (palette + appearance pickers in Profile stay — those drive `Palette`, separate from `Tradition`).
- Deleting `Tradition.substrateGradient` or accent-color machinery.
- Touching the Phase 0–7 commits' history. This is a forward-only simplification on top.
