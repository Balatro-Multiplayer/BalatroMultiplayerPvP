# Separate Almanac release work from the Chaos lab

Status: accepted direction; extraction not yet performed.

## Decision

- Preserve the entire collection before harvesting.
- Maintain two active tracks in PvP, API and server: `chaos-lab` and `almanac-v1`.
- Start the clean release track from pinned integration bases.
- Harvest feature-specific changes; never wholesale merge the experimental branch.
- Keep committed docs authoritative. Move historical `.context` notes into
  `docs/history/chaos-collection`; retain their exact text as historical evidence.
- Lead the v1 contract with the user's approved Almanac product statement.

## Consequences

The lab keeps opportunities and experiments without imposing release work.
The release must preserve newer upstream infrastructure rather than overwrite it
with old collection files. Baseline and gameplay recommendations remain unresolved
unless explicitly accepted; see `../almanac/v1.md`.

No push, production merge, deployment or queue enablement is authorized by this
preparation work.
