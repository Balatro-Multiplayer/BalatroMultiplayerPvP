# Chaos: shared PvP rules — v1 pseudospec

Design contract; private-match prototype now implemented, not live-validated.
Choose conditions both builds must withstand.
Deck-building remains the primary progression.

## Selection

```text
WHEN both players ready for PvP:
  IF encounter ante < 3:
    start PvP normally
    return

  eligible = rules unlocked at encounter ante
  privately offer each player 3 distinct eligible rules
  start shared 10-second deadline

  each player locks 1 choice
  timeout without choice → random rule from that player's offer
  hide choices until both resolve

  IF choices differ:
    rules = both choices
  ELSE:
    rules = chosen rule
          + random eligible rule excluding chosen rule

  reveal rules
  apply both rules to both players
  start PvP
```

- No preparation shop between reveal and combat.
- No pair exclusions, including multiple suit debuffs, suit + Plant, or
  Manacle + Psychic with fewer than five available cards.
- No duplicate stacking; no build-dependent protection.
- Timeout/wildcard draws use match-owned deterministic RNG.
- Persist offers, locked choices and resolution; rejoin must not reroll them.
- These abilities modify the existing PvP blind, not its target, scoring contest
  or win/loss logic.

## Pool

| Rule | Earliest ante | Effect on each player during this PvP encounter |
|---|---:|---|
| Manacle | 3 | -1 hand size. |
| Psychic | 3 | Must play exactly five cards; not all need to score. |
| House | 3 | Initial hand drawn face down. |
| Club | 3 | Clubs debuffed. |
| Goad | 3 | Spades debuffed. |
| Window | 3 | Diamonds debuffed. |
| Head | 3 | Hearts debuffed. |
| Glass Cannon | 3 | -2 hands, minimum one; X4 Mult. |
| Tooth | 3 | Lose $1 per card played. |
| Arm | 3 | Played hand loses one level before scoring, minimum level 1. |
| Verdant Leaf | 4 | Playing cards debuffed until that player sells a Joker. |
| Hook | 5 | After each played hand, discard two random held cards. |
| Plant | 5 | Face cards debuffed. |
| Water | 5 | Start the encounter with zero discards. |

Verdant Leaf uses the vanilla condition, not a mandatory pre-combat sale.
Each player clears their own debuff. Glass Cannon adjusts available hands
before play begins.

## Expiry

```text
WHEN encounter ends:
  remove temporary rules and their resource adjustments
  preserve unrelated acquisitions and permanent gains
  do not refund money lost, levels lost, Jokers sold,
    or other actual gameplay consequences
```

## Not v1

- Needle is excluded entirely; the last-life easter egg was dropped.
- Eye, Flint, Mouth, Wheel, Fish, Mark, Bell, Crimson Heart, Ox,
  Amber Acorn, Wall and Vessel are excluded.
- Serpent is shortlisted for a later round.
- No permanent or ante-wide shared-rule durations in v1.

Implementation contract and remaining validation:
[shared PvP rules](../../docs/shared-pvp-rules.md).
