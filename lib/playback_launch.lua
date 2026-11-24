-- Starts a local run that reproduces a recorded match: its seed, deck, stake and ruleset.
-- A local lobby has no code, so nothing is recorded while it plays.
-- `manifest` is the match's recorded "manifest" event.
function PVP.REPLAY.start(manifest, on_ready)
	-- Two lobbies at once fight over MPAPI's current lobby.
	if PVP.LOBBY and PVP.LOBBY.code then
		sendWarnMessage("PVP.REPLAY.start: refusing to start while connected to a real lobby (" .. tostring(PVP.LOBBY.code) .. ")", "MULTIPLAYER")
		return
	end

	-- Gate before any state is set; "Leave Queue & Continue" calls this again.
	if MPAPI.matchmaking.guard_queued(function() return PVP.REPLAY.start(manifest, on_ready) end) then
		return
	end

	PVP.REPLAY.drop_waiters()
	PVP.LOBBY.reset_config()
	PVP.PRACTICE.practice = true
	PVP.PRACTICE.ruleset = manifest.ruleset
	PVP.PRACTICE.playback_gamemode = PVP.REPLAY.gamemode_of(manifest.gamemode)

	local lobby = MPAPI.create_local_lobby(PVP.id, { max_players = 1 })
	if not lobby then
		PVP.PRACTICE.practice = false
		PVP.PRACTICE.playback_gamemode = nil
		return
	end
	lobby.suppress_lobby_view = true
	PVP.LOBBY.kind = PVP.LOBBY.Access.PRACTICE
	PVP.LOBBY.mode_key = manifest.gamemode
	PVP.LOBBY.mirror(lobby)

	-- lobby_start_run reads deck and stake from PVP.LOBBY.deck; the config gets them too, or
	-- the metadata mirror resets the deck to Red Deck.
	PVP.REPLAY.apply_loadout(PVP.LOBBY, manifest)

	PVP.GAME.lives = PVP.LOBBY.config.starting_lives

	-- A restart starts this from inside a run still on screen: wait for the new run's screen.
	local old_game = G.GAME

	lobby:on(MPAPI.LobbyEvent.CONNECTED, function()
		PVP.LOBBY.guest = { username = "???", id = "practice" }
		PVP.UI.lobby.send_settings(lobby, PVP.LOBBY.metadata(manifest.gamemode, PVP.LOBBY.Access.PRACTICE))
		-- CONNECTED fires inside a queued Event, and starting a run clears that queue mid-loop.
		PVP.REPLAY.next_frame(function()
			G.FUNCS.lobby_start_run(nil, { seed = manifest.seed })
		end)
	end)

	PVP.REPLAY.wait_for(function()
		-- A run loaded from a save taken inside a PvP blind comes up at "pick a hand".
		return G.GAME ~= old_game
			and (G.STATE == G.STATES.BLIND_SELECT or (G.STATE == G.STATES.SELECTING_HAND and G.STATE_COMPLETE))
	end, on_ready)
end

-- One-shot waiters, checked each frame.
PVP.REPLAY.waiters = PVP.REPLAY.waiters or {}

function PVP.REPLAY.wait_for(predicate, callback)
	PVP.REPLAY.waiters[#PVP.REPLAY.waiters + 1] = { predicate = predicate, callback = callback }
end

-- Runs `callback` from the next Game:update, outside any event the queue is running.
function PVP.REPLAY.next_frame(callback)
	PVP.REPLAY.wait_for(function()
		return true
	end, callback)
end

-- Waiters belong to the playback run that made them: a new run or the main menu drops them.
function PVP.REPLAY.drop_waiters()
	PVP.REPLAY.waiters = {}
end

local go_to_menu_ref = G.FUNCS.go_to_menu
G.FUNCS.go_to_menu = function(e)
	PVP.REPLAY.drop_waiters()
	return go_to_menu_ref(e)
end

local _playback_launch_update_ref = Game.update
function Game:update(dt)
	_playback_launch_update_ref(self, dt)
	local waiters = PVP.REPLAY.waiters
	for i = #waiters, 1, -1 do
		-- A callback that started a fresh run or left this one dropped the rest.
		if waiters ~= PVP.REPLAY.waiters then
			break
		end
		local w = waiters[i]
		if w.predicate() then
			table.remove(waiters, i)
			w.callback()
		end
	end
end
