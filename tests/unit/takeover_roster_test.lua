-- Run from the repo root: luajit tests/unit/takeover_roster_test.lua
-- A takeover with no Run save: the new host rebuilds the referee from what it saw itself.
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
		return self.result_pending == true
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


local function wins()
	local list = {}
	for _, msg in ipairs(sent) do
		if msg.key == "pvp_win" then list[#list + 1] = msg.params end
	end
	return list
end

-- Host "a" died on the Boss blind and left; guest "b" is the new host and no
-- checkpoint is in the metadata. The server still holds the result open.
local function guest_takes_over_a_pending_death(server_holds)
	setup("pair", 2, 4)
	PVP.LOBBY.config.death_on_round_loss = true
	lobby.is_host = false
	lobby.player_id = "b"
	lobby.players = { { id = "b" } }
	lobby.result_pending = server_holds ~= false
	PVP._match_players = { { id = "a" }, { id = "b" } }
	PVP.GAME.lives = 1
	PVP.GAME.pending_death = { player_id = "a", opponent_id = "b", blind_key = "1:Boss" }
	PVP.referee_reset(4)
	lobby.metadata = {}
	lobby.is_host = true
	sent = {}
	equal(PVP.referee_take_over(), "local")
	sent = {}
end

test("a takeover with no Run save lists every player of the match", function()
	guest_takes_over_a_pending_death()
	assert(PVP.REF.players.a, "the player who left should still be in the referee")
	assert(PVP.REF.players.b, "the new host should be in the referee")
end)

test("a takeover with no Run save keeps the hold the server has", function()
	guest_takes_over_a_pending_death()
	equal(PVP.GAME.result_held, true)
	equal(PVP.REF.pending_death.held, 1)
end)

test("a takeover with no Run save sees no hold when the server has none", function()
	guest_takes_over_a_pending_death(false)
	equal(PVP.GAME.result_held, false)
end)

test("the guest beats the blind after a takeover with no Run save and wins", function()
	guest_takes_over_a_pending_death()
	PVP.referee_on_blind_result("b", { ante = 1, blind = "Boss", beaten = true })
	local sent_wins = wins()
	equal(#sent_wins >= 1, true)
	equal(sent_wins[1].winner_id, "b")
	equal(sent_wins[1].draw, nil)
end)

test("the guest also loses its last life on that blind after a takeover and the match is a draw", function()
	guest_takes_over_a_pending_death()
	PVP.referee_on_blind_result("b", { ante = 1, blind = "Boss", beaten = false })
	equal(#wins(), 0)
	PVP.referee_on_fail_round("b")
	local sent_wins = wins()
	equal(#sent_wins >= 1, true)
	equal(sent_wins[1].draw, true)
end)
