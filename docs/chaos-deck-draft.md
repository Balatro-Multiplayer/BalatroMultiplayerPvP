# Almanac deck draft prototype

Select **Almanac** in Custom Solo's deck selector, or **Almanac** in
normal deck selection. This is a neutral carrier Back, not an initial acquisition.
The public Almanac queue remains Coming Soon. Almanac names both the deck and
the intended format; internal `chaos` IDs remain unchanged for save/replay compatibility.
Queue exclusivity and mandatory-deck enforcement are not implemented by this rename.

The neutral back uses its own blank pixel-art atlas, not Cocktail's artwork.
Regenerate both resolutions with `python3 scripts/generate_chaos_back.py`;
the standard-library generator writes 71×95 and 142×190 RGBA PNGs.

- Ante 1: ordinary starting cards and resources; zero deck effects.
- Draft only at antes 2, 3, 5 and 7, with three distinct eligible deck offers,
  independently seeded per player. No drafts at other antes, including after 7.
- Pick one; keep previous acquisitions. Four acquisitions in a normal run;
  no repeated decks. Older saves retain any extra acquisitions they already have.
- With fewer than three eligible decks remaining, offer all of them. Skip empty
  pools; later unlocks can resume drafting.
- Draft before the new ante's shop stock or blind-selection UI is constructed.
- Existing manual rules, stakes and sleeves remain separate; use Vanilla/no
  modifiers/no sleeve for the ordinary baseline.

## Cumulative unlock schedule

| First eligible ante | Decks |
|---|---|
| 2 | Red, Blue, Yellow, Green, Magic, Nebula, Zodiac, Violet, Anaglyph, Erratic |
| 3 | Black, Painted, Ghost, Checkered, Abandoned |
| 5 | Indigo, Orange, Oracle, Gradient |
| 7 | Heidelberg, Echo |

Earlier decks remain eligible. The catalogue contains 10/15/19/21 eligible decks
at these boundaries before removing acquisitions. Selection stays uniform over
eligible, unacquired decks: no premium slot or guaranteed newly unlocked deck.
Plasma remains excluded. Unlocks are declared on each acquisition as `min_ante`.

The same four milestones control draft timing; unlocks alone do not trigger
additional drafts between them. Quiet antes advance the checked-ante state so
gameplay and the PvP timer are not held waiting for a nonexistent draft.

Gates apply to newly generated offers. Existing acquisitions, saved pending offers
and exact recorded replay choices are preserved, including choices generated
before these gates existed. No save migration or reroll is needed.

## Runtime

`G.GAME.chaos_draft` holds the stable player-scoped seed, acquired deck keys,
last completed ante, pending offers and Orange's pending pack entitlement.
Offers use a local integer RNG, not gameplay's pseudorandom stream.

The picker displays deck art, acquisition descriptions, selected-effect previews
and the accumulated deck list. Click a deck to select it; click that same deck
again to acquire it (no timing threshold). Clicking a different deck changes the
selection. Click the heading to open the ordinary playing-deck inspector.
Closing an overlay does not bypass an unresolved draft.

The draw pile shows the latest eight acquired backs as cosmetic layers, newest
on top. Hover or controller focus fans them inward; new acquisitions slide into
place. Reduced motion keeps a static stagger. Extra decks get a count badge.
The ordinary deck viewer keeps its existing tabs and adds **Chaos decks**, with
six acquisitions per page. No real card transforms, draw order or gameplay RNG
are changed; the cached sprites are released when the pile/run is removed.

Acquisition adapters apply current-state changes, never `Back:apply_to_run`.
Anaglyph, Heidelberg and Echo continue receiving their native calculation hooks.
Ordinary runs have no draft state and pass through unchanged.

Save checkpoints precede selection and follow completed acquisition events.
Partial voucher/destruction processing is not saved. Orange's pack is another
transaction: interruption restores the checkpoint before opening it, not a partial
selection plus another free pack.

Live PvP records `chaos_pick` with the player seed, ante, choice and exact offers.
The POV replay applies that acquisition; opponent events do not mutate the local
deck. The local PvP timer does not charge the draft window. There is no shared
offer pool, simultaneous reveal or wait-for-opponent barrier in this prototype.
Network/rejoin and actual replay execution still require live validation.

## Acquisition semantics

All 14 vanilla decks other than Plasma, plus the seven enabled custom decks,
are supported. White is disabled upstream; Cocktail and Chaos are meta-decks,
not acquisitions. Other mods' decks need explicit adapters.

- **Red/Blue/Black/Painted:** add their resource/capacity deltas to current state.
  Black cannot be confirmed if its cost would leave fewer than one hand.
  If all remaining offers are unavailable, the picker permits passing that ante.
- **Yellow:** one-time money grant; active money rules still apply.
- **Green:** set unused-hand/discard payout rates and disable interest.
- **Magic/Nebula/Ghost/Zodiac/Oracle:** redeem unowned vouchers once and grant
  configured consumables once. Gifts can exceed tray capacity; no cards are
  evicted when capacity shrinks. Normal purchase restrictions remain.
- **Abandoned:** destroy physical Jacks, Queens and Kings through SMODS destruction,
  including destruction contexts; do not install a future face-card ban.
- **Checkered:** Clubs → Spades, Diamonds → Hearts, preserving other properties.
- **Erratic:** reroll current cards' ranks/suits; preserve enhancements/seals/editions.
- **Violet:** extra voucher offer, native calendar-ante discounts. Acquiring it in
  ante 2 gives the 30% discount; acquiring it later does not restart discounts.
- **Indigo:** extra pack choice, native skip restriction, future Red Card ban.
  An already-owned Red Card is retained.
- **Orange:** two Hanged Men and one free Giga Standard Pack.
- **Oracle:** native cap of $50 + interest cap, including clamping excess held money
  immediately. The picker explicitly warns about the loss.
- **Gradient:** enable its existing adjacent-rank interpretation hooks.
- **Heidelberg:** enable its existing shop-exit consumable-copy hook.
- **Echo:** add 0.2 to current blind scaling, then use its native retrigger and
  +0.2-per-boss hooks. This composes with existing scaling rather than resetting it.

No Clock cadence, forecast, timed mutators or balance pass is included.

## Checks

```sh
lua tests/test_chaos_draft.lua
luajit tests/test_chaos_draft.lua
lua tests/test_chaos_backs.lua
luajit tests/test_chaos_backs.lua
lua tests/test_mutators.lua
luajit tests/test_mutators.lua
```

Real-game smoke, with both installed mod links pointing at these worktrees:

```sh
bash <MPAPI-checkout>/scripts/run_scenario.sh MultiplayerPvP:chaos_draft
bash <MPAPI-checkout>/scripts/run_scenario.sh MultiplayerPvP:chaos_backs
```

`chaos_backs` supplies a nine-deck cosmetic fixture and opens the paginated native
viewer; it does not acquire or validate those decks' gameplay effects.
Optional `BMP_SCREENSHOT_DIR` captures the pile and collection into an existing
directory. Offline visual checks cover draw gating, cache cleanup, static reduced
motion, fan offsets, pagination and non-Chaos isolation, not rendered appearance.

The live scenario advances the ante as a fixture, clicks the rendered picker and
round-trips pending/completed acquisitions through the real save format. It does
not play full antes, exhaustively exercise every acquired deck, or run a network
match. Offline checks are not evidence that those workflows work in-game.

The reconciled collection passed `chaos_draft` (16 checks) and `chaos_backs`
(7 checks) with Steamodded BETA-1814a on 2026-11-03. Those results cover the
fixture-driven workflows above, not every live acquisition or network/replay path.
