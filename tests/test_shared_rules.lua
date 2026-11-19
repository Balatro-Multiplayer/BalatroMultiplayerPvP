-- Real shared-rule hooks and action/UI handlers with engine/network boundaries
-- stubbed. This is not evidence of rendered UI or a two-client network match.
local checks = 0
local function check(value, message)
	assert(value, message)
	checks = checks + 1
end
function copy_table(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in pairs(value) do
		result[key] = copy_table(item)
	end
	return result
end
PVP = { LOBBY = { is_host = true }, GAME = {}, LobbyAccess = { PRIVATE = "private" } }
local dispatched, records, sends = {}, {}, {}
local meta = { kind = "private", shared_pvp_rules = true }
local lobby = {
	server_features = { shared_pvp_rules = 2 },
	player_id = "a",
	is_host = true,
	get_players = function()
		return { { id = "a" }, { id = "b" } }
	end,
	get_metadata = function()
		return meta
	end,
	action = function(_, def)
		return {
			broadcast = function(_, params)
				sends[#sends + 1] = { key = def.key, params = params }
			end,
		}
	end,
}
MPAPI = {
	has_server_referee = function()
		return true
	end,
	get_current_lobby = function()
		return lobby
	end,
	ActionTypes = {},
	playback = {
		register_handler = function(_, opcode, fn)
			MPAPI.playback[opcode] = fn
		end,
	},
	sendWarnMessage = function() end,
	ActionType = function(def)
		MPAPI.ActionTypes[def.key] = def
	end,
}
G = {
	GAME = {},
	playing_cards = {},
	jokers = {},
	STAGES = { RUN = 1 },
	STAGE = 1,
	STATES = { BLIND_SELECT = 1 },
	STATE = 1,
	UIT = { R = 1, T = 2 },
	C = { UI = { TEXT_LIGHT = {}, BACKGROUND_INACTIVE = {} }, PURPLE = {} },
	FUNCS = {
		cash_out = function()
			return "cashout"
		end,
		go_to_menu = function()
			return "menu"
		end,
		exit_overlay_menu = function()
			G.OVERLAY_MENU = nil
		end,
		overlay_menu = function(args)
			G.OVERLAY_MENU = args.definition
		end,
	},
}
local queue = {}
G.E_MANAGER = {
	add_event = function(_, event)
		queue[#queue + 1] = event
	end,
}
Event = function(event)
	return event
end
delay = function() end
local now = 10
love = { timer = {
	getTime = function()
		return now
	end,
} }
Game = { update = function() end }
Blind = {
	set_blind = function(self, blind)
		self.config = { blind = blind }
		self:set_text()
		return "set"
	end,
	set_text = function(self)
		self.loc_debuff_lines = {}
		self.loc_debuff_text = "PvP"
	end,
	defeat = function()
		return "defeat"
	end,
	disable = function()
		return "disable"
	end,
	debuff_card = function(_, card)
		local flags = SMODS.calculate_context({ debuff_card = card, ignore_debuff = true })
		card:set_debuff(not flags.prevent_debuff and (flags.debuff or card.external or false))
		return "card"
	end,
	stay_flipped = function(_, to_area, card, from_area)
		local flags = SMODS.calculate_context({
			stay_flipped = true,
			to_area = to_area,
			other_card = card,
			from_area = from_area,
		})
		return not flags.prevent_stay_flipped and flags.stay_flipped
	end,
	debuff_hand = function(_, cards, hand, handname, check)
		local flags = SMODS.calculate_context({
			debuff_hand = true,
			full_hand = cards,
			poker_hands = hand,
			scoring_name = handname,
			check = check,
		})
		return not flags.prevent_debuff and flags.debuff
	end,
	press_play = function()
		return "play"
	end,
}
local blind = setmetatable({ children = { animatedSprite = {} } }, { __index = Blind })
PVP.is_pvp_boss = function()
	return true
end
Back = {
	trigger_effect = function(_, args)
		return args.chips, args.mult
	end,
}
local immunity = false
SMODS = {
	recalc_debuff = function(card)
		blind:debuff_card(card)
	end,
	calculate_context = function(context)
		if context.debuff_card or context.debuff_hand or context.stay_flipped then
			return { prevent_debuff = immunity, prevent_stay_flipped = immunity }
		end
		return "context", "second"
	end,
}
ease_hands_played = function(amount)
	G.GAME.current_round.hands_left = G.GAME.current_round.hands_left + amount
end
ease_discard = function(amount)
	G.GAME.current_round.discards_left = G.GAME.current_round.discards_left + amount
end
ease_dollars = function(amount)
	G.GAME.dollars = G.GAME.dollars + amount
end
level_up_hand = function(_, name, _, delta)
	G.GAME.hands[name].level = G.GAME.hands[name].level + delta
end
pseudoseed = function(key)
	return key
end
pseudorandom_element = function(pool)
	return pool[1], 1
end
UIBox_button = function(config)
	return { config = config }
end
create_UIBox_generic_options = function(config)
	return config
end
local discarded = 0
G.FUNCS.discard_cards_from_highlighted = function(_, forced)
	check(forced, "Hook uses forced discard path")
	discarded = discarded + #G.hand.highlighted
	G.hand.highlighted = {}
end
PVP.dispatch_action = function(key, params)
	dispatched[#dispatched + 1] = { key, params }
end
PVP.RLOG = {
	record = function(key, args)
		records[#records + 1] = { key, args }
	end,
}
PVP._playback_wait_for = function(predicate, fn)
	check(predicate(), "Replay waits at blind selection")
	fn()
end
dofile("lib/almanac/shared_rules.lua")
dofile("lib/almanac/shared_rules_round.lua")
dofile("overrides/shared_pvp_rules.lua")
dofile("pvp_api/actions/_helpers.lua")
dofile("pvp_api/actions/blind_handshake.lua")
dofile("pvp_api/actions/shared_rules.lua")
dofile("ui/shared_pvp_rules.lua")
dofile("lib/almanac/shared_rules_replay.lua")
local R = PVP.SHARED_RULES
local serial = 0
local function begin(a, b, ante)
	R.Round.finish()
	serial = serial + 1
	G.GAME = {
		round_resets = { hands = 4, discards = 3, ante = ante or 5 },
		current_round = { hands_left = 4, discards_left = 3, hands_played = 0, discards_used = 0 },
		hands = { Pair = { level = 3 } },
		dollars = 20,
		blind = blind,
	}
	G.hand = {
		config = { card_limit = 8 },
		cards = {},
		highlighted = {},
		change_size = function(self, amount)
			self.config.card_limit = self.config.card_limit + amount
		end,
		add_to_highlighted = function(self, card)
			self.highlighted[#self.highlighted + 1] = card
		end,
	}
	G.play = { cards = { {}, {}, {}, {}, {} } }
	G.playing_cards = {}
	queue = {}
	check(R.Round.resolve({ id = "rule" .. serial, ante = ante or 5, rules = { a, b } }), "Valid rule pair prepared")
	check(blind:set_blind({ key = "bl_mp_nemesis" }) == "set", "Native blind setup return preserved")
end
local function card(suit, face, external)
	return {
		is_suit = function(_, wanted)
			return wanted == suit
		end,
		is_face = function()
			return face
		end,
		set_debuff = function(self, value)
			self.debuff = value
		end,
		external = external,
	}
end

check(R.enabled(lobby), "Opt-in private two-player server lobby enabled")
lobby.server_features = nil
check(not R.enabled(lobby), "Older server cannot enable unsupported rule protocol")
lobby.server_features = { shared_pvp_rules = 1 }
check(not R.enabled(lobby), "Three-rule prototype server cannot enable the four-rule protocol")
lobby.server_features = { shared_pvp_rules = 2 }
meta.shared_pvp_rules = false
check(not R.enabled(lobby), "Default games unchanged")
meta.deck = "Almanac"
check(R.enabled(lobby), "Almanac always drafts rules without the prototype opt-in switch")
meta.deck = nil
meta.shared_pvp_rules = true
check(not R.Round.resolve({ id = "bad", ante = 3, rules = { "hook", "plant" } }), "Ante gates validated on receipt")
check(not R.Round.resolve({ id = "bad", ante = 5, rules = { "manacle", "manacle" } }), "No duplicate stacking")
local count = 0
for _ in pairs(R.definitions) do
	count = count + 1
end
check(count == 14 and not R.definitions.needle and not R.definitions.flint, "Accepted 14-rule pool only")

begin("manacle", "glass_cannon")
check(G.hand.config.card_limit == 7 and G.GAME.current_round.hands_left == 2, "Encounter resources adjusted")
check(G.GAME.round_resets.hands == 4, "Deck baseline unchanged")
R.Round.activate()
check(G.hand.config.card_limit == 7, "Activation idempotent")
local saved = copy_table(G.GAME)
G.GAME = saved
blind:set_blind({ key = "bl_mp_nemesis" }, true)
check(G.hand.config.card_limit == 7, "Save reconstruction does not reapply size change")
G.hand:change_size(2)
local chips, mult = Back.trigger_effect({}, { context = "final_scoring_step", chips = 12, mult = 3 })
check(chips == 12 and mult == 12, "Glass Cannon modifies Mult without replacing Chips")
R.Round.finish()
R.Round.finish()
check(G.hand.config.card_limit == 10, "Cleanup preserves permanent capacity changes and runs once")
check(
	not R.Round.resolve({ id = saved.pvp_shared_rules.id, ante = 5, rules = { "manacle", "glass_cannon" } }),
	"Late result cannot restart finished encounter"
)

begin("water", "glass_cannon")
check(
	G.GAME.current_round.discards_left == 0 and G.GAME.current_round.hands_left == 2,
	"Water and Glass Cannon allowed together"
)
G.GAME.current_round.hands_left = 1
-- A new activation against a one-hand baseline floors at one.
R.Round.finish()
G.GAME.pvp_shared_rules = nil
assert(R.Round.resolve({ id = "one", ante = 5, rules = { "water", "glass_cannon" } }))
R.Round.activate()
check(G.GAME.current_round.hands_left == 1, "Glass Cannon floors at one")

for key, suit in pairs({ club = "Clubs", goad = "Spades", window = "Diamonds", head = "Hearts" }) do
	begin(key, "plant")
	local suited, face, other = card(suit, false), card("Other", true), card("Other", false)
	blind:debuff_card(suited)
	blind:debuff_card(face)
	blind:debuff_card(other)
	check(suited.debuff and face.debuff and not other.debuff, "Suit plus Plant composes: " .. key)
	G.playing_cards = { suited, face, card("Other", false, true) }
	R.Round.finish()
	check(
		not suited.debuff and not face.debuff and G.playing_cards[3].debuff,
		"Cleanup preserves unrelated debuff: " .. key
	)
end
begin("club", "head")
local clubs, hearts = card("Clubs"), card("Hearts")
blind:debuff_card(clubs)
blind:debuff_card(hearts)
check(clubs.debuff and hearts.debuff, "Two suit debuffs allowed together")

begin("manacle", "psychic")
G.hand.config.card_limit = 4
check(blind:debuff_hand({ {}, {}, {}, {} }, {}, "Pair", true), "Psychic not protected against small hand capacity")
check(not blind:debuff_hand({ {}, {}, {}, {}, {} }, {}, "Pair", true), "Exactly five cards accepted")

begin("house", "arm")
check(blind:stay_flipped(G.hand, {}), "House hides initial draw")
G.GAME.current_round.discards_used = 1
check(not blind:stay_flipped(G.hand, {}), "House does not hide replacement draw after discard")
blind:debuff_hand({}, {}, "Pair", true)
check(G.GAME.hands.Pair.level == 3, "Arm does not delevel during preview")
blind:debuff_hand({}, {}, "Pair", false)
blind:debuff_hand({}, {}, "Pair", false)
blind:debuff_hand({}, {}, "Pair", false)
check(G.GAME.hands.Pair.level == 1, "Arm floors at level one")
R.Round.finish()
check(G.GAME.hands.Pair.level == 1, "Lost levels persist")

begin("house", "psychic")
immunity = true
check(not blind:stay_flipped(G.hand, {}), "House respects native face-down immunity")
check(not blind:debuff_hand({ {} }, {}, "Pair", true), "Psychic respects native hand-debuff immunity")
begin("club", "plant")
local immune = card("Clubs", true)
blind:debuff_card(immune)
check(not immune.debuff, "Shared card debuffs respect native debuff immunity")
immunity = false

begin("leaf", "club")
local leaf_card = card("Hearts")
G.playing_cards = { leaf_card }
blind:debuff_card(leaf_card)
check(leaf_card.debuff, "Leaf initially debuffs playing cards")
SMODS.calculate_context({ selling_card = true, card = { ability = { set = "Tarot" } } })
check(leaf_card.debuff, "Selling a non-Joker does not clear Leaf")
local one, two = SMODS.calculate_context({ selling_card = true, card = { ability = { set = "Joker" } } })
check(one == "context" and two == "second", "Context wrapper forwards multiple returns")
check(not leaf_card.debuff and R.has("club"), "Joker sale clears only local Leaf condition")

begin("tooth", "hook")
G.hand.cards = { {}, {}, {} }
G.play.cards = {}
check(blind:press_play() == true and G.GAME.dollars == 20, "Tooth waits for queued card transfers")
G.play.cards = { {}, {}, {}, {}, {} }
queue[1].func()
check(G.GAME.dollars == 15, "Tooth charges cards actually transferred to play")
queue[2].func()
check(discarded == 2, "Hook discards exactly two held cards")
R.Round.finish()
check(G.GAME.dollars == 15, "Tooth money loss persists")
begin("tooth", "hook")
G.hand.cards = { {}, {}, {} }
blind:press_play()
local stale_event = queue[2]
R.Round.finish()
stale_event.func()
check(discarded == 2, "Stale Hook event cannot affect next encounter")

begin("manacle", "house")
check(blind:disable() == "disable" and G.hand.config.card_limit == 8, "Boss disabling restores temporary capacity")
check(not R.has("house"), "Disabled rules stop applying")

-- Actual transport/UI entry points: no independent client rolls.
dofile("pvp_api/round_sync.lua")
PVP.current_target_id = function()
	return "b"
end
local offer = MPAPI.ActionTypes.pvp_rules_offer.on_receive
offer(nil, "b", { id = "OFFER", choices = { "club", "head", "arm", "house" }, ms_left = 10000 })
check(R.offer == nil, "Forged non-host offer ignored")
offer(nil, "a", { id = "OFFER", choices = { "club", "head", "arm", "house" }, ms_left = 10000 })
check(R.offer and #G.OVERLAY_MENU.contents == 7, "Offer builds four real choice controls")
G.FUNCS.pvp_shared_pick({ config = { ref_table = { key = "club" } } })
check(sends[#sends].key == "pvp_rules_pick" and sends[#sends].params.rule == "club", "Click sends offered rule request")
local result = { id = "RESOLVED", ante = 5, rules = { "tooth", "house" } }
R.Round.finish()
G.blind_select = {}
local receive = MPAPI.ActionTypes.pvp_start_blind.on_receive
local envelope = { first_player = "a", shared_rules = result, round_id = "ROUND", starting_hands = { b = 5 } }
receive(nil, "a", envelope)
receive(nil, "a", envelope)
check(PVP.GAME.round_sync.id == "ROUND", "Shared-rule start retains target round recovery")
check(dispatched[1][2].startingHands == 5, "Shared-rule start retains opponent starting hands")
check(#dispatched == 1 and #records == 1 and R.offer == nil, "Resolved message starts/logs once and closes picker")
check(PVP.GAME.next_blind_context.UIBox == G.blind_select, "Recovered start uses rebuilt blind UI")
R.Round.finish()
G.STATE = "shop"
receive(nil, "a", {
	first_player = "a",
	round_id = "DEFERRED-ROUND",
	starting_hands = { b = 3 },
	shared_rules = { id = "DEFERRED", ante = 5, rules = { "arm", "house" } },
})
check(R.Round.deferred ~= nil and #dispatched == 1, "Recovery result waits through unfinished shop")
G.STATE = G.STATES.BLIND_SELECT
Game:update(0)
check(R.Round.deferred == nil and #dispatched == 2, "Recovery resumes once blind UI is available")
check(
	PVP.GAME.round_sync.id == "DEFERRED-ROUND" and dispatched[2][2].startingHands == 3,
	"Deferred recovery keeps the complete start envelope"
)
R.Round.finish()
receive(nil, "a", {
	first_player = "a",
	round_id = "SECOND-SAME-ANTE",
	shared_rules = { id = "SECOND-SAME-ANTE", ante = 5, rules = { "manacle", "psychic" } },
})
check(
	#dispatched == 3 and G.GAME.pvp_shared_rules.id == "SECOND-SAME-ANTE",
	"a second PvP in the same ante gets its own draft result"
)
R.Round.finish()
receive(nil, "a", envelope)
check(
	#dispatched == 3 and G.GAME.pvp_shared_rules.id == "SECOND-SAME-ANTE",
	"delayed result for a retired encounter cannot restart it"
)
offer(nil, "a", { id = "RESOLVED", choices = { "club", "head", "arm", "house" }, ms_left = 10000 })
check(R.offer == nil, "delayed offer cannot reopen a retired encounter")
MPAPI.playback.shared_rules({ "REPLAY", 5, "club", "head" }, { is_pov = true })
check(G.GAME.pvp_shared_rules.id == "REPLAY", "POV replay prepares recorded pair without RNG")
MPAPI.playback.shared_rules({ "OTHER", 5, "arm", "head" }, { is_pov = false })
check(G.GAME.pvp_shared_rules.id == "REPLAY", "Opponent replay cannot alter POV rules")
print("Shared PvP rules: " .. checks .. " checks passed")
