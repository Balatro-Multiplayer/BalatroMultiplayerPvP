-- What each inbox item does to the receiving player's run. The server owns the items' effects (the
-- `effect` of an InboxItem in nakama/src/lobby/pvp/core/types.ts) and their fields; match_net runs the
-- next item at a safe point and moves inboxDone behind it. Each effect is a function(item) that
-- checks the item's fields and calls the game (pvp_api/inbox_game.lua). A missing or wrong field
-- refuses the whole item: it raises, match_net logs the reason and still moves past it.
local inbox = {}
PVP.inbox_handlers = inbox

local function text(value)
	return type(value) == "string" and value ~= ""
end

local function refuse(reason)
	error("refused: " .. reason, 0)
end

local function amount_of(item)
	if not PVP.view.whole(item.amount, 1) then refuse("amount must be a whole number above 0") end
	return item.amount
end

-- What a trap gives its owner, by trap key. The fields are read by the names of the one table the
-- sender also builds the record from (pvp_api/_trap_data.lua); the server copies the record as sent.
local function show_only() end

inbox.traps = {
	c_mp_trap_glyph_of_warding = function() PVP.inbox_game.add_tag("tag_mp_ward", nil, false) end,
	c_mp_trap_snare = function(data)
		if data.tag_key ~= nil then PVP.inbox_game.add_tag(data.tag_key, data.orbital_hand, true) end
	end,
	c_mp_trap_alarm = function(data) PVP.inbox_game.add_free_rerolls(data.rerolls) end,
	c_mp_trap_sepia_snake_sigil = function(data) PVP.inbox_game.add_joker(data.key) end,
	c_mp_trap_magic_mouth = function(data) PVP.inbox_game.add_stolen_card(data.card) end,
	c_mp_trap_web = function(data) PVP.inbox_game.add_consumable(data.key, true, data.set) end,
	c_mp_trap_mental_prison = function() PVP.inbox_game.add_wheels(2) end,
	c_mp_trap_faithful_hound = function(data) PVP.inbox_game.level_up_hand(data.hand_type, 3) end,
	c_mp_trap_phase_door = function(data) PVP.inbox_game.add_money(data.dollars, true) end,
}
for _, name in ipairs({ "symbol", "guards_and_wards", "programmed_illusion", "explosive_runes", "fire_trap", "arcane_lock", "forbiddance" }) do
	inbox.traps["c_mp_trap_" .. name] = show_only
end

-- Every effect an item can have: the server's (InboxItem.effect). match_net calls these with the item.
inbox.effects = {
	-- The ante it was eaten for: that ante's PvP blind takes the discards off, so a later ante gets none.
	pizza = function(item)
		local amount = amount_of(item)
		if item.ante == nil then return PVP.inbox_game.add_discards(amount) end
		if not PVP.view.whole(item.ante, 1) then refuse("ante must be a whole number above 0") end
		local now = PVP.inbox_game.ante()
		if now > item.ante then
			return PVP.inbox_game.warn("pizza for ante " .. item.ante .. " dropped in ante " .. now)
		end
		PVP.inbox_game.add_discards(amount)
	end,
	comebackBonus = function(item) PVP.inbox_game.add_comeback_bonus(amount_of(item)) end,
	voucherLife = function(item) PVP.inbox_game.show_life_gained(amount_of(item)) end,
	gambling = function(item) PVP.inbox_game.gambling_payout("j_mp_lets_go_gambling", amount_of(item)) end,
	asteroid = function(item) PVP.inbox_game.lower_best_hand(amount_of(item)) end,
	trapReward = function(item)
		local trap = item.trap
		if type(trap) ~= "table" or not text(trap.key) then refuse("trap.key must be text") end
		local give = inbox.traps[trap.key]
		if not give then refuse("no reward for the trap " .. trap.key) end
		if type(trap.data) ~= "table" then refuse("trap.data must be a table") end
		local data, problem = PVP.trap_data.received(trap.key, trap.data)
		if not data then refuse(problem) end
		give(data)
		PVP.inbox_game.show_trap_fired(trap.key)
	end,
}

return inbox
