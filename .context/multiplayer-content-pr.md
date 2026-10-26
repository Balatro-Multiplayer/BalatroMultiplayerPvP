# PR draft: refactor(content): extract multiplayer content into an explicit layer

### Why

Multiplayer content should be something a ruleset explicitly composes, not something admitted because the multiplayer-content flag is enabled. The old mod-wide fallback also admitted newly registered PvP cards that forgot to declare a layer.

### What this does

- Give the nine original MP Jokers, Asteroid and Manhunt vouchers an explicit `multiplayer_content` layer; compose it into applicable rulesets while retaining their flags and bans.
- Default-deny unowned PvP content. MPAPI generates inclusion gates from `included_*` membership instead of treating originals as reworks.
- Add Default / On / Off to private-lobby options: follow the base ruleset, explicitly add the pack (including Vanilla), or suppress inherited content. The choice lives in modifier layers, not an independent lobby boolean.
- Preserve the choice through shared metadata and replay/rejoin bootstrap; import legacy booleans only at the boundary. Fresh ranked queues use their ruleset defaults.
- Move Conjoined's Sandbox restriction into the Sandbox layer's bans. Magnet remains retired; no opponent-interaction logic changes.

### Test plan

- [x] `lua tests/test_multiplayer_content.lua <MPAPI checkout>` and the same command with `luajit`: 505 checks each.
- [x] Companion API: `lua tests/test_layer_content.lua` and `luajit tests/test_layer_content.lua`: 60 checks each.
- [x] Whitespace checks pass in both repos.
- [ ] Real game: `bash <MPAPI checkout>/scripts/run_scenario.sh MultiplayerPvP:multiplayer_content`. Launch currently refused because installed Mods point at another fork; no symlinks changed.
- [ ] Verify private-lobby rendering and a two-client selection change; play through replay/rejoin. Contract tests use stubbed game/lobby boundaries, not real networking or full playback.

## Companion MPAPI PR body

### Why

Layers can declare reworks but could not own original content without calling it a rework. Missing membership warnings also only recognized MPAPI's own key prefixes.

### What this does

- Index and compose `included_*` lists through the existing registration and pool-gating machinery.
- Support a layer-owned `pool_enabled` resolver for consumer-specific contexts such as local Practice.
- Warn for unlisted content from any registered isolated mod, regardless of prefix. Do not evaluate runtime isolation gates at registration or change another mod's eligibility policy.

### Test plan

- [x] Lua and LuaJIT: 60 layer-content contract checks each.
- [ ] Run the companion PvP live pool scenario after installing the matching checkouts.

## Parent handoff — not part of the PR body

Pull BOTH worktrees from this review subthread. These changes depend on the companion API extension.
All changes are uncommitted; no push or landing was performed. This file is a temporary draft for the parent agent, not intended for inclusion in the shipped change.
Magnet stays retired. Conjoined now uses an ordinary Sandbox ban rather than a custom pool exclusion, so normal banned-slot semantics apply.
