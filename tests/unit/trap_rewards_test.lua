-- Plain Lua test for the owner's reward handlers registered in objects/consumables/traps.lua
-- (PVP.TRAP.REWARDS): one passing row and, for every key that checks the fired data against the game's tables,
-- one failing row that returns false and changes nothing. Also pins the request body each key sends, through
-- the real json encoder of the API (a Lua {} is written as []): keys with no data send no `data` field, the
-- others send an object.
-- Run from the repo root: luajit tests/unit/trap_rewards_test.lua
-- The encoder is read from MPAPI_JSON (default D:/mp/api/lib/nakama/util/json.lua).
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

local fx, defs

local function setup()
	fx, defs = {}, {}
	PVP = {
		COLOURS = { BLACK = {}, DARK_PINK = {} },
		UI = {
			show_trap_fired_animation = function(name)
				fx[#fx + 1] = "anim:" .. name
			end,
		},
		TRAP = {
			REWARDS = {},
			fire_once = function(f)
				return f
			end,
			plant = function() end,
			grant_free_rerolls = function(n)
				fx[#fx + 1] = "rerolls:" .. tostring(n)
			end,
		},
	}
	MPAPI = {
		Consumable = function(def)
			defs[#defs + 1] = def
		end,
	}
	SMODS = {
		ConsumableType = function() end,
		Atlas = function() end,
		ConsumableTypes = { Tarot = {}, Planet = {}, Spectral = {}, Trap = {} },
		add_card = function(args)
			fx[#fx + 1] = "add:" .. args.key .. ":" .. tostring(args.set) .. ":" .. tostring(args.edition)
		end,
	}
	G = {
		P_CENTERS = {
			j_rare = { set = "Joker", rarity = 3 },
			j_rare_name = { set = "Joker", rarity = "Rare" },
			j_common = { set = "Joker", rarity = 1 },
			c_fool = { set = "Tarot" },
			c_pluto = { set = "Planet" },
			c_trance = { set = "Spectral" },
			c_mp_trap_web = { set = "Trap" },
		},
		P_TAGS = { tag_economy = {}, tag_orbital = {} },
		GAME = { hands = { Pair = {}, Flush = {} }, joker_buffer = 0, consumeable_buffer = 0 },
		jokers = { cards = {}, config = { card_limit = 5 } },
		consumeables = { cards = {}, config = { card_limit = 2 }, T = { x = 0, y = 0 } },
		E_MANAGER = { add_event = function() end },
		CARD_W = 1,
		CARD_H = 1,
	}
	Tag = function(key)
		return {
			key = key,
			apply_to_run = function()
				fx[#fx + 1] = "apply:" .. key
			end,
		}
	end
	add_tag = function(tag)
		fx[#fx + 1] = "tag:" .. tag.key
	end
	level_up_hand = function(_, hand, _, amount)
		fx[#fx + 1] = "level:" .. hand .. ":" .. tostring(amount)
	end
	ease_dollars = function(n)
		fx[#fx + 1] = "dollars:" .. tostring(n)
	end
	Event = function(args)
		return args
	end
	Card = function()
		return {}
	end
	dofile("objects/consumables/traps.lua")
end

-- key, pass data, the effect it must have, fail data (nil: the key checks nothing).
local ROWS = {
	{ "trap_glyph_of_warding", nil, "tag:tag_mp_ward" },
	{ "trap_symbol", nil, "anim:Symbol" },
	{ "trap_alarm", nil, "rerolls:2" },
	{ "trap_explosive_runes", nil, "anim:Explosive Runes" },
	{ "trap_sepia_snake_sigil", { key = "j_rare" }, "add:j_rare:Joker:nil", { key = "j_common" } },
	{ "trap_fire_trap", nil, "anim:Fire Trap" },
	{ "trap_guards_and_wards", nil, "anim:Guards and Wards" },
	{ "trap_magic_mouth", { key = "c_fool" }, "add:c_fool:Tarot:nil", { key = "c_trance" } },
	{ "trap_snare", { tag_key = "tag_economy" }, "apply:tag_economy", { tag_key = "tag_nope" } },
	{ "trap_arcane_lock", nil, "anim:Arcane Lock" },
	{ "trap_programmed_illusion", nil, "anim:Programmed Illusion" },
	{ "trap_web", { key = "c_pluto", set = "Planet" }, "add:c_pluto:Planet:e_negative", { key = "c_pluto", set = "Tarot" } },
	{ "trap_forbiddance", nil, "anim:Forbiddance" },
	{ "trap_faithful_hound", { hand_type = "Pair" }, "level:Pair:3", { hand_type = "Nope" } },
	{ "trap_phase_door", { golds = 2 }, "dollars:8", { golds = 0 } },
	{ "trap_mental_prison", nil, "anim:Mental Prison" },
}

local function contains(want)
	for _, entry in ipairs(fx) do
		if entry == want then return true end
	end
	return false
end

test("every trap key has a reward handler and every row names a registered key", function()
	setup()
	for _, row in ipairs(ROWS) do
		assert(PVP.TRAP.REWARDS["c_mp_" .. row[1]], "no reward for " .. row[1])
	end
	local n = 0
	for _ in pairs(PVP.TRAP.REWARDS) do
		n = n + 1
	end
	equal(n, #ROWS, "registered rewards")
	equal(#defs, #ROWS, "defined cards")
end)

for _, row in ipairs(ROWS) do
	local key, pass, effect, fail = row[1], row[2], row[3], row[4]
	test(key .. ": the pass row pays", function()
		setup()
		local result = PVP.TRAP.REWARDS["c_mp_" .. key](pass or {})
		equal(result, nil, "result")
		assert(contains(effect), "missing effect " .. effect .. ", got " .. table.concat(fx, ","))
	end)
	if fail then
		test(key .. ": a failed membership check returns false and pays nothing", function()
			setup()
			local result, reason = PVP.TRAP.REWARDS["c_mp_" .. key](fail)
			equal(result, false)
			assert(type(reason) == "string" and #reason > 0, "a reason")
			equal(#fx, 0, "effects " .. table.concat(fx, ","))
		end)
	end
end

test("rewards: Snare's Orbital copy needs a known poker hand", function()
	setup()
	local result = PVP.TRAP.REWARDS.c_mp_trap_snare({ tag_key = "tag_orbital", orbital_hand = "Nope" })
	equal(result, false)
	equal(#fx, 0)
	result = PVP.TRAP.REWARDS.c_mp_trap_snare({ tag_key = "tag_orbital", orbital_hand = "Flush" })
	equal(result, nil)
end)

test("rewards: Sepia accepts a Rare named by its rarity word, and Web refuses the Trap set", function()
	setup()
	equal(PVP.TRAP.REWARDS.c_mp_trap_sepia_snake_sigil({ key = "j_rare_name" }), nil)
	local result = PVP.TRAP.REWARDS.c_mp_trap_web({ key = "c_mp_trap_web", set = "Trap" })
	equal(result, false)
end)

-- The request bodies.
local json_path = os.getenv("MPAPI_JSON") or "D:/mp/api/lib/nakama/util/json.lua"
local json = dofile(json_path)

-- What each key's calculate sends as data (nil: none), as the fire call sites build it.
local SENT = {
	trap_glyph_of_warding = nil,
	trap_symbol = nil,
	trap_alarm = nil,
	trap_explosive_runes = nil,
	trap_sepia_snake_sigil = { key = "j_rare" },
	trap_fire_trap = nil,
	trap_guards_and_wards = nil,
	trap_magic_mouth = { key = "c_fool" },
	trap_snare = { tag_key = "tag_economy" },
	trap_programmed_illusion = nil,
	trap_web = { key = "c_pluto", set = "Planet" },
	trap_forbiddance = nil,
	trap_faithful_hound = { hand_type = "Pair" },
	trap_phase_door = { golds = 2 },
	trap_mental_prison = nil,
}

for key, data in pairs(SENT) do
	test(key .. ": the fire body encodes " .. (data and "data as an object" or "with no data field"), function()
		local body = json.encode({ runId = "r", trapId = 1, data = data })
		if data then
			assert(body:find('"data":{', 1, true), body)
		else
			assert(not body:find('"data"', 1, true), body)
		end
	end)
end

test("the encoder writes an empty table as an array, which is why a no-data key sends none", function()
	local body = json.encode({ runId = "r", trapId = 1, data = {} })
	assert(body:find('"data":[]', 1, true), body)
end)

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
