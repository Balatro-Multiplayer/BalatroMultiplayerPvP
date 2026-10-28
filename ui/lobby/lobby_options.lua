-- The lobby's options screen (previously a no-op placeholder, see ui/lobby/code.lua):
-- a host-only ruleset picker (private lobbies only -- ranked/casual matchmaking
-- already commits to a specific ruleset by which queue option was picked, see
-- pvp_api/queue.lua), plus Manhunt's Hunter/Runner or Teams' A/B role picker when
-- applicable (any lobby kind -- a casual matchmaking-formed Manhunt/Teams match
-- still needs its players to pick a role before the match can start).
--
-- Literal English strings (not localize() keys) match the existing "Practice"
-- ruleset-picker overlay's own style (ui/pvp_main_menu.lua) rather than inventing
-- localization keys ahead of a later polish pass.

local function ruleset_labels()
	return { "Vanilla", localize("k_mp_ruleset_balanced"), localize("k_mp_ruleset_expanded"), "Small World" }
end
local RULESET_KEYS = { "ruleset_mp_vanilla", "ruleset_mp_balanced", "ruleset_mp_expanded", "ruleset_mp_smallworld" }

local function current_ruleset_option()
	for i, key in ipairs(RULESET_KEYS) do
		if PVP.LOBBY.config.ruleset == key then
			return i
		end
	end
	return 2 -- Balanced, the default every gamemode key creates a lobby on.
end

function PVP.build_lobby_options()
	local rows = {}
	local lobby = MPAPI.get_current_lobby()

	if PVP._pvp_kind == PVP.LobbyAccess.PRIVATE then
		rows[#rows + 1] = {
			n = G.UIT.R,
			config = { align = "cm", padding = 0.1 },
			nodes = {
				MPAPI.disableable_option_cycle({
					id = "mp_pvp_ruleset_pick",
					label = "Ruleset",
					options = ruleset_labels(),
					current_option = current_ruleset_option(),
					opt_callback = "mp_pvp_change_ruleset",
					w = 4,
					scale = 0.6,
					enabled = function()
						return lobby and lobby.is_host
					end,
				}).node,
			},
		}
	end

	if PVP.LOBBY.config.manhunt then
		rows[#rows + 1] = {
			n = G.UIT.R,
			config = { align = "cm", padding = 0.1 },
			nodes = {
				MPAPI.disableable_option_cycle({
					id = "mp_pvp_manhunt_role",
					label = "Role",
					options = { "Hunter", "Runner" },
					current_option = (PVP.LOBBY.team_id == "RUNNER") and 2 or 1,
					opt_callback = "mp_pvp_change_manhunt_role",
					w = 4,
					scale = 0.6,
					enabled = function()
						return PVP.LOBBY.team_id == "RUNNER" or not PVP.is_runner_taken()
					end,
				}).node,
			},
		}

		if lobby and lobby.is_host then
			rows[#rows + 1] = {
				n = G.UIT.R,
				config = { align = "cm", padding = 0.1 },
				nodes = {
					create_option_cycle({
						id = "mp_pvp_manhunt_hunter_lives",
						label = "Hunter Lives",
						options = { "7", "8", "9", "10", "11", "12", "13", "14", "15", "16" },
						current_option = (PVP.LOBBY.config.manhunt_hunter_lives or 7) - 6,
						opt_callback = "mp_pvp_change_manhunt_hunter_lives",
						w = 4,
						scale = 0.6,
					}),
				},
			}
		end
	elseif PVP.LOBBY.config.team_based then
		rows[#rows + 1] = {
			n = G.UIT.R,
			config = { align = "cm", padding = 0.1 },
			nodes = {
				create_option_cycle({
					id = "mp_pvp_team_pick",
					label = "My Team",
					options = { "Team A", "Team B" },
					current_option = (PVP.LOBBY.team_id == "B") and 2 or 1,
					opt_callback = "mp_pvp_change_team",
					w = 4,
					scale = 0.6,
				}),
			},
		}
	end

	return create_UIBox_generic_options({ contents = rows })
end

G.FUNCS.mp_pvp_change_ruleset = function(e)
	PVP.LOBBY.config.ruleset = RULESET_KEYS[e.to_key]
	local lobby = MPAPI.get_current_lobby()
	if lobby and lobby.is_host then
		lobby:set_metadata(PVP.pvp_lobby_metadata(PVP._pvp_gamemode, PVP._pvp_kind))
	end
end

G.FUNCS.mp_pvp_change_manhunt_role = function(e)
	PVP.pvp_set_team((e.to_key == 2) and "RUNNER" or "HUNTER")
end

G.FUNCS.mp_pvp_change_team = function(e)
	PVP.pvp_set_team((e.to_key == 2) and "B" or "A")
end

G.FUNCS.mp_pvp_change_manhunt_hunter_lives = function(e)
	PVP.LOBBY.config.manhunt_hunter_lives = e.to_key + 6
	local lobby = MPAPI.get_current_lobby()
	if lobby and lobby.is_host then
		lobby:set_metadata(PVP.pvp_lobby_metadata(PVP._pvp_gamemode, PVP._pvp_kind))
	end
end
