# Manual mutators and Custom Solo

## Explicit multiplayer content

From the PvP root, point the content contracts at the matching MPAPI checkout:

```sh
lua tests/test_multiplayer_content.lua /path/to/BalatroMultiplayerAPI
luajit tests/test_multiplayer_content.lua /path/to/BalatroMultiplayerAPI
bash /path/to/BalatroMultiplayerAPI/scripts/run_scenario.sh MultiplayerPvP:multiplayer_content
```

The contracts load the real composition, pool gating, lobby callbacks and replay
bootstrap with stubbed game/network boundaries. The live scenario starts local
Expanded Practice and checks real Joker/Planet pools, not menu clicks, hand play
or opponent interactions. It requires Steam registration and both installed Mods
to point at the checkouts under test. The launcher does not retarget them.

## Manual mutator checks

Offline contracts (not a substitute for the real game):

```sh
lua tests/test_mutators.lua
luajit tests/test_mutators.lua
```

Real-game scenarios require MultiplayerAPI's scenario runner (`c677a0a` or later).
Dice Patch also requires the accompanying MPAPI `ReworkCenter` baseline fix:
restore absent hooks as `nil`, preserve `false`, and snapshot keys before applying
properties. The runner commit alone does not include that fix.
Install both checkouts as the active mods; the launcher checks their paths.
From this PvP checkout, with Balatro closed:

```sh
bash <MPAPI-checkout>/scripts/run_scenario.sh MultiplayerPvP:custom_solo
bash <MPAPI-checkout>/scripts/run_scenario.sh MultiplayerPvP:custom_solo_save
bash <MPAPI-checkout>/scripts/run_scenario.sh MultiplayerPvP:dice_patch
```

- `custom_solo`: rendered wall, real effect-button clicks, Black Deck + Glass
  Cannon, No Uncommons, actual face-down draw, normal loss, session cleanup.
  Deck/seed are fixture inputs; the scenario uses the real Play button.
- `custom_solo_save`: actual `save_run` serialization and `Game:start_run`
  restoration during a hand; resource deltas, Bigger Shop and Small World must
  remain unchanged; Dice Patch must remain active. Starts its fixture through
  `PVP.SOLO.start`, not the wall.
- `dice_patch`: real Balance wall and Play button; native card methods with
  controlled rolls for Lucky money, Space Joker and 8 Ball; Tarot delivery,
  Oops stacking/removal, tooltip values, save/reload with an owned Oops, and
  original odds/hooks restored in a subsequent ordinary vanilla run. The card
  fixtures are explicitly created, not bought from a shop; this is not a full
  scoring-animation or observed-frequency test.
- Neither scenario proves every effect's scoring, purchases, payouts or
  multiplayer/replay parity. Test those in live runs before release.

The launcher must not be run against production matches. These scenarios use
client-only local lobbies and need neither Steam registration nor a server.

Live validation on 2026-10-24: `custom_solo` 19/19, `custom_solo_save` 11/11,
`dice_patch` 36/36. Tested against the installed Steamodded BETA-1620a and both
worktrees, including the MPAPI baseline fix.
