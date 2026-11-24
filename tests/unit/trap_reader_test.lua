-- Run from the repo root: luajit tests/unit/trap_reader_test.lua
-- pvp_api/trap_reader.lua: each trap input body (the server's: nakama/src/lobby/pvp/parts/traps.ts), what
-- the view says of my traps, and what my cards and the Nemesis row must do to match it.
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
dofile("pvp_api/trap_reader.lua")
local reader = PVP.trap_reader

-- plant
same(reader.plant("c_mp_trap_alarm", 1), { key = "c_mp_trap_alarm", total = 1 }, "plant body")
eq(reader.plant("c_mp_trap_alarm", 0), nil, "plant total 0")
eq(reader.plant("c_mp_trap_alarm", 1.5), nil, "plant fraction")
eq(reader.plant("c_fool", 1), nil, "plant of a card that is not a mod card")
eq(reader.plant("", 1), nil, "plant with no key")
eq(reader.plant(nil, 1), nil, "plant with a nil key")

-- fire
same(reader.fire(3, "c_mp_trap_phase_door", { owner = "a", dollars = 8 }), { trapId = 3, data = { owner = "a", dollars = 8 } }, "fire body")
local body, problem = reader.fire(nil, "c_mp_trap_symbol", { owner = "a" })
eq(body, nil, "fire with no trap number")
eq(type(problem), "string", "fire with no trap number says why")
eq(reader.fire(0, "c_mp_trap_symbol", { owner = "a" }), nil, "fire trap 0")
eq(reader.fire(1, "c_mp_trap_phase_door", { owner = "a" }), nil, "fire with a field missing")

-- lost
same(reader.lost(4), { trapId = 4 }, "lost body")
eq(reader.lost(nil), nil, "lost with no number")
eq(reader.lost(-1), nil, "lost negative")

-- the view's traps
local function entry(id, owner, holder, state, key) return { id = id, key = key or "c_mp_trap_alarm", owner = owner, holder = holder, state = state } end
eq(reader.traps(nil), nil, "no view")
eq(reader.traps({ onlyMine = {} }), nil, "no list in the view")
same(reader.traps({ onlyMine = { traps = {} } }), {}, "an empty list is a list")
same(
	reader.traps({ onlyMine = { traps = { entry(1, "a", "b", "live"), { id = 2, key = "c_mp_trap_alarm", owner = "a", holder = "b" }, entry(3, "a", "b", "gone") } } }),
	{ entry(1, "a", "b", "live") },
	"a trap that is not whole in the view is left out"
)

-- my cards against the traps I hold
local function never() return false end
local traps = { entry(1, "b", "a", "live"), entry(2, "b", "a", "fired"), entry(3, "a", "b", "live"), entry(4, "b", "a", "lost") }
local work = reader.reconcile(traps, "a", {}, never)
same(work.add, { traps[1] }, "a held live trap with no card is added; fired, lost and other holders are not")
same(work.reveal, {}, "nothing to reveal with no card")
work = reader.reconcile(traps, "a", { { id = 1, fired = false }, { id = 2, fired = false } }, never)
same(work.add, {}, "a card there is not added again")
same(work.reveal, { 2 }, "a card the server says has gone off is revealed")
work = reader.reconcile(traps, "a", { { id = 2, fired = true } }, never)
same(work.reveal, {}, "a card already revealed is not revealed again")
work = reader.reconcile(traps, "a", {}, function(id) return id == 1 end)
same(work.add, {}, "a trap that has gone off here is not dealt again after a load")

-- the Nemesis row
local mine = { entry(1, "a", "b", "live"), entry(2, "a", "c", "live"), entry(3, "a", "b", "fired"), entry(4, "z", "b", "live"), entry(5, "a", "b", "lost") }
local row = reader.row(mine, "a", { "b" })
same(row.shown, { mine[1] }, "the live traps I planted that the Nemesis holds")
same(row.fired, { [3] = true }, "the ones that went off")
same(reader.row(mine, "a", {}).shown, {}, "no Nemesis, nothing shown")
same(reader.row(nil, "a", { "b" }).shown, {}, "no list, nothing shown")

-- the signature changes with the holder and the state
local before = reader.signature({ entry(1, "a", "b", "live") })
eq(before ~= reader.signature({ entry(1, "a", "c", "live") }), true, "a new holder changes it")
eq(before ~= reader.signature({ entry(1, "a", "b", "fired") }), true, "a new state changes it")
eq(before ~= reader.signature({ entry(1, "a", "b", "live"), entry(2, "a", "b", "live") }), true, "a new trap changes it")
eq(before, reader.signature({ entry(1, "a", "b", "live") }), "the same list gives the same signature")

print("trap_reader_test: ok (" .. checks .. " checks)")
