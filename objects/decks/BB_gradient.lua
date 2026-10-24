SMODS.Back({
	key = "gradient",
	config = {},
	atlas = "mp_decks",
	pos = { x = 0, y = 1 },
	apply = function(self)
		G.GAME.modifiers.mp_gradient = true -- i forgot how you get the deck, whatever
	end,
	mp_credits = { art = { "aura!", "Ganpan140" }, code = { "Toneblock" } },
})

-- we need to define a bunch of local functions first for some reason

-- water is wet
local function set_temp_id(card, key)
	if not card.orig_id then card.orig_id = card.base.id end
	card.base.id = card.orig_id + G.MP_GRADIENT
	if key ~= "j_raised_fist" then -- otherwise it gets confused and triggers a second card
		if card.base.id == 15 then
			card.base.id = 2
		elseif card.base.id == 1 then
			card.base.id = 14
		end
	end
end

-- if code runs twice it needs a func ig
local function reset_ids()
	if G.MP_GRADIENT then
		G.MP_GRADIENT = nil
		for i, card in ipairs(G.playing_cards) do
			card.base.id = card.orig_id
			card.orig_id = nil
		end
	end
	-- i am checking for G.MP_GRADIENT here. why?
	-- i know this code. i built it myself. this function will always be run at the correct time.
	-- or so i thought. alas, the day after release, i was humbled by a crashlog relating to this exact issue.
	-- i have reordered the code before, this was nothing new. i knew exactly what it was caused by, and i recreated it fairly easily.
	-- but the logic has expanded in complexity since then. no more can i follow where one line ends and the other begins.
	-- the code was watered with passion and motivation, but it grew into thick, thorny vines that stab my hands and block my vision.
	-- there is only pain for the person who decides to touch this. the code does not have emotion, it does not care.
	-- in some twisted way, i am attached to it. it falls short of the greatness expected, but it accomplishes so much.
	-- as a gift, for all it has done, i shift it, ever so slightly, that it thrives.

	-- tldr: i have no idea what this shit is doing anymore, this check shouldn't be necessary
	-- checking this prevents a crash and doesn't seem to break anything
end

local function get_bp(joker)
	local key = joker.config.center.key
	local count = 0
	local pos = 0
	for i, v in ipairs(G.jokers.cards) do
		if v == joker then pos = i end
	end
	while (key == "j_blueprint" or key == "j_brainstorm") and count <= #G.jokers.cards do
		if key == "j_blueprint" then
			key = G.jokers.cards[pos + 1] and G.jokers.cards[pos + 1].config.center.key or "NULL"
			pos = pos + 1
		elseif key == "j_brainstorm" then
			key = G.jokers.cards[1].config.center.key
			pos = 1
		end
		count = count + 1
	end
	return key
end

-- hardcoded dumb stuff, because cards that could trigger but don't due to rng are dumb and stupid and don't return anything
-- ALSO i have to add a whole get blueprint key thing (above) it's so stupid
-- all this to avoid lovely patching? who cares
local function valid_trigger(card, joker)
	local key = joker.config.center.key
	key = get_bp(joker)
	local function rank_check(ranks)
		for i, v in ipairs(ranks) do
			if card:get_id() == v then return true end
		end
		return
	end
	if card and not card.base then -- ??????????????????????
		return false
	end
	if key == "j_8_ball" then
		return rank_check({ 8 }) -- this being a table looks stupid now
	elseif key == "j_hit_the_road" then
		return rank_check({ 11 })
	elseif key == "j_business" or key == "j_reserved_parking" then
		return card:is_face()
	elseif key == "j_bloodstone" or key == "j_mp_bloodstone" or key == "j_mp_bloodstone2" then
		return card:is_suit("Hearts")
	end
end

local is_face_ref = Card.is_face
function Card:is_face(from_boss)
	local ret = is_face_ref(self, from_boss)
	if G.GAME.modifiers.mp_gradient and not G.MP_GRADIENT then
		local id = self:get_id() -- like seriously i want an explanation
		if self.debuff and not from_boss then return end
		if not ret and id == 10 or id == 14 then return true end
	end
	return ret
end

-- hardcoded functions because honk shoo
local function passkey(joker)
	local key = get_bp(joker)
	if key == "j_superposition" or key == "j_sixth_sense" then return true end
	return false
end
local function blacklist(joker)
	local key = get_bp(joker)
	if key == "j_photograph" or key == "j_faceless" or key == "j_ramen" then return true end
	return false
end

-- infamous calculate joker hook
local calculate_joker_ref = Card.calculate_joker
function Card:calculate_joker(context)
	if not context.blueprint then -- very important because bloopy recursively calls this
		if G.GAME.modifiers.mp_gradient and (context.other_card or passkey(self)) and not blacklist(self) then
			for i = 1, 3 do
				G.MP_GRADIENT = -i + 2
				for i, card in ipairs(G.playing_cards) do -- it's actually insane that this doesn't blow up the game??? this is being run thousands of times wastefully
					set_temp_id(card, self.config.center.key)
				end
				local ret, post = calculate_joker_ref(self, context)
				if ret or post or valid_trigger(context.other_card, self) then
					reset_ids()
					return ret, post
				end
			end
			reset_ids()
		end
	end
	return calculate_joker_ref(self, context)
end

-- a special hardcoded hook just for cloud nine! hook hook, hooray!
local update_ref = Card.update
function Card:update(dt)
	local ret = update_ref(self, dt)
	if G.GAME.modifiers.mp_gradient then
		if self.ability and self.ability.name == "Cloud 9" then
			self.ability.nine_tally = 0
			for k, v in pairs(G.playing_cards) do
				local id = v:get_id()
				if id == 8 or id == 9 or id == 10 then self.ability.nine_tally = self.ability.nine_tally + 1 end
			end
		end
	end
end
