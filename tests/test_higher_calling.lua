-- Real probability, lifecycle and source adapters; engine boundaries are stubbed.
local checks = 0
local function check(ok, message)
	assert(ok, message)
	checks = checks + 1
end
local function near(a, b, message)
	check(math.abs(a - b) < 1e-12, message)
end
local function clone(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in pairs(value) do
		result[key] = clone(item)
	end
	return result
end
PVP = {
	LOBBY = {},
	is_singleplayer = function()
		return true
	end,
}
dofile("lib/chaos_clock.lua")
dofile("lib/chaos_effects.lua")
dofile("lib/chaos_higher_calling.lua")
local C, H = PVP.CHAOS, PVP.CHAOS.HigherCalling
local probabilities = H.boost({
	{ key = "Common", p = 0.7 },
	{ key = "Uncommon", p = 0.25 },
	{ key = "Rare", p = 0.05 },
}, { Rare = 2 })
near(probabilities[3].p, 0.1, "Rare probability doubles, not just its weight")
near(probabilities[1].p / probabilities[2].p, 0.7 / 0.25, "Other rarity proportions preserved")
local editions = {
	{ key = "e_negative", p = 0.003 },
	{ key = "e_polychrome", p = 0.003 },
	{ key = "e_holo", p = 0.014 },
	{ key = "e_foil", p = 0.02 },
	{ key = "none", p = 0.96 },
}
local boosted = H.boost(editions, { e_negative = 2.5, e_polychrome = 3 }, "none")
near(boosted[1].p, 0.0075, "Negative probability is 2.5x")
near(boosted[2].p, 0.009, "Polychrome probability is 3x")
near(boosted[3].p, 0.014, "Holographic unchanged with enough plain mass")
near(boosted[4].p, 0.02, "Foil unchanged with enough plain mass")
near(boosted[5].p, 0.9495, "Boost spends plain probability first")
near(editions[1].p, 0.003, "Baseline data is not mutated")
for _, baseline in ipairs({
	{ { key = "e_negative", p = 0.4 }, { key = "e_polychrome", p = 0.4 }, { key = "none", p = 0.2 } },
	{ { key = "e_negative", p = 0.2 }, { key = "e_holo", p = 0.6 }, { key = "none", p = 0.2 } },
}) do
	local total = 0
	for _, entry in ipairs(H.boost(baseline, { e_negative = 2.5, e_polychrome = 3 }, "none")) do
		check(entry.p >= 0 and entry.p <= 1, "Extreme modifiers remain valid probabilities")
		total = total + entry.p
	end
	near(total, 1, "Extreme probabilities sum to one")
end

G = {
	STAGE = 1,
	STAGES = { RUN = 1 },
	STATE = 1,
	STATES = { BLIND_SELECT = 1, SHOP = 2 },
	CONTROLLER = { locked = false },
	GAME = { round_resets = { ante = 1 }, modifiers = {}, banned_keys = {}, used_jokers = {} },
	P_CENTERS = {},
	jokers = {},
	FUNCS = { cash_out = function() end },
}
Game = { update = function() end }
SMODS = {
	optional_features = {},
	always_scores = function()
		return false
	end,
	calculate_context = function() end,
	add_to_pool = function()
		return true, {}
	end,
	showman = function()
		return false
	end,
	ObjectTypes = {
		Joker = {
			rarities = {
				{ key = "Common", weight = 0.7 },
				{ key = "Uncommon", weight = 0.25 },
				{ key = "Rare", weight = 0.05 },
			},
		},
	},
	Rarities = {},
}
local pools =
	{ Common = { "j_common" }, Uncommon = { "j_uncommon" }, Rare = { "j_rare" }, Legendary = { "j_legendary" } }
for i, key in ipairs({ "Common", "Uncommon", "Rare", "Legendary" }) do
	G.P_CENTERS[pools[key][1]] = { rarity = i }
end
local edition_names = { "e_foil", "e_holo", "e_polychrome", "e_negative" }
for i, weight in ipairs({ 20, 14, 3, 3 }) do
	G.P_CENTERS[edition_names[i]] = {
		weight = weight,
		vanilla = true,
		get_weight = function(self)
			return self.weight * (G.GAME.edition_multiplier or 1)
		end,
	}
end
local shared = {}
get_current_pool = function(kind, rarity)
	for i = #shared, 1, -1 do
		shared[i] = nil
	end
	if kind == "Edition" then
		for _, key in ipairs(edition_names) do
			shared[#shared + 1] = key
		end
	else
		for _, key in ipairs(pools[rarity] or {}) do
			shared[#shared + 1] = (G.GAME.banned_keys[key] or G.GAME.used_jokers[key]) and "UNAVAILABLE" or key
		end
		if #shared == 0 then shared[1] = "j_common" end
	end
	return shared
end
local rolls = {}
pseudoseed = function(key)
	return key
end
pseudorandom = function(key)
	return rolls[key:match("^pvp_higher_calling_(%a+)")] or 0.5
end
pseudorandom_element = function(pool)
	return pool[1]
end
local native_calls, native_edition_calls, fail, guaranteed = 0, 0, false, false
poll_edition = function()
	native_edition_calls = native_edition_calls + 1
	return "native_edition"
end
create_card = function(kind, area, legendary, rarity, skip, soulable, forced, source)
	native_calls = native_calls + 1
	if fail then error("creation fixture error") end
	return {
		key = forced or "native_joker",
		edition = guaranteed and "guaranteed_edition"
			or poll_edition("edi" .. (source or "") .. G.GAME.round_resets.ante),
	}
end
dofile("overrides/chaos_clock.lua")
dofile("overrides/chaos_higher_calling.lua")
local function jud()
	return create_card("Joker", G.jokers, false, nil, nil, nil, nil, "jud")
end
local runtime = C.for_run(true)
check(jud().key == "native_joker", "Inactive Judgement is unchanged")
assert(runtime:activate("higher_calling"))
local director_rng = runtime.state.rng
check(not runtime:activate("higher_calling"), "Higher Calling cannot stack with itself")
rolls.legendary = 0.004999
check(jud().key == "j_legendary", "Legendary chance includes rolls below 0.5%")
rolls.legendary, rolls.rarity = 0.005, 0.91
check(jud().key == "j_rare", "Exactly 0.5% follows ordinary boosted rarity")
rolls.rarity = 0.899999
check(jud().key == "j_uncommon", "Rare's boosted interval starts at 90%")
rolls.rarity = 0.9
check(jud().key == "j_rare", "Rare probability really is 10%, not a normalized 2x weight")
rolls.legendary = 0
G.GAME.banned_keys.j_legendary = true
check(jud().key == "j_rare", "Banned Legendary falls back to ordinary selection")
G.GAME.banned_keys.j_legendary = nil
G.GAME.used_jokers.j_legendary = true
check(jud().key == "j_rare", "Duplicate exclusion is inherited from the actual pool")
G.GAME.used_jokers.j_legendary = nil
pools.Legendary = {}
check(jud().key == "j_rare", "Empty Legendary fallback is not promoted to Legendary")
pools.Legendary = { "j_legendary" }
rolls.legendary, rolls.edition = 0.5, 0.007499
check(jud().edition == "e_negative", "Negative interval is 2.5x baseline")
rolls.edition = 0.0075
check(jud().edition == "e_polychrome", "Polychrome is an alternative edition")
rolls.edition = 0.0165
check(jud().edition == "e_holo", "Polychrome interval has exactly 3x baseline width")
G.GAME.edition_multiplier, rolls.edition = 2, 0.014999
check(jud().edition == "e_negative", "Existing edition modifiers compose before the boost")
G.GAME.edition_multiplier = nil
SMODS.Rarities.Rare = {
	get_weight = function(_, weight)
		return weight * 2
	end,
}
G.GAME.rare_mod, rolls.rarity = 2, 0.7
check(jud().key == "j_rare", "Rarity hooks and run modifiers compose before the 2x chance")
check(runtime.state.rng == director_rng, "Judgement never consumes the director's selection RNG")
SMODS.Rarities.Rare, G.GAME.rare_mod = nil, nil
for _, source in ipairs({ "sou", "wra", "shop", "pack" }) do
	local card = create_card("Joker", G.jokers, nil, nil, nil, nil, nil, source)
	check(card.key == "native_joker" and card.edition == "native_edition", "Other sources are unchanged: " .. source)
end
check(
	create_card("Joker", G.jokers, true, nil, nil, nil, nil, "jud").key == "native_joker",
	"Explicit Legendary rolls remain native"
)
check(
	create_card("Joker", G.jokers, nil, 0.99, nil, nil, nil, "jud").key == "native_joker",
	"Explicit rarity rolls remain native"
)
check(create_card("Joker", G.jokers, nil, nil, nil, nil, "fixed", "jud").key == "fixed", "Forced identity is preserved")
guaranteed = true
check(jud().edition == "guaranteed_edition", "Guaranteed editions are preserved")
guaranteed = false
check(poll_edition("edijud1") == "native_edition", "Ordinary edition calls outside creation are untouched")
fail = true
check(not pcall(jud), "Creation errors still propagate")
fail = false
check(poll_edition("edijud1") == "native_edition", "Creation errors release scoped edition override")
runtime:boundary("blind_end", "1")
runtime:boundary("shop_end", "1")
check(C.has_rule("higher_calling"), "Effect survives blind and shop boundaries")
G.GAME = clone(G.GAME)
check(C.has_rule("higher_calling"), "Saved instance retains the window")
G.GAME.round_resets.ante = 2
Game:update(0)
check(not C.has_rule("higher_calling"), "Ante progression expires the effect")
check(jud().key == "native_joker", "Judgement is native after expiry")
G.STATE = G.STATES.SHOP
assert(C.for_run():activate("higher_calling"))
G.GAME.round_resets.ante = 1
check(not C.has_rule("higher_calling"), "Ante decreases also close the window")
SMODS.optional_features.object_weights = true
check(not C.for_run():activate("higher_calling"), "Unsupported probability engine is visibly ineligible")
SMODS.optional_features.object_weights = false
assert(C.for_run():activate("higher_calling"))
PVP.LOBBY.code = "NETWORK"
check(jud().key == "native_joker", "Network runs are not silently changed")
PVP.LOBBY.code = nil
PVP.is_singleplayer = function()
	return false
end
check(jud().key == "native_joker", "Ordinary runs are not silently changed")
check(native_calls > 0 and native_edition_calls > 0, "Native creation and unrelated edition paths are exercised")
print("Higher Calling: " .. checks .. " checks passed")
