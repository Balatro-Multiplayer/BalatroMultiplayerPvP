-- Standalone: luajit tests/unit/draft_candidates_test.lua (from the repo root).
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

local stake_keys = {
	"stake_white",
	"stake_red",
	"stake_green",
	"stake_black",
	"stake_blue",
	"stake_purple",
	"stake_orange",
	"stake_gold",
}
local function stakes(allowed, cap)
	local out = PVP.SETUP.draft_stakes(allowed, stake_keys, cap)
	return out and table.concat(out, ",") or "nil"
end
local expanded = { "stake_white", "stake_green", "stake_black", "stake_purple", "stake_gold" }
check("no stake rules is unrestricted", stakes(nil, 8), "nil")
check("empty stake rules is unrestricted", stakes({}, 8), "nil")
check("expanded stakes by index", stakes(expanded, 8), "1,3,4,6,8")
check("stake cap trims allowed stakes", stakes(expanded, 5), "1,3,4")
check("nothing allowed under the cap is unrestricted", stakes({ "stake_gold" }, 5), "nil")

if failures > 0 then
	os.exit(1)
end
print("ok")
