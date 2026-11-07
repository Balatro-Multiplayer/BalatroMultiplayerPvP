-- A tournament's own screen (page pvp_tournament, params {id}). The player
-- is brought here after checking in, and it is where they wait: before the
-- start a big countdown; when their match opens, a big READY / UNREADY with
-- the ready-up timer; between games and matches, what comes next. BRACKET,
-- DETAILS and LEAVE are always at hand. It refreshes every few seconds and on
-- every tournament notification.

PVP.TUI = PVP.TUI or {}
local TUI = PVP.TUI

local REFRESH_SECONDS = 5
local BIG = 1.5

local screen = { id = nil, view = nil, error = nil, el = nil, active = false, unlisten = nil, shape = nil, clock = { text = "", colour = { 1, 1, 1, 1 } } }

-- Defined further down; load() calls it.
local refresh

local function load()
	if not screen.id then
		return
	end
	PVP.Tournaments.get({ id = screen.id }, function(err, data)
		if not screen.active then
			return
		end
		if err then
			screen.error = err
		elseif data and data.tournament then
			screen.view = data.tournament
			screen.error = nil
			PVP.Tournaments.state.views[screen.id] = data.tournament
		end
		refresh()
	end)
end

-- The summary fields status_for reads, from a full view.
local function summary_of(view)
	local s = {}
	for k, v in pairs(view.summary or {}) do
		s[k] = v
	end
	s.role = view.role
	return s
end

local function big_clock(until_ms)
	local TT = PVP.TournamentTime
	if not until_ms then
		return nil, nil
	end
	local clock = TT.clock(until_ms)
	if clock then
		local left = until_ms - TT.now_ms()
		return clock, left < 60 * 1000 and G.C.RED or G.C.GOLD
	end
	return TT.format_local(until_ms), G.C.UI.TEXT_LIGHT
end

-- The middle of the screen: a heading, the big clock and one big button.
-- A big heading that pops in and floats: how the tournament ended for you.
local function big_heading(text, colour, scale)
	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.1 },
		nodes = {
			{
				n = G.UIT.O,
				config = {
					object = DynaText({
						string = { text },
						colours = { colour },
						scale = scale or 1.1,
						shadow = true,
						float = true,
						bump = true,
						pop_in = 0,
						pop_in_rate = 2,
						silent = true,
						maxw = TUI.WIDTH - 4,
					}),
				},
			},
		},
	}
end

local function centre(view)
	local s = TUI.status_for(summary_of(view), view)
	local heading, sub, button, button_label
	-- Set for an ending (knocked out, dropped out, finished): shown big.
	local big
	local until_ms = s.until_ms
	if s.kind == "registered" then
		heading, sub = PVP.T("k_tn_starts_in"), PVP.T("k_tn_sub_registered")
	elseif s.kind == "waitlist" then
		heading, sub = PVP.T("k_tn_starts_in"), PVP.T("k_tn_sub_waitlist")
	elseif s.kind == "check_in" then
		heading, sub = PVP.T("k_tn_check_in_closes_in"), PVP.T("k_tn_sub_check_in")
		button, button_label = TUI.button(PVP.T("k_tn_b_check_in"), "mp_pvp_tournament_check_in", { id = view.summary.id }, G.C.GREEN, 4, 0.6), "CHECK IN"
	elseif s.kind == "checked_in" then
		local total, ready = 0, 0
		for _, e in ipairs(view.entrants or {}) do
			total = total + 1
			if e.checkedIn then
				ready = ready + 1
			end
		end
		heading, sub = PVP.T("k_tn_starts_in"), PVP.T("k_tn_sub_checked_in", ready, total)
	elseif s.kind == "ready_up" or s.kind == "readied" then
		local m = s.match
		local game = m and ((m.wins[1] or 0) + (m.wins[2] or 0) + 1) or 1
		heading = (m and (m.bestOf or 1) > 1) and PVP.T("k_tn_game_ready_up", game) or PVP.T("k_tn_ready_up")
		sub = PVP.T("k_tn_vs", tostring(TUI.opponent_of(m)))
		if m and (m.bestOf or 1) > 1 then
			-- Your wins first: in bracket order the player in the second slot
			-- saw the score the wrong way round.
			local mine = PVP.Tournaments.my_side(m) or 1
			sub = sub .. PVP.T("k_tn_sub_series", m.bestOf, m.wins[mine] or 0, m.wins[3 - mine] or 0)
		end
		if s.kind == "readied" then
			sub = sub .. PVP.T("k_tn_sub_waiting_for_them")
			button, button_label = TUI.button(PVP.T("k_tn_b_unready"), "mp_pvp_tournament_unready", { id = view.summary.id }, G.C.ORANGE, 4, 0.6), "UNREADY"
		else
			button, button_label = TUI.button(PVP.T("k_tn_b_ready"), "mp_pvp_tournament_ready", { id = view.summary.id }, G.C.GREEN, 4, 0.6), "READY"
		end
	elseif s.kind == "in_game" then
		heading, sub, until_ms = PVP.T("k_tn_game_in_progress"), s.text, nil
		-- Not in the match's lobby (a missed notification): offer to join it.
		local m = s.match
		local current = MPAPI.get_current_lobby()
		if m and m.lobby and m.lobby.code and not (current and current.code == m.lobby.code) then
			button = TUI.button(PVP.T("k_tn_b_join_game"), "mp_pvp_tournament_join_game", { id = view.summary.id, match_id = m.id, code = m.lobby.code }, G.C.GREEN, 4, 0.6)
			button_label = "JOIN GAME"
		end
	elseif s.kind == "round_check_in" then
		local rc = s.round_check_in
		heading = PVP.T("k_tn_round_check_in_heading", rc.name):upper()
		sub = PVP.T("k_tn_sub_round_check_in")
		button, button_label = TUI.button(PVP.T("k_tn_b_check_in"), "mp_pvp_tournament_check_in", { id = view.summary.id }, G.C.GREEN, 4, 0.6), "CHECK IN"
	elseif s.kind == "round_checked_in" then
		heading, sub = PVP.T("k_tn_starts_in"), s.text
	elseif s.kind == "round_later" then
		local rc = s.round_check_in
		local minutes = math.floor((rc.startsAt - rc.opensAt) / 60000 + 0.5)
		heading = PVP.T("k_tn_round_starts_in", rc.name):upper()
		sub = PVP.T("k_tn_sub_round_later", TUI.duration(minutes))
	elseif s.kind == "waiting" then
		heading, sub, until_ms = PVP.T("k_tn_waiting"), s.text, nil
	elseif s.kind == "dropped" then
		heading, sub, until_ms = PVP.T("k_tn_dropped_out"), PVP.T("k_tn_sub_dropped_out"), nil
		big = { colour = G.C.RED }
	elseif s.kind == "eliminated" then
		heading, sub, until_ms = PVP.T("k_tn_knocked_out"), PVP.T("k_tn_sub_knocked_out"), nil
		big = { colour = G.C.RED }
	elseif s.kind == "paused" then
		heading, sub, until_ms = PVP.T("k_tn_paused"), PVP.T("k_tn_sub_paused"), nil
	elseif s.kind == "unplayed" then
		heading, sub, until_ms = PVP.T("k_tn_not_played"), PVP.T("k_tn_sub_not_played"), nil
	elseif s.kind == "finished" then
		local place
		local me = PVP.Tournaments.me_in(view)
		for _, p in ipairs(view.placements or {}) do
			if me and p.id == me.id then
				place = p.place
			end
		end
		heading, sub, until_ms = PVP.T("k_tn_finished"), place and PVP.T("k_tn_sub_placed", place) or PVP.T("k_tn_sub_over"), nil
		if place == 1 then
			heading, sub, big = PVP.T("k_tn_champion"), PVP.T("k_tn_sub_champion"), { colour = G.C.GOLD, scale = 1.4 }
		elseif place and place <= 3 then
			heading, sub, big = PVP.T("k_tn_place", place), PVP.T("k_tn_sub_well_played"), { colour = G.C.BLUE }
		elseif place then
			heading, big = PVP.T("k_tn_place", place), { colour = G.C.UI.TEXT_LIGHT, scale = 0.9 }
		end
	elseif s.kind == "cancelled" then
		-- Who cancelled it, with a moderator's reason in full.
		local why = TUI.cancel_reason(view)
		heading, sub, until_ms = s.text:upper(), why and why.line or "", nil
		if view.summary.status == "cancelled" then
			big = { colour = G.C.RED }
		end
	else
		heading, sub, until_ms = s.text:upper(), "", nil
	end
	local clock, colour = big_clock(until_ms)
	local rows = { big and big_heading(heading, big.colour, big.scale) or TUI.title(heading, G.C.UI.TEXT_LIGHT, 0.5) }
	if clock then
		-- Live text: the clock ticks without rebuilding the screen (and its buttons).
		TUI.set_live(screen.clock, clock, colour)
		rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = { TUI.live_text(screen.clock, BIG) } }
	end
	if sub and sub ~= "" then
		-- Wrapped: a moderator's reason can run to 200 characters.
		for _, line in ipairs(TUI.wrap(sub, 64)) do
			rows[#rows + 1] = TUI.message(line, G.C.UI.TEXT_LIGHT)
		end
	end
	if PVP.Tournaments.state.busy[view.summary.id] then
		rows[#rows + 1] = TUI.message(PVP.Tournaments.state.busy[view.summary.id] .. "...")
	elseif button then
		rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.1 }, nodes = { button } }
	end
	local busy = PVP.Tournaments.state.busy[view.summary.id]
	local shape = table.concat({ heading, sub or "", tostring(clock ~= nil), button and button_label or "", busy or "" }, "|")
	return rows, s, shape
end

-- Everything the screen shows apart from the ticking clock: when this
-- changes, the screen is rebuilt. (Computing it also moves the clock on.)
local function screen_shape()
	local view = screen.view
	if not view then
		return "none|" .. tostring(screen.error)
	end
	local _, _, shape = centre(view)
	local ranked = view.rankedProfile and tostring(view.rankedProfile.ok) or ""
	return table.concat({ shape, TUI.meta_line(view.summary), view.summary.name, view.role or "", view.summary.status, ranked, screen.error or "", tostring(screen.confirm_leave), view.notice or "" }, "|")
end

-- Rebuilds only when something besides the clock changed.
refresh = function()
	if screen.el and screen_shape() ~= screen.shape then
		screen.el:update()
	end
end

local function build()
	screen.shape = screen_shape()
	local view = screen.view
	local nodes = {}
	if not view then
		nodes[#nodes + 1] = TUI.message(screen.error or PVP.T("k_tn_loading"))
	else
		local summary = view.summary
		nodes[#nodes + 1] = { n = G.UIT.R, config = { align = "cm" }, nodes = { { n = G.UIT.C, config = { align = "cm" }, nodes = { TUI.name_line(summary, 0.55) } } } }
		nodes[#nodes + 1] = TUI.message(PVP.T("k_tn_meta_by", TUI.meta_line(summary), tostring(summary.organiserName)))
		-- Ranked profile required: say it while there is time to switch.
		nodes[#nodes + 1] = TUI.ranked_lines(summary, view.rankedProfile)
		local rows, s = centre(view)
		nodes[#nodes + 1] = { n = G.UIT.R, config = { align = "cm", minh = 2.6, padding = 0.05 }, nodes = { { n = G.UIT.C, config = { align = "cm" }, nodes = rows } } }
		local buttons = {
			TUI.button(PVP.T("k_tn_b_back"), "mp_pvp_tournaments_back", nil, G.C.ORANGE, 1.8),
			TUI.button(PVP.T("k_tn_b_bracket"), "mp_pvp_tournament_bracket", { id = summary.id }, G.C.BLUE, 1.8),
			TUI.button(PVP.T("k_tn_b_details"), "mp_pvp_tournament_details", { id = summary.id }, G.C.UI.BACKGROUND_INACTIVE, 1.8),
		}
		local can_leave = (view.role == "entrant" or view.role == "waitlist") and (summary.status == "registration" or summary.status == "check_in" or (summary.status == "running" and s.kind ~= "eliminated" and s.kind ~= "dropped"))
		local running = summary.status == "running"
		-- Leaving takes two presses: the first says what it does.
		local confirming = can_leave and screen.confirm_leave == summary.id
		if confirming then
			buttons = {
				TUI.button(PVP.T("k_tn_b_stay_in"), "mp_pvp_tournament_screen_stay", nil, G.C.GREEN, 2.2),
				TUI.button(PVP.T(running and "k_tn_b_yes_drop_out" or "k_tn_b_yes_leave"), "mp_pvp_tournament_screen_leave", { id = summary.id }, G.C.RED, 2.8),
			}
		elseif can_leave then
			buttons[#buttons + 1] = TUI.button(PVP.T(running and "k_tn_b_drop_out" or "k_tn_b_leave_tournament"), "mp_pvp_tournament_screen_leave", { id = summary.id }, G.C.RED, running and 1.8 or 3.2)
		end
		if confirming then
			local why = PVP.T(running and "k_tn_drop_out_warning" or "k_tn_leave_warning")
			-- Wrapped: one long line ran past the panel's edges.
			for _, line in ipairs(TUI.wrap(why, 64)) do
				nodes[#nodes + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.03 }, nodes = { TUI.text(line, TUI.TEXT, G.C.RED) } }
			end
		end
		nodes[#nodes + 1] = TUI.hbox(buttons, "cm", 0.06)
		if screen.error then
			nodes[#nodes + 1] = TUI.message(screen.error, G.C.RED)
		end
	end
	local panel = TUI.panel(nodes, { minw = TUI.WIDTH - 2, align = "cm" })
	local notice = view and type(view.notice) == "string" and view.notice ~= "" and view.notice or nil
	if not notice then
		return { nodes = { panel } }
	end
	-- The notice board: the organisers' text, above the screen (over the
	-- background), only while there is some.
	-- A thin gold frame round a black board nearly as wide, with room
	-- inside so the text never touches its edges.
	local width = TUI.WIDTH - 2
	local lines = { { n = G.UIT.R, config = { align = "cm", padding = 0.06 }, nodes = { TUI.text(PVP.T("k_tn_notice_heading"), TUI.SMALL, G.C.GOLD) } } }
	for _, line in ipairs(TUI.wrap(notice, 70)) do
		lines[#lines + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.025 }, nodes = { { n = G.UIT.T, config = { text = line, scale = 0.34, colour = G.C.UI.TEXT_LIGHT } } } }
	end
	local board = {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.07, r = 0.15, minw = width, colour = mix_colours(G.C.GOLD, G.C.BLACK, 0.25), emboss = 0.05 },
		nodes = { { n = G.UIT.C, config = { align = "cm", padding = 0.2, r = 0.1, minw = width - 0.14, colour = G.C.BLACK }, nodes = lines } },
	}
	return {
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cm" },
				nodes = {
					{ n = G.UIT.R, config = { align = "cm", padding = 0.1 }, nodes = { board } },
					{ n = G.UIT.R, config = { align = "cm" }, nodes = { panel } },
				},
			},
		},
	}
end

local function tick()
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = 1,
		blockable = false,
		blocking = false,
		timer = "REAL",
		func = function()
			if not screen.active then
				return true
			end
			screen.seconds = (screen.seconds or 0) + 1
			-- Already in this match's lobby (its game is on): that is where to be.
			local current = MPAPI.get_current_lobby()
			if current and PVP._tournament_lobby and current.code == PVP._tournament_lobby.code then
				PVP.show_tournament_lobby_page()
				return true
			end
			if screen.seconds % REFRESH_SECONDS == 0 then
				load()
			else
				refresh()
			end
			tick()
			return true
		end,
	}))
end

MPAPI.on_loaded(function()
	MPAPI.Page({
		key = "pvp_tournament",
		category = "game_select",
		build = function(self)
			if screen.id ~= (self.params and self.params.id) then
				screen.view = PVP.Tournaments.state.views[self.params and self.params.id]
				screen.error = nil
			end
			screen.id = self.params and self.params.id
			screen.confirm_leave = nil
			screen.el = MPAPI.ui_element(build)
			return { n = G.UIT.ROOT, config = { align = "tm", colour = G.C.CLEAR }, nodes = { { n = G.UIT.R, config = { align = "tm", padding = 0.1 }, nodes = { screen.el.node } } } }
		end,
		on_enter = function(self)
			TUI.page_enter()
			screen.active = true
			screen.seconds = 0
			-- Any tournament change (ready, results, notifications) reloads this one.
			screen.unlisten = PVP.Tournaments.on_change(function()
				local cached = PVP.Tournaments.state.views[screen.id]
				if cached then
					screen.view = cached
				end
				refresh()
			end)
			load()
			tick()
		end,
		dispose = function(self)
			screen.active = false
			if screen.unlisten then
				screen.unlisten()
				screen.unlisten = nil
			end
			screen.el = nil
		end,
	})
end)

-- The screen being shown, if it is this tournament's (the banner skips it).
function PVP.tournament_screen_id()
	if MPAPI.pages.current_key() == "pvp_tournament" and screen.active then
		return screen.id
	end
	return nil
end

G.FUNCS.mp_pvp_tournament_screen_leave = function(e)
	local id = e.config.ref_table and e.config.ref_table.id
	if not id then
		return
	end
	-- The first press asks (the screen says what leaving does).
	if screen.confirm_leave ~= id then
		screen.confirm_leave = id
		if screen.el then
			screen.el:update()
		end
		return
	end
	screen.confirm_leave = nil
	local running = screen.view and screen.view.summary and screen.view.summary.status == "running"
	PVP.Tournaments.leave(id, function(err)
		if not err and not running then
			MPAPI.pages.show("pvp_find_game", { category = "tournaments" })
			return
		end
		-- Dropped out mid-tournament: stay, and the screen says DROPPED OUT.
		if not err then
			PVP.Tournaments.refresh()
			load()
		end
		if screen.el then
			screen.el:update()
		end
	end)
end

G.FUNCS.mp_pvp_tournament_screen_stay = function()
	screen.confirm_leave = nil
	if screen.el then
		screen.el:update()
	end
end
