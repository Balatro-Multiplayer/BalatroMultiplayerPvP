# Sandbox historical reference

Historical evidence, not a runtime specification or a proposal to restore cards.
This directory is outside the gameplay loaders in `core.lua`.

## Original intent: testimony, not inference

During the Chaos Clock discussion, the user identified “changing commitments,
not just strength; strange rules, lasting combinations/scars, meaningful decisions
rather than automatic numerical escalation” as Sandbox's original intent.
That is the user's account. Code alone cannot establish the original philosophy,
why each card was removed, or whether a prototype worked in a released game.

Questions for the designer:

- Which cards best expressed Sandbox, rather than merely living in its folder?
- Were consequences meant to arise from purchases and sacrifices, imposed rules,
  or both?
- Which removals were technical casualties versus design rejections?
- Should a successor inherit the philosophy, the actual cards, or both?

## Provenance

Repository: `Balatro-Multiplayer/BalatroMultiplayerPvP`.
Local remote-tracking tips matched GitHub `ls-remote` during this investigation:

| Branch | Tip |
|---|---|
| `legacy/dev` | `053c17ed72ba909f83ae18e1b5936068996be173` |
| `legacy/sandbox/v1` | `3f1d912d9d2ae57f08e4e73b73ea91488e74f4fa` |
| `legacy/sandbox/v2` | `45681d4eb6e24035a14a39e61f2f0fb9f68294ad` |
| `legacy/sandbox/v3` | `428fcc740d9a859fc59a35d9e49b63e3f9c6ec23` |
| `legacy/sandbox/v3-rebased` | `86b43cf8a6020fc1db4d7873df256171829af110` |

`.context/legacy-branches.md` explains the upstream history rewrite: original
and rewritten SHAs can describe equivalent patches without sharing ancestry.

Protecting dev alone is insufficient. Among available remote refs, deletion
`46a88468` is reachable from `legacy/sandbox/v3`, not `legacy/dev`;
`25740604` is reachable from `legacy/sandbox/v1`. Retain those branches too.

## Sandbox v2: the designer's intended reference

The designer clarified that the relevant material is the unhinged v2 Joker set,
already committed into legacy dev, not primarily the deleted v1/Extra Credit
prototypes catalogued below. The first investigation overemphasized deletion
history and underexamined surviving cards.

Verified with `git merge-base --is-ancestor`: both the introduction
`8215b7546f2519ae61d9713f9f0961ad6184d867` ("feat: add sandbox jokers and
new stakes system") and release merge
`e8d48a0dd733639ea24e9851489e6de6d01c4002` (PR #282,
`sandbox/v2-release-candidate`) are ancestors of `origin/legacy/dev`.
No separate branch is needed to recover this release.

The following is a static reading at that release merge. Paths are
`objects/jokers/sandbox/<file>.lua`; this snapshot, not today's definitions,
is the reference for the behavior:

| File / card | V2 behavior |
|---|---|
| `cloud_9` / Cloud 9 | Each eligible scored card has a 1-in-4 chance to become a 9. End-round income pays $1 per nine for the first four, $2 each thereafter. The income engine rewrites the deck. |
| `lucky_cat` / Lucky Cat | Each scored lucky trigger adds X0.25; a 1-in-4 roll also converts that card to Glass, consuming the Lucky enhancement. |
| `vampire` / Vampire | Converts scored enhanced non-Stone cards to Stone for X0.2 each. Existing scored Stones pay $5 each only when no new conversion triggered the earlier return. |
| `juggler` / Juggler | +3 hand size; playing fewer than five cards spends one of those slots. Destroys itself when the bonus reaches zero. |
| `ride_the_bus` / Ride the Bus | Mult gains ramp from +1 to +5 per clean hand. A scored face card destroys the Joker instead of merely resetting it. |
| `loyalty_card` / Loyalty Card | Picks a visible hand type when added; four consecutive plays of it earn X6, then restart the counter. Another hand type resets progress. |
| `castle` / Castle | Locks its suit when acquired; each matching discarded card adds 12 Chips. Unlike vanilla, the suit does not rotate each round. |
| `faceless` / Faceless Joker | $15 for a discard containing at least one Jack, Queen, and King. |
| `constellation` / Constellation | X0.2 per Planet used, but loses X0.2 every round, floored at X1. |
| `satellite` / Satellite | Starts with $1 payout; each Planet adds $1; leaving a shop removes up to $2 of payout. |
| `throwback` / Throwback | X0.25 per lifetime skip plus X0.75 per skip while owned. Owned-skip bonus decays by 0.75 on qualifying round ends without the skip flag. |
| `steel_joker` / Steel Joker | Retriggers played Steel cards, creating tension with their ordinary held-in-hand role. |
| `order` / The Order | X5 for a Straight with no scoring face cards. |
| `misprint` / Misprint | Rolls its Mult on acquisition, potentially negative (-23 to 46, scaled by the probability numerator), rather than rerolling each hand. |

Each listed implementation declares its own `j_<file>_sandbox.png` atlas,
and those named assets remain in both current resolution directories.
The introduction also added art such as Gros Michel, Madness, Pants, and Scary
Face; their asset names alone do not establish corresponding implemented cards.

The release's `localization/en-us.lua` supplies contemporary presentation evidence:
Castle is a "DISCARD-BASED SUIT MARRIAGE"; Loyalty Card says "betray" its hand
and the counter resets; Satellite describes infrastructure falling apart without
constant planetary upgrades; Vampire creates "STONE-BASED CURRENCY".
This supports reading v2 in terms of commitments, conversion, upkeep, and failure
conditions, while the designer remains the source for original intent.

## Deleted cards

Behavior below is a static source reading, not live-game verification.
Recover exact source with `git show <snapshot>:<path>`.

### Early prototypes

Directory: `objects/jokers/sandbox/`.
Source snapshot: `a98d7894c1f752e5b1d904c876ae99b41b757339`
("split up into individual joker files").
Deletion: `25740604355f9b76a99b402cdca80b16c9befbbd`,
"remove junk jokers", Stephen Kirk, 2025-08-27.
Equivalent deletion: `f0a42188`. The title is not a complete design rationale.

| File / key | Behavior | Art |
|---|---|---|
| `chaos.lua` / `chaos_sandbox` | Adds 9,999 free rerolls while owned; subtracts them on removal. | Default atlas `(1,0)` |
| `stencil.lua` / `stencil_sandbox` | XMult = max(1.5, 1.5 × (empty Joker slots + count of **vanilla** `j_stencil`)). Preserve that lookup as written. | Default `(2,5)` |
| `to_the_moon.lua` / `to_the_moon_sandbox` | Persistent market mood reacts to played hands and random moon/crash events; affects reroll/blind-selection money and interest-based payout. | Default `(8,13)` |

No custom atlas is declared for these three. To the Moon begins with
"TODO test and verify!!"; several calls treat `SMODS.pseudorandom_probability`
as a numeric draw while others use it as a predicate. This is an unverified
prototype, not evidence of a working financial subsystem.

### Ten Extra Credit prototypes

Directory: `objects/jokers/sandbox/extra-credit/`.
Introduction: `b2aedee5`, "wip extra-credit".
Source snapshot: `8ddbeddbc8736e874c67dfaf371c0ad99811bdc3`.
Deletion: `46a8846823d2b3a1ec58c73fad1194ef13e0981a`,
"first pass of porting", Stephen Kirk, 2025-12-16.
That commit also added many other ports; deletion does not prove design rejection.

All use `ec_jokers_sandbox`, with zero-based cells below, and credit code to
`extracredit`. Atlas registration credits art to the Extra Credit team.
Do not infer individual artists from neighboring cards.

| File / card | Behavior | Atlas cell |
|---|---|---|
| `compost.lua` / Compost | +2 Mult per three discard callbacks; destroys itself at 30 Mult. Callbacks are not necessarily discard-button presses. | `(8,0)` |
| `corgi.lua` / Toby the Corgi | Consumes a random held consumable on blind selection for persistent +4 Mult. | `(0,2)` |
| `eclipse.lua` / Eclipse | +12 Chips per hand level above baseline, via `MP.EC.eclipse_sum_levels()`. | `(3,0)` |
| `handbook.lua` / Handbook | Persistent +5 Chips for the first play of a poker-hand type in a round. | `(3,1)` |
| `holdyourbreath.lua` / Hold Your Breath | +30 Chips before each hand; discard resets; destroys itself after a hand when Chips are **greater than** 180. | `(8,1)` |
| `purplejoker.lua` / Purple Joker | Accumulates Mult equal to unused hands plus discards at round end. | `(7,0)` |
| `rubberducky.lua` / Rubber Ducky | Transfers up to 3 Chips from each scored card into the Joker by reducing permanent bonus, with rank/enhancement-dependent floors. No restoration hook in this file. | `(4,0)` |
| `tengallon.lua` / Ten Gallon | XMult = 1 + 0.4 per complete $25 held, including dollar buffer; positive-gain guard. | `(2,1)` |
| `turtle.lua` / Turtle | Starts X1; gains X0.2 after non-boss rounds. | `(1,1)` |
| `yellowcard.lua` / Yellow Card | Pays $5 for skipping a booster pack. | `(0,1)` |

Rubber Ducky illustrates a lasting scar: selling it does not restore the card
bonuses in this implementation. Toby trades future consumable use for growth.
Hold Your Breath makes a discard a deliberate reset against self-destruction.
These are design readings, not claims about which cards inspired the designer.

### Seltzer

Path: `objects/jokers/sandbox/seltzer.lua`; key: `seltzer_sandbox`.
Source snapshot: `23e5978e19b444b144f9010dfb94a65e0851d7c8`.
Deletion in dev ancestry: `d8ad379d`,
"remove seltzer; fix quantum mechanics w alloy etc"; equivalent: `242f5f9e`.
Common, $5, ten-hand budget: retriggers played cards once outside PvP bosses,
decrements its budget only outside PvP, destroys itself when exhausted.
Default atlas `(3,15)`; no custom atlas declared.

Deletion searches also find `sandbox/jokers.lua`: its removal split definitions
into individual files, rather than removing another card.

## Disabled is not deleted

At the pinned dev tip, `layers/sandbox.lua` marks these variants out of rotation:
Bloodstone, Cloud 9, Constellation, Faceless, Juggler, Loyalty Card, Lucky Cat,
Magnet, The Order, Photograph, Ride the Bus, Runner, Satellite.
Their files remain.

Alloy's mapping is commented out, but
`objects/jokers/sandbox/extra-credit/alloy.lua` survives: gold counts as steel
and vice versa. Commit `a78c3e34` explicitly describes shelving Alloy and
disabling quantum enhancements.

Ship of Theseus survives too: its removed-playing-cards handler copies removed
cards back into the deck while growing XMult. This changes what destruction does,
not only its reward. Credits: CampfireCollective and steph (code), neatoqueen (art).

## Surviving artwork

The ten deleted Extra Credit cards' atlas is byte-identical at their pre-deletion
snapshot, the pinned dev tip, and current worktree HEAD:

| Path | Git blob |
|---|---|
| `assets/1x/ec_jokers_sandbox.png` | `c87c97bbd6c9f6c31b5144e874fb8653d086d8f1` |
| `assets/2x/ec_jokers_sandbox.png` | `ba77f538e5db2c89f3f3f4be3f710d024a69cc1f` |

Atlas registration specifies 71×95 logical pixels per cell (142×190 at 2x).
Coordinates above locate the art without renaming or duplicating it.
`ec_other_sandbox.png`, ERROR art, individual Sandbox rework PNGs, and
Magnet's `j_magnet.png` also survive in current assets.
This investigation did not establish bespoke art for the early three or Seltzer.

## Preservation plan

This document preserves the inventory, source coordinates, and testimony.
It is **not yet a self-contained source archive**.

Recommended archive: `docs/history/sandbox/`, outside all gameplay loaders.
Store verbatim source as `.lua.txt`, with a manifest of source commit, original
path, blob ID, deletion commit, dependencies, and credits. Include localization,
atlas helpers, and lossless atlas copies with hashes if independence from runtime
assets is required. Preserve bugs and TODOs; modern implementations are separate
work. Never restore historical prototypes into `objects/` merely to archive them.

Also retain an independently stored Git bundle of dev and all four Sandbox
branches. SHA references in a document cannot keep unreachable objects alive.
Branch protection is not a substitute for backup. No bundle, remote archive,
push, or runtime restoration was made during this investigation.

## GitHub protection: pending

Read-only inspection reported `legacy/dev` as `protected: false`.
Ruleset `13932733`, `dev-main-restrict-deletion`, is disabled, targets
`~DEFAULT_BRANCH` and `refs/heads/main`, and has only a deletion rule.
It does not protect this history.

Proposed new repository branch ruleset, requiring explicit approval:

- Name: `Preserve legacy Sandbox history`.
- Enforcement: **Active**, not Evaluate or Disabled.
- Include exact refs: `refs/heads/legacy/dev`, `refs/heads/legacy/sandbox/v1`,
  `refs/heads/legacy/sandbox/v2`, `refs/heads/legacy/sandbox/v3`,
  `refs/heads/legacy/sandbox/v3-rebased`.
- Exclusions: none. Bypass actors: none.
- Rules: **Restrict deletions** (`deletion`), **Block force pushes**
  (`non_fast_forward`).
- Optional separate decision: **Restrict updates** (`update`) would freeze new
  additions too; this stronger restriction is not implicitly approved.

Configure in Settings → Rules → Rulesets → New branch ruleset. Read back the
ruleset and effective branch rules afterward; do not test via destructive pushes.
Administrators who can edit rulesets can still dismantle them: “never prune”
also needs maintenance policy and independent backup.

No settings were changed. Protection remains pending until configured and verified.
