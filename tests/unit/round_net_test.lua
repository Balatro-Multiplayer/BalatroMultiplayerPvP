-- Run from the repo root: luajit tests/unit/round_net_test.lua
-- The shell around lib/round_facts.lua with a fake MPAPI: each fact is one request,
-- an ante run-out is a plain request, a PvP-timer answer lets the timer run out again, and the
-- hands the server counted for timer run-outs (timerLosses) come off once. Rows are named by rule.
local requests, logs, restored, state, lobby, handlers, spent, marks, run_loaded

local function setup()
	requests, logs, restored, state, handlers, spent, marks, run_loaded = {}, {}, {}, {}, {}, 0, nil, true
	lobby = { mod_id = "pvp", player_id = "u1", _game = { started = { run_id = "r1" } } }
	PVP = {
		id = "pvp",
		GAME = { timer_started = true, nemesis_timer_started = true },
		LOBBY = { config = {} },
		match_log = function(level, text)
			logs[#logs + 1] = level .. " " .. text
		end,
		current_ruleset = function()
			return {}
		end,
		is_pvp_boss = function()
			return true
		end,
		RunGate = {
			loaded = function()
				return run_loaded
			end,
		},
		HANDLERS = {
			handsSpent = function()
				-- As action_hands_spent: nothing with no hands left, else the effect once and 0 hands.
				if G.GAME.current_round.hands_left <= 0 then return end
				spent = spent + 1
				G.GAME.current_round.hands_left = 0
			end,
		},
		UI = {
			restore_timer = function(increment)
				restored[#restored + 1] = increment
			end,
		},
	}
	dofile("lib/pending_death.lua")
	dofile("lib/_state_value.lua")
	G = { GAME = { chips = 0, blind = { in_blind = true }, current_round = { hands_left = 7 } } }
	-- Whole-number scores only: the real compare is MPAPI.BigScore's, the shell just calls PVP.Score.
	MPAPI = {
		BigScore = {
			normalize = function(text)
				return text:match("^%d+$") and text or nil
			end,
			compare = function(a, b)
				a, b = tonumber(a), tonumber(b)
				return a < b and -1 or (a > b and 1 or 0)
			end,
			from_game_value = function(value)
				return string.format("%d", value)
			end,
			to_game_value = function(text)
				return tonumber(text)
			end,
		},
		request = function(kind, payload, on_result)
			requests[#requests + 1] = { kind = kind, payload = payload, on_result = on_result }
		end,
		get_state = function(key)
			return state[key]
		end,
		get_current_lobby = function()
			return lobby
		end,
		on_state = function(key, fn)
			handlers[key] = fn
		end,
	}
	dofile("lib/round_facts.lua")
	dofile("lib/round_end_view.lua")
	dofile("lib/score.lua")
	dofile("pvp_api/_net_basics.lua")
	dofile("pvp_api/round_net.lua")
end

local function equal(got, want)
	assert(got == want, ("got %s, wanted %s"):format(tostring(got), tostring(want)))
end

local failures = 0
local function test(name, fn)
	setup()
	local ok, err = pcall(fn)
	if ok then
		print("ok   " .. name)
	else
		failures = failures + 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end

test("R10/R28/R42/R12: each fact is one request with its payload", function()
	PVP.RoundNet.hand({ runId = "r1", roundId = 3, score = "5", handsLeft = 2 })
	PVP.RoundNet.blind({ runId = "r1", blindKey = "2:Big", beaten = false, roundLost = true })
	PVP.RoundNet.progress({ runId = "r1", ante = 2, furthestBlind = 4 })
	PVP.RoundNet.voucher({ runId = "r1", voucherKey = "v_mp_hieroglyph" })
	equal(#requests, 4)
	equal(requests[1].kind, "pvp.hand")
	equal(requests[1].payload.handsLeft, 2)
	equal(requests[2].kind, "pvp.blind")
	equal(requests[2].payload.roundLost, true)
	equal(requests[3].kind, "pvp.progress")
	equal(requests[4].kind, "pvp.voucher")
end)

test("R10 1585-1591: a refused plain request is logged and changes nothing else", function()
	PVP.RoundNet.hand({ runId = "r1", roundId = 3, score = "5", handsLeft = 2 })
	requests[1].on_result(false, { reason = "stale_hand" })
	equal(#logs, 1)
	assert(logs[1]:find("pvp.hand refused: stale_hand", 1, true))
	equal(G.GAME.current_round.hands_left, 7)
	requests[1].on_result(true, {})
	equal(#logs, 1)
end)

test("hand_commit: Play pressed is one request carrying what the caller built", function()
	PVP.RoundNet.hand_commit({ runId = "r1", roundId = 3, handsLeft = 2, timerLossesApplied = 1 })
	equal(#requests, 1)
	equal(requests[1].kind, "pvp.hand_commit")
	equal(requests[1].payload.runId, "r1")
	equal(requests[1].payload.roundId, 3)
	equal(requests[1].payload.handsLeft, 2)
	equal(requests[1].payload.timerLossesApplied, 1)
end)

test("hand_commit: a refusal is logged and takes no hand and changes no clock flag", function()
	PVP.RoundNet.hand_commit({ runId = "r1", roundId = 3, handsLeft = 2, timerLossesApplied = 0 })
	requests[1].on_result(false, { reason = "stale_hand" })
	assert(logs[1]:find("pvp.hand_commit refused: stale_hand", 1, true))
	equal(G.GAME.current_round.hands_left, 7)
	equal(PVP.GAME.timer_started, true)
	equal(PVP.GAME.nemesis_timer_started, true)
	equal(#restored, 0)
end)

test("the net has no run-out request: the server makes every run-out", function()
	equal(PVP.RoundNet.timer_loss, nil)
	equal(PVP.RoundNet.pvp_timer_loss, nil)
end)

-- The open round 3 of run r1 as the server's pvp.round shows it, with `losses` timer run-outs for u1.
local function open_round(losses, round_id)
	return {
		runId = "r1",
		roundId = round_id or 3,
		phase = "playing",
		players = { u1 = { timerLosses = losses, canTime = true }, u2 = { timerLosses = 8 } },
	}
end

local function in_round_3()
	PVP.current_run_id = function()
		return "r1"
	end
	PVP.GAME.round_id = 3
end

test("item 3: timer losses wait for a loaded run, then apply once from the frame", function()
	in_round_3()
	state["pvp.round"] = open_round(1)
	run_loaded = false
	handlers["pvp.round"]()
	equal(G.GAME.current_round.hands_left, 7)
	equal(PVP.RoundNet.applied_count("r1", 3), 0)
	PVP.RoundNet.after_rejoin()
	equal(G.GAME.current_round.hands_left, 7)
	PVP.RoundNet.update()
	equal(G.GAME.current_round.hands_left, 7)
	run_loaded = true
	PVP.RoundNet.update()
	equal(G.GAME.current_round.hands_left, 6)
	equal(PVP.RoundNet.applied_count("r1", 3), 1)
	PVP.RoundNet.update()
	equal(G.GAME.current_round.hands_left, 6)
end)

local HAND = { runId = "r1", roundId = 3, score = "44", handsLeft = 6, timerLossesApplied = 0 }
local function copy_with(args, fields)
	local out = {}
	for k, v in pairs(args) do
		out[k] = v
	end
	for k, v in pairs(fields) do
		out[k] = v
	end
	return out
end
local function hand_requests()
	local n = 0
	for _, r in ipairs(requests) do
		if r.kind == "pvp.hand" then n = n + 1 end
	end
	return n
end

test("item 6: a hand that timed out is sent again once after the rejoin snapshot", function()
	in_round_3()
	state["pvp.round"] = open_round(0)
	PVP.RoundNet.hand(HAND)
	requests[1].on_result(false, { reason = "timeout" })
	equal(hand_requests(), 1)
	PVP.RoundNet.update()
	equal(hand_requests(), 1)
	PVP.RoundNet.on_snapshot()
	PVP.RoundNet.update()
	equal(hand_requests(), 2)
	equal(requests[2].payload.score, "44")
	equal(requests[2].payload.handsLeft, 6)
	PVP.RoundNet.update()
	PVP.RoundNet.on_snapshot()
	PVP.RoundNet.update()
	equal(hand_requests(), 2)
end)

test("item 6: a hand answered before the drop is not sent again", function()
	in_round_3()
	state["pvp.round"] = open_round(0)
	PVP.RoundNet.hand(HAND)
	requests[1].on_result(true, {})
	PVP.RoundNet.on_snapshot()
	PVP.RoundNet.update()
	equal(hand_requests(), 1)
end)

test("item 6: a refused hand is not sent again, and one still waiting is left to the request layer", function()
	in_round_3()
	state["pvp.round"] = open_round(0)
	PVP.RoundNet.hand(HAND)
	requests[1].on_result(false, { reason = "stale_hand" })
	PVP.RoundNet.on_snapshot()
	PVP.RoundNet.update()
	equal(hand_requests(), 1)
	PVP.RoundNet.hand(copy_with(HAND, { handsLeft = 5 }))
	PVP.RoundNet.on_snapshot()
	PVP.RoundNet.update()
	equal(hand_requests(), 2)
end)

test("item 6: only the newest unanswered hand goes again, never a queue", function()
	in_round_3()
	state["pvp.round"] = open_round(0)
	PVP.RoundNet.hand(HAND)
	PVP.RoundNet.hand(copy_with(HAND, { score = "161", handsLeft = 5 }))
	requests[1].on_result(false, { reason = "timeout" })
	requests[2].on_result(false, { reason = "timeout" })
	PVP.RoundNet.on_snapshot()
	PVP.RoundNet.update()
	equal(hand_requests(), 3)
	equal(requests[3].payload.score, "161")
	equal(requests[3].payload.handsLeft, 5)
end)

test("item 6: a later hand that was answered covers an earlier one that timed out", function()
	in_round_3()
	state["pvp.round"] = open_round(0)
	PVP.RoundNet.hand(HAND)
	requests[1].on_result(false, { reason = "timeout" })
	PVP.RoundNet.hand(copy_with(HAND, { score = "161", handsLeft = 5 }))
	requests[2].on_result(true, {})
	PVP.RoundNet.on_snapshot()
	PVP.RoundNet.update()
	equal(hand_requests(), 2)
end)

test("item 6: a hand of a round that is over, or of another run, is dropped, not sent", function()
	in_round_3()
	state["pvp.round"] = open_round(0)
	PVP.RoundNet.hand(HAND)
	requests[1].on_result(false, { reason = "timeout" })
	state["pvp.round"] = { runId = "r1", roundId = 3, phase = "over", players = {} }
	PVP.RoundNet.on_snapshot()
	PVP.RoundNet.update()
	equal(hand_requests(), 1)
	state["pvp.round"] = open_round(0)
	PVP.RoundNet.on_snapshot()
	PVP.RoundNet.update()
	equal(hand_requests(), 1)
end)

test("item 6: a hand that times out after the snapshot is still sent again", function()
	in_round_3()
	state["pvp.round"] = open_round(0)
	PVP.RoundNet.hand(HAND)
	PVP.RoundNet.on_snapshot()
	PVP.RoundNet.update()
	PVP.RoundNet.update()
	equal(hand_requests(), 1)
	requests[1].on_result(false, { reason = "timeout" })
	PVP.RoundNet.update()
	equal(hand_requests(), 2)
	PVP.RoundNet.update()
	equal(hand_requests(), 2)
end)

test("item 6: H1 timed out, H2 still pending (its commit was delivered): only H2 is ever sent again", function()
	-- The request layer resends H2 itself on the snapshot. H1 is not resent here: a hand_commit that was
	-- delivered binds the server to H1's count, and the server clears that commit when H2 (fewer hands
	-- left than the committed count) arrives. That is a server rule, a separate change.
	in_round_3()
	state["pvp.round"] = open_round(0)
	PVP.RoundNet.hand(HAND)
	requests[1].on_result(false, { reason = "timeout" })
	PVP.RoundNet.hand(copy_with(HAND, { score = "161", handsLeft = 5 }))
	PVP.RoundNet.on_snapshot()
	PVP.RoundNet.update()
	equal(hand_requests(), 2)
	requests[2].on_result(false, { reason = "timeout" })
	PVP.RoundNet.update()
	equal(hand_requests(), 3)
	equal(requests[3].payload.handsLeft, 5)
	PVP.RoundNet.update()
	equal(hand_requests(), 3)
end)

test("item 6: a lobby run that is gone or another run's stops the resend though the state still shows the round", function()
	for _, current in ipairs({ false, "r2" }) do
		in_round_3()
		state["pvp.round"] = open_round(0)
		PVP.RoundNet.hand(HAND)
		local before = hand_requests()
		requests[#requests].on_result(false, { reason = "timeout" })
		PVP.current_run_id = function()
			return current or nil
		end
		PVP.RoundNet.on_snapshot()
		PVP.RoundNet.update()
		equal(hand_requests(), before)
	end
end)

test("item 6: the resend waits for a loaded run", function()
	in_round_3()
	state["pvp.round"] = open_round(0)
	PVP.RoundNet.hand(HAND)
	requests[1].on_result(false, { reason = "timeout" })
	run_loaded = false
	PVP.RoundNet.on_snapshot()
	PVP.RoundNet.update()
	equal(hand_requests(), 1)
	run_loaded = true
	PVP.RoundNet.update()
	equal(hand_requests(), 2)
end)

test("timerLosses from the server take that many hands off, once, across repeated pushes", function()
	in_round_3()
	state["pvp.round"] = open_round(1)
	handlers["pvp.round"]()
	equal(G.GAME.current_round.hands_left, 6)
	handlers["pvp.round"]()
	handlers["pvp.round"]()
	equal(G.GAME.current_round.hands_left, 6)
	state["pvp.round"] = open_round(2)
	handlers["pvp.round"]()
	equal(G.GAME.current_round.hands_left, 5)
end)

test("a rejoin takes the same run-outs again only when the hands were rebuilt without them", function()
	in_round_3()
	state["pvp.round"] = open_round(1)
	PVP.RoundNet.after_rejoin()
	equal(G.GAME.current_round.hands_left, 6)
	-- A second rejoin in this process: the record says it is applied, nothing more comes off.
	PVP.RoundNet.after_rejoin()
	equal(G.GAME.current_round.hands_left, 6)
end)

test("the applied count is in G.GAME, so a crash rejoin that restores the save takes nothing off twice", function()
	in_round_3()
	state["pvp.round"] = open_round(1)
	equal(PVP.RoundNet.applied_count("r1", 3), 0)
	handlers["pvp.round"]()
	equal(G.GAME.current_round.hands_left, 6)
	equal(PVP.RoundNet.applied_count("r1", 3), 1)
	-- A new process loads the saved G.GAME (hands and count together): the module holds no record.
	local saved = G.GAME
	local run, round_id = PVP.current_run_id, PVP.GAME.round_id
	setup()
	G.GAME = saved
	PVP.current_run_id = run
	PVP.GAME.round_id = round_id
	state["pvp.round"] = open_round(1)
	PVP.RoundNet.after_rejoin()
	equal(G.GAME.current_round.hands_left, 6)
	equal(PVP.RoundNet.applied_count("r1", 3), 1)
	-- A loss after the rejoin still takes its hand.
	state["pvp.round"] = open_round(2)
	PVP.RoundNet.after_rejoin()
	equal(G.GAME.current_round.hands_left, 5)
	equal(PVP.RoundNet.applied_count("r1", 3), 2)
end)

test("a Blind Select crash save with server timerLosses 1 ends at hands 6, count 1, once", function()
	in_round_3()
	-- The save was taken before the run-out: full hands, and no record or one of an earlier round.
	G.GAME.pvp_timer_losses_applied = { run = "r1", round = 2, count = 4 }
	state["pvp.round"] = open_round(1)
	PVP.RoundNet.after_rejoin()
	equal(G.GAME.current_round.hands_left, 6)
	equal(PVP.RoundNet.applied_count("r1", 3), 1)
	PVP.RoundNet.after_rejoin()
	handlers["pvp.round"]()
	equal(G.GAME.current_round.hands_left, 6)
	equal(PVP.RoundNet.applied_count("r1", 3), 1)
	setup()
	in_round_3()
	state["pvp.round"] = open_round(1)
	PVP.RoundNet.after_rejoin()
	equal(G.GAME.current_round.hands_left, 6)
	PVP.RoundNet.after_rejoin()
	equal(G.GAME.current_round.hands_left, 6)
end)

test("the applied count belongs to its round: another round or run counts none", function()
	in_round_3()
	state["pvp.round"] = open_round(2)
	handlers["pvp.round"]()
	equal(PVP.RoundNet.applied_count("r1", 3), 2)
	equal(PVP.RoundNet.applied_count("r1", 4), 0)
	equal(PVP.RoundNet.applied_count("r2", 3), 0)
end)

test("the hands never go below zero", function()
	in_round_3()
	G.GAME.current_round.hands_left = 1
	state["pvp.round"] = open_round(3)
	handlers["pvp.round"]()
	equal(G.GAME.current_round.hands_left, 0)
end)

test("no hands come off outside my open PvP round", function()
	in_round_3()
	local resolved = open_round(2)
	resolved.phase = "resolved"
	state["pvp.round"] = resolved
	handlers["pvp.round"]()
	equal(G.GAME.current_round.hands_left, 7)
	state["pvp.round"] = open_round(2, 4)
	handlers["pvp.round"]()
	equal(G.GAME.current_round.hands_left, 7)
	state["pvp.round"] = nil
	handlers["pvp.round"]()
	equal(G.GAME.current_round.hands_left, 7)
end)

test("no hands come off when the hands are not a number yet", function()
	in_round_3()
	G.GAME.current_round.hands_left = nil
	state["pvp.round"] = open_round(2)
	handlers["pvp.round"]()
	equal(G.GAME.current_round.hands_left, nil)
end)

-- The entry as view.ts roundOf projects it (there is no handsDone key on the wire).
local function with_entry(fields)
	local entry = {
		score = "0",
		handsLeft = 4,
		highestScore = "0",
		ante = 1,
		furthestBlind = 1,
		timerLosses = 0,
		handsSpent = false,
		canTime = true,
	}
	for key, value in pairs(fields) do
		entry[key] = value
	end
	local round = open_round(0)
	round.players.u1 = entry
	state["pvp.round"] = round
end

-- RoundEndNet's evaluation: what RoundEndView asks for, run through the handler with its marks kept.
local function evaluate_round_end()
	local commands, applied = PVP.RoundEndView.decide({
		round_value = state["pvp.round"],
		me = "u1",
		run_id = "r1",
		applied = marks,
		eliminated = false,
		current = { round_id = 3, in_pvp_blind = true },
		hands_left = G.GAME.current_round.hands_left,
	})
	marks = applied
	for _, command in ipairs(commands) do
		if command.kind == "hands_spent" then PVP.HANDLERS.handsSpent() end
	end
end

test("G6: a rejoin with 4 hands and 0 chips takes the server's 2 hands and score 300", function()
	in_round_3()
	G.GAME.current_round.hands_left = 4
	with_entry({ handsLeft = 2, score = "300" })
	PVP.RoundNet.after_rejoin()
	equal(G.GAME.current_round.hands_left, 2)
	equal(G.GAME.chips, 300)
	equal(spent, 0)
end)

test("G6: a server score under the local one keeps the local chips", function()
	in_round_3()
	G.GAME.chips = 500
	with_entry({ handsLeft = 2, score = "300" })
	PVP.RoundNet.after_rejoin()
	equal(G.GAME.chips, 500)
	equal(G.GAME.current_round.hands_left, 2)
end)

test("G6: no handsLeft, no handsSpent or no entry changes nothing and logs it", function()
	in_round_3()
	G.GAME.current_round.hands_left = 4
	with_entry({ handsLeft = false, score = "300" })
	PVP.RoundNet.after_rejoin()
	equal(G.GAME.current_round.hands_left, 4)
	equal(G.GAME.chips, 0)
	equal(#logs, 1)
	assert(logs[1]:find("server handsLeft unknown", 1, true))
	with_entry({ handsLeft = 2, handsSpent = false })
	state["pvp.round"].players.u1.handsSpent = nil
	PVP.RoundNet.after_rejoin()
	equal(G.GAME.current_round.hands_left, 4)
	assert(logs[2]:find("server handsSpent unknown", 1, true))
	state["pvp.round"].players.u1 = nil
	PVP.RoundNet.after_rejoin()
	equal(G.GAME.current_round.hands_left, 4)
	assert(logs[3]:find("no server entry", 1, true))
	equal(spent, 0)
end)

test("G6: another round or a resolved round is not taken", function()
	in_round_3()
	G.GAME.current_round.hands_left = 4
	with_entry({ handsLeft = 2 })
	state["pvp.round"].roundId = 4
	PVP.RoundNet.after_rejoin()
	equal(G.GAME.current_round.hands_left, 4)
end)

test("G6: at blind select nothing is taken", function()
	in_round_3()
	G.GAME.blind.in_blind = false
	G.GAME.current_round.hands_left = 4
	with_entry({ handsLeft = 0, score = "300" })
	PVP.RoundNet.after_rejoin()
	equal(G.GAME.current_round.hands_left, 4)
	equal(G.GAME.chips, 0)
	equal(spent, 0)
end)

test("G6: handsLeft 0 with handsSpent false runs the hands-spent effect once and ends on 0 hands", function()
	in_round_3()
	G.GAME.current_round.hands_left = 4
	with_entry({ handsLeft = 0, handsSpent = false, score = "300" })
	PVP.RoundNet.after_rejoin()
	equal(spent, 1)
	equal(G.GAME.current_round.hands_left, 0)
	equal(G.GAME.chips, 300)
	-- RoundEndNet needs handsSpent true: it adds nothing.
	evaluate_round_end()
	equal(spent, 1)
end)

test("G6: handsSpent true leaves the hands to RoundEndNet: one effect, rejoin first", function()
	in_round_3()
	G.GAME.current_round.hands_left = 4
	with_entry({ handsLeft = 2, handsSpent = true, score = "300" })
	PVP.RoundNet.after_rejoin()
	equal(spent, 0)
	equal(G.GAME.current_round.hands_left, 4)
	equal(G.GAME.chips, 300)
	evaluate_round_end()
	evaluate_round_end()
	equal(spent, 1)
	equal(G.GAME.current_round.hands_left, 0)
end)

test("G6: handsSpent true, RoundEndNet first: one effect, hands stay 0", function()
	in_round_3()
	G.GAME.current_round.hands_left = 4
	with_entry({ handsLeft = 2, handsSpent = true })
	evaluate_round_end()
	PVP.RoundNet.after_rejoin()
	evaluate_round_end()
	equal(spent, 1)
	equal(G.GAME.current_round.hands_left, 0)
end)

test("the net draws nothing from the opponent's state", function()
	equal(PVP.GAME.enemy, nil)
end)

print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
