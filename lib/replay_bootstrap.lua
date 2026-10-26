-- Pure helpers for starting a Replay. No game globals are touched at call time,
-- so luajit stub tests can load this file with a bare `PVP` table.

-- Finds this player's own bootstrap data in a built timeline: the first
-- match_manifest (schema_version), the first lobby_info (gamemode, ruleset,
-- sleeve, challenge) and the LAST run_info (seed, deck, stake). A reseeded match
-- logs one run_info per start, and the Replay plays the latest one.
-- Returns nil when the log has no lobby_info or no run_info for this player.
function PVP.replay_bootstrap(timeline, player_id)
	local bootstrap = {}
	local found_manifest, found_lobby, found_run = false, false, false
	for _, entry in ipairs(timeline) do
		if entry.player_id == player_id then
			if not found_manifest and entry.opcode == MPAPI.OPCODE.MATCH_MANIFEST then
				found_manifest = true
				bootstrap.schema_version = entry.args.schema_version
			elseif not found_lobby and entry.opcode == MPAPI.OPCODE.LOBBY_INFO then
				found_lobby = true
				bootstrap.gamemode = entry.args.gamemode
				bootstrap.ruleset = entry.args.ruleset
				local options = entry.args.options or {}
				bootstrap.sleeve = options.sleeve
				bootstrap.challenge = options.challenge
			elseif entry.opcode == MPAPI.OPCODE.RUN_INFO then
				found_run = true
				bootstrap.seed = entry.args.seed
				bootstrap.deck = entry.args.deck
				bootstrap.stake = entry.args.stake
			end
		end
	end
	if not (found_lobby and found_run) then
		return nil
	end
	return bootstrap
end

-- Writes the replay file's deck, stake, sleeve and challenge into both the
-- lobby deck and the lobby config. Later copies of the config (the metadata
-- mirror, copy_host_deck) read the config, so it must hold the real values.
function PVP.apply_replay_loadout(lobby_state, manifest)
	local deck = lobby_state.deck
	local config = lobby_state.config
	deck.back = manifest.deck
	deck.stake = manifest.stake
	deck.sleeve = manifest.sleeve
	deck.challenge = manifest.challenge
	config.back = manifest.deck
	config.stake = manifest.stake
	config.sleeve = manifest.sleeve
	config.challenge = manifest.challenge
	config.ruleset = manifest.ruleset
	config.gamemode = manifest.gamemode
end
