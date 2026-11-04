-- Shared building blocks for the tournament screens (PVP.TUI): text, rows,
-- buttons, the OFFICIAL badge, display names, and what a tournament means for
-- the player right now (status_for). Used by ui/main_menu/tournaments.lua and
-- the files in ui/tournament/.

PVP.TUI = PVP.TUI or {}
local TUI = PVP.TUI

TUI.TEXT = 0.32
TUI.SMALL = 0.28
TUI.WIDTH = 13.6

function TUI.text(str, scale, colour)
	return { n = G.UIT.T, config = { text = tostring(str), scale = scale or TUI.TEXT, colour = colour or G.C.UI.TEXT_LIGHT, shadow = true } }
end

function TUI.line(nodes, align)
	return { n = G.UIT.R, config = { align = align or "cl", padding = 0.02 }, nodes = nodes }
end

function TUI.spacer(w, h)
	return { n = G.UIT.C, config = { minw = w or 0.1, minh = h or 0.1 }, nodes = {} }
end

function TUI.button(label, button, ref, colour, minw, scale)
	return UIBox_button({
		button = button,
		ref_table = ref,
		label = { label },
		colour = colour or G.C.BLUE,
		minw = minw or 1.6,
		minh = 0.45,
		scale = scale or 0.32,
	})
end

-- A row of side-by-side nodes, each in its own column.
function TUI.hbox(nodes, align, padding)
	local cols = {}
	for _, node in ipairs(nodes) do
		cols[#cols + 1] = { n = G.UIT.C, config = { align = "cm", padding = padding or 0.04 }, nodes = { node } }
	end
	return { n = G.UIT.R, config = { align = align or "cm" }, nodes = cols }
end

function TUI.title(str, colour, scale)
	return { n = G.UIT.R, config = { align = "cm", padding = 0.06 }, nodes = { TUI.text(str, scale or 0.45, colour or G.C.UI.TEXT_LIGHT) } }
end

function TUI.message(str, colour)
	return { n = G.UIT.R, config = { align = "cm", padding = 0.12 }, nodes = { TUI.text(str, TUI.TEXT, colour or G.C.UI.TEXT_INACTIVE) } }
end

-- The gold OFFICIAL badge next to a tournament's name.
function TUI.official_badge()
	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.05, r = 0.08, colour = G.C.GOLD },
		nodes = { TUI.text("OFFICIAL", 0.26, G.C.BLACK) },
	}
end

-- The name line: name, plus the OFFICIAL badge.
function TUI.name_line(summary, scale)
	local nodes = { { n = G.UIT.C, config = { align = "cl" }, nodes = { TUI.text(summary.name, scale or 0.38) } } }
	if summary.official then
		nodes[#nodes + 1] = TUI.spacer(0.12)
		nodes[#nodes + 1] = TUI.official_badge()
	end
	return { n = G.UIT.R, config = { align = "cl", padding = 0.02 }, nodes = nodes }
end

-- A panel background (the dark rounded box).
function TUI.panel(nodes, config)
	config = config or {}
	return {
		n = G.UIT.C,
		config = { align = config.align or "tm", padding = config.padding or 0.12, r = 0.15, colour = G.C.L_BLACK, emboss = 0.05, minw = config.minw, minh = config.minh },
		nodes = nodes,
	}
end

-- One list row: text on the left, buttons on the right. Official
-- tournaments get a gold edge.
function TUI.row(left_nodes, buttons, width, official)
	local right = {}
	for _, b in ipairs(buttons or {}) do
		right[#right + 1] = { n = G.UIT.C, config = { align = "cm", padding = 0.03 }, nodes = { b } }
	end
	return {
		n = G.UIT.R,
		config = {
			align = "cm",
			padding = 0.07,
			r = 0.1,
			minw = width,
			colour = mix_colours(G.C.BLACK, G.C.L_BLACK, 0.5),
			emboss = 0.04,
			outline = official and 1.2 or nil,
			outline_colour = official and G.C.GOLD or nil,
		},
		nodes = {
			{ n = G.UIT.C, config = { align = "cl", minw = width - 3.9 }, nodes = left_nodes },
			{ n = G.UIT.C, config = { align = "cr", minw = 3.6 }, nodes = { { n = G.UIT.R, config = { align = "cr" }, nodes = right } } },
		},
	}
end

function TUI.format_name(format)
	return PVP.Tournaments.FORMAT_NAMES[format] or tostring(format)
end

function TUI.game_type(key)
	local def = PVP.PVP_GAMEMODES and PVP.PVP_GAMEMODES[key]
	return def and def.display or tostring(key)
end

function TUI.ruleset_name(key)
	local ok, name = pcall(PVP.ruleset_display_name, key)
	if ok and type(name) == "string" and name ~= "ERROR" and name ~= "" then
		return name
	end
	return (tostring(key):gsub("^ruleset_mp_", ""):gsub("^%l", string.upper))
end

-- "Swiss  -  12/64  -  Nemesis"
function TUI.meta_line(summary)
	return string.format(
		"%s  -  %d/%d  -  %s",
		TUI.format_name(summary.format),
		summary.players or 0,
		summary.maxPlayers or 0,
		TUI.game_type(summary.gameMode)
	)
end

local function opponent_of(match)
	local TN = PVP.Tournaments
	local side = TN.my_side(match)
	if not side then
		return nil
	end
	local other = match.players[side == 1 and 2 or 1]
	return type(other) == "table" and other.name or nil
end
TUI.opponent_of = opponent_of

-- What a tournament means for the player now. Returns a table:
--   kind     what to show: "registered", "waitlist", "check_in", "checked_in",
--            "ready_up", "readied", "in_game", "waiting", "eliminated",
--            "paused", "unplayed", "finished", "cancelled", "running"
--   text     a one-line status
--   colour
--   until_ms the moment the countdown counts to (or nil)
--   action   { label, button, colour } for the list row (or nil)
--   match    the player's current match view (or nil)
function TUI.status_for(summary, view)
	local TN = PVP.Tournaments
	local TT = PVP.TournamentTime
	local id = summary.id
	local s = { colour = G.C.UI.TEXT_LIGHT }
	local busy = TN.state.busy[id]
	if summary.status == "registration" then
		s.kind = summary.role == "waitlist" and "waitlist" or "registered"
		s.until_ms = summary.startsAt
		s.text = (summary.role == "waitlist" and "On the waitlist  -  starts " or "Starts ") .. TT.describe(summary.startsAt)
	elseif summary.status == "check_in" then
		local me = view and TN.me_in(view)
		s.until_ms = summary.startsAt
		if me and me.checkedIn then
			s.kind, s.colour = "checked_in", G.C.GREEN
			s.text = "Checked in  -  starts " .. TT.describe(summary.startsAt)
		else
			s.kind, s.colour = "check_in", G.C.GOLD
			s.text = "Check in now  -  closes " .. TT.describe(summary.startsAt)
			s.action = { label = "CHECK IN", button = "mp_pvp_tournament_check_in", colour = G.C.GREEN }
		end
	elseif summary.status == "running" then
		if not view then
			s.kind, s.text = "running", "Running"
		elseif view.you and view.you.eliminated then
			s.kind, s.text, s.colour = "eliminated", "Knocked out", G.C.UI.TEXT_INACTIVE
		elseif view.paused then
			s.kind, s.text, s.colour = "paused", "Paused by the organiser", G.C.UI.TEXT_INACTIVE
		else
			local match = TN.my_match(view)
			s.match = match
			local vs = match and opponent_of(match)
			local clock = match and match.clock
			local score = match and (match.bestOf or 1) > 1 and string.format("  (%d-%d)", match.wins[1] or 0, match.wins[2] or 0) or ""
			if not match then
				s.kind, s.text = "waiting", "Waiting for your next match"
			elseif match.status == "waiting" or not clock then
				s.kind, s.text = "waiting", vs and ("Next: vs " .. vs) or "Waiting for your opponent"
			elseif clock.phase == "ready_up" then
				s.until_ms = clock.deadline
				local side = TN.my_side(match)
				local left = clock.deadline and TT.countdown(clock.deadline) or nil
				local due = left and ("  -  " .. left .. " left") or ""
				if side and clock.ready and clock.ready[side] then
					s.kind, s.colour = "readied", G.C.GREEN
					s.text = "Ready  -  waiting for " .. tostring(vs) .. score .. due
					s.action = { label = "UNREADY", button = "mp_pvp_tournament_unready", colour = G.C.ORANGE }
				else
					s.kind, s.colour = "ready_up", G.C.GOLD
					s.text = "Ready up vs " .. tostring(vs) .. score .. due
					s.action = { label = "READY", button = "mp_pvp_tournament_ready", colour = G.C.GREEN }
				end
			elseif clock.phase == "in_game" then
				s.kind, s.colour = "in_game", G.C.GREEN
				s.text = "Playing vs " .. tostring(vs) .. score
			elseif clock.phase == "unplayed" then
				s.kind, s.colour = "unplayed", G.C.RED
				s.text = "Not played in time  -  the organiser decides"
			else
				s.kind, s.text = "waiting", "vs " .. tostring(vs)
			end
		end
	elseif summary.status == "finished" then
		s.kind, s.colour = "finished", G.C.UI.TEXT_INACTIVE
		s.text = "Finished"
	else
		s.kind, s.colour = "cancelled", G.C.UI.TEXT_INACTIVE
		s.text = "Cancelled"
	end
	if busy then
		s.text, s.colour, s.action = busy .. "...", G.C.UI.TEXT_INACTIVE, nil
	end
	return s
end

-- Where the tournament pages sit. The page box is anchored to the bottom of
-- the screen (MPAPI api/page/manager.lua, align "bmi"); the Find Game pillars
-- push it 1.5 below the edge, which is fine for their short cards but cut
-- these taller panels off. Lift it just above the edge instead, and move the
-- title logo up so the panels don't run into it.
TUI.PAGE_LIFT = -0.25
TUI.LOGO_OFFSET = -3.4

function TUI.page_enter()
	if G.MAIN_MENU_UI then
		G.MAIN_MENU_UI.alignment.offset.y = TUI.PAGE_LIFT
		G.MAIN_MENU_UI:align_to_major()
	end
	MPAPI.set_logo_offset(TUI.LOGO_OFFSET, true)
	-- A taller page (or a shorter window) would still reach the logo: move the
	-- logo up by however much it overlaps the top of the page.
	local box, logo = G.MAIN_MENU_UI, G.title_top
	if box and box.T and logo and logo.T and logo._mpapi_base_y then
		local logo_bottom = logo._mpapi_base_y + TUI.LOGO_OFFSET + logo.T.h
		local overlap = logo_bottom - box.T.y + 0.15
		if overlap > 0 then
			MPAPI.set_logo_offset(TUI.LOGO_OFFSET - overlap, true)
		end
	end
end

-- Live text: a text node that follows live.text and live.colour every frame
-- without rebuilding its UI (Balatro text nodes read ref_table[ref_value] as
-- they draw). Countdowns use it, so the rows and buttons around them are only
-- rebuilt when something real changes -- rebuilding every second made the
-- buttons flicker.
function TUI.live(store, key)
	store[key] = store[key] or { text = "", colour = { 1, 1, 1, 1 } }
	return store[key]
end

function TUI.set_live(live, text, colour)
	live.text = tostring(text or "")
	colour = colour or G.C.UI.TEXT_LIGHT
	for i = 1, 4 do
		live.colour[i] = colour[i] or 1
	end
end

function TUI.live_text(live, scale)
	return { n = G.UIT.T, config = { ref_table = live, ref_value = "text", scale = scale or TUI.TEXT, colour = live.colour, shadow = true } }
end
