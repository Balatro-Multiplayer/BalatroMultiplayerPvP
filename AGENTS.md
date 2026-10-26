# AGENTS.md

Orientation for coding agents. Player-facing overview and folder map: README.md. Setup, StyLua and PR flow: CONTRIBUTING.md.

## What this is

PvP Balatro mod (manifest `MultiplayerPvP.json`: id `MultiplayerPvP`, prefix `mp`, global `PVP` = `SMODS.current_mod`) running on MultiplayerAPI (global `MPAPI`, hard dependency, loads first). MPAPI owns connection, auth, lobbies, matchmaking, ratings, replays, spectating, menus host and The Order RNG. PvP supplies content, rules and the in-match protocol. Old monolith (mod id `Multiplayer`, own TCP client) is on the `legacy` branch; anything describing raw sockets, `Client` talking to a server, or Showdown/Survival gamemodes is from there.

## Loading

- `core.lua` loads `lib` → `overrides` → `compatibility` → `networking` → `gamemodes` → `layers` → `rulesets` → `ui` → `objects/*` via `PVP.load_mp_dir`. Within a dir, `_`-prefixed entries load first; use that for files siblings depend on at load time.
- `pvp_api/` loads inside `MPAPI.on_loaded`, so its GameObjects (GameModes, ActionTypes) are tagged with this mod's id; per-lobby routing filters on that id. Register API-side objects there. `on_loaded` only fires once MPAPI has a signed-in (Steam) session.
- `SMODS.GameObject` validates `required_params` in the constructor, not in `inject()`; fields must be on the init table before construction.

## Keys

- Rulesets and gamemodes take short keys; `PVP.Ruleset`/`PVP.Gamemode` add `ruleset_mp_`/`gamemode_mp_` and set `prefix_config.key = false`. Code everywhere else uses the full key.
- ActionTypes keep the literal `pvp_*` key (`prefix_config.key = false`, see `pvp_api/actions/_helpers.lua`); otherwise SMODS makes it `mp_pvp_*` and every lookup misses.
- Match-format keys in `PVP.PVP_GAMEMODES` (`pvp_nemesis`, `pvp_royale`, ...) and ranked tickets `pvp_ranked_<ruleset short>` are a contract with the server and web leaderboard. Change them only together with BalatroMultiplayerServer.
- The Draft runs on the server as a Setup step (`MPAPI.Setup`, ADR 0003). The server keeps the drafted stake for a restart; PvP writes no metadata key for it. The Setup step ids (`ruleset`, `traps`, `draft`) live in `pvp_api/setup.lua`.

## Network model

- Every client simulates the whole run from the shared seed; Balatro's per-slot RNG queues keep shops/packs in sync despite divergent choices. Only match state (scores, hands, lives, ready, outcomes) crosses the wire.
- Legacy call sites still emit `Client.send({action = ...})` (`networking/action_handlers.lua`); `pvp_api/net.lua` overrides it to broadcast the equivalent `pvp_*` ActionType. Inbound actions route back through `PVP.dispatch_action` into the old `PVP.ACTIONS.*` handlers.
- Broadcasts loop back to the sender. Relay actions: the sender ignores its own copy (`from == self`). Authoritative actions: the host computes the outcome in `pvp_api/referee.lua` (no-op on non-hosts) and everyone, host included, applies the broadcast.
- In server-refereed lobbies (`MPAPI.has_server_referee(lobby)`) start gating and results are the server's: every client reports placements via `lobby:report_result`, and the server rates them. Ranked is exactly 2 players because server-side result/forfeit handling assumes it.
- Act only on PvP's own lobby (`MPAPI.get_current_lobby().mod_id == PVP.id`).

## Session isolation

PvP's overrides, Lovely patches and layer hooks fire in vanilla runs and other mods' lobbies too. Gate PvP behaviour on `PVP.in_session()` (live lobby or practice) / `PVP.is_mp_or_practice()`. Practice mode is a client-only local lobby with no `PVP.LOBBY.code`; its ruleset is `PVP.SP.ruleset`. Card-pool isolation is `MPAPI.register_mod_isolation` in `layers/_layers.lua`.

## Formats, gamemodes, rulesets, layers

- Match formats (Nemesis, Small World, Royale, Manhunt, Teams, Experimental) are bridge `MPAPI.GameMode`s in `pvp_api/gamemodes.lua`, each mapping to a default ruleset plus a shape flag. Nemesis at 2 players is the plain 1v1; there is no separate 1v1 shape.
- `gamemodes/` holds blind-selection profiles (only Attrition: boss becomes `bl_mp_nemesis` from `pvp_start_round`). PvP drives blinds itself, so bridge GameModes return nothing from `get_blinds_by_ante`.
- Rulesets (`rulesets/`) are a few lines composing layers (`MPAPI.Layer`, `layers/`) plus overrides. Merge, left to right: `banned_*`/`reworked_*` arrays union; scalars last-wins; ruleset beats layers; modifiers beat the ruleset.
- Read the active ruleset only through `PVP.current_ruleset()` (folds in modifiers, safe with no ruleset). Gate on layers with `PVP.is_layer_active(name)`. `PVP.active_layer_chain()` stays PvP-owned (not MPAPI's) because it adds the ruleset's short name and knows practice mode; it dedups because layer hooks are not idempotent (Small World's cull would re-cull).
- Modifiers live in `MPAPI.MODIFIERS`, chosen by the host in Lobby Options or by the player in practice, plus a ruleset's `default_modifiers`. They are resolved at read time, never written onto the ruleset.
- Bans come from ruleset, gamemode and deck, merged by `MPAPI.ApplyBans`; layers react in `calculate(self, context)` on `context.apply_bans`. `banned_silent` hides a ban from the UI (vanilla counterparts of reworks).
- `force_lobby_options` returning `true` locks the host's options; `false` applies soft defaults. `forced_gamemode` skips the gamemode picker.

## Reworking cards

- Jokers: write a new card with a new key (`SMODS.Joker`), add the vanilla key to the layer's `banned_silent` and the new key to `reworked_jokers`. Listing it auto-attaches pool gating (`mp_include`); hand-write `mp_include` only for bespoke logic. Reason: mutating a joker's center after the shop pool has indexed it desyncs clients.
- Enhancements, consumables, tags, vouchers, blinds, stakes: `PVP.ReworkCenter(key, { layers = ..., config = ... })` patches in place. For these, `reworked_*` layer entries are display-only; the `ReworkCenter` call does the work.

## Other subsystems

- Scores are `PVP.INSANE_INT` big numbers; send them as `PVP.INSANE_INT.to_string(...)`.
- Replays: `PVP.RLOG` aliases `MPAPI.replay`; record gameplay opcodes with `PVP.RLOG.record`. Playback, rejoin (`lib/rejoin.lua`) and spectating (`pvp_api/spectate_feed.lua`) all reuse `lib/playback_*.lua`. Spectators never run participant ActionTypes.
- `.env` (copy `.env.example`, gitignored) overrides `PVP.EXPERIMENTAL` flags locally.

## Testing

No unit-test suite here; verify in real game instances. A live-instance control harness (ClaudeControl / `cctl`) can launch several clients, drive menus, evaluate Lua and run scripted multiplayer scenarios. Check what a scripted test actually exercises before trusting it; prefer driving the real UI over calling internals. Point test clients at a local or dev server; real matches and results on production affect real players' ratings.

## Code style

1. Self-describing names and structure; comments only for a non-obvious *why*, not history or what the code does.
2. Structure as namespace: the folder and file say what a thing is (`pvp_api/actions/ready.lua`); keep module-level state on one table per concern.
3. One responsibility per function and file.
4. Depend on contracts: PvP code talks to MPAPI and its own helpers, not to transports, sockets or another mod's internals.
5. At I/O boundaries (network callbacks, file reads, `pcall`) return `ok, value_or_err` / `nil, err` and handle it at the call site; don't let errors escape silently.
6. No stringly-typed domain concepts: put keys and enums in one named table (`PVP.LobbyAccess`, `PVP.GamemodeKey`, `PVP.LayerKey`) and reference that.
7. Keep pure computation (pairing, score comparison, ban merging) separate from effects (broadcasts, `G` mutation, UI) so it can be reasoned about and reused.

Formatting: StyLua (`stylua.toml`: tabs, width 120, double quotes); run `stylua .` before committing. User-facing strings go through `localize()` with entries in `localization/en-us.lua`.
