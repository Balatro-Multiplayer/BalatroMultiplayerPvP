# One of Each

Only the leftmost played card of each rank can score this blind.

- Poker-hand recognition is unchanged: Flush Five remains Flush Five.
- The first card claims its rank even when debuffed or otherwise unable to score.
- Stone and other rankless cards are exempt and do not claim a rank.
- Splash and Everybody Counts cannot restore excluded duplicates.
- The surviving card can retrigger normally; this is not a retrigger ban.
- Discarding, held-in-hand effects and Joker-wide scoring are unchanged.

Implemented as a local Custom Solo lab recipe, ending at cash-out like other
one-blind recipes. Activate at blind selection through Options → Chaos lab.
The shared PvP rule picker and network activation are not implemented here.

The hook uses SMODS.never_scores, after poker-hand recognition. Offline coverage:
`lua tests/test_one_of_each.lua` and `luajit tests/test_one_of_each.lua`.
Actual Flush Five/Idol scoring and UI presentation still need live validation.

One Take (scoring cards cannot retrigger) remains a design candidate, not implemented.
