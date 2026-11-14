-- Shared building blocks for the tournament UI (PVP.TUI): text, buttons,
-- panels, the OFFICIAL badge, display names, live (in-place) text, and what a
-- tournament means for the player right now (status_for). Used by the files
-- in ui/tournament/ and the lobby's series panel (pvp_api/tournament/play.lua).

PVP.TUI = PVP.TUI or {}
local TUI = PVP.TUI

TUI.TEXT = 0.32
TUI.SMALL = 0.28
TUI.WIDTH = 13.6

-- Text without the drop shadow, for sentences (easier to read).
function TUI.plain(str, scale, colour)
	return { n = G.UIT.T, config = { text = tostring(str), scale = scale or TUI.TEXT, colour = colour or G.C.UI.TEXT_LIGHT } }
end

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
		nodes = { TUI.text(PVP.T("k_tn_official_badge"), 0.26, G.C.BLACK) },
	}
end

-- The RANKED PROFILE badge: players need their ranked profile.
function TUI.ranked_badge()
	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.05, r = 0.08, colour = G.C.BLUE },
		nodes = { TUI.text(PVP.T("k_tn_ranked_badge"), 0.26, G.C.UI.TEXT_LIGHT) },
	}
end


-- What a ranked-profile tournament means for this player, as a line (nil
-- for other tournaments): green when they're on their ranked profile, red
-- with what to do when not, gold when the server didn't say. profile: the
-- view's rankedProfile ({ ok, message }).
function TUI.ranked_lines(summary, profile, align)
	if not summary or not summary.requireRanked then
		return nil
	end
	local text, colour = PVP.T("k_tn_ranked_howto"), G.C.GOLD
	if profile and profile.ok then
		text, colour = PVP.T("k_tn_ranked_ok"), G.C.GREEN
	elseif profile then
		colour = G.C.RED
	end
	return { n = G.UIT.R, config = { align = align or "cm", padding = 0.04 }, nodes = { TUI.plain(text, TUI.SMALL, colour) } }
end

-- The name line: name, plus the OFFICIAL badge (and RANKED PROFILE with
-- with_ranked: DETAILS only).
function TUI.name_line(summary, scale, with_ranked)
	local nodes = { { n = G.UIT.C, config = { align = "cl" }, nodes = { TUI.text(summary.name, scale or 0.38) } } }
	if summary.official then
		nodes[#nodes + 1] = TUI.spacer(0.12)
		nodes[#nodes + 1] = TUI.official_badge()
	end
	if with_ranked and summary.requireRanked then
		nodes[#nodes + 1] = TUI.spacer(0.12)
		nodes[#nodes + 1] = TUI.ranked_badge()
	end
	return { n = G.UIT.R, config = { align = "cl", padding = 0.02 }, nodes = nodes }
end

-- Words over lines of about `width` characters; the organiser's own line
-- breaks are kept.
function TUI.wrap(text, width)
	local lines = {}
	for part in (tostring(text) .. "\n"):gmatch("([^\n]*)\n") do
		local line = ""
		for word in part:gmatch("%S+") do
			if #line > 0 and #line + 1 + #word > width then
				lines[#lines + 1] = line
				line = word
			else
				line = #line > 0 and (line .. " " .. word) or word
			end
		end
		if #line > 0 then
			lines[#lines + 1] = line
		end
	end
	return lines
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

-- "Double Elim": k_tn_format_<format>, else the format as stored.
function TUI.format_name(format)
	local key = "k_tn_format_" .. tostring(format)
	local text = PVP.T(key)
	return text ~= key and text or tostring(format)
end

-- "1 deck" / "3 decks": key .. "_1" for one, key .. "_n" for any other count.
function TUI.count(n, key)
	return PVP.T(key .. (n == 1 and "_1" or "_n"), n)
end

function TUI.ruleset_name(key)
	local ok, name = pcall(PVP.ruleset_display_name, key)
	if ok and type(name) == "string" and name ~= "ERROR" and name ~= "" then
		return name
	end
	return (tostring(key):gsub("^ruleset_mp_", ""):gsub("^%l", string.upper))
end

-- "Swiss  -  12/64  -  Balanced"
function TUI.meta_line(summary)
	return string.format(
		"%s  -  %d/%d  -  %s",
		TUI.format_name(summary.format),
		summary.players or 0,
		summary.maxPlayers or 0,
		TUI.ruleset_name(summary.ruleset)
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
--            "ready_up", "readied", "in_game", "waiting", "eliminated", "dropped",
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
		s.text = PVP.T(summary.role == "waitlist" and "k_tn_status_waitlist" or "k_tn_status_starts", TT.describe(summary.startsAt))
	elseif summary.status == "check_in" then
		local me = view and TN.me_in(view)
		s.until_ms = summary.startsAt
		if me and me.checkedIn then
			s.kind, s.colour = "checked_in", G.C.GREEN
			s.text = PVP.T("k_tn_status_checked_in", TT.describe(summary.startsAt))
		else
			s.kind, s.colour = "check_in", G.C.GOLD
			s.text = PVP.T("k_tn_status_check_in", TT.describe(summary.startsAt))
			s.action = { label = PVP.T("k_tn_b_check_in"), button = "mp_pvp_tournament_check_in", colour = G.C.GREEN }
		end
	elseif summary.status == "running" then
		if not view then
			s.kind, s.text = "running", PVP.T("k_tn_status_running")
		elseif view.you and view.you.dropped then
			s.kind, s.text, s.colour = "dropped", PVP.T("k_tn_status_dropped"), G.C.UI.TEXT_INACTIVE
		elseif view.you and view.you.eliminated then
			s.kind, s.text, s.colour = "eliminated", PVP.T("k_tn_status_knocked_out"), G.C.UI.TEXT_INACTIVE
		elseif view.paused then
			s.kind, s.text, s.colour = "paused", PVP.T("k_tn_status_paused"), G.C.UI.TEXT_INACTIVE
		elseif TUI.round_check_in(view) then
			-- A round at a set time with its own check-in comes next.
			local rc = TUI.round_check_in(view)
			s.round_check_in = rc
			if rc.open and not rc.checkedIn then
				s.kind, s.colour, s.until_ms = "round_check_in", G.C.GOLD, rc.startsAt
				s.text = PVP.T("k_tn_status_round_check_in", rc.name)
				s.action = { label = PVP.T("k_tn_b_check_in"), button = "mp_pvp_tournament_check_in", colour = G.C.GREEN }
			elseif rc.open then
				s.kind, s.colour, s.until_ms = "round_checked_in", G.C.GREEN, rc.startsAt
				s.text = PVP.T("k_tn_status_round_checked_in", rc.name, PVP.TournamentTime.describe(rc.startsAt))
			else
				s.kind, s.until_ms = "round_later", rc.startsAt
				s.text = PVP.T("k_tn_status_round_later", rc.name, PVP.TournamentTime.describe(rc.startsAt))
			end
		else
			local match = TN.my_match(view)
			s.match = match
			local vs = match and opponent_of(match)
			local clock = match and match.clock
			local score = match and (match.bestOf or 1) > 1 and PVP.T("k_tn_status_score", match.wins[TN.my_side(match) or 1] or 0, match.wins[3 - (TN.my_side(match) or 1)] or 0) or ""
			if not match then
				s.kind, s.text = "waiting", PVP.T("k_tn_status_wait_next")
			elseif match.status == "waiting" or not clock then
				s.kind, s.text = "waiting", vs and PVP.T("k_tn_status_next_vs", vs) or PVP.T("k_tn_status_wait_opponent")
			elseif clock.phase == "ready_up" then
				s.until_ms = clock.deadline
				local side = TN.my_side(match)
				local left = clock.deadline and TT.countdown(clock.deadline) or nil
				local due = left and PVP.T("k_tn_status_left", left) or ""
				if side and clock.ready and clock.ready[side] then
					s.kind, s.colour = "readied", G.C.GREEN
					s.text = PVP.T("k_tn_status_readied", tostring(vs)) .. score .. due
					s.action = { label = PVP.T("k_tn_b_unready"), button = "mp_pvp_tournament_unready", colour = G.C.ORANGE }
				else
					s.kind, s.colour = "ready_up", G.C.GOLD
					s.text = PVP.T("k_tn_status_ready_up", tostring(vs)) .. score .. due
					s.action = { label = PVP.T("k_tn_b_ready"), button = "mp_pvp_tournament_ready", colour = G.C.GREEN }
				end
			elseif clock.phase == "in_game" then
				s.kind, s.colour = "in_game", G.C.GREEN
				s.text = PVP.T("k_tn_status_playing", tostring(vs)) .. score
			elseif clock.phase == "unplayed" then
				s.kind, s.colour = "unplayed", G.C.RED
				s.text = PVP.T("k_tn_status_unplayed")
			else
				s.kind, s.text = "waiting", PVP.T("k_tn_vs", tostring(vs))
			end
		end
	elseif summary.status == "finished" then
		s.kind, s.colour = "finished", G.C.UI.TEXT_INACTIVE
		s.text = PVP.T("k_tn_status_finished")
	else
		s.kind, s.colour = "cancelled", G.C.UI.TEXT_INACTIVE
		s.text = PVP.T("k_tn_status_cancelled")
	end
	if busy then
		s.text, s.colour, s.action = busy .. "...", G.C.UI.TEXT_INACTIVE, nil
	end
	return s
end

-- Why a cancelled tournament ended, from its event log: { who, line }.
-- who is a short phrase for a small card ("By a moderator"); line is the
-- full sentence for the tournament screen, with the moderator's reason.
-- nil when it isn't cancelled or the event has scrolled out of the log.
local CANCEL_WHO = {
	moderator = "k_tn_cancelled_by_moderator",
	organiser = "k_tn_cancelled_by_organiser",
	not_enough_players = "k_tn_cancelled_not_enough",
	start_failed = "k_tn_cancelled_start_failed",
}

function TUI.cancel_reason(view)
	if not (view and view.summary and view.summary.status == "cancelled") then
		return nil
	end
	local events = view.events or {}
	for i = #events, 1, -1 do
		local e = events[i]
		if type(e) == "table" and e.kind == "cancelled" then
			local key = CANCEL_WHO[e.reason]
			if not key then
				return nil
			end
			local who = PVP.T(key)
			local message = e.reason == "moderator" and type(e.message) == "string" and e.message ~= "" and e.message or nil
			return { who = who, line = message and PVP.T("k_tn_cancelled_reason", who, message) or (who .. ".") }
		end
	end
	return nil
end

-- The next round with its own check-in (view.you.roundCheckIn, from the
-- server), when it is what the player should look at: not while they have a
-- match to ready up for or play, and before its check-in opens only if their
-- next match is in it (or they have none yet). Adds .name ("the final").
function TUI.round_check_in(view)
	local rc = view and view.you and view.you.roundCheckIn
	if type(rc) ~= "table" or not rc.startsAt then
		return nil
	end
	local TN = PVP.Tournaments
	local match = TN.my_match(view)
	local phase = match and match.clock and match.clock.phase
	if phase == "ready_up" or phase == "in_game" or phase == "unplayed" then
		return nil
	end
	local layout = PVP.BracketLayout
	if not rc.open and match and layout and layout.step_of(view, match.stage, match.round) < (rc.firstRound or 0) then
		return nil
	end
	local out = {}
	for k, v in pairs(rc) do
		out[k] = v
	end
	out.name = layout and layout.step_name(view, rc.firstRound or 1) or PVP.T("k_tn_round", rc.firstRound or 1)
	return out
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

-- Names for what the server stores -------------------------------------------

-- "45 min", "2 hours", "3 days"
function TUI.duration(minutes)
	minutes = tonumber(minutes) or 0
	if minutes >= 24 * 60 and minutes % (24 * 60) == 0 then
		return TUI.count(math.floor(minutes / (24 * 60)), "k_tn_n_days")
	elseif minutes >= 60 and minutes % 60 == 0 then
		return TUI.count(math.floor(minutes / 60), "k_tn_n_hours")
	end
	return PVP.T("k_tn_n_min", minutes)
end
