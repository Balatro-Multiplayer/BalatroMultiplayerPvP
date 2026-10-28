function PVP.lobby.create_buttons()
	local L = PVP.lobby
	if L.buttons_initialized then
		return
	end
	local b = L.buttons

	b.start_game = MPAPI.disableable_button({
		id = "mp_pvp_start_game",
		button = "mp_pvp_start_game",
		colour = G.C.BLUE,
		minw = 3.65,
		minh = 1.55,
		label = localize("b_start_game_cap"),
		scale = 0.7,
		enabled = function()
			local lobby = L.ref
			if not lobby or not lobby.is_host then
				return false
			end
			local players = lobby:get_players()
			if #players < 2 then
				return false
			end
			for _, p in ipairs(players) do
				if p.id ~= lobby.player_id and not L.ready:is_ready(p.id) then
					return false
				end
			end
			return true
		end,
	})
	b.party_find_game = MPAPI.disableable_button({
		id = "mp_pvp_party_find_game",
		button = "mp_pvp_party_find_game",
		colour = G.C.BLUE,
		minw = 3.65,
		minh = 1.55,
		label = { localize("b_find_game_cap") },
		scale = 0.7,
		enabled = function()
			return MPAPI.Party.find_game_enabled(MPAPI.Party.find_game_facts(L.ref, L.ready))
		end,
	})
	b.ready_args = {
		id = "mp_pvp_ready",
		button = "mp_pvp_toggle_ready",
		colour = G.C.GREEN,
		minw = 3.65,
		minh = 1.55,
		label = { localize("b_ready_cap") },
		scale = 0.7,
		col = true,
		enabled = true,
	}
	b.ready = MPAPI.disableable_button(b.ready_args)
	b.lobby_options = MPAPI.disableable_button({
		id = "mp_pvp_lobby_options",
		button = "mp_pvp_lobby_options",
		colour = G.C.ORANGE,
		minw = 2.65,
		minh = 1.35,
		label = localize("b_lobby_options_cap"),
		scale = 0.6,
		col = true,
		-- Ruleset picking is private-lobby-only (ranked/casual already committed to
		-- a ruleset by which queue option was picked); Manhunt/Teams role pickers
		-- apply to any lobby kind, since a casual-formed match still needs roles
		-- picked before it can start.
		enabled = function()
			return PVP.LOBBY.config.manhunt or PVP.LOBBY.config.team_based or PVP._pvp_kind == PVP.LobbyAccess.PRIVATE
		end,
	})
	b.view_code = MPAPI.disableable_button({
		id = "mp_pvp_view_code",
		button = "mp_pvp_view_code",
		colour = G.C.GREEN,
		minw = 3.65,
		minh = 0.6,
		label = { localize("b_view_code_cap") },
		scale = 0.45,
		enabled = true,
	})
	b.copy_code = MPAPI.disableable_button({
		id = "mp_pvp_copy_code",
		button = "mp_pvp_copy_code",
		colour = G.C.PURPLE,
		minw = 3.65,
		minh = 0.6,
		label = { localize("b_copy_code_cap") },
		scale = 0.45,
		enabled = true,
	})
	b.leave = MPAPI.disableable_button({
		id = "mp_pvp_leave_lobby",
		button = "mp_pvp_leave_lobby",
		colour = G.C.RED,
		minw = 3.65,
		minh = 1.55,
		label = localize("b_leave_lobby_cap"),
		scale = 0.7,
		col = true,
		enabled = true,
	})

	L.buttons_initialized = true
end
