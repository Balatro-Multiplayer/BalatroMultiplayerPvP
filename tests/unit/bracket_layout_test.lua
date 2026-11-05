-- Run from the repo root: lua5.4 tests/unit/bracket_layout_test.lua
-- lib/bracket_layout.lua: where the bracket viewer puts every match.
dofile("lib/bracket_layout.lua")
local L = PVP.BracketLayout

local failures = 0
local function check(name, ok, detail)
	if not ok then
		failures = failures + 1
		print("FAIL " .. name .. (detail and (": " .. detail) or ""))
	end
end

local function player(n)
	return { id = "p" .. n, name = "Player " .. n }
end

-- Match ids the way the server's engine makes them.
local function single(n)
	local size, rounds = 2, 1
	while size < n do
		size, rounds = size * 2, rounds + 1
	end
	local bracket = {}
	for r = 1, rounds do
		for i = 1, size / 2 ^ r do
			local players = r == 1 and { player(2 * i - 1), (2 * i <= n) and player(2 * i) or nil } or { "tbd", "tbd" }
			bracket[#bracket + 1] = { id = "W" .. r .. "-" .. i, stage = "W", round = r, order = i, players = players, wins = { 0, 0 }, status = "waiting" }
		end
	end
	return { summary = { format = "single_elim" }, bracket = bracket }, rounds, size
end

local function double(n)
	local view, rounds, size = single(n)
	view.summary.format = "double_elim"
	local function add(stage, r, i)
		view.bracket[#view.bracket + 1] = { id = stage .. r .. "-" .. i, stage = stage, round = r, order = i, players = { "tbd", "tbd" }, wins = { 0, 0 }, status = "waiting" }
	end
	if rounds >= 2 then
		for i = 1, size / 4 do
			add("L", 1, i)
		end
		for j = 1, rounds - 1 do
			local count = size / 2 ^ (j + 1)
			for i = 1, count do
				add("L", 2 * j, i)
			end
			if j < rounds - 1 then
				for i = 1, count / 2 do
					add("L", 2 * j + 1, i)
				end
			end
		end
	end
	-- The server's ids: GF1 and GF2 (engine/elimination.ts).
	view.bracket[#view.bracket + 1] = { id = "GF1", stage = "GF", round = 1, order = 1, players = { "tbd", "tbd" }, wins = { 0, 0 }, status = "waiting" }
	view.bracket[#view.bracket + 1] = { id = "GF2", stage = "GF", round = 2, order = 1, players = { "tbd", "tbd" }, wins = { 0, 0 }, status = "waiting" }
	return view
end

local function overlaps(a, b)
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

local function sane(name, layout)
	for i = 1, #layout.boxes do
		local a = layout.boxes[i]
		check(name .. " box inside", a.x >= 0 and a.y >= 0 and a.x + a.w <= layout.width + 1e-9 and a.y + a.h <= layout.height + 1e-9, a.id)
		for j = i + 1, #layout.boxes do
			check(name .. " no overlap", not overlaps(a, layout.boxes[j]), a.id .. " / " .. layout.boxes[j].id)
		end
	end
	for _, line in ipairs(layout.lines) do
		local p = line.points
		local from, to = nil, nil
		for _, b in ipairs(layout.boxes) do
			if math.abs(p[1] - (b.x + b.w)) < 1e-9 and math.abs(p[2] - (b.y + b.h / 2)) < 1e-9 then
				from = b
			end
			if math.abs(p[#p - 1] - b.x) < 1e-9 and math.abs(p[#p] - (b.y + b.h / 2)) < 1e-9 then
				to = b
			end
		end
		check(name .. " line joins two boxes", from and to and from.x < to.x)
	end
end

for _, n in ipairs({ 2, 3, 4, 5, 8, 13, 16, 32, 64 }) do
	local view, rounds = single(n)
	local layout = L.build(view)
	sane("single " .. n, layout)
	-- Every round has a heading; the last is the final.
	check("single " .. n .. " labels", #layout.labels == rounds)
	check("single " .. n .. " final", layout.labels[#layout.labels].text == "Final")
	-- Round 2+ sit halfway between their feeders.
	local w21, w11, w12 = L.box(layout, "W2-1"), L.box(layout, "W1-1"), L.box(layout, "W1-2")
	if w21 and w11 and w12 then
		check("single " .. n .. " centred", math.abs(w21.y - (w11.y + w12.y) / 2) < 1e-9)
	end
	-- Fit puts the whole bracket in view.
	local zoom, px, py = L.fit(layout, 14, 6)
	check("single " .. n .. " fits", layout.width * zoom <= 14 + 1e-6 or zoom == L.MIN_ZOOM, tostring(zoom))
	check("single " .. n .. " fit centred", math.abs(px + 7 / zoom - layout.width / 2) < 1e-6 and math.abs(py + 3 / zoom - layout.height / 2) < 1e-6)
end

-- Byes in round 1 are drawn (one player), double byes aren't.
do
	local layout = L.build(single(5))
	check("bye shown", L.box(layout, "W1-2") ~= nil)
	local view = single(4)
	view.bracket[1].players = { nil, nil }
	check("double bye hidden", L.box(L.build(view), "W1-1") == nil)
end

for _, n in ipairs({ 2, 4, 5, 8, 16, 32 }) do
	local layout = L.build(double(n))
	sane("double " .. n, layout)
	local gf = L.box(layout, "GF1")
	check("double " .. n .. " grand final right of everything", gf ~= nil)
	for _, b in ipairs(layout.boxes) do
		if b.id ~= "GF1" and b.id ~= "GF2" then
			check("double " .. n .. " gf last", b.x < gf.x, b.id)
		end
	end
	-- Losers bracket below the winners bracket.
	local lowest_w, highest_l = 0, math.huge
	for _, b in ipairs(layout.boxes) do
		if b.match.stage == "W" then
			lowest_w = math.max(lowest_w, b.y + b.h)
		elseif b.match.stage == "L" then
			highest_l = math.min(highest_l, b.y)
		end
	end
	check("double " .. n .. " losers below", highest_l > lowest_w or highest_l == math.huge)
end

-- A void reset isn't drawn.
do
	local view = double(4)
	for _, m in ipairs(view.bracket) do
		if m.id == "GF2" then
			m.status = "void"
		end
	end
	check("void reset hidden", L.box(L.build(view), "GF2") == nil)
end

-- Round robin: a column per round, groups stacked.
do
	local bracket = {}
	for g = 1, 2 do
		for r = 1, 3 do
			for i = 1, 2 do
				bracket[#bracket + 1] = { id = "RR-g" .. g .. "-r" .. r .. "-" .. i, stage = "RR", round = r, order = i, group = g, players = { player(i), player(i + 2) }, wins = { 0, 0 }, status = "ready" }
			end
		end
	end
	local layout = L.build({ summary = { format = "round_robin" }, bracket = bracket })
	sane("round robin", layout)
	check("round robin boxes", #layout.boxes == 12)
	check("round robin labels", #layout.labels == 6 and layout.labels[1].text == "Group A  -  Round 1")
	check("round robin no lines", #layout.lines == 0)
end

-- Swiss: byes are results, so they show.
do
	local bracket = {
		{ id = "SW1-1", stage = "SW", round = 1, order = 1, players = { player(1), player(2) }, wins = { 1, 0 }, status = "done" },
		{ id = "SW1-2", stage = "SW", round = 1, order = 2, players = { player(3), nil }, wins = { 0, 0 }, status = "done" },
	}
	local layout = L.build({ summary = { format = "swiss" }, bracket = bracket })
	check("swiss bye shown", L.box(layout, "SW1-2") ~= nil)
	check("swiss hit", L.hit(layout, 0.1, L.LABEL_H + 0.1).id == "SW1-1")
	check("swiss miss", L.hit(layout, -1, -1) == nil)
end

-- Rounds in playing order, as the server counts them.
do
	local view = double(8) -- W1-3, L1-4, GF1-2
	check("step W1", L.step_of(view, "W", 1) == 1)
	check("step W2", L.step_of(view, "W", 2) == 2 and L.step_of(view, "L", 1) == 2)
	check("step L2", L.step_of(view, "L", 2) == 3)
	check("step W3", L.step_of(view, "W", 3) == 4 and L.step_of(view, "L", 3) == 4)
	check("step GF", L.step_of(view, "GF", 1) == 6 and L.step_of(view, "GF", 2) == 7)
	check("step single", L.step_of(single(8), "W", 3) == 3)
end

-- Timing: two short heading lines, room for them, and breaks in the gaps.
do
	local plain = L.build(single(8))
	local timed = L.build(single(8), { timing = function(step)
		if step == 1 then
			return { start = "starts Today 1:00 PM", play = "live, 10 min ready-up" }
		elseif step == 2 then
			return { brk = "15 min" }
		end
		return {}
	end })
	check("timed lines", timed.labels[1].sub == "starts Today 1:00 PM" and timed.labels[1].sub2 == "live, 10 min ready-up" and timed.labels[2].sub == nil)
	check("timed room", timed.label_h > plain.label_h and L.box(timed, "W1-1").y > L.box(plain, "W1-1").y)
	sane("timed", timed)
	check("one gap", #timed.gaps == 1 and timed.gaps[1].text == "15 min")
	local g = timed.gaps[1]
	local w1, w2 = L.box(timed, "W1-1"), L.box(timed, "W2-1")
	check("gap between columns", g.x > w1.x + w1.w and g.x < w2.x and g.bottom > g.y)
	check("no gaps untimed", #plain.gaps == 0)
	-- Double elimination: each section's own heading timing, gaps per section.
	local d = L.build(double(8), { timing = function(step)
		return { start = "step " .. step, brk = step == 3 and "5 min" or nil }
	end })
	local subs = {}
	for _, label in ipairs(d.labels) do
		subs[label.text] = label.sub
	end
	check("timed losers", subs["Losers R2"] == "step 3" and subs["Grand Final"] == "step 6", tostring(subs["Losers R2"]))
	check("losers gap", #d.gaps == 1 and d.gaps[1].y > 0)
end

-- The reset heading explains itself (a hover tooltip).
do
	local tip
	for _, label in ipairs(L.build(double(8)).labels) do
		if label.text == "Reset" then
			tip = label.tip
		end
	end
	check("reset tip", type(tip) == "table" and #tip > 0)
end

check("no bracket yet", L.build({ summary = { format = "swiss" }, bracket = nil }) == nil)

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("bracket_layout_test: all passed")
