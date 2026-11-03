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

-- Canonical encoding lets the checkpoint tests distinguish attempted writes from
-- echoed metadata without depending on the game's JSON library.
local function encode(value)
	if type(value) ~= "table" then return type(value) .. ":" .. tostring(value) end
	local keys, parts = {}, {}
	for key in pairs(value) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	for _, key in ipairs(keys) do parts[#parts + 1] = encode(key) .. "=" .. encode(value[key]) end
	return "{" .. table.concat(parts, ",") .. "}"
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
		STATES = { GAME_OVER = "over", HAND_PLAYED = "hand", BLIND_SELECT = "select" },
		STATE = "hand",
		GAME = { round_resets = { ante = 2, hands = 4 }, blind_on_deck = "Boss" },
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
		_pvp_entry_client_id = "client",
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
		self.metadata_writes = (self.metadata_writes or 0) + 1
		if self.disconnected then return end
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
		json_encode = encode,
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
	dofile("pvp_api/entry_sync.lua")
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

-- Recovery regressions for the five stranded-entry characterizations. Transport
-- loss and checkpoint lag are injected; this is not a running Balatro instance.
local function messages(key)
	local n = 0
	for _, message in ipairs(sent) do
		if message.key == key then n = n + 1 end
	end
	return n
end

local function intent(ready, revision, step)
	return { run_id = "run-1", client_id = "client", step = step or 9, revision = revision or 1,
		ready = ready, starting_hands = 4, round_protocol = 1 }
end

local function confirm_ready()
	local check = last("pvp_ready_check")
	for _, id in ipairs(check.players) do
		PVP.referee_on_ready_ack(id, check.nonce, true)
	end
end

local function retry_local(id)
	PVP.update_entry_sync(2)
	PVP.referee_on_entry_sync(id, last("pvp_entry_sync"))
end

test("a button press replaces the choice; a retry repeats it without delivery state", function()
	setup("pair")
	G.STATE = G.STATES.BLIND_SELECT
	local first = PVP.set_blind_readiness(true, 4)
	equal(encode(first), encode(intent(true)))
	PVP.update_entry_sync(2)
	equal(encode(last("pvp_entry_sync")), encode(first))
	equal(first.revision, 1)
	equal(first.retry_in, nil)
	equal(first.lobby, nil)
	equal(first.accepted_start_id, nil)
	local second = PVP.set_blind_readiness(false)
	equal(second.revision, 2)
	equal(second.ready, false)
	equal(first.ready, true) -- Replacing the answer does not rewrite the old one.
	equal(PVP.current_readiness_choice(), second)
	G.GAME.round_resets.ante = 3
	local next_blind = PVP.set_blind_readiness(true, 5)
	equal(next_blind.step, 12)
	equal(next_blind.revision, 1)
end)

test("the ready-check response confirms the exact current choice, not just Ready", function()
	setup("pair")
	G.STATE = G.STATES.BLIND_SELECT
	PVP.GAME.ready_blind = true
	local first = PVP.set_blind_readiness(true, 4)
	MPAPI.ActionType = function(def) MPAPI.ActionTypes[def.key] = def end
	dofile("pvp_api/actions/_helpers.lua")
	dofile("pvp_api/actions/blind_handshake.lua")
	lobby.is_host, lobby.player_id = false, "b"
	local check = { nonce = "check-1", players = { "b" }, entries = { b = first } }
	MPAPI.ActionTypes.pvp_ready_check:on_receive("a", check)
	equal(last("pvp_ready_ack").ready, true)
	PVP.set_blind_readiness(false)
	PVP.set_blind_readiness(true, 4)
	MPAPI.ActionTypes.pvp_ready_check:on_receive("a", check)
	equal(last("pvp_ready_ack").ready, false)
	check.entries.b = PVP.current_readiness_choice()
	MPAPI.ActionTypes.pvp_ready_check:on_receive("a", check)
	equal(last("pvp_ready_ack").ready, true)
end)

test("consuming Ready keeps the player's choice and the checkpoint wire schema", function()
	setup("pair")
	PVP.referee_on_entry_sync("a", intent(true))
	PVP.referee_on_entry_sync("b", intent(true))
	confirm_ready()
	equal(PVP.REF.players.b.is_ready, false)
	equal(PVP.REF.players.b.readiness_choice.ready, true)
	local checkpoint = lobby.metadata._pvp_ref
	equal(checkpoint.players.b.entry.ready, true)
	equal(checkpoint.players.b.readiness_choice, nil)
	equal(checkpoint.round.start.entry_id, PVP.REF.round.id)
	equal(PVP.referee_take_over(), "checkpoint")
	equal(PVP.REF.players.b.is_ready, false)
	equal(PVP.REF.players.b.readiness_choice.revision, 1)
end)

test("transient reconnect restores a Ready without another button press", function()
	setup("pair")
	G.STATE = G.STATES.BLIND_SELECT
	PVP.GAME.ready_blind = true -- Guest's intact local state during a socket drop.
	PVP.set_blind_readiness(true, 4)
	PVP.referee_on_entry_sync("b", intent(true))
	PVP.referee_on_player_reconnected("b")
	PVP.referee_on_entry_sync("a", intent(true))
	equal(PVP.GAME.ready_blind, true)
	equal(PVP.REF.players.b.is_ready, false)
	equal(starts(), 0)
	retry_local("b")
	confirm_ready()
	equal(starts(), 1)
end)

test("a Ready lost before host delivery retries through the real button/router", function()
	setup("pair")
	G.STATE = G.STATES.BLIND_SELECT
	-- Exercise the real button, local ready action and outgoing router. Only the
	-- socket and game engine are stubs: broadcasting while disconnected fails.
	package.loaded.json = package.loaded.json or {}
	love.thread = { getChannel = function()
		return { pop = function() end }
	end }
	sendTraceMessage = function() end
	G.FUNCS = {}
	PVP.ACTIONS = {}
	PVP.UI = {}
	PVP.RLOG = { record = function() end }
	PVP.OPPONENT_SIGNALS = { starting_hands = function(resets) return resets.hands end }
	PVP.UTILS.get_blind_to_display = function() return "" end
	MPAPI.OPCODE = { READY_BLIND = 1 }
	dofile("networking/action_handlers.lua")
	dofile("pvp_api/net.lua")
	dofile("ui/game/functions.lua")
	lobby.disconnected = true
	local button = { config = { ref_table = { key = "bl_mp_nemesis" } } }
	G.FUNCS.mp_toggle_ready(button)
	equal(PVP.GAME.ready_blind, true)
	equal(PVP.GAME.next_blind_context, button)
	equal(messages("pvp_ready_blind"), 0)
	lobby.disconnected = false
	PVP.referee_on_entry_sync("a", intent(true))
	Game:update(2)
	equal(PVP.GAME.ready_blind, true)
	equal(messages("pvp_entry_sync"), 1)
	PVP.referee_on_entry_sync("b", last("pvp_entry_sync"))
	confirm_ready()
	equal(starts(), 1)
end)

test("a missed blind-start recovers the same round and duplicate delivery enters once", function()
	setup("pair")
	G.STATE = G.STATES.BLIND_SELECT
	PVP.GAME.ready_blind = true
	PVP.GAME.next_blind_context = {}
	PVP.set_blind_readiness(true, 4)
	PVP.referee_on_entry_sync("a", intent(true))
	PVP.referee_on_entry_sync("b", intent(true))
	confirm_ready()
	equal(starts(), 1)
	local original = last("pvp_start_blind")
	-- Inject non-delivery of that broadcast to b. It never calls begin_round_sync.
	equal(PVP.GAME.round_sync, nil)
	assert(PVP.REF.round and PVP.REF.round.id)
	sent = {}
	PVP.referee_on_player_reconnected("b")
	retry_local("b")
	local recovered = last("pvp_start_blind")
	equal(recovered.round_id, original.round_id)
	equal(PVP.REF.round.id, original.round_id)
	local entered = 0
	PVP.dispatch_action = function() entered = entered + 1 end
	MPAPI.ActionType = function(def) MPAPI.ActionTypes[def.key] = def end
	dofile("pvp_api/actions/_helpers.lua")
	dofile("pvp_api/actions/blind_handshake.lua")
	lobby.is_host, lobby.player_id = false, "b"
	MPAPI.ActionTypes.pvp_start_blind:on_receive("a", recovered)
	MPAPI.ActionTypes.pvp_start_blind:on_receive("a", recovered)
	equal(entered, 1)
	equal(PVP.GAME.round_sync.id, original.round_id)
end)

test("shrinking from 3 to 2 preserves readiness and opens the check", function()
	setup("pair", 3)
	PVP.referee_on_ready_blind("a", 4, 1)
	PVP.referee_on_ready_blind("b", 4, 1)
	-- c leaves before readying: unlike the existing mid-check test, no check is open.
	leave("c")
	equal(PVP.referee_n_player_forfeit("c"), true)
	equal(PVP.REF.players.a.is_ready, true)
	equal(PVP.REF.players.b.is_ready, true)
	fire_timeout()
	equal(starts(), 1)
end)

test("takeover from a lagging checkpoint reconstructs readiness from client retries", function()
	setup("pair", 4)
	G.STATE = G.STATES.BLIND_SELECT
	local checkpoint = copy(lobby.metadata)
	PVP.referee_on_entry_sync("b", intent(true))
	PVP.referee_on_entry_sync("c", intent(true))
	PVP.referee_on_entry_sync("d", intent(true))
	PVP.GAME.ready_blind = true
	PVP.set_blind_readiness(true, 4)
	-- The latest metadata writes did not reach the server before host a left.
	lobby.metadata = checkpoint
	leave("a")
	lobby.player_id = "b"
	equal(PVP.referee_take_over(), "checkpoint")
	-- The real N-player departure handling does not reconcile readiness either.
	equal(PVP.referee_n_player_forfeit("a"), true)
	fire_timeout()
	equal(PVP.REF.players.b.is_ready, false)
	equal(starts(), 0)
	retry_local("b")
	PVP.referee_on_entry_sync("c", intent(true))
	PVP.referee_on_entry_sync("d", intent(true))
	confirm_ready()
	equal(starts(), 1)
end)

test("a failed checkpoint write retries until server metadata confirms it", function()
	setup("pair")
	lobby.disconnected = true
	PVP.referee_on_ready_blind("a", 4, 1)
	equal(lobby.metadata._pvp_ref.players.a.ready, 0)
	local attempts = lobby.metadata_writes
	lobby.disconnected = false
	Game:update(2)
	equal(lobby.metadata._pvp_ref.players.a.ready, 1)
	equal(lobby.metadata_writes, attempts + 1)
	Game:update(2)
	equal(lobby.metadata_writes, attempts + 1)
end)

test("a rebuilt client can restart revisions, and its old incarnation stays retired", function()
	setup("pair")
	PVP.referee_on_entry_sync("b", intent(true, 9))
	PVP.referee_on_player_reconnected("b")
	local rebuilt = intent(true)
	rebuilt.client_id = "rebuilt-client"
	PVP.referee_on_entry_sync("b", rebuilt)
	equal(PVP.REF.players.b.readiness_choice.client_id, "rebuilt-client")
	equal(PVP.REF.players.b.readiness_choice.revision, 1)
	PVP.referee_on_entry_sync("b", intent(false, 10))
	equal(PVP.REF.players.b.is_ready, true)
	equal(PVP.REF.players.b.readiness_choice.client_id, "rebuilt-client")
end)

test("a changed entry invalidates answers from an earlier ready check", function()
	setup("pair")
	PVP.referee_on_entry_sync("a", intent(true))
	PVP.referee_on_entry_sync("b", intent(true))
	local check = last("pvp_ready_check")
	PVP.referee_on_ready_ack("a", check.nonce, true)
	PVP.referee_on_entry_sync("a", intent(true, 2, 12))
	PVP.referee_on_ready_ack("b", check.nonce, true)
	equal(starts(), 0)
	equal(PVP.REF.ready_check, nil)
end)

test("delayed Ready cannot undo Unready, nor can old Unready undo a newer Ready", function()
	setup("pair")
	PVP.referee_on_entry_sync("a", intent(true, 1))
	PVP.referee_on_entry_sync("a", intent(false, 2))
	PVP.referee_on_entry_sync("a", intent(true, 1))
	PVP.referee_on_entry_sync("a", intent(true, 2)) -- Contradicts the same revision.
	equal(PVP.REF.players.a.is_ready, false)
	PVP.referee_on_entry_sync("a", intent(true, 3))
	PVP.referee_on_entry_sync("a", intent(false, 2))
	equal(PVP.REF.players.a.is_ready, true)
end)

test("lost Unready retries and cancels an open check", function()
	setup("pair")
	G.STATE = G.STATES.BLIND_SELECT
	PVP.referee_on_entry_sync("a", intent(true))
	PVP.referee_on_entry_sync("b", intent(true))
	local check = last("pvp_ready_check")
	PVP.set_blind_readiness(true, 4)
	PVP.set_blind_readiness(false) -- Drop its initial send.
	retry_local("b")
	equal(PVP.REF.players.b.is_ready, false)
	PVP.referee_on_ready_ack("a", check.nonce, true)
	PVP.referee_on_ready_ack("b", check.nonce, true)
	fire_timeout()
	equal(starts(), 0)
end)

test("a lost current-client ready-check answer never counts as consent; retry reopens it", function()
	setup("pair")
	PVP.referee_on_entry_sync("a", intent(true))
	PVP.referee_on_entry_sync("b", intent(true))
	local check = last("pvp_ready_check")
	PVP.referee_on_ready_ack("a", check.nonce, true)
	fire_timeout()
	equal(starts(), 0)
	equal(PVP.REF.ready_check, nil)
	PVP.referee_on_entry_sync("b", intent(true))
	confirm_ready()
	equal(starts(), 1)
end)

test("different blinds cannot be confirmed together; stale intents cannot roll entry back", function()
	setup("pair")
	PVP.referee_on_entry_sync("a", intent(true, 1, 9))
	PVP.referee_on_entry_sync("b", intent(true, 1, 12))
	equal(messages("pvp_ready_check"), 0)
	PVP.referee_on_entry_sync("b", intent(true, 99, 9))
	equal(PVP.REF.players.b.readiness_choice.step, 12)
	PVP.referee_on_entry_sync("a", intent(true, 1, 12))
	confirm_ready()
	equal(starts(), 1)
end)

test("invalid, foreign-run and eliminated-player intents cannot change readiness", function()
	setup("pair", 3)
	for _, entry in ipairs({
		{ run_id = "old-run", step = 9, revision = 1, ready = true },
		{ run_id = "run-1", step = 0 / 0, revision = 1, ready = true },
		{ run_id = "run-1", client_id = "client", step = math.huge, revision = 1, ready = true },
		{ run_id = "run-1", step = 9, revision = -1, ready = true },
		{ run_id = "run-1", step = 9, revision = 1, ready = "yes" },
	}) do PVP.referee_on_entry_sync("b", entry) end
	PVP.REF.players.b.lives = 0
	PVP.referee_on_entry_sync("b", intent(true))
	PVP.referee_on_entry_sync("outsider", intent(true))
	equal(PVP.REF.players.b.is_ready, false)
	equal(PVP.REF.players.outsider, nil)
	equal(messages("pvp_ready_check"), 0)
end)

test("start delivery rejects wrong entries, unsafe screens and missing blind context", function()
	setup("pair")
	PVP.set_blind_readiness(true, 4)
	PVP.GAME.next_blind_context = {}
	local entered = 0
	PVP.dispatch_action = function() entered = entered + 1 end
	MPAPI.ActionType = function(def) MPAPI.ActionTypes[def.key] = def end
	dofile("pvp_api/actions/_helpers.lua")
	dofile("pvp_api/actions/blind_handshake.lua")
	lobby.is_host, lobby.player_id = false, "b"
	local start = { entry_id = "entry", round_id = "round",
		entries = { b = intent(true) }, starting_hands = {} }
	-- G.STATE starts in HAND_PLAYED.
	MPAPI.ActionTypes.pvp_start_blind:on_receive("a", start)
	equal(entered, 0)
	G.STATE = G.STATES.BLIND_SELECT
	start.entries.b.step = 12
	MPAPI.ActionTypes.pvp_start_blind:on_receive("a", start)
	equal(entered, 0)
	start.entries.b.step = 9
	PVP.GAME.next_blind_context = nil
	MPAPI.ActionTypes.pvp_start_blind:on_receive("a", start)
	equal(entered, 0)
	equal(PVP.GAME.round_sync, nil)
	PVP.GAME.next_blind_context = {}
	MPAPI.ActionTypes.pvp_start_blind:on_receive("a", start)
	equal(entered, 1)
	-- Entry deduplication also works when mixed-version scoring has no round_id.
	PVP.GAME.entry_sync.accepted_start_id = nil
	PVP.GAME.round_sync = nil
	start.entry_id, start.round_id = "mixed-entry", nil
	MPAPI.ActionTypes.pvp_start_blind:on_receive("a", start)
	MPAPI.ActionTypes.pvp_start_blind:on_receive("a", start)
	equal(entered, 2)
end)

test("old hosts see one legacy Ready, not repeated legacy Ready messages", function()
	setup("pair")
	G.STATE = G.STATES.BLIND_SELECT
	dofile("pvp_api/net.lua")
	PVP.net_route({ action = "readyBlind", startingHands = 4 })
	for _ = 1, 10 do Game:update(2) end
	equal(messages("pvp_ready_blind"), 1)
	equal(messages("pvp_entry_sync"), 10)
end)

test("entry retries stop on countdown, changed blind, eliminated player, run or lobby", function()
	setup("pair")
	G.STATE = G.STATES.BLIND_SELECT
	PVP.set_blind_readiness(true, 4)
	PVP.GAME.pvp_countdown_in_progress = true
	PVP.update_entry_sync(2)
	PVP.GAME.pvp_countdown_in_progress = nil
	G.GAME.round_resets.ante = 3
	PVP.update_entry_sync(2)
	G.GAME.round_resets.ante = 2
	PVP.GAME.eliminated = true
	PVP.update_entry_sync(2)
	PVP.GAME.eliminated = nil
	lobby._game.started.run_id = "run-2"
	PVP.update_entry_sync(2)
	lobby._game.started.run_id = "run-1"
	PVP.GAME.entry_sync.lobby = {}
	PVP.update_entry_sync(2)
	equal(messages("pvp_entry_sync"), 0)
end)

test("a start retained by the checkpoint recovers after host takeover", function()
	setup("pair", 3)
	for _, id in ipairs({ "a", "b", "c" }) do PVP.referee_on_entry_sync(id, intent(true)) end
	confirm_ready()
	local original = last("pvp_start_blind")
	leave("a")
	lobby.player_id = "b"
	equal(PVP.referee_take_over(), "checkpoint")
	PVP.referee_on_entry_sync("c", intent(true))
	equal(last("pvp_start_blind").entry_id, original.entry_id)
	equal(PVP.REF.round.id, original.entry_id)
end)

for _, mode in ipairs({ "pair", "royale", "nemesis_pairing", "team_based", "manhunt" }) do
	test(mode .. ": a duplicate Ready recovers a start without creating another round", function()
		setup(mode, mode == "pair" and 2 or 4)
		for _, player in ipairs(lobby.players) do
			PVP.referee_on_entry_sync(player.id, intent(true))
		end
		confirm_ready()
		local round = PVP.REF.round.id
		PVP.referee_on_entry_sync("b", intent(true))
		PVP.referee_on_entry_sync("b", intent(true))
		equal(PVP.REF.round.id, round)
		equal(last("pvp_start_blind").entry_id, round)
		equal(PVP.REF.players.b.is_ready, false)
	end)
end
