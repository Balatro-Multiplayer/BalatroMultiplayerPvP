# Draft: reliable delivery for critical PvP events

> Temporary planning document for the draft PR. Remove this file before final merge.
> No protocol changes are implemented by this commit.

## Problem

Critical events such as `pvp_fail_timer`, `pvp_fail_round`, and `pvp_new_round`
are sent once and can be lost during a disconnect. MPAPI provides correlated
request/response callbacks, but not automatic retries or duplicate-safe processing.
`pvp_api/round_sync.lua` already implements a specialized acknowledgment/retry
protocol for committed hand reports.

## Proposed approach

- Introduce a reusable delivery layer for critical transitions, using stable event
  IDs scoped to the lobby, run, sender, and relevant round or timer instance.
- Keep unconfirmed events pending and retry with bounded frequency. Only an
  acknowledgment of authoritative acceptance should mark an event complete;
  a successful socket write is not enough. Expose unconfirmed delivery to the user.
- Validate scope and ordering before applying an event. Deduplicate accepted
  events and acknowledge retries without repeating their effects. Reject obsolete
  events explicitly: a delayed round reset must not rearm guards for a newer loss.
- Resume pending delivery after reconnect. Define how accepted-event records and
  pending events reconcile with referee checkpoints and host migration before
  enabling retries across takeover. Clear pending state when its lobby/run ends.
- Audit PvP actions by semantics: critical transitions need reliable delivery;
  latest-value updates can be versioned/coalesced; presentation-only signals may
  remain best-effort. Preserve the existing hand-report guarantees and define
  compatibility behavior for older clients.

The abstraction's home (PvP or MultiplayerAPI), wire format, retry limits,
retention bounds, and migration strategy remain design decisions. Retries alone
must not be treated as exactly-once execution or as server-side timer enforcement.

## Planned verification

- Deterministic tests for dropped requests and acknowledgments, duplicates,
  delayed/reordered events, stale scopes, and retry exhaustion.
- Reconnect and host-takeover tests, including an accepted event whose
  acknowledgment was lost, plus lobby/run cleanup and mixed-version behavior.
- Gameplay assertions that lives, hands, round resets, and comeback eligibility
  are neither skipped nor applied twice; in-game disconnect/reconnect testing.

Status: planning only. No implementation tests or in-game testing performed for
this change. Remove this document before the final merge.
