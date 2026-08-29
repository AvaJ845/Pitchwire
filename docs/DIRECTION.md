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
