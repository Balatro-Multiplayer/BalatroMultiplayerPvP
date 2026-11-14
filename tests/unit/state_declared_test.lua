--[[
  State declared guard.

  Every PVP.CLIENT, PVP.LOBBY and PVP.GAME field the mod reads or writes must be
  declared in state.lua, even when it starts out nil, so state.lua stays the
  one place to see what each lives for. This test fails on a field used in a
  .lua file or a lovely patch that state.lua doesn't declare.

  Run from the repo root:
    luajit tests/unit/state_declared_test.lua
]]

-- Tables whose own fields are checked too. Others (host, guest, round_sync, ...)
-- are checked only by name.
local NESTED = {
	["LOBBY.config"] = true,
	["LOBBY.deck"] = true,
	["GAME.enemy"] = true,
	["GAME.stats"] = true,
}
local ROOTS = {
	["PVP.CLIENT = {"] = "CLIENT",
	["PVP.LOBBY = {"] = "LOBBY",
	["PVP.LOBBY.config = {"] = "LOBBY.config",
	["PVP.GAME = {"] = "GAME",
}

local function count(s, ch)
	return select(2, s:gsub("%" .. ch, ""))
end

-- Paths ("GAME.enemy.score") of every field state.lua declares.
local declared = {}
local stack = {}
for line in io.lines("state.lua") do
	local code = line:gsub("%-%-.*$", "")
	local root = code:match("^%s*(PVP%.[%w_.]+ = {)")
	if root and ROOTS[root] and #stack == 0 then
		if count(code, "{") > count(code, "}") then stack = { ROOTS[root] } end
	elseif #stack > 0 then
		local name = code:match("^%s*([%a_][%w_]*) =")
		if name then declared[stack[#stack] .. "." .. name] = true end
		local opens, closes = count(code, "{"), count(code, "}")
		if name and opens > closes then
			stack[#stack + 1] = stack[#stack] .. "." .. name
		else
			for _ = 1, closes - opens do
				stack[#stack] = nil
			end
		end
	end
end

local offenders = {}
local handle = io.popen("find . \\( -name '*.lua' -o -name '*.toml' \\) -not -path './.git/*' -not -path './tests/*'")
for path in handle:lines() do
	local n = 0
	for line in io.lines(path) do
		n = n + 1
		for root, rest in line:gmatch("PVP%.(%u+)%.([%a_][%w_.]*)") do
			if root == "CLIENT" or root == "LOBBY" or root == "GAME" then
				local chain = root .. "." .. rest
				local top = chain:match("^[%u]+%.[%w_]+")
				local nested = chain:match("^[%u]+%.[%w_]+%.[%w_]+")
				local field = (nested and NESTED[top]) and nested or top
				if not declared[field] then offenders[#offenders + 1] = path .. ":" .. n .. " " .. field end
			end
		end
	end
end
handle:close()

local seen, unique = {}, {}
for _, o in ipairs(offenders) do
	if not seen[o] then
		seen[o] = true
		unique[#unique + 1] = o
	end
end

if #unique > 0 then
	print("FAIL: fields used but not declared in state.lua:")
	for _, o in ipairs(unique) do
		print("  " .. o)
	end
	os.exit(1)
end
print("ok   every CLIENT, LOBBY and GAME field is declared in state.lua")
