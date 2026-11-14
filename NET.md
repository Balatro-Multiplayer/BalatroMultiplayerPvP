# Network style guide

How PvP talks to the server. The server decides; the client sends facts and draws state.

The contract (every request, every state key, the timers and the numbered rules R1..R54 that comments cite) is
written down in the server repo: `nakama/docs/pvp-match.md` in BalatroMultiplayerServer.

## Rules

1. **One file pair per game concept.** `lib/<concept>_view.lua` is pure; `pvp_api/<concept>_net.lua` is the thin shell.
   Example: `lib/ready_view.lua` + `pvp_api/ready_net.lua`.

2. **Names come from the game, not the transport.** `lives`, `round`, `result`, `ready`; never `packet`, `msg`, `payload_type`.

3. **No delivery layer in Lua.** No queue, seq, ack or retry code. The client sends a fact with `MPAPI.request` and draws
   state from `MPAPI.on_state`. The server does the deciding and the ordering.
   ```lua
   MPAPI.request("pvp.ready", payload, on_result)  -- a fact
   MPAPI.on_state("pvp.ready", N.evaluate)         -- the state we draw
   ```

4. **Views are pure.** Plain tables in, plain tables out; a view that must tell the shell what to do returns a list of
   commands (`RoundEndView.decide`). No `G`, `MPAPI`, `love`, `os`, `SMODS`, `localize`, `PVP.GAME` or any other `PVP.<state>`
   (`PVP.config`, `PVP.LOBBY`, `PVP.current_run_id`). They are tested with luajit, no game needed.
   `tests/unit/pure_views_test.lua` fails if a view uses any of them; run it before you commit.
   ```lua
   function ReadyView.i_am_ready(value, my_id)
       return is_table(value) and is_table(value.ready) and value.ready[my_id] == true
   end
   ```

5. **Nets hold no rule branching.** A net gathers inputs, calls one view function, then acts on the answer.
   If a net has an `if` that decides a game rule, move it into the view.
   ```lua
   start, record = PVP.ReadyView.decide(value, record, run_id, #lobby:get_players())
   if start then start_blind(lobby, start) end   -- start_blind asks ReadyView.starts_here before it acts
   ```
   A view function takes one input table once it has more than about four inputs (`RoundEndView.decide(input)`); the net
   fills the table and acts on the commands it returns. A rule that two nets share is one view function: `ResultView.record_once`
   decides "show this run's end only once" for both the result and the "you are out" screen (lives), and each net says in a
   comment who saves the marker.
   ```lua
   local shown = ResultView.to_apply({ result_value = value, my_id = me, recorded = recorded, latched_run = latched,
       current_run_id = run_id,
       game = { result_handled = game.result_handled, contested = game.contested, won = game.won, draw = game.draw } })
   ```

6. **Once-only effects use a marker.** Two shapes are allowed:
   - A latest value plus a high-water mark, when only the newest event matters. The server keeps `lastStart`; the client keeps
     the highest round it started and acts only on a higher one (Ready). This marker is **in memory on purpose** (`record` in
     `ready_net.lua`): a new process has none, so the `lastStart` already there counts as started and a crash never starts an
     old blind again. Do not save it.
   - An append-only list plus a saved index, when every event must apply exactly once (lives events). The server appends; the
     client handles each entry past its saved index, then saves the new index.

   The other once-only markers are saved: lives (`PVP.GAME.applied`), round end (`PVP.GAME.round_end_applied`) and the result
   (`recordedRuns`). Either way, snapshots and repeats do nothing.

   **Ids.** Run ids are strings, round ids are numbers: `ReadyView.build_start` turns `lastStart.roundId` into a number once, and
   `PVP.GAME.round_id` and every payload carry that number.

7. **Every user-facing string goes through `localize()`.** Never put English text in a view or a net.

8. **We control the protocol.** No legacy-host code paths and no compatibility shims. If client and server disagree, tell the
   player to update.

## Shared plumbing and the lifecycle

- **Plain-data checks:** `lib/_state_value.lua` (`PVP.StateValue.is_table`, `same_run(value, run_id)`, `of_other_run(value, run_id)`).
  `same_run` is strict (both runs known and equal); `of_other_run` is the lenient twin (both known and different, so a value with
  no run is not "of another run"). Views and nets alias them; no net or view writes its own `tostring(value.runId) == ...`.
- **Shell helpers:** `pvp_api/_net_basics.lua` (`PVP.NetBasics.pvp_lobby()`, `PVP.current_run_id()`, `log_refusal`, `refusal_logger`).
  A refused request is only logged; the state shows the truth.
- **One lifecycle.** A net names the steps it has the same way: `on_connected()` (CONNECTED: read the state again, the run is live
  now), `on_snapshot()` (SNAPSHOT_APPLIED), `update()` (every frame). `PVP.CONNECTED_ORDER` and `PVP.SNAPSHOT_ORDER` in
  `pvp_api/lobby_bridge.lua` list who runs on those events, and `PVP.FRAME_ORDER` in `pvp_api/frame.lua` who runs every frame, in
  order, from the one `Game:update` wrapper. A net does not wrap `Game:update` itself. Each list has a comment saying why its order
  is what it is (`SNAPSHOT_ORDER`: it does not matter, each net only sets a flag for its next frame), and a unit test pins it.
- **Waiting for the run.** State that changes the game waits until the run is loaded (`PVP.RunGate.loaded()`): `evaluate` sets
  `apply_pending` and calls its apply step (`apply_new`, or `apply_result` in ResultNet); if the run is not loaded yet that step
  returns, and `update()` tries again each frame until it is. LivesNet, ResultNet and RoundEndNet all work this way.
- **Who reacts to a key.** One key can have more than one reader. Callbacks on the same key run in the order the nets
  registered, which is file load order (alphabetical by file name, so `round_end_net` before `timer_net`).

  | State key | Nets that register on it | Handler |
  |---|---|---|
  | `pvp.ready` | ReadyNet | `evaluate` |
  | `pvp.round` | RoundEndNet, TimerNet, EnemyScoreNet | `evaluate` (RoundEndNet, TimerNet), `refresh` (EnemyScoreNet) |
  | `pvp.lives` | LivesNet, RoundEndNet | `evaluate(value)` (LivesNet), `evaluate` (RoundEndNet reads `get_state`) |
  | `pvp.result` | ResultNet | `evaluate_result` |
  | `pvp.votes` | ResultNet | `evaluate_votes` (also shows the vote counts in chat) |
  | `pvp.targets` | TargetsNet, TeamsNet, EnemyScoreNet | `refresh` (all three) |
  | `pvp.teams` | TeamsNet | `refresh` |

  Some nets also read keys they do not register on (RoundEndNet reads `pvp.result`, `pvp.rules` and `pvp.teams` for its inputs).
- **Round facts.** `lib/round_facts.lua` (`PVP.RoundFacts`) is the pure side of `pvp_api/round_net.lua`: whether a hand counts, the
  hands left after a run-out or a rejoin, the blind key a run-out is filed under and the run-out ordinal.
- **The enemy's score is the server's to reveal.** While a PvP round is playing, the server leaves `score` and `highestScore` out of
  `pvp.round` (and `teamScores` out of `pvp.targets`) until this player has played a hand, so the peer bus never carries a score
  (`pvp_api/net.lua` sends hands, skips and lives only; the Nemesis blind's `receive` reads no score). `lib/enemy_score_view.lua`
  (`score`, `highest`, `round_is_mine`) and `pvp_api/enemy_score_net.lua` turn a push of this round into `PVP.GAME.enemy.score`
  and set `PVP.GAME.enemy.score_known`; the HUD shows "???" while it is false, and `action_start_blind` clears it each round.
  Teams' sum comes from `teams_net.lua`, which sets `score_known` only for this player's round. Every field may be absent.
- **Hands the server spent.** `pvp.round.players[me].handsSpent` (the server ended this player's hands while the round is still
  open) gives `RoundEndView.decide` a `hands_spent` command, before any `end_pvp`, once per round (`round_end_applied.spent`). The
  handler (`action_hands_spent`) fires `mp_pvp_loss`, sets the hands to 0 and shows the wait text; the round's result ends the blind.
- **A net reads top to bottom.** `pvp_api/timer_net.lua` keeps its mutable locals under one comment and splits the state into three
  named steps: `take_snapshot` (a join or rejoin starts again), `start_pushed_n` (a new `n` starts or restarts) and
  `follow_push_of_same_n` (the same `n`: who is timed, and the pause). `evaluate` only picks one.

## Timers

The server decides who is timed and who started it. The client never relays a timer message to the other player.

- **Out:** the timer button sends `pvp.timer_start {runId, kind, roundId?}` (`kind` is `"ante"` or `"pvp"`; `roundId` is sent for
  `"pvp"`; no clock or bank travels, the server owns them) or `pvp.timer_pause {runId}`. Play in the PvP blind (with a PvP hand
  timer in `pvp.rules.clocks`) sends `pvp.hand_commit {runId, roundId, handsLeft, timerLossesApplied}`: `handsLeft` is the hands
  left after this hand, `timerLossesApplied` the run-outs this client has already taken off its hands. The server may refuse a
  timer request: `not_ready`, `nobody_to_time`, `not_ahead`, `no_opponent`, `not_starter`, `not_timed`. A refusal is only logged;
  the button shows the state.
- **In:** `pvp.round.deadline` is `null` or `{kind, by, against, remainingMs?, n, paused?}`. `lib/timer_view.lua` turns it into
  `{running, timed_me, started_by_me, seconds, paused}` for the timer box; `pvp_api/timer_net.lua` writes the box's fields.
- **Two clocks.** With `remainingMs` set, the server counts the time: the box counts down from it, and when it reaches 0 the
  client sends nothing (the server makes the run-out and restarts the timer). With `remainingMs` null the deadline is a rate
  marker of a personal clock: it carries no time, and the clock itself is in `pvp.clocks` (read by `ClocksNet`). The client
  never reports a run-out.
- **`n`** goes up on every start and restart. A state with a new `n` starts (or restarts) the countdown; the same `n` again
  changes nothing but who is timed. A snapshot (join, rejoin) always starts it again from its own time left.
- **`paused`** is set while the timed player is disconnected: the server holds the time, so the box shows the `remainingMs` the
  state carries, frozen, and a frozen 0 is not a run-out. The push that ends the pause comes with the same `n` and no `paused`;
  the countdown goes on from the frozen time (`TimerView.keep_time`), it is not restarted.
- **Clocks and a disconnect.** The server owns every clock (`pvp.clocks`, `pvp.rules.clocks`) and makes every run-out; the
  client keeps, records and reports none. A reconnect reads the clocks again (`ClocksNet`) and the countdown restarts from the
  server's live time. Play in the PvP blind sends `pvp.hand_commit` so the server credits the hand time.
- **Host:** the lobby metadata carries `timer_base_seconds` and `timer_forgiveness` as the lobby has them, so the server can
  read the rules.

## Adding a concept

1. Write `lib/<concept>_view.lua` and a test in `tests/unit/<concept>_view_test.lua`.
2. Write `pvp_api/<concept>_net.lua`: requests out, `MPAPI.on_state` in, and the game effects the view's answer calls for
   (a frame hook, attention text, a game action). No rule decisions.
3. Run `luajit tests/unit/pure_views_test.lua` to confirm the view is still pure.
