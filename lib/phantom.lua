local get_card_areas_ref = SMODS.get_card_areas
function SMODS.get_card_areas(_type, _context)
	if _type == "jokers" and PVP.nemesis_jokers then
		local t = get_card_areas_ref(_type, _context)
		table.insert(t, PVP.nemesis_jokers)
		return t
	end
	return get_card_areas_ref(_type, _context)
end

-- Gap between the bottom of the Nemesis slots and the top of the player's own rows, in game units.
PVP.NEMESIS_SLOT_GAP = 1

local function remove_nemesis_slots()
	PVP.ante_nemesis = nil
	PVP.TRAP_ROW.reset()
	for _, key in ipairs({ "nemesis_jokers", "nemesis_jokers_hidden", "nemesis_consumeables" }) do
		if PVP[key] then
			PVP[key]:remove()
			PVP[key] = nil
		end
	end
end

local function new_nemesis_row(width, height)
	return CardArea(0, 0, width, height, {
		card_limit = 0,
		type = "joker",
		highlight_limit = 1,
		fixed_limit = true,
		no_card_count = true,
	})
end

-- Called from Game:start_run with the vanilla area sizes. The rows exist only in a live lobby.
function PVP.create_nemesis_slots(card_area_sizes)
	remove_nemesis_slots()
	if not PVP.LOBBY.code then return end
	PVP.nemesis_jokers = new_nemesis_row(card_area_sizes.joker_W, card_area_sizes.joker_H)
	PVP.nemesis_consumeables = new_nemesis_row(card_area_sizes.consumeable_W, card_area_sizes.consumeable_H)
	-- Phantom jokers of players who are not the ante's Nemesis wait here: kept in memory, never drawn,
	-- never in the joker calculation, and parked off-screen so the cursor cannot hit them.
	PVP.nemesis_jokers_hidden = new_nemesis_row(card_area_sizes.joker_W, card_area_sizes.joker_H)
	PVP.nemesis_jokers_hidden.states.visible = false
	PVP.nemesis_jokers_hidden.T.x = -100
	PVP.nemesis_jokers_hidden.T.y = -100
	PVP.nemesis_jokers_hidden:hard_set_T()
	PVP.ante_nemesis = { ante = nil, ids = {}, set = {} }
end

-- The ante's Nemesis, fixed once per ante and read by anything that targets "my Nemesis".
-- Read it through these two functions:
--   PVP.ante_nemesis_ids() -> array of player ids (empty before a Nemesis is known). One id in
--     every format, except a Manhunt runner: every hunter.
--   PVP.ante_nemesis_id() -> the first of those ids, or nil.
-- The value is fixed (see PVP.refresh_ante_nemesis) when the local ante changes, when the match
-- starts, and when the Nemesis pairing for the current ante arrives. A mid-ante change of
-- PVP.current_target_id() (new top hunter, new Royale neighbour) does not change it.
function PVP.ante_nemesis_ids()
	return PVP.ante_nemesis and PVP.ante_nemesis.ids or {}
end

function PVP.ante_nemesis_id()
	return PVP.ante_nemesis_ids()[1]
end

function PVP.is_ante_nemesis(player_id)
	return PVP.ante_nemesis ~= nil and PVP.ante_nemesis.set[player_id] == true
end

-- A Manhunt runner's Nemesis is every hunter. Everyone else's is their current target.
local function read_nemesis_ids()
	if PVP.LOBBY.config.manhunt and PVP.LOBBY.team_id == "RUNNER" then
		local ids = {}
		for id, role in pairs(PVP.LOBBY.roster or {}) do
			if role == "HUNTER" then ids[#ids + 1] = id end
		end
		table.sort(ids)
		if #ids > 0 then return ids end
	end
	local target = PVP.current_target_id()
	return target and { target } or {}
end

-- Where a copy from this sender lives: the visible row for the ante's Nemesis, the hidden store for the rest.
function PVP.nemesis_phantom_area(from)
	if PVP.is_ante_nemesis(from) then return PVP.nemesis_jokers end
	return PVP.nemesis_jokers_hidden
end

local function move_phantoms(from_area, to_area, wants_visible)
	local moving = {}
	for _, card in ipairs(from_area.cards) do
		local ability = card.ability
		if ability and ability.mp_phantom and PVP.is_ante_nemesis(ability.mp_phantom_from) == wants_visible then
			moving[#moving + 1] = card
		end
	end
	for _, card in ipairs(moving) do
		from_area:remove_card(card)
		to_area:emplace(card)
	end
end

-- Fix the ante's Nemesis from the current target, then show only that player's Phantom jokers.
function PVP.refresh_ante_nemesis()
	local state = PVP.ante_nemesis
	if not (state and PVP.nemesis_jokers and PVP.nemesis_jokers_hidden) then return end
	local ids = read_nemesis_ids()
	local set = {}
	for _, id in ipairs(ids) do
		set[id] = true
	end
	state.ante = G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante
	state.ids = ids
	state.set = set
	move_phantoms(PVP.nemesis_jokers, PVP.nemesis_jokers_hidden, false)
	move_phantoms(PVP.nemesis_jokers_hidden, PVP.nemesis_jokers, true)
	PVP.TRAP_ROW.refresh()
end

-- Detect the start of an ante (the local ante changed), and fill in a Nemesis that was still unknown
-- at that point (a Royale target that arrives after the ante change).
local game_update_ref = Game.update
function Game:update(dt)
	game_update_ref(self, dt)
	local state = PVP.ante_nemesis
	if not (state and G.GAME and G.GAME.round_resets and PVP.LOBBY and PVP.LOBBY.config) then return end
	if state.ante ~= G.GAME.round_resets.ante then
		PVP.refresh_ante_nemesis()
	elseif #state.ids == 0 and #read_nemesis_ids() > 0 then
		PVP.refresh_ante_nemesis()
	end
end

-- Called from set_screen_positions: each Nemesis row mirrors the x and width of the player's row below it.
function PVP.place_nemesis_slots()
	local pairs_to_place = {
		{ PVP.nemesis_jokers, G.jokers },
		{ PVP.nemesis_consumeables, G.consumeables },
	}
	for _, pair in ipairs(pairs_to_place) do
		local nemesis_row, own_row = pair[1], pair[2]
		if nemesis_row then
			nemesis_row.T.x = own_row.T.x
			nemesis_row.T.y = own_row.T.y - PVP.NEMESIS_SLOT_GAP - nemesis_row.T.h
			nemesis_row:hard_set_T()
		end
	end
end

-- Register the Nemesis joker row with the synced-object framework so `phantom = true`
-- jokers spawn their display copies here, and install the masking patches
-- (find_card / poll_edition / Card:remove) that hide phantom cards from real gameplay.
if MPAPI and MPAPI.configure_phantom then
	MPAPI.configure_phantom({
		area = function(from)
			return PVP.nemesis_phantom_area(from)
		end,
	})
end
