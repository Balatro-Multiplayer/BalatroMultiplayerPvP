# Almanac release checklist

Record command, result and all three repository SHAs for each validation run.
Keep unit evidence separate from rendered/live multiplayer evidence.

## Extraction gate

- [x] Target diff contains only chosen features and required dependencies (source review).
- [x] Current upstream networking, recovery, tests and unrelated content retained.
- [x] No Clock scheduler, opportunity hooks or debug mutation controls loaded by Almanac.
- [x] No imported dependency on ignored files, source checkout paths or credentials (source review).
- [x] Draft/backs/identity/shared-rule tests pass in Lua and LuaJIT.
- [x] API capability tests pass; target layer-content and layer-hook tests pass.
- [x] Server typecheck, tests and build pass; bundle regenerated from target source.

Checked extraction gates record offline validation of the harvested prototype,
not proof of the live product gates below. Re-run checks after further changes.

## Product gate

- [ ] Open decisions in `v1.md` resolved and documented.
- [ ] Same three eligible deck offers, excluding acquisitions owned by either
  player; independent picks, all four milestones.
- [ ] Acquisition save/load is exactly-once; reconnect never regenerates offers.
- [ ] Each player receives their own four-rule boss offer.
- [ ] Both lock orderings, timeout, duplicate picks and identical reveal.
- [ ] Every PvP from ante 3 drafts rules, including multiple encounters in one ante.
- [ ] Every shipping boss rule exercised in played hands.
- [ ] Cleanup preserves unrelated effects and permanent consequences.
- [ ] Disconnect before pick, after pick and after resolution; host migration.
- [ ] Actual replay and crash/rejoin during draft and encounter.
- [ ] Required deck and Expanded Ranked baseline enforced by competitive mode,
  except for Almanac's intended differences.
- [ ] Other competitive queues reject Almanac; practice remains available.
- [ ] Forecast and status communicate the approved information.
- [ ] Full two-player entry → match → result → rematch.
- [ ] Controller, reduced motion, localization and rendered layout.
- [ ] Played-match balance review; any scaling change explicitly justified.

Queue activation and deployment require separate authorization.

## Current implementation evidence (offline only)

Product boxes above remain unchecked until their live checks pass.

- Server-owned shared deck offers and both acquisition histories; the next
  milestone waits for both previous picks and excludes their union.
- Client request/ack retries; committed choices apply through the existing
  acquisition/save barrier. Solo practice and local replay retain local drafting.
- One four-rule boss offer per player; encounter identity uses run + PvP
  round ID. Retired IDs reject delayed opens, offers and resolutions.
- Almanac enables boss drafts without the private prototype switch.
- Schedule/status forecast in the Almanac pause menu; English localization keys.
- Requires `almanac_draft = 1` and `shared_pvp_rules = 2` server capabilities.
  API snapshot tests cover both. Server bundle regenerated.
- The five-stake update below resolves pre-run stake selection. Full competitive
  baseline enforcement/validation remains outstanding. The queue remains a
  non-interactive Coming Soon preview.

### Validation record

Base SHAs, each with this worktree's uncommitted changes:

| Repository | Base SHA |
| --- | --- |
| PvP | `64054bad88888bd52557bd142b95c2d618027d92` |
| API | `93328c8c865bace3a6c57cc96e30fd9ac07bc2d7` |
| Server | `3540d5f05c3e347e2080f3205e13f99fc34dbc5d` |

Commands run from the relevant repository root. `MPAPI_DIR` names this thread's
API checkout **with a trailing slash**; `SERVER_DIR` names its Server checkout.

| Command | Result |
| --- | --- |
| `lua tests/test_almanac_{backs,contract,draft,identity}.lua` and `lua tests/test_shared_rules.lua` (each file separately) | 28 / 37 / 1,886 / 20 / 94 checks passed |
| Same five files under `luajit` | Same checks passed |
| `luajit tests/unit/*_test.lua` (each file separately) | All 32 files passed; `score_test.lua` needed the path redirect below |
| API: `luajit tests/*.lua` (each file separately) | All 20 files passed |
| API: `lua tests/test_server_features.lua` | 4 checks passed |
| `corepack pnpm --dir nakama typecheck` | Passed |
| `corepack pnpm --dir nakama test --reporter=dot` | 80 files / 915 tests passed |
| `corepack pnpm --dir nakama build` | Passed; regenerated `nakama/modules/index.js` |
| StyLua on changed Lua implementation/test files; Biome on Almanac and shared-rule server modules/tests | Passed |
| `git diff --check` in all three repositories | Passed |

The score test hard-codes `../BalatroMultiplayerAPI/lib/big_score.lua`.
It passed with that `dofile` path redirected to `MPAPI_DIR`; source unchanged.
The initial broad Lua 5.4 run also hit existing harness incompatibilities:
`draft_board_test.lua` uses global `unpack`; API's `ban_pick_tooltip_test.lua`
uses `loadstring`. Both pass unchanged under LuaJIT.

No played-hand, rendered UI, real replay/crash-rejoin, host-migration network or
two-player end-to-end validation was run. No queue activated or deployment made.

### Five-stake draft update

The preceding draft/forecast work was committed before this update:

| Repository | Commit / validation base |
| --- | --- |
| PvP | `22b0c8f8a6b0600bedb79c706fdd9b1275faea75` |
| API | `1ed26ac7c33c896acb7b29d10fc975f2dd9d6aae` |
| Server | `9e4573d44c33d05c7fc86d60c63bfcbdf0260a43` |

This update remains uncommitted. API source is unchanged.

- Five fixed-deck stake tiles: White / White-, Green, Black, Purple, Gold /
  Spectral+. Two independent 50% replacements, rolled once when proposing the
  setup pool; the existing server Setup retains the exact offers and result.
- Three alternating single bans, then the second actor picks from the final
  two; the server still randomizes who is first.
- White- is appended to the stake registry, not inserted above White. It
  inherits only White and grants the two real vouchers through queued effects,
  once per fresh run. Existing ownership is respected.
- Almanac composes Expanded's actual layer chain and pins its carrier deck/no
  sleeve. Private Nemesis Lobby Options exposes it for two-player validation; missing
  server capabilities and incompatible stake caps fail before starting.
- The live ranked queue remains disabled. Lives, modifiers and all other
  competitive baseline settings still need an enforcement audit and live checks.

Validation at the bases above plus these working changes:

| Command | Result |
| --- | --- |
| `lua tests/test_almanac_setup.lua` and `luajit tests/test_almanac_setup.lua`, with `MPAPI_DIR` | 265 checks each; all four replacement combinations and boundaries, real setup/run-start wiring, voucher duplication and stale-event guards |
| All `tests/test_almanac_*.lua` and `tests/test_shared_rules.lua`, separately under Lua and LuaJIT | Passed |
| All 32 `tests/unit/*_test.lua`, separately under LuaJIT | Passed; same score-test path redirect noted above |
| API: `lua tests/test_server_features.lua` and `luajit tests/test_server_features.lua` | 4 checks each |
| `corepack pnpm --dir nakama typecheck` | Passed |
| `corepack pnpm --dir nakama test --reporter=dot` | 80 files / 916 tests passed; new setup test exercises all four five-stake pools through checkpoint, host change, bans, pick and reseed |
| `corepack pnpm --dir nakama build` | Passed; runtime bundle unchanged |

Still no rendered or played two-player evidence for the draft or White-.
