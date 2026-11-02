-- Run from the repo root: luajit tests/unit/ready_check_referee_test.lua
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
	sendDebugMessage = function() end
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
	sendDebugMessage = function() end
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

local function starts()
	local n = 0
	for _, m in ipairs(sent) do
		if m.key == "pvp_start_blind" then n = n + 1 end
	end
	return n
end

local function last(key)
	for i = #sent, 1, -1 do
		if sent[i].key == key then return sent[i].params end
	end
	error("No message " .. key)
end

local function equal(got, want)
	assert(got == want, ("got %s, wanted %s"):format(tostring(got), tostring(want)))
end

local function fire_timeout()
	local pending = events
	events = {}
	for _, event in ipairs(pending) do
		event.func()
	end
end

local function leave(id)
	for i, p in ipairs(lobby.players) do
		if p.id == id then table.remove(lobby.players, i) break end
	end
end

local function test(name, fn)
	fn()
	print("ok   " .. name)
end

test("the timeout runs on the real clock and while paused", function()
	setup("pair")
	PVP.referee_on_ready_blind("a", 4, 1)
	PVP.referee_on_ready_blind("b", 4, 1)
	equal(#events, 1)
	equal(events[1].timer, "REAL")
	equal(events[1].pause_force, true)
end)

test("a player who left mid-check does not get a blind started against them", function()
	setup("pair")
	PVP.referee_on_ready_blind("a", 4, 1)
	PVP.referee_on_ready_blind("b", 4, 1)
	local check = last("pvp_ready_check")
	leave("b")
	PVP.referee_on_ready_ack("a", check.nonce, true)
	fire_timeout()
	equal(starts(), 0)
	equal(PVP.REF.ready_check, nil)
end)

test("a 2-player check still starts when both stay", function()
	setup("pair")
	PVP.referee_on_ready_blind("a", 4, 1)
	PVP.referee_on_ready_blind("b", 4, 1)
	local check = last("pvp_ready_check")
	PVP.referee_on_ready_ack("a", check.nonce, true)
	PVP.referee_on_ready_ack("b", check.nonce, true)
	equal(starts(), 1)
end)

test("a refusal clears the refuser's first-ready flag", function()
	setup("pair")
	PVP.referee_on_ready_blind("b", 4, 1)
	PVP.referee_on_ready_blind("a", 4, 1)
	local check = last("pvp_ready_check")
	equal(PVP.REF.players.b.first_ready, true)
	PVP.referee_on_ready_ack("a", check.nonce, true)
	PVP.referee_on_ready_ack("b", check.nonce, false)
	equal(PVP.REF.players.b.first_ready, false)
end)

test("a lobby of 3 dropping to 2 mid-check still starts for the two left", function()
	setup("pair", 3)
	for _, id in ipairs({ "a", "b", "c" }) do
		PVP.referee_on_ready_blind(id, 4, 1)
	end
	local check = last("pvp_ready_check")
	leave("c")
	PVP.referee_on_ready_ack("a", check.nonce, true)
	PVP.referee_on_ready_ack("b", check.nonce, true)
	PVP.referee_on_ready_ack("c", check.nonce, true)
	fire_timeout()
	equal(starts(), 1)
	local ids = {}
	for id in pairs(last("pvp_start_blind").starting_hands) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	equal(table.concat(ids, ","), "a,b")
end)

test("a lobby of 3 dropping to 2 stays blocked when a remaining player is unready", function()
	setup("pair", 3)
	for _, id in ipairs({ "a", "b", "c" }) do
		PVP.referee_on_ready_blind(id, 4, 1)
	end
	local check = last("pvp_ready_check")
	leave("c")
	PVP.referee_on_unready_blind("b")
	PVP.referee_on_ready_ack("a", check.nonce, true)
	fire_timeout()
	equal(starts(), 0)
end)
