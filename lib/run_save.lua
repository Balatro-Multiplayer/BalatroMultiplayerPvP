-- PvP's part of a Run save (MPAPI.run_save): the match state that lives outside vanilla's
-- save table. PVP.GAME holds the lives, timers, scores and per-ante keys of the match. Only
-- a PvP session has any; in other runs the hook gives nothing.
--
-- Three keys cannot be saved. run_started_at and magnet_request_at are this client's own clock readings. next_blind_context is the
-- blind select button (a UI node, with links back into the whole UI tree), which the next
-- blind select fills in again.
local UNSAVED = { next_blind_context = true, run_started_at = true, magnet_request_at = true }

MPAPI.run_save.register_state(PVP.id, {
	save = function()
		if not PVP.LOBBY.in_session() then return nil end
		local state = {}
		for key, value in pairs(PVP.GAME) do
			if not UNSAVED[key] then state[key] = value end
		end
		return state
	end,
	-- Puts the saved match state over a fresh match, so no key of the live state (or of a player
	-- watched before) survives. The blind button is always cleared. The match roster belongs to the
	-- match, not to the run, so the load keeps it.
	load = function(state)
		-- The join keys already went out without this save's run: the rejoin ends here (MPAPI leaves the lobby).
		local refusal = PVP.NET and PVP.NET.take_refusal()
		if refusal then
			attention_text({ text = localize("k_pvp_rejoin_refused"), scale = 0.6, hold = 10, align = "cm", major = G.play })
			error(refusal, 0)
		end
		local match_players = PVP.LOBBY.match_players
		PVP.LOBBY.reset_game()
		PVP.LOBBY.match_players = match_players
		for key, value in pairs(state) do
			PVP.GAME[key] = value
		end
		PVP.GAME.next_blind_context = nil
		-- A PvP blind the save was taken in has the hands and score the server holds, not the save's.
		PVP.GAME.hands_source = PVP.READ.pvp_blind.hands_source_loaded()
	end,
})

-- A Run save each time the game arrives at "pick a hand" inside a PvP blind of a lobby (after the opening draw, each played hand, each discard). Vanilla saves at that same
-- moment, but a lobby switches saving off, so MPAPI's own save is taken instead.
function PVP.ACTIONS.save.blind_due(ctx)
	return ctx.in_lobby and ctx.is_pvp_blind and ctx.arrived and true or false
end

if Game and Game.update_selecting_hand then
	local update_selecting_hand_ref = Game.update_selecting_hand
	function Game:update_selecting_hand(dt)
		local building = not G.STATE_COMPLETE
		update_selecting_hand_ref(self, dt)
		local lobby = MPAPI.get_current_lobby()
		local due = PVP.ACTIONS.save.blind_due({
			in_lobby = lobby ~= nil and PVP.LOBBY.code ~= nil,
			is_pvp_blind = PVP.UTILS.is_pvp_blind(),
			arrived = building and G.STATE_COMPLETE and G.STATE == G.STATES.SELECTING_HAND,
		})
		if not due then return end
		-- Numbered like vanilla's blind select save: a newer pick-a-hand takes over a save put off by a
		-- mod that waits (MPAPI.run_save.register_save_wait).
		local save_point = MPAPI.run_save.start_save_point()
		G.E_MANAGER:add_event(Event({
			trigger = "immediate",
			no_delete = true,
			func = function()
				local ok, err = pcall(MPAPI.run_save.at_save_point, save_point)
				if not ok then sendWarnMessage("[blindsave] " .. tostring(err), "BlindSave") end
				return true
			end,
		}))
	end
end
