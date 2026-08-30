# Pitchwire — the Editorial Research Engine

**Pitchwire is an editorial-relevance research assistant, not a journalist
contact database.** The intelligence is the product; the personal data is not.

You give it a story. It identifies relevant editorial professionals and
publications, explains *why* they're relevant using verifiable editorial
evidence, and helps you write an appropriate pitch. It never holds or hands out
personal contact information.

---

## The privacy-first data model

**Not modelled, not collected, not inferred — ever:**
personal email · phone · home address · private/guessed contact info ·
personal social accounts.

The data model holds **professional editorial context + source evidence** only.
There is no field anywhere for contact data, and `EditorialSeedTests` fails the
build if one appears in the seed file.

### Types (`Sources/Models/`)

| Type | Holds |
|---|---|
| `JournalistProfile` (internal codename) | name, role, `beatTopics`, `outlet`, `audiences`, `regions`, `coveredAngles`, `doNotPitch` |
| `EditorialEvidenceRecord` | one sourced claim: `provenance`, `evidenceSummary`, `sourceURL`, `verificationDate?`, `verifiedBy?`, `confidence`, `pitchPreference?` (only if *they* published it) |
| `CoverageEvidence` | one real article: `title`, `url`, `publishedAt?`, `topics[]` |

`recentBylineTitles` is derived from `CoverageEvidence` — one code path for real
and demo data.

### Provenance taxonomy (exact `rawValue`s)

`PUBLIC_EDITORIAL_SIGNAL` · `PUBLISHER_PROVIDED` · `CLAIMED_PROFILE` ·
`LICENSED_SOURCE` · `USER_PROVIDED` · `FICTIONAL_SAMPLE` (dev only).

### The verification gate

> **Do not label information as verified unless a human has reviewed the
> underlying source.**

`EditorialEvidenceRecord.verificationDate` / `verifiedBy` are `nil` until a
person approves the record in the Research Lab. `isVerified == (verificationDate != nil)`.
`evidenceConfidence` **caps** unverified and fictional profiles at `.exploratory`
— nothing about unreviewed data can inflate a match. The UI shows every profile
as **Verified**, **Candidate**, or **Demo**, never ambiguously.

---

## The research workflow

```
AI discovers  →  AI organizes  →  AI scores  →  HUMAN VERIFIES  →  Pitchwire stores editorial evidence
```

AI can discover candidates and summarise sources. **AI can never mark a candidate
as verified — the human approval step is mandatory.**

- **Discovery** happens in a Claude research session (web search of public
  author/staff pages), producing a candidate JSON. It is *not* done in the app or
  the backend — no scraper, no search-API dependency.
- **Verification** happens in the in-app **Research Lab** (Slice 4b): a researcher
  reviews the sources, reviews the AI relevance assessment, approves or rejects,
  and writes/updates the `EditorialEvidenceRecord` (attaching real article URLs +
  dates, setting `verificationDate`).

---

## The 25-record Verified Editorial Seed Set

`BeatMatch/Resources/editorial_seed.json` — a **gold-standard evaluation
dataset**, not the beginning of a database. 25 real editorial professionals
across 4 verticals (AI & dev tools, privacy & security, fintech & personal
finance, indie iOS & consumer apps).

**Current state: candidates.** Every record ships `verificationDate: null`,
`provenance: PUBLIC_EDITORIAL_SIGNAL`, `confidence: exploratory`. Each carries a
real `sourceURL` (the author/staff/newsletter page found in research) — the
anchor a researcher opens to verify the beat and pull real article URLs + dates.
`articles` is intentionally empty until Lab verification; nothing is guessed.

Because none are verified, **no seed match can score above "Strong"** — which is
correct. Verifying a record in the Lab (adding dated articles, setting
`verificationDate`) is what unlocks "Excellent".

**Do not expand the dataset until matching quality is demonstrated** (see
`docs/EVAL.md`). The milestone is *"Pitchwire consistently explains why its top
recommendations are relevant"* — not a headcount.

---

## Matching = editorial relevance (`Sources/Services/RelevanceEngine.swift`)

Nine weighted, inspectable signals, deterministic, no AI in the ranking:

| Signal | Weight | Reads |
|---|---:|---|
| Topic match | 24% | declared beat topics vs the story |
| Recent coverage | 18% | on-topic articles, recency from real `publishedAt` |
| Repeated coverage | 14% | count of on-topic articles — a beat, not a one-off |
| Angle fit | 10% | covers this story type (launch / funding / …) |
| Audience fit | 10% | who they write for vs the story's audience |
| Publication relevance | 8% | `Outlet.verticals` vs the story vertical |
| Geography | 4% | region overlap |
| Pitch preference | 6% | **hard filter** — a published "don't pitch me X" zeroes it |
| Evidence & verification | 6% | freshness + verified state; unverified never elevates |

**The match score is editorial relevance. It never implies probability of
response, publication, or coverage.** `RelevanceResult.relevanceDisclaimer`
carries that line and it is shown on the score card.

---

## What every recommendation exposes (`JournalistDetailView`)

WHO · WHERE THEY PUBLISH (outlet link) · WHAT THEY COVER (beat) · WHY THEY MATCH ·
EVIDENCE (article links + dates) · SOURCE (`sourceURL` link) · VERIFICATION DATE
(or "not yet verified") · CONFIDENCE. Every source opens in the browser.

---

## Apple privacy principle

The architecture is **not** designed around compiling personal information from
public databases. App Store guideline 5.1.1(viii). If a future data provider
supplies journalist information, integration requires explicit documentation of
licensing rights, permitted fields, permitted use, retention, display rights, and
deletion/correction mechanisms — a provider is never integrated just because its
database is large.

---

## Slice 4b — the Research Lab (next)

A DEBUG-only admin surface (Profile → Developer) that lets a researcher:

1. Define a vertical.
2. Load session-discovered candidates (or paste a candidate JSON).
3. Review supporting sources (open each `sourceURL`).
4. Review the AI-generated relevance assessment.
5. **Approve or reject** each candidate.
6. On approve: attach real dated articles, set `verificationDate` / `verifiedBy`,
   write the `EditorialEvidenceRecord`.

AI cannot autonomously approve. The human step is the product's integrity.
