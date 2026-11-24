-- Run from the repo root: luajit tests/unit/timer_start_sound_test.lua
-- Main's timer start sound: it plays when an Ante or PvP countdown starts or its starter resumes it,
-- mine or an opponent's, as the Timer SFX setting allows. Never for the server's hold on a countdown ending.
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

PVP = {}
dofile("pvp_api/timer_reader.lua")
local reader = PVP.timer_reader

local function view(deadlines)
	return { me = "a", timers = { deadlines = deadlines } }
end
local function ante(by, hold)
	return { kind = "ante", by = by, against = { "b" }, endsAt = 100000, pausedAt = hold ~= "counting" and 80000 or nil, hold = hold }
end

local none = view({})
eq(reader.timer_started(none, view({ ante("a", "counting") })), true, "my Ante timer starts")
eq(reader.timer_started(none, view({ ante("b", "counting") })), true, "the opponent's Ante timer reaches me")
eq(reader.timer_started(none, view({ { kind = "pvp", by = "a", against = { "b" }, endsAt = 1, hold = "counting" } })), true, "a PvP timer starts")
eq(reader.timer_started(view({ ante("a", "paused by starter") }), view({ ante("a", "counting") })), true, "a resume plays again")
eq(reader.timer_started(view({ ante("a", "counting") }), view({ ante("a", "counting") })), false, "a running timer plays once")
eq(reader.timer_started(view({ ante("a", "counting") }), view({ ante("a", "paused by starter") })), false, "a pause is silent")
eq(reader.timer_started(view({ ante("a", "held for player") }), view({ ante("a", "counting") })), false, "the server's hold ending is silent")
-- A timer started while I animate reaches me held by the server: still its start (main plays on the start).
eq(reader.timer_started(none, view({ ante("b", "held for player") })), true, "the opponent's timer reaching me held plays")
eq(reader.timer_started(none, view({ { kind = "pvp", by = "b", against = { "a" }, endsAt = 1, hold = "held for player" } })), true, "a PvP timer reaching me held plays")
eq(reader.timer_started(view({ ante("a", "paused by starter") }), view({ ante("a", "held for player") })), true, "a resume while held plays")
eq(reader.timer_started(view({ ante("a", "held for player") }), view({ ante("a", "held for player") })), false, "a held timer plays once")
eq(reader.timer_started(none, view({ { kind = "personal", by = nil, against = { "a" }, endsAt = 1, hold = "counting" } })), false, "a personal countdown is not a timer start")
eq(reader.timer_started(nil, view({ ante("a", "counting") })), false, "the first view after a join is silent")

-- One timer split in parts (a Ready target's frozen share) reads as one: the most running part.
local function share(by, against, hold)
	return { kind = "ante", by = by, against = { against }, endsAt = 100000, pausedAt = hold ~= "counting" and 80000 or nil, hold = hold }
end
local split = view({ share("a", "c", "counting"), share("a", "b", "paused for ready") })
eq(reader.timer_started(split, split), false, "a split timer plays once")
eq(reader.timer_started(view({ share("a", "b", "paused for ready"), share("a", "c", "counting") }), split), false, "the part order does not matter")
eq(reader.timer_started(view({ share("a", "c", "counting") }), split), false, "a part freezing is silent")
eq(reader.timer_started(split, view({ share("a", "c", "counting"), share("a", "b", "counting") })), false, "a part thawing is silent")
eq(reader.timer_started(view({ share("a", "c", "paused by starter"), share("a", "b", "paused for ready") }), split), true, "the starter's restart plays while a part is frozen")
eq(reader.timer_started(split, view({ share("a", "c", "paused by starter"), share("a", "b", "paused for ready") })), false, "the starter's pause is silent")

-- Timer SFX: 1 On, 2 Once per Ante, 3 Off.
eq(reader.start_sound_plays(1, 2, 2), true, "On plays every start")
eq(reader.start_sound_plays(2, 2, 1), true, "Once per Ante plays the first start of an ante")
eq(reader.start_sound_plays(2, 2, 2), false, "Once per Ante stays quiet the rest of the ante")
eq(reader.start_sound_plays(3, 2, 1), false, "Off never plays")

print("timer_start_sound_test: " .. checks .. " checks passed")
