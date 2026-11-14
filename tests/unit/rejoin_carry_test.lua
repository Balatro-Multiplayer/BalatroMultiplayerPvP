-- Run from the repo root: luajit tests/unit/rejoin_carry_test.lua
-- lib/rejoin.lua: every index of the opponent facts survives the attach (the mirror's reset of
-- PVP.GAME), the catch-up begins when the run starts and ends after attach or when the seat is lost.
local hooks, calls

local passed, failed = 0, 0
local function equal(got, want, what)
	assert(got == want, ("%s: got %s, wanted %s"):format(what or "value", tostring(got), tostring(want)))
end

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

local KEYS = {
	"applied",
	"comeback_bonus",
	"comeback_bonus_given",
	"round_end_applied",
	"opponent_applied",
	"replies_applied",
	"traps_applied",
	"traps_sent",
	"trap_rewards_applied",
	"pincher_pending",
	"spent_total",
	"spent_before_shop",
}

local function setup()
	calls = {}
	MPAPI = {
		playback = {
			register_rejoin_hooks = function(_, registered)
				hooks = registered
			end,
		},
	}
	PVP = {
		id = "pvp",
		SP = { practice = true },
		rejoined_lobby_kind = function() end,
		-- What PVP.setup_lobby_mirror does to the match state: a fresh PVP.GAME.
		setup_lobby_mirror = function()
			calls[#calls + 1] = "mirror"
			PVP.GAME = {}
		end,
		_start_playback = function()
			calls[#calls + 1] = "playback"
		end,
		_drop_playback_waiters = function() end,
		OpponentNet = {
			begin_catch_up = function()
				calls[#calls + 1] = "begin"
			end,
			end_catch_up = function()
				calls[#calls + 1] = "end"
			end,
			abort_catch_up = function()
				calls[#calls + 1] = "abort"
			end,
		},
	}
	G = { FUNCS = {
		go_to_menu = function()
			calls[#calls + 1] = "menu"
		end,
	} }
	dofile("lib/rejoin.lua")
end

test("every carried key survives the attach", function()
	setup()
	local saved = {}
	PVP.GAME = {}
	for _, key in ipairs(KEYS) do
		saved[key] = { runId = "r1", marker = key }
		PVP.GAME[key] = saved[key]
	end
	hooks.attach({}, {})
	for _, key in ipairs(KEYS) do
		equal(PVP.GAME[key], saved[key], key)
	end
end)

test("the carried records replace the reset's fresh ones", function()
	setup()
	PVP.GAME = { traps_sent = { runId = "r1", ids = { 4 } } }
	hooks.attach({}, {})
	equal(PVP.GAME.traps_sent.ids[1], 4)
end)

test("a key the save does not hold is left as the reset made it", function()
	setup()
	PVP.GAME = { traps_applied = { runId = "r1", index = 2 } }
	hooks.attach({}, {})
	equal(PVP.GAME.opponent_applied, nil)
	equal(PVP.GAME.traps_sent, nil)
end)

test("a carried opponent_applied is back after the attach, so an applied index is not applied again", function()
	setup()
	PVP.GAME = { opponent_applied = { runId = "r1", index = 5 } }
	hooks.attach({}, {})
	equal(PVP.GAME.opponent_applied.index, 5)
end)

test("attach: the mirror is rebuilt, then the carried keys are back, then the catch-up ends", function()
	setup()
	PVP.GAME = { traps_applied = { runId = "r1", index = 1 } }
	hooks.attach({}, {})
	equal(table.concat(calls, ","), "mirror,end")
	equal(PVP.SP.practice, false)
end)

-- The shop report is spent_total - spent_before_shop (lovely/game.toml). The run save holds both; the mirror's
-- reset zeroes them (core.lua), so without the carry only the spend after the rejoin was reported.
test("a shop visit's spend across a rejoin is the whole visit", function()
	setup()
	-- 6 spent in earlier shops, 4 more in this visit before the crash.
	PVP.GAME = { spent_before_shop = 6, spent_total = 10 }
	-- The mirror's reset: counters back at core.lua's initial values.
	PVP.setup_lobby_mirror = function()
		PVP.GAME = { spent_total = 0, spent_before_shop = 0 }
	end
	hooks.attach({}, {})
	-- 8 spent after the rejoin (the ease_dollars patch's accumulation).
	PVP.GAME.spent_total = PVP.GAME.spent_total + 8
	equal(PVP.GAME.spent_total - PVP.GAME.spent_before_shop, 12, "reported spend")
end)

test("the run start begins the catch-up before the playback starts", function()
	setup()
	hooks.start_run({}, function() end)
	equal(table.concat(calls, ","), "begin,playback")
end)

test("a lost seat ends the catch-up and leaves the run", function()
	setup()
	hooks.aborted()
	equal(table.concat(calls, ","), "abort,menu")
end)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
