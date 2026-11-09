-- Offline contracts. Real rendering, SMODS event ordering and gameplay are
-- covered separately by tests/scenarios/almanac_draft.lua.
local checks = 0
local function check(value, message)
	assert(value, message)
	checks = checks + 1
end
local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for k, v in pairs(value) do
		result[k] = copy(v)
	end
	return result
end
PVP = {}
G = { P_CENTERS = {}, GAME = {} }
dofile("lib/almanac/draft.lua")
local D = PVP.ALMANAC_DRAFT
for key in pairs(D.definitions) do
	G.P_CENTERS[key] = { config = {}, key = key }
end

-- Exact cumulative unlock schedule, independent of the implementation catalogue.
local unlocks = {
	[2] = {
		"b_red",
		"b_blue",
		"b_yellow",
		"b_green",
		"b_magic",
		"b_nebula",
		"b_zodiac",
		"b_mp_violet",
		"b_anaglyph",
		"b_erratic",
		"b_mp_orange",
	},
	[3] = { "b_black", "b_painted", "b_ghost", "b_checkered", "b_abandoned" },
	[5] = { "b_mp_indigo", "b_mp_oracle", "b_mp_gradient" },
	[7] = { "b_mp_heidelberg", "b_mp_echodeck" },
}
local expected_unlock = {}
for ante, keys in pairs(unlocks) do
	for _, key in ipairs(keys) do
		expected_unlock[key] = ante
		check(D.definitions[key].min_ante == ante, key .. " unlocks at ante " .. ante)
	end
end
for key in pairs(D.definitions) do
	check(expected_unlock[key], "every acquisition has an explicit scheduled unlock")
end
for _, ante in ipairs({ 2, 3, 5, 7 }) do
	local seen = {}
	for seed = 1, 100 do
		local offer = D.offer(D.new("GATES" .. seed), ante, G.P_CENTERS)
		check(#offer.choices == 3, "three offers at each draft milestone")
		local distinct = {}
		for _, key in ipairs(offer.choices) do
			check(expected_unlock[key] <= ante and not distinct[key], "only eligible distinct decks offered")
			distinct[key], seen[key] = true, true
		end
	end
	for key, unlock in pairs(expected_unlock) do
		check(not not seen[key] == (unlock <= ante), "eligible pool remains cumulative: " .. key)
	end
end
for _, ante in ipairs({ 1, 4, 6, 8, 9, 10, 20 }) do
	local state = D.new("QUIET")
	check(not D.offer(state, ante, G.P_CENTERS), "no draft outside milestones: " .. ante)
	check(state.last_ante == ante, "quiet ante acknowledged for gameplay/timer gates: " .. ante)
	check(not D.offer(state, ante, G.P_CENTERS), "quiet ante remains idempotent")
end
local exhausted = D.new("EXHAUSTED")
for key, ante in pairs(expected_unlock) do
	if ante == 2 then exhausted.acquired[#exhausted.acquired + 1] = key end
end
check(not D.offer(exhausted, 2, G.P_CENTERS), "empty early pool does not leak locked decks")
check(#D.offer(exhausted, 3, G.P_CENTERS).choices == 3, "new unlocks resume an exhausted early pool")
local small_pool = { b_red = {}, b_blue = {}, b_mp_echodeck = {} }
check(#D.offer(D.new("SMALL"), 2, small_pool).choices == 2, "offer fewer rather than fill with locked decks")
local legacy = D.new("LEGACY")
legacy.pending = { ante = 2, choices = { "b_mp_echodeck", "b_black", "b_red" } }
local legacy_offer = legacy.pending
check(D.offer(legacy, 2, G.P_CENTERS) == legacy_offer, "pre-gate saved offers are not rerolled")
legacy.pending.ante = 4
check(D.offer(legacy, 4, G.P_CENTERS) == legacy_offer, "pre-milestone pending offers survive schedule changes")

local configs = {
	b_red = { discards = 1 },
	b_blue = { hands = 1 },
	b_black = { hands = -1, joker_slot = 1 },
	b_yellow = { dollars = 10 },
	b_green = { extra_hand_bonus = 2, extra_discard_bonus = 1 },
	b_magic = { voucher = "v_crystal_ball", consumables = { "c_fool", "c_fool" } },
	b_nebula = { voucher = "v_telescope", consumable_slot = -1 },
	b_ghost = { spectral_rate = 2, consumables = { "c_hex" } },
	b_zodiac = { vouchers = { "v_tarot_merchant", "v_planet_merchant", "v_overstock_norm" } },
	b_painted = { hand_size = 2, joker_slot = -1 },
	b_mp_orange = { consumables = { "c_hanged_man", "c_hanged_man" } },
	b_mp_oracle = { vouchers = { "v_clearance_sale" }, consumables = { "c_medium" } },
}
for key, config in pairs(configs) do
	G.P_CENTERS[key].config = config
end
for _, key in ipairs({
	"v_crystal_ball",
	"v_telescope",
	"v_tarot_merchant",
	"v_planet_merchant",
	"v_overstock_norm",
	"v_clearance_sale",
}) do
	G.P_CENTERS[key] = { key = key }
end
local function reset()
	G.GAME = {
		round_resets = { hands = 4, discards = 3, ante = 1 },
		dollars = 4,
		starting_params = { ante_scaling = 1 },
		modifiers = {},
		banned_keys = {},
		used_vouchers = {},
		interest_cap = 25,
		pseudorandom = { seed = "GAMESEED" },
		almanac_draft = D.new("TEST", "player1"),
	}
	G.hand = {
		config = { card_limit = 8 },
		change_size = function(self, n)
			self.config.card_limit = self.config.card_limit + n
		end,
	}
	G.jokers = { cards = {}, config = { card_limit = 5 } }
	G.consumeables = {
		cards = {},
		config = { card_limit = 2 },
		emplace = function(self, card)
			self.cards[#self.cards + 1] = card
		end,
	}
	G.playing_cards = {}
	for i = 2, 14 do
		G.playing_cards[#G.playing_cards + 1] = {
			base = { id = i, suit = "Clubs" },
			seal = "Red",
			enhancement = "Glass",
			change_suit = function(self, suit)
				self.base.suit = suit
			end,
		}
	end
end
local grants, removed = {}, {}
Card = {
	apply_to_run = function(_, center)
		grants[#grants + 1] = center.key
	end,
}
SMODS = {
	create_card = function(args)
		return { key = args.key, add_to_deck = function() end }
	end,
	destroy_cards = function(cards)
		removed = cards
	end,
	change_base = function(card, suit, rank)
		card.base.suit, card.new_rank = suit, rank
	end,
	change_voucher_limit = function(n)
		G.GAME.modifiers.extra_vouchers = (G.GAME.modifiers.extra_vouchers or 0) + n
	end,
}
function ease_dollars(n)
	G.GAME.dollars = G.GAME.dollars + n
end
reset()
check(not D.offer(G.GAME.almanac_draft, 1, G.P_CENTERS), "ante 1 has no picker")
local first = D.offer(G.GAME.almanac_draft, 2, G.P_CENTERS)
check(#first.choices == 3, "three offers at ante 2")
check(
	first.choices[1] ~= first.choices[2]
		and first.choices[2] ~= first.choices[3]
		and first.choices[1] ~= first.choices[3],
	"distinct offers"
)
check(D.offer(G.GAME.almanac_draft, 3, G.P_CENTERS) == first, "pending offer cannot reroll")
local restored = copy(G.GAME.almanac_draft)
check(table.concat(D.offer(restored, 2, G.P_CENTERS).choices) == table.concat(first.choices), "pending save roundtrip")
local again = D.offer(D.new("TEST", "player1"), 2, G.P_CENTERS)
check(table.concat(first.choices) == table.concat(again.choices), "deterministic offer")
local other = D.offer(D.new("TEST", "player2"), 2, G.P_CENTERS)
check(table.concat(first.choices) ~= table.concat(other.choices), "independent player stream")
check(not D.commit(restored, "b_plasma", D.apply), "reject unoffered/unsupported choice")
check(
	not D.definitions.b_plasma and not D.definitions.b_mp_cocktail and not D.definitions.b_mp_almanac,
	"exclude plasma and meta-decks"
)

local function acquire(key, ante)
	local state = G.GAME.almanac_draft
	state.pending = { ante = ante or state.last_ante + 1, choices = { key } }
	local ok, err = D.commit(state, key, D.apply)
	check(ok, key .. ": " .. tostring(err))
	check(not D.commit(state, key, D.apply), "double confirm rejected: " .. key)
	state.busy = nil -- engine event queue boundary in the live implementation
end
acquire("b_blue")
acquire("b_black")
check(G.GAME.round_resets.hands == 4 and G.jokers.config.card_limit == 6, "Blue/Black compose")
acquire("b_red")
check(G.GAME.round_resets.discards == 4, "Red resource delta")
acquire("b_yellow")
check(G.GAME.dollars == 14, "Yellow pays once")
check(not D.offer(G.GAME.almanac_draft, G.GAME.almanac_draft.last_ante, G.P_CENTERS), "one acquisition per ante")
local next_offer = D.offer(G.GAME.almanac_draft, 7, G.P_CENTERS)
for _, key in ipairs(next_offer.choices) do
	check(not D.has(G.GAME.almanac_draft, key), "owned decks excluded")
end
acquire("b_green")
check(G.GAME.modifiers.no_interest and G.GAME.modifiers.money_per_hand == 2, "Green package")
acquire("b_magic")
acquire("b_nebula")
acquire("b_ghost")
acquire("b_zodiac")
check(#grants == 5 and #G.consumeables.cards == 3, "voucher and consumable grants")
check(G.consumeables.config.card_limit == 1 and G.GAME.spectral_rate == 2, "capacity and spectral policy")
local grant_count = #grants
D.apply("b_zodiac")
check(#grants == grant_count, "owned vouchers not redeemed twice")
acquire("b_painted")
check(G.hand.config.card_limit == 10 and G.jokers.config.card_limit == 5, "Painted package")
acquire("b_abandoned")
check(#removed == 3 and removed[1].base.id == 11 and removed[3].base.id == 13, "physical J/Q/K destroyed, not Aces")
acquire("b_checkered")
check(
	G.playing_cards[1].base.suit == "Spades" and G.playing_cards[1].seal == "Red",
	"Checkered preserves other properties"
)
acquire("b_erratic")
check(G.playing_cards[1].new_rank and G.playing_cards[1].enhancement == "Glass", "Erratic keeps enhancements")
acquire("b_mp_violet")
check(G.GAME.modifiers.extra_vouchers == 1 and G.GAME.modifiers.mp_violet, "Violet")
acquire("b_mp_indigo")
check(G.GAME.modifiers.booster_choice_mod == 1 and G.GAME.banned_keys.j_red_card, "Indigo")
acquire("b_mp_orange")
check(G.GAME.almanac_draft.pack_due and #G.consumeables.cards == 5, "Orange pack entitlement and grants")
G.GAME.dollars = 200
acquire("b_mp_oracle")
check(G.GAME.modifiers.oracle_max == 50 and G.GAME.dollars == 75, "Oracle explicit existing cash clamp")
acquire("b_mp_gradient")
check(G.GAME.modifiers.mp_gradient, "Gradient")
acquire("b_mp_heidelberg")
acquire("b_mp_echodeck")
acquire("b_anaglyph")
check(G.GAME.starting_params.ante_scaling == 1.2, "Echo preserves existing scaling")
check(#G.GAME.almanac_draft.acquired == 21, "all 21 supported decks, no accumulation cap")
check(not D.offer(G.GAME.almanac_draft, 30, G.P_CENTERS), "exhaustion finishes cleanly")
check(G.GAME.almanac_draft.last_ante == 30, "exhaustion advances checkpoint")
local calls = {}
Back = function()
	return {
		trigger_effect = function()
			calls.anaglyph = true
		end,
	}
end
G.P_CENTERS.b_mp_heidelberg.calculate = function()
	calls.heidelberg = true
end
G.P_CENTERS.b_mp_echodeck.calculate = function()
	calls.echo = true
	return { repetitions = 1 }
end
local result = D.calculate({}, {})
check(calls.anaglyph and calls.heidelberg and calls.echo and result.repetitions == 1, "all acquired callbacks dispatch")
reset()
G.GAME.round_resets.hands = 1
check(not D.can_acquire("b_black"), "do not erase Black's cost at a hand floor")
check(D.can_acquire("b_painted"), "capacity reduction retains existing inventory")
local tiny = { b_red = G.P_CENTERS.b_red }
check(#D.offer(D.new("tiny"), 2, tiny).choices == 1, "small remaining pools")

-- Real gate/update/save wrappers with a fake engine boundary.
local progressed, saved, shown = 0, 0, 0
Game = {
	update = function() end,
	update_shop = function()
		progressed = progressed + 1
	end,
	update_blind_select = function()
		progressed = progressed + 1
	end,
}
G.STAGES, G.STATES, G.STAGE = { RUN = 1 }, { SHOP = 2, BLIND_SELECT = 3 }, 1
G.STATE = 3
local quiet = true
MPAPI = { playback = {
	_queues_empty = function()
		return quiet
	end,
} }
save_run = function()
	saved = saved + 1
end
D.show = function()
	shown = shown + 1
	G.OVERLAY_MENU = {}
end
dofile("overrides/almanac_draft.lua")
reset()
G.GAME.almanac_draft.seed_pending = "original-player"
Game:update_blind_select(0)
check(progressed == 1 and shown == 0, "ante 1 runs normally")
check(G.GAME.almanac_draft.seed == "GAMESEED:original-player", "seed finalized after setup")
G.GAME.round_resets.ante = 2
quiet = false
Game:update_shop(0)
check(progressed == 1 and shown == 0, "wait for cashout events before draft")
quiet = true
Game:update_shop(0)
check(progressed == 1 and shown == 1 and saved == 1, "offer before stock generation; pending saved")
G.OVERLAY_MENU = nil
Game:update_shop(0)
check(shown == 2, "closing overlay cannot bypass draft")
local state = G.GAME.almanac_draft
state.pending = { ante = 2, choices = { "b_yellow" } }
check(D.commit(state, "b_yellow", D.apply), "gate acquisition")
local before = saved
save_run()
check(saved == before, "partial acquisition cannot save")
quiet = false
Game:update(0)
check(state.busy, "wait for acquisition events")
quiet = true
Game:update(0)
check(not state.busy and saved == before + 1, "completed acquisition saved")
Game:update_shop(0)
check(progressed == 2, "shop resumes after acquisition")
G.GAME.almanac_draft = nil
Game:update_shop(0)
check(progressed == 3, "ordinary runs untouched")

reset()
G.GAME.almanac_draft.last_ante = 3
G.GAME.round_resets.ante = 4
G.OVERLAY_MENU = nil
local prior_progress, prior_shown = progressed, shown
Game:update_shop(0)
check(progressed == prior_progress + 1 and shown == prior_shown, "quiet ante does not block shop construction")
check(G.GAME.almanac_draft.last_ante == 4, "quiet ante releases the draft timer gate")
G.GAME.round_resets.ante = 5
Game:update_shop(0)
check(progressed == prior_progress + 1 and shown == prior_shown + 1, "next milestone blocks for its draft")
check(G.GAME.almanac_draft.pending.ante == 5, "quiet ante does not consume the next milestone")

-- Gift pack checkpoint spans all choices; partial packs cannot be duplicated.
reset()
G.STATE, G.STATE_COMPLETE, G.OVERLAY_MENU = G.STATES.SHOP, true, nil
G.play, G.CARD_W, G.CARD_H, G.P_CARDS = { T = { x = 0, y = 0 } }, 1, 1, { empty = {} }
G.P_CENTERS.p_mp_standard_giga = {}
setmetatable(Card, {
	__call = function()
		return {}
	end,
})
G.FUNCS = {
	use_card = function()
		G.STATE = 99
	end,
}
state = G.GAME.almanac_draft
state.pack_due = true
before = saved
Game:update(0)
check(saved == before + 1 and state.pack_active and not state.pack_due, "checkpoint before Orange pack")
save_run()
check(saved == before + 1, "no save inside gift pack")
Game:update(0)
check(state.pack_seen, "gift pack was entered")
G.STATE = G.STATES.SHOP
Game:update(0)
check(not state.pack_active and saved == before + 2, "pack completion saved once")

-- UI callback contracts (not a renderer).
function localize(args)
	return type(args) == "table" and args.key or args
end
function Sprite()
	return {}
end
function UIBox_button(args)
	return { button = args }
end
function create_UIBox_generic_options(args)
	return args
end
G.UIT = { R = "row", C = "column", T = "text", O = "object" }
G.C = { WHITE = {}, PURPLE = {}, BLACK = {}, GREEN = {}, RED = {} }
G.ASSET_ATLAS = { centers = {} }
G.FUNCS.overlay_menu = function(args)
	G.OVERLAY_MENU = args.definition
end
G.FUNCS.exit_overlay_menu = function()
	G.OVERLAY_MENU = nil
end
G.FUNCS.deck_info = function()
	G.OVERLAY_MENU = "deck inspector"
end
local records = {}
local sounds = {}
function play_sound(key)
	sounds[#sounds + 1] = key
end
PVP.rlog_active = function()
	return true
end
PVP.RLOG = {
	record = function(op, args)
		records[#records + 1] = { op, copy(args) }
	end,
}
dofile("ui/almanac_draft.lua")
reset()
state = G.GAME.almanac_draft
state.pending = { ante = 2, choices = { "b_blue", "b_yellow", "b_abandoned" } }
D.show()
check(G.OVERLAY_MENU.no_back and G.OVERLAY_MENU.no_esc, "picker is mandatory")
G.FUNCS.pvp_almanac_select({ config = { ref_table = { key = "b_blue" } } })
check(state.pending.selected == "b_blue", "selection is preview only")
check(G.GAME.round_resets.hands == 4, "preview has no effects")
check(D.preview("b_blue"):find("4 %-> 5") ~= nil, "resource preview")
check(D.preview("b_abandoned"):find("Destroy 3") ~= nil, "destruction preview")
G.FUNCS.pvp_almanac_inspect()
check(G.OVERLAY_MENU == "deck inspector" and state.pending, "inspection keeps pending choice")
G.FUNCS.pvp_almanac_select({ config = { ref_table = { key = "b_yellow" } } })
check(
	state.pending.selected == "b_yellow" and #state.acquired == 0,
	"different card changes selection without committing"
)
G.FUNCS.pvp_almanac_select({ config = { ref_table = { key = "b_black" } } })
check(state.pending.selected == "b_yellow", "unoffered card cannot be selected")
G.FUNCS.pvp_almanac_select({ config = { ref_table = { key = "b_blue" } } })
check(#state.acquired == 0, "returning to a previous card only selects it")
G.FUNCS.pvp_almanac_select({ config = { ref_table = { key = "b_blue" } } })
check(G.GAME.round_resets.hands == 5 and state.acquired[1] == "b_blue", "real confirm callback")
check(sounds[1] == "cardSlide1" and sounds[#sounds] == "tarot1", "selection and commit cues")
check(#records == 1 and records[1][1] == "almanac_pick" and records[1][2][3] == "b_blue", "choice recorded")
G.FUNCS.pvp_almanac_select({ config = { ref_table = { key = "b_blue" } } })
check(#records == 1 and G.GAME.round_resets.hands == 5, "double click cannot grant/record again")

-- Exact recorded offers override local replay identity, never opponent state.
local handler
MPAPI.playback.register_handler = function(_, opcode, fn)
	check(opcode == "almanac_pick", "replay opcode registered")
	handler = fn
end
PVP._playback_wait_for = function(predicate, fn)
	check(predicate(), "replay ready boundary")
	fn()
end
dofile("lib/almanac/draft_replay.lua")
reset()
G.STATE = G.STATES.BLIND_SELECT
handler(records[1][2], { is_pov = false })
check(#G.GAME.almanac_draft.acquired == 0, "opponent choice does not mutate POV")
handler(records[1][2], { is_pov = true })
check(G.GAME.round_resets.hands == 5 and D.has(G.GAME.almanac_draft, "b_blue"), "recorded choice replayed")
G.GAME.almanac_draft.busy = nil
handler(records[1][2], { is_pov = true })
check(G.GAME.round_resets.hands == 5, "duplicate replay does not grant twice")

-- Actual multiplayer request/ack path, with transport stubbed. The server may
-- commit before our client saves, but only our normal gate applies effects.
reset()
G.STATE, G.STAGE = G.STATES.BLIND_SELECT, G.STAGES.RUN
G.GAME.round_resets.ante = 2
G.OVERLAY_MENU = nil
local now, requests = 10, {}
love = { timer = {
	getTime = function()
		return now
	end,
} }
copy_table = copy
local network_lobby = {
	code = "ABC123",
	player_id = "a",
	is_host = true,
	server_features = { almanac_draft = 1 },
	_game = { started = { run_id = "RUN" } },
	action = function(_, def)
		return {
			broadcast = function(_, params)
				requests[#requests + 1] = { key = def.key, params = copy(params) }
			end,
		}
	end,
}
MPAPI.get_current_lobby = function()
	return network_lobby
end
MPAPI.ActionTypes = {}
MPAPI.ActionType = function(def)
	MPAPI.ActionTypes[def.key] = def
end
MPAPI.sendWarnMessage = function() end
G.C.UI = { TEXT_LIGHT = {} }
PVP.SHARED_RULES = { definitions = {} }
dofile("pvp_api/actions/_helpers.lua")
dofile("pvp_api/actions/almanac.lua")
dofile("ui/almanac_forecast.lua")
state = G.GAME.almanac_draft
check(D.gate() and not state.pending, "network draft never rolls a local offer")
check(requests[1].key == "pvp_almanac_open", "either player requests the shared offer")
local receive = MPAPI.ActionTypes.pvp_almanac_offer.on_receive
local params = { id = "RUN:decks:2", ante = 2, choices = { "b_blue", "b_yellow", "b_red" } }
receive(nil, "b", params)
check(not D.network_reply, "peer cannot forge a deck offer")
local old = copy(params)
old.id = "OLD:decks:2"
receive(nil, "a", old)
check(not D.network_reply, "delayed offers from the previous run are ignored")
receive(nil, "a", params)
check(D.gate() and state.pending.id == params.id, "shared offer installed at the gate")
check(not D.waiting_state, "received offer replaces the waiting overlay")
local selected = { config = { ref_table = { key = "b_blue" } } }
G.FUNCS.pvp_almanac_select(selected)
G.FUNCS.pvp_almanac_select(selected)
check(#state.acquired == 0 and state.pending.submitted, "click waits for server commitment")
check(requests[#requests].key == "pvp_almanac_pick", "confirmation submits the selected deck")
now = 13
D.gate()
check(
	requests[#requests].key == "pvp_almanac_pick" and requests[#requests].params.deck == "b_blue",
	"lost acknowledgement retransmits the same choice"
)
params.picked = "b_blue"
receive(nil, "a", params)
D.gate()
check(
	#state.acquired == 1 and state.acquired[1] == "b_blue" and state.busy,
	"acknowledged choice applies once through the acquisition barrier"
)
receive(nil, "a", params)
check(not D.network_reply, "duplicate acknowledgement cannot grant twice")
Game:update(0)
check(not state.busy and not D.gate(), "settled commitment saves and releases the shop gate")

-- Restore the pre-commit checkpoint: the server's locked result reapplies once
-- to that old board, rather than generating a different offer.
reset()
G.GAME.round_resets.ante = 2
state = G.GAME.almanac_draft
receive(nil, "a", params)
D.gate()
check(
	G.GAME.round_resets.hands == 5 and state.last_ante == 2,
	"crash recovery applies server commitment to old checkpoint"
)
Game:update(0)
receive(nil, "a", params)
D.gate()
check(G.GAME.round_resets.hands == 5, "recovered commitment remains exactly once")
local prior_pending, prior_acquired = state.pending, #state.acquired
local forecast = D.forecast(state, 2)
check(#forecast == 6 and forecast[2]:find("k_almanac_complete"), "forecast shows completed milestone and full schedule")
check(
	state.pending == prior_pending and #state.acquired == prior_acquired,
	"forecast never generates offers or acquisitions"
)
network_lobby.code = nil
check(not D.networked(), "practice and replay retain the local draft path")
print("Almanac draft: " .. checks .. " checks passed")
