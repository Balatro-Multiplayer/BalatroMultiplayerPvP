-- Plain Lua test for objects/jokers/standard/reserved_parking.lua: a held face card rolls for $1 on every trigger,
-- and a miss does not cancel its retriggers (Mime, Red Seal).
-- Run from the repo root: luajit tests/unit/reserved_parking_test.lua
local def
local rolls = {}
local roll_result = true
SMODS = {
	Joker = function(d) def = d end,
	pseudorandom_probability = function(trigger_obj, seed, numerator, denominator)
		rolls[#rolls + 1] = { seed = seed, numerator = numerator, denominator = denominator }
		return roll_result
	end,
	get_probability_vars = function(_, numerator, denominator) return numerator, denominator end,
}
G = {
	hand = {},
	play = {},
	GAME = {},
	C = { RED = "red" },
	E_MANAGER = { add_event = function() end },
}
Event = function(e) return e end
localize = function(key) return key end

assert(loadfile("objects/jokers/standard/reserved_parking.lua"))()

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local card = { ability = { extra = { odds = 2, dollars = 1 } } }
local function face(extra)
	local c = { debuff = false, is_face = function() return true end }
	for k, v in pairs(extra or {}) do c[k] = v end
	return c
end
local function held(other)
	return { individual = true, cardarea = G.hand, other_card = other }
end
local function run(context)
	rolls = {}
	G.GAME.dollar_buffer = nil
	return def.calculate(def, card, context), #rolls
end

check("same rarity as vanilla", def.rarity, 1)
check("same cost as vanilla", def.cost, 6)
check("same art as vanilla", def.pos.x .. "," .. def.pos.y, "6,13")
check("blueprint compatible", def.blueprint_compat, true)
check("balanced sticker flag", def.config.mp_balanced, true)

local ret, n = run(held(face()))
check("held face card first pass rolls once", n, 1)
check("held face card first pass pays $1", ret and ret.dollars, 1)
check("a hit wiggles the joker like vanilla", ret and ret.card, card)
check("a hit has no extra func, like vanilla", ret and ret.func, nil)
check("tooltip uses the game's own text", def.loc_vars(def, {}, card).key, "j_reserved_parking")
check("tooltip vars are dollars, numerator, denominator", table.concat(def.loc_vars(def, {}, card).vars, ","), "1,1,2")
check("rolls under the vanilla probability key", rolls[1].seed, "parking")
check("rolls 1 in 2", rolls[1].numerator .. "/" .. rolls[1].denominator, "1/2")

roll_result = false
ret, n = run(held(face()))
check("failed roll pays nothing", ret and ret.dollars, nil)
check("failed roll shows nothing", ret and ret.message, nil)
check("failed roll still counts as a trigger", ret ~= nil and type(ret.func), "function")
check("failed roll does not wiggle the cards", ret and ret.no_juice, true)
roll_result = true

-- SMODS.score_card's gate for a held card: its retriggers are only collected, and the next one only runs, when the
-- pass before returned an effect. Each pass's roll comes from `results` in order.
local function score_held(retriggers, results)
	local i, total_rolls, paid = 0, 0, 0
	local reps = 1
	local j = 1
	while j <= reps do
		i = i + 1
		roll_result = results[i]
		local r, rolled = run(held(face({ repetition_trigger = j > 1 and j - 1 })))
		total_rolls = total_rolls + rolled
		if r and r.dollars then paid = paid + r.dollars end
		if j == 1 and r then reps = 1 + retriggers end
		j = j + (r and 1 or reps)
	end
	roll_result = true
	return total_rolls, paid
end

n, ret = score_held(1, { false, true })
check("Mime after a miss still rolls again", n, 2)
check("Mime after a miss can still pay", ret, 1)
n, ret = score_held(1, { true, true })
check("Mime after a hit rolls again", n, 2)
check("Mime after a hit can pay twice", ret, 2)
n = score_held(2, { true, false, true })
check("a miss on a retrigger does not stop the next one", n, 3)

ret, n = run(held({ is_face = function() return false end }))
check("held non-face card does not roll", n, 0)
check("held non-face card pays nothing", ret, nil)

ret, n = run({ individual = true, cardarea = G.play, other_card = face() })
check("played face card does not roll", n, 0)
check("played face card pays nothing", ret, nil)

ret, n = run({ individual = true, cardarea = G.hand, end_of_round = true, other_card = face() })
check("end of round does not roll", n, 0)

ret = run(held(face({ debuff = true })))
check("debuffed held face card shows debuffed", ret and ret.message, "k_debuffed")
check("debuffed held face card pays nothing", ret and ret.dollars, nil)

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("all passed")
