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

-- Deck + stake box, purple and button-sized so it lines up with the rest of the bar.
-- The host's opens the vanilla run setup screen (G.FUNCS.lobby_choose_deck, ui/lobby/code.lua);
-- a guest's is the same box, display-only, since every player plays the host's deck.
-- Rebuilt with the rest of the controls whenever the lobby metadata changes.
local function deck_button()
	local lobby = PVP.lobby.ref
	local deck_name = PVP.LOBBY.deck.back or "Red Deck"
	local deck_key = PVP.UTILS.get_deck_key_from_name(deck_name)
	local stake_key = SMODS.stake_from_index(tonumber(PVP.LOBBY.deck.stake) or 1)
	-- A name with no center (e.g. "Challenge Deck") is shown as is.
	local labels = {
		deck_key and localize({ type = "name_text", key = deck_key, set = "Back" }) or deck_name,
		stake_key and localize({ type = "name_text", key = stake_key, set = "Stake" }) or "",
	}
	return MPAPI.disableable_button({
		id = "mp_pvp_choose_deck",
		button = "lobby_choose_deck",
		colour = G.C.PURPLE,
		minw = 2.65,
		minh = 1.35,
		label = labels,
		scale = 0.5,
		col = true,
		enabled = function()
			return lobby and lobby.is_host and not lobby.group_queue
		end,
	}).node
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
	row_nodes[#row_nodes + 1] = deck_button()
	row_nodes[#row_nodes + 1] = code_panel()
	row_nodes[#row_nodes + 1] = b.leave.node

	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.1, r = 0.1, emboss = 0.1, colour = G.C.L_BLACK, mid = true },
		nodes = { { n = G.UIT.R, config = { align = "cm", padding = 0.1 }, nodes = row_nodes } },
	}
end

-- A Party lobby (MPAPI.Party) has no lobby options and no deck: the host
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
	if not MPAPI.Party.kind_known(lobby) then
		return build_pending_controls()
	end
	if MPAPI.Party.is_party_lobby(lobby) then
		return build_party_controls()
	end
	return build_private_controls()
end
