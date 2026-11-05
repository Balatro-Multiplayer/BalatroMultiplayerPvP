# Shared PvP rules prototype

Private two-player server lobbies only. Host: **Lobby Options → Shared PvP
rules → On**, before starting. Default Off; ranked/public matches unchanged.
The toggle is disabled unless Nakama advertises `shared_pvp_rules: 1`.
Requires the matching API and server changes; no production deployment is implied.

From ante 3, both players ready as usual, then have 10 seconds to privately
choose one of three rules. No choice means a random offered rule. Both choices
apply to both players for that PvP. Matching choices keep the rule once and add
a distinct eligible wildcard. No pair exclusions or build-dependent protections.

Pool:

- Ante 3: Manacle, Psychic, House, Club, Goad, Window, Head, Glass Cannon,
  Tooth, Arm.
- Ante 4: add Verdant Leaf.
- Ante 5: add Hook, Plant, Water.
- Needle is excluded. The historical full rules are in
  `docs/history/chaos-collection/docs/chaos-shared-pvp-rules.md`.
  Final launch scope is governed by `docs/almanac/v1.md`.

## Authority and ownership

- Existing host referee detects both-ready and requests `pvp_rules_open` instead
  of starting the blind. Nakama owns offers, immutable locks, the deadline,
  timeout rolls and duplicate resolution.
- `pvp_rules_pick` and `pvp_rules_sync` are intercepted before normal relay.
  A pick is never forwarded to the opponent, even if its envelope targets `*`.
- Offers go only to their recipient. Picks stay out of public snapshots/metadata.
  Server-generated offers/results use the existing host-referee envelope identity;
  clients cannot emit `pvp_rules_offer` through the relay.
- Server RNG is private to the draft, seeded by run ID and encounter ante;
  no gameplay RNG or global random calls. Rule catalogue/ante gates are explicit
  in both Lua and TypeScript.
- Server checkpoints retain offers, locks and RNG. Downtime shifts the deadline;
  ordinary disconnects do not pause it. Rejoin requests the existing offer/result.
  Host migration does not move or regenerate the server-owned draft.
- Resolved `pvp_start_blind` carries the rule pair; the client records `shared_rules`
  before the usual blind-start/countdown path. Duplicate delivery is idempotent.
  The rule descriptions are revealed during that countdown and named on the blind.
- POV replay prepares the recorded pair, never rerolls it; opponent replay events
  do not apply the opponent's rules again to the POV.

## Effect boundaries

The PvP blind remains the PvP blind. Rules do not replace its target or scoring
referee. Hand/discard restrictions adjust encounter balances, not `round_resets`.
Manacle records its size delta; expiry adds that delta back rather than restoring
an old snapshot. Recalculation removes only these debuffs, preserving other owners.
Card/hand debuffs and House use SMODS context arbitration, including existing
immunity/prevent flags; there are still no offer-level pair protections.

Defeat/cash-out or leaving the run cleans up. Money lost, hand levels lost and
Jokers sold are not refunded. Verdant Leaf clears locally only after a Joker sale.
Hook uses the forced-discard path and discards at most two held cards.

Prototype choice: disabling the PvP blind also stops its shared rules and restores
Manacle's capacity. It does not refund already consumed resources or consequences.
Rerolling a boss does not redraft the shared choices. Existing manual Glass Cannon
is independent: enabling both currently compounds their scoring multipliers.

## Checks

PvP root:

```sh
lua tests/test_shared_rules.lua
luajit tests/test_shared_rules.lua
```

API root:

```sh
lua tests/test_server_features.lua
luajit tests/test_server_features.lua
```

Server root (Corepack supplies the pinned pnpm):

```sh
corepack pnpm --filter bmp-nakama-modules typecheck
corepack pnpm --filter bmp-nakama-modules test
corepack pnpm --filter bmp-nakama-modules build
```

Offline tests exercise real relay reducers, hooks and UI/action callbacks with
engine boundaries stubbed. They do not establish rendered fit, played-hand
scoring, live rejoin or two-client synchronization.

Before release, run two clients against the matching server and check:

- Ante 2 bypass; ante 3/4/5 eligibility; both lock orderings; timeout at 10 seconds.
- Matching/distinct picks; no pair protections; exact same reveal on both clients.
- Every rule in a played PvP, with scoring, card debuffs, sales and forced discards.
- Cleanup into the next shop/blind; no permanent-resource drift.
- Disconnect before/after locking, after resolution, and host migration.
- Actual replay and crash-rejoin during selection and during the affected blind.
