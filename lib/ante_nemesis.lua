-- The ante's Nemesis, fixed once per ante and read by anything that targets "my Nemesis".
-- Read it through these two functions:
--   PVP.ante_nemesis_ids() -> array of player ids (empty before a Nemesis is known). One id in
--     every format, except a Manhunt runner: every hunter.
--   PVP.is_ante_nemesis(player_id) -> whether that player is one of them.
-- The ids are the view's run.targets.cardTargets, fixed (see PVP.refresh_ante_nemesis) when the local
-- ante changes, when the match starts, and once the view names a target for the ante. A mid-ante
-- change in the view (new top hunter, new Royale neighbour) does not change them.
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

-- A Manhunt runner's card targets are every hunter; everyone else's is their one target. Empty while
-- the view names none: the later re-check fills the list.
local function read_nemesis_ids()
	return PVP.card_target_ids()
end

-- Fix the ante's Nemesis from the view, then show only that player's Phantom jokers.
function PVP.refresh_ante_nemesis()
	local state = PVP.ante_nemesis
	if not (state and PVP.nemesis_jokers and PVP.nemesis_jokers_hidden) then return end
	local ids = read_nemesis_ids()
	local set = {}
	for _, id in ipairs(ids) do
		set[id] = true
	end
	local ante = G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante
	state.ante = ante
	state.ids = ids
	state.set = set
	PVP.sort_phantoms_by_ante_nemesis()
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
