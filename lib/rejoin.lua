-- PvP's side of the crash rejoin. The flow itself (join the lobby first, skip to the last
-- checkpoint, play the tail, resume) is MPAPI's: BalatroMultiplayerAPI/api/playback/rejoin.lua.
-- PvP supplies the hooks: what its run start needs from the log, how to boot the catch-up run,
-- and the state to restore before the run goes live (the lobby mirror, the lobby kind).
--
-- Lives and the Nemesis or Teams target are not rebuilt here. The host sends them when it hears
-- the player is back (PVP.referee_on_player_reconnected); MPAPI holds those messages while the
-- player catches up and plays them once the lobby is attached, after the mirror below has reset
-- the game state. The opponent's REPLAY_TAIL is held and applied the same way
-- (pvp_api/lobby_bridge.lua).
--
-- PvP sets a catch-up limit: the server forfeits a seat that is still catching up after 3 min
-- (nakama lobby/catch_up.ts, keyed by this mod's id).

local function read_lobby_info(args, bootstrap)
	local options = args.options or {}
	bootstrap.sleeve = options.sleeve
	bootstrap.challenge = options.challenge
end

local function read_run_info(args, bootstrap)
	bootstrap.deck = args.deck
end

-- The live lobby replaces the local playback one.
local function attach(lobby, _ctx)
	-- _start_playback ran the catch-up as a practice session; left set, the resumed run stays in
	-- practice mode and its PvP blinds never reach the referee, so the round never resolves.
	PVP.SP.practice = false
	PVP._pvp_kind = PVP.rejoined_lobby_kind(lobby)
	-- The same wiring PVP.pvp_join_lobby does (opponent mirror, HUD, lobby events). It runs before
	-- MPAPI plays the held messages, so the host's lives and target resend lands on a reset state.
	PVP.setup_lobby_mirror(lobby)
end

MPAPI.playback.register_rejoin_hooks(PVP.id, {
	playback_mod_id = "pvp",
	read_lobby_info = read_lobby_info,
	read_run_info = read_run_info,
	start_run = function(bootstrap, on_ready)
		PVP._start_playback(bootstrap, on_ready)
	end,
	attach = attach,
	-- The seat was lost before the run went live (the 3 min catch-up limit, a forfeit, a closed
	-- lobby): what is left is the local catch-up run, which nobody can play on. Leave it.
	aborted = function()
		PVP._drop_playback_waiters()
		G.FUNCS.go_to_menu()
	end,
})
