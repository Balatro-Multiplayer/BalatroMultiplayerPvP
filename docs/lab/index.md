# Chaos lab

`chaos-lab` preserves the whole experimental collection. `almanac-v1` receives
only selected competitive-mode components. Never merge this entire branch into
the release track.

| Experiment/support | Status | Disposition |
|---|---|---|
| Effect lifecycle, claims, receipts, saved RNG | Implemented local prototype | Preserve for later experiments |
| Manual scheduler/debug controls | Simulated ticks, default off | Lab only |
| Higher Calling + Judgement shader | Implemented, scoped generation hooks | Deferred candidate |
| Everybody Counts / One of Each | Implemented scoring experiments | Deferred candidates |
| Resource/economy recipes | Several executable; six retired from manual wall | Preserve compatibility and tests |
| Short Shelf Life / other pending recipes | Inspectable blockers, not active payloads | Specify before building |
| Mutator wall / Custom Solo | Working experimentation surface | Harvest only minimum test support if needed |
| Dice Patch / content layers / sandbox changes | Separate balance/content work | Not automatically Almanac baseline |
| Scenario runner / packaging | Development infrastructure | Reuse only required pieces |

See `opportunities.md` for future work. Runtime mechanics remain documented in
`../chaos-clock-runtime.md`; do not duplicate the technical specification.
Historical notes live in `../history/chaos-collection/`, never as current scope.

Promote a candidate only with an explicit product decision, mechanics contract,
network/save/replay ownership and validation. A working solo lab is not a
multiplayer implementation.
