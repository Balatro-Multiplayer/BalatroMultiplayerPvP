# Draft PR: Fix PvP cash-out showing an unfinished opponent score

## Branch and base

- Head: `fix/pvp-cashout-final-scores`
- Intended base: `fix/pvp-event-reliability` (`5680d1c` when this branch was created)
- This is a follow-up to the event-reliability work, not a replacement for it.
  Review the cash-out changes against that branch; a comparison against `main`
  currently includes the unmerged reliability work as well.

## Summary

Use the referee's committed final scores on the PvP cash-out screen instead of
sampling the opponent's animated score counter. Carry the scores alongside the
round outcome and lives so the display explains the decision that actually
settled the round.

This changes result presentation, not score-comparison or life-loss rules.

## Problem

The opponent's HUD score counts up over three seconds. Previously, cash-out
copied that counter into `G.GAME.blind.chip_text` when its blind row was created.
If the animation had not finished, the copied value was too low and stayed frozen
even after the counter reached the real score.

A reproduced example:

- Local final score: **6,673**.
- Opponent final score: **8,000**.
- Opponent's animated counter when cash-out opens: **462**.
- The referee correctly deducts a life from the local player, but cash-out shows
  **462**, making the result look reversed.

This reproduces a mechanism consistent with the reported screenshot; it does
not establish the opponent's actual final score in that particular match.

## Changes

### Referee result snapshot

- Freeze canonical per-player score text when the referee commits a round outcome.
- Include optional `scores` in `pvp_round_state`.
- For Teams, include optional `team_scores` containing the exact sums used by the
  team-comparison decision, including ties and final-life eliminations.
- Keep these values in the existing checkpointed round record so result retries,
  archived rounds, and live host takeover preserve the same snapshot.

### Client result application

- Copy final scores into `PVP.GAME.round_result` before applying any life or
  outcome handlers, which can synchronously trigger UI transitions.
- Pin the displayed opponent score when the result arrives; later target changes
  or presentation relays cannot alter this cached value.
- Clear the cached result at the start of the next PvP round, including a switch
  back to a legacy host.

### Cash-out display

- Use the cached referee score for both Nemesis and other PvP-marked blinds.
- For hosts that do not provide final score fields, use the last received
  non-animated opponent score rather than the unfinished HUD counter.
- Leave ordinary non-PvP blind targets and other cash-out rows unchanged.

## Compatibility and scope

- The existing round protocol and reliable transport carry the additional fields;
  no new action type or protocol-version bump is introduced.
- Older hosts without the optional score fields still deliver their outcomes.
  Their fallback remains best-effort: it cannot recover a display relay that was
  never received.
- Full correctness of the frozen cash-out score requires the updated host and
  client result/UI code.
- Host-change coverage is for the existing live-process checkpoint recovery.
  Closed-game relaunch, server-process failure, and restart durability are not
  added by this fix.

## Validation

Run from the repository root:

```sh
for test in tests/unit/*_test.lua; do
  texlua "$test" || exit 1
done
git diff --check
```

Verified on **2026-11-04**:

- **All 37 Lua unit-test suites pass**.
- **9 cash-out display cases** exercise unfinished easing, a stale display relay,
  final zero/large scores, older-host fallback, PvP-marked normal blinds, and
  unchanged non-PvP/other-row rendering.
- The **43 round-sync cases** include frozen scores across retries, score-text
  precision, cache-before-handler ordering, target changes, duplicate results,
  cache reset, older-host results, team totals, archived rounds, and checkpoint
  takeover.
- The existing **39 multi-client reliable-referee cases** pass, with added
  assertions that final scores and the correct opponent score arrive through
  serialized reliable outputs and host takeover both before and after server
  checkpoint storage.
- `git diff --check` passes.

These are unit and simulated-network tests, not live Nakama/game verification.

## Before marking ready

- [ ] Verify in a live two-player match that immediate cash-out displays the
      opponent's final score while its HUD counter is still counting up.
- [ ] Verify a Teams cash-out shows the opposing team's final aggregate.
- [ ] Exercise an updated client with a host that omits the new score fields.
- [ ] If the reliability branch merges first, retarget/rebase this branch onto
      the updated `main` and rerun the suites.
