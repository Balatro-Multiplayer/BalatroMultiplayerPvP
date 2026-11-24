-- Run from the repo root: luajit tests/unit/lobby_options_keys_test.lua
-- Every option the Lobby Options screen writes, and every key a private lobby publishes, is a key of
-- the lobby config in core.lua. Read from the source text: neither file loads without the game.
local function read(path)
	local file = assert(io.open(path, "rb"))
	local text = file:read("*a")
	file:close()
	return (text:gsub("\r", ""))
end

local failures = 0
local function check(ok, message)
	if not ok then
		failures = failures + 1
		print("FAIL " .. message)
	end
end

local core = read("core.lua")
local block = core:match("function PVP%.LOBBY%.reset_config.-\n\tPVP%.LOBBY%.config = {(.-)\n\t}\nend")
assert(block, "reset_config block not found")
local defaults = {}
for key in block:gmatch("\n\t\t([%a_][%w_]*) =") do defaults[key] = true end
assert(defaults.starting_lives and defaults.timer, "the defaults were not read")

local options = read("ui/lobby/lobby_options.lua")
local written = {}
for key in options:gmatch('toggle_row%("[%w_]+", "[%w_]+", "([%w_]+)"') do written[key] = "toggle_row" end
for key in options:gmatch('number_row%("([%w_]+)"') do written[key] = "number_row" end
for key in options:gmatch("\n\t([%a_][%w_]*) = { values") do written[key] = "NUMBER_OPTIONS" end
assert(written.starting_lives and written.trap_cards, "the option rows were not read")
for key, where in pairs(written) do
	check(defaults[key], where .. " writes " .. key .. ", which is not a config key in core.lua")
end

local flow = read("pvp_api/flow.lua")
local list = flow:match("PVP%.LOBBY%.PRIVATE_OPTION_KEYS = {(.-)}")
assert(list, "PRIVATE_OPTION_KEYS not found")
for key in list:gmatch('"([%w_]+)"') do
	check(defaults[key], "PRIVATE_OPTION_KEYS lists " .. key .. ", which is not a config key in core.lua")
end

if failures > 0 then os.exit(1) end
print("ok   lobby option keys")
