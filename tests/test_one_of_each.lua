local checks, active = 0, true
local function check(ok, message)
	assert(ok, message)
	checks = checks + 1
end
PVP = {}
dofile("lib/chaos_clock.lua")
dofile("lib/chaos_effects.lua")
local C = PVP.CHAOS
C.has_rule = function(key)
	return active and key == "one_of_each"
end
SMODS = {
	has_no_rank = function(card)
		return card.rankless
	end,
	never_scores = function(card)
		return card.excluded or false
	end,
}
G = { play = { cards = {} } }
dofile("overrides/chaos_one_of_each.lua")
local function card(rank, rankless)
	return {
		rankless = rankless,
		get_id = function()
			return rank
		end,
	}
end
local a, b, c, d, e = card(14), card(14), card(14), card(14), card(14)
G.play.cards = { a, b, c, d, e }
check(not SMODS.never_scores(a), "Leftmost identical card remains eligible")
for _, duplicate in ipairs({ b, c, d, e }) do
	check(SMODS.never_scores(duplicate), "Later identical cards cannot score")
end
G.play.cards = { e, a, b, c, d }
check(not SMODS.never_scores(e) and SMODS.never_scores(a), "Reordering changes the survivor")
a.debuff = true
G.play.cards = { a, b }
check(SMODS.never_scores(b), "Debuffed first card still consumes its rank")
local stone1, stone2 = card(14, true), card(14, true)
G.play.cards = { stone1, stone2, b }
check(not SMODS.never_scores(stone1) and not SMODS.never_scores(stone2), "Rankless cards are exempt")
check(not SMODS.never_scores(b), "Rankless cards do not consume a rank")
G.play.cards = { card(2), card(3), card(4), card(5), card(6) }
for _, distinct in ipairs(G.play.cards) do
	check(not SMODS.never_scores(distinct), "Distinct ranks remain eligible")
end
check(not SMODS.never_scores(card(2)), "Cards outside the played hand are unaffected")
G.play.cards = { a, b }
active = false
check(not SMODS.never_scores(b), "Inactive rule preserves duplicate scoring")
b.excluded = true
check(SMODS.never_scores(b), "Native exclusions are preserved")
active = true
b.excluded = false
-- Mirror SMODS' final membership rule: never_scores wins over all-card scoring.
local count = 0
for _, played in ipairs(G.play.cards) do
	local splashed = true
	if splashed and not SMODS.never_scores(played) then count = count + 1 end
end
check(count == 1, "Splash and Everybody Counts cannot restore duplicates")
local state = C.new_state("ONEOFEACH")
local runtime = C.runtime(state, {
	allowed = function()
		return true
	end,
	apply = function()
		return {}
	end,
	remove = function() end,
})
assert(runtime:activate("one_of_each"))
check(state.active[1].key == "one_of_each", "Available as an executable recipe")
runtime:boundary("shop_end")
check(#state.active == 1, "Unrelated boundary does not expire rule")
runtime:boundary("blind_end")
check(#state.active == 0, "Expires at blind end")
print("One of Each: " .. checks .. " checks passed")
