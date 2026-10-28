local function code_panel()
	local b = PVP.lobby.buttons
	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.1, r = 0.2, colour = G.C.BLACK },
		nodes = {
			{ n = G.UIT.C, config = { align = "cm", maxh = 1.4 }, nodes = {
				{ n = G.UIT.T, config = { text = localize("k_lobby_code_cap"), scale = 0.45, colour = G.C.UI.TEXT_LIGHT, vert = true, maxh = 1.4 } },
			} },
			{ n = G.UIT.C, config = { align = "cm", padding = 0.1 }, nodes = {
				{ n = G.UIT.R, config = { align = "cm" }, nodes = { b.view_code.node } },
				{ n = G.UIT.R, config = { align = "cm" }, nodes = { b.copy_code.node } },
			} },
		},
	}
end

-- Read-only deck box (host deck picker is a later addition), purple and button-sized like
-- SPDRN's lobby deck box (BalatroMultiplayerSpeed/ui/lobby/controls.lua) so it lines up
-- with the rest of the bar.
local function deck_panel()
	local lobby = PVP.lobby.ref
	local meta = (lobby and lobby:get_metadata()) or {}
	local rows = {}
	for _, line in ipairs({ "Deck", meta.deck or "Red Deck" }) do
		rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm", minw = 2.65, maxw = 2.45 }, nodes = {
			{ n = G.UIT.T, config = { text = line, scale = 0.4, colour = G.C.UI.TEXT_LIGHT } },
		} }
	end
	return { n = G.UIT.C, config = { align = "cm", padding = 0.05 }, nodes = {
		{ n = G.UIT.C, config = { align = "cm" }, nodes = {
			{ n = G.UIT.C, config = { align = "cm", r = 0.1, colour = G.C.PURPLE, minh = 1.35, shadow = true }, nodes = rows },
		} },
	} }
end

local function build_private_controls()
	local b = PVP.lobby.buttons
	local lobby = PVP.lobby.ref
	local row_nodes = {}
	if lobby and lobby.is_host then
		row_nodes[#row_nodes + 1] = b.start_game.node
		row_nodes[#row_nodes + 1] = b.lobby_options.node
	else
		row_nodes[#row_nodes + 1] = b.ready.node
		-- Manhunt's role and Teams' team are each player's own pick (the options
		-- screen keeps the ruleset and Hunter Lives rows host-only); without this
		-- a guest could never open the picker and always got the host's default.
		if PVP.LOBBY.config.manhunt or PVP.LOBBY.config.team_based then
			row_nodes[#row_nodes + 1] = b.lobby_options.node
		end
	end
	row_nodes[#row_nodes + 1] = deck_panel()
	row_nodes[#row_nodes + 1] = code_panel()
	row_nodes[#row_nodes + 1] = b.leave.node

	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.1, r = 0.1, emboss = 0.1, colour = G.C.L_BLACK, mid = true },
		nodes = { { n = G.UIT.R, config = { align = "cm", padding = 0.1 }, nodes = row_nodes } },
	}
end

local function waiting_for_host_panel()
	return { n = G.UIT.C, config = { align = "cm", padding = 0.1, minw = 3.65, minh = 1.55 }, nodes = {
		{ n = G.UIT.T, config = { text = localize("k_pvp_waiting_for_host"), scale = 0.4, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
	} }
end

-- A Party lobby (pvp_api/party_lobby.lua) has no lobby options and no deck: the host
-- has Find Game, every other player a Ready toggle. While the party queues, the
-- group panel (ui/lobby/group_panel.lua) says where it is.
local function build_party_controls()
	local b = PVP.lobby.buttons
	local lobby = PVP.lobby.ref
	local row_nodes = {}
	if lobby.is_host then
		row_nodes[#row_nodes + 1] = b.party_find_game.node
	else
		row_nodes[#row_nodes + 1] = b.ready.node
		row_nodes[#row_nodes + 1] = waiting_for_host_panel()
	end
	row_nodes[#row_nodes + 1] = code_panel()
	row_nodes[#row_nodes + 1] = b.leave.node

	local rows = { { n = G.UIT.R, config = { align = "cm", padding = 0.1 }, nodes = row_nodes } }
	local group_panel = PVP.lobby.build_group_panel(lobby)
	if group_panel then
		rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = { group_panel } }
	end
	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.1, r = 0.1, emboss = 0.1, colour = G.C.L_BLACK, mid = true },
		nodes = rows,
	}
end

-- Reactive status panel: a Setup vote or the deck Draft while one is active,
-- otherwise the waiting line. Held as one ui_element so it refreshes in place.
local _mm_status_el = nil
local function build_mm_status()
	if PVP.SETUP.is_voting() then
		return { nodes = PVP.SETUP.build_contents() }
	end
	if MPAPI.BanPick.is_active() then
		return { nodes = MPAPI.BanPick.build_contents() }
	end
	return { nodes = {
		{ n = G.UIT.R, config = { align = "cm", padding = 0.1 }, nodes = {
			{ n = G.UIT.T, config = { id = "mp_pvp_mm_status", text = localize("k_waiting_for_players"), scale = 0.5, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
		} },
	} }
end

local function build_matchmaking_controls()
	_mm_status_el = _mm_status_el or MPAPI.ui_element(build_mm_status)
	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.2, r = 0.1, emboss = 0.1, colour = G.C.L_BLACK, mid = true },
		nodes = { _mm_status_el.node },
	}
end

function PVP.lobby.refresh_mm_status()
	if _mm_status_el then
		_mm_status_el:update()
	end
end

-- A joiner before the host's metadata arrives: only what every lobby kind has.
local function build_pending_controls()
	local b = PVP.lobby.buttons
	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.1, r = 0.1, emboss = 0.1, colour = G.C.L_BLACK, mid = true },
		nodes = { { n = G.UIT.R, config = { align = "cm", padding = 0.1 }, nodes = {
			waiting_for_host_panel(),
			code_panel(),
			b.leave.node,
		} } },
	}
end

function PVP.lobby.build_controls()
	if PVP.is_matchmaking() then
		return build_matchmaking_controls()
	end
	local lobby = PVP.lobby.ref
	if not PVP.lobby_kind_known(lobby) then
		return build_pending_controls()
	end
	if PVP.is_party_lobby(lobby) then
		return build_party_controls()
	end
	return build_private_controls()
end
