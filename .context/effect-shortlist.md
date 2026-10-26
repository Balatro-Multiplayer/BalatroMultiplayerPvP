# Chaos Clock: effect shortlist

Discussion decisions supplement CHAOS_CLOCK_DESIGN.md. These are design contracts,
not implemented effects. The first four concepts have pending entries in
example-poc.lua; the others below are design-only. None enter gameplay.

## Approved concepts to stub

### Loaded Dice

- Forecasted blind: listed probabilities are doubled, including adverse outcomes.
- Glass breakage is part of the appeal, not an exception to remove.
- Before implementation: define exactly which probability checks participate and
  how the multiplier composes with existing probability modifiers.
- Clock selection itself must remain unaffected.
- Preset eligibility and selection weight remain undecided.

### Everybody Counts

- Forecasted blind: every played card scores.
- This changes scoring-card membership, not poker-hand recognition.
- Before implementation: check interaction with existing all-card scoring effects
  so cards do not score twice merely because two sources enable the same rule.
- Preset eligibility and selection weight remain undecided.

### Clearance Sale

- Announce at shop entry, before purchases: Jokers bought here are free and Perishable.
- Mark the actual offer before purchase; Perishable remains after leaving the shop.
- The attraction is temporary power plus slot pressure and ownership-based shop
  exclusion, not simply extra money.
- Ownership normally excludes another copy from the shop pool; do not describe
  this as permanent exclusion after selling. Verify duplicate-enabling exceptions.
- Before implementation: decide how Perishable-incompatible and already Eternal
  Jokers are handled, and prevent free purchases becoming an unintended resale loop.
- Preset eligibility and selection weight remain undecided.

### Bonfire

- Normal and Mayhem: forecast before the blind.
- After the first scored hand resolves, destroy its scoring cards exactly once.
- The destruction is permanent; the triggering window is not.
- This is preferred to Dead Cards as a flagship effect, not yet a decision to
  remove the existing manual Dead Cards option.
- Before implementation: settle small-deck eligibility, destruction interactions,
  winning-hand timing, and save/reload protection against repeated destruction.

### Face Tax

- Approved concept: after each scored hand, destroy all scored face cards.
- Forecast before commitment; destruction repeats across hands, unlike Bonfire.
- Destruction is permanent even though the rule lasts only this blind.
- Before implementation: define face-status timing and interactions with face
  conversion, existing destruction effects, winning hands, and small decks.
- Preset eligibility and selection weight remain undecided.

### Bankruptcy Protection

- Approved concept: cannot gain money during this blind; spending and losses remain.
- Low-money builds can benefit from keeping their balance below a threshold.
- Unresolved: whether the window includes end-of-round payouts.
- Preset eligibility and selection weight remain undecided.

### Bad Investment

- Approved as a rare shop rule: Jokers bought here are Rental.
- Rental's $1 purchase price is part of the opportunity, not just its ongoing cost.
- Reveal Rental status and the actual price before purchase; the sticker remains
  after leaving the shop.
- Before implementation: verify price interactions and sticker compatibility.
- Exact rarity and preset eligibility remain undecided.

## Keep exploring, not yet recipes

### Steel on Stage

- Steel cards provide their held-in-hand effect when scored.
- Unresolved: additional to their held effect, or instead of it? Do not lock in
  replacement behavior that unintentionally guts existing Steel builds.
- A Mayhem lasting variant is appealing, not yet approved as a final contract.

### Borrowed Talent

- One revealed, curated Joker effect for an ante without occupying a slot.
- Investigate existing phantom Jokers as the implementation route.
- Park until lifecycle, supported effects, and interaction behavior are understood.

## Other discussion outcomes

- Second Serving: interesting but filler; not a priority flagship.
- Pocket Change and Second Wind: retain as quiet effects.
- Fresh Ink: proposed previously, but no decision recorded yet.

## Implementation boundary

Effect hooks may be small; composition, reveal, expiry, and replay still need real
contracts. Pending recipes must remain excluded from random selection. Do not
expose empty layer registrations as functioning manual options.
