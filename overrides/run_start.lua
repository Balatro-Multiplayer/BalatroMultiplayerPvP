-- G.FUNCS.start_run wrapper — interprets mp_start (from lobby_start_run); for a
-- non-mp_start start while in a lobby, syncs the chosen deck/stake into PVP.LOBBY.
local start_run_ref = G.FUNCS.start_run
G.FUNCS.start_run = function(e, args)
	if PVP.LOBBY.code then
		if not args.mp_start then
			G.FUNCS.exit_overlay_menu()
			local chosen_stake = args.stake
			if PVP.DECK.MAX_STAKE > 0 and chosen_stake > PVP.DECK.MAX_STAKE then
				PVP.UI.UTILS.overlay_message(
					"Selected stake is incompatible with Multiplayer, stake set to "
						.. SMODS.stake_from_index(PVP.DECK.MAX_STAKE)
				)
				chosen_stake = PVP.DECK.MAX_STAKE
			end
			if PVP.LOBBY.is_host then
				PVP.LOBBY.config.back = args.challenge and "Challenge Deck"
					or (args.deck and args.deck.name)
					or G.GAME.viewed_back.name
				PVP.LOBBY.config.stake = chosen_stake
				PVP.LOBBY.config.sleeve = G.viewed_sleeve
				PVP.LOBBY.config.challenge = args.challenge and args.challenge.id or ""
			end
			PVP.LOBBY.deck.back = args.challenge and "Challenge Deck"
				or (args.deck and args.deck.name)
				or G.GAME.viewed_back.name
			PVP.LOBBY.deck.stake = chosen_stake
			PVP.LOBBY.deck.sleeve = G.viewed_sleeve
			PVP.LOBBY.deck.challenge = args.challenge and args.challenge.id or ""
			-- Publish the host's pick through the lobby metadata: every client's metadata mirror, and
			-- the lobby view refresh on that change, take it from there.
			local lobby = MPAPI.get_current_lobby()
			if PVP.LOBBY.is_host and lobby then
				lobby:set_metadata(PVP.pvp_lobby_metadata(PVP._pvp_gamemode, PVP._pvp_kind))
			end
		else
			start_run_ref(e, {
				challenge = args.challenge,
				stake = tonumber(PVP.LOBBY.deck.stake),
				seed = args.seed,
			})
		end
	else
		start_run_ref(e, args)
	end
end
