-- Run from the repo root: luajit tests/unit/legacy_removal_test.lua
-- The legacy TCP router and the guessed opponent facts are gone: no Client.send, the opponent
-- sync is gone (the server owns skips), and a replayed hand with no recorded score writes nothing.
-- NET_PATH / ACTIONS_PATH / PLAYBACK_PATH (optional) point at older copies of the files, to
-- check a test against older code.
local failures = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		print("ok   " .. name)
	else
		failures = failures + 1
		print("FAIL " .. name .. "\n     " .. tostring(err))
	end
end

local function equal(a, b)
	if a ~= b then error("expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

local function read(path)
	local f = assert(io.open(path, "rb"))
	local text = f:read("*a")
	f:close()
	return text
end

local NET = os.getenv("NET_PATH") or "pvp_api/net.lua"
local ACTIONS = os.getenv("ACTIONS_PATH") or "networking/action_handlers.lua"
local PLAYBACK = os.getenv("PLAYBACK_PATH") or "lib/playback_handlers.lua"
local REPLAY_ACTIONS = os.getenv("REPLAY_ACTIONS_PATH") or "pvp_api/replay_log_actions.lua"
local SCORE = os.getenv("SCORE_PATH") or "lib/score.lua"
local PLAYER_RESULT = os.getenv("PLAYER_RESULT_PATH") or "pvp_api/actions/player_result.lua"

local synced, logs, handlers

local function setup(game)
	synced, logs, handlers = {}, {}, {}
	G = {
		GAME = game,
		P_BLINDS = {
			bl_mp_nemesis = {
				sync = function(_, payload)
					synced[#synced + 1] = payload
				end,
			},
		},
	}
	PVP = {
		GAME = { lives = 3, enemy = {} },
		NetBasics = {
			pvp_lobby = function()
				return nil
			end,
		},
		match_log = function(level, text)
			logs[#logs + 1] = level .. " " .. text
		end,
		current_run_id = function()
			return nil
		end,
		RLOG = { record = function() end },
		Score = {
			from_game_value = function(v)
				return v
			end,
		},
		UTILS = { AREA = {} },
		ReadyNet = {},
		RoundFacts = {},
		RoundNet = { hand = function() end, applied_count = function() end },
		TimerNet = {},
		PendingDeath = {},
	}
	MPAPI = {
		ActionTypes = {},
		OPCODE = setmetatable({}, {
			__index = function(_, k)
				return k
			end,
		}),
		get_state = function() end,
		playback = {
			register_handler = function(_, opcode, fn)
				handlers[opcode] = fn
			end,
		},
	}
end

test("net.lua leaves the Client table alone: there is no Client.send override", function()
	setup({ skips = 1 })
	local original = function() end
	Client = { send = original }
	dofile(NET)
	equal(Client.send, original)
	Client = nil
end)

-- SOURCE_REV (optional) reads the mod's files from that git revision instead of the working tree.
local SOURCE_REV = os.getenv("SOURCE_REV")

local function lines_of(cmd)
	local p = assert(io.popen(cmd))
	local out = {}
	for line in p:lines() do
		out[#out + 1] = line
	end
	p:close()
	return out
end

local function source(path)
	if not SOURCE_REV then return read(path) end
	return table.concat(lines_of("git show " .. SOURCE_REV .. ":" .. path), "\n")
end

-- Every Lua file and Lovely patch of the mod, tests excluded.
local function mod_sources()
	local list = lines_of(SOURCE_REV and ("git ls-tree -r --name-only " .. SOURCE_REV) or "git ls-files")
	local out = {}
	for _, path in ipairs(list) do
		local wanted = path:match("%.lua$") or path:match("^lovely/.*%.toml$")
		if wanted and not path:match("^tests/") then out[#out + 1] = path end
	end
	return out
end

test("no source file or Lovely patch calls or defines Client.send", function()
	for _, path in ipairs(mod_sources()) do
		local text = source(path)
		if text:find("Client.send", 1, true) or text:find("\nClient = {}", 1, true) then
			error(path .. " still names Client.send")
		end
	end
end)

test("gaining hands on the PvP blind reports no hand: only a played hand is a hand", function()
	local text = source("lovely/game.toml")
	for block in text:gmatch("%[%[patches%]%](.-)%f[%[]%[%[patches%]%]") do
		if block:find("hands_left + mod", 1, true) and block:find("play_hand", 1, true) then
			error("lovely/game.toml sends play_hand when hands are gained")
		end
	end
	local last = text:match(".*%[%[patches%]%](.*)$") or ""
	if last:find("hands_left + mod", 1, true) and last:find("play_hand", 1, true) then
		error("lovely/game.toml sends play_hand when hands are gained")
	end
end)

test("a played hand and a skip relay nothing to the opponent: the server owns the skip count", function()
	setup({ skips = 2 })
	dofile(NET)
	PVP.net_route({ action = "playHand", score = "100", handsLeft = 1 })
	PVP.net_route({ action = "skip", skips = 3 })
	equal(#synced, 0)
	equal(#logs, 0)
end)

test("no source file names the peer skip relay or the old skip-time bookkeeping", function()
	for _, path in ipairs(mod_sources()) do
		local text = source(path)
		for _, word in ipairs({ "relay_enemy_skips", "update_matching_skip_timer", "skips_before_pvp", "skips_difference", "skips_resync" }) do
			if text:find(word, 1, true) then error(path .. " still names " .. word) end
		end
	end
end)

test("a replayed hand with no recorded score writes no enemy field", function()
	setup({})
	PVP.Score.parse = function(text)
		if type(text) ~= "string" or not tonumber(text) then return nil end
		return text
	end
	PVP.Score.greater = function(a, b)
		return b == nil or tonumber(a) > tonumber(b)
	end
	dofile(PLAYBACK)
	local ctx = { is_pov = false }
	handlers.HAND_RESULT({ nil, 3 }, ctx)
	equal(PVP.GAME.enemy.real_score, nil)
	equal(PVP.GAME.enemy.highest_score, nil)
	equal(PVP.GAME.enemy.hands, nil)
	handlers.HAND_RESULT({ "garbage", 2 }, ctx)
	equal(PVP.GAME.enemy.real_score, nil)
	equal(PVP.GAME.enemy.hands, nil)
	handlers.HAND_RESULT({ "40", 2 }, ctx)
	equal(PVP.GAME.enemy.real_score, "40")
	equal(PVP.GAME.enemy.hands, 2)
end)

test("no source under pvp_api/, ui/ or networking/ names has_server_referee, seed_votes or draw_votes", function()
	for _, path in ipairs(mod_sources()) do
		if path:match("^pvp_api/") or path:match("^ui/") or path:match("^networking/") then
			local text = source(path)
			for _, word in ipairs({ "has_server_referee", "seed_votes", "draw_votes" }) do
				if text:find(word, 1, true) then error(path .. " still names " .. word) end
			end
		end
	end
end)

test("a playback run start sets the opponent's skips to 0, then each skip counts one", function()
	setup({})
	dofile(PLAYBACK)
	G.FUNCS = {}
	Game = { update = function() end }
	local local_lobby = { on = function() end }
	PVP.LOBBY = { config = { starting_lives = 4 } }
	PVP.SP = {}
	PVP.LobbyAccess = { PRACTICE = "practice" }
	PVP.id = "pvp"
	PVP.GAME.enemy = { skips = nil }
	PVP.playback_gamemode_of = function() end
	PVP.reset_lobby_config = function() end
	PVP.setup_lobby_mirror = function() end
	PVP.apply_replay_loadout = function() end
	PVP.pvp_lobby_metadata = function() end
	MPAPI.matchmaking = {
		guard_queued = function()
			return false
		end,
	}
	MPAPI.create_local_lobby = function()
		return local_lobby
	end
	MPAPI.LobbyEvent = { CONNECTED = "connected" }
	dofile("lib/playback_launch.lua")
	PVP._playback_wait_for = function() end
	PVP._start_playback({ seed = "s", gamemode = "pvp_nemesis" }, function() end)
	equal(PVP.GAME.enemy.skips, 0)
	handlers.SKIP_BLIND({}, { is_pov = false })
	equal(PVP.GAME.enemy.skips, 1)
end)

test("the opponent's skip before the playback run start is unknown: no change and a log line", function()
	setup({})
	dofile(PLAYBACK)
	PVP.GAME.enemy.skips = nil
	handlers.SKIP_BLIND({}, { is_pov = false })
	equal(PVP.GAME.enemy.skips, nil)
	equal(#logs, 1)
	assert(logs[1]:find("skip count unknown", 1, true), logs[1])
end)

test("the receive pump is gone: no queue pop, no legacy-server branch, no socket channels", function()
	local text = read(ACTIONS)
	for _, word in ipairs({ "pull_next_network_message", "legacy_server", "networkToUi", "uiToNetwork", "register_action" }) do
		equal(text:find(word, 1, true), nil)
	end
end)

test("the lobby and connection handlers of the old server are gone", function()
	local text = read(ACTIONS)
	for _, name in ipairs({
		"action_connected",
		"action_lobbyInfo",
		"action_joinedLobby",
		"action_rejoinedLobby",
		"action_disconnected",
		"action_reconnecting",
	}) do
		equal(text:find(name, 1, true), nil)
	end
end)

test("the handlers live code dispatches are still there", function()
	local text = read(ACTIONS)
	for _, name in ipairs({ "startGame", "startBlind", "handsSpent", "endPvP", "winGame", "loseGame", "drawGame" }) do
		assert(text:find("	" .. name .. " = ", 1, true), name)
	end
	assert(text:find("function PVP.dispatch_action", 1, true))
end)

test("the replay transport comment no longer names Client.send", function()
	equal(read(REPLAY_ACTIONS):find("Client.send", 1, true), nil)
end)

test("no score default is left: PVP.Score has no or_zero and player_result does not call one", function()
	equal(read(SCORE):find("or_zero", 1, true), nil)
	equal(read(PLAYER_RESULT):find("or_zero", 1, true), nil)
end)

if failures > 0 then os.exit(1) end
