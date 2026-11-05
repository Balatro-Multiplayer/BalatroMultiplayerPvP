# Legacy branches (pre-Nakama history)

Upstream renamed to `Balatro-Multiplayer/BalatroMultiplayerPvP` and replaced `main` with unrelated history.
Old branches moved to `legacy/*` with rewritten SHAs. The SHAs below are the originals (local + PR heads).

## Chaos Clock POC stack

Four linear layers on old `dev` at `5551e21f` (2026-09-01, "Update TheOrder.lua"). PRs closed unmerged 2026-10-22.

| Layer | Tip | PR | Adds |
|---|---|---|---|
| `steph/random-effects-runtime` | `7caa5c1c` | #542 | scenario test runner; mutator registry, game modifiers, round deltas, keyed RNG, Chaos Clock engine |
| `steph/random-effects-wall` | `5b3289ff` | #543 | custom editor wall reads the registry; Chaos Clock control + HUD |
| `steph/random-effects-mode` | `45340dba` | #544 | MP Jokers become a layer; mp_content scenario tests; mutator docs |
| `steph/custom-multiplayer-lobbies` | `29036d50` | #547 | custom lobby setup + shared rules readout; compact modifier payloads for relay string limit |

- `steph/custom-multiplayer-lobbies` contains all four layers. It is pushed to `origin` and checked out in this folder.
- Per-layer diff: `git log <lower tip>..<upper tip>`, e.g. `git log 45340dba..29036d50` for lobbies alone.
- Original commits also live upstream at `refs/pull/542..547/head`.
- Upstream rewritten copies: `origin/legacy/steph/random-effects-{runtime,wall,mode}`, `origin/legacy/steph/custom-multiplayer-lobbies`.
- `steph/random-effects-mode-backup` (`3ac1357b`) is an earlier, diverged take on the mode layer. It is not part of the stack.
- No common ancestor with new `main`, so porting means cherry-pick or reimplementation, not rebase.

## steph/rework-engine-v2

- `ee00a311` rebuilds ReworkCenter as a pure function of the layer chain: every apply re-derives reworked props from a load-time vanilla snapshot.
  - `rulesets/_reworks.lua` replaces the in-place `mp_<layer>_<prop>` engine and `LoadReworks`.
  - Begin/EndRunReworks bracket a run. ApplyReworks is the menu preview and refuses a chain change mid-run.
  - Rarity reworks move only affected jokers between pools. `rework_fingerprint()` rides in the mod string, and a mismatch shows in the version modal.
  - `tests/test_reworks.lua` has 51 checks.
- `ecaeecc7` re-snapshots pools on every `injectItems` pass so reworks survive `init_item_prototypes` (profile/language switch).
- Predecessor: PR #454 "deterministic ReworkCenter? do not merge" (`steph/competitive-agent-refactor`), closed 2026-10-22.
