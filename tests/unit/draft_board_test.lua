--[[
  Draft board test.

  PVP.SETUP.draft_board turns the ruleset's allowed decks and stakes into the
  Draft's tiles: 9 by default, at most 4 per stake and 3 per deck, no repeated
  (deck, stake) pair, at least one White tile, sorted by stake then by the
  game's deck order. The Draft config builds its pool with it and shows the
  tiles in PVP.SETUP.draft_tile_order.

  Run from the repo root:
    luajit tests/unit/draft_board_test.lua
]]

PVP = { DECK = {}, id = "MultiplayerPvP" }
MPAPI = {}
G = { FUNCS = {} }
function localize(k)
	return k
end

dofile("pvp_api/setup.lua")
local S = PVP.SETUP

-- Deterministic LCG in [0,1) so runs are reproducible.
local function make_rng(seed)
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

local failures = 0
local function check(cond, msg)
	if cond then
		print("PASS: " .. msg)
	else
		failures = failures + 1
		print("FAIL: " .. msg)
	end
end

-- The game's deck order: vanilla as the collection lists them, then PvP's.
local DECKS = {
	"b_red",
	"b_blue",
	"b_yellow",
	"b_green",
	"b_black",
	"b_magic",
	"b_nebula",
	"b_ghost",
	"b_abandoned",
	"b_checkered",
	"b_zodiac",
	"b_painted",
	"b_anaglyph",
	"b_plasma",
	"b_erratic",
	"b_challenge",
	"b_mp_orange",
	"b_mp_violet",
	"b_mp_cocktail",
}
local MP_ID = { b_mp_orange = true, b_mp_violet = true, b_mp_cocktail = true }
G.P_CENTER_POOLS = { Back = {}, Stake = {} }
for _, k in ipairs(DECKS) do
	G.P_CENTER_POOLS.Back[#G.P_CENTER_POOLS.Back + 1] = { key = k, mod = MP_ID[k] and { id = "MultiplayerPvP" } or nil }
end
local RANK = {}
for i, k in ipairs(DECKS) do
	RANK[k] = i
end
local STAKES = {
	"stake_white",
	"stake_red",
	"stake_green",
	"stake_black",
	"stake_blue",
	"stake_purple",
	"stake_orange",
	"stake_gold",
	"stake_mp_planet",
	"stake_mp_spectral",
	"stake_mp_spectralplus",
}
for i, k in ipairs(STAKES) do
	G.P_CENTER_POOLS.Stake[i] = { key = k }
end

local function board_ok(board, size, decks, stakes)
	local deck_ok, stake_ok = {}, {}
	for _, k in ipairs(decks) do
		deck_ok[k] = true
	end
	for _, s in ipairs(stakes) do
		stake_ok[s] = true
	end
	local ok = { size = #board == size, allowed = true, caps = true, pairs = true, white = false, sorted = true }
	local per_stake, per_deck, ids = {}, {}, {}
	for i, t in ipairs(board) do
		if not deck_ok[t.key] or not stake_ok[t.stake] then ok.allowed = false end
		if t.id ~= t.key .. "@" .. t.stake or ids[t.id] then ok.pairs = false end
		ids[t.id] = true
		per_stake[t.stake] = (per_stake[t.stake] or 0) + 1
		per_deck[t.key] = (per_deck[t.key] or 0) + 1
		if t.stake == 1 then ok.white = true end
		local prev = board[i - 1]
		if prev and (prev.stake > t.stake or (prev.stake == t.stake and RANK[prev.key] > RANK[t.key])) then
			ok.sorted = false
		end
	end
	for _, n in pairs(per_stake) do
		if n > 4 then ok.caps = false end
	end
	for _, n in pairs(per_deck) do
		if n > 3 then ok.caps = false end
	end
	return ok
end

print("-- board rules: 300 seeded boards --")
local vanilla = { unpack(DECKS, 1, 15) }
local cases = {
	{ "every stake up to 8", vanilla, { 1, 2, 3, 4, 5, 6, 7, 8 } },
	{ "Expanded's five stakes", vanilla, { 1, 3, 4, 6, 8 } },
	{ "three decks", { "b_red", "b_blue", "b_yellow" }, { 1, 2, 3, 4, 5, 6, 7, 8 } },
}
for _, case in ipairs(cases) do
	local name, decks, stakes = case[1], case[2], case[3]
	local all = { size = true, allowed = true, caps = true, pairs = true, white = true, sorted = true }
	for seed = 1, 300 do
		for k, v in pairs(board_ok(S.draft_board(decks, stakes, { rng = make_rng(seed) }), 9, decks, stakes)) do
			if not v then all[k] = false end
		end
	end
	check(all.size, name .. ": 9 tiles")
	check(all.allowed, name .. ": only the allowed decks and stakes")
	check(all.caps, name .. ": at most 4 per stake and 3 per deck")
	check(all.pairs, name .. ": ids are key@stake and no pair repeats")
	check(all.white, name .. ": at least one White tile")
	check(all.sorted, name .. ": sorted by stake, then deck order")
end

local only_white = true
for seed = 1, 50 do
	local board = S.draft_board(vanilla, { 1 }, { rng = make_rng(seed) })
	if #board ~= 9 then only_white = false end
end
check(only_white, "a stake cap of 1 still fills 9 White tiles")
check(#S.draft_board(vanilla, { 1, 2, 3 }, { rng = make_rng(1), size = 6 }) == 6, "size sets the board size")
local a = S.draft_board(vanilla, { 1, 3, 4, 6, 8 }, { rng = make_rng(42) })
local b = S.draft_board(vanilla, { 1, 3, 4, 6, 8 }, { rng = make_rng(42) })
local same = #a == #b
for i = 1, #a do
	if a[i].id ~= b[i].id then same = false end
end
check(same, "the same rng gives the same board")

print()
print("-- tile order --")
check(S.draft_tile_order({ key = "b_red", stake = 1 }, { key = "b_abandoned", stake = 1 }), "deck order, not alphabetical")
check(S.draft_tile_order({ key = "b_erratic", stake = 1 }, { key = "b_red", stake = 3 }), "lower stake first")
check(S.draft_tile_order({ key = "b_erratic", stake = 1 }, { key = "b_mp_violet", stake = 1 }), "PvP decks after vanilla")
check(not S.draft_tile_order({ key = "b_red", stake = 1 }, { key = "b_red", stake = 1 }), "a tile is not before itself")

print()
print("-- the Draft config the host hands MPAPI.BanPick --")
-- The ruleset fields as rulesets/ and layers/ declare them (Small World lists the same stakes as Expanded).
local FIELDS = {
	ruleset_mp_balanced = { banned_backs = { "b_mp_orange", "b_mp_violet" }, allowed_backs = { "b_mp_orange", "b_mp_violet" } },
	ruleset_mp_expanded = {
		allowed_backs = { "b_mp_orange", "b_mp_violet", "b_mp_cocktail" },
		allowed_stakes = { "stake_white", "stake_green", "stake_black", "stake_purple", "stake_gold", "stake_mp_spectralplus" },
		half_weight_stakes = { "stake_mp_spectralplus" },
	},
	ruleset_mp_smallworld = "ruleset_mp_expanded",
}
function MPAPI.resolve_ruleset_field(ruleset, field)
	local fields = type(FIELDS[ruleset]) == "string" and FIELDS[FIELDS[ruleset]] or FIELDS[ruleset]
	return fields and fields[field]
end
local noop = function() end
PVP._pvp_action_helpers = setmetatable({}, {
	__index = function()
		return noop
	end,
})
dofile("pvp_api/actions/run_lifecycle.lua")

local function pool_stakes_and_decks(ruleset, pool_size)
	local config = PVP._ban_pick_config_for({ ban_pick = { pool_size = pool_size or 9, keep = 1, schedule = {} } }, ruleset)
	local stakes, decks, sizes = {}, {}, {}
	for _ = 1, 200 do
		local board = config.build_pool()
		sizes[#board] = true
		for _, t in ipairs(board) do
			stakes[t.stake], decks[t.key] = true, true
		end
	end
	return stakes, decks, sizes, config
end
local function keys_of(set)
	local out = {}
	for k in pairs(set) do
		out[#out + 1] = k
	end
	table.sort(out, function(x, y)
		return tostring(x) < tostring(y)
	end)
	return table.concat(out, ",")
end

local stakes, decks, sizes, config = pool_stakes_and_decks("ruleset_mp_expanded")
check(config.tile_order == S.draft_tile_order, "the config shows tiles in draft_tile_order")
check(keys_of(stakes) == "1,11,3,4,6,8", "Expanded drafts its allowed stakes, Spectral+ included (" .. keys_of(stakes) .. ")")
check(decks.b_mp_orange and decks.b_mp_violet and decks.b_mp_cocktail and not decks.b_challenge, "Expanded drafts Orange, Violet and Cocktail, not Challenge")
check(sizes[9] and keys_of(sizes) == "9", "Expanded boards have 9 tiles")
local counts = {}
for _ = 1, 3000 do
	for _, t in ipairs(config.build_pool()) do
		counts[t.stake] = (counts[t.stake] or 0) + 1
	end
end
local plus = counts[11] / counts[3]
check(plus > 0.35 and plus < 0.65, ("Spectral+ comes up about half as often as Green (%.2f)"):format(plus))
stakes, decks = pool_stakes_and_decks("ruleset_mp_smallworld")
check(decks.b_mp_cocktail, "Small World drafts Cocktail")
check(keys_of(stakes) == "1,11,3,4,6,8", "Small World drafts the same stakes as Expanded (" .. keys_of(stakes) .. ")")
stakes, decks = pool_stakes_and_decks("ruleset_mp_balanced")
check(keys_of(stakes) == "1,2,3,4,5,6,7,8", "Balanced drafts every stake up to 8")
check(not decks.b_mp_orange and not decks.b_mp_violet and not decks.b_mp_cocktail, "Balanced drafts no PvP decks")
PVP.DECK.MAX_STAKE = 3
stakes, decks = pool_stakes_and_decks("ruleset_mp_smallworld")
check(decks.b_mp_cocktail, "Small World drafts Cocktail")
check(keys_of(stakes) == "1,3", "a stake cap of 3 limits the stakes")
PVP.DECK.MAX_STAKE = nil
local _, _, small = pool_stakes_and_decks("ruleset_mp_balanced", 6)
check(keys_of(small) == "6", "the board has the server's pool_size tiles")

print()
if failures == 0 then
	print("ALL PASS")
else
	print(failures .. " FAIL")
	os.exit(1)
end
