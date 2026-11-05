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
	add("GF", 1, 1)
	add("GF", 2, 1)
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
	local gf = L.box(layout, "GF1-1")
	check("double " .. n .. " grand final right of everything", gf ~= nil)
	for _, b in ipairs(layout.boxes) do
		if b.id ~= "GF1-1" and b.id ~= "GF2-1" then
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
		if m.id == "GF2-1" then
			m.status = "void"
		end
	end
	check("void reset hidden", L.box(L.build(view), "GF2-1") == nil)
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

check("no bracket yet", L.build({ summary = { format = "swiss" }, bracket = nil }) == nil)

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("bracket_layout_test: all passed")
