-- The "your match is open" banner. When a tournament match opens (or a
-- ready-up deadline is close) and the player isn't on that tournament's
-- screen, a banner slides in at the top with a sound. It never takes the
-- player anywhere by itself: READY readies up for the match, and GO opens
-- the tournament screen (when PvP has it); both only in the menus, so a
-- running game is never interrupted. It goes away on its own after
-- SHOW_SECONDS.

PVP.TUI = PVP.TUI or {}
local TUI = PVP.TUI

local SHOW_SECONDS = 15
local banner = { box = nil, id = nil, serial = 0 }

local function remove()
	if banner.box then
		banner.box:remove()
		banner.box = nil
	end
	banner.id = nil
end

local function in_menus()
	return G.STAGE == G.STAGES.MAIN_MENU
end

-- content: the TOURNAMENT_MATCH notification ({tournamentId, name, kind,
-- minutesLeft, opponent}).
function PVP.show_tournament_banner(content)
	if not content or not content.tournamentId then
		return
	end
	local ranked = content.kind == "ranked_profile_needed"
	local message = content.kind == "organiser_message"
	-- The ranked-profile reminder and organiser messages show on the
	-- tournament's own screen too.
	if not ranked and not message and PVP.tournament_screen_id and PVP.tournament_screen_id() == content.tournamentId then
		return
	end
	remove()
	banner.id = content.tournamentId
	banner.serial = banner.serial + 1
	local serial = banner.serial
	local vs = content.opponent and content.opponent.name or PVP.T("k_tn_your_opponent")
	local headline = PVP.T(content.kind == "reminder" and "k_tn_banner_closes_soon" or content.kind == "series" and "k_tn_banner_next_game" or "k_tn_banner_open")
	local detail = PVP.T("k_tn_status_ready_up", tostring(vs)) .. (content.minutesLeft and PVP.T("k_tn_banner_min_left", content.minutesLeft) or "")
	if ranked then
		headline = PVP.T("k_tn_banner_ranked")
		detail = PVP.T("k_tn_banner_ranked_detail")
	elseif content.kind == "round_check_in" then
		headline = PVP.T("k_tn_banner_round_check_in")
		detail = content.startsAt and PVP.T("k_tn_banner_round_check_in_detail", PVP.TournamentTime.describe(content.startsAt)) or ""
	end
	-- An organiser's message: their words, over as many lines as it takes.
	local detail_lines = { TUI.line({ TUI.text(detail, TUI.SMALL) }) }
	if message then
		headline = PVP.T("k_tn_banner_from_organiser", tostring(content.from or PVP.T("k_tn_the_organiser")))
		detail_lines = {}
		for _, line in ipairs(TUI.wrap(content.text or "", 60)) do
			detail_lines[#detail_lines + 1] = TUI.line({ TUI.text(line, 0.32, G.C.UI.TEXT_LIGHT) })
		end
	end
	local buttons = {}
	-- A match to ready up for (not a reminder of something else).
	local ready_up = not ranked and not message and content.kind ~= "round_check_in" and content.matchId ~= nil
	if in_menus() and ready_up then
		buttons[#buttons + 1] = TUI.button(PVP.T("k_tn_b_ready"), "mp_pvp_tournament_banner_ready", { id = content.tournamentId }, G.C.GREEN, 1.4)
	end
	if in_menus() and not message and PVP.open_tournament then
		buttons[#buttons + 1] = TUI.button(PVP.T("k_tn_b_go"), "mp_pvp_tournament_banner_go", { id = content.tournamentId }, ready_up and G.C.BLUE or G.C.GREEN, 1.2)
	end
	buttons[#buttons + 1] = TUI.button("X", "mp_pvp_tournament_banner_close", nil, G.C.UI.BACKGROUND_INACTIVE, 0.6)
	local body = TUI.panel({
		{
			n = G.UIT.R,
			config = { align = "cm" },
			nodes = {
				{
					n = G.UIT.C,
					config = { align = "cl", padding = 0.04 },
					nodes = {
						TUI.line({ TUI.text(tostring(content.name), 0.34, G.C.GOLD) }),
						TUI.line({ TUI.text(headline, 0.4, message and G.C.GOLD or nil) }),
						unpack(detail_lines),
					},
				},
				TUI.spacer(0.2),
				-- A column (not a row) beside the text column, so the buttons stay in the box.
				{ n = G.UIT.C, config = { align = "cm" }, nodes = { TUI.hbox(buttons, "cm", 0.04) } },
			},
		},
	}, { align = "cm", padding = 0.1 })
	banner.box = UIBox({
		definition = { n = G.UIT.ROOT, config = { align = "cm", colour = G.C.CLEAR }, nodes = { body } },
		-- "tmi": inside the top edge of the game area (plain "tm" sits above it, off
		-- screen), so it is visible at any window size.
		config = { align = "tmi", offset = { x = 0, y = 0.25 }, major = G.ROOM_ATTACH, bond = "Weak", instance_type = "POPUP" },
	})
	play_sound("highlight2", 1.1, 0.6)
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		-- A message stays long enough to read.
		delay = message and SHOW_SECONDS * 2 or SHOW_SECONDS,
		blockable = false,
		blocking = false,
		timer = "REAL",
		func = function()
			if banner.serial == serial then
				remove()
			end
			return true
		end,
	}))
end

-- Readies up for the match; the server then makes its lobby, which the
-- player joins by themselves (pvp_api/tournament/play.lua).
G.FUNCS.mp_pvp_tournament_banner_ready = function(e)
	local id = e.config.ref_table and e.config.ref_table.id
	remove()
	if id then
		PVP.Tournaments.ready(id, true, function(err)
			if err and PVP.UI and PVP.UI.UTILS and PVP.UI.UTILS.overlay_message then
				PVP.UI.UTILS.overlay_message(tostring(err))
			end
		end)
	end
end

G.FUNCS.mp_pvp_tournament_banner_go = function(e)
	local id = e.config.ref_table and e.config.ref_table.id
	remove()
	if id and in_menus() and PVP.open_tournament then
		PVP.open_tournament(id)
	end
end

G.FUNCS.mp_pvp_tournament_banner_close = function()
	remove()
end
