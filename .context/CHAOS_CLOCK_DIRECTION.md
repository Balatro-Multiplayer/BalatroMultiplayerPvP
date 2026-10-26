# Chaos Clock: the edge of Mayhem

**Status: direction agreed in discussion; recipe details remain provisional.**
This records an emotional and mechanical direction alongside
[the product design](CHAOS_CLOCK_DESIGN.md) and [effect shortlist](effect-shortlist.md).
It does not change their budgets or register new recipes.

## The attraction is not knowing what this run could become

The player knows Balatro well enough to notice when one of its rules starts behaving
strangely. An unusually generous Judgement, a shop worth fishing for Negatives,
or a reason to deliberately break Glass can redirect the run without replacing it.

**Mayhem should make you suspect something extraordinary could happen, not promise
that everything becomes extraordinary.**

Target: **recognisable rules, unfamiliar opportunities, occasional lasting damage.**

- Preserve the importance of money, slots, hand choice, and the build already made.
- Permit spectacular outcomes. Do not make spectacular outcomes the new minimum.
- Let a rule create temptation before it creates a reward.
- Some events can be hostile or irreversible; they need not all pay compensation.
- Do not turn Mayhem into a promise that every run becomes overpowered.

The desired unknown has three forms:

1. **Unknown arrival:** what will the Clock introduce next?
2. **Unknown result:** the rule is known, but the next Judgement might be extraordinary.
3. **Unknown combination:** familiar effects interact in a way the player has not tried.

**Never conceal what an active rule does.** The uncertainty is in arrival,
results, and combinations, not undisclosed costs or consequences.
Show scope, duration, costs, and permanent consequences accurately.
Qualitative descriptions of improved odds are allowed; exact tuning belongs in
the implementation reference and changelogs, not necessarily the announcement.
Atmosphere must not make rules text less legible or conceal a mechanical change.

The existing `???` slot and first-hand incident cadence concern an event before
its reveal, not permission to hide its behavior after activation. Whether
“never conceal” also removes those pre-reveal windows needs explicit confirmation;
this document does not silently change the product design's cadence.

Stephen's motivation: concealed multiplayer behavior has previously produced bad
experiences and pressure for compensating patches. Do not create that problem
and then remove interesting mechanics to compensate for poor disclosure.

## Cryptid is a reference, not the destination

The upstream [Cryptid README](https://github.com/SpectralPack/Cryptid) calls it
“An unbalanced Balatro mod” and discusses extending the scoring ceiling through
Amulet. Its configurable thematic sets matter too: it is not only bigger numbers.

The local archived copy inspected for this discussion identifies itself as
**0.5.17c**. Its English descriptions include:

- **Wormhole Deck:** start with an Exotic Joker; 20x Negative likelihood; -2 Joker slots.
- **Exponentia:** gains exponential Mult when XMult triggers.
- **Gateway:** create an Exotic Joker and destroy all other Jokers.
- **Hammerspace:** apply random consumables as if they were enhancements to held cards.

Source: that copy's `Cryptid.json` and `localization/en-us.lua`; descriptions are
design evidence, not a verification of its runtime probability calculations.
The archived version need not match upstream main.

Borrow the permission to encounter something strange and the excitement of a
rare opening. Do not assume we need its expanded rarities, scoring operators,
content volume, or scoring ceiling to get that feeling.

### Zalgo at minimum, not a smaller version of Zalgo at maximum

Stephen's aesthetic direction: **frayed edges; a descending gradient; slightly off.**
This remains head-to-head Balatro. Exponential Mult and an overpowered new rarity
ladder are not the intended route; they change the core gameplay loop rather than
just making its edges strange.

The aesthetic distinction is separate from power level. A modest effect can feel
unsettling; a large reward need not introduce a different visual universe.
Keep the familiar game recognisable and let deviations register at its edges.
Specific art, animation, and sound treatments are still to be designed.
“Zalgo at minimum” describes atmosphere, not a requirement for corrupted text.

### Writing: describe the invitation, not the tuning spreadsheet

- Use short, plain statements about what is different and how long it lasts.
- Let familiar things sound slightly unusual. Avoid grandiose power claims,
  faux-corrupted text, and elaborate lore in mechanical descriptions.
- Higher Calling's announcement: **“Judgement produces unusually good Jokers this ante.”**
- Do not list every probability multiplier in the announcement. “Unusually good”
  can remain the identity while its rarity and edition rates are tuned.
- Keep exact candidate values in design/implementation notes and document shipped
  balance changes in changelogs. They are tuning, not the effect's name or promise.
- Qualitative upside is not permission to hide a downside. Costs, destruction,
  restrictions, duration, and persistent consequences must remain explicit.
- Use numbers when they are the useful rule: a cash payout or resource cost is
  different from a list of generation weights. Do not make every effect vague.
- Avoid guarantees: “unusually good” is not “always Rare” or “always editioned.”

The distinction is not simply 4x versus 20x. Increasing every source permanently
can make an exceptional result routine. Increasing one source for one ante can
make an ordinary consumable worth saving, buying, or spending differently.

## Mayhem changes commitments, not just strength

Mayhem can expose a stranger rule, combine it with a lasting rule, or leave a scar.
It should still leave a decision worth making.

Stephen identifies this as Sandbox's original intent, not a new philosophy
invented for the Clock. Historical Sandbox exploration is a separate discussion.

- Good: an announced window makes Judgement unusually promising; choose whether
  to spend money finding Tarots, free a slot, or keep the current build.
- Good: a destruction rule makes an expendable hand attractive.
- Weak: a global payout increase that changes no priorities.
- Wrong direction: automatic escalation until familiar constraints stop mattering.
- Wrong direction: an unrevealed permanent restriction that invalidates the build
  before the player gets a meaningful response.

Manual all-run configuration can be stranger than random mid-run eligibility.
“Works as a toggle” does not mean “safe to spring on someone halfway through.”

## A run becomes a deck

Stephen's proposed mode direction: **do not select a deck; the run becomes one.**
Deck effects become a source of Clock ingredients, including the lasting rules
that gradually define this particular run. This is a mode proposal, not yet a
change to deck selection or to other formats.

The starting state needs an explicit neutral baseline. Recommendation: ordinary
cards and base resources, without silently inheriting a selectable deck's bonus.
Exact baseline and whether this is exclusive to a particular Clock preset remain open.

This gives lasting rules a clearer purpose: not simply stronger temporary effects,
but pieces of an emerging deck identity. Early arrival gives the player time to
build around them. Late arrival changes their value and can make some unsuitable.

### Gradient belongs in the ingredient catalogue

The existing Gradient Deck says cards count as one rank higher or lower **for
Joker effects**. An 8 can satisfy a Joker looking for 7, 8, or 9; this does not
make those ranks identical for poker-hand recognition or permanently change cards.
Source: `objects/decks/BB_gradient.lua` and `localization/en-us.lua`.

- Requested effect: Gradient's adjacent-rank behavior as an all-run toggle,
  a whole-ante Clock rule, or a lasting Clock acquisition.
- Expiry removes the interpretation rule, not rewards already earned under it.
- Existing implementation has special cases; audit those before promising uniform
  behavior across every Joker. Do not copy the hooks blindly into a timed effect.
- This is distinct from permanently converting the physical ranks in the deck.

### All deck effects are candidates, not interchangeable activation hooks

Review the deck catalogue as design material. Do not make every existing deck's
`apply` function callable mid-run and assume it will be reversible.

| Kind of deck effect | Clock treatment to explore |
|---|---|
| Ongoing interpretation, such as Gradient | Ante or lasting rule; changes how existing cards interact. |
| Recurring resource or economy rule | Ante or lasting rule; compose with the current baseline rather than resetting it. |
| Starting cash, cards, or vouchers | An explicit acquisition, not a rule that grants again whenever state is restored. |
| Initial deck composition | Setup identity or an explicitly described one-time transformation; not a temporary rule with an invented undo. |

Tune lasting acquisitions as a combined deck, not isolated bonuses:

- The current lasting-rule cap and family conflicts remain in force pending review.
- Adding deck-derived recipes must not add a second independent event budget.
- A rule's value depends on when it arrives, the existing build, and other rules.
- Preserve non-numerical identities. Gradient need not become “two ranks either
  way” merely because it lasts longer or appears in Mayhem.
- Some full deck packages contain both benefits and costs. Decide deliberately
  whether to preserve that package or author separate ingredients.
- Surface the accumulated run identity together, while keeping temporary rules
  and persistent changes distinct.

Open: should a deckless run receive an identity ingredient immediately, or begin
neutral and acquire its first identity through the ordinary Clock schedule?

## Five candidate ingredients

Cross-Pollination's concept received explicit approval. Higher Calling's ante
opportunity is endorsed; its rarity/edition package remains under discussion.
Breakage Insurance prompted interest in its early-run build-changing potential.
Other names and numbers remain proposals. None are registered recipes.
Each has one core rule, an all-run toggle, and an explicitly bounded Clock window.
Clock expiry stops future applications; it does not reclaim earned cards or levels.

| Candidate | Core rule | All-run toggle | Clock ingredient | Decision it creates |
|---|---|---|---|---|
| **Negative Space** | Naturally generated shop Jokers have 4x their baseline chance of being Negative. Other creation sources and guaranteed editions are untouched. | Every shop. | Announced before stock generation, for one shop or an authored whole-ante variant. | Spend on rerolls for a possible slot-free addition, or protect cash? |
| **Higher Calling** | Judgement produces unusually good Jokers. | Every Judgement use. | One announced ante. A Mayhem rest-of-run variant is tentative, not approved. | Hunt Judgements for strong cards, slot-free additions, or ordinary Jokers made worth keeping by their edition. |
| **Cross-Pollination** | Using a Planet also levels one randomly chosen different poker hand already played this run, once per use. If none qualifies, no bonus. | Every Planet use. | One announced ante. | Specialise normally, or establish a second hand that can benefit? |
| **Breakage Insurance** | Glass has twice its normal break chance; each Glass card actually broken by that check pays $6. Neither unrelated destruction nor merely scoring Glass pays. | Every blind. | One forecasted blind, including its final hand. | Risk a valuable Glass card, or intentionally cash out expendable ones? |
| **Wild Harvest** | After the first discard of a blind, one randomly chosen unenhanced card from that discard gains a random eligible enhancement. No valid target means no change. | Once each blind. | One unforecasted blind, revealed before drawing; an ante variant would repeat once per blind. | Discard useful plain cards to cultivate them, or prioritise the current hand? |

### Higher Calling: narrow source, potentially several improved outcomes

Negative Space's shop scope is a proposed starting point, not a rejection of the
broader “Negatives occur 4x more” toggle.

Stephen proposed bundling rarity and edition boosts: “they're just real good cards
this ante.” He also liked the distinction between better rarity and unusual
editions. The choice is still open, not a rejection of either proposal.

Candidate tuning, not announcement copy. These are alternative playtest packages,
not Calm/Normal/Mayhem strengths. The original multipliers are the upper bound,
not the default.

| Package | Rare chance multiplier | Negative chance multiplier | Polychrome chance multiplier | Legendary chance per Judgement |
|---|---:|---:|---:|---:|
| Restrained | 1.5x | 1.5x | 2x | 0.1% (1 in 1,000) |
| Middle | 2x | 2x | 3x | 0.25% (1 in 400) |
| Upper bound | 4x | 3x | 5x | 0.5% (1 in 200) |

Start with Restrained for the one-ante version. All values are provisional;
baseline rarity/edition behavior still needs verification. An edition-only
comparison remains useful. A lasting version needs separate exposure testing,
not automatic use of the upper-bound package.

Higher Calling can also produce a Legendary. This is a new, rare outcome, not
a multiplier on an otherwise zero chance. The table's Legendary probabilities
are absolute per eligible Judgement use, not conditional on first rolling Rare.
The Legendary replaces the ordinary Joker result; it is not an extra grant.
Use the normal eligible Legendary pool and respect bans and duplicate rules.
If that pool is empty, resolve the ordinary result instead.

Announcement copy can remain “Judgement produces unusually good Jokers this ante.”
Supporting text should disclose the new possibility: “Can create Legendary Jokers.”
Exact rates belong in tuning notes and changelogs.

Recommendation for discussion: keep one Higher Calling family and test a combined
package against an edition-only package. Do not add each tuning candidate as a
separate Clock draw. The combined package sells the promise of unusually good
Judgements; edition-only preserves more ordinary Jokers as interesting outcomes.
Rarity and edition are separate dimensions; Negative and Polychrome are alternative
edition outcomes, not two editions applied to the same Joker.

For the odds proposals:

- “4x chance” should mean four times the relevant baseline probability, capped at
  100%, not four times a weight that is then renormalised to an unrelated rate.
- Define the baseline and composition with existing modifiers before implementation.
  A 1% to 4% change is only an illustration, not an assertion about the game's rates.
- Resolve the Legendary opportunity first; Rare multipliers apply within the
  remaining ordinary rarity selection. Thus the table's Rare multiplier is
  conditional on a non-Legendary result, not an unconditional final probability.
  Within that selection, preserve other eligible non-Rare outcomes proportionally.
  For an edition boost, decide explicitly which outcomes give up probability mass.
- Never overwrite guaranteed outcomes, bypass content bans, or promote empty pools.
- A static toggle and the same Clock family must not silently multiply to 16x.
- Do not call an existing source's zero edition chance “4x more.” Giving that source
  a new edition roll would be a separate, explicitly stated mechanic.

### Breakage Insurance: a tactic or a reason to build differently?

An early announcement, such as ante 2, could make this a run changer.
One forecasted blind mainly creates a tactical cash-out opportunity; it may not
give enough time to acquire Glass and build around the rule.

An announced whole-ante variant would allow some adaptation. A rest-of-run
variant announced early could make Glass production an economic plan, but also
creates a lasting destruction risk. These are distinct exposure proposals,
not approved additions or a reason to increase the payout automatically.
Show both the increased break chance and the permanent loss of broken cards.

### Constraints to settle before promoting any candidate

- Cross-Pollination needs a precise eligible hand list and Planet-copy/retrigger rules.
- Breakage Insurance overlaps Loaded Dice's probability changes; define composition
  or exclude the overlap. Confirm destruction timing and payout exactly once.
- Wild Harvest must respect enhancement bans, preserve other card properties, and
  consume its once-per-blind trigger even when no eligible target exists.
- All candidates need saved trigger state and deterministic source-specific draws.
  None may change the Clock's own selection RNG.
- A useful all-run toggle may be too subtle during a single blind. Give shop,
  consumable, and build-development effects enough exposure to create a choice.

## Questions that determine the direction

1. Does “never conceal” retain the existing pre-reveal `???` slots and first-hand
   incidents, provided all mechanics become explicit at reveal?
2. For Higher Calling, start with the combined package or edition-only?
   Exact multipliers and a possible Mayhem lasting variant remain open.
3. Does early Breakage Insurance mean a whole-ante opportunity or an explicitly
   lasting rule that can redirect the rest of the run?
