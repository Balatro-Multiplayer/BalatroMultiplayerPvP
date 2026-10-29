-- Standalone: lua tests/test_draft_candidates.lua (from the repo root).
PVP = {}
G = { FUNCS = {} }
dofile("pvp_api/setup.lua")

local function backs(...)
	local list = {}
	for _, spec in ipairs({ ... }) do
		list[#list + 1] = { key = spec[1], mod_id = spec[2] }
	end
	return list
end

local pool = backs(
	{ "b_red" },
	{ "b_black" },
	{ "b_challenge" },
	{ "b_mp_orange", "MultiplayerPvP" },
	{ "b_mp_violet", "MultiplayerPvP" },
	{ "b_mp_white", "MultiplayerPvP" },
	{ "b_other_deck", "OtherMod" }
)

local function run(allowed, banned)
	return table.concat(PVP.SETUP.draft_candidates(pool, allowed, banned), ",")
end

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s\n  got:  %s\n  want: %s"):format(name, got, want))
	end
end

check("no rules: base decks only, no Challenge Deck", run(nil, nil), "b_red,b_black")
check("allowed PvP decks join", run({ "b_mp_orange", "b_mp_violet" }, nil), "b_red,b_black,b_mp_orange,b_mp_violet")
check("banned beats allowed", run({ "b_mp_orange", "b_mp_violet" }, { "b_mp_orange", "b_mp_violet" }), "b_red,b_black")
check("other mod decks are opt-in", run({ "b_other_deck" }, nil), "b_red,b_black,b_other_deck")
check("banned can remove a base deck", run(nil, { "b_black" }), "b_red")

if failures > 0 then
	os.exit(1)
end
print("ok")
