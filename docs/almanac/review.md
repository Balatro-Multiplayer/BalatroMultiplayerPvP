# almanac-v1: reading guide

The game mode is in `v1.md` and the remaining work in `release-checklist.md`. This file maps the code.

The branch is `almanac-v1` in three repos: PvP (this one, ~4.3k lines, mostly tests), Server (~1.5k lines including the regenerated bundle: `nakama/src/lobby/almanac.ts`, `shared_rules.ts`), and API (19 lines: `lobby.server_features` from the snapshot's `serverFeatures`).

The server owns every decision: deck offers, both players' acquisition histories, rule offers and picks, the 10 s deadline, timeout rolls and resolution. The host only asks for a rule draft to start. Clients apply results and never send offers or their own history. Push back on any change that lets a client decide something.

## Reading order

1. **Entry.** `rulesets/zz_almanac.lua` appends `layers/almanac.lua` to Expanded's `_layer_order`. The layer pins `b_mp_almanac` and turns off sleeves and challenges. `PVP.pvp_start_match` (`pvp_api/flow.lua`) refuses anything except two players in a Nemesis lobby on a server with `almanac_draft = 1` and `shared_pvp_rules = 2`.
2. **Stake draft.** `lib/draft.lua` (`almanac_board`, `almanac_tile_order`) is switched on in `pvp_api/actions/run_lifecycle.lua`. The stakes are in `objects/stakes/` (`00_planet`, `01_spectral`, `02_spectralplus`, `zz_white_minus`) and White-'s vouchers are in `overrides/white_minus.lua`.
3. **Deck draft.** `lib/almanac/draft.lua`. `D.definitions` hand-codes each deck because `Back:apply_to_run` only works at setup. `D.commit` records a pick before applying it, `state.busy` holds `save_run` until the pick has applied, and Orange's Giga pack has its own `pack_due` → `pack_active` checkpoint. Online polling is in `pvp_api/actions/almanac.lua` and the shop/blind-select gate is in `overrides/almanac_draft.lua`.
4. **Shared rules.** `lib/almanac/shared_rules.lua` defines the rules as Blind-shaped hooks and `shared_rules_round.lua` defines `R.Round` (`resolved` → `active` → `finished`). Dispatch is in `overrides/shared_pvp_rules.lua`. `pvp_api/referee.lua` `start_blind_2p` sends `pvp_rules_open` in place of `pvp_start_blind` from ante 3.
5. **Recovery.** `pvp_api/lobby_bridge.lua` calls `SHARED_RULES.sync()`. `lib/almanac/draft_replay.lua` and `shared_rules_replay.lua` replay the POV player's picks.
6. **UI.** `ui/almanac_draft.lua` (offer), `ui/almanac_backs.lua` (cosmetic back fan), `ui/almanac_forecast.lua` (pause menu), `ui/game/timer.lua` (pauses during drafts), `ui/main_menu/find_game.lua` (Coming Soon preview, no queue).

## Where to push

- **Catalogue copies.** Deck and rule antes exist in both the client (`D.definitions`, `R.definitions`) and the server (`DECK_ANTES`, `RULE_ANTES`). Only `tests/test_almanac_contract.lua` keeps them aligned.
- **Hand-coded decks.** Abandoned, Erratic and Checkered destroy or rewrite cards. Anaglyph, Heidelberg and Echo run every round through `D.calculate`. These need a check against the real deck config.
- **Detection.** Server `isAlmanac` and client `R.enabled` trust lobby metadata the host can edit. Move this to `rankedMode` before a queue exists.
- **Soft lock.** If the server never answers, the draft gate leaves the run on the "waiting" overlay.
- **Prototype toggle.** Lobby Options keeps "Shared PvP rules (prototype)" for non-Almanac private lobbies. Ship it or remove it.

## Running it

- **Offline:** run `lua` and `luajit` on `tests/test_almanac_*.lua` and `tests/test_shared_rules.lua`. The contract test needs `SERVER_DIR`; the setup test needs `MPAPI_DIR` with a trailing slash. Also `luajit tests/unit/draft_board_test.lua` and `ready_check_referee_test.lua`.
- **Server:** `corepack pnpm --dir nakama typecheck`, then `test`, then `build`.
- **Live:** `bash scripts/run_pair.sh pair_almanac` runs two real clients through the lobby, the stake draft, the ante-2 and ante-3 deck drafts, the rule reveal and two PvP blinds. `pair_almanac_stakes` takes `BMP_STAKE_VARIANT=planet|spectral|neither`. See `tests/scenarios/pair.md`.
- **Not covered live:** reconnect, replay, host migration, rule timeouts, matching picks, rule effects in play, antes 5 and 7, rematch and rendered layout. The product gate in `release-checklist.md` stays open until these are covered.

**Out of scope:** the queue (`pvp_ranked_almanac` exists, but nothing feeds it), baseline enforcement, rejecting Almanac in other queues, and ante scaling.
