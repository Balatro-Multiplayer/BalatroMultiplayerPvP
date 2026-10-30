-- Run from the repo root: lua5.4 tests/unit/cocktail_test.lua
-- Load the actual deck with minimal game stubs; exercise selection and apply.
local function noop() end
PVP = {
	id = "MultiplayerPvP",
	config = { cocktail = "000H" },
	LOBBY = { code = "test", deck = { cocktail = "" } },
	is_layer_active = function() return false end,
}
G = {
	P_CENTERS = {
		b_red = { set = "Back", order = 1, config = { discards = 1 } },
		b_blue = { set = "Back", order = 2, config = { hands = 1 } },
		b_mp_test = {
			set = "Back", order = 3, mod = PVP, config = { dollars = 10 },
		},
		b_other = {
			set = "Back", order = 4, mod = { id = "Other" }, config = {},
		},
	},
	E_MANAGER = { add_event = noop },
}
SMODS = {
	Back = function(def)
		G.P_CENTERS.b_mp_cocktail = def
		def.set = "Back"
	end,
	DrawStep = noop,
	Atlas = noop,
}
Back = { change_to = noop }
Card = { click = noop, draw = noop, hover = noop, highlight = noop }
CardArea = { can_highlight = noop }
Controller = { queue_R_cursor_press = noop }
Event = function(event) return event end
generate_card_ui = noop
localize = noop
generate_starting_seed = function() return "test" end
pseudoseed = function(seed) return seed end
pseudoshuffle = noop -- Stable order makes selection assertions exact.

dofile("objects/decks/ZZ_cocktail.lua")
local function check(name, got, want)
	assert(got == want, name .. ": got " .. tostring(got) .. ", want " .. tostring(want))
	print("ok   " .. name)
end
local function apply(cfg)
	PVP.LOBBY.deck.cocktail = cfg
	G.GAME = {
		pseudorandom = {}, modifiers = {},
		selected_back = { effect = { config = {} } },
	}
	G.P_CENTERS.b_mp_cocktail:apply()
	return table.concat(G.GAME.modifiers.mp_cocktail, ",")
end

check("pool includes current mod, excludes other mods and Cocktail",
	table.concat(PVP.get_cocktail_decks(), ","), "b_red,b_blue,b_mp_test")
check("empty lobby config uses defaults, not local preferences", PVP.cocktail_cfg_get(), "111H")
check("default lobby applies three decks", apply(""), "b_red,b_blue,b_mp_test")
check("red effect applied", G.GAME.selected_back.effect.config.discards, 1)
check("blue effect applied", G.GAME.selected_back.effect.config.hands, 1)
check("PvP effect applied", G.GAME.selected_back.effect.config.dollars, 10)
check("default is not marked edited", PVP.cocktail_check_edited(), false)
check("one forced deck fills both remaining slots", apply("211H"), "b_red,b_blue,b_mp_test")
check("two forced decks fill last slot", apply("221H"), "b_red,b_blue,b_mp_test")
check("three forced decks need no random candidates", apply("222H"), "b_red,b_blue,b_mp_test")
check("small pool keeps all available candidates", apply("210H"), "b_red,b_blue")
check("explicit empty selection is preserved", apply("000H"), "")
PVP.config.cocktail = "H"
PVP.LOBBY.deck.cocktail = "111S"
check("visibility uses effective config length", PVP.cocktail_cfg_readpos("show", true), "S")
PVP.LOBBY.code = nil
PVP.config.cocktail = "010H"
local decks = PVP.get_cocktail_decks(true)
check("single-player keeps local selection", table.concat(decks, ","), "b_blue")
