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
- **Keys server-side only.** `AIConfiguration` holds `baseURL` + a scoped per-user `clientToken`.
  There is no field for a provider key. Ship with `baseURL: nil`.
- **Observable.** `AIClient` times every call and emits an `AIEvent` (task, tier, model, latency,
  cached, ok/error) through one `AITelemetry` hook — vendor-neutral, `print` today.
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
one-line change in the backend task→model map. `AIConfiguration.defaultModel` is `glm-4.7-flash`,
advisory only. **Re-check z.ai's pricing page for the current free-model lineup when wiring the
backend** — it changes.

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
| A | Claimed journalist profiles (journalist edits their own beat / pitch rules / do-not-pitch) | modeled (`claimedProfile`), not yet real |
| B | Publisher / network partnerships (first-party editorial context) | modeled (`publisherPartner`), not yet real |
| C | Licensed professional datasets (only where rights are explicit) | modeled (`licensedDataset`), not yet real |
| D | Public editorial signals (bylines, author pages, RSS, topic patterns) | modeled (`publicSignal`), not yet real |

App Store guideline **5.1.1(viii)** — apps compiling personal info from sources not provided by
the user, "even public databases," are not permitted — is the strategic constraint the whole
data layer is shaped around. Recommendation + provenance + consent-aware usage, not mass
compiled personal data.

## Success metric

**Qualified pitch actions per analyzed story** — user submits a story, gets good matches, and
saves / drafts / acts on them. Not downloads.

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
