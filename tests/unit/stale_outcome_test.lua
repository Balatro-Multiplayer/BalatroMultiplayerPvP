-- Run from the repo root: luajit tests/unit/stale_outcome_test.lua
-- The real referee.lua with a stubbed lobby and a captured event queue, so the ready
-- check timeout can be fired on demand.
local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, item in pairs(value) do
		out[key] = copy(item)
	end
	return out
end

local lobby, sent, notices, sequence, events

local function setup(mode, count, lives)
	sent, notices, sequence, events = {}, {}, 0, {}
	PVP = {
		match_log = function() end,
		id = "pvp",
		GAME = {},
		LOBBY = { config = { starting_lives = lives or 4 }, roster = {} },
		UTILS = {
			string_split = function(s)
				local parts = {}
				for part in s:gmatch("[^e]+") do
					parts[#parts + 1] = part
				end
				return parts
			end,
		},
		current_target_id = function()
			return "b"
		end,
	}
	if mode ~= "pair" then PVP.LOBBY.config[mode] = true end
	G = {
		STAGE = "run",
		STAGES = { RUN = "run" },
		STATES = { GAME_OVER = "over", HAND_PLAYED = "hand" },
		STATE = "hand",
		E_MANAGER = { add_event = function(_, event)
			events[#events + 1] = event
		end },
	}
	Event = function(spec)
		return spec
	end
	Game = { update = function() end }
	love = { timer = {
		getTime = function()
			return 0
		end,
	} }
	number_format = tostring
	math.pow = math.pow or function(a, b)
		return a ^ b
	end
	sendWarnMessage = function() end
	localize = function(key)
		return key
	end
	attention_text = function(message)
		notices[#notices + 1] = message
	end
	lobby = {
		is_host = true,
		mod_id = "pvp",
		player_id = "a",
		metadata = {},
		_game = { started = { run_id = "run-1" } },
		players = {},
	}
	for i = 1, count or 2 do
		lobby.players[i] = { id = string.char(96 + i) }
	end
	function lobby:get_players()
		return self.players
	end
	function lobby:is_result_pending()
		return false
	end
	function lobby:get_metadata()
		return self.metadata
	end
	function lobby:set_metadata(meta)
		self.metadata = copy(meta)
	end
	function lobby:get_gamemode_instance()
		return {}
	end
	function lobby:action(action)
		local function send(_, target, params)
			if lobby.disconnected then return false end
			sent[#sent + 1] = { key = action.key, to = target, params = copy(params) }
			return true
		end
		return {
			send = send,
			broadcast = function(self, params)
				return send(self, "*", params)
			end,
		}
	end
	MPAPI = {
		match_log = function() end,
		get_current_lobby = function()
			return lobby
		end,
		generate_id = function()
			sequence = sequence + 1
			return "round-" .. sequence
		end,
		json_encode = function()
			sequence = sequence + 1
			return tostring(sequence)
		end,
		ActionTypes = setmetatable({}, {
			__index = function(t, key)
				local action = { key = key }
				rawset(t, key, action)
				return action
			end,
		}),
		ReadyTracker = function()
			return {
				set = function(self, id, value)
					self[id] = value
				end,
				is_ready = function(self, id)
					return self[id] == true
				end,
				reset = function(self)
					for k, v in pairs(self) do
						if type(v) ~= "function" then self[k] = nil end
					end
				end,
			}
		end,
	}
	dofile((os.getenv("MPAPI_DIR") or "../BalatroMultiplayerAPI/") .. "lib/big_score.lua")
	dofile("lib/score.lua")
	dofile("lib/pending_death.lua")
	dofile("lib/ready_check.lua")
	dofile("pvp_api/server_hold.lua")
	dofile("pvp_api/referee.lua")
	dofile("pvp_api/round_sync.lua")
	PVP.referee_reset(lives)
	sent = {}
end



local function equal(got, want)
	assert(got == want, ("got %s, wanted %s"):format(tostring(got), tostring(want)))
end

local function test(name, fn)
	fn()
	print("ok   " .. name)
end

local function wins_sent()
	local n = 0
	for _, msg in ipairs(sent) do
		if msg.key == "pvp_win" then n = n + 1 end
	end
	return n
end

-- Match 1 ends with a result while this client is host.
local function host_match_one_to_a_result()
	setup("pair", 2, 1)
	PVP.LOBBY.config.death_on_round_loss = true
	PVP.referee_on_fail_round("a")
	PVP.referee_on_fail_round("b")
	assert(PVP.REF.last_outcome, "match 1 should have a result")
	sent = {}
end

local function take_over()
	-- These cases take over a new match, not the completed checkpoint's run.
	lobby._game.started.run_id = "run-2"
	lobby.is_host = true
	PVP.GAME.lives = 1
	PVP.referee_take_over()
end

test("a guest at the start of a run drops the result of its earlier match as host", function()
	host_match_one_to_a_result()
	lobby.is_host = false
	PVP.referee_reset(4)
	equal(PVP.REF.last_outcome, nil)
end)

test("a guest at the start of a run drops the larger-match result mark", function()
	host_match_one_to_a_result()
	PVP.REF.many_result_sent = true
	lobby.is_host = false
	PVP.referee_reset(4)
	equal(PVP.REF.many_result_sent, nil)
end)

test("a takeover never resends the result of an earlier match", function()
	host_match_one_to_a_result()
	lobby.is_host = false
	PVP.referee_reset(4)
	take_over()
	PVP.referee_on_result_request("b")
	equal(wins_sent(), 0)
end)

test("a takeover clears the old result even when no run start cleared it", function()
	host_match_one_to_a_result()
	PVP.REF.many_result_sent = true
	take_over()
	equal(PVP.REF.last_outcome, nil)
	equal(PVP.REF.many_result_sent, nil)
	PVP.referee_on_result_request("b")
	equal(wins_sent(), 0)
end)

test("the new host still sends the result of the match it took over", function()
	host_match_one_to_a_result()
	lobby.is_host = false
	PVP.referee_reset(4)
	take_over()
	PVP.referee_on_fail_round("a")
	PVP.referee_on_fail_round("b")
	assert(wins_sent() >= 1, "the takeover match result should be sent")
end)
