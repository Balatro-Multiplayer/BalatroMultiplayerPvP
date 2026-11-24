-- Run from the repo root: luajit tests/unit/ready_button_test.lua
-- The Ready button of a PvP blind (ui/game/functions.lua) while the Boss slot is undecided and after the
-- view answers: held with no action while the answer is unknown, Ready once it says there is a partner,
-- never held for the Small blind. The Boss is built by the real gamemode and decided by the real screen,
-- from a rolled boss that is not the default.
local T = dofile("tests/support/check.lua")
local eq = T.eq

local gamemode
local lobby = {}
Game = { update = function() end }
MPAPI = { get_current_lobby = function() return lobby end }
localize = function(key) return key end
PVP = {
	NET = {}, READ = {},
	LOBBY = { config = { pvp_start_ante = 2, nemesis_pairing = true }, mirror_players = function() end },
	GAME = {},
	PRACTICE = {},
	RULES = { Gamemode = function(init) gamemode = init return { inject = function() end } end, active_gamemode = function() return "attrition" end },
	UI = { blind_start = {
		ready_button = function() return PVP.look end,
		ready_colour = function() return (PVP.look == "held" or PVP.look == "waiting") and "inactive" or "ready_colour" end,
	} },
	refresh_catching_up_badge = function() end,
}
G = {
	C = { UI = { BACKGROUND_INACTIVE = "inactive" }, FILTER = "filter" },
	FUNCS = {},
	GAME = { blind_on_deck = "Boss", round_resets = { ante = 2, pvp_blind_choices = {}, blind_choices = {}, blind_states = {} } },
}

dofile("pvp_api/read/_view.lua")
dofile("pvp_api/read/target.lua")
dofile("pvp_api/ui/target.lua")
dofile("gamemodes/attrition.lua")
PVP.RULES.gamemodes = { attrition = gamemode }
dofile("ui/game/functions.lua")

local resets = G.GAME.round_resets

local function view_of(my_boss)
	return { me = "a", match = { run = {
		targets = { opponents = {}, cardTargets = {}, myBoss = my_boss },
		players = { a = { ante = 2 } },
	} } }
end

-- What the button looks like the moment the blind select is built: the label says Select.
local function button()
	local shown = { text = "Select" }
	return {
		config = { button = "select_blind", colour = "filter" },
		children = { { config = { ref_table = shown, ref_value = "text" } } },
	}
end

-- The Boss is built before the view answers.
PVP.NET = { view = nil }
resets.blind_choices = { Boss = "bl_hook" }
resets.blind_states = { Boss = "Upcoming" }
local _, _, key = gamemode:get_blinds_by_ante(resets.ante)
resets.blind_choices.Boss = key
eq(resets.blind_choices.Boss, "bl_mp_nemesis", "built as the placeholder")
eq(resets.pvp_normal_boss, "bl_hook", "the rolled boss is kept")

local held = button()
G.FUNCS.pvp_ready_button(held)
eq(held.config.button, nil, "an undecided Boss on deck has no action")
eq(held.config.colour, "inactive", "and looks inactive")
G.FUNCS.pvp_ready_button(held)
eq(held.config.button, nil, "and stays held while the answer is unknown")

-- The Small blind is not held, whatever the Boss is.
G.GAME.blind_on_deck = "Small"
local small = button()
G.FUNCS.pvp_ready_button(small)
eq(small.config.button, "mp_toggle_ready", "Small on deck is Ready, unaffected")
eq(small.config.colour, "ready_colour", "with the Ready colour")
G.GAME.blind_on_deck = "Boss"

-- The answer arrives: a partner. The held button is Ready again.
PVP.NET.view = view_of("plays")
PVP.UI.target.update()
eq(resets.pvp_boss, "decided", "the answer decides the Boss")
eq(resets.blind_choices.Boss, "bl_mp_nemesis", "a partner keeps the PvP blind")
G.FUNCS.pvp_ready_button(held)
eq(held.config.button, "mp_toggle_ready", "after the answer the button is Ready")
eq(held.config.colour, "ready_colour", "with the Ready colour")
eq(held.config.pvp_boss_hold, "free", "and no longer held")
eq(held.children[1].config.maxw, 2.2, "the Ready text is bounded to the button")

-- The answer arrives: a bye. The Boss is the rolled one and is a PvP Boss, which is what
-- blind_choice.lua reads to build the Ready button (pvp_ready_button) instead of a plain Select.
resets.blind_choices = { Boss = "bl_hook" }
resets.blind_states = { Boss = "Upcoming" }
resets.pvp_blind_choices = {}
PVP.NET.view = nil
_, _, key = gamemode:get_blinds_by_ante(resets.ante)
resets.blind_choices.Boss = key
PVP.NET.view = view_of("bye")
PVP.UI.target.update()
eq(resets.blind_choices.Boss, "bl_hook", "a bye plays the rolled boss")
eq(resets.pvp_blind_choices.Boss, true, "a bye's Boss is a PvP Boss: it gets the Ready button")
eq(resets.pvp_boss, "decided", "and is decided")
G.GAME.blind_on_deck = "Boss"
local bye_button = button()
G.FUNCS.pvp_ready_button(bye_button)
eq(bye_button.config.button, "mp_toggle_ready", "the bye's button is Ready")

-- A blind playing: the Ready button has no action and looks inactive, and releases by itself.
resets.blind_choices = { Boss = "bl_hook" }
G.GAME.blind_on_deck = "Boss"
resets.pvp_boss = "decided"
local ready = button()
PVP.look = "not_ready"
G.FUNCS.pvp_ready_button(ready)
eq(ready.config.button, "mp_toggle_ready", "no hold: the button is Ready")
PVP.look = "held"
G.FUNCS.pvp_ready_button(ready)
eq(ready.config.button, nil, "held: no action")
eq(ready.config.colour, "inactive", "held: inactive look")
G.FUNCS.pvp_ready_button(ready)
eq(ready.config.button, nil, "held stays held")
PVP.look = "not_ready"
G.FUNCS.pvp_ready_button(ready)
eq(ready.config.button, "mp_toggle_ready", "released: Ready again")
eq(ready.config.colour, "ready_colour", "released: the Ready colour")
local held_first = button()
PVP.look = "held"
G.FUNCS.pvp_ready_button(held_first)
eq(held_first.config.button, nil, "held from the first frame: no action")
PVP.look = "not_ready"
G.FUNCS.pvp_ready_button(held_first)
eq(held_first.config.button, "mp_toggle_ready", "and released")

-- Before the server's first view a press sends nothing: no action, released once the view comes.
local no_view = button()
PVP.look = "waiting"
G.FUNCS.pvp_ready_button(no_view)
eq(no_view.config.button, nil, "no view yet: no action")
eq(no_view.config.colour, "inactive", "no view yet: inactive look")
PVP.look = "not_ready"
G.FUNCS.pvp_ready_button(no_view)
eq(no_view.config.button, "mp_toggle_ready", "the view came: Ready")

T.done("ready_button_test")
