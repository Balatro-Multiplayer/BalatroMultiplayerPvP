-- The inbox: what each item the server sends does to the receiving player's run. The server owns the
-- items' effects (the `effect` of an InboxItem in nakama/src/lobby/pvp/core/types.ts) and their fields;
-- the server link runs the next item at a safe point and moves inboxDone behind it. Each effect is a
-- function(item) that checks the item's fields and calls the game (the game calls below). A missing or
-- wrong field refuses the whole item: it raises, the server link logs the reason and still moves past it.
-- A game call makes its change at once or queues it as an event, so the server link's last-item-done
-- event runs after it.
local inbox = {}
PVP.NET.inbox = inbox

-- The server link calls these with each item.
function inbox.install(net)
	net.handlers = inbox.effects
end

local function text(value)
	return type(value) == "string" and value ~= ""
end

local function refuse(reason)
	error("refused: " .. reason, 0)
end

local function amount_of(item)
	if not PVP.READ.view.whole(item.amount, 1) then refuse("amount must be a whole number above 0") end
	return item.amount
end

-- What a trap gives its owner, by trap key. The fields are read by the names of the one table the
-- sender also builds the record from (pvp_api/read/_trap_record.lua); the server copies the record as sent.
local function show_only() end

inbox.traps = {
	c_mp_trap_glyph_of_warding = function() inbox.add_tag("tag_mp_ward", nil, false) end,
	c_mp_trap_snare = function(data)
		if data.tag_key ~= nil then inbox.add_tag(data.tag_key, data.orbital_hand, true) end
	end,
	c_mp_trap_alarm = function(data) inbox.add_free_rerolls(data.rerolls) end,
	c_mp_trap_sepia_snake_sigil = function(data) inbox.add_joker(data.key) end,
	c_mp_trap_magic_mouth = function(data) inbox.add_stolen_card(data.card) end,
	c_mp_trap_web = function(data) inbox.add_consumable(data.key, true, data.set) end,
	c_mp_trap_mental_prison = function() inbox.add_wheels(2) end,
	c_mp_trap_faithful_hound = function(data) inbox.level_up_hand(data.hand_type, 3) end,
	c_mp_trap_phase_door = function(data) inbox.add_money(data.dollars, true) end,
}
for _, name in ipairs({ "symbol", "guards_and_wards", "programmed_illusion", "explosive_runes", "fire_trap", "arcane_lock", "forbiddance" }) do
	inbox.traps["c_mp_trap_" .. name] = show_only
end

-- Every effect an item can have: the server's (InboxItem.effect). the server link calls these with the item.
inbox.effects = {
	-- The ante it was eaten for: that ante's PvP blind takes the discards off, so a later ante gets none.
	pizza = function(item)
		local amount = amount_of(item)
		if item.ante == nil then return inbox.add_discards(amount) end
		if not PVP.READ.view.whole(item.ante, 1) then refuse("ante must be a whole number above 0") end
		local now = inbox.ante()
		if now > item.ante then
			return inbox.warn("pizza for ante " .. item.ante .. " dropped in ante " .. now)
		end
		inbox.add_discards(amount)
	end,
	comebackBonus = function(item) inbox.add_comeback_bonus(amount_of(item)) end,
	voucherLife = function(item) inbox.show_life_gained(amount_of(item)) end,
	gambling = function(item) inbox.gambling_payout("j_mp_lets_go_gambling", amount_of(item)) end,
	asteroid = function(item) inbox.lower_best_hand(amount_of(item)) end,
	trapReward = function(item)
		local trap = item.trap
		if type(trap) ~= "table" or not text(trap.key) then refuse("trap.key must be text") end
		local give = inbox.traps[trap.key]
		if not give then refuse("no reward for the trap " .. trap.key) end
		if type(trap.data) ~= "table" then refuse("trap.data must be a table") end
		local data, problem = PVP.READ.trap_record.received(trap.key, trap.data)
		if not data then refuse(problem) end
		give(data)
		inbox.show_trap_fired(trap.key)
	end,
}


-- The game calls.
function inbox.warn(message)
	sendWarnMessage("[inbox] " .. message, "MULTIPLAYER")
end

function inbox.ante()
	return G.GAME.round_resets.ante
end

function inbox.add_money(amount, at_once)
	ease_dollars(amount, at_once)
end

function inbox.add_discards(amount)
	PVP.GAME.pizza_discards = PVP.GAME.pizza_discards + amount
	G.GAME.round_resets.discards = G.GAME.round_resets.discards + amount
	ease_discard(amount)
end

-- Let's Go Gambling misfire: the server's amount (main's copy amount, always $10). The copy only juices up.
function inbox.gambling_payout(card_key, amount)
	local copy = PVP.UTILS.get_phantom_joker(card_key)
	if copy then copy:juice_up() end
	inbox.add_money(amount)
end

function inbox.lower_best_hand(levels)
	for _ = 1, levels do
		PVP.UI.show_asteroid_hand_level_up()
	end
end

function inbox.add_comeback_bonus(amount)
	PVP.GAME.comeback_payout = "pending"
	PVP.GAME.comeback_bonus = PVP.GAME.comeback_bonus + amount
end

function inbox.show_life_gained(amount)
	PVP.UI.ease_lives(amount)
end

function inbox.show_trap_fired(trap_key)
	PVP.UI.show_trap_fired_animation(localize({ type = "name_text", set = "Trap", key = trap_key }))
end

function inbox.add_free_rerolls(amount)
	PVP.TRAP.grant_free_rerolls(amount)
end

-- The copy keeps the original's poker hand; a tag that acts at once is run here because vanilla does
-- that only on a skip.
function inbox.add_tag(tag_key, orbital_hand, at_once)
	G.orbital_hand = orbital_hand
	local tag = Tag(tag_key)
	G.orbital_hand = nil
	add_tag(tag)
	if at_once then tag:apply_to_run({ type = "immediate" }) end
end

-- A card that does not fit is lost; a negative card needs no room.
function inbox.add_consumable(card_key, negative, set)
	if not G.P_CENTERS[card_key] then return inbox.warn("no consumable " .. card_key) end
	local has_room = #G.consumeables.cards + G.GAME.consumeable_buffer < G.consumeables.config.card_limit
	if has_room or negative then
		SMODS.add_card({ key = card_key, set = set, area = G.consumeables, edition = negative and "e_negative" or nil })
	end
end

-- The Magic Mouth's stolen card, as the Nemesis's game saved it; it is lost when there is no room.
function inbox.add_stolen_card(saved_card)
	local has_room = #G.consumeables.cards + G.GAME.consumeable_buffer < G.consumeables.config.card_limit
	if has_room then MPAPI.rebuild_card(saved_card, G.consumeables) end
end

-- Built directly: SMODS.add_card would poll shared random streams.
function inbox.add_wheels(amount)
	for _ = 1, amount do
		if #G.consumeables.cards + G.GAME.consumeable_buffer < G.consumeables.config.card_limit then
			G.GAME.consumeable_buffer = G.GAME.consumeable_buffer + 1
			G.E_MANAGER:add_event(Event({
				trigger = "before",
				delay = 0.0,
				func = function()
					local wheel = Card(G.consumeables.T.x, G.consumeables.T.y, G.CARD_W, G.CARD_H, nil, G.P_CENTERS.c_wheel_of_fortune)
					wheel:add_to_deck()
					G.consumeables:emplace(wheel)
					G.GAME.consumeable_buffer = math.max(0, G.GAME.consumeable_buffer - 1)
					return true
				end,
			}))
		end
	end
end

function inbox.add_joker(card_key)
	if #G.jokers.cards + G.GAME.joker_buffer < G.jokers.config.card_limit then
		SMODS.add_card({ key = card_key, set = "Joker", area = G.jokers })
	end
end

function inbox.level_up_hand(hand, levels)
	level_up_hand(nil, hand, true, levels)
end

return inbox
