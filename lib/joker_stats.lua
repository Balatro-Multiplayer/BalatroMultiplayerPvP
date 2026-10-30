PVP.STATS = {}

function PVP.STATS.get_player_joker_keys()
	local keys = {}
	if not G.jokers or not G.jokers.cards then return keys end
	for i = 1, #G.jokers.cards do
		local card = G.jokers.cards[i]
		if card.config and card.config.center and card.config.center.key then
			if not PVP.is_phantom(card) then table.insert(keys, card.config.center.key) end
		end
	end
	return keys
end

function PVP.STATS.record_match(won)
	local config = PVP.config
	config.joker_stats = config.joker_stats or {}
	config.match_history = config.match_history or {}

	local joker_keys = PVP.STATS.get_player_joker_keys()

	local entry = {
		won = won,
		joker_keys = joker_keys,
		gamemode = PVP.LOBBY.config.gamemode,
		ruleset = PVP.LOBBY.config.ruleset,
		timestamp = os.time(),
		ante_reached = G.GAME.round_resets and G.GAME.round_resets.ante or 1,
	}
	table.insert(config.match_history, entry)

	if won then
		for _, key in ipairs(joker_keys) do
			config.joker_stats[key] = (config.joker_stats[key] or 0) + 1
		end
	end

	SMODS.save_mod_config(PVP)
end

function PVP.STATS.get_joker_wins(joker_key)
	local config = PVP.config
	return config.joker_stats and config.joker_stats[joker_key] or 0
end
