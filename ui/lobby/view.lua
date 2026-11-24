PVP.UI.lobby.build = function()
	local L = PVP.UI.lobby
	local lobby = MPAPI.get_current_lobby()

	if lobby and not L.ui_ref then
		L.ref = lobby
		L.ui_ref = MPAPI.create_lobby_ui(lobby)
	end
	if not L.ui_ref then
		return PVP.UI.pre_lobby.build()
	end

	L.create_buttons()
	MPAPI.set_logo_offset(-10, true)

	local rows = {
		{ n = G.UIT.R, config = { align = "cm", padding = 0.1, mid = true }, nodes = { L.ui_ref.node } },
	}
	-- Live: the host republishes the verdict on every lobby change, which refreshes this view.
	if PVP.VERIFIED.is_verified() then
		rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = {
			{ n = G.UIT.C, config = { align = "cm", padding = 0.08, r = 0.1, colour = G.C.GREEN, emboss = 0.05 }, nodes = {
				{ n = G.UIT.T, config = { text = localize("k_pvp_verified_lobby"), scale = 0.45, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
			} },
		} }
	end
	-- A private lobby says what it plays (ui/lobby/mode_banner.lua); a Party has no
	-- gamemode, and a matchmade lobby is already committed to the queue's.
	local is_private = lobby and not PVP.LOBBY.is_matchmaking() and MPAPI.Party.kind_known(lobby) and not MPAPI.Party.is_party_lobby(lobby)
	local banner = is_private and L.build_mode_banner(lobby)
	rows[#rows + 1] = banner or { n = G.UIT.R, config = { minh = 0.2 } }
	rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm" }, nodes = { L.build_controls() } }

	return {
		n = G.UIT.ROOT,
		config = { align = "cm", colour = G.C.CLEAR },
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cm" },
				nodes = rows,
			},
		},
	}
end
