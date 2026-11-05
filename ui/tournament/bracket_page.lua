-- The bracket viewer page (pvp_tournament_bracket, params {id}): the whole
-- bracket on a zoomable canvas (ui/tournament/bracket_canvas.lua), with
-- zoom and fit buttons, MY MATCH, an info line for the clicked match, and
-- for round robin and Swiss the standings beside it. Under each round's
-- heading, its timing (TIMES toggles it): when it starts, breaks, live or by
-- a deadline. A tournament that hasn't started shows the bracket it would
-- have now (provisional). Refreshes every few
-- seconds; the layout is rebuilt only when the bracket changed, and the
-- view (zoom, position) is kept.
--
-- Preview mode (PVP.open_tournament_bracket_preview, for the Tournament
-- Organiser's create wizard): a made-up bracket handed in by the caller, no
-- refreshing, and < ROUND > buttons that ask the caller for another round.

PVP.TUI = PVP.TUI or {}
local TUI = PVP.TUI

local REFRESH_SECONDS = 5
local CANVAS_H = 6.4
local WIDE = 15.6
local NARROW = 11.2

local page = {
	id = nil,
	view = nil,
	canvas = nil,
	standings = nil,
	active = false,
	shape = nil,
	selected = nil,
	info = { text = "", colour = { 1, 1, 1, 1 } },
	-- What the selected match's round plays (game type, ruleset, decks).
	rules = { text = "", colour = { 1, 1, 1, 1 } },
	-- Preview mode: { view, step, steps, on_step(delta), title }.
	preview = nil,
	round_label = { text = "", colour = { 1, 1, 1, 1 } },
	-- The timing lines under the round headings.
	show_times = true,
}

local HINT = "Drag to move  -  mouse wheel to zoom  -  click a match for details"
local STAGES = { W = "Winners", L = "Losers", GF = "Grand final", RR = "Round", SW = "Round" }

local function me()
	return MPAPI.connection_state and MPAPI.connection_state.player_id or nil
end

local function find_match(id)
	for _, m in ipairs(page.view and page.view.bracket or {}) do
		if m.id == id then
			return m
		end
	end
	return nil
end

local function name_of(p)
	if p == "tbd" then
		return "TBD"
	end
	return type(p) == "table" and p.name or "bye"
end

-- The info line for the selected match: who, the score, and what is happening.
local function info_for(m)
	if not m then
		if page.view and page.view.provisional then
			return "Bracket Preview (not final)", G.C.GOLD
		end
		return HINT, G.C.UI.TEXT_INACTIVE
	end
	local round = (STAGES[m.stage] or m.stage) .. " " .. m.round
	local head = string.format("%s:  %s  %d - %d  %s", round, name_of(m.players[1]), m.wins and m.wins[1] or 0, m.wins and m.wins[2] or 0, name_of(m.players[2]))
	if (m.bestOf or 1) > 1 then
		head = head .. "  (best of " .. m.bestOf .. ")"
	end
	local TT = PVP.TournamentTime
	local clock = m.clock
	if m.status == "done" then
		local w = m.outcome and m.outcome.winner
		local winner = nil
		for _, p in ipairs(m.players or {}) do
			if type(p) == "table" and p.id == w then
				winner = p.name
			end
		end
		local how = m.outcome and m.outcome.reason ~= "played" and ("  (" .. tostring(m.outcome.reason):gsub("_", " ") .. ")") or ""
		return head .. "  -  " .. (winner and (winner .. " won") or (m.outcome and m.outcome.draw and "draw" or "no winner")) .. how, G.C.UI.TEXT_LIGHT
	elseif clock and clock.phase == "in_game" then
		return head .. "  -  playing now", G.C.GREEN
	elseif clock and clock.phase == "ready_up" and clock.deadline then
		return head .. "  -  ready up, " .. (TT.countdown(clock.deadline) or TT.format_local(clock.deadline)) .. " left", G.C.GOLD
	elseif clock and clock.phase == "unplayed" then
		return head .. "  -  not played in time, the organiser decides", G.C.RED
	elseif m.status == "waiting" then
		return head .. "  -  waiting for the earlier matches", G.C.UI.TEXT_INACTIVE
	end
	return head, G.C.UI.TEXT_LIGHT
end

-- "Plays: Nemesis, Balanced, Black Deck on Orange Stake"
local function rules_for(m)
	if not m then
		return ""
	end
	local parts = {}
	if m.gameMode then
		parts[#parts + 1] = TUI.game_type(m.gameMode)
	end
	if m.ruleset then
		parts[#parts + 1] = TUI.ruleset_name(m.ruleset)
	end
	if type(m.deck) == "table" then
		parts[#parts + 1] = TUI.deck_rule(m.deck)
	end
	return #parts > 0 and ("Plays: " .. table.concat(parts, ", ")) or ""
end

-- A round's timing (in playing order) for the bracket: { start, play, brk }.
--   start  when its block of rounds starts, on the block's first round:
--          "starts Today 1:00 PM", "continues Sat 8:00 PM", "organiser
--          starts it", or once the round before has finished, the real time
--   play   "live, 10 min ready-up" or "deadline Sat 8:00 PM"
--   brk    a break before it ("15 min"), drawn between the columns
local function raw_timing(view, step)
	local schedule = view and view.schedule
	if type(schedule) ~= "table" or #schedule == 0 then
		return {}
	end
	local TT = PVP.TournamentTime
	local i, first = 1, 1
	while i < #schedule and step > schedule[i].untilStep do
		first = schedule[i].untilStep + 1
		i = i + 1
	end
	local b = schedule[i]
	local clock = view.blocks and view.blocks[i] or {}
	local out = {}
	local start = b.start or {}
	if step == first and not clock.startedAt then
		if start.kind == "at" then
			out.start = "continues " .. TT.format_local(start.at)
		elseif start.kind == "manual" then
			out.start = "organiser starts it"
		elseif i == 1 then
			if not page.preview then
				out.start = "starts " .. TT.format_local(view.summary.startsAt)
			end
		elseif (start.breakMinutes or 0) > 0 then
			local before = view.blocks and view.blocks[i - 1]
			if before and before.finishedAt then
				out.start = "starts " .. TT.format_local(before.finishedAt + start.breakMinutes * 60000)
			end
		end
	end
	if step == first and start.kind == "after_previous" and (start.breakMinutes or 0) > 0 then
		out.brk = TUI.duration(start.breakMinutes)
	end
	local play = b.play or {}
	if play.kind == "live" then
		out.play = "live, " .. TUI.duration(play.readyUpMinutes) .. " ready-up"
	elseif play.kind == "window" then
		local closes = play.closesAt or (clock.startedAt and play.durationMinutes and (clock.startedAt + play.durationMinutes * 60000))
		out.play = closes and ("deadline " .. TT.format_local(closes)) or (TUI.duration(play.durationMinutes) .. " to play")
	end
	return out
end

-- The same, with the way of playing only where it changes.
local function step_timing(view, step)
	local out = raw_timing(view, step)
	if step > 1 and out.play and out.play == raw_timing(view, step - 1).play then
		out.play = nil
	end
	return out
end

local function update_info()
	local m = page.selected and find_match(page.selected)
	local text, colour = info_for(m)
	TUI.set_live(page.info, text, colour)
	TUI.set_live(page.rules, rules_for(m), G.C.UI.TEXT_INACTIVE)
	if page.preview then
		local p = page.preview
		TUI.set_live(page.round_label, p.step == 0 and "Not started" or (p.step >= p.steps and "Finished" or ("After round " .. p.step .. " of " .. p.steps)), G.C.GOLD)
	end
end

-- What the drawing depends on: rebuild the layout only when this changes.
local function shape_of(view)
	local parts = { tostring(page.show_times) }
	for i, b in ipairs(view and view.blocks or {}) do
		parts[#parts + 1] = i .. ":" .. tostring(b.startedAt) .. ":" .. tostring(b.finishedAt)
	end
	for _, m in ipairs(view and view.bracket or {}) do
		parts[#parts + 1] = table.concat({ m.id, m.status, name_of(m.players[1]), name_of(m.players[2]), m.wins and m.wins[1] or 0, m.wins and m.wins[2] or 0, m.clock and m.clock.phase or "" }, ",")
	end
	return table.concat(parts, ";")
end

-- What the canvas says with no bracket: before the start, a provisional
-- one needs two players.
local function empty_text(view)
	-- Until the first answer: the cached view may be from before the preview.
	if not page.preview and not page.loaded then
		return "Loading..."
	end
	local status = view and view.summary and view.summary.status
	if status == "draft" or status == "registration" or status == "check_in" then
		local n = status == "check_in" and "checked in" or "signed up"
		return "No bracket yet: it appears once 2 players have " .. n .. "."
	elseif status == "cancelled" then
		return "This tournament was cancelled before it started."
	end
	return "The bracket is drawn when the tournament starts."
end

local function apply_view(view)
	page.view = view
	if page.canvas then
		page.canvas:set_empty_text(empty_text(view))
	end
	local shape = shape_of(view)
	if page.canvas and shape ~= page.shape then
		page.shape = shape
		local timing = page.show_times and function(step)
			return step_timing(view, step)
		end or nil
		page.canvas:set_layout(PVP.BracketLayout.build(view, { timing = timing }), me())
	end
	if page.standings then
		page.standings:update()
	end
	update_info()
end

local function load()
	if page.preview then
		return
	end
	-- provisional: before the start, the bracket it would have now.
	PVP.Tournaments.get({ id = page.id, provisional = true }, function(err, data)
		if not page.active or err or not data or not data.tournament then
			return
		end
		page.loaded = true
		-- A provisional bracket isn't the tournament's: keep it out of the cache.
		if not data.tournament.provisional then
			PVP.Tournaments.state.views[page.id] = data.tournament
		end
		apply_view(data.tournament)
	end)
end

local function standings_rows()
	local rows = {}
	local view = page.view
	if not view or not view.standings then
		return rows
	end
	local names = {}
	for _, e in ipairs(view.entrants or {}) do
		names[e.id] = e.name
	end
	for g, table_rows in ipairs(view.standings) do
		if #view.standings > 1 then
			rows[#rows + 1] = { text = "Group " .. string.char(64 + g), colour = G.C.GOLD }
		end
		for _, r in ipairs(table_rows) do
			local mine = r.id == me()
			rows[#rows + 1] = {
				text = string.format("%2d. %s  %g", r.rank, (names[r.id] or "?"):sub(1, 14), r.points),
				colour = mine and G.C.BLUE or (r.dropped and G.C.UI.TEXT_INACTIVE or G.C.UI.TEXT_LIGHT),
			}
		end
	end
	return rows
end

-- Round robin and Swiss get standings beside the bracket -- not before the
-- start (a bracket preview has no results to rank).
local function has_standings(view)
	local s = view and view.summary
	if not s or s.status == "draft" or s.status == "registration" or s.status == "check_in" then
		return false
	end
	return s.format == "round_robin" or s.format == "swiss"
end

local function build_page()
	local view = page.view
	local side = has_standings(view)
	local width = side and NARROW or WIDE
	page.canvas = PVP.BracketCanvas({
		w = width,
		h = CANVAS_H,
		me = me(),
		on_select = function(box)
			page.selected = box and box.id or nil
			update_info()
		end,
	})
	page.shape = nil
	if view then
		apply_view(view)
	end
	local function col(node)
		return { n = G.UIT.C, config = { align = "cm", padding = 0.04 }, nodes = { node } }
	end
	local title
	if page.preview then
		title = TUI.text(page.preview.title or "PREVIEW", 0.45, G.C.PURPLE)
	else
		title = view and TUI.name_line(view.summary, 0.45) or TUI.text("Bracket", 0.45)
	end
	local header_nodes = {
		col(TUI.button("BACK", "mp_pvp_tbracket_back", nil, G.C.ORANGE, 1.6)),
		{ n = G.UIT.C, config = { align = "cm", padding = 0.1, minw = width - (page.preview and 13.9 or 11.3) }, nodes = { title } },
		col(TUI.button("-", "mp_pvp_tbracket_zoom", { factor = 1 / 1.3 }, G.C.UI.BACKGROUND_INACTIVE, 0.7, 0.45)),
		col(TUI.button("+", "mp_pvp_tbracket_zoom", { factor = 1.3 }, G.C.UI.BACKGROUND_INACTIVE, 0.7, 0.45)),
		col(TUI.button("FIT", "mp_pvp_tbracket_fit", nil, G.C.UI.BACKGROUND_INACTIVE, 1.2)),
		col(TUI.button("TIMES", "mp_pvp_tbracket_times", nil, page.show_times and G.C.GOLD or G.C.UI.BACKGROUND_INACTIVE, 1.4)),
	}
	if page.preview then
		-- Step through the made-up results a round at a time.
		header_nodes[#header_nodes + 1] = col(TUI.button("<", "mp_pvp_tbracket_step", { delta = -1 }, G.C.RED, 0.7, 0.45))
		header_nodes[#header_nodes + 1] = { n = G.UIT.C, config = { align = "cm", minw = 3.0 }, nodes = { TUI.live_text(page.round_label, TUI.TEXT) } }
		header_nodes[#header_nodes + 1] = col(TUI.button(">", "mp_pvp_tbracket_step", { delta = 1 }, G.C.RED, 0.7, 0.45))
	else
		header_nodes[#header_nodes + 1] = col(TUI.button("MY MATCH", "mp_pvp_tbracket_mine", nil, G.C.BLUE, 2.0))
	end
	local header = { n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = header_nodes }
	local body_nodes = { { n = G.UIT.C, config = { align = "cm" }, nodes = { { n = G.UIT.O, config = { object = page.canvas } } } } }
	if side then
		if page.standings then
			page.standings:dispose()
		end
		page.standings = TUI.scroll_list({
			items = standings_rows,
			build_row = function(row)
				return { n = G.UIT.R, config = { align = "cl", minw = 3.8 }, nodes = { TUI.text(row.text, TUI.SMALL, row.colour) } }
			end,
			visible = 15,
			row_h = 0.4,
			width = 3.8,
			empty = "No results yet.",
		})
		body_nodes[#body_nodes + 1] = TUI.spacer(0.15)
		body_nodes[#body_nodes + 1] = {
			n = G.UIT.C,
			config = { align = "tm", padding = 0.06 },
			nodes = { TUI.text("STANDINGS", TUI.TEXT, G.C.GOLD), page.standings.node },
		}
	end
	local body = TUI.panel({
		header,
		{ n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = body_nodes },
		{ n = G.UIT.R, config = { align = "cm", padding = 0.04 }, nodes = { TUI.live_text(page.info, TUI.TEXT) } },
		{ n = G.UIT.R, config = { align = "cm", padding = 0.02 }, nodes = { TUI.live_text(page.rules, TUI.SMALL) } },
	}, { align = "cm" })
	return { n = G.UIT.ROOT, config = { align = "tm", colour = G.C.CLEAR }, nodes = { { n = G.UIT.R, config = { align = "tm", padding = 0.1 }, nodes = { body } } } }
end

-- One ticker per visit: leaving and coming back within a second must not
-- leave two running.
local function tick(gen)
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = 1,
		timer = "REAL",
		blockable = false,
		blocking = false,
		func = function()
			if not page.active or gen ~= page.gen then
				return true
			end
			page.seconds = (page.seconds or 0) + 1
			if page.seconds % REFRESH_SECONDS == 0 then
				load()
			else
				update_info()
			end
			tick(gen)
			return true
		end,
	}))
end

MPAPI.on_loaded(function()
	MPAPI.Page({
		key = "pvp_tournament_bracket",
		category = "game_select",
		build = function(self)
			local preview = self.params and self.params.preview
			local id = self.params and self.params.id
			if page.id ~= id or preview ~= page.preview then
				page.selected = nil
			end
			page.preview = preview
			page.id = id
			page.loaded = false
			page.back_to_details = self.params and self.params.back_to_details or false
			page.view = preview and preview.view or PVP.Tournaments.state.views[id]
			return build_page()
		end,
		on_enter = function(self)
			-- The logo out of the way: the bracket wants the whole screen.
			if G.MAIN_MENU_UI then
				G.MAIN_MENU_UI.alignment.offset.y = TUI.PAGE_LIFT
				G.MAIN_MENU_UI:align_to_major()
			end
			MPAPI.set_logo_offset(-10, true)
			page.active = true
			page.loaded = false
			page.seconds = 0
			page.gen = (page.gen or 0) + 1
			update_info()
			load()
			tick(page.gen)
		end,
		dispose = function(self)
			page.active = false
			if page.standings then
				page.standings:dispose()
				page.standings = nil
			end
			page.canvas = nil
		end,
	})
end)

-- opts.back_to_details: BACK reopens the DETAILS overlay it came from.
function PVP.open_tournament_bracket(id, opts)
	MPAPI.pages.show("pvp_tournament_bracket", { id = id, back_to_details = opts and opts.back_to_details or nil })
end

-- A made-up bracket (the Tournament Organiser's preview). spec: { view (a
-- tournament view), step, steps (rounds played / in all), title, on_step =
-- function(delta) } -- on_step answers with PVP.update_tournament_bracket_preview.
function PVP.open_tournament_bracket_preview(spec)
	MPAPI.pages.show("pvp_tournament_bracket", { preview = spec })
end

function PVP.update_tournament_bracket_preview(view, step, steps)
	local p = page.preview
	if not p or not page.active then
		return
	end
	p.view, p.step, p.steps = view, step, steps or p.steps
	apply_view(view)
end

G.FUNCS.mp_pvp_tbracket_step = function(e)
	local delta = e.config.ref_table and e.config.ref_table.delta
	if page.preview and page.preview.on_step and delta then
		page.preview.on_step(delta)
	end
end

G.FUNCS.mp_pvp_tbracket_back = function()
	local details_id = page.back_to_details and page.id
	MPAPI.pages.back()
	if details_id and PVP.open_tournament_details then
		-- Once the page underneath is back.
		G.E_MANAGER:add_event(Event({
			trigger = "after",
			delay = 0.1,
			timer = "REAL",
			blockable = false,
			blocking = false,
			func = function()
				PVP.open_tournament_details(details_id, true)
				return true
			end,
		}))
	end
end

G.FUNCS.mp_pvp_tbracket_zoom = function(e)
	if page.canvas and e.config.ref_table then
		page.canvas:zoom_by(e.config.ref_table.factor)
	end
end

-- The timing lines under the round headings, on or off.
G.FUNCS.mp_pvp_tbracket_times = function(e)
	page.show_times = not page.show_times
	if e and e.config then
		e.config.colour = page.show_times and G.C.GOLD or G.C.UI.BACKGROUND_INACTIVE
	end
	page.shape = nil
	if page.view then
		apply_view(page.view)
	end
end

G.FUNCS.mp_pvp_tbracket_fit = function()
	if page.canvas then
		page.canvas:fit()
	end
end

-- Centre the player's current (or next) match.
G.FUNCS.mp_pvp_tbracket_mine = function()
	local view = page.view
	local id = view and view.you and view.you.nextMatchId
	if not id and view then
		-- Knocked out or finished: their last match.
		for _, m in ipairs(view.bracket or {}) do
			for _, p in ipairs(m.players or {}) do
				if type(p) == "table" and p.id == me() then
					id = m.id
				end
			end
		end
	end
	if id and page.canvas and page.canvas:focus(id) then
		page.selected = id
		update_info()
	end
end
