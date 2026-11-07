# Almanac release checklist

Record command, result and all three repository SHAs for each validation run.
Keep unit evidence separate from rendered/live multiplayer evidence.

## Extraction gate

- [x] Target diff contains only chosen features and required dependencies (source review).
- [x] Current upstream networking, recovery, tests and unrelated content retained.
- [x] No Clock scheduler, opportunity hooks or debug mutation controls loaded by Almanac.
- [x] No imported dependency on ignored files, source checkout paths or credentials (source review).
- [x] Draft/backs/identity/shared-rule tests pass in Lua and LuaJIT.
- [x] API capability tests pass; target layer-content and layer-hook tests pass.
- [x] Server typecheck, tests and build pass; bundle regenerated from target source.

Checked extraction gates record offline validation of the harvested prototype,
not proof of the live product gates below. Re-run checks after further changes.

## Product gate

- [ ] Open decisions in `v1.md` resolved and documented.
- [ ] Same three eligible offers, independent picks, all four milestones.
- [ ] Acquisition save/load is exactly-once; reconnect never regenerates offers.
- [ ] Both lock orderings, timeout, duplicate picks and identical reveal.
- [ ] Every PvP from ante 3 drafts rules, including multiple encounters in one ante
  (prototype encounter identity is currently run plus ante).
- [ ] Every shipping boss rule exercised in played hands.
- [ ] Cleanup preserves unrelated effects and permanent consequences.
- [ ] Disconnect before pick, after pick and after resolution; host migration.
- [ ] Actual replay and crash/rejoin during draft and encounter.
- [ ] Required deck and fixed config enforced by competitive mode.
- [ ] Other competitive queues reject Almanac; practice remains available.
- [ ] Forecast and status communicate the approved information.
- [ ] Full two-player entry → match → result → rematch.
- [ ] Controller, reduced motion, localization and rendered layout.
- [ ] Played-match balance review; any scaling change explicitly justified.

Queue activation and deployment require separate authorization.
