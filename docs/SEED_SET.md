# Building the real seed set — fellows recommendation

The app runs on 15 fictional journalists. To judge whether the matching is any
good, we need ~15–20 **real** ones. DJ doesn't have a press list — but that's not
the blocker people assume it is. A journalist's beat and bylines are public
editorial output; you don't need to *know* anyone.

The real question is doing it **defensibly**. This is the Legal/Policy Fellow's
call, with a research method from the Data Fellow.

---

## The Legal/Policy Fellow — the constraint that shapes everything

App Store guideline **5.1.1(viii)**: apps that compile personal information from
sources not provided directly by the user, or without explicit consent — *"even
public databases"* — are not permitted.

A hand-curated list of 20 real journalists **with their contact details** is
compiling personal data. Twenty is enough to be a problem.

**The reframe that makes this shippable:** separate the two things Pitchwire
touches.

| Editorial facts (OK to compile carefully) | Personal contact data (NOT ours to hold) |
|---|---|
| Outlet, beat, recent byline titles + dates, public bio, which story angles they cover | Email, phone, DMs, private "how to pitch me" notes |

Pitchwire's job is **who + why + draft the pitch.** It does **not** need to store
or hand out contact details — the user sends the pitch through their own email,
having found the address the normal way (or the journalist opted in and shared
it). The app already reflects this: there is no "Send" button, only Copy and
Share.

### Recommended seed strategy

**Public editorial signals only, no contact distribution.**

- Seed 15–20 real journalists' **beats and bylines**, compiled from their public
  outlet author pages and newsletters.
- Store **no** email, **no** phone, **no** pitch preferences beyond what they've
  published publicly (e.g. a newsletter footer that says "pitch me at…" — that's
  *their* published statement, quote it verbatim and cite it).
- For "how to reach them," the app deep-links to the outlet's staff/contact page
  or says *"find them via {outlet}."* It never presents a contact field.
- Provenance: `.publicSignal`, detail = *"Compiled from {outlet} author archive +
  public bio, {date}."*
- Ship a **working** "Report / request removal" on every profile (the button
  exists; wire it to an inbox + a real 48-hour takedown SLA before any public
  release).

### The better long-term path — claimed profiles (Layer A)

Email 20–30 journalists at their **public work address**. Tell them plainly what
Pitchwire is: *a tool that helps founders send fewer, more relevant pitches — not
a blast list.* Invite them to claim a profile and set their own beat + a
do-not-pitch list. Journalists want fewer irrelevant pitches; some will say yes.

That's **consent** — bulletproof under 5.1.1 — and a real moat (Cision and Muck
Rack both prove controlled, claimed professional identity is valuable in this
category). Run this in parallel with the public-signal seed; as claims come in,
they replace the `.publicSignal` records and `isSampleData` / the banners take
care of themselves.

### Where NOT to get data

- Scraping Muck Rack / Cision / a media database — ToS violation **and** the
  5.1.1(viii) problem.
- Buying a media list — same.
- LinkedIn scraping — same, plus LinkedIn's own ToS.
- Any "enriched" contact provider (Apollo, Hunter, etc.) — this is exactly the
  compiled-personal-data pattern the guideline names.

---

## The Data Fellow — the research method (~2–3 hours, zero contacts needed)

1. **Pick the verticals that match what we'd actually pitch.** DJ's own portfolio
   is the tell — Kestrel (weather/climate/science), Hummingbird (consumer
   finance / markets-education), Crossbeat (consumer wellness / indie iOS),
   Redress & BreachKit (consumer advocacy / class actions / privacy), Milestone
   (personal finance), Pitchwire itself (PR/marketing tools). Seed **4 verticals**:
   *indie iOS & consumer apps, privacy & security, personal finance / fintech,
   AI & developer tools.*

2. **For each vertical, find who wrote the last ~10 launch or feature stories.**
   Public sources, in rough order of usefulness:
   - The outlet's **topic / tag pages** (e.g. a site's `/tag/privacy` or
     `/apps` section) → whoever's byline keeps appearing.
   - **Tech newsletters on Substack / beehiiv** — many are one person, they
     publish their pitch address in the footer, and they cover exactly one niche.
     This is the highest-signal, most-pitchable category.
   - **Techmeme** — its river and "who's covering this" attributions surface the
     active reporters on a story in real time.
   - **RSS** of the relevant section of 3–4 outlets; skim two weeks.

3. **For each journalist, record only:** name · outlet · outlet URL · public
   author-page URL · 3 real recent byline titles + publish dates · the beat as
   *they* describe it (their bio line) · which angles their recent work covers
   (launch / funding / acquisition / …). **Nothing private.**

4. **Enter it** into `SampleJournalists.swift`'s replacement (a real
   `Resources/journalists.json` loaded at first run), each with a `.publicSignal`
   `ProvenanceRecord` citing the source and date.

5. **Sanity-check the matching.** Paste 5 real past launch stories (our own
   portfolio's, or public ones) and see if the top matches are people you'd
   actually pitch. If yes, the engine is worth building the real pipeline for —
   which is the whole point of the MVP.

### Starter list of *sources* (organisations, not people)

Work from these; do the per-person compilation yourself or with a researcher,
with the removal pipeline live first:

- **Indie iOS / consumer apps:** app-focused sections of major tech outlets;
  indie-dev newsletters; the iOS-press lists that indie devs maintain publicly.
- **Privacy & security:** dedicated security desks at 2–3 outlets; independent
  security newsletters; consumer-advocacy outlets.
- **Personal finance / fintech:** the fintech verticals of business outlets;
  independent fintech newsletters; personal-finance desks at consumer outlets.
- **AI & developer tools:** AI-beat reporters at general tech outlets;
  developer-tooling newsletters; open-source-focused publications.

(Deliberately not naming individuals here — a list of 20 real journalists in a
repo doc is itself the compilation this whole memo is about. The method is the
deliverable; the list lives behind the removal pipeline.)

---

## Verdict

**Approve** the two-track plan: ship a **public-editorial-signal** seed (beats +
bylines, no contact data, working removal) to unblock matching evaluation now,
and run **claimed-profile outreach** in parallel as the path to a real,
consented, defensible database. **Reject** any purchased list, scrape, or
enrichment provider — that's the exact pattern 5.1.1(viii) prohibits and it's the
thing that would sink the app on review.
