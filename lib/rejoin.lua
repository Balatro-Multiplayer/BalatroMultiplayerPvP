-- PvP's hooks for MPAPI's crash rejoin (api/playback/rejoin.lua): what the run start needs from
-- the log, how to start the run, and what to reset before it goes live. Lives, targets and the
-- opponent come back in the server's view.

local function read_lobby_info(args, bootstrap)
	local options = args.options or {}
	bootstrap.sleeve = options.sleeve
	bootstrap.challenge = options.challenge
	bootstrap.the_order_enabled = options.the_order_enabled
end

local function read_run_info(args, bootstrap)
	bootstrap.deck = args.deck
end

-- The live lobby replaces the local one.
local function attach(lobby, _ctx)
	-- Left set, the resumed run stays a practice run and its PvP blinds never reach the server.
	PVP.SP.practice = false
	PVP.SP.playback_gamemode = nil
	PVP._pvp_kind = PVP.rejoined_lobby_kind(lobby)
	-- Before MPAPI plays the held messages, so the view lands on a reset state.
	PVP.setup_lobby_mirror(lobby)
end

MPAPI.playback.register_rejoin_hooks(PVP.id, {
	playback_mod_id = "pvp",
	-- The run starts through Game:start_run, so it starts from the staged Run save.
	supports_run_save = true,
	read_lobby_info = read_lobby_info,
	read_run_info = read_run_info,
	start_run = function(bootstrap, on_ready)
		PVP._start_playback(bootstrap, on_ready)
	end,
	attach = attach,
	-- The seat was lost before the run went live: nobody can play on, so leave.
	aborted = function()
		PVP._drop_playback_waiters()
		G.FUNCS.go_to_menu()
	end,
})
