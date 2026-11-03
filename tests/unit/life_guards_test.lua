-- Run from the repo root: luajit tests/unit/life_guards_test.lua
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

local function lives_of(id)
	return PVP.REF.players[id].lives
end

local function new_match(mode)
	setup(mode, mode == "team_based" and 4 or 2, 4)
	PVP.LOBBY.config.death_on_round_loss = true
end

test("an Ante timer run-out costs a life every time, also twice in one round", function()
	new_match("pair")
	PVP.referee_on_fail_timer("a")
	PVP.referee_on_fail_timer("a")
	equal(lives_of("a"), 2)
end)

test("a failed blind after an Ante timer life in the same round costs a life", function()
	new_match("pair")
	PVP.referee_on_fail_timer("a")
	PVP.referee_on_fail_round("a")
	equal(lives_of("a"), 2)
end)

test("a second failed blind in one round costs no life", function()
	new_match("pair")
	PVP.referee_on_fail_round("a")
	PVP.referee_on_fail_round("a")
	equal(lives_of("a"), 3)
end)

test("a failed blind then an Ante timer run-out in one round costs two lives", function()
	new_match("pair")
	PVP.referee_on_fail_round("a")
	PVP.referee_on_fail_timer("a")
	equal(lives_of("a"), 2)
end)

test("a new round re-arms the failed-blind guard", function()
	new_match("pair")
	PVP.referee_on_fail_round("a")
	PVP.referee_on_new_round("a")
	PVP.referee_on_fail_round("a")
	equal(lives_of("a"), 2)
end)

local function team_setup()
	new_match("team_based")
	PVP.LOBBY.roster = { a = "A", b = "A", c = "B", d = "B" }
	PVP.referee_reset(4)
	return PVP.REF.team_lives
end

test("Teams: an Ante timer run-out costs the team a life every time", function()
	local team_lives = team_setup()
	PVP.referee_on_fail_timer("a")
	PVP.referee_on_fail_timer("a")
	equal(team_lives.A, 2)
	equal(lives_of("b"), 2)
end)

test("Teams: a failed blind after an Ante timer life costs the team a life", function()
	local team_lives = team_setup()
	PVP.referee_on_fail_timer("a")
	PVP.referee_on_fail_round("a")
	equal(team_lives.A, 2)
end)

test("Teams: a second failed blind in one round costs no life", function()
	local team_lives = team_setup()
	PVP.referee_on_fail_round("a")
	PVP.referee_on_fail_round("a")
	equal(team_lives.A, 3)
end)

test("Teams: both teammates failing the same round cost one team life", function()
	local team_lives = team_setup()
	PVP.referee_on_fail_round("a")
	PVP.referee_on_fail_round("b")
	equal(team_lives.A, 3)
	equal(lives_of("b"), 3)
end)

test("Teams: a timer life then a teammate's failed blind cost two team lives", function()
	local team_lives = team_setup()
	PVP.referee_on_fail_timer("a")
	PVP.referee_on_fail_round("b")
	equal(team_lives.A, 2)
end)

test("Teams: the other team keeps its own guard", function()
	local team_lives = team_setup()
	PVP.referee_on_fail_round("a")
	PVP.referee_on_fail_round("c")
	equal(team_lives.B, 3)
end)

test("Teams: a new round re-arms the team guard", function()
	local team_lives = team_setup()
	PVP.referee_on_fail_round("a")
	PVP.referee_on_new_round("a")
	PVP.referee_on_fail_round("b")
	equal(team_lives.A, 2)
end)

test("Teams: a takeover mid-round keeps the team guard", function()
	team_setup()
	PVP.referee_on_fail_round("a")
	PVP.referee_checkpoint()
	local saved = lobby.metadata
	team_setup()
	lobby.metadata = saved
	PVP.referee_take_over()
	PVP.referee_on_fail_round("b")
	equal(PVP.REF.team_lives.A, 3)
end)

test("a referee takeover mid-round keeps the failed-blind guard", function()
	new_match("pair")
	PVP.referee_on_fail_round("a")
	PVP.referee_checkpoint()
	local saved = lobby.metadata
	new_match("pair")
	lobby.metadata = saved
	PVP.referee_take_over()
	equal(lives_of("a"), 3)
	PVP.referee_on_fail_round("a")
	equal(lives_of("a"), 3)
	PVP.referee_on_fail_timer("a")
	equal(lives_of("a"), 2)
end)

test("a run save with the shared guard set loads", function()
	new_match("pair")
	PVP.referee_on_fail_round("a")
	PVP.referee_checkpoint()
	local saved = lobby.metadata
	for _, key in pairs(saved) do
		for _, pl in pairs(key.players) do
			pl.blocker = 1
		end
	end
	new_match("pair")
	lobby.metadata = saved
	assert(PVP.referee_take_over() == "checkpoint")
	equal(lives_of("b"), 4)
end)
