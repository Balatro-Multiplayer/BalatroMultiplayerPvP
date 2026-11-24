-- The ante's Nemesis, fixed once per ante and read by anything that targets "my Nemesis".
-- Read it through these two functions:
--   PVP.NEMESIS.ante_ids() -> array of player ids (empty before a Nemesis is known). One id in
--     every format, except a Manhunt runner: every hunter.
--   PVP.NEMESIS.is_ante(player_id) -> whether that player is one of them.
-- The ids are the view's run.targets.cardTargets, fixed (see PVP.NEMESIS.refresh_ante) when the local
-- ante changes, when the match starts, and once the view names a target for the ante. A mid-ante
-- change in the view (new top hunter, new Royale neighbour) does not change them.
function PVP.NEMESIS.ante_ids()
	return PVP.NEMESIS.ante and PVP.NEMESIS.ante.ids or {}
end

function PVP.NEMESIS.is_ante(player_id)
	return PVP.NEMESIS.ante ~= nil and PVP.NEMESIS.ante.set[player_id] == true
end

function PVP.NEMESIS.init_ante()
	PVP.NEMESIS.ante = { ante = nil, ids = {}, set = {} }
end

function PVP.NEMESIS.clear_ante()
	PVP.NEMESIS.ante = nil
end

-- A Manhunt runner's card targets are every hunter; everyone else's is their one target. Empty while
-- the view names none: the later re-check fills the list.
local function read_nemesis_ids()
	return PVP.READ.target.card_ids()
end

-- Fix the ante's Nemesis from the view, then show only that player's Phantom jokers.
function PVP.NEMESIS.refresh_ante()
	local state = PVP.NEMESIS.ante
	if not (state and PVP.NEMESIS.jokers and PVP.NEMESIS.hidden_jokers) then return end
	local ids = read_nemesis_ids()
	local set = {}
	for _, id in ipairs(ids) do
		set[id] = true
	end
	local ante = G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante
	state.ante = ante
	state.ids = ids
	state.set = set
	PVP.NEMESIS.sort_phantoms()
	PVP.UI.trap_row.refresh()
end

-- Detect the start of an ante (the local ante changed), and fill in a Nemesis that was still unknown
-- at that point (a Royale target that arrives after the ante change).
local game_update_ref = Game.update
function Game:update(dt)
	game_update_ref(self, dt)
	local state = PVP.NEMESIS.ante
	if not (state and G.GAME and G.GAME.round_resets and PVP.LOBBY and PVP.LOBBY.config) then return end
	if state.ante ~= G.GAME.round_resets.ante then
		PVP.NEMESIS.refresh_ante()
	elseif #state.ids == 0 and #read_nemesis_ids() > 0 then
		PVP.NEMESIS.refresh_ante()
	end
end
