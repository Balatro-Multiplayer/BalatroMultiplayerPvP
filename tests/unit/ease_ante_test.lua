-- Plain Lua test for the ante override (ui/game/round.lua): an ante going up is applied once per
-- ante key, but an ante going down (a Manhunt voucher redeemed in the shop of the same blind)
-- is never dropped.
-- Run from the repo root: luajit tests/unit/ease_ante_test.lua
local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

-- round.lua needs the whole game to load, so load just ease_ante (and the vanilla function it
-- wraps) from it.
local function slice(text, header)
	local start = assert(text:find(header, 1, true), "function not found: " .. header)
	local _, finish = text:find("\nend\r?\n", start)
	return text:sub(start, finish)
end
local file = assert(io.open("ui/game/round.lua", "r"))
local text = file:read("*a")
file:close()
local chunk = "local ease_ante_ref = ease_ante\n" .. slice(text, "function ease_ante(mod)") .. "return ease_ante\n"

local reported, vanilla_calls
local function setup(in_multiplayer)
	reported = {}
	vanilla_calls = {}
	G = {
		GAME = { round_resets = { ante = 2 } },
		E_MANAGER = {
			add_event = function(_, event)
				event.func()
			end,
		},
	}
	Event = function(t)
		return t
	end
	ease_discard = function() end
	check_and_set_high_score = function() end
	ease_ante = function(mod)
		vanilla_calls[#vanilla_calls + 1] = mod
	end
	PVP = {
		LOBBY = { config = { disable_live_and_timer_hud = false } },
		GAME = { antes_keyed = {}, ante_key = "key1", pizza_discards = 0 },
		UTILS = { log_mem_debug_messages = function() end },
		ACTIONS = {
			set_ante = function(ante)
				reported[#reported + 1] = ante
			end,
		},
		is_mp_or_practice = function()
			return in_multiplayer
		end,
		is_practice_mode = function()
			return false
		end,
	}
	return assert((loadstring or load)(chunk))()
end

local ease = setup(true)
ease(1)
check("first +1 raises the ante", G.GAME.round_resets.ante, 3)
check("first +1 reports the new ante once", #reported, 1)
check("first +1 reports ante + 1", reported[1], 3)
check("first +1 calls the vanilla function once", #vanilla_calls, 1)
check("first +1 calls the vanilla function with 1", vanilla_calls[1], 1)

ease = setup(true)
ease(1)
ease(1)
check("second +1 under the same key leaves the ante", G.GAME.round_resets.ante, 3)
check("second +1 under the same key reports nothing more", #reported, 1)
check("second +1 under the same key skips the vanilla call", #vanilla_calls, 1)

ease = setup(true)
ease(1)
ease(-1)
check("-1 under a key marked by +1 lowers the ante", G.GAME.round_resets.ante, 2)
check("-1 under a key marked by +1 reports ante - 1", reported[2], 2)
check("-1 under a key marked by +1 calls the vanilla function", #vanilla_calls, 2)
check("-1 under a key marked by +1 calls it with -1", vanilla_calls[2], -1)

ease = setup(true)
ease(-1)
check("-1 under a fresh key lowers the ante", G.GAME.round_resets.ante, 1)
ease(1)
check("-1 under a fresh key does not mark it", G.GAME.round_resets.ante, 2)
check("-1 under a fresh key leaves the later +1 reported", #reported, 2)

ease = setup(true)
ease(1)
PVP.GAME.ante_key = "key2"
ease(1)
check("after a new key a +1 raises the ante again", G.GAME.round_resets.ante, 4)

ease = setup(false)
ease(1)
check("outside multiplayer the ante is left to vanilla", G.GAME.round_resets.ante, 2)
check("outside multiplayer nothing is reported", #reported, 0)
check("outside multiplayer only the vanilla function runs", #vanilla_calls, 1)

if failures > 0 then os.exit(1) end
