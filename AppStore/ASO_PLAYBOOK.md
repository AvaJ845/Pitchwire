# Pitchwire — ASO Playbook

Applying *The $50K/Month ASO Playbook* to Pitchwire (internal codename "BeatMatch").
The loop only compounds if every stage is built: **keywords → impressions →
screenshots → downloads → happy-moment reviews → rank boost → better keywords.**
Skipping a stage breaks the flywheel. This is a multi-year compounding asset, not
a launch-week sprint.

Paste-ready Name / Subtitle / Keywords and the Naming Council verdict live in
`METADATA.md` next to this file.

## 1. Discovery — get found

- [x] Naming Council run with live App Store collision checks — 2026-08-29. Verdict: **Revise** — rename BeatMatch → **Pitchwire**, ship as `PR Outreach - Pitchwire`. (see `METADATA.md`)
- [x] Applied the rename in the Xcode project (2026-08-29): `PRODUCT_NAME` → `Pitchwire`, `PRODUCT_BUNDLE_IDENTIFIER` → `com.avaresearch.pitchwire`, `INFOPLIST_KEY_CFBundleDisplayName` → `Pitchwire`, test bundle → `com.avaresearch.pitchwireUITests`, in-app title + About section → "Pitchwire". xcodegen target key, folder, scheme, and Swift types stay `BeatMatch` (codename). Build + UI test green.
- [x] App Store Name leads with primary keyword, brand second — `PR Outreach - Pitchwire` (23/30).
- [x] Subtitle is all-new words, secondary-keyword slot not a restated tagline — `Find journalists, pitch news` (28/30).
- [x] Keywords field comma-joined, no spaces, singular, no repeats of Name/Subtitle words, no competitor names — 97/100.
- [x] Exclusion list defined (`wire`, `distribution`, `HARO`, competitor names, outcome claims) — see `METADATA.md`.
- [ ] Enter metadata in App Store Connect; push keywords to the full 100 chars.
- [ ] Baseline keyword ranks recorded on the day of launch (expect invisible — that's normal per the patience curve).

## 2. Conversion — win the tap

- [ ] Icon legible at home-screen size — the mark *is* the product, not a logo lockup.
- [ ] 5 screenshots, real captured UI, hero feature first (match list, not the empty Home screen). Draft order in `METADATA.md`. Source captures already exist in `BeatMatch/Screenshots/`.
- [ ] Big legible captions, one idea per frame.
- [ ] (Optional) 15–20s App Preview of one real paste → match → draft loop.
- [ ] Product-page A/B test after launch: hero screenshot order first, then name (`PR Outreach` vs `Press Release`).

## 3. Momentum — compound with reviews

- [ ] Native review prompt fires after the **3rd pitch marked as sent** — a real happy moment, once per version, never at onboarding or after an error.
- [ ] Reply Loop: respond to every review; fix the complaint, flip the rating.
- [ ] Signature Hack on support email: "If Pitchwire helped you land a conversation, a short review really helps."
- [ ] Roadmap Signal: ~20 reviews asking for the same thing → build it, say so in a reply.
- [ ] Track keyword rank monthly; rotate the weakest keyword each update.

## Notes / open decisions

- **Rename applied 2026-08-29** — brand is **Pitchwire**, bundle `com.avaresearch.pitchwire`. Code-level `BeatMatch*` names kept as an internal codename.
- Category: **Business** primary (media-relations tool for founders/marketers), Productivity secondary.
- Competitive landscape (2026-08-29): the iOS media-relations niche is near-empty — closest is `ScoopSeeker` (Business, 3 ratings) and a dead `QuickPR` (0 ratings). Web incumbents (Cision, Muck Rack, Prowly, Prezly) have no meaningful iOS presence. This is the opportunity.
