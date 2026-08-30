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

## Design
`Sources/Design/` — `Palette` (brand navy + teal, all tokens light **and** dark), `Components`
(`Card`, `Monogram`, `ConfidencePill`, `EvidenceDot`, `.pitchwire` button style, `SectionLabel`),
`Haptics`. Every screen is card-based on `Palette.canvas`, full dark mode, Dynamic-Type-friendly.
`AccentColor` asset tints the app teal.

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
  UITests/CoreLoopUITests.swift   smoke test: paste → analyze → confirm → match → detail → draft
  UnitTests/EntitlementsTests.swift   entitlement limits, period reset, feature gates, AI tiers
  Screenshots/                reference captures of each step
```

## What's real vs. placeholder
- **Pitchwire is an editorial-relevance research assistant, not a contact database.** No personal
  contact data is modelled, collected, or inferred — full spec `docs/EDITORIAL_RESEARCH_ENGINE.md`.
- **The match pool is a 25-record *candidate* seed set** — `Resources/editorial_seed.json`, 25 real
  editorial professionals across 4 verticals, compiled from public author pages. Every record ships
  unverified (`verificationDate: null`); AI can discover but **never verify** — that's the Research
  Lab's job (Slice 4b). Because none are verified, no seed match scores above "Strong". The UI
  labels every profile **Verified / Candidate / Demo**. `EditorialSeedLoader` falls back to 15
  fictional `FICTIONAL_SAMPLE` demo profiles when no file is bundled. `EditorialSeedTests` +
  `SampleDataTests` enforce the honesty (and that no contact field ever enters the schema).
- **Matching quality is the milestone, not headcount.** `docs/EVAL.md` + `EditorialRelevanceEvalTests`
  are the living benchmark — every match must explain itself with a real beat + a grounded reason.
- **Research Lab (Slice 4b, DEBUG-only)** — Profile → Developer → Research Lab. The persistent
  `JournalistDirectory` is seeded once and shared by every campaign; a researcher opens a
  candidate's source, attaches real dated articles, and **verifies or rejects** it. AI never
  verifies. Rejected → excluded from matching. "Report an issue / request removal" feeds a
  local queue (monitored-inbox POST still TODO). See `docs/RESEARCH_LAB.md`,
  `docs/DATA_PROVIDER_INTAKE.md`.
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

## Relevance engine + backend + seed-set plan
- **`Sources/Services/RelevanceEngine.swift`** — matching is now a weighted 7-signal score
  (beat, recent coverage, angle, audience, geography, pitch-preference hard-filter, evidence),
  each inspectable. `WeightedRelevanceService` ranks the pool; "why this match" prose is built
  from the driving signals; journalist detail has a "How we scored this" breakdown. Deterministic.
- **`backend/`** — **DEPLOYED & LIVE** at `pitchwire-ai.divine-mountain-8173.workers.dev`.
  Cloudflare Worker: keys in Worker secrets, failover chain (NVIDIA `gpt-oss-120b`/`-20b` → z.ai),
  6h cache, rate limit. The app connects via gitignored `BeatMatch/Config/AIConfig.plist` (template:
  `AIConfig.example.plist`). z.ai is Aliyun-blocked from Cloudflare — NVIDIA carries it; see
  `backend/README.md`. `wrangler` is in `backend/`; `npm run deploy` from there.
- **`docs/SEED_SET.md`** — the fellows' plan for a real 15–20 journalist seed set:
  public-editorial-signal only (no contact data), claimed-profile outreach in parallel, never
  buy/scrape/enrich (5.1.1(viii)).

## Slice 3 — closing the last north-star gaps
- **Real explanations.** `ExplanationEnricher` runs on the match list — rewrites the top ~8
  "why this match" reasons into grounded prose via the live backend (name/`they` only, one
  sentence, "AI" badge). The relevance engine's grounded one-liner shows first;
  `MatchExplanation.groundedReason` keeps it.
- **Follow-up memory.** `FollowUpsView` (match-list toolbar) — add/complete follow-ups per
  campaign with due dates. "Mark as sent" offers a reminder; Home shows a "Follow-ups due"
  section. Free plan (`.followUpReminders`).

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
- **AI infrastructure** (`Sources/AI/`) — one chokepoint (`AIClient.run`), typed `AITask`s,
  `ModelTier` per task, `AIGateway` boundary (`OfflineGateway` ships, `HTTPGateway` ready),
  `AIConfiguration` holds only a scoped client token (no provider key), `AITelemetry` on every call.
  `FallbackGateway` is the failover chain (GLM-4.7 → GLM-4.5 → NVIDIA NIM, all free), which runs
  **in the backend** — the app makes one call and never sees the failover. `OpenAICompatibleGateway`
  is the shared z.ai/NVIDIA client (backend/keyed-dev only). DEBUG build: Profile → Developer has an
  **LLM log** (every call + failover) with a capture toggle. Guardrails: `-uitest-reset` is
  DEBUG-only; `Redaction` scrubs secrets at every log boundary; a second toggle sends full
  prompts/responses to `OSLog` (device-only, `.private`) and is **off by default even in DEBUG**.
- **Entitlements** (`Sources/Entitlements/`) — features ask `Entitlements.can/remaining/consume`,
  never `if plan == .free`. All limits/features/trials live in `LocalEntitlementStore.catalog`
  (one place). Swappable `EntitlementStore` protocol for a StoreKit/server-backed store later.
  Gates wired on story analysis + AI pitch drafts; shown as "N of M left" in Home and Profile.

Both layers have unit tests (`UnitTests/EntitlementsTests.swift`). See `docs/DIRECTION.md`.

## Next
Not yet built: the backend / AI router itself, real journalist ingestion (Layers A–D), URL &
file story input, Share Extension, iPad 3-pane workspace, accounts, a paid `EntitlementStore`
+ StoreKit products.
