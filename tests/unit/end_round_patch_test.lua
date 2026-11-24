-- Run from the repo root: luajit tests/unit/end_round_patch_test.lua
-- lovely/end_round.toml sets the flag that PVP.handle_duplicate_end (ui/game/game_state.lua) reads,
-- and the flag is reset where every other PvP blind flag is.
local function read(path)
	local f = assert(io.open(path, "r"))
	local text = f:read("*a")
	f:close()
	return text
end

local patch = read("lovely/end_round.toml")
local set = patch:match("PVP%.GAME%.([%w_]+) = true")
assert(set, "end_round.toml sets no PVP.GAME flag")

local guard = read("ui/game/game_state.lua")
local read_flag = guard:match("function PVP%.handle_duplicate_end%(%).-if PVP%.GAME%.([%w_]+) then")
assert(read_flag, "handle_duplicate_end reads no PVP.GAME flag")

if set ~= read_flag then
	error(string.format("end_round.toml sets PVP.GAME.%s but handle_duplicate_end reads PVP.GAME.%s", set, read_flag))
end
assert(read("core.lua"):find(set .. " = false", 1, true), "core.lua does not start " .. set .. " false")
assert(read("networking/action_handlers.lua"):find("PVP.GAME." .. set .. " = false", 1, true), "action_handlers does not reset " .. set)

print("end_round_patch_test: ok (4 checks)")
