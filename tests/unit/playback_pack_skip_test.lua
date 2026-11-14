-- Run from the repo root: luajit tests/unit/playback_pack_skip_test.lua
-- A replayed pack_skip waits for the pack to be open. A skip_blind whose tag opens a pack lets the
-- driver play on at once, and the pack opens a few frames later: a skip_booster before that ends
-- a pack that is not open, and the game state comes back as the (empty) interrupted state, nil.
-- Everything after it, the Blind Select wait of a replay included, then never sees Blind Select.
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

local handlers, waiters, skipped, gave_up, now, driver_log, used

local function setup()
	handlers, waiters, skipped, gave_up, driver_log, used = {}, {}, 0, {}, 0, {}
	now = 0
	G = {
		GAME = {},
		P_BLINDS = {},
		STATES = { BLIND_SELECT = 7, SMODS_BOOSTER_OPENED = 999 },
		STATE = 7,
		STATE_COMPLETE = true,
		FUNCS = {
			use_card = function(e)
				used[#used + 1] = e.config.ref_table
			end,
			skip_booster = function()
				skipped = skipped + 1
			end,
		},
	}
	love = { timer = { getTime = function() return now end } }
	PVP = {
		GAME = { enemy = {} },
		UTILS = { AREA = {} },
		match_log = function() end,
		_playback_wait_for = function(predicate, callback)
			waiters[#waiters + 1] = { predicate = predicate, callback = callback }
		end,
	}
	MPAPI = {
		ActionTypes = {},
		OPCODE = setmetatable({}, {
			__index = function(_, k)
				return k
			end,
		}),
		playback = {
			register_handler = function(_, opcode, fn)
				handlers[opcode] = fn
			end,
			record_gave_up_wait = function(message)
				gave_up[#gave_up + 1] = message
			end,
			leave_shop_if_needed = function() end,
		},
	}
	dofile("lib/playback_handlers.lua")
end

-- One frame of the waiters, as Game:update runs them.
local function frame()
	local list = waiters
	waiters = {}
	for _, w in ipairs(list) do
		if w.predicate() then
			w.callback()
		else
			waiters[#waiters + 1] = w
		end
	end
end

local function ctx()
	return {
		is_pov = true,
		driver = {
			pause = function() driver_log = driver_log + 1 end,
			play = function() driver_log = driver_log - 1 end,
		},
	}
end

test("pack_skip before the pack is open skips nothing, and plays on when it opens", function()
	setup()
	local c = ctx()
	handlers.PACK_SKIP({}, c)
	equal(skipped, 0)
	equal(driver_log, 1)
	frame()
	equal(skipped, 0)
	G.STATE = G.STATES.SMODS_BOOSTER_OPENED
	G.pack_cards = { cards = { {}, {} } }
	frame()
	equal(skipped, 1)
	equal(driver_log, 0)
end)

test("pack_skip waits while the pack's state is not complete", function()
	setup()
	G.STATE = G.STATES.SMODS_BOOSTER_OPENED
	G.pack_cards = { cards = { {} } }
	G.STATE_COMPLETE = false
	handlers.PACK_SKIP({}, ctx())
	frame()
	equal(skipped, 0)
	G.STATE_COMPLETE = true
	frame()
	equal(skipped, 1)
end)

test("pack_pick before the pack is open picks nothing, then picks the card once it opens", function()
	setup()
	local c = ctx()
	handlers.PACK_PICK({ 2 }, c)
	equal(#used, 0)
	equal(driver_log, 1)
	frame()
	equal(#used, 0)
	local first, second = {}, {}
	G.STATE = G.STATES.SMODS_BOOSTER_OPENED
	G.pack_cards = { cards = { first, second } }
	frame()
	equal(#used, 1)
	equal(used[1], second)
	equal(driver_log, 0)
end)

test("a pack that never opens releases the driver on a pick too", function()
	setup()
	handlers.PACK_PICK({ 1 }, ctx())
	now = 11
	frame()
	equal(#used, 0)
	equal(#gave_up, 1)
	equal(driver_log, 0)
end)

test("pack_skip with the pack open skips it", function()
	setup()
	G.STATE = G.STATES.SMODS_BOOSTER_OPENED
	G.pack_cards = { cards = { {} } }
	handlers.PACK_SKIP({}, ctx())
	frame()
	equal(skipped, 1)
end)

test("a pack that never opens is given up on after 10 s, with the driver released", function()
	setup()
	local c = ctx()
	handlers.PACK_SKIP({}, c)
	now = 11
	frame()
	equal(skipped, 0)
	equal(#gave_up, 1)
	equal(driver_log, 0)
end)

test("pack_skip of another player does nothing", function()
	setup()
	handlers.PACK_SKIP({}, { is_pov = false })
	equal(#waiters, 0)
	equal(skipped, 0)
end)

if failures > 0 then
	print(failures .. " failed")
	os.exit(1)
end
print("all passed")
