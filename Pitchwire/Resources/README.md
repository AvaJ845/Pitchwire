# Editorial research seed set

The gold-standard evaluation dataset lives here as `editorial_seed.json` once
compiled. Format: see `Sources/Data/EditorialSeedLoader.swift` (`SeedFile`).

Rules: no contact data of any kind; every article carries a real URL; every
record ships `verificationDate: null` until a human approves it in the Research
Lab. Nothing here is fabricated — missing fields are left empty.
