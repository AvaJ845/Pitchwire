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

1. Open the candidate. Tap **Open author page**.
2. Confirm the beat matches what the page shows. Fix `beatTopics` if needed (edit
   the seed / model — a Lab field for this is a future nicety).
3. Find 2–3 recent on-topic pieces. For each: **Add article** → paste the real
   headline + URL, set the date (leave blank if genuinely unknown — never guess).
4. Set your initials + a confidence level.
5. **Verify.** Or **Reject** if the candidate doesn't hold up (wrong beat, left
   journalism, no recent relevant work).

## Claimed profiles

`Mark as claimed profile` sets provenance to `CLAIMED_PROFILE` — **only** when the
journalist has confirmed they claimed it (e.g. by email). A self-serve claim flow
(the journalist signs in and edits their own beat + do-not-pitch list) needs
accounts, which don't exist yet; it's the intended Layer-A path (see `SEED_SET.md`).

## Not done yet

- Removal requests are a **local** queue. Before any public release, "Report an
  issue" must also POST to a monitored inbox with a real **48-hour SLA**, and the
  in-app copy already promises that window.
- No Lab editing of `beatTopics` / `audiences` / `coveredAngles` (edit the seed).
- No bulk import of a session-discovered candidate JSON beyond the bundled seed.
- Not gated behind a real admin auth — it's `#if DEBUG`, compiled out of release.
