# Data-provider intake checklist

**Do not integrate a data provider because its database is large.** Pitchwire's
value is editorial-relevance intelligence, not personal-contact aggregation. A
provider is only integrated if it clears every item below, and the answers are
committed to this repo before any code is written.

This exists because App Store guideline **5.1.1(viii)** prohibits apps that
compile personal information from sources not provided by the user "even [from]
public databases." A licensed provider does not remove that risk on its own — the
licence terms have to actually permit what we'd do.

## Gate 1 — is this editorial context or personal data?

| Integrate | Never integrate |
|---|---|
| Outlet, beat, role, byline titles + dates + URLs, public bio, public "how to pitch me" statements the journalist published | Email, phone, physical address, private/inferred contact info, personal social handles, "enriched" or "waterfall" contact data |

If the provider's core offering is contact data, stop here.

## Gate 2 — documented rights (all required)

- [ ] **Licensing rights** — a signed licence that names Pitchwire and the app as a
      permitted use. Not "public API, use at your own risk."
- [ ] **Permitted fields** — an explicit list of which fields we may store and
      display. Map each to a Pitchwire model field; anything unmapped is dropped
      on import.
- [ ] **Permitted use** — recommendation + display to the app's user is covered.
      Resale, redistribution, and bulk export are out (and we don't do them).
- [ ] **Retention** — how long we may keep a record, and the refresh cadence
      required to keep it "current."
- [ ] **Display rights** — may we show the source name? Must we attribute? Any
      fields that are "compute-only" (may inform ranking, may not be shown)?
- [ ] **Deletion / correction** — the provider's own removal SLA, and a webhook or
      feed we consume so a record deleted upstream is deleted in Pitchwire within
      that SLA. Our own "request removal" path (see `RESEARCH_LAB.md`) must also
      reach the provider where the record originated there.
- [ ] **Journalist opt-out** — does the provider honour a journalist's request to
      be excluded? If not, we can't rely on it for 5.1.1(viii).

## Gate 3 — provenance + honesty

- [ ] Records import as `LICENSED_SOURCE` provenance, `verificationDate: null`
      (a licence is not a human review of the underlying sources).
- [ ] `evidenceSummary` cites the provider + import date.
- [ ] The Research Lab shows them as candidates; a researcher still verifies the
      articles before the profile presents as verified.
- [ ] `EditorialSeedTests`-style guard: the import path rejects any payload key
      that looks like contact data.

## Gate 4 — the removal pipeline is live first

No provider import ships until "Report an issue / request removal" POSTs to a
monitored inbox with a working 48-hour takedown. Twenty licensed records is still
a compilation; the takedown path is what makes it defensible.

---

**Decision log:** _(none yet — the shipped seed is `PUBLIC_EDITORIAL_SIGNAL`,
compiled by hand, no provider.)_
