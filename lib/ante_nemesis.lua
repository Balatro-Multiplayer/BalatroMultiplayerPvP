-- The ante's Nemesis, fixed once per ante and read by anything that targets "my Nemesis".
-- Read it through these two functions:
--   PVP.ante_nemesis_ids() -> array of player ids (empty before a Nemesis is known). One id in
--     every format, except a Manhunt runner: every hunter.
--   PVP.is_ante_nemesis(player_id) -> whether that player is one of them.
-- The value is fixed (see PVP.refresh_ante_nemesis) when the local ante changes, when the match
-- starts, and when the Nemesis pairing for the current ante arrives. A mid-ante change of
-- PVP.current_target_id() (new top hunter, new Royale neighbour) does not change it.
function PVP.ante_nemesis_ids()
	return PVP.ante_nemesis and PVP.ante_nemesis.ids or {}
end

function PVP.is_ante_nemesis(player_id)
	return PVP.ante_nemesis ~= nil and PVP.ante_nemesis.set[player_id] == true
end

function PVP.init_ante_nemesis()
	PVP.ante_nemesis = { ante = nil, ids = {}, set = {} }
end

function PVP.clear_ante_nemesis()
	PVP.ante_nemesis = nil
end

-- A Manhunt runner's Nemesis is every hunter, and none until the roster has arrived: the later re-check then
-- fills the whole list. Everyone else's is their current target.
local function read_nemesis_ids()
	if PVP.LOBBY.config.manhunt and PVP.LOBBY.team_id == "RUNNER" then
		local ids = {}
		for id, role in pairs(PVP.LOBBY.roster or {}) do
			if role == "HUNTER" then ids[#ids + 1] = id end
		end
		table.sort(ids)
		return ids
	end
	local target = PVP.current_target_id()
	return target and { target } or {}
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
	local ante = G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante
	if state.ante ~= ante then PVP.TRAP_ROW.forget_fired() end
	state.ante = ante
	state.ids = ids
	state.set = set
	PVP.sort_phantoms_by_ante_nemesis()
	PVP.TRAP_ROW.refresh()
end

-- A Nemesis pairing arrived. It moves the Nemesis only when none is fixed for this ante yet, or when it is
-- for an ante this client has reached and the fixed Nemesis is from an older one. A repeat of the same
-- ante's pairing (a rejoin, a recompute) changes nothing.
function PVP.on_nemesis_pairing(pairing_ante)
	local state = PVP.ante_nemesis
	if not state then return end
	local local_ante = G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante
	if #state.ids == 0 and not (pairing_ante and local_ante and pairing_ante > local_ante) then
		PVP.refresh_ante_nemesis()
	elseif pairing_ante and local_ante and pairing_ante <= local_ante and (state.ante or 0) < pairing_ante then
		PVP.refresh_ante_nemesis()
	end
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
