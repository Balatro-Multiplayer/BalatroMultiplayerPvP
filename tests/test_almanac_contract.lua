-- Cross-repository contract: SERVER_DIR must name this thread's Server checkout.
-- Standalone source/data check, not a live server test.
local server = assert(os.getenv("SERVER_DIR"), "Set SERVER_DIR to the BalatroMultiplayerServer checkout")
PVP = {}
dofile("lib/almanac/draft.lua")
dofile("lib/almanac/shared_rules.lua")
local checks = 0
local function mirror(path, name, client, field)
	local file = assert(io.open(server .. "/" .. path, "r"))
	local source = file:read("*a")
	file:close()
	local block = assert(source:match("export const " .. name .. ".-\n}"), "Missing server catalogue " .. name)
	local gates = {}
	for key, ante in block:gmatch("([%w_]+):%s*(%d+)") do
		gates[key] = tonumber(ante)
	end
	for key, definition in pairs(client) do
		assert(gates[key] == definition[field], "Server/client gate mismatch: " .. key)
		gates[key] = nil
		checks = checks + 1
	end
	assert(next(gates) == nil, "Server has entries absent from the client")
	checks = checks + 1
end
mirror("nakama/src/lobby/almanac.ts", "DECK_ANTES", PVP.ALMANAC_DRAFT.definitions, "min_ante")
mirror("nakama/src/lobby/shared_rules.ts", "RULE_ANTES", PVP.SHARED_RULES.definitions, "ante")
print("Almanac cross-repository contract: " .. checks .. " checks passed")
