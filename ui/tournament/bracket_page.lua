-- The bracket viewer page (pvp_tournament_bracket, params {id}): the whole
-- bracket on a zoomable canvas (ui/tournament/bracket_canvas.lua), with
-- zoom and fit buttons, MY MATCH, an info line for the clicked match, and
-- for round robin and Swiss the standings beside it. Refreshes every few
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

local function deck_name(key)
	local ok, name = pcall(localize, { type = "name_text", set = "Back", key = key })
	return ok and type(name) == "string" and name ~= "ERROR" and name or tostring(key)
end

local function stake_name(index)
	local center = G.P_CENTER_POOLS and G.P_CENTER_POOLS.Stake and G.P_CENTER_POOLS.Stake[index]
	if not center then
		return "stake " .. tostring(index)
	end
	local ok, name = pcall(localize, { type = "name_text", set = "Stake", key = center.key })
	return ok and type(name) == "string" and name ~= "ERROR" and name or center.key
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
	local deck = type(m.deck) == "table" and m.deck or nil
	if deck and deck.kind == "locked" then
		parts[#parts + 1] = deck_name(deck.deck) .. " on " .. stake_name(deck.stake)
	elseif deck and deck.kind == "draft" then
		local stakes = {}
		for _, i in ipairs(deck.stakes or {}) do
			stakes[#stakes + 1] = stake_name(i)
		end
		parts[#parts + 1] = "ban and pick (" .. table.concat(stakes, ", ") .. ")"
	end
	return #parts > 0 and ("Plays: " .. table.concat(parts, ", ")) or ""
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
	local parts = {}
	for _, m in ipairs(view and view.bracket or {}) do
		parts[#parts + 1] = table.concat({ m.id, m.status, name_of(m.players[1]), name_of(m.players[2]), m.wins and m.wins[1] or 0, m.wins and m.wins[2] or 0, m.clock and m.clock.phase or "" }, ",")
	end
	return table.concat(parts, ";")
end

local function apply_view(view)
	page.view = view
	local shape = shape_of(view)
	if page.canvas and shape ~= page.shape then
		page.shape = shape
		page.canvas:set_layout(PVP.BracketLayout.build(view), me())
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
	PVP.Tournaments.get({ id = page.id }, function(err, data)
		if not page.active or err or not data or not data.tournament then
			return
		end
		PVP.Tournaments.state.views[page.id] = data.tournament
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

local function has_standings(view)
	local f = view and view.summary and view.summary.format
	return f == "round_robin" or f == "swiss"
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
		{ n = G.UIT.C, config = { align = "cm", padding = 0.1, minw = width - (page.preview and 12.4 or 9.8) }, nodes = { title } },
		col(TUI.button("-", "mp_pvp_tbracket_zoom", { factor = 1 / 1.3 }, G.C.UI.BACKGROUND_INACTIVE, 0.7, 0.45)),
		col(TUI.button("+", "mp_pvp_tbracket_zoom", { factor = 1.3 }, G.C.UI.BACKGROUND_INACTIVE, 0.7, 0.45)),
		col(TUI.button("FIT", "mp_pvp_tbracket_fit", nil, G.C.UI.BACKGROUND_INACTIVE, 1.2)),
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

function PVP.open_tournament_bracket(id)
	MPAPI.pages.show("pvp_tournament_bracket", { id = id })
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
	MPAPI.pages.back()
end

G.FUNCS.mp_pvp_tbracket_zoom = function(e)
	if page.canvas and e.config.ref_table then
		page.canvas:zoom_by(e.config.ref_table.factor)
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
