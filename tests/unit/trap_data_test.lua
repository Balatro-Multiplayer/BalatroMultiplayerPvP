-- Run from the repo root: luajit tests/unit/trap_data_test.lua
-- pvp_api/_trap_data.lua: the fire data names are main's, the sender builds exactly what the handler reads,
-- and a record the server would refuse is never built.
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

local function show(value)
	if type(value) ~= "table" then return tostring(value) end
	local keys = {}
	for key in pairs(value) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local parts = {}
	for _, key in ipairs(keys) do parts[#parts + 1] = tostring(key) .. "=" .. show(value[key]) end
	return "{" .. table.concat(parts, ",") .. "}"
end
local function same(actual, expected, message) eq(show(actual), show(expected), message) end

PVP = {}
dofile("pvp_api/_view.lua")
dofile("pvp_api/_trap_data.lua")
dofile("pvp_api/inbox_handlers.lua")
local data, inbox = PVP.trap_data, PVP.inbox_handlers
-- The game: every call is recorded by name.
local made
PVP.inbox_game = setmetatable({}, { __index = function(_, name) return function() made[#made + 1] = name end end })

-- What each trap sends, with the names main used, and the game call its owner's handler makes from it.
local rows = {
	{ "c_mp_trap_glyph_of_warding", {}, "add_tag" },
	{ "c_mp_trap_symbol", {}, nil },
	{ "c_mp_trap_alarm", { rerolls = 2 }, "add_free_rerolls" },
	{ "c_mp_trap_explosive_runes", {}, nil },
	{ "c_mp_trap_sepia_snake_sigil", { key = "j_blueprint" }, "add_joker" },
	{ "c_mp_trap_fire_trap", {}, nil },
	{ "c_mp_trap_guards_and_wards", {}, nil },
	{ "c_mp_trap_magic_mouth", { card = "H4sIAAAAAAAA" }, "add_stolen_card" },
	{ "c_mp_trap_snare", { tag_key = "tag_double", orbital_hand = "Pair" }, "add_tag" },
	{ "c_mp_trap_arcane_lock", {}, nil },
	{ "c_mp_trap_programmed_illusion", {}, nil },
	{ "c_mp_trap_web", { key = "c_pluto", set = "Planet" }, "add_consumable" },
	{ "c_mp_trap_forbiddance", {}, nil },
	{ "c_mp_trap_faithful_hound", { hand_type = "Flush" }, "level_up_hand" },
	{ "c_mp_trap_phase_door", { dollars = 12 }, "add_money" },
	{ "c_mp_trap_mental_prison", {}, "add_wheels" },
}

for _, row in ipairs(rows) do
	local key, values, call = row[1], row[2], row[3]
	local sent_values = { owner = "a" }
	for name, value in pairs(values) do sent_values[name] = value end
	local record, problem = data.build(key, sent_values)
	eq(problem, nil, key .. " builds")
	same(record, sent_values, key .. " sends exactly the fields it was given")
	-- The handler reads what the sender built.
	made = {}
	local ok, why = pcall(inbox.effects.trapReward, { effect = "trapReward", trap = { id = 1, key = key, data = record } })
	eq(why, nil, key .. " handler accepts the sender's record")
	eq(ok, true, key .. " handler runs")
	eq(made[#made], "show_trap_fired", key .. " shows the trap")
	eq(made[1] ~= "show_trap_fired" and made[1] or nil, call, key .. " handler call")
end

-- Every trap card the mod has has a table row.
local count = 0
for _ in pairs(data.FIELDS) do count = count + 1 end
eq(count, #rows, "one row per trap")

-- The names are main's, exactly.
local function names(key)
	local out = {}
	for name in pairs(data.FIELDS[key]) do out[#out + 1] = name end
	table.sort(out)
	return table.concat(out, ",")
end
eq(names("c_mp_trap_snare"), "orbital_hand,owner,tag_key", "snare fields")
eq(names("c_mp_trap_sepia_snake_sigil"), "key,owner", "sepia fields")
eq(names("c_mp_trap_magic_mouth"), "card,owner", "magic mouth fields")
eq(names("c_mp_trap_web"), "key,owner,set", "web fields")
eq(names("c_mp_trap_faithful_hound"), "hand_type,owner", "hound fields")
eq(names("c_mp_trap_phase_door"), "dollars,owner", "phase door fields")
eq(names("c_mp_trap_alarm"), "owner,rerolls", "alarm fields")

-- Not built: an unknown trap, a missing field, a wrong kind, a fraction, a field of another trap.
local refused = {
	{ "unknown trap", "c_mp_trap_nothing", { owner = "a" } },
	{ "not a table", "c_mp_trap_symbol", "x" },
	{ "no owner", "c_mp_trap_symbol", {} },
	{ "alarm without rerolls", "c_mp_trap_alarm", { owner = "a" } },
	{ "alarm text rerolls", "c_mp_trap_alarm", { owner = "a", rerolls = "2" } },
	{ "alarm fraction", "c_mp_trap_alarm", { owner = "a", rerolls = 1.5 } },
	{ "phase door zero", "c_mp_trap_phase_door", { owner = "a", dollars = 0 } },
	{ "sepia empty key", "c_mp_trap_sepia_snake_sigil", { owner = "a", key = "" } },
	{ "web without set", "c_mp_trap_web", { owner = "a", key = "c_pluto" } },
	{ "snare bad orbital", "c_mp_trap_snare", { owner = "a", orbital_hand = 2 } },
}
for _, row in ipairs(refused) do
	local record, problem = data.build(row[2], row[3])
	eq(record, nil, row[1] .. " not built")
	eq(type(problem), "string", row[1] .. " says why")
end

-- The snare may name no tag (a skip with no tag): the record is just the owner.
same(data.build("c_mp_trap_snare", { owner = "a" }), { owner = "a" }, "snare with no tag")

-- A field of another trap is dropped, not sent.
same(data.build("c_mp_trap_symbol", { owner = "a", dollars = 4 }), { owner = "a" }, "extra field dropped")

-- The server's size cap (1024 bytes of JSON): a real Magic Mouth card is about 540 characters and fits;
-- a card over the cap is refused, never cut.
local small = string.rep("x", 540)
eq(data.build("c_mp_trap_magic_mouth", { owner = "a", card = small }) ~= nil, true, "a real card fits")
local record, problem = data.build("c_mp_trap_magic_mouth", { owner = "a", card = string.rep("x", 1100) })
eq(record, nil, "a card over the cap is refused")
eq(problem:find("1024", 1, true) ~= nil, true, "the refusal names the cap")
-- Quotes count double, as the server counts the encoded text.
eq(data.build("c_mp_trap_magic_mouth", { owner = "a", card = string.rep('"', 600) }), nil, "escapes count")

-- The cap to the byte. The JSON text is written out here, so the size is counted by the test, not by
-- the code under test: a string value and two keys, then four keys with a number among them.
local function card_with_size(size)
	local overhead = #'{"card":"","owner":"a"}'
	return string.rep("x", size - overhead)
end
for _, case in ipairs({ { 1024, true }, { 1025, false }, { 1023, true } }) do
	local size, fits = case[1], case[2]
	local card = card_with_size(size)
	eq(#('{"card":"' .. card .. '","owner":"a"}'), size, "the test's JSON text is " .. size .. " bytes")
	eq(data.build("c_mp_trap_magic_mouth", { owner = "a", card = card }) ~= nil, fits, size .. " bytes, a string value and two keys")
end
local function web_with_size(size)
	local overhead = #'{"key":"","owner":"a","set":"s"}'
	return string.rep("k", size - overhead)
end
for _, case in ipairs({ { 1024, true }, { 1025, false } }) do
	local key = web_with_size(case[1])
	eq(#('{"key":"' .. key .. '","owner":"a","set":"s"}'), case[1], "the web's JSON text is " .. case[1] .. " bytes")
	eq(data.build("c_mp_trap_web", { owner = "a", key = key, set = "s" }) ~= nil, case[2], case[1] .. " bytes, three keys")
end
-- A number is its digits, with no quotes.
local number_only = data.build("c_mp_trap_phase_door", { owner = "a", dollars = 12 })
eq(number_only.dollars, 12, "a number is counted as digits")
local snare_text = string.rep("t", 1024 - #'{"orbital_hand":"","owner":"a","tag_key":"x"}')
eq(data.build("c_mp_trap_snare", { owner = "a", tag_key = "x", orbital_hand = snare_text }) ~= nil, true, "two keys and an optional one, 1024 bytes")
eq(data.build("c_mp_trap_snare", { owner = "a", tag_key = "x", orbital_hand = snare_text .. "t" }), nil, "and 1025 bytes")

-- A whole number of 16 digits counts as all its digits (tostring would write 9.007199254741e+15).
local digits_owner = string.rep("o", 1024 - #'{"dollars":9007199254740991,"owner":""}')
eq(data.build("c_mp_trap_phase_door", { owner = digits_owner, dollars = 2 ^ 53 - 1 }) ~= nil, true, "a 16-digit number at 1024 bytes")
eq(data.build("c_mp_trap_phase_door", { owner = digits_owner .. "o", dollars = 2 ^ 53 - 1 }), nil, "and one byte more is refused")

-- What the owner receives: the trap's own fields, and no owner needed. An empty record (the server's
-- Arcane Lock bounce, which reaches Lua as an empty table either way) is fine for a trap with no fields.
same(data.received("c_mp_trap_arcane_lock", {}), {}, "an empty record is received for the lock")
same(data.received("c_mp_trap_alarm", { rerolls = 3 }), { rerolls = 3 }, "no owner needed")
same(data.received("c_mp_trap_alarm", { rerolls = 3, owner = "a" }), { rerolls = 3 }, "an owner is not kept")
eq(data.received("c_mp_trap_alarm", {}), nil, "a field of the trap itself is still needed")
eq(data.received("c_mp_trap_alarm", "x"), nil, "a record that is not a table is refused")
eq(data.received("c_mp_trap_nothing", {}), nil, "an unknown trap is refused")
eq(data.checked("c_mp_trap_arcane_lock", {}), nil, "the sender still names the owner")

-- Whole numbers are sent as they are; the server owns the upper limit.
local most = 2 ^ 53 - 1
eq(data.build("c_mp_trap_phase_door", { owner = "a", dollars = most }).dollars, most, "a big whole number is sent")
eq(data.build("c_mp_trap_phase_door", { owner = "a", dollars = 1.5 }), nil, "a fraction is refused")

print("trap_data_test: ok (" .. checks .. " checks)")
