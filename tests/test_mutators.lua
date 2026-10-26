-- Contract tests for manual setup. Run from the PvP root with Lua or LuaJIT.
-- These do not simulate Balatro's scoring, shop generation, or save engine.
local passed = 0
local function check(value, message)
	assert(value, message)
	passed = passed + 1
end

PVP = { SP = {}, LOBBY = { config = {} }, id = "MultiplayerPvP", EXPERIMENTAL = {} }
PVP.LayerKey = {
	MULTIPLAYER_CONTENT = "multiplayer_content",
	NO_MULTIPLAYER_CONTENT = "no_multiplayer_content",
	SANDBOX = "sandbox",
}
MPAPI = { Layers = {}, MODIFIERS = {}, Rulesets = {} }
G = { P_CENTERS = {}, P_CENTER_POOLS = { Stake = { {} } }, GAME = {}, FUNCS = {} }
SMODS = { Mods = {} }
Back = {
	trigger_effect = function()
		return nil, nil
	end,
}
local session = true
function PVP.in_session()
	return session
end
function MPAPI.Layer(key, definition)
	check(MPAPI.Layers[key] == nil, "unique layer " .. key)
	MPAPI.Layers[key] = definition
end
function PVP.is_layer_active(key)
	for _, name in ipairs(MPAPI.MODIFIERS) do
		if key == name then return true end
	end
	return false
end
function copy_table(source)
	local result = {}
	for key, value in pairs(source) do
		result[key] = type(value) == "table" and copy_table(value) or value
	end
	return result
end
function pseudoshuffle() end
function pseudoseed()
	return 0.5
end

dofile("lib/mutators.lua")
dofile("layers/glass_cannon.lua")
dofile("layers/resource_mutators.lua")
dofile("layers/ban_mutators.lua")
dofile("layers/economy_mutators.lua")
dofile("layers/multiplayer_content.lua")
dofile("layers/sandbox.lua")
dofile("layers/sandbox_mutators.lua")

local function setup(hands, discards)
	G.GAME = { round_resets = { hands = hands, discards = discards }, banned_keys = {} }
end
for initial = 1, 5 do
	setup(initial, 0)
	local layer = MPAPI.Layers.glass_cannon
	layer:calculate({ apply_bans = true })
	check(G.GAME.round_resets.hands == math.max(1, initial - 2), "Glass Cannon is deck-relative and clamped")
	layer:calculate({ apply_bans = true })
	check(G.GAME.round_resets.hands == math.max(1, initial - 2), "Glass Cannon setup is idempotent")
end
setup(4, 0)
MPAPI.Layers.all_in:calculate({ apply_bans = true })
check(G.GAME.round_resets.hands == 5 and G.GAME.round_resets.discards == 0, "All In preserves discard floor")
MPAPI.Layers.fresh_start:calculate({ apply_bans = true })
check(G.GAME.round_resets.discards == 1, "Fresh Start adds a discard")
session = false
PVP.apply_round_deltas("outside", { hands = -10 })
check(G.GAME.round_resets.hands == 5, "resource effects do not touch vanilla")
session = true
check(MPAPI.Layers.discard_dividend.game_modifiers.discard_cost == 1, "Discard Dividend costs $1")
check(MPAPI.Layers.discard_dividend.game_modifiers.money_per_discard == 2, "Discard Dividend pays $2 unused")
check(MPAPI.Layers.paid_overtime.game_modifiers.no_extra_hand_money, "Paid Overtime removes hand payout")
check(MPAPI.Layers.working_capital.game_modifiers.no_interest, "Working Capital removes interest")

setup(4, 3)
G.P_CENTERS = {
	j_a = { set = "Joker", rarity = 1 },
	j_b = { set = "Joker", rarity = 2 },
	j_c = { set = "Joker", rarity = 3 },
	c_a = { set = "Tarot", rarity = 2 },
}
MPAPI.Layers.no_uncommons:calculate({ apply_bans = true })
check(
	G.GAME.banned_keys.j_b and not G.GAME.banned_keys.j_a and not G.GAME.banned_keys.j_c,
	"ban exactly Uncommon Jokers"
)
check(not G.GAME.banned_keys.c_a, "do not ban consumables with rarity 2")
for group, layer in pairs(PVP.SANDBOX.GROUP_LAYERS) do
	MPAPI.MODIFIERS = { layer }
	for _, mapping in ipairs(PVP.SANDBOX.joker_mappings) do
		check(
			PVP.SANDBOX.is_joker_allowed(mapping.sandbox) == (PVP.SANDBOX.group_of(mapping) == group),
			"group isolates " .. mapping.sandbox
		)
	end
end
MPAPI.MODIFIERS = { "idol_collector" }
check(PVP.SANDBOX.is_joker_allowed(PVP.SANDBOX.IDOLS.collector), "Collector override")
check(not PVP.SANDBOX.is_joker_allowed(PVP.SANDBOX.IDOLS.zealot), "Collector excludes Zealot")
MPAPI.MODIFIERS = { "idol_none", "sandbox" }
check(not PVP.SANDBOX.is_joker_allowed(PVP.SANDBOX.IDOLS.collector), "None overrides Sandbox")
SMODS.Mods.extracredit = { can_load = true }
MPAPI.MODIFIERS = { "sandbox", "sandbox_extra_credit" }
check(
	not PVP.SANDBOX.is_joker_allowed(PVP.SANDBOX.mappings_in("extra_credit")[1].sandbox),
	"Extra Credit compatibility"
)

-- Model only the delayed size boundary SMODS exposes; actual areas still need
-- the real-game check. In particular, pre-area challenge setup must still work.
CardArea = {
	update = function(self)
		self:handle_card_limit()
	end,
}
UIElement = { update_text = function() end }
dofile("layers/shared_pockets.lua")
local function area(limit)
	return {
		config = { card_limit = limit, card_count = 0 },
		pending = 0,
		change_size = function(self, delta)
			self.pending = self.pending + delta
		end,
		handle_card_limit = function(self)
			self.config.card_limit = self.config.card_limit + self.pending
			self.pending = 0
		end,
	}
end
G.GAME = { modifiers = {} }
G.jokers, G.consumeables, G.hand = area(6), area(3), area(8)
PVP.setup_shared_pockets(true)
check(G.GAME.mp_shared_pockets.joker_limit == 100006, "Shared Pockets captures custom deck baseline")
CardArea.update(G.hand, 0)
check(G.hand.config.card_limit == 15, "Shared Pockets applies live hand size")
G.jokers.config.card_count = 1
CardArea.update(G.hand, 0)
check(G.hand.config.card_limit == 14, "owned Joker consumes a shared slot")
G.jokers.config.card_count, G.jokers.config.card_limit = 2, 100007
CardArea.update(G.hand, 0)
check(G.hand.config.card_limit == 14, "Negative extra slot does not consume hand capacity")
PVP.setup_shared_pockets(true)
check(G.jokers.config.card_limit == 100007, "Shared Pockets setup is idempotent")
G.GAME = { modifiers = {}, starting_params = { joker_slots = 5, consumable_slots = 2, hand_size = 7 } }
G.jokers, G.consumeables, G.hand = nil, nil, nil
PVP.setup_shared_pockets()
check(G.GAME.starting_params.hand_size == 14, "pre-area challenge setup remains supported")

-- Exercise Polymorph's formerly unbounded searches without a scoring simulator.
Card = {
	set_ability = function(self, center)
		self.config.center = center
	end,
}
SMODS.calculate_context = function() end
generate_card_ui = function()
	return {}
end
localize = function(value)
	return value
end
function MPAPI.should_exclude_from_pool()
	return false
end
dofile("layers/polymorph_spam.lua")
local a, b = { key = "j_a", set = "Joker" }, { key = "j_b", set = "Joker" }
G.P_CENTERS, G.P_CENTER_POOLS.Joker = { j_a = a, j_b = b }, { a, b }
local removed, added = 0, 0
local card = {
	config = { center = a },
	remove_from_deck = function()
		removed = removed + 1
	end,
	add_to_deck = function()
		added = added + 1
	end,
	set_ability = Card.set_ability,
	set_cost = function() end,
}
G.jokers, G.consumeables = { cards = { card } }, { cards = {} }
G.GAME = { modifiers = { mp_polymorph_spam = true }, banned_keys = { j_a = true } }
SMODS.calculate_context({ setting_blind = true })
check(card.config.center == b and removed == 1 and added == 1, "Polymorph can leave a banned owned center")
G.GAME.banned_keys.j_b = true
SMODS.calculate_context({ setting_blind = true })
check(card.config.center == b and removed == 1, "empty eligible pool terminates without mutation")
card.config.center = { key = "j_missing", set = "Joker" }
SMODS.calculate_context({ setting_blind = true })
check(removed == 1, "center absent from pool terminates without mutation")

dofile("lib/singleplayer.lua")
PVP.Rulesets = { ruleset_mp_vanilla = {} }
PVP.Mutator("glass_cannon", "chaos", 1)
local config = { ruleset = "ruleset_mp_vanilla", modifiers = { "glass_cannon" }, stake = 1 }
check(PVP.SOLO.validate(config), "valid solo configuration")
for _, invalid in ipairs({ "clock_mayhem", "not_a_layer", 5 }) do
	config.modifiers = { invalid }
	check(not PVP.SOLO.validate(config), "reject unavailable modifier " .. tostring(invalid))
end
config.modifiers, config.stake = {}, 0
check(not PVP.SOLO.validate(config), "reject invalid stake")
config.stake, config.deck = 1, "missing_deck"
check(not PVP.SOLO.validate(config), "reject invalid deck")
config.deck, config.seed = nil, 123
check(not PVP.SOLO.validate(config), "reject non-string seed")

-- Draft computation is testable without pretending to render the game UI.
dofile("ui/main_menu/custom_solo.lua")
PVP.Mutator("no_interest", PVP.MutatorCategory.ECONOMY, 1)
PVP.Mutator("fresh_start", PVP.MutatorCategory.RESOURCES, 1)
PVP.Mutator("sandbox_rotation", PVP.MutatorCategory.CONTENT, 1)
PVP.MUTATORS.sandbox_rotation.implied_by = "sandbox"
PVP.Rulesets.ruleset_mp_sandbox = { _layer_order = { "sandbox" } }
local C = PVP.CUSTOM
C.decks = { "b_red" }
C.draft = C.new_draft()
C.draft.selected = { fresh_start = true, glass_cannon = true, no_interest = true }
local selected = C.config()
check(table.concat(selected.modifiers, ",") == "no_interest,glass_cannon,fresh_start", "deterministic wall order")
check(not PVP.is_singleplayer(), "draft does not start a session")
C.draft.base = 4
check(C.inherited("sandbox_rotation"), "Sandbox subgroup is inherited")
C.draft.selected.sandbox_rotation = true
check(#C.config().modifiers == 3, "inherited layer is not duplicated")
C.draft.content, C.draft.idol = 3, 5
selected = C.config()
check(
	selected.modifiers[4] == "no_multiplayer_content" and selected.modifiers[5] == "idol_none",
	"explicit Off and None survive config"
)
G.FUNCS.pvp_solo_reset()
check(next(C.draft.selected) == nil and C.draft.content == 1 and C.draft.idol == 1, "reset clears rules and choices")

local metadata
MPAPI.get_current_lobby = function() end
MPAPI.modifiers_parse = function(serialized)
	MPAPI.MODIFIERS = {}
	for key in serialized:gmatch("[^,]+") do
		MPAPI.MODIFIERS[#MPAPI.MODIFIERS + 1] = key
	end
end
MPAPI.modifiers_serialize = function()
	return table.concat(MPAPI.MODIFIERS, ",")
end
MPAPI.create_local_lobby = function(_, options)
	metadata = options.metadata
	return {}
end
PVP.reset_lobby_config = function()
	PVP.LOBBY.config = {}
end
PVP.reset_game_states = function() end
for _, case in ipairs({
	{ "multiplayer_content", "multiplayer_content" },
	{ "no_multiplayer_content", "no_multiplayer_content" },
	{ "multiplayer_jokers", "multiplayer_content" },
	{ "no_multiplayer_jokers", "no_multiplayer_content" },
}) do
	check(
		PVP.SOLO.establish({ ruleset = "ruleset_mp_vanilla", modifiers = { case[1] }, stake = 1 }),
		"solo accepts content selection " .. case[1]
	)
	check(metadata.modifier_layers == case[2], "solo lobby uses canonical content layer for " .. case[1])
end
print(("Manual mutator contracts: %d checks passed"):format(passed))
