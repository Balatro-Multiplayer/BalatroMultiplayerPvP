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
local function centre(view)
	local s = TUI.status_for(summary_of(view), view)
	local heading, sub, button, button_label
	local until_ms = s.until_ms
	if s.kind == "registered" then
		heading, sub = "STARTS IN", "Check-in opens before the start."
	elseif s.kind == "waitlist" then
		heading, sub = "STARTS IN", "You're on the waitlist. The organiser can move you in."
	elseif s.kind == "check_in" then
		heading, sub = "CHECK-IN CLOSES IN", "Check in or you'll be removed when it starts."
		button, button_label = TUI.button("CHECK IN", "mp_pvp_tournament_check_in", { id = view.summary.id }, G.C.GREEN, 4, 0.6), "CHECK IN"
	elseif s.kind == "checked_in" then
		local total, ready = 0, 0
		for _, e in ipairs(view.entrants or {}) do
			total = total + 1
			if e.checkedIn then
				ready = ready + 1
			end
		end
		heading, sub = "STARTS IN", string.format("You're checked in. %d of %d players checked in.", ready, total)
	elseif s.kind == "ready_up" or s.kind == "readied" then
		local m = s.match
		local game = m and ((m.wins[1] or 0) + (m.wins[2] or 0) + 1) or 1
		heading = (m and (m.bestOf or 1) > 1) and string.format("GAME %d  -  READY UP", game) or "READY UP"
		sub = "vs " .. tostring(TUI.opponent_of(m))
		if m and (m.bestOf or 1) > 1 then
			sub = sub .. string.format("   (best of %d, %d-%d)", m.bestOf, m.wins[1] or 0, m.wins[2] or 0)
		end
		if s.kind == "readied" then
			sub = sub .. "   -   waiting for them"
			button, button_label = TUI.button("UNREADY", "mp_pvp_tournament_unready", { id = view.summary.id }, G.C.ORANGE, 4, 0.6), "UNREADY"
		else
			button, button_label = TUI.button("READY", "mp_pvp_tournament_ready", { id = view.summary.id }, G.C.GREEN, 4, 0.6), "READY"
		end
	elseif s.kind == "in_game" then
		heading, sub, until_ms = "GAME IN PROGRESS", s.text, nil
		-- Not in the match's lobby (a missed notification): offer to join it.
		local m = s.match
		local current = MPAPI.get_current_lobby()
		if m and m.lobby and m.lobby.code and not (current and current.code == m.lobby.code) then
			button = TUI.button("JOIN GAME", "mp_pvp_tournament_join_game", { id = view.summary.id, match_id = m.id, code = m.lobby.code }, G.C.GREEN, 4, 0.6)
			button_label = "JOIN GAME"
		end
	elseif s.kind == "waiting" then
		heading, sub, until_ms = "WAITING", s.text, nil
	elseif s.kind == "eliminated" then
		heading, sub, until_ms = "KNOCKED OUT", "Thanks for playing. Follow the rest in the bracket.", nil
	elseif s.kind == "paused" then
		heading, sub, until_ms = "PAUSED", "The organiser paused the tournament. Deadlines are on hold.", nil
	elseif s.kind == "unplayed" then
		heading, sub, until_ms = "NOT PLAYED IN TIME", "The organiser decides this match.", nil
	elseif s.kind == "finished" then
		local place
		local me = PVP.Tournaments.me_in(view)
		for _, p in ipairs(view.placements or {}) do
			if me and p.id == me.id then
				place = p.place
			end
		end
		heading, sub, until_ms = "FINISHED", place and ("You placed #" .. place) or "The tournament is over.", nil
	else
		heading, sub, until_ms = s.text:upper(), "", nil
	end
	local clock, colour = big_clock(until_ms)
	local rows = { TUI.title(heading, G.C.UI.TEXT_LIGHT, 0.5) }
	if clock then
		-- Live text: the clock ticks without rebuilding the screen (and its buttons).
		TUI.set_live(screen.clock, clock, colour)
		rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = { TUI.live_text(screen.clock, BIG) } }
	end
	if sub and sub ~= "" then
		rows[#rows + 1] = TUI.message(sub, G.C.UI.TEXT_LIGHT)
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
	return table.concat({ shape, TUI.meta_line(view.summary), view.summary.name, view.role or "", view.summary.status, screen.error or "" }, "|")
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
		nodes[#nodes + 1] = TUI.message(screen.error or "Loading...")
	else
		local summary = view.summary
		nodes[#nodes + 1] = { n = G.UIT.R, config = { align = "cm" }, nodes = { { n = G.UIT.C, config = { align = "cm" }, nodes = { TUI.name_line(summary, 0.55) } } } }
		nodes[#nodes + 1] = TUI.message(TUI.meta_line(summary) .. "  -  by " .. tostring(summary.organiserName))
		local rows, s = centre(view)
		nodes[#nodes + 1] = { n = G.UIT.R, config = { align = "cm", minh = 2.6, padding = 0.05 }, nodes = { { n = G.UIT.C, config = { align = "cm" }, nodes = rows } } }
		local buttons = {
			TUI.button("BACK", "mp_pvp_tournaments_back", nil, G.C.ORANGE, 1.8),
			TUI.button("BRACKET", "mp_pvp_tournament_bracket", { id = summary.id }, G.C.BLUE, 1.8),
			TUI.button("DETAILS", "mp_pvp_tournament_details", { id = summary.id }, G.C.UI.BACKGROUND_INACTIVE, 1.8),
		}
		local can_leave = (view.role == "entrant" or view.role == "waitlist") and (summary.status == "registration" or summary.status == "check_in" or (summary.status == "running" and s.kind ~= "eliminated"))
		if can_leave then
			buttons[#buttons + 1] = TUI.button(summary.status == "running" and "DROP OUT" or "LEAVE", "mp_pvp_tournament_screen_leave", { id = summary.id }, G.C.RED, 1.8)
		end
		nodes[#nodes + 1] = TUI.hbox(buttons, "cm", 0.06)
		if screen.error then
			nodes[#nodes + 1] = TUI.message(screen.error, G.C.RED)
		end
	end
	return { nodes = { TUI.panel(nodes, { minw = TUI.WIDTH - 2, align = "cm" }) } }
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
	local running = screen.view and screen.view.summary and screen.view.summary.status == "running"
	local function go()
		PVP.Tournaments.leave(id, function(err)
			if not err then
				MPAPI.pages.show("pvp_find_game", { category = "tournaments" })
			end
		end)
	end
	-- Dropping out mid-tournament forfeits every match left: ask first.
	if running and G.FUNCS.confirm_selection then
		G.FUNCS.confirm_selection(go)
	else
		go()
	end
end
