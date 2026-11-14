-- Run from the repo root: luajit tests/unit/play_commit_test.lua
-- ui/game/timer.lua's Play override: pressing Play in the PvP blind with a PvP hand timer sends
-- pvp.hand_commit with the hands left AFTER this hand, once, and only when the play really ran.
-- The real file is loaded; the engine, the play lock and the clock rules are stubs.
local failures = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		print("ok   " .. name)
	else
		failures = failures + 1
		print("FAIL " .. name .. "\n     " .. tostring(err))
	end
end
local function equal(a, b)
	if a ~= b then error("expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

local commits, logs, ran
local rules, in_pvp_boss, lock_runs
local old_play_body

-- Any colour read answers a table, so the file's gradients load.
local colours = setmetatable({}, {
	__index = function()
		return { 1, 1, 1, 1 }
	end,
})

local function setup(opts)
	opts = opts or {}
	commits, logs, ran = {}, {}, 0
	rules = opts.rules == nil and { ante = "bank", pvp = { baseMs = 60000, handMs = 15000 } } or opts.rules
	if opts.no_rules then rules = nil end
	in_pvp_boss = opts.in_pvp_boss ~= false
	lock_runs = opts.lock_runs ~= false
	old_play_body = opts.old_play or function() end
	G = {
		C = colours,
		FUNCS = {
			play_cards_from_highlighted = function(...)
				ran = ran + 1
				old_play_body(...)
			end,
		},
		play = { cards = opts.play_cards or {} },
		GAME = { current_round = { hands_left = opts.hands_left == nil and 4 or opts.hands_left } },
	}
	if opts.hands_left == false then G.GAME.current_round.hands_left = nil end
	mix_colours = function()
		return { 1, 1, 1, 1 }
	end
	SMODS = {
		Gradient = function() end,
	}
	PVP = {
		UI = {},
		LOBBY = { code = "ABCD", config = {} },
		GAME = {},
		ACTIONS = {
			hand_commit = function(hands_left)
				commits[#commits + 1] = hands_left
			end,
		},
		PlayLock = {
			run = function(play, ...)
				if not lock_runs then return false end
				play(...)
				return true
			end,
		},
		clocks_rules = function()
			return rules
		end,
		is_pvp_boss = function()
			return in_pvp_boss
		end,
		match_log = function(level, msg)
			logs[#logs + 1] = level .. ": " .. msg
		end,
	}
	dofile("ui/game/timer.lua")
end

local function press()
	G.FUNCS.play_cards_from_highlighted()
end

test("the PvP blind with a PvP hand timer sends the hands left after this hand", function()
	setup({ hands_left = 4 })
	press()
	equal(ran, 1)
	equal(#commits, 1)
	equal(commits[1], 3)
end)

test("the last hand sends 0", function()
	setup({ hands_left = 1 })
	press()
	equal(commits[1], 0)
end)

test("a play that changes hands_left still sends the count from before the press", function()
	setup({
		hands_left = 4,
		old_play = function()
			G.GAME.current_round.hands_left = 3
		end,
	})
	press()
	equal(#commits, 1)
	equal(commits[1], 3)
end)

test("not the PvP blind: nothing is sent", function()
	setup({ in_pvp_boss = false })
	press()
	equal(ran, 1)
	equal(#commits, 0)
end)

test("no PvP hand timer in the rules: nothing is sent", function()
	setup({ rules = { ante = "bank" } })
	press()
	equal(#commits, 0)
end)

test("rules unknown: nothing is sent", function()
	setup({ no_rules = true })
	press()
	equal(ran, 1)
	equal(#commits, 0)
end)

test("no lobby: nothing is sent", function()
	setup()
	PVP.LOBBY.code = nil
	press()
	equal(#commits, 0)
end)

test("a play the lock dropped sends nothing", function()
	setup({ lock_runs = false })
	press()
	equal(ran, 0)
	equal(#commits, 0)
end)

test("a play vanilla refused (cards still in G.play) sends nothing", function()
	setup({ play_cards = { {} } })
	press()
	equal(#commits, 0)
end)

test("hands_left not a number: nothing is sent and the warning is logged", function()
	setup({ hands_left = false })
	press()
	equal(ran, 1)
	equal(#commits, 0)
	equal(#logs, 1)
	assert(logs[1]:find("^warn: %[pvp%] hand_commit skipped"), logs[1])
end)

if failures > 0 then
	print(failures .. " failed")
	os.exit(1)
end
print("all passed")
