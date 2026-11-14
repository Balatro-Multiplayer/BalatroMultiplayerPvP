-- Run from the repo root: luajit tests/unit/hands_spent_test.lua
-- The handler for "the server spent my hands" (networking/action_handlers.lua, action_hands_spent)
-- and the reconnect tail catching up with no `args` (pvp_api/reconnect_tail.lua).
local passed, failed = 0, 0
local function check(name, got, want)
	if got == want then
		passed = passed + 1
		print("ok   " .. name)
	else
		failed = failed + 1
		print(("FAIL %s: got %s, wanted %s"):format(name, tostring(got), tostring(want)))
	end
end

-- action_handlers.lua needs the whole game to load, so load just this handler from it.
local file = assert(io.open("networking/action_handlers.lua", "r"))
local text = file:read("*a")
file:close()
local start = assert(text:find("local function action_hands_spent()", 1, true), "handler not found")
local _, finish = text:find("\nend\r?\n", start)
local chunk = text:sub(start, finish) .. "\nreturn action_hands_spent"

local events
local function handler(hands_left)
	events = {}
	G = { play = "play", GAME = { current_round = { hands_left = hands_left } } }
	stop_use = function()
		events[#events + 1] = "stop_use"
	end
	SMODS = {
		calculate_context = function(context)
			events[#events + 1] = ("context mp_pvp_loss=%s hands=%s"):format(
				tostring(context.mp_pvp_loss),
				tostring(context.mp_hands_left)
			)
		end,
	}
	localize = function(key)
		return key
	end
	attention_text = function(args)
		events[#events + 1] = "text " .. args.text
	end
	return assert((loadstring or load)(chunk))()
end

local spend = handler(3)
spend()
check("mp_pvp_loss fires with the hands that were left", events[2], "context mp_pvp_loss=true hands=3")
check("the use is stopped first", events[1], "stop_use")
check("the hands go to 0", G.GAME.current_round.hands_left, 0)
check("the wait text is shown", events[3], "text k_wait_enemy")
check("nothing else happens", #events, 3)

spend = handler(0)
spend()
check("with no hands left nothing happens", #events, 0)
check("with no hands left the hands stay 0", G.GAME.current_round.hands_left, 0)

-- Reconnect tail: the server strips `args` from another player's events.
PVP = { GAME = { enemy = { score = "0", hands = 4, highest_score = "0" } }, RLOG = { _last_seen_t = {} } }
MPAPI = { OPCODE = { HAND_RESULT = 7 } }
dofile("pvp_api/reconnect_tail.lua")
PVP.RECONNECT_TAIL.receive_pushed_tails({ { playerId = "they", events = { { t = 5 }, { t = 6, opcode = 7 } } } })
PVP.RECONNECT_TAIL.catch_up("they")
local ok, err = pcall(PVP.RECONNECT_TAIL.on_checkpoint)
check("a tail with no args is not an error", ok, true)
if not ok then print(err) end
check("a tail with no args leaves the hands alone", PVP.GAME.enemy.hands, 4)
check("a tail with no args still moves the last seen time", PVP.RLOG._last_seen_t.they, 6)

PVP.RECONNECT_TAIL.receive_pushed_tails({
	{ playerId = "they", events = { { t = 8, opcode = 7, args = { "999", 2 } } } },
})
PVP.RECONNECT_TAIL.catch_up("they")
PVP.RECONNECT_TAIL.on_checkpoint()
check("a tail with args does not write the hands either", PVP.GAME.enemy.hands, 4)
check("a tail with args never applies the score", PVP.GAME.enemy.score, "0")
check("a tail with args never sets the highest score", PVP.GAME.enemy.highest_score, "0")

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
