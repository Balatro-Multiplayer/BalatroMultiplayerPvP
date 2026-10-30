-- The Party lobby's queue panel (pvp_api/group_queue.lua): while the party
-- queues, every player sees where it is and may cancel. Nothing shows while
-- it does not queue; the host's Find Game (ui/lobby/controls.lua) starts it.

local function text_row(text, scale, colour)
	return { n = G.UIT.R, config = { align = "cm", padding = 0.03 }, nodes = {
		{ n = G.UIT.T, config = { text = text, scale = scale or 0.32, colour = colour or G.C.UI.TEXT_LIGHT, shadow = true } },
	} }
end

local function mode_display(key)
	local def = PVP.PVP_GAMEMODES[key]
	return def and def.display or tostring(key)
end

-- The panel's rows, or nil while the party does not queue. Reads only.
function PVP.lobby.group_panel_rows(lobby)
	local Group = MPAPI.matchmaking.group
	local view = lobby.group_queue
	if not view then
		return nil
	end
	local rows = { text_row(localize("k_party_lobby"), 0.36, G.C.UI.TEXT_INACTIVE) }
	local line = Group.status_line(lobby)
	rows[#rows + 1] = text_row((line and line.text or "") .. " " .. mode_display(view.mode), 0.36, G.C.GOLD)
	if not lobby.is_host then
		rows[#rows + 1] = text_row(localize("k_group_member_queued_by_host") .. " " .. mode_display(view.mode), 0.28)
	end
	if view.phase ~= Group.Phase.AWAY then
		rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = {
			UIBox_button({ id = "mp_pvp_group_cancel", button = "mp_pvp_group_cancel", label = { localize("b_group_cancel") }, colour = G.C.RED, minw = 2.6, minh = 0.6, scale = 0.4 }),
		} }
	end
	return rows
end

function PVP.lobby.build_group_panel(lobby)
	local rows = PVP.lobby.group_panel_rows(lobby)
	if not rows then
		return nil
	end
	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.08, r = 0.1, colour = G.C.BLACK, minw = 6 },
		nodes = rows,
	}
end
