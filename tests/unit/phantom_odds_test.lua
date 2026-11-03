-- Plain Lua test for the SMODS.get_probability_vars wrap in lib/phantom.lua: the odds shown on
-- another player's jokers leave out this player's own modifiers (Oops! All 6s), and rolls keep them.
-- Run from the repo root: luajit tests/unit/phantom_odds_test.lua
local calls = {}
SMODS = {}
-- Stands in for SMODS: this player holds one Oops! All 6s, which doubles the numerator.
function SMODS.get_probability_vars(trigger_obj, base_numerator, base_denominator, identifier, from_roll, no_mod)
	calls[#calls + 1] = { no_mod = no_mod }
	if no_mod then
		return base_numerator, base_denominator
	end
	return base_numerator * 2, base_denominator
end
MPAPI = { connection_state = { player_id = "me" } }
PVP = { end_game_jokers = {} }
function PVP.is_phantom(card)
	return card.ability ~= nil and card.ability.mp_phantom == true
end

-- Load only the wrap, not the rest of lib/phantom.lua.
local source = assert(io.open("lib/phantom.lua")):read("*a")
local first = assert(source:find("local get_probability_vars_ref", 1, true))
local _, last = source:find("\nend\n", first, true)
assert((loadstring or load)(source:sub(first, last)))()

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end
local function shown(...)
	return (SMODS.get_probability_vars(...))
end

local own = { ability = {} }
local phantom = { ability = { mp_phantom = true } }
local end_screen = { ability = {}, area = PVP.end_game_jokers }

PVP._end_screen_selected_player_id = "them"
check("own joker keeps Oops", shown(own, 1, 4, "x"), 2)
check("Phantom joker leaves out Oops", shown(phantom, 1, 4, "x"), 1)
check("end screen, other player selected: leaves out Oops", shown(end_screen, 1, 4, "x"), 1)
PVP._end_screen_selected_player_id = "me"
check("end screen, self selected: keeps Oops", shown(end_screen, 1, 4, "x"), 2)
PVP._end_screen_selected_player_id = nil
check("end screen, nobody selected: leaves out Oops", shown(end_screen, 1, 4, "x"), 1)
check("table without ability keeps Oops", shown({}, 1, 4, "x"), 2)
check("nil trigger_obj keeps Oops", shown(nil, 1, 4, "x"), 2)
check("string trigger_obj keeps Oops", shown("s", 1, 4, "x"), 2)
check("a caller's own no_mod is kept", shown(own, 1, 4, "x", false, true), 1)
PVP._end_screen_selected_player_id = "them"
check("a Phantom joker's roll keeps Oops", shown(phantom, 1, 4, "x", true), 2)
check("a roll passes no no_mod", calls[#calls].no_mod, false)

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("all passed")
