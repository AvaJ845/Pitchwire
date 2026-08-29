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

- **Provider abstraction.** Never hard-code to one AI provider. `Services/AIProvider.swift` is
  the seam — `ModelTier` (fast/quality) + `AIProvider`. Default model when a backend exists:
  GLM-5.3-Flash via a server-side router; quality-tier fallback to another provider.
- **Keys server-side only.** The app holds a scoped client token, never a provider key.
- **Cost control.** Ingest once → structure once → store facts → retrieve relevant evidence →
  generate only when needed. Summaries, not full text. Cache.
- **Defer:** multi-model routing, self-hosting (GLM is MIT/open-weight — a *future* option,
  not an MVP trigger), GPU/inference ops.

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

Done (Slice 0 + 1): the full loop runs offline — story intake, richer story understanding, the
"what we understood" confirmation screen, deterministic matching with confidence tiers +
evidence-confidence labels, multi-source provenance on every profile, template pitch drafting
through the AI-provider seam, campaign / draft / follow-up persistence (SwiftData, local-only).

Not built: the backend + AI router, real ingestion for Layers A–D, URL & file story input,
Share Extension, iPad 3-pane workspace, accounts, subscriptions.
