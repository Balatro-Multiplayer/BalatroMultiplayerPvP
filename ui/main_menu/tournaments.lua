-- The TOURNAMENTS tab of the Find Game page (ui/main_menu/find_game.lua):
-- the tournaments the player plays in, full width, in a scrollable list
-- (finished and cancelled ones behind "Show past"). Each row says what is
-- happening for the player and offers what to do next (CHECK IN, READY,
-- UNREADY) plus OPEN, the tournament's own screen (ui/tournament/screen.lua).
-- The header has BROWSE (ui/tournament/browser.lua) and, only when the
-- Tournament Organiser mod has registered a section, ORGANISE.
-- Data comes from PVP.Tournaments (pvp_api/tournament/net.lua): refreshed
-- every REFRESH_SECONDS and on tournament notifications; countdowns redraw
-- every second.

-- Shared with ui/tournament/common.lua, which fills it (it loads after this file).
PVP.TUI = PVP.TUI or {}
local TUI = PVP.TUI

local REFRESH_SECONDS = 15
local VISIBLE_ROWS = 4

-- Sections other mods add (the Organiser mod's Create/manage).
-- def = { key = string, label = string?, build = function() return a UI node end }.
PVP._tournament_sections = PVP._tournament_sections or {}

function PVP.register_tournament_section(def)
	assert(type(def) == "table" and type(def.key) == "string" and type(def.build) == "function", "register_tournament_section needs key and build")
	for i, existing in ipairs(PVP._tournament_sections) do
		if existing.key == def.key then
			PVP._tournament_sections[i] = def
			return
		end
	end
	PVP._tournament_sections[#PVP._tournament_sections + 1] = def
end

local ACTIVE = { registration = true, check_in = true, running = true }
local ORDER = { running = 1, check_in = 2, registration = 3, finished = 4, cancelled = 5 }

-- The tournaments the player plays in (not those they only organise):
-- current ones, or past ones. What's happening soonest first.
local function playing(past)
	local out = {}
	for _, t in ipairs(PVP.Tournaments.state.mine or {}) do
		local mine = t.role == "entrant" or t.role == "waitlist"
		if mine and (ACTIVE[t.status] and not past or not ACTIVE[t.status] and past) then
			out[#out + 1] = t
		end
	end
	table.sort(out, function(a, b)
		local oa, ob = ORDER[a.status] or 9, ORDER[b.status] or 9
		if oa ~= ob then
			return oa < ob
		end
		if past then
			return (a.startsAt or 0) > (b.startsAt or 0)
		end
		return (a.startsAt or 0) < (b.startsAt or 0)
	end)
	return out
end

local tab = { list = nil, header = nil, active = false, unlisten = nil, past = false }

-- The status line of each row, by tournament id (live text: ticks without a rebuild).
local live = {}

-- What a row looks like apart from its ticking status text: when this
-- changes, the list is rebuilt.
local function row_shape(t, s)
	return table.concat({ t.id, t.name, TUI.meta_line(t), tostring(t.official), tostring(t.rankedOk), s.kind or "", s.action and s.action.label or "" }, "|")
end

local function list_shape()
	local views = PVP.Tournaments.state.views
	local parts = { tostring(tab.past), tostring(PVP.Tournaments.state.mine ~= nil) }
	for _, t in ipairs(playing(tab.past)) do
		parts[#parts + 1] = row_shape(t, TUI.status_for(t, views[t.id]))
	end
	return table.concat(parts, "\n")
end

local function header_shape()
	return table.concat({ tostring(tab.past), #playing(true), #PVP._tournament_sections, PVP.Tournaments.state.error or "" }, "|")
end

-- Updates every row's status text in place.
local function refresh_live()
	local views = PVP.Tournaments.state.views
	for _, t in ipairs(playing(tab.past)) do
		if live[t.id] then
			local s = TUI.status_for(t, views[t.id])
			TUI.set_live(live[t.id], s.text, s.colour)
		end
	end
end

local function build_row(t)
	local TN = PVP.Tournaments
	local s = TUI.status_for(t, TN.state.views[t.id])
	local status = TUI.live(live, t.id)
	TUI.set_live(status, s.text, s.colour)
	local buttons = {}
	if s.action then
		buttons[#buttons + 1] = TUI.button(s.action.label, s.action.button, { id = t.id }, s.action.colour, 1.7)
	end
	buttons[#buttons + 1] = TUI.button(PVP.T("k_tn_b_open"), "mp_pvp_tournament_open", { id = t.id }, G.C.BLUE, 1.3)
	local left = {
		TUI.name_line(t),
		TUI.line({ TUI.text(TUI.meta_line(t), TUI.SMALL, G.C.UI.TEXT_INACTIVE) }),
		TUI.line({ TUI.live_text(status, TUI.TEXT) }),
	}
	-- Signed up to a ranked-profile tournament, but not on it right now.
	if t.rankedOk == false then
		left[#left + 1] = TUI.line({ TUI.plain(PVP.T("k_tn_ranked_required"), TUI.SMALL, G.C.RED) })
	end
	return TUI.row(left, buttons, TUI.WIDTH - 0.6, t.official)
end

local function build_header()
	local state = PVP.Tournaments.state
	local left = TUI.text(PVP.T(tab.past and "k_tn_past_tournaments" or "k_tn_your_tournaments"), 0.45, G.C.GOLD)
	local buttons = {}
	local past_count = #playing(true)
	if tab.past then
		buttons[#buttons + 1] = TUI.button(PVP.T("k_tn_b_show_current"), "mp_pvp_tournaments_toggle_past", nil, G.C.UI.BACKGROUND_INACTIVE, 2.4)
	elseif past_count > 0 then
		buttons[#buttons + 1] = TUI.button(PVP.T("k_tn_b_show_past", past_count), "mp_pvp_tournaments_toggle_past", nil, G.C.UI.BACKGROUND_INACTIVE, 2.4)
	end
	buttons[#buttons + 1] = TUI.button(PVP.T("k_tn_b_browse"), "mp_pvp_tournaments_browse", nil, G.C.BLUE, 2.0)
	if #PVP._tournament_sections > 0 then
		buttons[#buttons + 1] = TUI.button(PVP.T("k_tn_organise"), "mp_pvp_tournaments_organise", nil, G.C.PURPLE, 2.0)
	end
	local right = {}
	for _, b in ipairs(buttons) do
		right[#right + 1] = { n = G.UIT.C, config = { align = "cm", padding = 0.04 }, nodes = { b } }
	end
	local rows = {
		{
			n = G.UIT.R,
			config = { align = "cm", minw = TUI.WIDTH },
			nodes = {
				{ n = G.UIT.C, config = { align = "cl", minw = TUI.WIDTH - 7.2 }, nodes = { left } },
				{ n = G.UIT.C, config = { align = "cr", minw = 7.2 }, nodes = { { n = G.UIT.R, config = { align = "cr" }, nodes = right } } },
			},
		},
	}
	if state.error then
		rows[#rows + 1] = TUI.message(state.error, G.C.RED)
	end
	return { nodes = { { n = G.UIT.C, config = { align = "cm" }, nodes = rows } } }
end

local function empty_text()
	local state = PVP.Tournaments.state
	if not state.mine then
		return state.error and "" or PVP.T("k_tn_loading")
	end
	return PVP.T(tab.past and "k_tn_no_past" or "k_tn_none_joined")
end

-- After any change: rebuild the header or the list only when what they show
-- changed; otherwise just update the status texts.
local function redraw(force)
	local hs = header_shape()
	if tab.header and (force or hs ~= tab.header_shape) then
		tab.header_shape = hs
		tab.header:update()
	end
	local ls = list_shape()
	if tab.list and (force or ls ~= tab.list_shape) then
		tab.list_shape = ls
		tab.list:update()
	else
		refresh_live()
	end
end

local function schedule(delay, fn)
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = delay,
		blockable = false,
		blocking = false,
		timer = "REAL",
		func = function()
			if tab.active then
				fn()
			end
			return true
		end,
	}))
end

local function tick_countdowns()
	schedule(1, function()
		redraw()
		tick_countdowns()
	end)
end

local function tick_refresh()
	schedule(REFRESH_SECONDS, function()
		PVP.Tournaments.refresh()
		tick_refresh()
	end)
end

function PVP.start_tournaments_tab()
	if tab.active then
		return
	end
	tab.active = true
	tab.unlisten = PVP.Tournaments.on_change(function()
		redraw()
	end)
	PVP.Tournaments.refresh()
	tick_countdowns()
	tick_refresh()
end

function PVP.stop_tournaments_tab()
	tab.active = false
	if tab.unlisten then
		tab.unlisten()
		tab.unlisten = nil
	end
	if tab.list then
		tab.list:dispose()
		tab.list = nil
	end
	tab.header = nil
end

-- The tab's content under the Find Game tab row: { definition, dispose }.
function PVP.build_tournaments_ui(tab_row)
	if tab.list then
		tab.list:dispose()
	end
	tab.header_shape, tab.list_shape = nil, nil
	tab.header = MPAPI.ui_element(build_header)
	tab.list = TUI.scroll_list({
		items = function()
			return playing(tab.past)
		end,
		build_row = build_row,
		visible = VISIBLE_ROWS,
		row_h = 1.0,
		width = TUI.WIDTH - 0.6,
		empty = empty_text,
	})
	local body = TUI.panel({
		{ n = G.UIT.R, config = { align = "cm" }, nodes = { tab.header.node } },
		{ n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = { tab.list.node } },
	}, { minw = TUI.WIDTH })
	local definition = {
		n = G.UIT.ROOT,
		config = { align = "tm", colour = G.C.CLEAR },
		nodes = { tab_row, { n = G.UIT.R, config = { align = "tm", padding = 0.12 }, nodes = { body } } },
	}
	return {
		definition = definition,
		dispose = function()
			PVP.stop_tournaments_tab()
		end,
	}
end

-- Buttons. Each acts on the tournament id in its ref_table.
local function id_of(e)
	return e and e.config and e.config.ref_table and e.config.ref_table.id
end

function PVP.open_tournament(id)
	MPAPI.pages.show("pvp_tournament", { id = id })
end

G.FUNCS.mp_pvp_tournament_open = function(e)
	local id = id_of(e)
	if id then
		PVP.open_tournament(id)
	end
end

G.FUNCS.mp_pvp_tournaments_browse = function()
	MPAPI.pages.show("pvp_tournament_browse", {})
end

G.FUNCS.mp_pvp_tournaments_organise = function()
	MPAPI.pages.show("pvp_tournament_organise", {})
end

G.FUNCS.mp_pvp_tournaments_toggle_past = function()
	tab.past = not tab.past
	if tab.list then
		tab.list.offset = 0
	end
	redraw(true)
end

G.FUNCS.mp_pvp_tournament_join = function(e)
	local id = id_of(e)
	if id then
		PVP.Tournaments.join(id)
	end
end

G.FUNCS.mp_pvp_tournament_leave = function(e)
	local id = id_of(e)
	if id then
		PVP.Tournaments.leave(id)
	end
end

-- Checking in takes the player to the tournament's screen to wait there.
G.FUNCS.mp_pvp_tournament_check_in = function(e)
	local id = id_of(e)
	if id then
		PVP.Tournaments.check_in(id, function(err)
			if not err and MPAPI.pages.current_key() ~= "pvp_tournament" then
				PVP.open_tournament(id)
			end
		end)
	end
end

G.FUNCS.mp_pvp_tournament_ready = function(e)
	local id = id_of(e)
	if id then
		PVP.Tournaments.ready(id, true)
	end
end

G.FUNCS.mp_pvp_tournament_unready = function(e)
	local id = id_of(e)
	if id then
		PVP.Tournaments.ready(id, false)
	end
end
