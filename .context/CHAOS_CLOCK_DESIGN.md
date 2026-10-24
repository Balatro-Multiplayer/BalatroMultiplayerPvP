# Chaos Clock: product design

**Status:** agreed product direction, with initial playtest numbers.
This describes the intended game, not a completed feature.

The Clock and mutator wall are still being ported to MultiplayerPvP. The local
`layers/chaos_taste.lua` file contains some executable effect definitions and
explicit stubs. It does not select, schedule, announce, or expire events.

## 1. What the Clock should feel like

An ante can have a theme. A blind can have a rule worth preparing for or skipping.
Occasionally, the first drawn hand produces an incident.

Most effects should offer opportunities, change decisions, or introduce weirdness.
Hostile effects belong too, especially in Mayhem. They should change how you play,
not casually make the required score unreachable.

**Higher Chaos does not mean multiplying every number.**

- **Calm:** occasional opportunities and manageable disruptions.
- **Normal:** more active rules, ante identities, and occasional light lasting changes.
- **Mayhem:** stranger situations, rare structural commitments, and some corruption.

An effect can have exactly the same strength in all three presets. The director
can change its frequency, timing, duration, or eligibility instead.

### Examples of the distinction

- Waste Not pays **$1 per unused discard**, not $1/$2/$3 by preset.
- Glass Cannon keeps **X4 Mult and −2 hands**. Normal offers one forecasted blind;
  Mayhem can make it the whole ante.
- Eeeee always freezes **40% of eligible RNG poll keys** when active.
- Bigger Shop is a legitimate small numerical exception: +1 slot normally,
  randomly +1 or +2 on Mayhem.
- A run without interest is a possible Mayhem corruption, not automatically a
  restriction that needs a compensating gift.

## 2. When effects happen

Activation, reveal, and expiry are separate properties. Tell the player all
important consequences of a forecasted effect before they commit.

### First-hand incident

Reveal and execute after the blind's first hand has been drawn, before play.
Do not execute again on later draws or when loading the same saved blind.

Examples: gain cash, gain a Fool, change a card's suit, receive a Negative Magnet.

An instant is finished once it happens. Its consequences can remain:
a transformed card stays transformed, and a granted card remains yours.
That does not make the incident an ongoing run-long rule.

An incident can also create a rule **for this blind**, such as Paid Overtime.
There is no separately authored "surprise for the rest of the ante" cadence.

### Forecasted blind rule

Show the actual rule at blind selection. Activate only if that blind is played.
Expire after its completion, after relevant end-of-round payouts.

Skipping avoids the effect and consumes that named slot's forecast.
It must not transfer to the next blind the player chooses to play.

Examples: Glass Cannon, Blind Poker, All In.

### Shop-local rule

Announce on entering the shop, before generating affected stock or making purchases.
Expire on leaving that shop.

Examples: Bigger Shop, local Inflation, a free first reroll.

### Shop-prepared encounter

Announce and activate at shop entry. Let the player shop around the coming rule.
Continue through the immediately following named blind, including its round payouts.
Expire before the following shop. Skipping that blind also ends the rule.

Examples: Waste Not, Discard Dividend.

Before the first shop exists, these effects are not eligible. Do not grant an
extra encounter draw just because the player reaches another shop.

### Whole-ante theme

Announce at the ante boundary, before the first decisions belonging to that ante.
Keep it until the next ante boundary, including shops inside its window.

The shop reached after an ante increase belongs to the new theme. End the old
theme and resolve the new one before that shop is generated.

Examples: Eeeee, Working Capital, Mayhem Glass Cannon.

### Lasting change

An explicitly authored variant announced at an ante boundary and retained for
the rest of the run. Never infer permanence from an effect's severity.

Examples: +1 discard each round, or a possible Mayhem run-long Inflation rule.
A strong blind effect does not automatically become a strong permanent effect.

### Run-start identity

A curated configuration chosen before run and pool creation. It establishes a
different version of the run rather than surprising the player halfway through.
Show the package before the run's first decision.

Examples: Kind Wraith replaces regular Wraith; No Uncommons; a curated Joker
replacement package. These do not consume a later ante or incident slot.

Manual wall selections remain supported regardless of random Clock eligibility.

## 3. Give the director a budget, not one roll per recipe

Adding recipes should increase variety, not multiply event frequency.

These are **starting playtest values**, not final balance promises:

| Opportunity | Calm | Normal | Mayhem |
|---|---:|---:|---:|
| Ante slot occupied, once per ante | 45% | 65% | 85% |
| Encounter slot occupied, per named blind | 20% | 35% | 50% |
| First-hand incident, per played blind | 8% | 16% | 26% |
| Successful ante draw uses a lasting variant | 0% | 6% | 12% |
| Maximum active Clock-created lasting rules | 0 | 2 | 3 |
| Run-start identity package | 0% | 0% | 10% |

- At most **one whole-ante theme** at a time.
- At most **one encounter rule per blind**. Forecasted and shop-origin rules share
  this budget; a starting split is 60% forecasted / 40% shop-origin when both qualify.
- At most **one first-hand incident** per played blind, with plenty of blanks.
- An incident that creates an encounter rule cannot add a second encounter rule.
  If that slot is occupied, exclude such incidents rather than replacing the forecast.
- A lasting acquisition replaces that ante's temporary theme draw. Existing
  lasting rules can remain active underneath a later theme.
- If conflicts, cooldowns, or missing implementation leave no eligible choice,
  leave a blank. Do not force a reward as compensation.

Ordinary selection mix, after eligibility:

| Character | Calm | Normal | Mayhem |
|---|---:|---:|---:|
| Opportunity / buff | 60% | 45% | 30% |
| Tradeoff / weird rule | 35% | 40% | 45% |
| Hostile restriction | 5% | 15% | 25% |

These are targets, not quotas that override safety or force every event to appear.
Rare wildcards use their own limits within the incident budget.

## 4. The existing wall catalogue

Unless stated otherwise, a blank difficulty means "not randomly selected there."
It does not remove the player's manual wall option.

### Economy and shopping

| Effect | Intended Clock behavior |
|---|---|
+| Inflation | One shop: each purchase raises prices by $1 within that shop. Leaving restores the prior price baseline, without refunding urchases. |
+| No Interest | Normal: one announced ante without interest. Mayhem: same temporary rule; run-long corruption remains a tentative andidate. |
| Discard Tax | Normal: forecasted blind, $1 per discard. Initial Mayhem candidate: $2 per discard for one blind; no permanent version. |
+| Frugal / Waste Not | One family, not two draws. $1 per unused discard. Prepared encounter; Mayhem can use an ante or light lasting ariant. |
| Kind Wraith | Run identity: replace Wraith with the existing Kind Wraith content. Not a temporary pool hot-swap. |
| Bigger Shop | This shop, before stock generation. +1 slot; Mayhem chooses +1 or +2. |
| Spartan | Normal/Mayhem forecasted Small or Big Blind with no blind payout. Never remove the boss payout by surprise. |
| Pricey Packs | This shop: initial Normal +$1 / Mayhem +$2 proposal. This is a local price variant, not a universal scaling rule. |

**Inflation variants:** start with shop-local. Run-long accumulation across all
future shops is a separate Mayhem structural candidate. "Only this shop creates
price increases, but those increases persist forever" is parked, not scheduled.

### Scoring, information, and structural effects

| Effect | Intended Clock behavior |
|---|---|
+| Blind Poker | Normal/Mayhem: all cards face down for one forecasted blind. No longer duration on Mayhem. Starting cooldown: two ntervening antes before the family can return. |
+| Dead Cards | Rare Mayhem-only forecasted non-boss blind initially. Played cards become debuffed; existing damage remains after the ctivation window ends. |
+| No Takebacks | Normal/Mayhem: new shop Jokers are Eternal, visibly marked before purchase. Rare Mayhem lasting version is a structural andidate. |
| Heavy Pockets | Whole ante: initial Normal −1 hand size per $20 / Mayhem per $10 proposal. Expiry restores only the size it removed. |
| Shared Pockets | Mayhem run-identity/lasting structural candidate. Hold random mid-run activation until safe conversion exists. |
+| Instability | Forecasted blind. Initial Normal 25%-difference / Mayhem original full-difference proposal, preserving Chips ≥0 and Mult 1. |
| Glass Cannon | X4 Mult, −2 hands, minimum one. Normal: forecasted blind. Mayhem: whole ante. Not in Calm's random pool. |
| Eeeee | Whole ante; always 40% of eligible poll keys. Preset changes frequency, not freeze percentage. No lasting version initially. |
+| Polymorph | Mayhem first-hand incident. Single same-rarity Joker transformation and mass transformation are distinct rare variants. anual Polymorph Spam retains its authored behavior. |
| Cash Ceiling | Hold out of random selection pending redesign. Keep manual option; do not randomly impose impossible early scoring. |

The remaining numeric proposals above are effect-specific playtest candidates.
They are not instructions to manufacture three strengths for every effect.

### Restrictions and content identities

| Control | Treatment |
|---|---|
| No Easy Money | Manual setup; candidate rare Mayhem start identity. |
| No Uncommons | Manual setup; candidate rare Mayhem start identity. |
| No Red Seals | Manual setup only. Hold out of random Clock selection. |
| Small World | Manual/start identity candidate. No surprise mid-run 75% pool cull initially. |
| MP Jokers Default/On/Off | Setup content policy; random effects must respect it. |
+| Sandbox rotation / Encore / Extra Credit / Idol variants | Setup content choices, preserving compatibility restrictions. Not temporary lock effects. |
| Base content / Glass-card variant / timer variants / PvP timer | Setup only initially. No surprise timer changes. |
| Chaos Clock preset | Director configuration. Cannot select itself. |

The proposed Kars sell-Joker replacement package belongs with run identities.
Verify its PR and exact membership first; preserve Let's Go Gambling as discussed.
Do not invent six card definitions from the package description.

## 5. New recipes and authored variants

These are fixed cores. Additional duration choices must be explicit, not inferred.

| Recipe | Core behavior | Exposure |
|---|---|---|
| Second Wind | +1 hand | Calm/Normal blind; Mayhem whole ante. Separate Mayhem lasting +1 variant. |
| Fresh Start | +1 discard | One blind. Separate Normal/Mayhem lasting +1 variant. |
+| Waste Not | $1 per unused discard | Same family as Frugal. Prepared encounter; Mayhem ante theme; separate Normal/Mayhem lasting ariant. |
| Shop Subsidy | Gain $5 | Shop-entry instant; same amount on every preset. |
| Pocket Change | Gain $3 | First-hand incident; same amount on every preset. |
| All In | +1 hand, −1 discard; preserve floors | Calm/Normal forecasted blind; Mayhem whole ante. |
+| Paid Overtime | +1 hand, no unused-hand payout | First draw through this blind's payout, all presets. Never surprise for the rest of the nte. |
| Discard Dividend | +1 discard; $1 per use; $2 per unused discard | Calm/Normal prepared encounter; Mayhem whole ante. |
| Working Capital | +1 hand each round, no interest | Normal/Mayhem whole ante; separate Mayhem lasting variant. |
| Free first reroll | One free reroll | Just this shop, all presets. Implementation pending. |
| Gold Rush | Gold Seal on one drawn card | First-hand incident, all presets. |
| Blue Hour | Blue Seal on one drawn card | First-hand incident, all presets. |
| Red Letter Day | Red Seal on one drawn card | Rare incident. Mayhem: 1-3. |
| Suit Drift | One drawn card changes to a rolled suit | First-hand incident. |
| Suit Storm | Whole drawn hand changes to a rolled suit | Separate Mayhem incident; not an arbitrary five-card limit. |
+| Seal the Deal | Random eligible seal on 1 / 2 / 3 drawn cards | Original event; retain as an effect-specific count variant for initial esting. |
+| Touch-Up | Random eligible enhancement on 1 / 1 / 2 drawn cards | Original event; retain as an effect-specific count variant for initial esting. |

Two **unapproved exploration ideas**, not active catalogue commitments:

- Reroll debt: first reroll free, later rerolls cost an extra $1 this shop.
- Sealed fate: explicitly replace a card's existing seal, with a newly rolled seal.

## 6. Gifts can be silly without becoming an allowance

All of these are first-hand incidents. Their chances below are **absolute chances
per eligible played blind**, included inside the total incident budget.
They are not probabilities to multiply by another surprise roll.

| Incident | Calm | Normal | Mayhem |
|---|---:|---:|---:|
| One ordinary Fool | 2% | 3% | 4% |
| Fistful of Fools: three ordinary Fools | — | — | 0.3% |
| One Negative Death | — | 0.2% | 0.5% |
| One Negative Magnet | — | — | 0.5% |
| Single-Joker Polymorph | — | — | 1% |
| Mass Polymorph | — | — | 0.2% |

The remaining incident probability belongs to ordinary eligible events.
Do not independently roll every rare event and allow several to fire together.

### Fool delivery

- Do not require a previously used Tarot/Planet. An unhelpful Fool is still a Fool.
- Do not silently cancel an announced grant because the consumable tray is full.
- Fistful of Fools really means three cards, not a label for a one-card substitute.
- **Open implementation choice:** overflow, queued delivery, or another explicit
  mechanism. Keep the grant pending until its delivery behavior is implemented.
- Content bans still apply. No grant event silently bypasses the selected rules.

### Negative Magnet

- Fresh solo Practice cannot randomly roll Animal Magnetism.
- Live multiplayer can grant the existing Magnet with Negative edition.
- Playback/rejoin reproduces the recorded grant and exact recorded multiplayer
  interaction, including the copied Joker's serialized state.
- Do not require a live opponent during playback, choose a fresh replacement,
  or substitute a solo reward. Reuse earlier BMP replay work where applicable.
- Grant and replay integration remain stubs.

## 7. Rules that keep it understandable and reproducible

### Forecasts and surprises

Forecasts show the actual encounter rule before play/skip. First-hand incidents
stay hidden until the first draw. A hidden incident that creates a restriction
should be manageable for that blind, not invalidate several future encounters.

The HUD separates upcoming effects, active temporary rules, and lasting rules.
Show expiry in ordinary language: "this shop", "next blind", "this ante", or
"rest of run". State persistent consequences even when the triggering rule expires.

### Conflicts and repetition

- Static wall selections and inherited content count as already active.
- Group aliases and variants by family: Frugal/Waste Not, short/lasting variants,
  and single/mass Polymorph must not gain extra draw weight merely from duplication.
- Do not stack overlapping runtime owners until composition and expiry are safe.
  Clamped hand/discard deltas are particularly unsafe to restore out of order.
- A lasting family cannot repeatedly accumulate copies. Respect the lasting cap.
- Bans, compatibility, unavailable targets, and pending implementations affect eligibility.
- Ineligible rare incidents leave their probability blank; they do not become
  another gift. The precise selection procedure is still to be derived.

### Determinism, saves, and replay

Use the run's Clock seed, feature name, ante, and named Small/Big/Boss slot.
Skipping must not shift later selections. Shop rules belong to a stable named
encounter, not a counter that varies with visits or rerolls.

Do not let Eeeee alter the Clock's own draws. Reserve persistent selections
deterministically so divergent skip paths do not change future eligibility.

Save active windows, remaining state, forecasts, and consumed incidents. Loading
must neither reroll nor repeat a grant. Restore deck/stake baselines and only the
actual clamped resource changes when temporary effects expire.

Replay/rejoin restores configuration before pools and run creation. Identical
configuration must yield identical Clock behavior; recorded multiplayer responses
reproduce opponent-dependent consequences rather than simulating a new opponent.

**Unresolved:** the Clock seed policy when different player seeds are enabled.
Do not claim multiplayer parity until this is decided and tested.

## 8. What is decided, and what remains work

**Pinned direction:** cadence meanings, fixed effect identities, independent rarity,
forecast/skip agency, explicit lasting variants, Mayhem corruption, and exact MP replay.

**Playtest knobs:** event budgets, category mix, rare rates, Blind Poker cooldown,
the identity draw rate, and the few explicitly numerical variants.

**Still tentative or held:** permanent No Interest; run-long Inflation and No
Takebacks; safe mid-run Shared Pockets; Cash Ceiling redesign; optional reroll/seal
ideas; exact identity packages and their frequency mix.

**Still to implement:** the director/selection algorithm, scheduler, reveal/HUD,
safe shop pricing/size hooks, grant delivery, full catalogue integration,
run-start identities, and recorded multiplayer/rejoin parity.

### Acceptance examples

1. Normal Glass Cannon is forecast before a blind. Skip it: no hand reduction
   occurs and the next blind does not inherit it.
2. Mayhem Glass Cannon is announced for an ante at X4/−2, not a larger multiplier.
3. Local Inflation raises prices during one shop and restores the prior pricing
   baseline on exit. Spent money is not refunded.
4. Waste Not pays $1 per unused discard on every preset. Only exposure changes.
5. Paid Overtime arrives after the first draw and ends after that blind's payout,
   not at the next ante. It cannot add a second encounter rule.
6. Eeeee uses 40% when active but cannot corrupt the Clock's deterministic forecast.
7. A Fool can arrive without a useful prior card to copy. Full capacity cannot
   silently erase the promised grant.
8. A replay of Animal Magnetism reconstructs the recorded Negative Magnet and
   opponent-dependent result without a live connection or replacement reward.
9. Adding ten recipes does not increase the director's occupied-slot probabilities.
10. Saving and loading an active blind never grants its incident twice.
