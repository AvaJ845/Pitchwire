# App Store — Pitchwire (earlier working name "BeatMatch", now fully renamed)

> Aligned to *The $50K/Month ASO Playbook* (`~/Downloads/The__50K_ASO_Playbook.pdf`).
> As an unknown new entrant, the App Store **Name leads with the primary keyword,
> not the brand** — we cannot afford to spend the name slot on brand the way an
> established player can.

## Naming Council — 2026-08-29

Live App Store evidence via iTunes Search API (`itunes.apple.com/search`).

| Fellow | Lean | Key finding |
|---|---|---|
| Discoverability | **Approve** | Primary keyword "PR Outreach" is first in the Name, brand second (`<keyword> - <brand>`). Name 23/30, Subtitle 28/30, Keywords 97/100. Zero words repeated across the three fields. Target term "press release" sits in the Indie Battlefield / near-Unicorn quadrant — real founder search intent, only one dead direct competitor. Nit: use singular "journalist" in the subtitle; spend the last 3 keyword chars. |
| Collision | **Revise** | **"BeatMatch" is a hard collision** — `Beatmatch: Do More Together` by **Beatmatch, Inc.** (Social Networking, live, 5★) holds the exact spelling → trademark exposure + search confusion. Also `Beatmatch PRO` (Games) and `BeatMatch: Dance Sync` (Sports); "beatmatch" is a DJ term that pulls the wrong audience (Auto BPM, Crossfader, Remixlive all surface). **"Pitchwire" is clean** — no exact or near match, no company. The PR-tool niche on iOS is near-empty: `press release` / `PR outreach` / `media pitch` / `publicist` all return news readers + influencer-PR-package apps, plus one dead competitor `QuickPR` (0 ratings) and a tiny `ScoopSeeker` (3 ratings). |
| Portfolio | **Revise** | **Internal collision:** we already ship **Crossbeat** (`com.avaresearch.crossbeat`, a rhythm game) whose keyword field contains `beat` — "BeatMatch" under the same org competes with our own app for that token. `com.avaresearch.pitchwire` is clean and consistent with the AvaResearch house style (Crossbeat, Doorframe, BreachKit, Milestone). No other portfolio app targets PR / press / media / journalist keywords. Keep the brand decoupled from any in-app "match/matching" feature term (Top Pup lesson) — "BeatMatch" stays a code-only codename. Exclude outcome/guarantee and paid-distribution language for App Review, same discipline as Kestrel's advice-exclusion list. |

**VERDICT: Revise** — the metadata *structure* is playbook-aligned and approved.
The one required change is the brand: **drop "BeatMatch"** (hard external collision
with Beatmatch, Inc. + DJ-term dilution + internal clash with our own Crossbeat) and
ship as **`PR Outreach - Pitchwire`**, home-screen name **`Pitchwire`**, bundle
**`com.avaresearch.pitchwire`**. *(Update 2026-08-31: "BeatMatch" is fully retired — folder, xcodegen targets, scheme, and Swift types are all `Pitchwire` now.)*

---

## Identity — Discovery (paste-ready)

- **App Store Name (≤30):** `PR Outreach - Pitchwire`  *(23 — primary keyword FIRST, brand second)*
  - Home-screen name (CFBundleDisplayName): `Pitchwire`
- **Subtitle (≤30):** `Find journalists, pitch news`  *(28 — all new words, none repeated from the Name)*
  - Alts: `Match your story to reporters` *(28)* · `Media list + pitch drafts` *(24)*
- **Keywords (≤100):** `press,release,media,reporter,publicist,newsroom,coverage,story,editor,contact,byline,founder,list`  *(97)*
- **Bundle ID:** `com.avaresearch.pitchwire`
- **Primary category:** Business  ·  **Secondary:** Productivity
- **Age rating:** 4+
- **Price:** Free for Slice 0. (Later: a proxy-backed Pro tier once real ingestion + LLM calls ship — a client-side API key is not viable past Slice 0, per ARCHITECTURE.md §4.)

**Combinations harvested** (Apple indexes Name + Subtitle + Keywords as one string):
`PR outreach`, `media pitch`, `pitch news`, `press release`, `media list`, `media contact`,
`press coverage`, `media coverage`, `journalist outreach`, `find journalist`, `newsroom contact`,
`reporter email`, `story pitch`, `editor contact`, `founder PR`, `press story`.

**Deliberately excluded:**
- `wire` / `newswire` / `distribution` — Pitchwire drafts and targets pitches; it is **not** a paid
  press-release distribution service (PR Newswire / Business Wire). Claiming distribution invites an
  App Review question and disappoints users.
- `HARO` — trademarked (Cision / "Connectively"); Apple rejects trademarked competitor terms.
- `Cision`, `Muck Rack`, `Prowly`, `Meltwater`, `QuickPR` — competitor names; Apple auto-rejects.
- `guaranteed`, `get featured`, `press hits` — outcome claims we cannot back.
- plural `journalists` in the Keywords field — the singular is already implied via the Subtitle, and
  Apple handles plurals automatically.

### Alternate name (if "PR Outreach" tests weak)
`Press Release - Pitchwire` *(25)* — highest raw search volume; only dead direct competitor is
`QuickPR` (0 ratings). Risk: implies wire distribution, so the Subtitle must carry the clarification
(`Find journalists & send your pitch`). Test both with a product-page A/B on the hero screenshot order
first (Step 3), name second.

---

## Screenshots (6.9" — Conversion, lead with the payoff)
Per the playbook's A/B finding (authentic real UI beats abstract polish), use real captured screens —
we already have them in `Pitchwire/Screenshots/`:
1. **Match list** — "Paste your story. See who's most likely to care." (confidence-tiered results, reason on every card)
2. **Journalist detail** — "Every match comes with a reason and its source." (why-this-match + provenance)
3. **Pitch draft** — "A subject line and two pitch lengths, ready to edit." 
4. **Home intake** — "No dashboard. Just: what's your story?"
5. *(Slice 1)* an honesty/provenance beat — "We never invent a contact. Every profile shows where it came from."

Never open on the empty Home screen alone — lead with the match list (the payoff).

## Momentum (reviews)
- **Happy moment:** fire the native review prompt after the user marks their **3rd pitch as sent**
  (a real "I did the thing" peak) — once per app version, never at onboarding.
- Reply to every review; treat repeated feature asks as the Slice 1+ roadmap signal.
- Support-email signature: "If Pitchwire helped you land a conversation, a short review really helps."
