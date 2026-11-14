-- The Nemesis consumable row: face-down, display-only copies of the planted Trap cards the ante's
-- Nemesis holds. It is a projection of the server's "pvp.traps" record (pvp_api/traps_net.lua refreshes it on
-- every change): the live traps whose holder is one of the ante's Nemesis ids. A trap the record says fired
-- shows its reveal to the Trapper who owns it, and leaves the row for everyone else.
PVP.TRAP_ROW = PVP.TRAP_ROW or {}

local TRAPS_KEY = "pvp.traps"

local reported = {}

local function self_id()
	local lobby = MPAPI.get_current_lobby()
	return lobby and lobby.player_id
end

local function row_key(holder, id)
	return holder .. ":" .. tostring(id)
end

-- The row for the run's record. Pure: plain tables in, plain tables out.
--   value         the "pvp.traps" value, nil while unknown
--   run_id        the open run
--   nemesis_ids   the ante's Nemesis ids, in Nemesis order
--   is_trap       is_trap(key): whether the key is a trap center this client has (the server does not check keys)
-- Returns { wanted = { { row_key, sender, id, key, owner } }, fired = { [row_key] = true }, refused = { { row_key, key } } }:
-- the live traps held by a Nemesis, and every trap of theirs the record says fired. A live trap whose key is
-- not a trap center is left out of `wanted` and it is named in `refused`.
function PVP.TRAP_ROW.project(value, run_id, nemesis_ids, is_trap)
	local row = { wanted = {}, fired = {}, refused = {} }
	if not PVP.StateValue.same_run(value, run_id) or type(value.traps) ~= "table" then return row end
	for _, holder in ipairs(nemesis_ids) do
		for _, trap in ipairs(value.traps) do
			if trap.holder == holder then
				local key = row_key(holder, trap.id)
				if trap.state == "live" and not is_trap(trap.key) then
					row.refused[#row.refused + 1] = { row_key = row_key(holder, trap.id), key = tostring(trap.key) }
				elseif trap.state == "live" then
					row.wanted[#row.wanted + 1] = { row_key = key, sender = holder, id = trap.id, key = trap.key, owner = trap.owner }
				elseif type(trap.state) == "table" and trap.state.fired ~= nil then
					row.fired[key] = true
				end
			end
		end
	end
	return row
end

-- A trap center of this client: the key names a center of the Trap set.
local function is_trap_center(key)
	local center = type(key) == "string" and key:sub(1, 10) == "c_mp_trap_" and G.P_CENTERS[key] or nil
	return center ~= nil and center.set == "Trap"
end

local function add_display_card(area, entry)
	local card = Card(area.T.x + area.T.w / 2, area.T.y, G.CARD_W, G.CARD_H, nil, G.P_CENTERS[entry.key])
	-- Both facings: Card:draw reads sprite_facing, Card:hover reads facing.
	card.facing = "back"
	card.sprite_facing = "back"
	card.ability.mp_trap_display = true
	card.ability.mp_trap_row_key = entry.row_key
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

-- Make the row match the record. The cards are never added to the deck, so they neither
-- calculate nor count for any effect.
function PVP.TRAP_ROW.refresh()
	local area = PVP.nemesis_consumeables
	if not area then return end
	-- nil while the ante's Nemesis is not known: the row stays as it is until it is.
	local nemesis_ids = PVP.ante_nemesis_ids()
	if nemesis_ids == nil then return end
	local row = PVP.TRAP_ROW.project(MPAPI.get_state(TRAPS_KEY), PVP.current_run_id(), nemesis_ids, is_trap_center)
	-- Each refused trap is logged once: the row is refreshed on every state change.
	for _, refused in ipairs(row.refused) do
		if not reported[refused.row_key] then
			reported[refused.row_key] = true
			PVP.match_log("info", "[pvp] error: trap row skips a card that is not a trap: " .. refused.key)
		end
	end
	local wanted_keys = {}
	for _, entry in ipairs(row.wanted) do
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
		if row.fired[card.ability.mp_trap_row_key] and card.ability.mp_trap_owner_id == self_id() then
			flip_and_dissolve(card)
		else
			area:remove_card(card)
			card:remove()
		end
	end
	for _, entry in ipairs(row.wanted) do
		if not shown[entry.row_key] then
			add_display_card(area, entry)
		end
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
