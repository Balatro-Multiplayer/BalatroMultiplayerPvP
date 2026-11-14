-- The ante's Nemesis, read from the server and used by anything that targets "my Nemesis".
-- Read it through these two functions:
--   PVP.ante_nemesis_ids() -> array of player ids; nil while the ante is not known, {} when it is known nobody was my Nemesis.
--     One id in every format, except a Manhunt runner: every hunter.
--   PVP.is_ante_nemesis(player_id) -> whether that player is one of them.
-- The server freezes the row per ante ("pvp.nemesis".byAnte[ante].each) and says which ante I am at
-- ("pvp.round".players[me].ante). Nothing is kept here: a mid-ante change of PVP.current_target_id() (new top
-- hunter, new Royale neighbour) changes nothing, because the frozen row does not move. The Phantom rows and the
-- trap row are re-sorted when the ids read from the state change (PVP.sync_ante_nemesis).
local NEMESIS_KEY = "pvp.nemesis"
local ROUND_KEY = "pvp.round"

local function read_ids()
	local lobby = PVP.NetBasics.pvp_lobby()
	if not lobby then return nil end
	local run_id = PVP.current_run_id()
	local R = PVP.OPPONENT_RECORD
	local ante = R.player_ante(MPAPI.get_state(ROUND_KEY), run_id, lobby.player_id)
	local row = R.nemesis_row(MPAPI.get_state(NEMESIS_KEY), run_id, ante)
	if row == nil or type(row.each) ~= "table" then return nil end
	return row.each
end

function PVP.ante_nemesis_ids()
	return read_ids()
end

function PVP.is_ante_nemesis(player_id)
	for _, id in ipairs(read_ids() or {}) do
		if id == player_id then return true end
	end
	return false
end

-- The ids the rows were last sorted for, joined; nil before the first sort.
local sorted_for = nil

-- The rows were rebuilt (a new run, a loaded save): the next sync sorts them even for the same ids.
function PVP.reset_ante_nemesis_sort()
	sorted_for = nil
end

-- Moves the Phantom jokers and the trap row to match the Nemesis the state names now, when that is not what
-- they were sorted for.
function PVP.sync_ante_nemesis()
	if not (PVP.nemesis_jokers and PVP.nemesis_jokers_hidden) then
		sorted_for = nil
		return
	end
	local ids = read_ids()
	local key = ids and table.concat(ids, ",") or "unknown"
	if key == sorted_for then return end
	sorted_for = key
	PVP.sort_phantoms_by_ante_nemesis()
	PVP.TRAP_ROW.refresh()
end

if MPAPI.on_state then
	MPAPI.on_state(NEMESIS_KEY, PVP.sync_ante_nemesis)
	MPAPI.on_state(ROUND_KEY, PVP.sync_ante_nemesis)
end
