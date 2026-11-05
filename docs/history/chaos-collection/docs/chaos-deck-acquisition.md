# Chaos: deck acquisition

Primary progression: build the run's identity through choices. Clock events test
that identity; shared PvP rules let players choose the conditions of competition.

## Current prototype

```text
START:
  ordinary cards and base resources; no opening deck acquisition

FROM ANTE 2, before new-ante shop stock or blind selection:
  offer 3 distinct, unacquired supported decks
  player selects one, then clicks it again to commit
  apply acquisition to current state; retain earlier acquisitions
  never offer an acquired deck again

IF fewer than 3 remain:
  offer the remaining decks
IF none remain:
  stop drafting
```

- Offers are independently seeded per player, separate from gameplay RNG.
- No accumulation cap. Current catalogue: 14 vanilla decks excluding Plasma,
  plus seven enabled custom decks. Cocktail and Chaos are not acquisitions.
- Acquisition adapters distinguish ongoing rules, one-time gifts and permanent
  card transformations; never blindly call setup-only `Back:apply_to_run`.
- Save pending offers and completed acquisitions; reload must not repeat gifts.
- Preserve permanent acquisitions when temporary Clock/PvP rules expire.
- Acquired backs stack cosmetically on the draw pile; inspection lists all picks.
- Use Vanilla/no manual modifiers/no sleeve for the ordinary prototype baseline.

## Product direction

Confirmed hierarchy: deck-building primary; changing conditions secondary.
Choices should reward synergy, flexibility and adaptation, not merely select
the largest unconditional bonus.

Still to validate: offer balance, complete-run pacing, network/rejoin and actual
replay execution. Existing replay hooks and offline tests do not prove these.

Implementation reference: [deck draft](../../docs/chaos-deck-draft.md).
