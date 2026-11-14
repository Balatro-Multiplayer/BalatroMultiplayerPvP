-- Run from the repo root: luajit tests/unit/tournament_buttons_test.lua
-- Every button the tournament code draws (TUI.button(label, "mp_pvp_...", ...))
-- has its G.FUNCS handler in the tournament code, or is only drawn when the
-- handler exists (if G.FUNCS.<name> then), so a click never calls nil.

local FILES = {
	"pvp_api/tournament/net.lua",
	"pvp_api/tournament/play.lua",
	"ui/tournament/banner.lua",
	"ui/tournament/common.lua",
	"ui/tournament/screen.lua",
}

local failures = 0
local defined, used = {}, {}
for _, path in ipairs(FILES) do
	local f = assert(io.open(path, "r"))
	local src = f:read("*a")
	f:close()
	for name in src:gmatch("G%.FUNCS%.([%w_]+)%s*=") do
		defined[name] = true
	end
	for name in src:gmatch("if G%.FUNCS%.([%w_]+) then") do
		defined[name] = true
	end
	for name in src:gmatch('TUI%.button%([^,]+,%s*"([%w_]+)"') do
		used[#used + 1] = { name = name, path = path }
	end
end
for _, u in ipairs(used) do
	if not defined[u.name] then
		failures = failures + 1
		print("FAIL no G.FUNCS." .. u.name .. " (drawn in " .. u.path .. ")")
	end
end
if #used < 4 then
	failures = failures + 1
	print("FAIL found only " .. #used .. " buttons")
end

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("tournament_buttons_test: all passed")
