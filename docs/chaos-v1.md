# Almanac v1: deck building, shared rules, ante scaling

## Agreed direction

- Almanac names both the queue and its required signature deck.
- Intended competitive availability: Almanac queue only; retain solo/private practice access.
  Queue restriction/enforcement is not implemented yet.
- One mode and a fixed baseline, not a public configuration wall.
- Neutral start; deck drafts at antes 2, 3, 5, 7. Three offers, keep one.
- Acquisitions accumulate; no repeats. Earlier unlocked decks remain eligible.
- Shared PvP rule selection; a bounded launch pool.
- Gently tougher ante requirements after acquisitions; exact curve still needs tuning.
- Temporary opportunities, including Higher Calling, move to v1.1. Keep existing lab work.

## V1.1 opportunity direction

- Same opportunity for both players, announced at an ante boundary before spending.
- One opportunity at a time; rare in normal play, easy to exercise in tests.
- Small launch pool: Higher Calling, Everybody Counts, and the free/Perishable shop event.
- Higher Calling should offer a useful route to participate; the access mechanism is unresolved.

## Implemented here is not the whole product

- Deck milestones and accumulated-deck inspection exist.
- Higher Calling works in the local lab and decorates affected Judgement cards.
- Everybody Counts currently lasts one blind: every played card scores, with unchanged hand recognition.
- Run effects inspection separates active-effect descriptions/expiry from lab controls.
- Short Shelf Life replaces the shop event's display name, avoiding vanilla Clearance Sale.
  Its internal `clearance_sale` key is unchanged; the event remains pending.
- The queue is disabled. Shared opportunity scheduling, announcement and network authority are not implemented.
- The inspection screen is an English-only Custom Solo prototype, not a multiplayer status HUD.

## Decisions still required

- Front door: recommend a simple fixed-mode entry, with lab/configuration kept separate;
  the user has asked to debate this rather than treating the menu structure as settled.
- Exact baseline: list and freeze enabled balance/content layers.
- Ante curve: choose and validate the post-acquisition increases against that baseline.
- Shared rules: final launch pool and ante gates. The prototype already implements
  duplicate-pick handling and countdown reveal; those still need live validation.

## V1.1 decisions still required

- Opportunity cadence: first eligible ante, probability or spacing, repeat policy.
- Everybody Counts: retain one-blind duration or extend to the ante?
- Short Shelf Life: which shop is affected after announcement? Sticker compatibility,
  Eternal exclusions, and resale protection must be specified before activation.
- Higher Calling access: guaranteed offer, gifted Judgement, or increased availability?
  A gift also needs a full-consumable-slot rule.

## Release acceptance

- [ ] Working entry point with short rules, fixed baseline and clear mode identity.
- [ ] Almanac required in its queue and unavailable in other competitive queues.
- [ ] Four milestone drafts work across save/load, replay and reconnect.
- [ ] Simultaneous PvP picks, ten-second timeout, duplicate picks and both-player application verified.
- [ ] Ante curve tuned through played matches; no unintended opening difficulty increase.
- [ ] Status distinguishes permanent deck effects from encounter rules.
- [ ] Full two-player match from entry through result and rematch.
- [ ] Controller, reduced motion, localization and actual in-game layout checked.

Do not enable the queue merely because local mechanic tests pass.
