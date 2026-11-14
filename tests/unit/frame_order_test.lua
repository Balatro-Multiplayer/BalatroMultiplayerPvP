-- Run from the repo root: luajit tests/unit/frame_order_test.lua
-- pvp_api/frame.lua is the one per-frame hook of the nets: the game's own update first, then each
-- net's update() in PVP.FRAME_ORDER. The order is pinned here (see the comment in frame.lua for why).
local passed, failed = 0, 0
local function check(name, got, want)
	if got == want then
		passed = passed + 1
		print("ok   " .. name)
	else
		failed = failed + 1
		print(("FAIL %s: got %s, wanted %s"):format(name, tostring(got), tostring(want)))
	end
end

local calls = {}
PVP = {}
Game = {
	update = function()
		calls[#calls + 1] = "game"
	end,
}
dofile("pvp_api/frame.lua")

check(
	"the declared frame order",
	table.concat(PVP.FRAME_ORDER, ","),
	"LivesNet,ReadyNet,ResultNet,RoundEndNet,TimerNet,RoundNet,SkipsNet,OpponentNet,EffectsNet,TrapsNet,AnimatingNet"
)

-- The modules are looked up when the frame runs, so they may load after frame.lua.
for _, name in ipairs(PVP.FRAME_ORDER) do
	PVP[name] = {
		update = function()
			calls[#calls + 1] = name
		end,
	}
end

Game:update(0)
check(
	"the game first, then every net in the declared order",
	table.concat(calls, ","),
	"game," .. table.concat(PVP.FRAME_ORDER, ",")
)

calls = {}
Game:update(0)
Game:update(0)
check("every frame runs them again", #calls, 2 * (#PVP.FRAME_ORDER + 1))

-- No net wraps Game:update itself any more: frame.lua is the only wrapper.
local files = assert(io.popen(package.config:sub(1, 1) == "\\" and 'dir /b "pvp_api\\*.lua"' or "ls pvp_api/*.lua"))
local wrappers = {}
for line in files:lines() do
	local name = line:match("([^/\\]+%.lua)%s*$")
	if name then
		local file = assert(io.open("pvp_api/" .. name, "rb"))
		local text = file:read("*a")
		file:close()
		if text:find("Game.update", 1, true) or text:find("Game:update", 1, true) then
			wrappers[#wrappers + 1] = name
		end
	end
end
files:close()
check("only frame.lua wraps Game:update in pvp_api", table.concat(wrappers, ","), "frame.lua")

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
