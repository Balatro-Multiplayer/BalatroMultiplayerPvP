-- Saved deck acquisitions, separate from setup-only Back:apply_to_run.
-- The catalogue is deliberately explicit: an arbitrary installed Back cannot
-- safely be applied halfway through a run.
-- Keep chaos_draft save fields and RNG keys stable for existing runs/replays.
PVP.ALMANAC_DRAFT = { definitions = {}, milestones = { [2] = true, [3] = true, [5] = true, [7] = true } }
local D = PVP.ALMANAC_DRAFT

function D.new(seed, player)
	return {
		version = 1,
		seed = tostring(seed) .. ":" .. tostring(player or "solo"),
		acquired = {},
		last_ante = 1,
	}
end

function D.has(state, key)
	for _, acquired in ipairs(state.acquired) do
		if acquired == key then return true end
	end
	return false
end

-- Local integer RNG: independent of both gameplay polls and offer/preview count.
function D.random(seed)
	local value = 1
	for i = 1, #seed do
		value = (value * 31 + seed:byte(i)) % 2147483647
	end
	return function(limit)
		value = (value * 16807) % 2147483647
		return value % limit + 1
	end
end

function D.offer(state, ante, centers)
	-- Keep saved offers stable, including those created before unlock gates.
	if state.pending then return state.pending end
	if ante < 2 or ante <= state.last_ante then return end
	if not D.milestones[ante] then
		-- Acknowledge quiet antes so draft gates and the PvP timer can proceed.
		state.last_ante = ante
		return
	end
	local pool = {}
	for key, definition in pairs(D.definitions) do
		if ante >= definition.min_ante and centers[key] and not D.has(state, key) then pool[#pool + 1] = key end
	end
	table.sort(pool)
	if #pool == 0 then
		state.last_ante = ante
		return
	end
	local random = D.random(state.seed .. ":offers:" .. ante)
	local choices = {}
	for i = 1, math.min(3, #pool) do
		choices[i] = table.remove(pool, random(#pool))
	end
	state.pending = { ante = ante, choices = choices }
	return state.pending
end

function D.commit(state, key, apply)
	if state.busy or not state.pending or D.has(state, key) then return nil, "No pending acquisition" end
	local offered = false
	for _, choice in ipairs(state.pending.choices) do
		if choice == key then offered = true end
	end
	if not offered or not D.definitions[key] then return nil, "Deck was not offered" end
	local allowed, reason = D.can_acquire(key)
	if not allowed then return nil, reason end
	state.busy = true
	-- Mark before callbacks: nested callbacks cannot acquire the same deck again.
	state.acquired[#state.acquired + 1] = key
	state.last_ante = state.pending.ante
	state.pending = nil
	apply(key)
	return true
end

local function add(key, min_ante, lines, apply)
	D.definitions[key] = { min_ante = min_ante, lines = lines, apply = apply }
end

local function resource(field, amount)
	G.GAME.round_resets[field] = G.GAME.round_resets[field] + amount
end

local function voucher(key)
	if G.GAME.used_vouchers[key] then return end
	G.GAME.used_vouchers[key] = true
	Card.apply_to_run(nil, G.P_CENTERS[key])
end

local function consumable(key)
	local card = SMODS.create_card({ key = key, area = G.consumeables, key_append = "chaos_draft" })
	card:add_to_deck()
	G.consumeables:emplace(card)
end

local function configured_grants(key)
	local config = G.P_CENTERS[key].config
	if config.voucher then voucher(config.voucher) end
	for _, value in ipairs(config.vouchers or {}) do
		voucher(value)
	end
	for _, value in ipairs(config.consumables or {}) do
		consumable(value)
	end
end

function D.can_acquire(key)
	local config = G.P_CENTERS[key].config
	if G.GAME.round_resets.hands + (config.hands or 0) < 1 then
		return nil, "This deck would leave fewer than one hand."
	end
	return true
end

add("b_red", 2, { "+1 discard each round." }, function()
	resource("discards", G.P_CENTERS.b_red.config.discards)
end)
add("b_blue", 2, { "+1 hand each round." }, function()
	resource("hands", G.P_CENTERS.b_blue.config.hands)
end)
add("b_yellow", 2, { "Gain $10." }, function()
	ease_dollars(G.P_CENTERS.b_yellow.config.dollars, true)
end)
add("b_green", 2, { "$2 per unused hand.", "$1 per unused discard.", "No interest." }, function()
	local config = G.P_CENTERS.b_green.config
	G.GAME.modifiers.money_per_hand = config.extra_hand_bonus
	G.GAME.modifiers.money_per_discard = config.extra_discard_bonus
	G.GAME.modifiers.no_interest = true
end)
add("b_black", 3, { "+1 Joker slot.", "-1 hand each round." }, function()
	local config = G.P_CENTERS.b_black.config
	resource("hands", config.hands)
	G.jokers.config.card_limit = G.jokers.config.card_limit + config.joker_slot
end)
add("b_magic", 2, { "Gain Crystal Ball if unowned.", "Gain 2 Fools, even if full." }, configured_grants)
add("b_nebula", 2, { "Gain Telescope if unowned.", "-1 consumable slot." }, function(key)
	configured_grants(key)
	G.consumeables.config.card_limit = G.consumeables.config.card_limit + G.P_CENTERS[key].config.consumable_slot
end)
add("b_ghost", 3, { "Spectrals may appear in shops.", "Gain a Hex, even if full." }, function(key)
	G.GAME.spectral_rate = G.P_CENTERS[key].config.spectral_rate
	configured_grants(key)
end)
add(
	"b_abandoned",
	3,
	{ "Destroy all Jacks, Queens", "and Kings in your deck now.", "Destruction effects trigger." },
	function()
		local removed = {}
		for _, card in ipairs(G.playing_cards) do
			local rank = card.base.id
			if rank >= 11 and rank <= 13 then removed[#removed + 1] = card end
		end
		SMODS.destroy_cards(removed)
	end
)
add("b_checkered", 3, { "Clubs become Spades.", "Diamonds become Hearts.", "Other card properties stay." }, function()
	for _, card in ipairs(G.playing_cards) do
		if card.base.suit == "Clubs" then card:change_suit("Spades") end
		if card.base.suit == "Diamonds" then card:change_suit("Hearts") end
	end
end)
add(
	"b_zodiac",
	2,
	{ "Gain Tarot Merchant,", "Planet Merchant and Overstock", "if not already owned." },
	configured_grants
)
add("b_painted", 3, { "+2 hand size.", "-1 Joker slot.", "Existing Jokers are kept." }, function(key)
	local config = G.P_CENTERS[key].config
	G.hand:change_size(config.hand_size)
	G.jokers.config.card_limit = G.jokers.config.card_limit + config.joker_slot
end)
add("b_anaglyph", 2, { "After each future Boss Blind,", "gain a Double Tag." }, function() end)
add(
	"b_erratic",
	2,
	{ "Randomize every card's", "rank and suit now.", "Enhancements, seals, editions stay." },
	function()
		local state = G.GAME.chaos_draft
		local random = D.random(state.seed .. ":erratic:" .. state.last_ante)
		local suits = { "Spades", "Hearts", "Clubs", "Diamonds" }
		local ranks = { "2", "3", "4", "5", "6", "7", "8", "9", "10", "Jack", "Queen", "King", "Ace" }
		for _, card in ipairs(G.playing_cards) do
			SMODS.change_base(card, suits[random(#suits)], ranks[random(#ranks)])
		end
	end
)
add(
	"b_mp_violet",
	2,
	{ "+1 voucher offer per shop.", "30% voucher discount in ante 2.", "No discount from ante 3 onward." },
	function()
		SMODS.change_voucher_limit(1)
		G.GAME.modifiers.mp_violet = true
	end
)
add(
	"b_mp_indigo",
	5,
	{ "+1 choice from Booster Packs.", "Cannot skip usable choices.", "No future Red Card offers." },
	function()
		G.GAME.modifiers.mp_indigo = true
		G.GAME.modifiers.booster_choice_mod = (G.GAME.modifiers.booster_choice_mod or 0) + 1
		G.GAME.banned_keys.j_red_card = true
	end
)
add("b_mp_orange", 5, { "Open a free Giga Standard Pack.", "Gain 2 Hanged Men, even if full." }, function(key)
	configured_grants(key)
	G.GAME.chaos_draft.pack_due = true
end)
add(
	"b_mp_oracle",
	5,
	{ "Gain Clearance Sale and Medium.", "Money cap: $50 + interest cap.", "Excess cash is lost now." },
	function(key)
		configured_grants(key)
		G.GAME.modifiers.oracle_max = 50
		-- Unlike the setup hook, acquisition must handle money already above the cap.
		G.GAME.dollars = math.min(G.GAME.dollars, 50 + G.GAME.interest_cap)
	end
)
add(
	"b_mp_gradient",
	5,
	{ "Adjacent ranks count for", "supported Joker effects.", "Poker hands are unchanged." },
	function()
		G.GAME.modifiers.mp_gradient = true
	end
)
add(
	"b_mp_heidelberg",
	7,
	{ "Leaving a shop creates a", "Negative copy of a random", "consumable you hold." },
	function() end
)
add(
	"b_mp_echodeck",
	7,
	{ "Retrigger playing-card effects.", "Blind scaling increases by 0.2,", "then +0.2 after each Boss." },
	function()
		G.GAME.starting_params.ante_scaling = G.GAME.starting_params.ante_scaling + 0.2
	end
)

function D.apply(key)
	D.definitions[key].apply(key)
end

function D.calculate(back, context)
	local state = G.GAME.chaos_draft
	if not state then return end
	if D.has(state, "b_anaglyph") then Back(G.P_CENTERS.b_anaglyph):trigger_effect(context) end
	if D.has(state, "b_mp_heidelberg") then G.P_CENTERS.b_mp_heidelberg:calculate(back, context) end
	if D.has(state, "b_mp_echodeck") then return G.P_CENTERS.b_mp_echodeck:calculate(back, context) end
end
