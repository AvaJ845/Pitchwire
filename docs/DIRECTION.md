# Pitchwire — Product Direction

Synthesized from the product-direction brief and `AI_Infrastructure_Direction_GLM53_Flash.pptx`
(the deck calls the product "StoryReach" — same product, the shipped name is **Pitchwire**).

## North Star

**An AI press agent in your pocket.** "Tell us what you're launching, and we'll tell you who is
most likely to care, why they matter, and what to say."

The product is a story-first workflow, not a database:

```
story intake → AI understanding → relevance matching → outreach guidance → campaign memory
```

## Who it's for (v1)

Startup founders first, then small in-house marketers, then agencies serving small brands. Not
enterprise media intelligence.

## Product principles

1. **Story-first, not database-first.** The primary object is the user's story.
2. **Explain every recommendation.** Never a bare score — always the reason and its evidence.
3. **Provenance is a visible feature.** Every profile detail shows source + verification date.
4. **Respect over volume.** No "blast 5,000 journalists."
5. **Professional identity, not personal exploitation.** Outlet, beat, recent coverage, public
   pitch preference, claimed profile, publisher metadata, licensed data — never scraped dumps.
6. **Mobile-native.** Fast capture, concise recommendations, tap-to-act.

## Authority split (non-negotiable)

The model **interprets and drafts language**. It is never the source of truth for:
journalist identity, outlet identity, article dates, published coverage, contact info, source
provenance, verification dates. Those come from structured data and deterministic logic.

## AI infrastructure (non-negotiable from day one)

Implemented in `Sources/AI/`:

- **One chokepoint, typed tasks.** Every LLM call goes through `AIClient.run(AIRequest)`.
  Requests are typed by `AITask` (`storyAnalysis`, `pitchDraft`, …), never free-form prompts
  from random call sites. `ModelTier` (fast/quality) is chosen per task via `AITask.defaultTier`.
- **Provider abstraction.** `AIGateway` is the boundary. `OfflineGateway` ships (always throws →
  deterministic fallback). `HTTPGateway` is ready — talks only to the Pitchwire backend, never a
  provider. `AIClient.configure(_:)` swaps the gateway at runtime.
- **Failover.** `FallbackGateway` tries a chain of gateways in order and returns the first
  success, logging each failed hop. In production this lives **in the backend** — the app makes
  one call to `HTTPGateway` and the backend runs the chain, so a z.ai rate-limit is invisible to
  the user:
  `GLM-4.7-Flash (z.ai, free)` → `GLM-4.5-Flash (z.ai, free)` → `NVIDIA NIM (free, ~40 rpm)`.
  `OpenAICompatibleGateway` is the shared client for z.ai and NVIDIA NIM (both OpenAI-compatible);
  it holds a real key so it is **backend / keyed-dev only**, never shipped in the app.
  ⚠️ Verify NVIDIA's free-tier ToS permits commercial use before wiring it in the backend.
- **Keys server-side only.** `AIConfiguration` holds `baseURL` + a scoped per-user `clientToken`.
  There is no field for a provider key. Ship with `baseURL: nil`.
- **Observable.** `AIClient` times every call and emits an `AIEvent` (task, tier, model, latency,
  cached, ok/error) through one `AITelemetry` hook — vendor-neutral, `print` today. A DEBUG-only
  **LLM log** (`LLMLog` + a viewer in Profile → Developer, compiled out of release) captures every
  call and every provider failover, with a capture toggle. Expected offline `notConfigured` states
  are filtered out.
- **Debug-logging guardrails:**
  - `-uitest-reset` launch arg is honoured in **DEBUG only** (`#else` → `false` in release).
  - `Redaction` scrubs bearer tokens, `nvapi-`/`sk-` key shapes, `api_key=`/`token=` pairs, and any
    registered exact secret (the client token registers itself on `AIClient.configure`) at every
    log boundary — `LLMLog.record` redacts entry detail, `LoggingTelemetry` redacts before print.
  - **Prompt/response payload capture is a second toggle, OFF by default even in DEBUG**
    (`LLMLog.isCapturingPayloads`). When on, `PayloadLog` writes redacted prompts + responses to
    `OSLog` with `.private` fields — visible in Xcode/Console when attached, never in sysdiagnose,
    never in the in-app viewer (prompts carry the user's unpublished story).
- **Cost control.** `AIResponse` carries `cached` + `usage`; the gateway contract lets the backend
  do retrieval-before-generation and return summaries. Fast tier for extraction, quality for prose.
- **Defer:** multi-model routing policy, self-hosting (GLM is MIT/open-weight — a *future* option,
  not an MVP trigger), GPU/inference ops.

### Model choice (decided 2026-08-29)

**MVP runs entirely on z.ai's free tier.** Every task here is structured extraction or short
business prose — not hard reasoning — and the LLM never invents facts (authority split), so a
free Flash model is both sufficient and safe. Cost is ~$0.001/story even on the paid model, so
the reason to start free is rate-limit simplicity + generous free-plan limits, not token cost.

An API key **is** required even for the free models (there is no keyless access) — it lives in
the **backend vault only**, never the app. The app declares `AITask` + `ModelTier`; the backend
owns this map:

| Tier | Tasks | MVP model | Later (Pro) |
|---|---|---|---|
| `.fast` | `storyAnalysis`, `matchExplanation` | **GLM-4.7-Flash** (free), fallback GLM-4.5-Flash | unchanged |
| `.quality` | `pitchDraft`, `pitchRewrite`, `subjectLine`, `followUp` | **GLM-4.7-Flash** (free) | route `pitchDraft`/`pitchRewrite` → **GLM-5.3-Flash** (paid, ~$0.075/$0.25 per M) |

Add the paid tier only when (1) free-tier rate limits actually bite under real usage **and**
(2) there's evidence users care about draft polish specifically (vs. match quality). It's a
one-line change in the backend task→model map. **The app carries no model name** — not in config,
not in the UI (`AIConfiguration` has no `model` field; Profile shows only "Status: On-device only /
Connected"). The DEBUG LLM log shows `AIResponse.model` per entry — the actual model that answered,
for failover debugging. **Re-check z.ai's pricing page for the current free-model lineup when
wiring the backend** — it changes.

**Vision (GLM-4.6V-Flash) — not MVP.** Its only fit is story intake from a screenshot / PDF /
image-heavy page, and that intake path is itself deferred (MVP is paste-text). When file/URL
intake is built: extract text on-device first — PDFKit for PDFs, Apple Vision-framework OCR for
images (free, private) — and feed the text model. Use the vision model only as a fallback when
OCR can't (infographics, odd layouts, "read this announcement screenshot"). Never run vision on
anything involving a person's photo or identity. Carrying it later means one new `AITask` plus an
image-bytes field on `AIRequest.input` — a small extension, not a rewrite; not worth building
speculatively now.

## Commercial model = data, not code (`Sources/Entitlements/`)

No feature ever checks `if plan == .free`. Features ask `Entitlements`:
`can(.exportPitch)` / `remaining(.storyAnalysis)` / `consume(.aiPitchDraft)`.

- **One config object.** `LocalEntitlementStore.catalog` is the only place plan limits, features,
  and trial lengths live. Change pricing / free limits / Pro entitlements / trials / AI caps there;
  no other code moves.
- **Swappable store.** `EntitlementStore` protocol. `LocalEntitlementStore` (Free plan + UserDefaults
  metering) is the default; a StoreKit- or server-entitlement-backed store replaces it behind the
  same protocol.
- **Wired gates:** `.storyAnalysis` (Home), `.aiPitchDraft` (journalist detail). `.activeCampaign`
  is in the catalog, not yet enforced.

## Data strategy (layered, safest first)

| Layer | Source | Status |
|---|---|---|
| A | Claimed journalist profiles (journalist edits their own beat / pitch rules / do-not-pitch) | `ProvenanceSourceType.claimedProfile` modeled; **no real data yet** |
| B | Publisher / network partnerships (first-party editorial context) | `.publisherPartner` modeled; **no real data yet** |
| C | Licensed professional datasets (only where rights are explicit) | `.licensedDataset` modeled; **no real data yet** |
| D | Public editorial signals (bylines, author pages, RSS, topic patterns) | `.publicSignal` modeled; **no real data yet** |

**Today every match is fictional.** `SampleJournalists.seedPool()` returns 15 made-up profiles,
each carrying only `.sampleData` provenance, so `JournalistProfile.isSampleData` is true. The app
says so, loudly: a `SampleDataBanner` on the match list, a "Sample" tag on every card, a "Sample
data" pill on the detail header, and an honest "Fictional profile — this is not a real person"
provenance record. Sample profiles always score `.exploratory` evidence confidence — nothing
about "verified" data inflates them. When real ingestion writes real `ProvenanceRecord`s,
`isSampleData` flips false and every banner disappears on its own. (`SampleDataTests` enforces
this.)

App Store guideline **5.1.1(viii)** — apps compiling personal info from sources not provided by
the user, "even public databases," are not permitted — is the strategic constraint the whole
data layer is shaped around. Recommendation + provenance + consent-aware usage, not mass
compiled personal data.

## Visual system (`Sources/Design/`)

- **`Palette`** — brand navy + teal (from the app icon), semantic tokens (`canvas`, `surface`,
  `hairline`, `ink*`), tier colours, evidence colours. Every token is defined light **and** dark.
  `AccentColor` asset tints the whole app teal.
- **`Components`** — one `Card` surface, `Monogram` (name-derived tinted initials, no fetched
  avatars), `Tag` / `ConfidencePill` / `EvidenceDot`, `PitchwireButtonStyle` (`.pitchwire` /
  `.pitchwireQuiet`), `SectionLabel` (uppercase display, original-case a11y label).
- **`Haptics`** — success / warning / tap / select, one line per meaningful moment.
- Every screen: card layout on `Palette.canvas`, Dynamic-Type-friendly (system fonts,
  `fixedSize(vertical:)` on wrapping text, no fixed heights except text editors), full dark mode.
- Match list: monogram + confidence pill + evidence dot rows, tiered headers with counts, swipe
  to shortlist / hide. Journalist detail: sticky "Draft pitch" bar. Pitch draft: segmented
  short/long, Copy + Share, mark-as-sent with a filled state.
- Match reasons read as sentences ("Covers AI and product launch — a direct hit for this story"),
  not keyword dumps — the shape the quality-tier model produces, done deterministically offline.

## Success metric

**Qualified pitch actions per analyzed story** — user submits a story, gets good matches, and
saves / drafts / acts on them. Not downloads.

## Relevance engine (`Sources/Services/RelevanceEngine.swift`)

Matching is a **weighted, inspectable** score — not keyword intersection. Seven signals,
each 0–1 with a weight and a human fragment:

| Signal | Weight | What it reads |
|---|---:|---|
| Beat match | 28% | declared beat topics vs the story |
| Recent coverage | 24% | byline titles that overlap the story, recency-weighted |
| Angle fit | 16% | do they cover this kind of story (launch / funding / …) |
| Audience fit | 12% | who they write for vs the story's audience |
| Geography | 6% | region overlap |
| Pitch preference | 6% | a **hard filter** — a declared "no funding pitches" zeroes the match |
| Evidence | 8% | small tilt toward better-sourced profiles |

`WeightedRelevanceService` applies it over the pool; the "why this match" prose is built
from the signals that actually drove the score. Journalist detail has a **"How we scored
this"** breakdown (score bar + per-signal bars). All deterministic — the model never runs
here. `RelevanceEngineTests` covers alignment, off-topic rejection, the do-not-pitch filter,
and recency lift.

## Real seed set — see `docs/SEED_SET.md`

Fellows verdict: ship a **public-editorial-signal** seed (beats + bylines, **no contact
data**, working removal pipeline) to unblock matching evaluation now; run **claimed-profile
outreach** in parallel for a consented, 5.1.1(viii)-defensible database. Never buy a list,
scrape, or use an enrichment provider.

## Backend — **deployed & live** (`backend/`)

A single Cloudflare Worker at `pitchwire-ai.divine-mountain-8173.workers.dev` implementing the
`HTTPGateway` contract: keys in Worker secrets, task→model map, failover chain, 6h cache, per-IP
rate limit. The app connects via a gitignored `BeatMatch/Config/AIConfig.plist`
(`AIConfiguration.fromBundle()`); `AIConfig.example.plist` is the template.

**Live chain:** NVIDIA NIM `gpt-oss-120b` / `gpt-oss-20b` (free) → z.ai GLM-4.7/4.5-Flash.
z.ai's API is Aliyun-fronted and **blocks Cloudflare Worker IPs**, so NVIDIA carries it for now;
z.ai lights up automatically if the gateway moves off Cloudflare or proxies via OpenRouter.
Real GLM/gpt-oss output verified end-to-end: story analysis returns constrained JSON, pitch
drafts are grounded in the journalist's actual beat + bylines.

## Build status

Done (Slice 0–2): the full loop runs offline — story intake, richer story understanding, the
"what we understood" confirmation screen, deterministic matching with confidence tiers +
evidence-confidence labels, multi-source provenance on every profile, pitch drafting through
the typed AI gateway, campaign / draft / follow-up persistence (SwiftData, local-only). Plus
the AI infrastructure (`Sources/AI/`) and the entitlements layer (`Sources/Entitlements/`)
above, with 7 unit tests + 1 UI smoke test.

Not built: the backend + AI router itself, real ingestion for Layers A–D, URL & file story
input, Share Extension, iPad 3-pane workspace, accounts, a paid `EntitlementStore` + StoreKit
products, a real telemetry sink.
