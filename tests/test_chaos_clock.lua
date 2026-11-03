-- Offline lifecycle and real adapter/UI contracts; not game/scoring evidence.
PVP = { LOBBY = {} }
dofile("lib/chaos_clock.lua")
dofile("lib/chaos_effects.lua")
local C = PVP.CHAOS
local checks = 0
local function check(condition, message)
	assert(condition, message)
	checks = checks + 1
end
local function clone(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in pairs(value) do
		result[key] = clone(item)
	end
	return result
end

local applied, removed = 0, 0
local allowed = true
local adapter = {
	allowed = function()
		return allowed, "Unsafe point"
	end,
	apply = function()
		applied = applied + 1
		return {}
	end,
	remove = function()
		removed = removed + 1
	end,
}
local state = C.new_state("TEST")
local runtime = C.runtime(state, adapter)
check(#runtime:candidates() == 10, "Ten implemented recipes")
local first = assert(runtime:activate("second_wind"))
check(not runtime:activate("second_wind"), "Duplicate activation rejected")
check(not runtime:activate("all_in"), "Resource claims exclude overlapping owners")
assert(runtime:activate("fresh_start"))
check(#state.active == 2, "Disjoint resources compose")
local before = applied
check(not runtime:activate("bonfire"), "Pending recipes rejected")
check(applied == before, "Rejected effects have no side effects")
check(not runtime:activate("missing"), "Unknown recipes rejected")
runtime:boundary("shop_end")
check(#state.active == 2, "Unrelated boundary does not expire")
runtime:boundary("blind_end")
check(#state.active == 0 and removed == 2, "Blind expiry removes exactly once")
check(not runtime:expire(first.id) and removed == 2, "Repeated expiry is harmless")
assert(runtime:activate("pocket_change"))
check(#state.active == 0, "Instant grants do not linger")
runtime:clear()
check(removed == 2, "Clearing does not reclaim instant grants")

-- Saved once-only trigger state and arbitrary duration counts, without
-- serializing handler closures into instances.
local fires = 0
C.handlers.test = function(_, _, context)
	fires = fires + context.amount
end
C.define({
	key = "test_event",
	label = "Test event",
	duration = { boundary = "ante_end", count = 2 },
	events = { after_scoring = { once = true, handler = "test" } },
})
assert(runtime:activate("test_event"))
runtime:event("after_scoring", { amount = 1 })
local restored = clone(state)
local restored_runtime = C.runtime(restored, adapter)
restored_runtime:event("after_scoring", { amount = 1 })
check(fires == 1, "Once trigger survives restoration")
restored_runtime:boundary("ante_end", "ante1")
check(restored.active[1].remaining == 1, "Boundary counter decrements")
restored_runtime:boundary("ante_end", "ante1")
check(restored.active[1].remaining == 1, "Repeated boundary token is harmless")
restored_runtime = C.runtime(clone(restored), adapter)
restored = restored_runtime.state
restored_runtime:boundary("ante_end", "ante1")
check(restored.active[1].remaining == 1, "Boundary deduplication survives restoration")
restored_runtime:boundary("ante_end", "ante2")
check(#restored.active == 0, "Multi-boundary duration expires")
C.effects.test_event = nil
state.active = {}

local a, b = C.runtime(C.new_state("SEED"), adapter), C.runtime(C.new_state("SEED"), adapter)
for _ = 1, 50 do
	local left, right = a:random(), b:random()
	check(left.key == right.key, "Dedicated RNG is repeatable")
	check(not C.effects[left.key].pending, "Random selection excludes pending effects")
	a:clear()
	b:clear()
end
local clock = a.state.scheduler
check(not clock.enabled, "Scheduler is opt-in")
a:advance(100)
check(clock.remaining == 30, "Disabled clock does not advance")
clock.enabled = true
a:advance(10, true)
check(clock.remaining == 30, "Paused clock does not advance")
a:advance(10, false)
check(clock.remaining == 20, "Manual tick advances")
allowed = false
local rng = a.state.rng
a:advance(1000)
check(clock.remaining == 0 and a.state.rng == rng, "Unsafe due event waits without consuming RNG")
allowed = true
check(a:advance(0) ~= nil and clock.remaining == 30, "Due event retries at eligible point")
check(#a.state.active <= 1, "No catch-up storm")
check(not pcall(function()
	a:advance(-1)
end), "Reject negative time")
check(not pcall(function()
	a:advance(0 / 0)
end), "Reject NaN time")
check(not pcall(function()
	C.define({ key = "bad_duration", payload = {}, duration = { boundary = "blind_end", count = 0 } })
end), "Reject invalid recipe duration")

-- Load the real game adapter with only its external boundaries stubbed.
local solo = true
local cashouts, saves = 0, 0
PVP.is_singleplayer = function()
	return solo
end
G = {
	STAGES = { RUN = 1 },
	STAGE = 1,
	STATES = { BLIND_SELECT = 1, SHOP = 2, SELECTING_HAND = 3 },
	STATE = 1,
	CONTROLLER = { locked = false },
	SETTINGS = {},
	GAME = { round_resets = { hands = 1, discards = 0 }, modifiers = {}, dollars = 0 },
	FUNCS = {
		cash_out = function()
			cashouts = cashouts + 1
			return "cashout"
		end,
	},
}
SMODS = {
	always_scores = function(card)
		return card.stone
	end,
	calculate_context = function()
		return "context", "preserved"
	end,
}
ease_dollars = function(amount)
	G.GAME.dollars = G.GAME.dollars + amount
end
save_run = function()
	saves = saves + 1
end
dofile("overrides/chaos_clock.lua")
runtime = assert(C.for_run(true))
assert(runtime:activate("all_in"))
check(G.GAME.round_resets.hands == 2 and G.GAME.round_resets.discards == 0, "Resource floors respected")
G.GAME.round_resets.hands = G.GAME.round_resets.hands + 1
runtime:clear()
check(
	G.GAME.round_resets.hands == 2 and G.GAME.round_resets.discards == 0,
	"Actual delta undone, permanent gains preserved"
)
assert(runtime:activate("working_capital"))
check(G.GAME.modifiers.no_interest == true, "Modifier applied")
local saved_game = clone(G.GAME)
G.GAME = saved_game
runtime = assert(C.for_run())
check(G.GAME.round_resets.hands == 3, "Reconstruction does not double-apply")
check(G.FUNCS.cash_out() == "cashout" and cashouts == 1, "Cashout forwards return")
check(G.GAME.round_resets.hands == 2 and G.GAME.modifiers.no_interest == nil, "Cashout expiry restores nil")

G.GAME.modifiers.no_interest = false
check(not runtime:activate("working_capital"), "Even false existing modifier ownership is preserved")
local receipt = C.adapter.apply({ modifiers = { no_interest = true } })
C.adapter.remove(receipt)
check(G.GAME.modifiers.no_interest == false, "Undo receipt preserves false")
G.GAME.modifiers.no_interest = nil
receipt = C.adapter.apply({ modifiers = { no_interest = true } })
G.GAME.modifiers.no_interest = "external"
C.adapter.remove(receipt)
check(G.GAME.modifiers.no_interest == "external", "Cleanup does not overwrite external writer")
G.GAME.modifiers.no_interest = nil
G.GAME.pvp_round_deltas = { glass_cannon = { hands = -1 } }
check(not runtime:activate("second_wind"), "Static resource owner excludes timed owner")
G.GAME.pvp_round_deltas = nil
assert(runtime:activate("everybody_counts"))
check(
	SMODS.always_scores({}) and SMODS.always_scores({ stone = true }),
	"All-card membership is boolean, not duplicate scoring"
)
runtime:clear()
check(not SMODS.always_scores({}) and SMODS.always_scores({ stone = true }), "Native scoring behavior restored")
assert(runtime:activate("pocket_change"))
runtime:clear()
check(G.GAME.dollars == 3, "Instant cash remains after clearing")
G.STATE = G.STATES.SHOP
G.GAME.pack_choices = 1
check(C.safe_point(), "A previous booster choice count does not block the shop")
assert(runtime:activate("shop_subsidy"))
check(G.GAME.dollars == 8, "Shop payload delivered")
check(not runtime:activate("second_wind"), "Wrong activation boundary rejected")
local one, two = SMODS.calculate_context({ ending_shop = true })
check(one == "context" and two == "preserved", "Context wrapper preserves multiple returns")
G.STATE = G.STATES.SELECTING_HAND
check(not runtime:activate("pocket_change"), "No mid-hand activation")
solo = false
check(C.for_run(true) == nil, "No vanilla/network/replay run mutation")
solo = true
PVP.LOBBY.code = "NETWORK"
check(C.for_run(true) == nil, "Network lobby explicitly excluded")
PVP.LOBBY.code = nil

-- Render-tree smoke and actual debug callbacks (not a live UI test).
G.STATE = G.STATES.BLIND_SELECT
G.UIT = { R = "row", T = "text" }
G.C = { UI = { TEXT_LIGHT = {} }, PURPLE = {} }
UIBox_button = function(config)
	return { config = config }
end
create_option_cycle = function(config)
	return { config = config }
end
create_UIBox_generic_options = function(config)
	return config
end
create_UIBox_options = function()
	return "normal options"
end
G.FUNCS.overlay_menu = function(config)
	G.OVERLAY_MENU = config.definition
end
localize = function(key)
	return key
end
G.FUNCS.options = function(value)
	return "original options", value
end
dofile("ui/pvp_run_options.lua")
dofile("ui/chaos_debug.lua")
G.FUNCS.options()
check(
	G.OVERLAY_MENU.contents[2].nodes[1].config.button == "pvp_chaos_debug",
	"Actual Options entry point exposes lab without active-menu dispatch"
)
check(G.SETTINGS.paused, "Solo Options pauses the game")
G.STATE = G.STATES.SELECTING_HAND
G.FUNCS.options()
check(G.OVERLAY_MENU.contents[2].nodes[1].config.button == "pvp_chaos_debug", "Lab entry remains visible during a hand")
G.FUNCS.pvp_chaos_debug()
check(#G.OVERLAY_MENU.contents <= 3, "Mid-hand lab is read-only")
solo = false
local original, argument = G.FUNCS.options("passthrough")
check(
	original == "original options" and argument == "passthrough",
	"Unrelated runs retain original Options behavior and returns"
)
solo = true
G.STATE = G.STATES.BLIND_SELECT
G.FUNCS.pvp_chaos_debug()
check(#G.OVERLAY_MENU.contents > 6, "Debug menu builds controls and status")
G.FUNCS.pvp_chaos_random()
check(saves == 1 and G.GAME.pvp_chaos.last ~= nil, "Debug random uses shared runtime and saves")
G.FUNCS.pvp_chaos_clear()
check(#G.GAME.pvp_chaos.active == 0, "Debug clear uses shared expiry")
G.FUNCS.pvp_chaos_scheduler()
G.FUNCS.pvp_chaos_tick()
check(G.GAME.pvp_chaos.scheduler.remaining == 20, "Debug tick drives scheduler stub")
G.FUNCS.pvp_chaos_normal_options()
check(G.OVERLAY_MENU == "normal options", "Original run options remain reachable")

-- The draft and lab share a run but not resource ownership or selection RNG.
-- Exercise both real implementations together, including saved undo receipts.
dofile("lib/chaos_draft.lua")
local D = PVP.CHAOS_DRAFT
G.P_CENTERS = { b_blue = { config = { hands = 1 } }, b_red = { config = { discards = 1 } } }
G.GAME.chaos_draft = D.new("COMBINED")
local draft = G.GAME.chaos_draft
local expected = clone(D.offer(D.new("COMBINED"), 2, G.P_CENTERS))
local hands = G.GAME.round_resets.hands
runtime = assert(C.for_run())
assert(runtime:activate("second_wind"))
local offer = D.offer(draft, 2, G.P_CENTERS)
check(
	table.concat(offer.choices, ",") == table.concat(expected.choices, ","),
	"Timed effects do not change draft offers"
)
assert(D.commit(draft, "b_blue", D.apply))
check(G.GAME.round_resets.hands == hands + 2, "Permanent acquisition composes with timed resource delta")
G.GAME = clone(G.GAME)
runtime = assert(C.for_run())
runtime:clear()
check(G.GAME.round_resets.hands == hands + 1, "Saved timed expiry retains the acquired Blue Deck hand")
check(D.has(G.GAME.chaos_draft, "b_blue"), "Clearing lab effects does not clear deck acquisitions")
print("Chaos Clock: " .. checks .. " checks passed")
