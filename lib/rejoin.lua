-- PvP's side of the crash rejoin. The flow itself (join the lobby first, skip to the last
-- checkpoint, play the tail, resume) is MPAPI's: BalatroMultiplayerAPI/api/playback/rejoin.lua.
-- PvP supplies the hooks: what its run start needs from the log, how to boot the catch-up run,
-- and the state to restore before the run goes live (the lobby mirror, the lobby kind).
--
-- Lives are not rebuilt here: they come from the server's pvp.lives state, which LivesNet reads
-- again at CONNECTED (pvp_api/lobby_bridge.lua), once the lobby is attached. The saved applied
-- index is carried across the mirror's reset below so no life event applies twice. The Nemesis
-- or Teams target comes from the server when it hears the player is back
-- (pvp.targets, pvp.teams); MPAPI holds those messages while the player catches up
-- and plays them once the lobby is attached. The opponent's REPLAY_TAIL is held and applied the
-- same way.
--
-- PvP sets a catch-up limit: the server forfeits a seat that is still catching up after 3 min
-- (nakama lobby/catch_up.ts, keyed by this mod's id).

local function read_lobby_info(args, bootstrap)
	local options = args.options or {}
	bootstrap.sleeve = options.sleeve
	bootstrap.challenge = options.challenge
	bootstrap.the_order_enabled = options.the_order_enabled
end

local function read_run_info(args, bootstrap)
	bootstrap.deck = args.deck
end

-- The match state the run save restored that the mirror's reset must not wipe: the applied
-- lives index (so no life event applies twice), the comeback gold, the round-end marks and the opponent
-- facts indexes (pvp_api/opponent_net.lua: what I applied), and the shop
-- spend counters (the leave-shop report is their difference, so the visit's spend before the crash stays). The lives
-- count is not carried: the saved one is the count at the save and the catch-up run starts from
-- the lobby's starting lives, so it stays unknown (nil, "???") until the server's total arrives.
local CARRIED = {
	"applied",
	"comeback_bonus",
	"comeback_bonus_given",
	"round_end_applied",
	"opponent_applied",
	"replies_applied",
	"traps_applied",
	"traps_sent",
	"trap_rewards_applied",
	"pincher_pending",
	"spent_total",
	"spent_before_shop",
	"shop_marked",
}

-- The live lobby replaces the local playback one.
local function attach(lobby, _ctx)
	-- _start_playback ran the catch-up as a practice session; left set, the resumed run stays in
	-- practice mode and its PvP blinds never reach the server, so the round never resolves.
	PVP.SP.practice = false
	PVP.SP.playback_gamemode = nil
	PVP._pvp_kind = PVP.rejoined_lobby_kind(lobby)
	-- The same wiring PVP.pvp_join_lobby does (opponent mirror, HUD, lobby events). It runs before
	-- MPAPI plays the held messages, so the server's target state lands on a reset state.
	local carried = {}
	for _, key in ipairs(CARRIED) do
		carried[key] = PVP.GAME[key]
	end
	PVP.setup_lobby_mirror(lobby)
	for _, key in ipairs(CARRIED) do
		if carried[key] ~= nil then PVP.GAME[key] = carried[key] end
	end
	-- The carried counters are back: what the catch-up queued goes out, in order.
	PVP.OpponentNet.end_catch_up()
end

MPAPI.playback.register_rejoin_hooks(PVP.id, {
	playback_mod_id = "pvp",
	-- PVP._start_playback starts its run through Game:start_run, so a staged Run save is what
	-- the catch-up run starts from; the match state comes back through lib/run_save.lua.
	supports_run_save = true,
	-- The catch-up can start in a shop loaded from a save: the replayed shop handlers wait for
	-- the shop to have its cards, drawn or loaded.
	run_save_screens = { SHOP = true },
	read_lobby_info = read_lobby_info,
	read_run_info = read_run_info,
	start_run = function(bootstrap, on_ready)
		-- The catch-up numbers my sells and shop slots again, from the saved counters, and queues them unsent.
		PVP.OpponentNet.begin_catch_up()
		PVP._start_playback(bootstrap, on_ready)
	end,
	attach = attach,
	-- Caught up, the replayed PvP start is the past. The catch-up may have stopped the timer box or reset
	-- its fields, so who is timed is read again; the clocks are the server's and need no restoring. The
	-- hands the round's PvP-timer run-outs took come off again (pvp_api/round_net.lua).
	resumed = function()
		PVP.TimerNet.resync()
		PVP.RoundNet.after_rejoin()
	end,
	-- The seat was lost before the run went live (the 3 min catch-up limit, a forfeit, a closed
	-- lobby): what is left is the local catch-up run, which nobody can play on. Leave it.
	aborted = function()
		PVP.OpponentNet.abort_catch_up()
		PVP._drop_playback_waiters()
		G.FUNCS.go_to_menu()
	end,
})
