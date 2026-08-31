# Pitchwire — matching evaluation

The MVP milestone is not *"Pitchwire has N journalists"* — it is:

> **Pitchwire can consistently explain why its top recommendations are relevant.**

This file is the living benchmark. After any change to `RelevanceEngine`, the
seed set, or the analysis prompt, re-run `EditorialRelevanceEvalTests` and read
the printed report.

## What "good" means here

For every test story, the engine must produce a ranked list where:

1. **Every match is explained.** Each returned match has ≥1 `CoverageEvidence`
   article **and** a non-empty, grounded reason string. No bare scores.
2. **"Excellent" means a pattern.** No match is tier `.excellent` unless the
   professional has ≥2 recent on-topic articles (repeated coverage).
3. **The top picks are in the right neighbourhood.** The top 3 matches belong to
   the vertical(s) the story is about (checked once the real seed set is loaded —
   see "Vertical expectations" below).
4. **Pitch-preference is respected.** A profile that has publicly asked not to be
   pitched this angle is disqualified (score floored), not merely down-ranked.

## Test stories

Real launch stories, paraphrased. Each names the vertical(s) whose editorial
professionals *should* surface.

| # | Story (one line) | Expected vertical(s) | Why |
|---|---|---|---|
| 1 | A solo developer launches a native macOS Markdown editor with local-first sync. | indie iOS / consumer apps | consumer app launch, no funding/enterprise angle |
| 2 | A startup raises a $12M Series A to build an open-source LLM evaluation framework for engineering teams. | AI & developer tools | model tooling + funding; devtools + AI-infra reporters |
| 3 | A privacy company ships end-to-end encrypted group calling and publishes a third-party audit. | privacy & security | security desk story: E2EE, audit, threat model |
| 4 | A neobank launches automated tax-loss harvesting for retail brokerage customers. | personal finance / fintech | consumer-finance + fintech-vertical reporters |
| 5 | An AI lab releases a smaller open-weight model that runs on a laptop, MIT-licensed. | AI & developer tools | open-weight model release; AI-beat + OSS reporters |
| 6 | A well-funded startup is acquired by a large incumbent for its developer-tools team. | AI & developer tools | acqui-hire / build-vs-buy angle for the devtools space |

## Vertical expectations

Enforced by the eval test **only when the verified `editorial_seed.json` is
bundled** (each profile has a `vertical`). With the fictional fallback pool the
test checks invariants 1, 2 and 4 only.

## Status (2026-08-31)

Passing on the 21-record verified seed. Every top match cites a real recent
article by title + date; every returned match reads as verified with evidence;
the per-vertical top-3 checks pass for all six stories. Known slack: some
cross-vertical bleed at lower ranks (e.g. a consumer-apps reporter who covered a
privacy settlement surfaces on the privacy story) — real but not who you'd pitch
first. Tuning target: article `topics` tags are coarse (outlet section labels);
tighter tagging or a publication-relevance penalty would sharpen it.

## Running it

```
xcodebuild -scheme BeatMatch -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BeatMatchUnitTests/EditorialRelevanceEvalTests test
```

The test prints, per story, the top 5 matches with tier, score, and reason — read
that, not just the pass/fail.
