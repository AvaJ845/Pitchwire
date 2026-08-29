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
Paste any launch story into Home → Analyze → a confidence-tiered list of (sample) journalists
with a one-line reason on every card → tap one for the full "why this match" + provenance →
Draft pitch → subject/short/long pitch text you can edit and mark as sent. Campaigns and Drafts
tabs list what you've built up. Everything is local — SwiftData, no accounts, no network calls.

Reference screenshots of the loop are in `BeatMatch/Screenshots/`.

## Layout
```
BeatMatch/
  project.yml                 XcodeGen spec (deployment target, bundle id, targets)
  Sources/                    the 22 Swift files — Models/ Services/ Data/ Views/ + BeatMatchApp.swift
  UITests/CoreLoopUITests.swift   one smoke test: paste → analyze → match → detail → draft
  Screenshots/                reference captures of each step
BeatMatch-Source/             original hand-off copy, kept in sync with Sources/
```

## What's real vs. placeholder
- The 15 journalists in `Data/SampleJournalists.swift` are fictional — clearly marked as sample
  data, not real people. Real ingestion (Fellow 4's job) replaces this file's `seedPool()` later.
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

## Next
See `ARCHITECTURE.md` for the full reasoning (MVP scope, challenged assumptions, deferred work).
Slice 1 per the brief: URL/file story input, real journalist ingestion, iPad 3-pane layout,
Share Extension, accounts.
