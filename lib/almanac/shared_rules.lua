-- A shared rule is a boss effect added on top of the PvP blind. Each rule is a
-- record with the hooks a Blind has, under the same names and signatures:
--
--   set_blind(self)                               the round became active
--   disable(self)                                 undo set_blind; runs once
--   press_play(self) -> triggered
--   debuff_hand(self, cards, hand, handname, check) -> debuffed
--   recalc_debuff(self, card) -> debuffed         playing cards only
--   stay_flipped(self, area, card, from_area) -> face_down
--   calculate(self, context)                      any other SMODS context
--   final_scoring_step(self, chips, mult) -> chips, mult
--
-- overrides/shared_pvp_rules.lua calls them for the rules in force
-- (R.in_force). Keys and antes are mirrored by the server's RULE_ANTES.
PVP.SHARED_RULES = { definitions = {} }
local R = PVP.SHARED_RULES

local Rule = {}
Rule.__index = Rule

function R.Rule(def)
	R.definitions[def.key] = setmetatable(def, Rule)
end

-- Queues fn as an event. It runs only if this rule is still in force in the
-- same round by then.
function Rule:queue(fn, config)
	local round = R.Round.current()
	config = config or {}
	config.func = function()
		if R.Round.current() == round and R.has(self.key) then fn() end
		return true
	end
	G.E_MANAGER:add_event(Event(config))
end

function R.supported(lobby)
	return lobby and lobby.server_features and lobby.server_features.shared_pvp_rules == 2
end

function R.enabled(lobby)
	return lobby
		and R.supported(lobby)
		and MPAPI.has_server_referee(lobby)
		and #lobby:get_players() == 2
		and (
			(lobby:get_metadata() or {}).ruleset == "ruleset_mp_almanac"
			or (lobby:get_metadata() or {}).deck == "Almanac"
			or (
				(lobby:get_metadata() or {}).kind == PVP.LobbyAccess.PRIVATE
				and (lobby:get_metadata() or {}).shared_pvp_rules == true
			)
		)
end

-- Whether `key` is one of the active round's rules and has not been disabled.
function R.has(key)
	local round = R.Round.current()
	if not round or round.phase ~= R.Round.Phase.ACTIVE or round.disabled[key] then return false end
	for _, rule in ipairs(round.rules) do
		if rule == key then return true end
	end
	return false
end

-- Iterates the active round's rules that are in force, in the round's order.
-- With `hook`, only the rules that define it.
function R.in_force(hook)
	local round = R.Round.current()
	local keys = round and round.phase == R.Round.Phase.ACTIVE and round.rules or {}
	local i = 0
	return function()
		while i < #keys do
			i = i + 1
			local rule = R.definitions[keys[i]]
			if not round.disabled[rule.key] and (not hook or rule[hook]) then return rule end
		end
	end
end

function R.refresh_debuffs()
	for _, card in ipairs(G.playing_cards or {}) do
		SMODS.recalc_debuff(card)
	end
end

local function debuffs_suit(suit)
	return function(_, card)
		return card:is_suit(suit, true)
	end
end

R.Rule({
	key = "manacle",
	label = "The Manacle",
	text = "-1 hand size.",
	ante = 3,
	set_blind = function()
		G.hand:change_size(-1)
	end,
	disable = function()
		if G.hand then G.hand:change_size(1) end
	end,
})

R.Rule({
	key = "psychic",
	label = "The Psychic",
	text = "Must play exactly 5 cards.",
	ante = 3,
	debuff_hand = function(_, cards)
		return #cards ~= 5
	end,
})

R.Rule({
	key = "house",
	label = "The House",
	text = "Initial hand drawn face down.",
	ante = 3,
	stay_flipped = function(_, area)
		return area == G.hand and G.GAME.current_round.hands_played == 0 and G.GAME.current_round.discards_used == 0
	end,
})

R.Rule({
	key = "club",
	label = "The Club",
	text = "Clubs are debuffed.",
	ante = 3,
	recalc_debuff = debuffs_suit("Clubs"),
})

R.Rule({
	key = "goad",
	label = "The Goad",
	text = "Spades are debuffed.",
	ante = 3,
	recalc_debuff = debuffs_suit("Spades"),
})

R.Rule({
	key = "window",
	label = "The Window",
	text = "Diamonds are debuffed.",
	ante = 3,
	recalc_debuff = debuffs_suit("Diamonds"),
})

R.Rule({
	key = "head",
	label = "The Head",
	text = "Hearts are debuffed.",
	ante = 3,
	recalc_debuff = debuffs_suit("Hearts"),
})

-- The lost hands are this round's only: round_resets is untouched, so there is
-- nothing to undo.
R.Rule({
	key = "glass_cannon",
	label = "Glass Cannon",
	text = "-2 hands (minimum 1); X4 Mult.",
	ante = 3,
	set_blind = function()
		local hands = G.GAME.current_round.hands_left
		ease_hands_played(math.max(1, hands - 2) - hands)
	end,
	final_scoring_step = function(_, chips, mult)
		return chips, mult * 4
	end,
})

R.Rule({
	key = "tooth",
	label = "The Tooth",
	text = "Lose $1 per card played.",
	ante = 3,
	press_play = function(self)
		-- The played cards reach G.play through events queued before press_play.
		self:queue(function()
			ease_dollars(-#G.play.cards)
		end, { trigger = "after", delay = 0.2 })
		return true
	end,
})

R.Rule({
	key = "arm",
	label = "The Arm",
	text = "Played hand loses 1 level before scoring (minimum 1).",
	ante = 3,
	debuff_hand = function(_, _, _, handname, check)
		if not check and G.GAME.hands[handname].level > 1 then
			level_up_hand(G.GAME.blind.children.animatedSprite, handname, nil, -1)
		end
	end,
})

R.Rule({
	key = "leaf",
	label = "Verdant Leaf",
	text = "Playing cards debuffed until you sell a Joker.",
	ante = 4,
	recalc_debuff = function()
		return true
	end,
	calculate = function(self, context)
		if context.selling_card and context.card and context.card.ability.set == "Joker" then
			R.Round.disable_rule(self.key)
		end
	end,
})

R.Rule({
	key = "hook",
	label = "The Hook",
	text = "Discard 2 random held cards after each played hand.",
	ante = 5,
	press_play = function(self)
		self:queue(function()
			local pool = {}
			for _, card in ipairs(G.hand.cards) do
				pool[#pool + 1] = card
			end
			for _ = 1, math.min(2, #pool) do
				local card, index = pseudorandom_element(pool, pseudoseed("hook"))
				G.hand:add_to_highlighted(card, true)
				table.remove(pool, index)
			end
			if #pool < #G.hand.cards then G.FUNCS.discard_cards_from_highlighted(nil, true) end
		end)
		delay(0.7)
		return true
	end,
})

R.Rule({
	key = "plant",
	label = "The Plant",
	text = "Face cards are debuffed.",
	ante = 5,
	recalc_debuff = function(_, card)
		return card:is_face(true)
	end,
})

R.Rule({
	key = "water",
	label = "The Water",
	text = "Start with 0 discards.",
	ante = 5,
	set_blind = function()
		ease_discard(-G.GAME.current_round.discards_left)
	end,
})
