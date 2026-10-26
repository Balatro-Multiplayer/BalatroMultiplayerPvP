# Handover: fold the mutator wall into PvP Practice

## Product direction

- Stephen does not want a separate solo product path. Fold the configurable
  layers/wall into PvP's existing Practice flow.
- The current **CUSTOM SOLO** main-menu entry and `lib/singleplayer.lua` are
  a working inspection/test shell, not the intended final architecture.
- Making Practice accessible without Steam is a separate follow-up. The
  prototype's Steam-free entry demonstrates feasibility, not an agreed design.
- The prototype's normal-loss and save/continue behavior are not automatically
  requirements for Practice. Resolve those semantics rather than inheriting them
  accidentally during integration.

## Bring along

- 32 manual, run-long layer toggles; Sandbox groups; MP-content and Idol choices.
- Balance column: Kind Wraith and Dice Patch. Dice Patch uses `ReworkCenter`,
  retaining vanilla keys: Oops X1.75; Lucky's $20 at 1/10; 8 Ball and Space
  Joker at 1/3. Lucky's Mult roll stays 1/5.
- Layer/setup fixes, including resource floors, idempotence on reload,
  Shared Pockets timing and bounded Polymorph searches.
- MPAPI's accompanying `ReworkCenter` fix: preserve absent/false baseline
  properties and snapshot source keys before applying a variant.

## Evidence and limits

- Real game: Custom Solo 19/19; save/reload 11/11; Dice Patch 36/36.
- Lua and LuaJIT: 222 PvP contract checks; 9 MPAPI baseline checks each.
- Those scenarios validate the prototype shell. Adapt them to the actual Practice
  UI/lifecycle when integrating; they do not yet prove that integration.
- No Clock director/scheduling, forecasts, temporary expiry or grant delivery.
  Manual run-long behavior is not a substitute for the documented Clock cadence.
- Full coverage and known Lovely warnings: `tests/README.md` and
  `.context/layer-port-status.md`.

No merge or push has been performed. Both repositories contain changes that need
to travel together. Installed mod symlinks currently point at this fork for
inspection; they were deliberately left there at Stephen's request.
