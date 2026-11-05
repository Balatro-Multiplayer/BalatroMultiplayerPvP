# Almanac harvest handoff

Preparation only. Do not implement unresolved gameplay decisions, enable the
queue, push, deploy or merge to main. The next assignment is selective extraction.

## Pinned repositories

| Repository | Complete collection snapshot | Clean integration base |
|---|---|---|
| BalatroMultiplayerPvP | `8dbe7db01b650127f45245ed0fdcca29b54298e8` | `3777ba63f3db1e32b459483c38b57ad6e9ceb17c` |
| BalatroMultiplayerAPI | `549eb1578715c831a3b320d60fdf53d65f292d93` | `1996fc56217bf0d9bc3da9642dcf792de46d8c79` |
| BalatroMultiplayerServer | `7ae9638a63b43ef86b36fbfc3ab9f2a23dbab9d1` | `92ff9287692db7fc944d8f6fd204c690fa4ca6db` |

Bases are the locally recorded `origin/main` revisions at preparation time.
No fetch or cross-repository compatibility claim is implied.

Each repo has `archive/chaos-collection-pre-harvest` at its snapshot, `chaos-lab`
preserving the collection, and `almanac-v1` at its clean base. PvP's release branch
also receives a docs-only preparation commit. The lab subsequently reorganizes
docs; gameplay at the snapshot remains the source of truth for extraction.

All then-uncommitted tracked/untracked project changes are committed. All 13 PvP
`.context` notes are committed at the snapshot and copied byte-for-byte by moves
to `docs/history/chaos-collection` on the prepared lab branch. Three of those
notes were previously ignored. No API/server `.context` notes were present.
The ignored `scripts/local-balatro.sh` remains local-only: it contains a stale
absolute API checkout path, is not a source dependency and must not be used by
the harvester. No local credentials, dependencies or build caches are handoff inputs.

## Starting a harvest subthread

1. Attach/fork all three repositories. Work only in that subthread's worktrees.
2. Read `v1.md`, `implementation.md`, this file and `release-checklist.md`.
3. Verify every pinned source and base exists with `git cat-file -e <sha>^{commit}`.
   Do not assume local branch refs were replicated. If a source object is absent,
   stop and request its transfer; never substitute another checkout's filesystem.
4. Require a clean working tree. Use existing `almanac-v1`, or create a local
   branch from its pinned base when refs are absent. Preserve these preparation
   docs in the PvP target before editing code.
5. Read source files with `git show <snapshot>:<path>` and compare with the target.
   Source docs at the snapshot retain old paths; moved historical notes on the lab
   are byte-identical. No `.context` or uncommitted parent context is required.
6. Apply feature hunks, not whole-file restores of shared infrastructure.
7. Commit logical extraction units locally, recording dependencies and tests.
8. Report exact revisions, remaining product gaps and validation evidence.
   Do not claim the harvested prototype is a completed competitive mode.

## Inventory / disposition

Paths below are relative to the named repository. A listed integration file is
not permission to overwrite that file. Preserve newer upstream behavior.

### PvP: keep

| Unit | Source paths | Dependencies / extraction notes |
|---|---|---|
| Draft engine and adapters | `lib/chaos_draft.lua`, `overrides/chaos_draft.lua`, `lib/chaos_draft_replay.lua` | Native deck centers, game state construction, save checkpoints, replay queue and timer gating; preserve stable IDs |
| Almanac carrier | `objects/decks/03_chaos.lua`, `assets/1x/chaos_back.png`, `assets/2x/chaos_back.png`, `scripts/generate_chaos_back.py` | Explicit carrier, not arbitrary Back setup during a run |
| Draft UI / acquired backs | `ui/chaos_draft.lua`, `ui/chaos_backs.lua` | Native deck inspector, controller/reduced motion; localization hunks only |
| Draft evidence | `tests/test_chaos_draft.lua`, `tests/test_chaos_backs.lua`, `tests/test_almanac_identity.lua`, `tests/scenarios/chaos_draft.lua`, `tests/scenarios/chaos_backs.lua` | Adapt fixtures to target; identity test currently assumes prototype menu shape |
| Shared rule model/hooks | `lib/shared_pvp_rules.lua`, `overrides/shared_pvp_rules.lua`, `lib/shared_rules_replay.lua` | Native immunity arbitration, own temporary adjustments, preserve consequences |
| Shared rule actions/UI | `pvp_api/actions/shared_rules.lua`, `ui/shared_pvp_rules.lua`, `tests/test_shared_rules.lua` | Matching API/server changes required |
| Shared integration hunks | `core.lua`, `pvp_api/actions/blind_handshake.lua`, `pvp_api/flow.lua`, `pvp_api/lobby_bridge.lua`, `pvp_api/referee.lua`, `ui/game/timer.lua`, `ui/lobby/lobby_options.lua` | Port readiness, capability, rejoin and config hooks into current architecture |
| Identity integration hunks | `localization/en-us.lua`, `ui/main_menu/find_game.lua`, `ui/main_menu/custom_solo.lua` | Disabled Ranked preview only; do not enable matchmaking |

### PvP: lab-only additions

- `lib/chaos_clock.lua`, `lib/chaos_effects.lua`, `overrides/chaos_clock.lua`,
  `ui/chaos_debug.lua`: temporary-effect runtime and manual scheduler.
- `lib/chaos_higher_calling.lua`, `overrides/chaos_higher_calling.lua`,
  `ui/higher_calling.lua`, `assets/shaders/higher_calling.fs`: opportunity experiment.
- `overrides/chaos_one_of_each.lua`: scoring experiment.
- `ui/chaos_status.lua`: current opportunity status inspector, not the required
  multiplayer forecast; reuse presentation ideas only if useful.
- `layers/resource_mutators.lua`, `layers/sandbox_mutators.lua`,
  `layers/zz_mutator_catalogue.lua`, `lib/mutators.lua`: manual experiment support.
- `rulesets/reworks/dice_patch.lua` and experiment-only changes to
  `layers/dice_patch.lua`: separate balance candidate.
- Clock, Higher Calling, One of Each, status and mutator-catalogue tests/scenarios:
  retain in the lab, not requirements for a release without those features.

### PvP: unresolved dependencies / mixed changes

- Custom Solo, `lib/singleplayer.lua`, `lib/practice_mode.lua`,
  `ui/pvp_run_options.lua`: keep only needed practice/testing paths; do not bring
  the full wall/debug surface merely to satisfy a copied UI test.
- `layers/multiplayer_content.lua`, layer/ruleset registry edits and content
  visibility: baseline decision required. Prefer existing upstream equivalents.
- Deck adapter support in `objects/decks/ZZ_cocktail.lua` and native custom
  deck hooks: audit against target centers before copying. Current target may have
  redesigned draft machinery; preserve both modes' isolation.
- `lib/session.lua`, `lib/rejoin.lua`, `lib/playback_launch.lua`,
  `networking/action_handlers.lua`, `ui/game/game_state.lua`, `lovely/game.toml`,
  `ui/replay/replay_browser.lua`, `pvp_api/queue.lua`: source contains solo/manual
  support mixed with old multiplayer infrastructure. Retain only proven dependencies.
- Other layer changes, Conjoined/sandbox Joker fixes, ruleset renames, README and
  test-index changes: inspect individually; not automatically Almanac features.
- `scripts/package_chaos_playtest.py`: optional development support; narrow packaged
  inputs and source paths if retained. Not a release criterion by itself.

### API

Keep `api/lobby/nakama.lua` capability hunk and `tests/test_server_features.lua`.

Earlier commits `0886b11` and `f78b2a0` contain absent/false ReworkCenter baseline
handling and explicit layer content support (`api/ruleset/reworks.lua`,
`api/layers/{fields,pool_gating,registry}.lua`, associated tests).
Classify as conditional dependencies, not automatically required Almanac changes.
Check whether the target already has equivalent fixes before porting.

### Server

Keep `nakama/src/lobby/shared_rules.ts` and `shared_rules.test.ts`.
Port narrow integration hunks in `checkpoint.ts`, `match.ts`, `protocol.ts`,
`relay.ts`, `state.ts` in that directory. Preserve current reducers, authority,
rate budgeting and checkpoint semantics.

Regenerate `nakama/modules/index.js` from the TARGET sources; never copy the old
bundle. No changes to unrelated moderation, web, database or rating features.
Competitive eligibility/results are later product work, not permission to remove
the private-only guards without an approved replacement.

### Existing upstream / never harvest by reverse diff

The clean bases have extensive newer networking, recovery, tests and other
features absent from the collection. Those source absences are NOT requested
deletions. Do not apply `git diff <target-base> <old-collection>` wholesale.

For a complete enumerable candidate inventory:

```sh
# PvP: all collection additions/changes relative to its pre-collection baseline
git diff --name-status 1c5192a1 8dbe7db01b650127f45245ed0fdcca29b54298e8
# API: its original feature ancestry, excluding newer target drift
git diff --name-status "$(git merge-base 1996fc56217bf0d9bc3da9642dcf792de46d8c79 549eb1578715c831a3b320d60fdf53d65f292d93)" 549eb1578715c831a3b320d60fdf53d65f292d93
# Server: exactly the shared-rule snapshot commit
git diff --name-status 7ae9638a63b43ef86b36fbfc3ab9f2a23dbab9d1^ 7ae9638a63b43ef86b36fbfc3ab9f2a23dbab9d1
```

Any candidate not explicitly kept above defaults to dependency review, NOT import.
Historical docs are evidence; generated artifacts are rebuilt; unrelated upstream
changes stay untouched.

## Suggested extraction commits

1. Draft engine/carrier/adapters, UI and tests with minimum necessary integration.
2. API capability exposure and tests.
3. Server shared-rule reducer/integration/tests, rebuilt target bundle.
4. Client shared-rule hooks/actions/UI and tests.
5. Almanac identity/disabled preview and refreshed implementation status.

Do not bundle new shared-offer logic, forecast design, queue activation or scaling
into extraction commits. Those follow the unresolved decisions in `v1.md`.

## Validation commands

PvP, both interpreters:

```sh
for interpreter in lua luajit; do
  for test in tests/test_chaos_draft.lua tests/test_chaos_backs.lua tests/test_almanac_identity.lua tests/test_shared_rules.lua; do
    "$interpreter" "$test" || exit 1
  done
done
git diff --check
```

API: `lua tests/test_server_features.lua` and
`luajit tests/test_server_features.lua`; run layer/rework tests if those are retained.

Server:

```sh
corepack pnpm --filter bmp-nakama-modules typecheck
corepack pnpm --filter bmp-nakama-modules test
corepack pnpm --filter bmp-nakama-modules build
git diff --check
```

Also run the target repositories' applicable current suites. Live scenario commands
and remaining full-match cases are recorded in the source docs and release
checklist. Never point a launcher at inherited absolute paths from another thread.
