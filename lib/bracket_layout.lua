-- Where everything goes in the bracket viewer, in "bracket units" (the
-- canvas zooms and pans over this). Pure: tests/unit/bracket_layout_test.lua
-- runs it under plain Lua.
--
-- Input: the server's tournament view (bracket = list of matches with id,
-- stage, round, order, group, players, wins, status, outcome). Output:
--   boxes  { id, x, y, w, h, match }   one per match shown
--   lines  { points = {x1, y1, x2, y2, ...} }  connectors (elbows)
--   labels { text, x, y, sub, sub2, tip }  round headings (tip: lines for a
--                                      hover tooltip); with opts.timing two
--                                      short lines (when it starts, how it's
--                                      played)
--   gaps   { x, y, bottom, text }      a break before a round: drawn in the
--                                      gap left of its column, y to bottom
--   width, height                      the whole drawing
--
-- Elimination: the winners bracket on top, the losers bracket under it, the
-- grand final to the right. Each match sits halfway between the two matches
-- that feed it (match ids say which: W r-i is fed by W r-1 (2i-1) and (2i);
-- see the server's engine/elimination.ts). Matches between two byes are not
-- drawn. Round robin and Swiss: one column per round (per group).

PVP = PVP or {}
local L = {}
PVP.BracketLayout = L

L.BOX_W = 3.6
L.BOX_H = 0.95
L.COL_GAP = 1.1
L.ROW_GAP = 0.3
L.SECTION_GAP = 1.2
L.LABEL_H = 0.55
-- Each timing line under a heading, when shown.
L.SUB_H = 0.36

-- Match ids are "W3-2" (stage, round, order); the grand final and its reset
-- are just "GF1" and "GF2" (one match each).
local function parse_id(id)
	local stage, round, order = id:match("^(%a+)(%d+)%-(%d+)$")
	if stage then
		return stage, tonumber(round), tonumber(order)
	end
	stage, round = id:match("^(GF)(%d+)$")
	if stage then
		return stage, tonumber(round), 1
	end
	return nil
end

local function is_bye(m)
	local a, b = m.players and m.players[1], m.players and m.players[2]
	-- The server sends null (a JSON null decodes to nil or a sentinel) for
	-- nobody and "tbd" for not known yet.
	local function nobody(p)
		return p == nil or p == false or (type(p) ~= "table" and p ~= "tbd")
	end
	return nobody(a) and nobody(b)
end

local function col_x(col)
	return (col - 1) * (L.BOX_W + L.COL_GAP)
end

-- Elimination round names: the last rounds get names.
local function winners_label(round, rounds, double)
	if double then
		if round == rounds then
			return PVP.T("k_tn_winners_final")
		end
		return PVP.T("k_tn_winners_round", round)
	end
	if round == rounds then
		return PVP.T("k_tn_final")
	elseif round == rounds - 1 then
		return PVP.T("k_tn_semifinals")
	elseif round == rounds - 2 and rounds >= 4 then
		return PVP.T("k_tn_quarterfinals")
	end
	return PVP.T("k_tn_round", round)
end

-- Which round (1-based, in playing order) a bracket round is: as the server
-- counts (engine/schedule.ts roundSteps). Double elimination: W1, then W r
-- with L (2r-3), then L (2r-2)...; the grand final and reset after.
function L.step_of(view, stage, round)
	local format = view.summary and view.summary.format
	if format == "double_elim" then
		local k = 0
		for _, m in ipairs(view.bracket or {}) do
			if m.stage == "W" then
				k = math.max(k, m.round or 0)
			end
		end
		if stage == "W" then
			return round == 1 and 1 or 2 * (round - 1)
		elseif stage == "L" then
			return round + 1
		elseif stage == "GF" then
			return 2 * k - 1 + round
		end
	end
	return round
end

-- What to call round `step` (in playing order) in a sentence: the grand
-- final, the final, the semifinals... or "Round 3".
function L.step_name(view, step)
	local format = view.summary and view.summary.format
	local rounds = 0
	for _, m in ipairs(view.bracket or {}) do
		if m.stage == "W" then
			rounds = math.max(rounds, m.round or 0)
		end
	end
	for _, m in ipairs(view.bracket or {}) do
		if L.step_of(view, m.stage, m.round) == step then
			if m.stage == "GF" then
				return PVP.T("k_tn_grand_final")
			elseif format == "single_elim" and m.stage == "W" then
				return winners_label(m.round, rounds, false)
			end
		end
	end
	return PVP.T("k_tn_round", step)
end

local function elimination(view, lh, timing)
	local by_id, rounds = {}, { W = 0, L = 0, GF = 0 }
	for _, m in ipairs(view.bracket or {}) do
		by_id[m.id] = m
		rounds[m.stage] = math.max(rounds[m.stage] or 0, m.round or 0)
	end
	local double = rounds.L > 0 or rounds.GF > 0
	-- The grand final and the reset, by stage and round (their ids are GF1, GF2).
	local gf_id = {}
	for _, m in ipairs(view.bracket or {}) do
		if m.stage == "GF" then
			gf_id[m.round] = m.id
		end
	end
	local GF1, GF2 = gf_id[1] or "GF1", gf_id[2] or "GF2"
	local y = {} -- match id -> top y (within its section)
	local out = { boxes = {}, lines = {}, labels = {} }
	local step = L.BOX_H + L.ROW_GAP

	-- Winners bracket.
	local w_top = lh
	local w_count = 0
	for i = 1, 4096 do
		if not by_id["W1-" .. i] then
			break
		end
		y["W1-" .. i] = w_top + (i - 1) * step
		w_count = i
	end
	for r = 2, rounds.W do
		for i = 1, 4096 do
			local id = "W" .. r .. "-" .. i
			if not by_id[id] then
				break
			end
			local a, b = y["W" .. (r - 1) .. "-" .. (2 * i - 1)], y["W" .. (r - 1) .. "-" .. (2 * i)]
			y[id] = (a and b) and (a + b) / 2 or (a or b or w_top)
		end
	end
	local w_bottom = w_top + math.max(1, w_count) * step

	-- Losers bracket, under the winners bracket.
	local l_top = w_bottom + L.SECTION_GAP + lh
	local l_bottom = l_top
	if rounds.L > 0 then
		local l_count = 0
		for i = 1, 4096 do
			if not by_id["L1-" .. i] then
				break
			end
			y["L1-" .. i] = l_top + (i - 1) * step
			l_count = i
		end
		for r = 2, rounds.L do
			for i = 1, 4096 do
				local id = "L" .. r .. "-" .. i
				if not by_id[id] then
					break
				end
				if r % 2 == 0 then
					-- Survivors meet the drop-ins: level with the match feeding it.
					y[id] = y["L" .. (r - 1) .. "-" .. i] or l_top
				else
					local a, b = y["L" .. (r - 1) .. "-" .. (2 * i - 1)], y["L" .. (r - 1) .. "-" .. (2 * i)]
					y[id] = (a and b) and (a + b) / 2 or (a or b or l_top)
				end
			end
		end
		l_bottom = l_top + math.max(1, l_count) * step
	end

	-- Columns: the winners rounds, the losers rounds, then the grand final
	-- after whichever bracket is wider.
	local col = {}
	for r = 1, rounds.W do
		col["W" .. r] = r
	end
	for r = 1, rounds.L do
		col["L" .. r] = r
	end
	local gf_col = math.max(rounds.W, rounds.L) + 1
	if rounds.GF > 0 then
		local wf, lf = y["W" .. rounds.W .. "-1"], y["L" .. rounds.L .. "-1"]
		local mid = (wf and lf) and (wf + lf) / 2 or (wf or w_top)
		y[GF1] = mid
		y[GF2] = mid
		col.GF1 = gf_col
		col.GF2 = gf_col + 1
	end

	local function box_of(id)
		for _, b in ipairs(out.boxes) do
			if b.id == id then
				return b
			end
		end
		return nil
	end

	-- Boxes.
	for _, m in ipairs(view.bracket or {}) do
		local c = col[m.stage .. m.round]
		if c and y[m.id] and not is_bye(m) and m.status ~= "void" then
			out.boxes[#out.boxes + 1] = { id = m.id, x = col_x(c), y = y[m.id], w = L.BOX_W, h = L.BOX_H, match = m }
		end
	end

	-- Connectors: from the right middle of a feeder to the left middle of the
	-- match it feeds, as an elbow.
	local function connect(from_id, to_id)
		local a, b = box_of(from_id), box_of(to_id)
		if not a or not b then
			return
		end
		local x1, y1 = a.x + a.w, a.y + a.h / 2
		local x2, y2 = b.x, b.y + b.h / 2
		local xm = (x1 + x2) / 2
		out.lines[#out.lines + 1] = { points = { x1, y1, xm, y1, xm, y2, x2, y2 } }
	end
	for _, m in ipairs(view.bracket or {}) do
		local stage, r, i = parse_id(m.id)
		if stage == "W" and r and r > 1 then
			connect("W" .. (r - 1) .. "-" .. (2 * i - 1), m.id)
			connect("W" .. (r - 1) .. "-" .. (2 * i), m.id)
		elseif stage == "L" and r and r > 1 then
			if r % 2 == 0 then
				connect("L" .. (r - 1) .. "-" .. i, m.id)
			else
				connect("L" .. (r - 1) .. "-" .. (2 * i - 1), m.id)
				connect("L" .. (r - 1) .. "-" .. (2 * i), m.id)
			end
		elseif stage == "GF" and r == 1 then
			connect("W" .. rounds.W .. "-1", m.id)
			connect("L" .. rounds.L .. "-1", m.id)
		elseif stage == "GF" and r == 2 then
			connect(GF1, m.id)
		end
	end

	-- Round headings.
	out.gaps = {}
	local gap_seen = {}
	-- A heading with its timing; a break goes in the gap left of the column.
	local function label(text, stage, round, col, y, bottom)
		local info = timing and timing(L.step_of(view, stage, round)) or {}
		out.labels[#out.labels + 1] = { text = text, x = col_x(col), y = y, sub = info.start, sub2 = info.play }
		local key = col .. ":" .. y
		if info.brk and col > 1 and not gap_seen[key] then
			gap_seen[key] = true
			out.gaps[#out.gaps + 1] = { x = col_x(col) - L.COL_GAP / 2, y = y, bottom = bottom, text = info.brk }
		end
	end
	for r = 1, rounds.W do
		label(winners_label(r, rounds.W, double), "W", r, r, 0, w_bottom)
	end
	for r = 1, rounds.L do
		label(PVP.T("k_tn_losers_round", r), "L", r, r, l_top - lh, l_bottom)
	end
	if rounds.GF > 0 then
		local gy = (y[GF1] or 0) - lh
		local gf_bottom = (y[GF1] or 0) + L.BOX_H + L.ROW_GAP
		label(PVP.T("k_tn_grand_final"), "GF", 1, gf_col, gy, gf_bottom)
		if box_of(GF2) then
			label(PVP.T("k_tn_reset"), "GF", 2, gf_col + 1, gy, gf_bottom)
			-- One line per \n in the text.
			local tip = {}
			for line in (PVP.T("k_tn_reset_tip") .. "\n"):gmatch("([^\n]*)\n") do
				tip[#tip + 1] = line
			end
			out.labels[#out.labels].tip = tip
		end
	end

	local max_col = rounds.GF > 0 and (box_of(GF2) and gf_col + 1 or gf_col) or math.max(rounds.W, 1)
	out.width = col_x(max_col) + L.BOX_W
	out.height = (rounds.L > 0 and l_bottom or w_bottom)
	return out
end

local function by_rounds(view, lh, timing)
	local out = { boxes = {}, lines = {}, labels = {}, gaps = {} }
	local step = L.BOX_H + L.ROW_GAP
	local groups, max_round = {}, 0
	for _, m in ipairs(view.bracket or {}) do
		local g = m.group or 1
		groups[g] = groups[g] or {}
		groups[g][m.round] = groups[g][m.round] or {}
		table.insert(groups[g][m.round], m)
		max_round = math.max(max_round, m.round or 0)
	end
	local top = 0
	local multi = #groups > 1
	local swiss = view.summary and view.summary.format == "swiss"
	for g = 1, #groups do
		local rows = 0
		for r = 1, max_round do
			local list = groups[g][r] or {}
			table.sort(list, function(a, b)
				return (a.order or 0) < (b.order or 0)
			end)
			local label = multi and PVP.T("k_tn_group_round", string.char(64 + g), r) or PVP.T("k_tn_round", r)
			-- Timing on the first group's headings (every group plays together).
			local info = timing and g == 1 and timing(r) or {}
			out.labels[#out.labels + 1] = { text = label, x = col_x(r), y = top, sub = info.start, sub2 = info.play }
			if info.brk and r > 1 then
				out.gaps[#out.gaps + 1] = { x = col_x(r) - L.COL_GAP / 2, y = top, bottom = nil, text = info.brk }
			end
			local shown = 0
			for _, m in ipairs(list) do
				-- A Swiss bye is shown (it is a result); a round robin rest isn't a match.
				if not is_bye(m) or swiss then
					out.boxes[#out.boxes + 1] = { id = m.id, x = col_x(r), y = top + lh + shown * step, w = L.BOX_W, h = L.BOX_H, match = m }
					shown = shown + 1
				end
			end
			rows = math.max(rows, shown)
		end
		top = top + lh + math.max(1, rows) * step + L.SECTION_GAP
	end
	-- Round robin and Swiss breaks run down through every group.
	for _, gap in ipairs(out.gaps) do
		gap.bottom = top - L.SECTION_GAP
	end
	out.width = col_x(math.max(1, max_round)) + L.BOX_W
	out.height = math.max(lh + step, top - L.SECTION_GAP)
	return out
end

-- The layout for a tournament view (nil when there is no bracket yet).
-- opts.timing(step) -> { start, play, brk } (text or nil each): two short
-- heading lines per round, and a break shown before it.
function L.build(view, opts)
	if not view or not view.bracket or #view.bracket == 0 then
		return nil
	end
	local timing = type(opts) == "table" and opts.timing or nil
	local lh = timing and (L.LABEL_H + 2 * L.SUB_H) or L.LABEL_H
	local format = view.summary and view.summary.format
	local out
	if format == "round_robin" or format == "swiss" then
		out = by_rounds(view, lh, timing)
	else
		out = elimination(view, lh, timing)
	end
	out.label_h = lh
	return out
end

-- The box of a match id in a layout, or nil.
function L.box(layout, id)
	for _, b in ipairs(layout and layout.boxes or {}) do
		if b.id == id then
			return b
		end
	end
	return nil
end

-- The match box at a point (bracket units), or nil.
function L.hit(layout, x, y)
	for _, b in ipairs(layout and layout.boxes or {}) do
		if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
			return b
		end
	end
	return nil
end

-- Zoom and pan that fit the whole layout into a w x h view with a margin.
function L.fit(layout, w, h, margin)
	margin = margin or 0.3
	local zoom = math.min((w - 2 * margin) / layout.width, (h - 2 * margin) / layout.height)
	zoom = math.max(L.MIN_ZOOM, math.min(L.MAX_ZOOM, zoom))
	-- Pan is the bracket point at the view's top-left corner.
	local pan_x = (layout.width - w / zoom) / 2
	local pan_y = (layout.height - h / zoom) / 2
	return zoom, pan_x, pan_y
end

L.MIN_ZOOM = 0.15
L.MAX_ZOOM = 2.5

return L
