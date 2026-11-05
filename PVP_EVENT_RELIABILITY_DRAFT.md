# Draft: reliable delivery for critical PvP events

> Temporary design document. Remove before final merge.
> Includes the reliability work and timer follow-up on `fix/pvp-cashout-final-scores`. No API/server changes.

## Scope and status

On **2026-11-04**, restart-after-game-closure recovery was explicitly deferred.
PvP timer behavior while the game is closed, catch-up, and rejoin eligibility need
further design. This implementation only handles **live processes retaining their
in-memory state**. No disk journal, playback integration, or restart recovery was
added. Existing restart code is not made reliable by these changes.

Implemented:

- Payload-agnostic ordered ACK/retry channels (`lib/reliable_messages.lua`).
- Hand-score adapter using that core while preserving the existing
  `pvp_play_hand` / `pvp_round_state` wire protocol (`pvp_api/round_sync.lua`).
- A server-echo checkpoint barrier (`lib/referee_checkpoint.lua`).
- Negotiated reliable referee inputs and per-recipient output queues, stored with
  the referee's accepted input cursors and gameplay state
  (`pvp_api/reliable_events.lua`, `pvp_api/actions/reliable.lua`).
- Fresh authoritative checkpoint reads during host takeover, rather than trusting
  potentially stale local metadata (`pvp_api/referee.lua`).
- Central routing for critical legacy callers, ready-check answers and ante-skip
  vouchers. Gameplay rules, including timer/life-loss rules, remain unchanged.
- Authority/incarnation guards and checkpoint transactions for asynchronous
  ready-check timeouts and pending-result server-hold callbacks. A replacement
  host re-requests an outstanding server hold.

## Delivery path

Every physical connection remains **client <-> Nakama**. The host is another
player's client, not the Nakama server. Nakama authenticates/relays messages and
stores the checkpoint; the host still executes PvP rules.

1. Caller queues an event once. The adapter freezes it and sends only the head of
   that player's FIFO to the current host through Nakama.
2. Host applies the next contiguous input inside a referee transaction. It advances
   that sender's accepted cursor and queues the resulting outputs without sending
   them yet.
3. Host submits one complete metadata checkpoint containing state, accepted input
   cursors, and the per-recipient output queues. Input ACKs are staged behind the
   same checkpoint barrier.
4. Only an exact full metadata echo releases those ACKs and permits the committed
   output identities to transmit.
5. Each recipient applies contiguous outputs once and ACKs them. Output ACK
   progress is included in subsequent checkpoints.

There is one in-flight input per player and one in-flight output per recipient.
Different players are not globally ordered. A delayed recipient does not prevent
other recipient queues from progressing, subject to the shared checkpoint/storage
capacity.

## Shared channel API

Own a manager per uniquely scoped lobby/run/channel lifetime. The namespace is
global; the queues and cursors are not a global singleton.

```lua
local delivery = PVP.ReliableMessages.new({
    scope = unique_run_channel_scope,
    transmit = function(peer, envelope) return transport_send(peer, envelope) end,
    on_message = function(from, payload, seq)
        -- Validate context and safely apply, or return false with NO effects.
        return true, authoritative_response
    end,
    on_ack = function(peer, response, seq) -- Optional.
        -- Reconcile opaque response before advancing.
        return true
    end,
    on_timeout = function(peer, seq, payload) show_sync_failure() end,
})
local seq, reason = delivery:send(peer_id, payload)
-- Centrally feed :receive(authenticated_from, envelope) and :update(dt).
```

Generic envelopes:

```lua
{ kind = "message", scope = "...", seq = 41, payload = ... }
{ kind = "ack", scope = "...", seq = 41, response = ... }
```

- `send` means queued, not delivered. It returns `nil, reason` on closed/full
  channels without allocating a sequence. Plain JSON-shaped payloads are copied.
- Defaults: retry every 2 seconds, stall after 30 active seconds, 128 pending
  messages and 128 peers. Timeout retains the head and all dependent work.
- Only an exact actually-sent head ACK advances the generic sender.
- Receiver accepts only the next contiguous sequence. Duplicates return its
  existing cursor/cached response without applying again; gaps do not apply.
- Handler/response-application errors fault a stream rather than blindly replaying
  an effect that may already have partially happened.
- `pause` stops sending/deadlines; `resume` rearms retained work. Explicit
  `retarget` moves a queue and pauses it; it does not itself restore authority.
- `export_channels` / `restore_channels` and `export_received` /
  `restore_received` support live authority transfer into fresh managers. Imports
  validate capacity/continuity and are atomic. They do not access a filesystem.
- `close` permanently cancels the manager.

## Live referee adapter

The session belongs to `lobby._pvp_reliable_events`, not `PVP.GAME`. Normal local
state resets and end screens therefore retain output duplicate cursors and
terminal outboxes. A new run ID closes/replaces the old managers; leaving the
lobby ends that session.

The input scope is `<run>/referee-input-v1`; the output scope is
`<run>/referee-output-v1`. Clients validate the authenticated current physical host
before treating its output as coming from the stable logical sender `referee`.

Four MPAPI actions carry envelopes:

- `pvp_reliable_event`, `pvp_reliable_ack`
- `pvp_reliable_output`, `pvp_reliable_output_ack`

A checkpoint advertises `reliable_protocol=1`. Clients enable it only for the
matching run and current `_delivery.writer`; a reliable hello/input records peer
capability. First negotiation re-issues referee state through the new outbox,
recovering bootstrap lives/roster messages sent before capability was known.
Old hosts keep legacy inputs. Unknown/legacy recipients keep legacy outputs. Once a client has negotiated the protocol, an unconfirmed replacement
host pauses its pending work rather than falling back to one-shot duplicates.
Mixed-version delivery does **not** acquire the full new guarantees.

Migrated inputs: ready/unready blind, round failure, ante-timer failure, PvP-timer
failure, blind result, ante, new round, furthest blind, skip, ready-check answer,
and ante-skip voucher. Hand scoring retains its specialized wire adapter.

Migrated outputs include lives/team lives, ready checks/start blind, timer-hand
loss, pending death/elimination, round state, round/match outcomes, and
Royale/Nemesis/Manhunt/Teams target/roster/score-board messages. Unrelated lobby,
draft/setup, presentation, replay and other relays have **not** all been migrated.

## Checkpoint barrier and host takeover

The barrier permits one full checkpoint in flight. Later cumulative state
coalesces behind it while staged effects remain ordered. Retries retain the same
checkpoint ID. A socket write, matching ID alone, or arbitrary metadata event is
not confirmation: the entire echoed checkpoint must match. Publication errors
close the gate rather than repeat potentially partial publication.

The current server permits only its current host to set metadata, shallow-merges
top-level keys, and echoes full metadata after accepting a patch. A replacement
host first writes a fresh `_pvp_ref_probe` token without replacing `_pvp_ref`.
Only the matching full echo supplies the authoritative checkpoint to restore.
It blocks processing until the read completes, restores state/cursors/outboxes,
then confirms its own checkpoint before releasing its outputs.

- Failure before server acceptance: restore the older state/cursor; pending input
  retries apply the uncommitted event.
- Failure after acceptance but before host sees the echo: restore the accepted
  state/cursor and retained outputs; do not apply that input again.
- Lost output ACK progress: replay the same output identities. Live recipients
  retain their cursors and suppress duplicate effects.
- A recipient can be ahead of the restored host's output head. The specialized
  output ACK adapter accepts its cumulative cursor only within the confirmed
  output limit, retiring covered restored heads without permitting an uncommitted
  tail to escape. Generic core ACK matching remains strict.
- Missing, wrong-run or invalid recovery state blocks instead of reconstructing
  guessed accepted IDs. Explicit reconciliation can retry an authoritative read.
- Old-host writes are rejected by server authority; clients reject old-host
  actions and old-run envelopes. Rapid host changes invalidate obsolete probes.

This is **live server acceptance, not disk durability**. The inspected server
has no per-checkpoint durable-storage commit or revision CAS. Server-process
failure and malicious-host behavior are not solved here.

## Hand scoring

Committed hand snapshots are captured once; the shared queue owns retries. Wire
round IDs and report revisions remain unchanged. Revision zero is a state query,
not fabricated scoring. Core sequence numbers can differ from report revisions.

Authoritative revisions acknowledge covered sent reports; terminal round state
closes pending delivery before applying lives and then the outcome once.
The terminal `pvp_round_state` includes frozen per-player `scores` and, for Teams,
the `team_scores` used in the decision. These stay with the checkpointed round
through result retries and live host takeover. Clients cache them before applying
lives/outcomes and freeze the current opponent's score for cash-out, independent
of late presentation relays or the three-second HUD count-up. Older hosts without
these optional fields fall back to the last uneased display score.
Reconciliation can replay a confirmed report to recover an outcome produced later.
A full hand-report queue retains the latest unqueued cumulative snapshot without
discarding already queued transitions. Mixed-version rounds keep the legacy wire
without enabling unsafe retries.

## Timer transitions

`pvp_api/timer_sync.lua` sends Start, Pause, expiry and reconnect samples as
`pvp_timer_transition` inputs through the existing critical FIFO. Accepted state,
input cursors and `pvp_timer_state`/`pvp_timer_expired` outputs share the checkpoint
barrier. Countdown ticks remain local; no per-tick timer traffic is added.

Each timer names its starter and timed player, a round-context **generation**, a
unique **id**, a countdown **cycle**, and an increasing state **revision**. Round
boundaries and timer-hand losses retire generations. Boundary outputs carry the
new generations because their delivery can precede the recipient's metadata echo.

- Same-cycle samples only lower remaining time and never resume a paused timer or
  replay Start effects. This deliberately cannot increase an already-too-low copy;
  it is not a wall-clock synchronization protocol or an RTT compensation scheme.
- Explicit Resume after Pause creates a new cycle and preserves legitimate time
  added while paused. Ante expiry validates the old cycle/running state, accounts
  for forgiveness or life loss, and allocates a restart in **one transaction**.
  Last-life expiry stops instead. A stale sample cannot trim a new countdown.
- Pause intent survives Start in flight and an opposite-player expiry race, but
  an old-cycle Pause sample cannot shorten a newly restarted cycle.
- PvP state includes the round, committed scores (not the HUD count-up), and hand
  counts. Delayed states cannot rearm a timer stopped by a newer hand. A state
  ahead of the enemy display relay is held locally until it matches; a deferred
  running sample ages while waiting. Start waits for a matching hand checkpoint.
  PvP expiry waits for the timed player's hand checkpoint, validates its cycle,
  and uses the existing critical hand-loss output. An opponent hand that leaves
  the timed player behind does not invalidate that expiry.
- Local/animation timers keep their local countdown samples; synchronization does
  not overwrite them. Explicit new-cycle restarts retain their reset behavior.

Hello and checkpoints advertise `timer_protocol=1`. Initial negotiation requires
all connected potential hosts to support it; mixed-version lobbies retain legacy
one-shot timer messages. After negotiation, missing or downgraded capability
**retains/blocks** critical work until support returns, rather than dropping it or
sending unknown keys to an older host. Later FIFO inputs can wait behind it.
Hot-swapping to older code mid-run is not transparent compatibility. This remains
an in-memory/live-process protocol, not closed-game recovery.

## Bounds and failure behavior

The server caps action params at 16 KiB and match messages at 64 KiB. The adapter
checks generic envelopes before sequence allocation and reserves framing headroom
with a 60 KiB encoded checkpoint limit. Output queues have a shared 4,096-entry
cap. Impossible writes/overflow fail explicitly and retain/block work; they are
not silently discarded or split into non-atomic state fragments. Capacity faults
currently require intervention, not automatic queue compaction. Retry stalls can
be resumed by reconciliation; permanent callback faults are not blindly retried.

## Verification

Run from the PvP repository root with `texlua tests/unit/<name>_test.lua`.

All **38 PvP unit-test files pass** under LuaJIT 2.1, including:

- **31** ordered-core cases, including frozen/atomic checkpoint export/import.
- **36** transport cases using real MPAPI action instance/dispatch code and SDK
  JSON with a simulated two-hop relay. The 32 seeded fault schedules cover
  **1,536 events** under loss, duplication, reordering and temporary disconnects.
- **8** standalone checkpoint-barrier cases.
- **84** multi-client referee cases with separate live Lua environments and
  serialized simulated server routing/metadata acceptance. Timer coverage includes
  both outage directions, first-frame catch-up ordering, Start/Pause/expiry races,
  forgiveness and last life, checkpoint/takeover replay, paused bonuses, stale PvP
  hand phases, and capability loss/restoration.
- **43** hand-score/round-result cases, plus scoring end-to-end through the
  checkpoint and reliable-output path in the multi-client tests.
- **9** cash-out display cases covering unfinished easing, stale relays, final
  zero/large scores, older hosts, and PvP-marked normal blinds.

Coverage includes lost requests/ACKs/results, FIFO fail/reset/fail, retained
stalls, synchronous callbacks, checkpoint failure windows, stale caches, lost
probes, rapid host changes/host return, cumulative output ACKs, invalid state,
new-run/end-screen lifecycle, asynchronous callbacks, wire bounds, migrated
production callers, mixed versions, and takeover life-state checks for Royale,
Nemesis pairing, Teams and Manhunt. Existing game-rule suites also pass.

These are **simulated-network tests, not live Nakama/game tests**, and not a proof
of every possible failure schedule. Live relay/rate-limit behavior, full in-game
UI/reward verification, and long-running queue/metadata performance still need
validation. Closed-game rejoin and closed-game timer catch-up remain deliberately deferred.
