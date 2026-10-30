-- Run from the repo root: lua5.4 tests/unit/round_sync_test.lua
-- Real referee + client recovery, with an explicitly lossy in-memory transport.
local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, item in pairs(value) do
		out[key] = copy(item)
	end
	return out
end

local lobby, sent, notices, sequence

-- The referee asks everyone who looks ready to confirm before it starts the blind.
local function confirm_ready_check()
	local check = PVP.REF.ready_check
	if not check then return end
	for _, id in ipairs(check.ids) do
		PVP.referee_on_ready_ack(id, check.nonce, true)
	end
end

local function setup(mode, count, lives, legacy)
	sent, notices, sequence = {}, {}, 0
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
		E_MANAGER = { add_event = function() end },
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
	for _, p in ipairs(lobby.players) do
		PVP.referee_on_ready_blind(p.id, 4, not legacy and 1 or nil)
	end
	confirm_ready_check()
	if mode == "nemesis_pairing" then PVP.REF.nemesis_of = { a = "b", b = "a", c = "d", d = "c" } end
	PVP.begin_round_sync(PVP.REF.round.enabled and PVP.REF.round.id or nil, "a")
	sent = {}
end

local function report(id, revision, score, hands, round_id)
	PVP.referee_on_play_hand(id, {
		round_id = round_id or PVP.REF.round.id,
		revision = revision,
		score = tostring(score),
		handsLeft = hands,
	})
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

local function test(name, fn)
	fn()
	print("ok   " .. name)
end

test("lost final report retries the committed score while in HAND_PLAYED", function()
	setup("pair")
	report("b", 1, 200, 0)
	lobby.disconnected = true
	PVP.commit_round_report({ score = "100", handsLeft = 0 })
	equal(#sent, 1)
	equal(PVP.GAME.round_sync.pending, true)
	PVP.GAME.score = "999" -- Represents unrelated/mid-scoring live state: never sampled.
	lobby.disconnected = false
	PVP.reconcile_round()
	PVP.update_round_sync(0)
	local pending = last("pvp_play_hand")
	equal(pending.score, "100")
	PVP.referee_on_play_hand("a", pending)
	equal(PVP.REF.players.a.lives, 3)
	equal(last("pvp_round_state").outcome.key, "pvp_end_pvp")
end)

test("lost ack retries; a matching ack stops retries; stale ack does not", function()
	setup("pair")
	PVP.commit_round_report({ score = "100", handsLeft = 3 })
	local first = last("pvp_play_hand")
	PVP.referee_on_play_hand("a", first)
	local old_ack = copy(last("pvp_round_state"))
	Game:update(2)
	equal(last("pvp_play_hand").revision, 1)
	PVP.commit_round_report({ score = "200", handsLeft = 2 })
	PVP.receive_round_state("a", old_ack)
	equal(PVP.GAME.round_sync.pending, true)
	PVP.referee_on_play_hand("a", last("pvp_play_hand"))
	PVP.receive_round_state("a", last("pvp_round_state"))
	equal(PVP.GAME.round_sync.pending, false)
	local before = #sent
	PVP.update_round_sync(20)
	equal(#sent, before)
end)

test("reordered reports cannot roll score/hands back", function()
	setup("pair")
	report("a", 2, 200, 2)
	report("a", 1, 100, 3)
	equal(PVP.Score.display(PVP.REF.players.a.score), PVP.Score.display("200"))
	equal(PVP.REF.players.a.hands_left, 2)
	equal(last("pvp_round_state").revisions.a, 2)
end)

test("wrong round, unknown sender and malformed revisions cannot mutate referee", function()
	setup("pair")
	report("a", 1, 100, 0, "previous-run")
	report("outsider", 1, 100, 0)
	report("a", -1, 100, 0)
	report("a", 0.5, 100, 0)
	report("a", 0 / 0, 100, 0)
	equal(PVP.REF.players.a.hands_left, 4)
	equal(PVP.REF.players.outsider, nil)
	equal(#sent, 0)
end)

for _, mode in ipairs({ "pair", "team_based", "manhunt", "nemesis_pairing", "royale" }) do
	test(mode .. ": duplicate and newer reports after resolution cannot deduct another life", function()
		setup(mode, mode == "pair" and 2 or 4)
		for i, p in ipairs(lobby.players) do
			report(p.id, 1, 500 - i * 100, 0)
		end
		assert(PVP.REF.round.outcome, "round did not resolve")
		local lives, teams = {}, copy(PVP.REF.team_lives)
		for id, pl in pairs(PVP.REF.players) do
			lives[id] = pl.lives
			PVP.referee_on_new_round(id)
		end
		for _, p in ipairs(lobby.players) do
			report(p.id, 1, 999, 0)
			report(p.id, 2, 999, 0)
		end
		for id, value in pairs(lives) do
			equal(PVP.REF.players[id].lives, value)
		end
		for id, value in pairs(teams) do
			equal(PVP.REF.team_lives[id], value)
		end
	end)
end

test("lost outcome is returned with lives, and client applies it exactly once", function()
	setup("pair")
	PVP.commit_round_report({ score = "100", handsLeft = 0 })
	PVP.referee_on_play_hand("a", last("pvp_play_hand"))
	PVP.receive_round_state("a", last("pvp_round_state"))
	report("b", 1, 200, 0) -- All broadcasts from resolution are dropped.
	local applied = 0
	MPAPI.ActionTypes.pvp_player_lives.on_receive = function(_, _, params)
		if params.player_id == "a" then PVP.GAME.lives = params.lives end
	end
	MPAPI.ActionTypes.pvp_end_pvp.on_receive = function()
		applied = applied + 1
	end
	PVP.reconcile_round()
	PVP.update_round_sync(0)
	PVP.referee_on_play_hand("a", last("pvp_play_hand"))
	local state = last("pvp_round_state")
	PVP.receive_round_state("a", state)
	PVP.receive_round_state("a", state)
	equal(PVP.GAME.lives, 3)
	equal(applied, 1)
	equal(PVP.GAME.round_sync.pending, false)
end)

test("final-life result is retained as a match win", function()
	setup("pair", 2, 1)
	report("a", 1, 100, 0)
	report("b", 1, 200, 0)
	report("a", 1, 100, 0)
	equal(last("pvp_round_state").outcome.key, "pvp_win")
	equal(last("pvp_round_state").outcome.params.winner_id, "b")
	equal(last("pvp_round_state").lives.a, 0)
end)

test("resolved round and accepted revisions survive checkpoint takeover", function()
	setup("pair")
	report("a", 1, 100, 0)
	report("b", 1, 200, 0)
	local id = PVP.REF.round.id
	PVP.REF.round = nil
	equal(PVP.referee_take_over(), "checkpoint")
	equal(PVP.REF.round.id, id)
	equal(PVP.REF.round.revisions.a, 1)
	report("a", 1, 100, 0)
	equal(last("pvp_round_state").lives.a, 3)
	equal(PVP.REF.players.a.lives, 3)
end)

test("new round rejects previous round reports and responses", function()
	setup("pair")
	report("a", 1, 100, 0)
	report("b", 1, 200, 0)
	local old = copy(last("pvp_round_state"))
	for _, p in ipairs(lobby.players) do
		PVP.referee_on_ready_blind(p.id, 4, 1)
	end
	confirm_ready_check()
	PVP.begin_round_sync(PVP.REF.round.id, "a")
	report("a", 2, 999, 0, old.round_id)
	PVP.receive_round_state("a", old)
	equal(PVP.REF.players.a.hands_left, 4)
	equal(PVP.GAME.round_sync.applied, nil)
end)

test("unanswered requests surface failure; reconnect retries; leaving cancels", function()
	setup("pair")
	PVP.commit_round_report({ score = "100", handsLeft = 0 })
	PVP.update_round_sync(30)
	equal(PVP.GAME.round_sync.failed, true)
	equal(#notices, 1)
	PVP.update_round_sync(30)
	equal(#notices, 1)
	PVP.reconcile_round()
	PVP.update_round_sync(0)
	equal(PVP.GAME.round_sync.failed, false)
	local before = #sent
	lobby = nil
	PVP.update_round_sync(30)
	equal(#sent, before)
	PVP.GAME = {}
	PVP.update_round_sync(30)
	equal(#sent, before)
end)

test("mixed-version lobby stays on legacy wire protocol without retries", function()
	setup("pair", 2, 4, true)
	equal(PVP.REF.round.enabled, false)
	equal(PVP.GAME.round_sync, nil)
	equal(PVP.commit_round_report({ score = "100", handsLeft = 0 }), false)
	PVP.referee_on_play_hand("a", { score = "100", handsLeft = 0 })
	PVP.referee_on_play_hand("b", { score = "200", handsLeft = 0 })
	equal(last("pvp_end_pvp").loser_id, "a")
end)

test("a query before the first hand does not fabricate a zero-hand report", function()
	setup("pair")
	PVP.reconcile_round()
	PVP.update_round_sync(0)
	PVP.referee_on_play_hand("a", last("pvp_play_hand"))
	equal(PVP.REF.players.a.hands_left, 4)
	equal(PVP.REF.round.outcome, nil)
	equal(last("pvp_round_state").revisions.a, 0)
end)

test("host socket drop keeps the referee's result available after rejoin", function()
	setup("pair")
	report("a", 1, 100, 0)
	lobby.disconnected = true
	report("b", 1, 200, 0) -- The inbound report landed just before outgoing transport failed.
	equal(PVP.REF.players.a.lives, 3)
	lobby.disconnected = false
	report("b", 1, 200, 0)
	equal(last("pvp_round_state").outcome.key, "pvp_end_pvp")
	equal(PVP.REF.players.a.lives, 3)
end)

test("only the current host can acknowledge a report, including after takeover", function()
	setup("pair")
	PVP.commit_round_report({ score = "100", handsLeft = 2 })
	local state = { round_id = PVP.REF.round.id, revisions = { a = 1 } }
	PVP.receive_round_state("b", state)
	equal(PVP.GAME.round_sync.pending, true)
	PVP.reconcile_round("b")
	PVP.receive_round_state("a", state)
	equal(PVP.GAME.round_sync.pending, true)
	PVP.receive_round_state("b", state)
	equal(PVP.GAME.round_sync.pending, false)
end)

test("the final result still reaches players eliminated in an earlier round", function()
	setup("royale", 3, 1)
	report("a", 1, 300, 0)
	report("b", 1, 200, 0)
	report("c", 1, 100, 0)
	local retired = PVP.REF.round.id
	equal(PVP.REF.players.c.lives, 0)
	for _, id in ipairs({ "a", "b" }) do
		PVP.referee_on_new_round(id)
		PVP.referee_on_ready_blind(id, 4, 1)
	end
	confirm_ready_check()
	local active = PVP.REF.round.id
	-- c missed both its elimination and the old round's end. The survivors moved on.
	report("c", 1, 100, 0, retired)
	equal(last("pvp_round_state").round_id, retired)
	equal(last("pvp_round_state").eliminated.c, true)
	equal(PVP.REF.round.id, active)
	report("a", 1, 300, 0)
	report("b", 1, 200, 0)
	equal(last("pvp_win").winner_id, "a")
	local recipient
	for _, message in ipairs(sent) do
		if message.key == "pvp_win" then recipient = message.to end
	end
	equal(recipient, "c")
	equal(last("pvp_round_state").outcome.key, "pvp_win")
end)

test("real action handlers restore lives before ending the blind and ignore duplicate state", function()
	setup("pair")
	MPAPI.ActionType = function(def)
		MPAPI.ActionTypes[def.key] = def
	end
	dofile("pvp_api/actions/_helpers.lua")
	dofile("pvp_api/actions/blind_handshake.lua")
	dofile("pvp_api/actions/score_resolution.lua")
	dofile("pvp_api/actions/outcomes.lua")
	dofile("lib/lives_lookup.lua")
	local ended = 0
	PVP.dispatch_action = function(action, params)
		if action == "playerInfo" then PVP.GAME.lives = params.lives end
		if action == "endPvP" then
			equal(PVP.GAME.lives, 3)
			equal(params.lost, true)
			ended = ended + 1
		end
	end
	local hand = MPAPI.ActionTypes.pvp_play_hand
	hand:on_receive("a", { round_id = PVP.REF.round.id, revision = 1, score = "100", handsLeft = 0 })
	hand:on_receive("b", { round_id = PVP.REF.round.id, revision = 1, score = "200", handsLeft = 0 })
	local state = last("pvp_round_state")
	MPAPI.ActionTypes.pvp_round_state:on_receive("a", state)
	MPAPI.ActionTypes.pvp_round_state:on_receive("a", state)
	equal(ended, 1)
	PVP.end_pending_death = function() end
	MPAPI.has_server_referee = function()
		return false
	end
	MPAPI.ActionTypes.pvp_win:on_receive("a", { winner_id = "a" })
	equal(PVP.GAME.round_sync, nil)
end)

test("a new run clears archived results and rejects a previous run's report", function()
	setup("pair")
	local old = PVP.REF.round.id
	PVP.referee_reset(4)
	for _, p in ipairs(lobby.players) do
		PVP.referee_on_ready_blind(p.id, 4, 1)
	end
	confirm_ready_check()
	assert(old ~= PVP.REF.round.id)
	report("a", 1, 999, 0, old)
	equal(PVP.REF.players.a.hands_left, 4)
	equal(next(PVP.REF.retired_rounds), nil)
end)

test("outgoing router advertises the protocol and retains the exact committed report", function()
	setup("pair")
	dofile("pvp_api/net.lua")
	PVP.net_route({ action = "readyBlind", startingHands = 5 })
	equal(last("pvp_ready_blind").round_protocol, 1)
	PVP.net_route({ action = "playHand", score = "1e100", handsLeft = 0 })
	local report_sent = last("pvp_play_hand")
	equal(report_sent.round_id, PVP.REF.round.id)
	equal(report_sent.score, "1e100")
	equal(report_sent.handsLeft, 0)
	equal(PVP.GAME.round_sync.report.score, "1e100")
end)

test("a ready that outlived its blind does not start the next one under a player still in it", function()
	setup("pair")
	local function starts()
		local n = 0
		for _, message in ipairs(sent) do
			if message.key == "pvp_start_blind" then n = n + 1 end
		end
		return n
	end
	-- b's Ready arrived after the blind it belonged to had started, so it stayed set.
	PVP.referee_on_ready_blind("b", 4, 1)
	PVP.referee_on_ready_blind("a", 4, 1)
	local check = last("pvp_ready_check")
	equal(starts(), 0)
	PVP.referee_on_ready_ack("a", check.nonce, true)
	PVP.referee_on_ready_ack("b", check.nonce, false) -- b is still inside the previous blind
	equal(starts(), 0)
	equal(PVP.REF.players.b.is_ready, false)
	equal(PVP.REF.players.a.is_ready, true)
	-- b readies for real; the blind starts once both confirm.
	PVP.referee_on_ready_blind("b", 4, 1)
	check = last("pvp_ready_check")
	PVP.referee_on_ready_ack("a", check.nonce, true)
	PVP.referee_on_ready_ack("b", check.nonce, true)
	equal(starts(), 1)
end)
