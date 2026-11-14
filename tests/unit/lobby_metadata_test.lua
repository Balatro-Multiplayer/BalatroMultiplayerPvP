-- Run from the repo root: luajit tests/unit/lobby_metadata_test.lua
-- pvp_api/flow.lua: the host publishes the timer settings the server reads raw, the skip time's
-- increment included (nil is left out).
local failures = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		print("ok   " .. name)
	else
		failures = failures + 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end

local function equal(got, want)
	assert(got == want, ("got %s, wanted %s"):format(tostring(got), tostring(want)))
end

local function load_flow(config)
	MPAPI = { Party = { KIND = "party" } }
	PVP = {
		LOBBY = { config = config },
		PVP_GAMEMODES = { pvp_nemesis = { gamemode = "gamemode_mp_attrition", ruleset = "ruleset_mp_ranked" } },
		MatchmakingPolicy = {
			cocktail_recipe = function()
				return nil
			end,
		},
	}
	dofile("pvp_api/flow.lua")
	return PVP.pvp_lobby_metadata("pvp_nemesis", "private")
end

test("the timer settings are published raw", function()
	local meta = load_flow({ timer_base_seconds = 180, timer_forgiveness = 5, timer_increment_seconds = 60 })
	equal(meta.timer_base_seconds, 180)
	equal(meta.timer_forgiveness, 5)
	equal(meta.timer_increment_seconds, 60)
end)

test("an unset increment is left out", function()
	equal(load_flow({}).timer_increment_seconds, nil)
end)

print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
