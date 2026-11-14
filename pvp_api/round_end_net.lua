-- Applies the server's round end and pending deaths ("pvp.round", "pvp.lives").
--
-- Nothing is requested here: the server decides every PvP round and every pending death.
-- On every STATE or SNAPSHOT (and on a later frame, while the run is not loaded yet) this
-- asks lib/round_end_view.lua what is new and calls the existing handlers: endPvP once per
-- round (handsSpent once per round first, when the server spent this player's hands while the round
-- is still open), deathPending once per pending entry, end_pending_death when this player's entry
-- goes.
--
-- Restart rule: the applied marks are PVP.GAME.round_end_applied, so they are saved with the
-- run (lib/run_save.lua saves all of PVP.GAME) and a crash rejoin that restores the run
-- restores them: a round applied before the crash is not applied again, and a round that was
-- decided while the player was down is applied once after the load. lib/rejoin.lua lists the
-- key in CARRIED so the rejoin attach's mirror reset keeps it. A new run starts from
-- reset_game_states, so its marks are fresh; the marks also carry their run id, and marks of
-- another run are dropped. Nothing is kept in module memory, so a process restart and a
-- socket reconnect behave the same.
--
-- endPvP runs only for the round this client is in: lastResult N, PVP.GAME.round_id == N and
-- the player inside the PvP blind (lib/round_end_view.lua); any other round is only marked.
-- ReadyNet sets the round id (a start, or a rejoin restoring it from lastStart). On a rejoin
-- the lobby attach holds the run (PVP.RunGate) for the whole CONNECTED handler, so nothing is
-- read here until ReadyNet has restored it.
--
-- N.on_connected() re-reads the state: a rejoin snapshot can arrive before the lobby's started run
-- is set, and nothing else evaluates again until the next push (lobby_bridge calls it on
-- CONNECTED, as it does for lives_net).

local ROUND_KEY = "pvp.round"
local LIVES_KEY = "pvp.lives"
local RESULT_KEY = "pvp.result"
local RULES_KEY = "pvp.rules"
local TEAMS_KEY = "pvp.teams"

PVP.RoundEndNet = PVP.RoundEndNet or {}
local N = PVP.RoundEndNet

local apply_pending = false

local pvp_lobby = PVP.NetBasics.pvp_lobby

local function run(command)
	if command.kind == "hands_spent" then
		PVP.HANDLERS.handsSpent()
	elseif command.kind == "end_pvp" then
		PVP.HANDLERS.endPvP()
	elseif command.kind == "death_pending" then
		PVP.HANDLERS.deathPending({
			player_id = command.player_id,
			opponent_id = command.opponent_id,
			blind_key = command.blind_key,
			team_id = command.team_id,
		})
	elseif command.kind == "end_pending_death" then
		PVP.end_pending_death()
	end
end

-- Applies what is new, once the run is loaded; until then the work stays pending.
function N.apply_new()
	local lobby = pvp_lobby()
	local run_id = PVP.current_run_id()
	if not lobby or run_id == nil then
		apply_pending = false
		return
	end
	if not PVP.RunGate.loaded() then return end
	apply_pending = false
	local commands, applied = PVP.RoundEndView.decide({
		round_value = MPAPI.get_state(ROUND_KEY),
		lives_value = MPAPI.get_state(LIVES_KEY),
		me = lobby.player_id,
		run_id = run_id,
		applied = PVP.GAME.round_end_applied,
		result_set = PVP.ResultView.result_run(MPAPI.get_state(RESULT_KEY), run_id) ~= nil,
		eliminated = PVP.GAME.eliminated,
		started_count = PVP.LivesView.started_count(MPAPI.get_state(RULES_KEY), run_id),
		hands_left = G.GAME and G.GAME.current_round and G.GAME.current_round.hands_left,
		teams = PVP.RoundEndView.team_map(MPAPI.get_state(TEAMS_KEY), run_id),
		-- PVP.GAME.round_id is set by ReadyNet (a start, or a rejoin restoring it).
		current = {
			round_id = PVP.GAME.round_id,
			in_pvp_blind = (PVP.is_pvp_boss() and G.GAME.blind and G.GAME.blind.in_blind) and true or false,
		},
	})
	-- Marked before the handlers run: a handler that errors must not run twice.
	PVP.GAME.round_end_applied = applied
	for _, command in ipairs(commands) do
		run(command)
	end
end

function N.evaluate()
	if not pvp_lobby() then return end
	apply_pending = true
	N.apply_new()
end

-- CONNECTED: reads the state again, the run may have gone live after the last push.
function N.on_connected()
	N.evaluate()
end

-- Per frame (pvp_api/frame.lua): applies what the run not being loaded yet left pending.
function N.update()
	if apply_pending then N.apply_new() end
end

if MPAPI.on_state then
	MPAPI.on_state(ROUND_KEY, N.evaluate)
	MPAPI.on_state(LIVES_KEY, N.evaluate)
end
