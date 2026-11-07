# Almanac implementation status

This describes the preserved collection identified in `harvest.md`, not the
clean release base. No release-readiness claim follows from existing unit tests.

| Component | Collection state | Remaining work |
|---|---|---|
| Identity | Almanac display name, Ranked Coming Soon tile | Working competitive entry |
| Deck draft | Neutral start; 2/3/5/7; explicit adapters; 21 eligible deck types; accumulated inspection | Common offers, chosen eligibility contract, live synchronization |
| Deck persistence | Pending/completed state, replay hooks, interrupted acquisition checkpoints | Real multiplayer reconnect/replay validation |
| Shared rules | Server offers/locks/deadline/timeout/wildcard/checkpoint; client reveal/effects/cleanup | Competitive integration, final pool/gates, live validation |
| Capabilities | API exposes server feature versions | Version/availability handling in final mode |
| Competitive enforcement | Not implemented for Almanac | Required deck, fixed baseline, other-queue exclusion, results/rematch |
| Forecast | No finished forecast UI | Implement schedule/status only |
| Ante curve | No custom curve | Deferred; skip for now |

## Important implementation boundaries

- Current deck seeds are player-scoped. Removing the player seed alone does not
  produce common offers after players acquire different decks.
- Shared rules currently require a private two-player lobby and reject ranked or
  game-mode lobbies. They are not enabled by changing the queue tile.
- Shared rules compose with the existing PvP blind, not its scoring referee.
- Temporary cleanup preserves money lost, levels lost and Jokers sold.
- Clock opportunities use a separate lifecycle. Do not generalize the boss-rule
  implementation into that lifecycle as part of extraction.
- Preserve the target base's newer networking/referee/recovery code.

## Detailed source references

Read these at the pinned PvP collection revision, not as target-release contracts:

- `docs/chaos-deck-draft.md`: adapters, unlocks, save/replay and visual semantics.
- `docs/shared-pvp-rules.md`: authority, immunity and cleanup boundaries.
- `docs/history/chaos-collection/docs/chaos-shared-pvp-rules.md` on `chaos-lab`:
  full historical rule table.
- `docs/chaos-clock-runtime.md` and `docs/one-of-each.md`: lab only.

Historical local and live test reports refer to earlier revisions; the release
checklist deliberately remains unchecked until the harvested branch is tested.
