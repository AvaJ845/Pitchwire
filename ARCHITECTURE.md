# Pitchwire (AI Press Agent) — Architecture & Kickoff

Synthesized from the Fellows Build Brief, following the Build Philosophy: smallest MVP → core action → core outcome → challenge assumptions → architecture → smallest vertical slice.

## 1. Core user action (unchanged from brief)
Paste/submit a launch story and get ranked, explained journalist matches.

## 2. Core measurable outcome (unchanged from brief)
Qualified pitch actions per analyzed story (saves, drafts, or sends against recommended targets).

## 3. Smallest valuable MVP — Slice 0
The brief's MVP scope (story input, analysis, matching, explanation, pitch drafting, shortlist, provenance) is already trimmed. For the first vertical slice, it narrows further to the smallest thing that proves the core loop end-to-end on iPhone:

- Story input: **paste text only** (URL fetch and file upload come after the loop is proven)
- One hardcoded vertical (AI / dev tools journalists) with a **seed set of ~15–20 real journalists** (real bylines, real outlets, hand-curated) standing in for the full ingestion pipeline
- Analysis → ranked matches (excellent/strong/possible) → reason-on-card → journalist detail → pitch draft (subject + short/long)
- SwiftData persistence, **no accounts/auth**, everything local to device
- No Share Extension, no iPad 3-pane, no campaign persistence beyond local save — those are Slice 1+

## 4. Assumptions challenged
- **Auth**: Not needed for Slice 0. Shortlist/campaigns are local-only (SwiftData). Answers the brief's first open question for now — revisit when sync across devices or team sharing is actually requested.
- **Full journalist database / licensed data (Layer C)**: Deferred. A small hand-curated seed set is enough to validate that matching + explanation quality is worth building the real ingestion pipeline for. Don't build the data layer before proving the product loop wants it.
- **iPad 3-pane workspace**: Deferred to Slice 1. Slice 0 is iPhone-only ("assistant in motion").
- **Share Extension**: Deferred to Slice 1 — real leverage once there's a working match/draft loop to hand it off to.
- **Backend services (API gateway, subscriptions, rate limiting)**: Not needed for Slice 0. LLM calls happen from a thin client-side service layer behind protocols, so a real backend can be swapped in later without touching UI code. (Flagging for later: shipping a real API key in the client isn't viable past Slice 0 — a proxy service is needed before any public release.)
- **Two-tier model routing**: Build the *abstraction* now (cheap model for extraction/tagging, stronger model for user-facing text) since it's cheap to define and expensive to retrofit — but only one real provider needs to be wired up today.

## 5. Architecture

**Client:** SwiftUI + SwiftData, single iOS app target (iPhone first, iPad layouts in Slice 1).

**Entities (SwiftData @Model, all 9 modeled now — cheap to define, used throughout):**
Story, Campaign, MediaTarget, Outlet, JournalistProfile, MatchExplanation, PitchDraft, ProvenanceRecord, FollowUpTask.

**Service layer (protocol-first, so a real backend can replace the client-side impl later without UI changes):**
- `StoryAnalysisService` — structured output only (topic, audience, geography, angle, urgency). The LLM is never the source of truth for *who exists* — that's the seed/data layer.
- `MatchingService` — scores seed `JournalistProfile` set against analysis output → ranked `MediaTarget` list with confidence tier. Deterministic scoring, not LLM-invented.
- `PitchDraftingService` — subject + short/long variants, stronger model tier, grounded in the story + match explanation (never a bare number, always a reason).
- `ProvenanceStore` — seed data carries source + last-verified + report-issue stub per the brief's provenance requirement, even in Slice 0.

**Information architecture:** 4 tabs (Home, Campaigns, Drafts, Profile). Home = calm "what's your story?" intake, not a dashboard. Result flow: story summary → confidence-tiered match list → journalist detail with "why this match" (one-line reason on every card, never a bare score).

## 6. Slice 0 build scope (this session)
1. 4-tab app shell (Home / Campaigns / Drafts / Profile)
2. Home: paste-text intake → "Analyze"
3. `StoryAnalysisService` protocol + stub/LLM-backed implementation
4. Seed `JournalistProfile` dataset (AI/dev-tools vertical)
5. `MatchingService` → confidence-tiered match list (excellent/strong/possible), reason on every card
6. Journalist detail view with full "why this match" explanation + provenance (source, last verified)
7. `PitchDraftingService` → pitch draft screen (subject + short/long)
8. Local save to shortlist (SwiftData)

Explicitly **not** in this pass: URL/file story input, real journalist ingestion, iPad layout, Share Extension, accounts, subscriptions, rate limiting, App Store submission checks. Those are Slice 1+ per the brief's own cut list and the Design/QA fellow's App Store checklist (5.1.1(viii) review happens before submission, not before Slice 0 exists).

## Open questions carried forward (unchanged)
- Accounts/auth: deferred, not decided — Slice 0 assumes local-only.
- Licensed data source for Layer C: not chosen; Slice 0 uses a hand-curated seed set instead, so this decision isn't blocking early progress.
