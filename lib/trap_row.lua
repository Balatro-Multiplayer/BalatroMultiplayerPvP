-- The Nemesis consumable row: face-down, display-only copies of the planted Trap cards the ante's
-- Nemesis holds. Every client broadcasts the list of planted Trap cards in its own consumables
-- whenever that list changes (and again when someone joins or rejoins), stores every sender's list,
-- and draws only the ante Nemesis's list(s) in PVP.nemesis_consumeables.
PVP.TRAP_ROW = PVP.TRAP_ROW or {}

local state = { lists = {}, fired = {}, fired_ids = {}, last_sent = nil, counter = 0 }

local function self_id()
	local lobby = MPAPI.get_current_lobby()
	return lobby and lobby.player_id
end

-- Called when a client starts or leaves a run: nothing from the previous run carries over.
function PVP.TRAP_ROW.reset()
	state.lists = {}
	state.fired = {}
	state.fired_ids = {}
	state.last_sent = nil
end

-- Forget the fired ids of the previous ante. Called when the ante's Nemesis is fixed.
function PVP.TRAP_ROW.forget_fired()
	state.fired_ids = {}
end

-- A planted Trap card carries an id in its ability (so it is saved with the card) that is unique
-- among this client's cards. It lets a viewer name one specific card of a sender's list.
function PVP.TRAP_ROW.new_card_id()
	state.counter = state.counter + 1
	return os.time() .. "-" .. state.counter
end

-- Planted Trap cards this client holds that have not fired, in the order of its consumable area.
local function held_entries()
	local entries = {}
	for _, card in ipairs(G.consumeables and G.consumeables.cards or {}) do
		local ability = card.ability
		if ability.mp_trap_hidden and not ability.mp_trap_fired and ability.mp_trap_card_id then
			entries[#entries + 1] = {
				id = ability.mp_trap_card_id,
				key = card.config.center.key,
				owner = ability.mp_trap_owner_id,
			}
		end
	end
	return entries
end

local function signature(entries)
	local parts = {}
	for _, entry in ipairs(entries) do
		parts[#parts + 1] = entry.id .. ":" .. entry.key .. ":" .. tostring(entry.owner)
	end
	return table.concat(parts, "|")
end

-- Records the planted Trap cards that have fired and returns every fired id kept so far, so later messages
-- still name them. A card is flagged fired for a moment before it leaves the consumables, so the sender sees it
-- here. The ids are dropped at the start of each ante: by then every receiver has shown the fire.
local function collect_fired_ids()
	for _, card in ipairs(G.consumeables and G.consumeables.cards or {}) do
		local ability = card.ability
		if ability.mp_trap_hidden and ability.mp_trap_fired and ability.mp_trap_card_id then
			state.fired_ids[ability.mp_trap_card_id] = true
		end
	end
	local ids = {}
	for id in pairs(state.fired_ids) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	return ids
end

-- The one place the held list goes out. `force` sends even when the list is unchanged (a join or a
-- rejoin: the newcomer has none of the lists yet).
function PVP.TRAP_ROW.send_held(force)
	local lobby = MPAPI.get_current_lobby()
	if not (lobby and PVP.nemesis_consumeables and G.consumeables) then return end
	local entries = held_entries()
	local fired = collect_fired_ids()
	local current = signature(entries) .. "#" .. table.concat(fired, ",")
	if not force and current == state.last_sent then return end
	state.last_sent = current
	lobby:action(PVP.TRAP_ROW.held_action):broadcast({ cards = entries, fired = fired })
end

local function row_key(sender, entry_id)
	return sender .. ":" .. entry_id
end

-- The entries that should show now: every list of the ante's Nemesis, in Nemesis order.
local function wanted_entries()
	local wanted = {}
	for _, sender in ipairs(PVP.ante_nemesis_ids()) do
		for _, entry in ipairs(state.lists[sender] or {}) do
			wanted[#wanted + 1] = {
				row_key = row_key(sender, entry.id),
				sender = sender,
				id = entry.id,
				key = entry.key,
				owner = entry.owner,
			}
		end
	end
	return wanted
end

local function add_display_card(area, entry)
	local card = Card(area.T.x + area.T.w / 2, area.T.y, G.CARD_W, G.CARD_H, nil, G.P_CENTERS[entry.key])
	-- Both facings: Card:draw reads sprite_facing, Card:hover reads facing.
	card.facing = "back"
	card.sprite_facing = "back"
	card.ability.mp_trap_display = true
	card.ability.mp_trap_row_key = entry.row_key
	card.ability.mp_trap_row_sender = entry.sender
	card.ability.mp_trap_row_id = entry.id
	card.ability.mp_trap_owner_id = entry.owner
	card.states.click.can = false
	card.states.drag.can = false
	-- stay_flipped: emplace otherwise turns a face-down card face-up.
	area:emplace(card, nil, true)
end

-- The Trapper's view of a fire: the card flips face-up and dissolves where it sits.
local function flip_and_dissolve(card)
	card.ability.mp_trap_row_dissolving = true
	card.states.hover.can = false
	card:flip()
	card:juice_up(0.8, 0.5)
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = 0.9,
		blockable = false,
		func = function()
			card:start_dissolve()
			return true
		end,
	}))
end

local function fired_in_row(card)
	local ability = card.ability
	local fired = state.fired[ability.mp_trap_row_sender]
	return fired and fired[ability.mp_trap_row_id]
end

-- Make the row match the wanted entries. The cards are never added to the deck, so they neither
-- calculate nor count for any effect.
function PVP.TRAP_ROW.refresh()
	local area = PVP.nemesis_consumeables
	if not area then return end
	local wanted = wanted_entries()
	local wanted_keys = {}
	for _, entry in ipairs(wanted) do
		wanted_keys[entry.row_key] = true
	end
	local shown = {}
	local stale = {}
	for _, card in ipairs(area.cards) do
		local key = card.ability.mp_trap_row_key
		-- Phantom jokers share the Nemesis area in Classic: only trap display cards belong to the trap row.
		if card.ability.mp_trap_display and not card.ability.mp_trap_row_dissolving then
			if wanted_keys[key] and not shown[key] then
				shown[key] = true
			else
				stale[#stale + 1] = card
			end
		end
	end
	for _, card in ipairs(stale) do
		if fired_in_row(card) and card.ability.mp_trap_owner_id == self_id() then
			flip_and_dissolve(card)
		else
			area:remove_card(card)
			card:remove()
		end
	end
	for _, entry in ipairs(wanted) do
		if not shown[entry.row_key] then
			add_display_card(area, entry)
		end
	end
end

local function sanitize_ids(ids)
	local set = {}
	for _, id in ipairs(type(ids) == "table" and ids or {}) do
		if type(id) == "string" then
			set[id] = true
		end
	end
	return set
end

local function sanitize(cards)
	local entries = {}
	for _, entry in ipairs(type(cards) == "table" and cards or {}) do
		local center = type(entry) == "table" and type(entry.key) == "string" and G.P_CENTERS[entry.key]
		if center and center.set == "Trap" and type(entry.id) == "string" then
			entries[#entries + 1] = { id = entry.id, key = entry.key, owner = entry.owner }
		end
	end
	return entries
end

PVP.TRAP_ROW.held_action = MPAPI.ActionType({
	key = "pvp_trap_held",
	prefix_config = { key = false },
	parameters = {
		{ key = "cards", type = "table", required = false },
		{ key = "fired", type = "table", required = false },
	},
	on_receive = function(_at, from, params)
		if from == self_id() then return end
		state.lists[from] = sanitize(params.cards)
		state.fired[from] = sanitize_ids(params.fired)
		PVP.TRAP_ROW.refresh()
	end,
})

-- A player who left holds no cards any more.
function PVP.TRAP_ROW.forget(player_id)
	state.lists[player_id] = nil
	state.fired[player_id] = nil
	PVP.TRAP_ROW.refresh()
end

-- Everyone sends again when a player joins or rejoins; a returning client also forgets what it last sent.
function PVP.TRAP_ROW.on_player_back(player_id)
	if player_id == self_id() then
		state.last_sent = nil
		return
	end
	PVP.TRAP_ROW.send_held(true)
end

local game_update_ref = Game.update
function Game:update(dt)
	game_update_ref(self, dt)
	if PVP.nemesis_consumeables then
		PVP.TRAP_ROW.send_held(false)
	end
end

-- Only the card's Trapper sees its name and text. Vanilla shows no tooltip on a face-down card, so
-- the Trapper's hover reads as face-up for the length of the call; the sprite stays face-down.
local card_hover_ref = Card.hover
function Card:hover()
	local ability = self.ability
	if ability and ability.mp_trap_display and ability.mp_trap_owner_id == self_id() then
		local facing = self.facing
		self.facing = "front"
		card_hover_ref(self)
		self.facing = facing
		return
	end
	return card_hover_ref(self)
end
