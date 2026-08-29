# Pitchwire — Slice 0 is built, running, and verified.

**Brand: Pitchwire** (bundle `com.avaresearch.pitchwire`). "BeatMatch" is now an
internal codename only — it lost a live App Store collision check (an incorporated
"Beatmatch, Inc." holds the exact name, plus DJ-term dilution and a clash with our
own Crossbeat). The xcodegen project folder, target, scheme, and Swift types keep
the `BeatMatch` name as codename; only the product/bundle/display name changed. See
`AppStore/ASO_PLAYBOOK.md` and `AppStore/METADATA.md` for the full naming pass.

The Xcode project exists. It builds clean and the end-to-end loop passes a UI test
on the iPhone 17 Pro simulator (Xcode 26). No manual Xcode wizard step is needed.

## Open it

`BeatMatch.xcodeproj/` is **git-ignored** — it's generated from `project.yml` by
[XcodeGen](https://github.com/yonyz/XcodeGen). On a fresh clone you must generate it first:

```
brew install xcodegen                 # if you don't have it (or ~/bin/xcodegen)
cd "~/Documents/AI Press Agent/BeatMatch"
xcodegen generate
open BeatMatch.xcodeproj               # Cmd+R to run, Cmd+U for the smoke test
```

Re-run `xcodegen generate` whenever you edit `project.yml` or add/rename/move source files
(new files inside `Sources/` are picked up automatically by Xcode's folder sync, so you only
need it for `project.yml` changes). The source of truth is `project.yml` + `Sources/` + `UITests/`.

**If Xcode won't build / "fails to load":** you're almost certainly on a stale generated
project — delete `BeatMatch.xcodeproj`, re-run `xcodegen generate`, and clean the build folder
(Cmd+Shift+K). `project.yml` sets `ALWAYS_SEARCH_USER_PATHS: NO` (Xcode 26 rejects the legacy
"traditional headermap" behaviour) — if you see that warning, your project predates that fix.

Build/test from the command line:

```
cd "~/Documents/AI Press Agent/BeatMatch"
xcodebuild -scheme BeatMatch -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## What you'll see
Paste a launch story into Home → Analyze → **"What we understood"** (theme, audience, angle,
timing, editable topic chips) → Find journalists → a confidence-tiered list with a reason and an
evidence-confidence label on every card → tap one for "why this match" + **About this profile**
(each provenance record: source type, coverage basis, last verified, pitch preference) → Draft
pitch → subject/short/long text you can edit and mark as sent. Campaigns and Drafts tabs list
what you've built up. Everything is local — SwiftData, no accounts, no network calls.

Reference screenshots of the loop are in `BeatMatch/Screenshots/`.

## Layout
```
BeatMatch/
  project.yml                 XcodeGen spec (deployment target, bundle id, targets)
  Sources/                    Models/ Services/ Data/ Views/ + BeatMatchApp.swift
  UITests/CoreLoopUITests.swift   one smoke test: paste → analyze → confirm → match → detail → draft
  Screenshots/                reference captures of each step
```

## What's real vs. placeholder
- The 15 journalists in `Data/SampleJournalists.swift` are fictional — clearly marked as sample
  data, not real people. Real ingestion (Fellow 4's job) replaces this file's `seedPool()` later.
- The `Story` ↔ `StoryAnalysisResult` mapping lives in one place — `Story.apply(_:)` and
  `Story.analysisResult` (in `Models/Story.swift`). Add a new analysis field there, not at call sites.
- Story analysis and pitch drafting are deterministic/template-based (`StubStoryAnalysisService`,
  `TemplatePitchDraftingService`) so the app runs with zero API keys. Both sit behind protocols —
  swap in an LLM-backed implementation without touching any view code (see ARCHITECTURE.md, section 4).

## Changed since the original hand-off
- Xcode project created via XcodeGen; builds clean on Xcode 26 / iOS 17+ deployment target.
- Navigation converted from value-based `.navigationDestination(for:)` to direct-destination
  `NavigationLink`s in the child views — the value-based form silently failed to push when mixed
  with `HomeView`'s programmatic `.navigationDestination(item:)` in the same stack.
- `StubStoryAnalysisService` now renders "AI" / "Fintech" etc. as proper display names instead of
  `"ai".capitalized` → "Ai" leaking into campaign names and pitch subjects.
- Added `UITests/CoreLoopUITests.swift` — one smoke test covering the whole loop.
- Removed the duplicate `BeatMatch-Source/` tree — `BeatMatch/Sources/` is the single source of truth.
- Added the app icon — `Sources/Assets.xcassets/AppIcon.appiconset/` (single 1024 asset). Master
  also at `AppStore/AppIcon-1024.png` for App Store Connect. Rebuilt from
  `~/Downloads/Pitchwire_Modern_P_Icon_1024.png`: cropped the AI-generated icon-in-a-frame down
  to the P mark and re-composited it full-bleed on a solid navy field (no rounded corners / shadow /
  alpha — iOS masks the shape itself).

## Slice 1 — toward the AI Press Agent direction
Built against the product direction (story-first workflow) + the AI Infrastructure Direction deck:
- **Richer story understanding** — `StoryAnalysisResult` / `Story` now carry audience, subtopics,
  and media hooks alongside theme/vertical/region/angle/urgency.
- **Screen 2, "What we understood"** (`StorySummaryView`) — sits between Analyze and the match
  list; editable angle/region/topics so a wrong tag doesn't cascade into wrong matches. `MatchRunner`
  builds targets and is re-runnable after edits.
- **Multi-source provenance** — `JournalistProfile.provenanceRecords: [ProvenanceRecord]` (was 1:1),
  each tagged `ProvenanceSourceType` (claimed / publisher / licensed / public-signal / sample) with a
  coverage basis. `evidenceConfidence` (high / moderate / exploratory) is derived from the best
  source + how recently it was verified, and shown on every match card and the detail view.
- **AI provider seam** (`Services/AIProvider.swift`) — `ModelTier` (fast/quality) + an `AIProvider`
  protocol. `OfflineAIProvider` ships today (always throws → deterministic fallback). Per the deck:
  the app never holds a key; a real provider talks to a backend that routes to GLM-5.3-Flash.
  `TemplatePitchDraftingService` already calls through the seam and falls back.

## Next
See `ARCHITECTURE.md` for the full reasoning. Not yet built: the backend / AI router itself,
real journalist ingestion (Layers A–D), URL & file story input, Share Extension, iPad 3-pane
workspace, accounts.
