-- Run from the repo root: luajit tests/unit/shop_spend_test.lua
-- The spend a shop visit reports (lib/shop_spend.lua, with the lovely patches in lovely/game.toml that call
-- it) across a crash rejoin. The run save holds the counters, the catch-up replays what the save does
-- not hold as a practice playback with no lobby code, the mirror's reset zeroes the counters, and the live
-- run resumes in the same shop: the report is the whole visit in every case.
local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
		print("ok   " .. name)
	else
		failed = failed + 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end
local function equal(got, want, what)
	assert(got == want, ("%s: got %s, wanted %s"):format(what or "value", tostring(got), tostring(want)))
end

-- The patch payloads, as the toml holds them: the code that really runs in the game.
local file = assert(io.open("lovely/game.toml", "r"))
local toml = file:read("*a")
file:close()
local function payload_after(anchor)
	local from, at = toml:find(anchor, 1, true)
	assert(from, "patch not found: " .. anchor)
	local _, last = toml:find("payload = '''", at, true)
	local close = assert(toml:find("'''", last + 1, true))
	return toml:sub(last + 1, close - 1)
end
local on_spend = assert(loadstring("local mod = ...\n" .. payload_after("pattern = '''G.GAME.dollars = G.GAME.dollars + mod'''")))
local on_leave_shop = assert(loadstring(payload_after("pattern = '''G.FUNCS.toggle_shop = function(e)'''")))

to_big = function(x)
	return x
end
to_number = function(x)
	return x
end

local reports, hooks

local function setup()
	reports = {}
	MPAPI = {
		playback = {
			register_rejoin_hooks = function(_, registered)
				hooks = registered
			end,
		},
	}
	PVP = {
		id = "pvp",
		LOBBY = {},
		SP = { practice = false },
		GAME = { spent_total = 0, spent_before_shop = 0, shop_marked = false },
		is_mp_or_practice = function()
			return PVP.LOBBY.code or PVP.SP.practice == true
		end,
		rejoined_lobby_kind = function() end,
		-- What the mirror does: the lobby is attached (it has its code) over a fresh match state.
		setup_lobby_mirror = function()
			PVP.LOBBY.code = "ABCD"
			PVP.GAME = { spent_total = 0, spent_before_shop = 0, shop_marked = false }
		end,
		OpponentNet = {
			end_catch_up = function() end,
			report_shop = function(spent)
				reports[#reports + 1] = spent
			end,
		},
	}
	dofile("lib/shop_spend.lua")
	dofile("lib/rejoin.lua")
end

local function leave_shop()
	on_leave_shop()
end

test("a live shop visit reports what it spent, and the next visit starts from the mark", function()
	setup()
	PVP.LOBBY.code = "ABCD"
	PVP.GAME.spent_total = 6
	PVP.open_shop_visit()
	on_spend(-5)
	on_spend(3)
	leave_shop()
	equal(reports[1], 5, "first visit")
	PVP.open_shop_visit()
	on_spend(-2)
	leave_shop()
	equal(reports[2], 2, "second visit")
end)

test("the save holds the visit's spend before the crash: the report covers the whole visit", function()
	setup()
	-- The save was taken after a $5 purchase in this visit (6 spent in earlier shops).
	PVP.GAME = { spent_before_shop = 6, spent_total = 11, shop_marked = true }
	hooks.attach({}, {})
	PVP.open_shop_visit()
	on_spend(-8)
	leave_shop()
	equal(reports[1], 13)
end)

test("the purchase is replayed from the run log with no lobby code: the report covers the whole visit", function()
	setup()
	-- The save is from before the $5 purchase, inside the shop (6 spent in earlier shops).
	PVP.GAME = { spent_before_shop = 6, spent_total = 6, shop_marked = true }
	PVP.SP.practice = true
	-- The catch-up replays the purchase; the shop is built already, so the mark is not set again.
	PVP.open_shop_visit()
	on_spend(-5)
	-- The live lobby attaches: the mirror's reset, then the carried counters.
	hooks.attach({}, {})
	equal(PVP.SP.practice, false)
	-- The live run resumes in the same shop: its open does not move the mark.
	PVP.open_shop_visit()
	on_spend(-8)
	leave_shop()
	equal(reports[1], 13)
end)

test("a shop opened during the catch-up is marked there, with the spend before it", function()
	setup()
	-- The save is from before the shop (6 spent in earlier shops); the replay opens it and buys.
	PVP.GAME = { spent_before_shop = 0, spent_total = 6, shop_marked = false }
	PVP.SP.practice = true
	PVP.open_shop_visit()
	on_spend(-5)
	hooks.attach({}, {})
	PVP.open_shop_visit()
	on_spend(-8)
	leave_shop()
	equal(reports[1], 13)
end)

test("no spend is counted outside a PvP session", function()
	setup()
	on_spend(-5)
	equal(PVP.GAME.spent_total, 0)
end)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
