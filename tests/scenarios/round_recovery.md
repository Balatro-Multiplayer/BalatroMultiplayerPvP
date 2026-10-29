# PvP round recovery

The host remains the referee. Nakama relays reports and stores the existing referee
checkpoint; it does not adjudicate scores.

## Protocol

- All active players advertise `round_protocol = 1` when readying. Otherwise the
  round uses legacy messages, without automatic report retries.
- The host assigns a fresh opaque `round_id`. A player retains its latest committed
  score/hands report with an increasing revision. Reconnect never samples live scoring.
- Only a matching `pvp_round_state` from the current host acknowledges a report.
  Duplicate/older reports return state without changing scores or resolving again.
- Resolution is guarded before effects in every scoring mode. The result carries
  authoritative lives, team lives and eliminations; the client applies it once.
- Resolved state stays through the shop. Rounds that eliminated a player stay until
  run end, because that player need not ready the next blind.
- Pending reports retry every two seconds. After 30 seconds without acknowledgement,
  an on-screen warning replaces silent retry exhaustion. A reconnect rearms recovery.
  These durations govern retries and feedback, not correctness.
- Current/retired round records and accepted revisions enter the existing checkpoint.
  Host takeover is only as current as that checkpoint; this is not a durable
  server-acknowledged transaction.

## Automated checks

From the PvP repository root:

```sh
lua5.4 tests/unit/round_sync_test.lua
luajit tests/unit/round_sync_test.lua
```

The harness uses the actual referee and recovery module with a lossy transport,
plus an action-handler integration case. It is not a running Balatro instance.

The companion server change marks `pvp_round_state` host-only and updates the
generated Nakama bundle. The client also pins responses to the host identified by
the blind-start action, updated by host-change/rejoin events. No MPAPI change.

## In-game checks still required

Use two current clients for 1v1, then repeat the loss/duplicate checks in Royale,
N-player Nemesis, Teams and Manhunt:

1. Drop the reporting client's socket as its final hand commits. Rejoin while
   waiting in `HAND_PLAYED`; the correct score must resolve the round.
2. Drop the recipient before lives/outcome delivery. Rejoin; restore lives before
   leaving the blind. Check both an ordinary life loss and the final life.
3. Drop the host's socket during the final reports. Rejoin; no second life loss.
4. Eliminate a disconnected player, let survivors begin another blind, then rejoin
   the eliminated player. It must receive its elimination, not enter the new blind.
5. Reconnect mid-scoring, in the shop and after a result. No premature resolution,
   stale score sampling or repeated win/loss effects.
6. Leave/restart while a report is pending. Nothing may be sent into the new run.
7. Mix an old client with a new client. Ordinary play retains the legacy protocol;
   this change does not promise reconnect recovery for that lobby.

Outside this change: recovering a missed blind-start handshake, replaying a crashed
client into a round, and guaranteeing host migration when its latest checkpoint
never reached the server.
