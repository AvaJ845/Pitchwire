# The Research Lab (Slice 4b)

The internal, DEBUG-only workflow that turns AI-discovered **candidates** into
**verified** editorial-evidence records. Reached from **Profile → Developer →
Research Lab**. It is the mandatory human step in:

```
AI discovers → AI organizes → AI scores → HUMAN VERIFIES (here) → Pitchwire stores evidence
```

## What it is

- `JournalistDirectory` — the persistent pool matching scores against. Seeded once
  from `editorial_seed.json` (`ensureSeeded`, idempotent). Every campaign shares
  these records, so a verify/reject/edit applies everywhere.
- `ResearchLabView` — lists the directory by state (Candidate / Verified /
  Rejected) + the open **removal-request** queue.
- `CandidateReviewView` — one profile: open its `sourceURL`, read the AI-drafted
  assessment (labelled *not evidence*), attach real articles, verify or reject.
- `LabActions` — every state change as a pure, unit-tested model mutation. **AI
  never calls these.**

## The rules it enforces

| Rule | Mechanism |
|---|---|
| No contact data, ever | The article editor takes only headline / https URL / date / topics. There is no field for anything else, here or in the model. `EditorialSeedTests` fails the build if a contact field appears in the seed. |
| AI cannot verify | `verificationDate` / `verifiedBy` are only ever set by `LabActions.verify`, which is wired to a button a person taps. |
| A verification must be attributable and evidenced | `verify` returns false without **≥1 article** and a **reviewer name**. |
| Unverified never over-presents | `evidenceConfidence` caps candidates + fictional at `.exploratory`; a fresh human verification unlocks the stated confidence, which then decays to `.moderate` after 180 days. |
| A rejected profile disappears from the product | `isRejected` → excluded by `JournalistDirectory.matchable` → never scored, never shown. |
| Removal requests get acted on | "Report an issue / request removal" on any profile creates a `RemovalRequest`; the Lab surfaces the open queue; rejecting a profile auto-resolves its requests. |

## The verify checklist (what a researcher actually does)

1. Open the candidate. Tap **Get verification brief** — the model drafts what to
   confirm on the author page and what to search for (it has no web access and
   concludes nothing; the brief isn't saved).
2. Tap **Open author page**. Work through the brief's checks.
3. Correct **Beat & fit** (beat topics / audiences / covered angles / do-not-pitch)
   against what the page actually shows — edit inline.
4. Find 2–3 recent on-topic pieces (the brief's searches help). For each:
   **Add article** → real headline + https URL, set the date (leave blank if
   genuinely unknown — never guess).
5. Set your initials + a confidence level.
6. **Verify.** Or **Reject** if the candidate doesn't hold up (wrong beat, left
   journalism, no recent relevant work).

## Claimed profiles

`Mark as claimed profile` sets provenance to `CLAIMED_PROFILE` — **only** when the
journalist has confirmed they claimed it (e.g. by email). A self-serve claim flow
(the journalist signs in and edits their own beat + do-not-pitch list) needs
accounts, which don't exist yet; it's the intended Layer-A path (see `SEED_SET.md`).

## The verification brief (`AITask.verificationBrief`)

A `.fast`-tier call that returns two plain blocks — `CHECKS:` and `SEARCHES:` —
parsed by `VerificationBriefService`. The system prompt forbids inventing article
titles, URLs or dates and forbids concluding anything; the model has no web
access. It's `origin: .userInitiated` so it preempts background enrichment. The
output is shown, not stored — regenerate any time. This is the spec's "review the
AI-generated relevance assessment" step, turned into something actionable.

## Not done yet

- Removal requests: the Worker route + optional webhook exist; a **monitored
  inbox with a real 48-hour SLA is the operator's job** (the in-app copy promises
  it).
- No bulk import of a session-discovered candidate JSON beyond the bundled seed.
- Not gated behind a real admin auth — it's `#if DEBUG`, compiled out of release.
- Enrichment still warms only the top 3 matches on the list (`enrichOne` covers
  any card opened). Widening that is worth it once profiles carry real articles.
