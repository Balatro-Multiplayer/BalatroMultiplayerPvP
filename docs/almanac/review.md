# almanac-v1: what this branch is and how to review it

Almanac is a 1v1 Nemesis format on Expanded's baseline. you play the Almanac deck,
you draft extra decks at antes 2, 3, 5 and 7 and keep their effects, and from ante 3
every PvP blind runs under two boss rules that hit both players. the product
statement and approved decisions live in `v1.md`. this doc covers the code.

it spans three repos, each on an `almanac-v1` branch:

| repo | size | what |
| --- | --- | --- |
| PvP (this one) | ~4.3k lines, mostly tests | deck, ruleset, both drafts, rule effects, UI, harness |
| Server | ~1.5k lines incl. regenerated bundle | `nakama/src/lobby/almanac.ts`, `shared_rules.ts` |
| API | 19 lines | `lobby.server_features` from the snapshot's `serverFeatures` |

the shape to hold onto: **the server owns every decision, the client applies
results.** offers, both acquisition histories, rule picks, the 10s deadline,
timeout rolls and resolution are all match state on the server. the host only asks
for a rule draft to start. clients never send offers or their own history. if a
change makes a client decide something, that's the thing to push back on.

## the pieces

**entry.** `rulesets/zz_almanac.lua` copies Expanded's actual `_layer_order` and
appends `layers/almanac.lua`, so content can't drift from Expanded. the layer pins
the carrier deck `b_mp_almanac`, no sleeve, no challenge, shared rules on. the
only path in is private Nemesis lobby → Lobby Options → Almanac. `PVP.pvp_start_match`
(`pvp_api/flow.lua`) refuses anything but exactly two players in Nemesis on a
server advertising `almanac_draft = 1` and `shared_pvp_rules = 2`. the ranked pillar
in `ui/main_menu/find_game.lua` is a Coming Soon preview with a How to Play overlay.
it doesn't queue.

**stake draft (pre-run).** reuses the existing server Setup/BanPick. it's turned on
for Almanac in `run_lifecycle.lua` through the `PVP.SETUP.plan` draft flag.
`lib/draft.lua` `almanac_board` deals five stake tiles of the same deck: White,
Green, Black, Purple and Gold, with independent 50% rolls swapping White → White-
and Gold → Spectral+. bans alternate three times, then the second player picks
from the last two. White- (`objects/stakes/zz_white_minus.lua` +
`overrides/white_minus.lua`) is White plus Grabber and Wasteful, granted once
through the run-start event queue. it's appended, not inserted above White, so
existing stake ids don't move.

**deck draft (in-run).** the core is `lib/almanac_draft.lua`. it hand-codes each
deck's effect, because `Back:apply_to_run` only works at run setup. `D.commit`
records the deck *before* applying it, `state.busy` blocks `save_run` until the
apply's events drain, and Orange's free Giga pack has its own `pack_due` →
`pack_active` checkpoint. `overrides/almanac_draft.lua` gates `update_shop` and
`update_blind_select` while a draft is open. online, `pvp_api/actions/almanac.lua`
polls the server every 2s with `pvp_almanac_open`/`pick` and only accepts an offer
whose id matches `<run>:decks:<ante>`. the server deals one shared offer, waits
until both players have picked the previous milestone, and excludes the *union* of
both histories. solo practice and local replay still roll offers on the client.
UI: `ui/almanac_draft.lua` (click a deck to select it, click again to confirm,
with a preview of resource changes), `ui/almanac_backs.lua` (a purely cosmetic
fan of acquired backs on the deck, no state), `ui/almanac_forecast.lua` (pause
menu, schedule and status only, never rolls future offers).

**boss rules.** `lib/shared_pvp_rules.lua` holds the catalogue and lifecycle,
`overrides/shared_pvp_rules.lua` the effects. effects compose with the PvP blind
instead of replacing it, and they go through SMODS's debuff arbitration, so
immunity still wins. flow: both players ready → after the ready check the referee
(`referee.lua` `start_blind_2p`) sends `pvp_rules_open` instead of
`pvp_start_blind` at ante ≥ 3 → the server sends each player its own four-rule
offer → picks lock → the server sends `pvp_start_blind` with the two rules. if both
pick the same rule, the server adds a random second one from the whole eligible
pool. the encounter id is run + round id. retired ids reject late opens, offers
and starts (`blind_handshake.lua`, `R.prepare`). rules turn on in `Blind:set_blind`
and turn off on defeat, disable, cash out or going to the menu. the PvP timer
pauses while a rule offer or deck draft is open (`ui/game/timer.lua`).

**recovery and replay.** `lobby_bridge.lua` calls `SHARED_RULES.sync()` on
reconnect and on replay tails. the server checkpoint keeps both ledgers and pushes
the rule deadline back by however long the server was down.
`lib/almanac_draft_replay.lua` and `lib/shared_rules_replay.lua` replay the POV
player's picks, including a recorded "pass" when no offer is legal.

## where to push in review

- **three copies of each catalogue.** deck min antes are in `D.definitions`
  (client) and `DECK_ANTES` (server). rule antes are in `R.definitions` and
  `RULE_ANTES`. `tests/test_almanac_contract.lua` (needs `SERVER_DIR`) is the only
  thing keeping them in sync. any catalogue edit should touch both and that test.
- **hand-coded deck effects are the risk surface.** each `add(...)` is our
  reimplementation of a vanilla or MP deck, mid-run. check each against the
  deck's real config, especially the destructive ones (Abandoned, Erratic,
  Checkered) and the ones that run every round through `D.calculate`
  (Anaglyph, Heidelberg, Echo).
- **what decides "this is Almanac".** the server's `isAlmanac` and the client's
  `R.enabled` both accept `metadata.ruleset == almanac` *or* `metadata.deck ==
  "Almanac"`, and both are host-editable metadata. fine for private lobbies, but it
  should become `rankedMode` before a queue exists.
- **the private toggle is still there.** Lobby Options has "Shared PvP rules
  (prototype)" for non-Almanac private lobbies. i'd rather decide whether that
  ships than let it survive by accident.
- **gates freeze the state machine.** the draft gate returns early from shop and
  blind-select updates until the server answers. a server that never answers is
  a soft-locked run with a "waiting" overlay. make sure that's the failure we want.

## evidence

offline, from the repo root: `lua` and `luajit` on `tests/test_almanac_{backs,
contract,draft,identity,setup}.lua` and `tests/test_shared_rules.lua` (contract
needs `SERVER_DIR`, setup needs `MPAPI_DIR` with a trailing slash), plus
`tests/unit/ready_check_referee_test.lua`. server: `corepack pnpm --dir nakama
typecheck`, `test` and `build`. `release-checklist.md` has the last recorded counts.

live: `bash scripts/run_pair.sh pair_almanac` (see `tests/scenarios/pair.md`). two
real clients get through the lobby, stake draft, the ante-2 and ante-3 deck drafts
with the same offers and the union excluded, their own four-rule offers, an
identical reveal, and two played PvP blinds with matching lives. that's the first
real two-player evidence on this branch. it does **not** cover reconnect, replay,
host migration, timeouts, matching picks, rule effects in play, antes 5 and 7, the
rematch, or rendered layout. the product gate in the checklist stays unchecked
for those.

## not done, on purpose or otherwise

- no queue. `pvp_ranked_almanac` exists server-side; nothing queues into it.
- competitive baseline enforcement (lives, modifiers, the rest of Expanded
  Ranked) and rejecting Almanac in other queues are both still open.
- no ante scaling change (decision 6).
- at the time of writing, the working tree is moving `lib/almanac_draft*.lua` and
  `lib/shared_*` into `lib/almanac/` and dropping `tests/test_almanac_setup.lua`.
  the paths above are the committed ones.
