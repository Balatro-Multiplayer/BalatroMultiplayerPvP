# Chaos: Clock events

Secondary pressure: change the situation around the deck being assembled.
Recognizable Balatro; unfamiliar opportunities; occasional lasting damage.
Not automatic escalation until money, slots and hand choice stop mattering.

## Intended rules

```text
DIRECTOR:
  select eligible effects within a shared cadence/event budget
  adding effects increases variety, not event frequency
  leave quiet stretches

EFFECT:
  announce what changes, its window and permanent consequences
  activate at the specified gameplay boundary
  expire the rule at its stated boundary
  retain outcomes earned or suffered while it was active
```

- Windows may be a shop, blind, ante, or explicitly the rest of the run.
- Forecasts can create preparation/skip decisions; exact reveal cadence remains
  unresolved. Never conceal an active rule's actual behavior.
- Mystery belongs in arrival, outcome and combinations, not undisclosed costs.
- Deck acquisition defines identity; events should create reasons to use,
  redirect or protect that identity.
- Shared chosen PvP rules are a separate mechanic, not random Clock events.

## Implemented local lab, not production behavior

```text
Custom Solo → Options → Chaos lab (debug)
  activate selected/random eligible effect
  inspect / expire oldest / clear
  arm scheduler stub; advance in explicit 10-second ticks
```

- Ten executable recipes: Second Wind, Fresh Start, All In, Paid Overtime,
  Discard Dividend, Working Capital, Waste Not, Everybody Counts,
  Shop Subsidy and Pocket Change.
- Saved instances, conflict claims, expiry receipts and dedicated selection RNG.
- Blind rules survive payout evaluation and expire at cash-out.
- Scheduler is off by default; 30 simulated seconds per event, manual ticks only.
  These are lab values, not agreed production cadence.
- Pending: Loaded Dice, Clearance Sale, Bonfire, Face Tax, Bankruptcy Protection
  and Bad Investment; excluded from activation/random selection.
- Higher Calling, Cross-Pollination, Breakage Insurance, Negative Space,
  Destruction and Sandbox windows remain design candidates.

Still needed: production director/budgets, forecasts/HUD, broader payloads,
ante lifecycle and multiplayer authority/replay/rejoin. The public Chaos queue
remains Coming Soon.

Implementation reference: [Clock lab](../../docs/chaos-clock-runtime.md).
