-- Practice deck and stake pickers through the real visibility hooks, without the game.
-- Run from the repo root: texlua tests/unit/practice_deck_picker_test.lua
local function noop() end
local function center(key, mod)
	return { key = key, mod = mod and { id = mod } }
end
local function stake_pool() return G.P_CENTER_POOLS.Stake end

G = {
	SETTINGS = {},
	UIT = { R = "row" },
	P_CENTER_POOLS = {
		Back = {
			center("b_red"),
			center("b_blue"),
			center("b_mp_orange", "MultiplayerPvP"),
			center("b_mp_cocktail", "MultiplayerPvP"),
		},
		Stake = {
			center("stake_white"),
			center("stake_mp_planet", "MultiplayerPvP"),
			center("stake_mp_spectral", "MultiplayerPvP"),
			center("stake_mp_spectralplus", "MultiplayerPvP"),
		},
	},
	CHALLENGES = {},
	UIDEF = {
		deck_stake_column = stake_pool,
		current_stake = stake_pool,
		stake_option = stake_pool,
		challenges = noop,
		challenge_list = noop,
		challenge_list_page = noop,
		run_setup_option = function()
			return create_option_cycle({
				opt_callback = "change_viewed_back",
				options = G.P_CENTER_POOLS.Back,
				stakes = G.UIDEF.deck_stake_column(),
			})
		end,
	},
	FUNCS = {
		go_to_menu = noop,
		start_setup_run = noop,
		change_selected_back = noop,
		change_viewed_back = function(args)
			return G.P_CENTER_POOLS.Back[args.to_key].key
		end,
		overlay_menu = function(args)
			G.OVERLAY_MENU = args.definition
		end,
		setup_run = function()
			return G.UIDEF.run_setup_option()
		end,
	},
}
PVP = {
	id = "MultiplayerPvP",
	LOBBY = {},
	LobbyAccess = { PRIVATE = "private", PRACTICE = "practice", RANKED = "ranked", CASUAL = "casual" },
	config = {},
	current_ruleset = function() return { multiplayer_content = false } end,
}
SMODS = { injectItems = noop }
function create_option_cycle(args) return args end
function create_tabs(args) return args.tabs[1].tab_definition_function() end
function create_UIBox_generic_options(args) return args.contents[1].nodes[1] end
function localize(key) return key end

dofile("lib/practice_mode.lua")
dofile("lib/mp_content_visibility.lua")
dofile("overrides/hide_content.lua")
SMODS.injectItems()

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local function cycle_to(cycle, index)
	return G.FUNCS.change_viewed_back({ cycle_config = cycle, to_key = index })
end

local function check_stakes(context, cycle, show_mp)
	local expected = "stake_white"
	if show_mp then expected = expected .. ",stake_mp_planet,stake_mp_spectral,stake_mp_spectralplus" end
	local function keys(pool)
		local result = {}
		for _, stake in ipairs(pool) do result[#result + 1] = stake.key end
		return table.concat(result, ",")
	end
	check(context .. " run setup stakes", keys(cycle.stakes), expected)
	for _, name in ipairs({ "deck_stake_column", "current_stake", "stake_option" }) do
		check(context .. " " .. name, keys(G.UIDEF[name]()), expected)
	end
	check(context .. " restores the full stake pool", #G.P_CENTER_POOLS.Stake, 4)
end

local singleplayer = G.FUNCS.setup_run()
check("singleplayer hides multiplayer decks", #singleplayer.options, 2)
check_stakes("singleplayer", singleplayer, false)
check("singleplayer cycles the filtered pool", cycle_to(singleplayer, 2), "b_blue")
check("collection still cycles the full pool", cycle_to({}, 3), "b_mp_orange")

for _, ruleset in ipairs({ "balanced", "expanded", "vanilla", "smallworld" }) do
	local key = "ruleset_mp_" .. ruleset
	PVP.open_practice_setup(key)
	local cycle = G.OVERLAY_MENU
	check(ruleset .. " practice setup keeps its ruleset", PVP.practice_setup_ruleset(), key)
	check(ruleset .. " practice setup has no network lobby", PVP.LOBBY.code, nil)
	check(ruleset .. " practice is not running yet", PVP.is_practice_mode(), false)
	check(ruleset .. " practice setup shows multiplayer decks", #cycle.options, 4)
	check_stakes(ruleset .. " practice setup", cycle, true)
	check(ruleset .. " practice cycles to Orange", cycle_to(cycle, 3), "b_mp_orange")
	check(ruleset .. " practice cycles to Cocktail", cycle_to(cycle, 4), "b_mp_cocktail")
	check(ruleset .. " picker restores the full pool", #G.P_CENTER_POOLS.Back, 4)
end

singleplayer = G.FUNCS.setup_run()
check("normal setup clears the practice setup context", PVP.practice_setup_ruleset(), nil)
check("normal setup hides multiplayer decks again", #singleplayer.options, 2)
check_stakes("normal setup after practice setup", singleplayer, false)

PVP.SP.practice = true
PVP._pvp_kind = PVP.LobbyAccess.PRACTICE
local practice = G.UIDEF.run_setup_option()
check("active practice shows multiplayer decks without setup context", #practice.options, 4)
check("active practice cycles to Cocktail", cycle_to(practice, 4), "b_mp_cocktail")
check_stakes("active practice", practice, true)

PVP.SP.practice = false
singleplayer = G.FUNCS.setup_run()
check("after practice, stale practice kind does not expose decks", #singleplayer.options, 2)
check_stakes("after practice with stale practice kind", singleplayer, false)
PVP.LOBBY.code = "ABCDE"
PVP._pvp_kind = PVP.LobbyAccess.RANKED
local ranked = G.FUNCS.setup_run()
check("ranked ruleset without multiplayer content still hides decks", #ranked.options, 2)
check_stakes("ranked ruleset without multiplayer content", ranked, false)
PVP._pvp_kind = PVP.LobbyAccess.PRIVATE
local private = G.FUNCS.setup_run()
check("private lobby still shows multiplayer decks", #private.options, 4)
check_stakes("private lobby", private, true)

if failures > 0 then os.exit(1) end
print("all passed")
