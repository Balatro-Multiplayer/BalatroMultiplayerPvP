-- A normal, saveable solo run with a PvP ruleset and manual house rules.
-- The local lobby supplies MPAPI's ruleset context, not an opponent/referee.
PVP.SOLO = {}

function PVP.is_singleplayer()
	return PVP.SP.singleplayer == true
end

function PVP.SOLO.validate(config)
	if type(config) ~= "table" or not PVP.Rulesets[config.ruleset] then return nil, "ruleset" end
	if config.seed ~= nil and (type(config.seed) ~= "string" or #config.seed > 8 or config.seed:find("[^%w]")) then
		return nil, "seed"
	end
	if type(config.modifiers) ~= "table" then return nil, "modifiers" end
	for _, key in ipairs(config.modifiers) do
		if type(key) ~= "string" then return nil, "modifiers" end
		if
			not PVP.MUTATORS[key]
			and key ~= "multiplayer_jokers"
			and key ~= "no_multiplayer_jokers"
			and key ~= "idol_zealot"
			and key ~= "idol_collector"
			and key ~= "idol_both"
			and key ~= "idol_none"
		then
			return nil, "modifiers"
		end
		if not MPAPI.Layers[key] then return nil, "modifiers" end
	end
	if config.deck and (not G.P_CENTERS[config.deck] or G.P_CENTERS[config.deck].set ~= "Back") then
		return nil, "deck"
	end
	if type(config.stake) ~= "number" or config.stake % 1 ~= 0 or not G.P_CENTER_POOLS.Stake[config.stake] then
		return nil, "stake"
	end
	return true
end

function PVP.SOLO.establish(config)
	local ok, err = PVP.SOLO.validate(config)
	if not ok then return nil, err end
	if MPAPI.get_current_lobby() then return nil, "lobby" end
	PVP.reset_lobby_config()
	PVP.SP.practice = false
	PVP.SP.singleplayer = true
	PVP.SP.ruleset = config.ruleset
	PVP.LOBBY.config.ruleset = config.ruleset
	PVP.LOBBY.config.gamemode = nil
	PVP.LOBBY.config.timer = false
	MPAPI.modifiers_parse(table.concat(config.modifiers, ","))
	local lobby = MPAPI.create_local_lobby(PVP.id, {
		max_players = 1,
		metadata = { ruleset = config.ruleset, modifier_layers = MPAPI.modifiers_serialize() },
	})
	if not lobby then
		PVP.end_session()
		return nil, "lobby"
	end
	lobby.suppress_lobby_view = true
	PVP.CURRENT_LOBBY = lobby
	PVP.reset_game_states()
	return true
end

function PVP.SOLO.start(config)
	local ok, err = PVP.SOLO.validate(config)
	if not ok then return nil, err end
	config = copy_table(config)
	if
		MPAPI.matchmaking.guard_queued(function()
			local started, start_err = PVP.SOLO.start(config)
			if not started then PVP.UI.UTILS.overlay_message(localize("k_solo_invalid_" .. start_err)) end
		end)
	then
		return true
	end
	ok, err = PVP.SOLO.establish(config)
	if not ok then return nil, err end
	G.FUNCS.exit_overlay_menu()
	if config.deck then G.GAME.viewed_back = Back(G.P_CENTERS[config.deck]) end
	-- Even a randomly seeded custom run must not earn vanilla unlocks.
	G.FUNCS.start_run(
		nil,
		{ stake = config.stake, seed = config.seed and config.seed ~= "" and config.seed or generate_starting_seed() }
	)
	return true
end

function PVP.SOLO.restore(save)
	local config = save and save.GAME and save.GAME.pvp_solo
	if not config then return true end
	if PVP.is_singleplayer() then return true end
	return PVP.SOLO.establish(config)
end
