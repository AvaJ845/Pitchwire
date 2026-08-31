# Editorial Researcher — your role

You are the **mandatory human step** in Pitchwire's research workflow:

```
AI discovers → AI organizes → AI scores → YOU VERIFY → Pitchwire stores editorial evidence
```

AI finds candidates and drafts assessments. **Nothing is "verified" until you say
so**, and your name is attached when you do. If the app ever marked something
verified without you, that's a bug.

## What this job is *not*

- Not collecting contact info — email, phone, social. There is **no field for it**
  anywhere, and there never will be. The product's value is *who is relevant and
  why*, not *how to reach them*.
- Not building a big database. This is a **curated gold-standard set** (~25). Don't
  pad it.
- Not scraping, buying lists, or using enrichment providers. (If a licensed data
  provider is ever proposed, `docs/DATA_PROVIDER_INTAKE.md` is the gate.)

## Your tasks

### 1. Verification pass — the main job right now

For each candidate in **Profile → Developer → Research Lab → Candidates**:

1. Tap **Get verification brief** — the AI lists what to check and gives you 3
   ready-to-run searches (tappable).
2. Tap **Open author page** — their real author/staff page.
3. Confirm: still at this outlet? still this beat? published something **on-topic
   in the last ~3–6 months**?
4. Correct **Beat & fit** (topics / audiences / covered angles / do-not-pitch) to
   match what the page actually shows.
5. **Add 2–3 recent on-topic articles** — real headline, real `https://` URL,
   publish date (leave blank if you genuinely can't find it — **never guess**),
   topics.
6. Enter your initials, pick a **confidence** level, tap **Verify**. Or **Reject**
   if they don't hold up (wrong beat, left journalism, nothing recent/relevant).

Start with **8–10**, spread across the four verticals (AI & dev tools, privacy &
security, fintech & personal finance, indie iOS & consumer apps).

### 2. Export + commit

When a batch is done: **Research Lab → Export → Export directory as
editorial_seed.json**. It writes the file and copies the JSON to the clipboard.
Replace `Pitchwire/Resources/editorial_seed.json` in the repo and commit — that
makes your work the shipped default. (Without this step, verification lives only
on your device.)

### 3. Removal requests

The Lab shows open requests under **Removal requests**. For each: review, then
either **Reject** the profile (auto-resolves the request) or resolve it with a
note. The app promises a **48-hour** turnaround — hold that.

### 4. Keep it current

Verified confidence decays to "moderate" after 180 days. Periodically re-open
verified profiles — still at the outlet? still the beat? Re-verify or reject.

### 5. Claimed profiles — the better path

Email the ~25 at their **public work address**. Say it plainly: Pitchwire helps
founders send *fewer, more relevant* pitches — not a blast list. Invite them to
claim their profile and set their own beat + do-not-pitch list. When one
confirms, use **Mark as claimed profile**. Claimed = consent = the strongest
footing. Run this in parallel with the public-signal set; as claims land, they
replace the public-signal records.

## Rules you never break

- **No contact data.** If you want a field for an email, stop — wrong product.
- **Never guess or invent.** No made-up dates, no invented article titles. Blank
  beats fabricated.
- **Every claim traces to a source.** Can't point to the author page or the
  article URL? It doesn't go in.
- **Keep the set small and curated.** Gold-standard eval set, not a database.

## What "done well" looks like

Paste a real launch story (`docs/EVAL.md` has six). The top 3–5 matches are people
you'd actually pitch, each with a reason grounded in their real recent work and
2–3 articles you can open. That's the milestone — not a headcount.
