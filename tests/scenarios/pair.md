# pair scenarios

two real Balatro clients, one local Nakama, one scenario file both of them run.
it's the cheapest way we have to see a multiplayer change happen on two screens
without two humans clicking through a lobby.

```sh
bash scripts/run_pair.sh pair_pvp_blind   # ~1 min
```

## what it does

- `scripts/run_pair.sh` reuses whatever answers on `127.0.0.1:7350`, else starts
  Nakama from `BMP_SERVER_DIR` (default `.context/BalatroMultiplayerServer`) and
  leaves it up. it links the Dev mod for the run only and unlinks it after, so a
  normal launch still goes to Official.
- each role logs in as a fresh Device account, `pair-<role>-<run>`. fresh on
  purpose: a reused account remembers its seat from a killed run and the next
  launch sits on the Reconnect prompt forever.
- launches are 2s apart because Lovely names logs by the second. same second,
  same file, interleaved garbage.
- host and guest talk through files in the run dir: `P.put`/`P.get` for values
  (the lobby code, who picked what), `P.sync` for barriers.
- `P.snapshot` logs a `STATE` line per side. the script diffs host against guest;
  any difference fails the run even if every check passed.
- more than two clients: put `-- roles: a_host a_guest b_host b_guest` at the top
  of the scenario. one client per role, `P.sync` waits for all of them, `P.only`
  takes a list, and every role's STATE is diffed against the first's.
  `party_roster_reveal` runs four (~25s).

## what's real and what's a fixture

real: login, lobby, ready/start, the server's stake Draft, cash out and shop,
the referee, and every played hand. fake: `P.jump_to_pvp` sets the ante and
skips Small/Big so we land on the PvP boss. it tells the referee the ante via
`PVP.ACTIONS.set_ante`, as `ease_ante` would.

the host plays five leftmost cards, the guest plays one. with a shared seed and
identical hands every blind was a tie, which proves nothing about lives.

## reviewing it

- **the diff is the assertion.** anything you want both clients to agree on goes
  in `project()` in `lib/pair.lua`, keyed by role (`lives_host`), never
  mine/theirs, or the lines can't match byte for byte.
- **push fixtures toward the edges.** `jump_to_pvp` and the hand loop are where
  we lie to the game. if a fixture starts reimplementing game logic, i'd rather
  drive the real button (see `next_round`) than grow the fake.
- **watch for private reach-ins.** `MPAPI._internal.conn` (age question),
  `G.I.UIBOX` (Cash Out is its own UIBox, not inside `G.round_eval`). fine for a
  test, but they break silently when MPAPI moves things.
- **a timeout isn't a diagnosis.** `NOTE` lines log state changes and plays;
  `nakama.log` and both Lovely logs are linked from the run dir the script prints.
- **only `run_pair.sh` touches the machine.** it changes the Mods dir and the shared
  `bmp-nakama` container, which other workspaces use too. say so in the PR if
  you change either.

## known gaps

- both clients share one Balatro profile dir. don't build save/reload checks on
  this yet.
- macOS only, one pair at a time, and the reused DB collects throwaway accounts.
