# Content-layer checks

From the PvP root, point these at the matching MPAPI checkout:

```sh
lua tests/test_multiplayer_content.lua /path/to/BalatroMultiplayerAPI
luajit tests/test_multiplayer_content.lua /path/to/BalatroMultiplayerAPI
```

The contract test loads the actual MPAPI composition/pool code and PvP content,
rulesets and card definitions. SMODS registration and game state are stubbed.
It checks explicit ownership, unchanged ruleset defaults, live/Practice contexts,
Default/On/Off selection, Conjoined's layer-owned bans, bespoke exclusions and
default-deny for unlisted content. It exercises the real lobby-option callbacks
and shared-metadata mirroring with a stub lobby.
It does not simulate gameplay, networking, saves or full replay.

For real pool generation in a running game:

```sh
bash /path/to/BalatroMultiplayerAPI/scripts/run_scenario.sh MultiplayerPvP:multiplayer_content
```

Both installed Mods must point at the checkouts under test. The launcher checks
this and does not retarget them. Steam registration is required; a server and
opponent are not. The scenario starts local Expanded Practice through its entry
helper, then checks real Joker/Planet pools with and without the content layer
and the Off modifier layer. Other eligible pool keys must retain their order.
It does not drive menu clicks, play a hand or test opponent interactions.
