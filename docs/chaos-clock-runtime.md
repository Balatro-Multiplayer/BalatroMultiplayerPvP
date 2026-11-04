# Chaos Clock lab

This is a local **Custom Solo** prototype, not the Chaos matchmaking queue.
Production cadence, forecasts, multiplayer authority and replay recording remain
unimplemented. The disabled queue tile stays disabled.

## Try it

Start Custom Solo, then open pause → **Chaos lab (debug)** at blind selection or
in a shop. Original solo options remain under **Run options**.

- Select a recipe to see its rule, window and eligibility/pending reason.
- Activate selected or random eligible; inspect active rules and remaining windows.
- Expire oldest or clear active rules. Earned cash is not reclaimed.
- Arm the scheduler stub, then advance it in explicit 10-second ticks.
  Its interval is 30 simulated seconds. It does not run in the background.
  These lab values are not the production design's event budgets.

Debug mutation is restricted to safe blind-selection/shop states. Rules already
active continue during hands. Blind rules last through round evaluation and
expire at cash-out, so their payout/interest consequences are included.
Skipping a blind does not consume the next played-blind window.

## Data ownership

```text
lib/chaos_effects.lua       definitions: rule, activation point, expiry, claims
lib/chaos_clock.lua         lifecycle + dedicated RNG + manual scheduler
G.GAME.pvp_chaos            saved instances, undo receipts, triggers, RNG, clock
overrides/chaos_clock.lua   game adapter + scoring/expiry hooks
ui/chaos_debug.lua          developer controls using the same runtime
```

Definitions contain no per-run state. Payloads cover resource deltas, modifier
values, cash grants and ongoing interpretation rules. Named event handlers cover
unusual mechanics without encoding all of Balatro in a custom data language.
The six existing manual resource layers now consume these same payloads rather
than maintaining a separate copy of their numbers.
`after_scoring` maps to SMODS's `after` context; destruction effects still need
their own timing/target contracts before using it.

Duration is either `instant` or a boundary/count pair.
Blind/shop expiry and ante-change expiry are wired to the game. Ante windows end
on any change to the saved ante, including decreases from vouchers. The director
still has no production ante scheduler. Boundary tokens prevent
repeated callbacks from decrementing saved lifetimes twice.

Activation claims prevent overlapping timed owners. Manual resource ledgers and
existing game modifiers conservatively exclude conflicting timed recipes.
Expiry subtracts actual clamped resource adjustments, preserving permanent
resource changes acquired in the meantime. Modifier receipts preserve `nil` and
`false`; cleanup does not overwrite a later writer with a different value.
Same-value external ownership cannot be detected by this prototype.

Loading an ordinary game save restores both changed game values and instances;
it must not activate the recipes again. Once-only event flags and dedicated RNG
state live in the save, not in closures. Instant outcomes persist after expiry;
expiry is not undoing gameplay.

## Catalogue

Working payloads: Second Wind, Fresh Start, All In, Paid Overtime, Discard Dividend,
Working Capital, Waste Not, Everybody Counts, Shop Subsidy, Pocket Change and Higher Calling.
Everybody Counts changes scoring membership through `SMODS.always_scores`; it
does not alter hand recognition or add an extra scoring pass.

### Higher Calling

Activate at blind selection or in a shop through the lab. It lasts for the
remainder of the current ante, survives blind/shop boundaries and save/reload,
and does not reclaim created Jokers or editions when it expires.

- Only ordinary Judgement generation (`jud` source) is changed. Soul, Wraith,
  shops, explicit rarity/identity rolls and guaranteed editions are preserved.
- Legendary: 0.5% per eligible Judgement, replacing the ordinary result. Empty
  eligible Legendary pools fall back to ordinary selection.
- Rare: 2x the current eligible baseline chance, conditional on no Legendary.
  Other ordinary rarity outcomes give up mass proportionally.
- Negative: 2.5x baseline; Polychrome: 3x baseline. These are alternatives, not
  two editions on one Joker. Plain outcomes give up probability first; only if
  exhausted do other editions give up mass proportionally. Extreme modifiers
  cap each probability and normalize the two boosted targets if their sum exceeds 1.
- Baselines use Steamodded's active rarity/edition weights and run modifiers;
  the boost acts on probabilities, not a multiplier renormalized back into weights.
  Pool bans/duplicate rules remain native. Empty ordinary pools keep the engine's
  own fallback behavior.
- Generation uses named game RNG streams, separate from director selection.
  No global rarity/edition modifiers are temporarily installed.
- The experimental Steamodded `object_weights` engine is not supported; the lab
  reports Higher Calling as ineligible under that engine rather than applying
  guessed odds. Production multiplayer/replay authority is not added here.

Live validation on 2026-11-04 with Steamodded BETA-1814a: 13 checks passed
through actual Judgement use, lab activation, a real save reconstruction and
`ease_ante` expiry. Controlled rolls verify outcomes, not observed frequencies.

Pending, inspectable, excluded from activation/random draws: Loaded Dice,
Clearance Sale, Bonfire, Face Tax, Bankruptcy Protection and Bad Investment.
Their entries record blockers rather than registering silent no-op layers.
Other POC recipes and direction-document candidates have not been migrated yet.

The clock is disabled by default. A due tick with no eligible recipe stays due
without consuming RNG; the next explicit eligible tick retries it. Selection is
currently uniform over sorted eligible keys, not the proposed preset budgets.
No wall-clock, networking or replay API is involved.

## Validation

From the PvP root:

```sh
lua tests/test_chaos_clock.lua
luajit tests/test_chaos_clock.lua
lua tests/test_mutators.lua
luajit tests/test_mutators.lua
```

The new contracts exercise the real lifecycle, adapter and debug callbacks with
game/UI boundaries stubbed. They are not proof of rendered layout, played-hand
scoring, payouts or actual disk save/load. A live scenario is supplied as
`tests/scenarios/chaos_clock.lua`; it must run with both fork checkouts installed
as the active mods. Do not run it against someone else's installed checkout or
an active multiplayer match.

The reconciled collection passed this live scenario (14 checks) with Steamodded
BETA-1814a on 2026-11-03: rendered controls, saved instances, one played hand's
scoring membership and cash-out expiry. This is not exhaustive payload, payout
or network validation.
