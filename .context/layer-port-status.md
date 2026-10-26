# Manual layers are ported; the Clock director is not

**Integration direction:** fold this wall/layer work into existing PvP Practice,
not a separate solo path. Steam-free Practice access is a separate follow-up.
See `practice-handover.md`; the Custom Solo shell below is the current prototype.

Entry point: **CUSTOM SOLO** below the vanilla main-menu buttons.
No Steam sign-in or network server required. Choose a base, vanilla deck, stake,
optional seed and house rules. Cancelling the editor does not change live modifiers.

## Implemented in this pass

- 32 run-long manual toggles; MP-content Default/On/Off; Idol
  Default/Zealot/Collector/Both/None.
- Balance column contains Kind Wraith and Dice Patch. Dice Patch uses
  `ReworkCenter` with original keys: Oops X1.75; Lucky $20 at 1/10; 8 Ball and
  Space Joker at 1/3. Lucky's Mult roll remains 1/5.
- Six fixed resource recipes: Second Wind, Fresh Start, All In, Paid Overtime,
  Discard Dividend and Working Capital.
- Glass Cannon uses relative −2 hands, minimum one, respecting Black Deck.
- Blind Poker uses vanilla's numeric face-down denominator, not `true`.
- No Uncommons bans registered rarity-2 Jokers at setup.
- Sandbox rotation, Encore and Extra Credit groups reuse the mapping table;
  Extra Credit copies stand down when the original mod is loaded.
- Bigger Shop, Small World, resource changes and Sandbox's Idol choice are
  idempotent when MPAPI reapplies setup after loading a save.
- Shared Pockets supports both pre-area challenge setup and post-area MPAPI
  layer setup; its slot baseline no longer assumes every deck starts at 5/2.
- Polymorph's collection walk is finite even if an owned card is banned or its
  pool has no eligible replacement; transformation updates deck membership.
- Eeeee uses a private LÖVE RNG rather than reseeding global `math.random`.

## Solo is not Practice

Uses `MPAPI.create_local_lobby` only to supply ruleset context. No queue mode,
gamemode, referee, PvP boss, opponent, rating or Practice no-fail flag.
Normal win/loss and ante progression remain vanilla. Custom runs are seeded
even when their seed is generated, so they do not earn vanilla unlocks.

The selected configuration is stored in `G.GAME.pvp_solo`. Continue restores the
local ruleset/modifier context before reworks, pools and run reconstruction.
Exiting through Main Menu or New Run leaves the local lobby and clears modifiers.
Actual save/reload is covered by the live `custom_solo_save` and `dice_patch`
scenarios, including an owned Oops and its saved probability multiplier.

## Manual behavior is not temporary Clock behavior

- Manual Inflation accumulates for the run; shop-local rollback is not built.
- Manual Pricey Packs retains ante-scaled prices, not the proposed shop variant.
- Manual Polymorph keeps the collection-position behavior, not same-rarity
  first-hand incidents.
- Sandbox subgroup toggles bring their Joker replacements, not the entire
  Sandbox ruleset's consumables, tags and reworks.
- MP-content On does not invent an opponent. Opponent-only effects remain
  dependent on multiplayer; Encore's Magnet is a manual content choice.
- Glass variant layers are still empty and are not exposed.
- Pending Loaded Dice, Everybody Counts, Clearance Sale, Bonfire and the other
  shortlist concepts remain design-only, not fake functioning buttons.

## Next implementation boundary

The old per-recipe Clock rolls contradict the new budget/cadence design.
Do not transplant that scheduler unchanged.

Still needed: director selection, named-slot reservations, hidden blind-entry
reveal, forecast/skip handling, first-hand incidents, temporary ownership and
expiry, shop-local rollback, grant delivery, Clock save state, and multiplayer
replay/rejoin integration. The unresolved different-player-seed policy remains.

## Verification

- Offline contract tests exercise real layer definitions with stubbed game
  boundaries; they do not prove rendering, scoring or save-engine behavior.
- Three real-game scenarios are in `tests/scenarios/`; commands and coverage are
  in `tests/README.md`.
- Live validation on 2026-10-24: Custom Solo 19/19; save/reload 11/11; Dice Patch
  36/36. Tests use the actual game, with no rated matches.
- The accompanying MPAPI fix is required: vanilla `nil`/`false` properties must
  survive reworks; applying a variant snapshots keys before changing the center.
  A separate MPAPI contract test covers baseline restoration.
- Existing Lovely warnings remain for Practice's `_RELEASE_MODE` target, The
  Order's seed-hash target, optional Patchwork compatibility, and an excess deck
  patch match. DebugPlus's `.luarc.json` files are also reported as invalid mod
  metadata. These are outside the tested Dice Patch changes.
