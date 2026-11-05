# Scenario runner: spec

Generic in-game scenario runner in MultiplayerAPI. Each mod owns its scenarios. Ported from the PvP gigabranch harness, not built on `api/playback/`.

Source to port (PvP repo, branch `origin/steph/custom-multiplayer-lobbies` @ `29036d50`):

```
git show 29036d50:tests/scenarios/_runner.lua     # step engine, 137 lines
git show 29036d50:scripts/run_scenario.sh         # launcher, 59 lines
git show 29036d50:tests/scenarios/glass_cannon.lua  # example of the step format
git show 29036d50:tests/readme.md                 # old docs
```

## Goal

- Run one scripted scenario in one real game instance and get pass/fail from the shell: `bash scripts/run_scenario.sh <mod>:<name>`, exit 0 only on `DONE … fail=0`.
- The runner is mod-agnostic. A mod contributes only `tests/scenarios/*.lua`.
- Inert unless its env var is set.

## Non-goals (v1)

- Multi-instance or networked scenarios. `BMP_IMPERSONATE_*` makes them possible later.
- Headless (no-LÖVE) unit tests. Gigabranch `tests/_stubs.lua` stays parked.
- Replay-based regression scenarios (feed a recorded match through `MPAPI.playback.new_driver`, then assert). Worth a v2.
- Replacing ClaudeControl.

## Layout

```
BalatroMultiplayerAPI/
  dev/scenario/runner.lua    step engine + S API + output protocol
  dev/init.lua               + `if os.getenv('BMP_SCENARIO') then MPAPI.load_mpapi_file('dev/scenario/runner.lua') end`
  scripts/run_scenario.sh    launcher
  dev/scenario/README.md     [TBD] or a section in AGENTS.md "Verifying changes"

BalatroMultiplayerPvP/
  tests/scenarios/smoke.lua
  tests/scenarios/[TBD].lua
  tests/readme.md            one screen: how to run, which scenarios exist, what each covers
```

## Env contract

| Var | Meaning |
|---|---|
| `BMP_SCENARIO=<mod_id>:<name>` | Load `<mod path>/tests/scenarios/<name>.lua` for `SMODS.Mods[mod_id]`. Example: `MultiplayerPvP:smoke`. |
| `BMP_SCENARIO_QUIT=1` | `love.event.quit()` about 1s after `DONE`. The launcher always sets it. |
| `BMP_SERVER_HOST` / `_PORT` | Already in `dev/init.lua`. Unset means the local stack on `127.0.0.1:7350`. |
| `BMP_IMPERSONATE_*` | Already in `dev/init.lua`. Not used in v1. |

The old runner used `MP_SCENARIO`. The rename to `BMP_` puts it with the other dev switches.

## Scenario file format

The format is unchanged from the gigabranch. The file returns a list of steps:

```lua
return {
  { wait = 2, run = function(S) ... end },                 -- seconds after previous step (default 0.5)
  { until_ = function() return G.hand end, timeout = 10,   -- poll; FAIL + finish on timeout (default 10)
    run = function(S) ... end },
}
```

Optional addition: `{ settle = true, ... }` waits until `MPAPI.playback._queues_empty()` (no *blocking* events) before `run`. This is the only thing taken from the playback driver. Its header comment explains why "queue non-empty" is the wrong test.

## S API

| Fn | Behaviour |
|---|---|
| `S.check(cond, msg)` | Log `PASS msg` / `FAIL msg` and count it. Returns `cond`. |
| `S.log(msg)` | Log `LOG msg`. |
| `S.shot(name)` | `love.graphics.captureScreenshot`, then write `<mod path>/.context/scenarios/<name>/<shot>.png`. Log `SHOT <path>`. |
| `S.fake_button(ref_table)` | Minimal UIElement for calling `G.FUNCS.*` handlers. Prefer clicking the real UI when a scenario can. |
| `S.name`, `S.mod_id`, `S.pass`, `S.fail` | Read-only state. |

## Runner lifecycle

1. Loaded from `dev/init.lua`, which runs after all of `api/` and `ui/`. At this point other mods' files may not be loaded yet, so the scenario file is not loaded here.
2. `MPAPI.on_loaded(function() ready = true end)` (`api/connection/lifecycle.lua:84`). This fires once `G.STEAM` exists and the connection has started. Because MPAPI loads first, this callback runs before the mods' own `on_loaded`. So the flag is only consumed on a later frame, never in the callback itself.
3. `Game:update` hook. The start condition is `ready and G.STATE == G.STATES.MENU and G.MAIN_MENU_UI`. When it holds:
   - Load the scenario file with `SMODS.load_file("tests/scenarios/<name>.lua", mod_id)`.
   - If the mod is missing or the file is missing or won't compile, emit `FAIL` and finish.
   - Otherwise emit `START <mod_id>:<name> steps=N`.
4. Per frame, walk the steps: `wait`, then `until_`/`settle`, then `run`, each `pcall`'d. An error or timeout emits `FAIL step i …` and finishes. It doesn't continue.
5. Finish: emit `DONE pass=N fail=M`, then quit if `BMP_SCENARIO_QUIT` is set.
6. Boot conveniences carried over from the old runner:
   - Skip the splash for this boot only. Restore `G.SETTINGS.skip_splash`, because it is persisted.
   - Hide DebugPlus new-log previews through `configDefinition.showNewLogs.onUpdate(false)` without writing its config. MPAPI has a vendored `lib/debugplus`, so check which DebugPlus is actually live ([TBD]).
   - The old `suppress_dev_warning` step is gone: PvP `main` defines the flag but nothing reads it.

## Output protocol

Each line goes to the Lovely log via `MPAPI.sendInfoMessage` (or `sendInfoMessage(..., "MPAPI")`), prefixed `BMP_SCENARIO `:

```
BMP_SCENARIO START MultiplayerPvP:smoke steps=3
BMP_SCENARIO PASS pvp main menu page is up
BMP_SCENARIO SHOT /…/.context/scenarios/smoke/menu.png
BMP_SCENARIO FAIL step 2 timed out waiting
BMP_SCENARIO DONE pass=1 fail=1
```

The launcher's success regex is `^BMP_SCENARIO DONE pass=[0-9]+ fail=0\s*$`.

## Launcher: `scripts/run_scenario.sh`

Usage: `bash scripts/run_scenario.sh <mod_id>:<name> [--mod-repo <path>]`. `--mod-repo` defaults to cwd if cwd is a mod repo [TBD: or require it].

Kept from the old script:
- Refuse if Balatro is already running (`pgrep -f Balatro.app/Contents/MacOS/love`).
- `caffeinate -u -t $TIMEOUT >/dev/null 2>&1 &`. It must not inherit stdout, or an agent's shell hangs until it exits.
- Launch `"$BALATRO_DIR/run_lovely_macos.sh"` with the env vars. `BALATRO_DIR` defaults to `~/Library/Application Support/Steam/steamapps/common/Balatro`.
- Poll the pid for `SCENARIO_TIMEOUT` (default 120s), then `pkill -9`. The game ignores SIGTERM while stuck in `present()`.
- Find the newest log in `~/Library/Application Support/Balatro/Mods/lovely/log/`, fail if no new log appeared, print the `BMP_SCENARIO` lines and the log path, and set the exit code from `DONE`.

New:
- **Checkout guard.** Scan `Mods/*` symlinks. Fail unless one resolves to this MPAPI repo root and one resolves to `--mod-repo`. Print what each currently points at. Without this, a run from a worktree silently tests the main checkout. The script doesn't retarget symlinks, because other agents share `Mods/`.
- **Server guard.** Refuse if `BMP_SERVER_HOST` is set to [TBD: production host(s)]. The default (unset) is the local stack.
- Print the commit each repo under test is at (`git -C <repo> rev-parse --short HEAD`) in the header.

Known constraint: the Mac must stay unlocked and awake, or LÖVE blocks in `present()` and the run never leaves the loading screen.

## First scenarios (PvP)

| Name | Steps | Proves |
|---|---|---|
| `smoke` | wait for menu → check `MPAPI.is_ready()` → check PvP is registered (`MPAPI` mod registry has `PVP.id`) → open the PvP main menu page → shot | Boot, MPAPI ready, PvP `on_loaded` ran, menu host swaps in PvP |
| `[TBD]` | e.g. Practice → start a seeded run → BLIND_SELECT → select small → SELECTING_HAND with cards → shot | Practice path end-to-end, no server needed past login |

For the smoke scenario, look up the real accessor for "registered mods" and the call that opens a mod's menu page. Don't guess them: [TBD].

## Open questions (now closed)

- [TBD] Does launching `run_lovely_macos.sh` directly (not through Steam) give `G.STEAM`? -> my guess yes and no. steam doesn't work through the lovely launch. consider workaround: If not, the launcher needs `steam://run/2379780` plus env passing, or a `steam_appid.txt` route.
- [TBD] Does a scenario boot need the local server stack up, or does `on_loaded` fire with the connection merely *started*? Not sure. Don't know how to laumch server.
- [TBD] `.context/` is ignored in the PvP repo only through `.git/info/exclude`. MPAPI has no ignore for it. Screenshots go under the *mod's* path, so this only matters if MPAPI gets its own scenarios. -> propose infra.
- [TBD] MPAPI commit `aace395` (Connor, 2026-10-22) removed the strip-dev workflow, and `dev/init.lua` is tracked on `main`. Confirm how releases exclude `dev/` (`dist/`?) before adding more under it. Otherwise the env-var gate is the only thing keeping it inert, and `dev/init.lua` already repoints the default server unconditionally. -> don't understand this.
- [TBD] Name: "scenario" (old) vs anything else.

## Done when

- `bash scripts/run_scenario.sh MultiplayerPvP:smoke` exits 0 from a clean state and writes a screenshot.
- Deliberately breaking an assertion, the scenario name, or a mod symlink each exits non-zero with a readable reason.
- A normal launch (no `BMP_SCENARIO`) shows no runner log lines and no behaviour change.
