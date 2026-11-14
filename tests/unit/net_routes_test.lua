-- Run from the repo root: luajit tests/unit/net_routes_test.lua
-- pvp_api/net.lua routes: every fact a duel produces is a request to the server
-- through PVP.RoundNet / PVP.ResultNet, and only the relay-kept pvp_* actions are sent.
local requests, actions, roundnet, resultnet, current, chats, winner_hook, state, deadline_n, applied_count, logs

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

-- Function bodies of the real handlers, without loading the whole socket-era file.
local function load_handler(name)
	local text = read("networking/action_handlers.lua"):gsub("\r\n", "\n")
	local body = text:match("\nfunction " .. name:gsub("%.", "%%.") .. "%b().-\nend\n")
	assert(body, name .. " not found")
	assert(loadstring(body, "=" .. name))()
end

local function setup()
	requests, actions, roundnet, resultnet, chats, winner_hook, logs = {}, {}, {}, {}, {}, nil, {}
	-- The n of the server deadline the timer box shows.
	deadline_n = 6
	-- The server timer losses this client had already taken off its hands.
	applied_count = 2
	-- The server has this client's round 7 open.
	state = { ["pvp.round"] = { runId = "r-1", roundId = 7, phase = "playing" } }
	current = {
		mod_id = "pvp",
		player_id = "u1",
		is_host = true,
		_game = { started = { run_id = "r-1" } },
		action = function(_, at)
			return {
				broadcast = function(_, params)
					actions[#actions + 1] = { key = at.key, params = params }
				end,
			}
		end,
	}
	local function recorder(into, kind)
		return function(args)
			into[#into + 1] = { kind = kind, args = args }
		end
	end
	PVP = {
		id = "pvp",
		GAME = { round_id = 7, furthest_blind = 2 },
		LOBBY = { config = {}, deck = {}, roster = {} },
		ACTIONS = {},
		match_log = function(level, text)
			logs[#logs + 1] = level .. " " .. text
		end,
		TimerNet = {
			deadline_n = function()
				return deadline_n
			end,
		},
		Score = {
			from_game_value = function(s)
				return s
			end,
		},
		RoundNet = {
			hand = recorder(roundnet, "hand"),
			applied_count = function()
				return applied_count
			end,
			blind = recorder(roundnet, "blind"),
			hand_commit = recorder(roundnet, "hand_commit"),
			progress = recorder(roundnet, "progress"),
			voucher = recorder(roundnet, "voucher"),
		},
		ResultNet = {
			forfeit = function()
				resultnet[#resultnet + 1] = { kind = "forfeit" }
			end,
			vote = recorder(resultnet, "vote"),
		},
		report_roster_result = function() end,
		dispatch_action = function() end,
		ReadyNet = { request_ready = function() end, request_unready = function() end },
	}
	dofile("lib/pending_death.lua")
	dofile("lib/_state_value.lua")
	dofile("lib/round_facts.lua")
	G = {
		C = { BLUE = {} },
		GAME = {
			blind_on_deck = "Big",
			round_resets = { ante = 3, blind_states = { Boss = "Upcoming" } },
			current_round = { hands_left = 2 },
			skips = 0,
		},
	}
	MPAPI = {
		ActionTypes = {},
		OPCODE = {},
		get_current_lobby = function()
			return current
		end,
		get_state = function(key)
			return state[key]
		end,
		request = function(kind, payload)
			requests[#requests + 1] = { kind = kind, payload = payload }
		end,
		ActionType = function(def)
			MPAPI.ActionTypes[def.key] = def
		end,
		chat = {
			addMessage = function(text)
				chats[#chats + 1] = text
			end,
		},
		on_winner_declared = function(fn)
			winner_hook = fn
		end,
		GameMode = function() end,
	}
	setmetatable(MPAPI.ActionTypes, {
		__index = function(_, k)
			return { key = k }
		end,
	})
	localize = function()
		return nil
	end
	dofile("pvp_api/_net_basics.lua")
	dofile("pvp_api/net.lua")
	load_handler("PVP.ACTIONS.blind_result")
	load_handler("PVP.ACTIONS.fail_round")
	load_handler("PVP.ACTIONS.hand_commit")
	dofile("pvp_api/run_actions.lua")
end

-- The pvp_* keys net.lua still relays between peers; any other pvp_* send is a dropped action.
local RELAY_KEYS = {
	pvp_location = true,
	pvp_get_end_game_jokers = true,
	pvp_receive_end_game_jokers = true,
	pvp_get_nemesis_deck = true,
	pvp_receive_nemesis_deck = true,
	pvp_end_game_stats_requested = true,
	pvp_nemesis_end_game_stats = true,
}

local function only_relay_actions()
	for _, a in ipairs(actions) do
		assert(RELAY_KEYS[a.key], "sent dropped action " .. a.key)
	end
	equal(#requests, 0)
end

test("a full duel sends only relay-kept pvp_* actions and the facts reach the server nets", function()
	setup()
	for _, msg in ipairs({
		{ action = "newRound" },
		{ action = "setAnte", ante = 3 },
		{ action = "setFurthestBlind", furthestBlind = 2 },
		{ action = "playHand", score = "100", handsLeft = 1 },
		{ action = "skip", skips = 1 },
		{ action = "blindResult", ante = 3, blind = "Small", beaten = true },
		{ action = "handCommit", handsLeft = 1 },
	}) do
		PVP.net_route(msg)
	end
	PVP.ACTIONS.fail_round(2)
	PVP.ACTIONS.hand_commit(1)
	only_relay_actions()
	assert(#roundnet > 0, "facts must reach the server nets")
end)

test("the timer relays are gone: the old timer messages send nothing", function()
	setup()
	for _, action in ipairs({ "startAnteTimer", "restartAnteTimer", "pauseAnteTimer" }) do
		PVP.net_route({ action = action, time = 90 })
	end
	equal(#actions, 0)
	equal(#requests, 0)
	equal(#roundnet, 0)
end)

test("playHand is one hand fact with the round", function()
	setup()
	PVP.net_route({ action = "playHand", score = "100", handsLeft = 1 })
	equal(#roundnet, 1)
	equal(roundnet[1].kind, "hand")
	equal(roundnet[1].args.runId, "r-1")
	equal(roundnet[1].args.roundId, 7)
	equal(roundnet[1].args.score, "100")
	equal(roundnet[1].args.handsLeft, 1)
end)

test("a hand states how many server timer losses were already taken off when it was counted", function()
	setup()
	PVP.net_route({ action = "playHand", score = "100", handsLeft = 1 })
	equal(roundnet[1].args.timerLossesApplied, 2)
	applied_count = 0
	PVP.net_route({ action = "playHand", score = "200", handsLeft = 1 })
	equal(roundnet[2].args.timerLossesApplied, 0)
end)

test("the blind-select hand of a normal blind before any PvP round is not sent", function()
	setup()
	PVP.GAME.round_id = nil
	state["pvp.round"] = { runId = "r-1", roundId = 0, phase = "shop" }
	PVP.net_route({ action = "playHand", score = "0", handsLeft = 4 })
	equal(#roundnet, 0)
end)

test("a hand after the round resolved is not sent", function()
	setup()
	state["pvp.round"].phase = "resolved"
	PVP.net_route({ action = "playHand", score = "0", handsLeft = 4 })
	equal(#roundnet, 0)
end)

test("no open run drops the fact", function()
	setup()
	current._game = {}
	PVP.net_route({ action = "playHand", score = "100", handsLeft = 1 })
	equal(#roundnet, 0)
end)

test("handCommit is one hand_commit fact with the round and the timer losses already taken off", function()
	setup()
	PVP.net_route({ action = "handCommit", handsLeft = 3 })
	equal(#roundnet, 1)
	equal(roundnet[1].kind, "hand_commit")
	equal(roundnet[1].args.runId, "r-1")
	equal(roundnet[1].args.roundId, 7)
	equal(roundnet[1].args.handsLeft, 3)
	equal(roundnet[1].args.timerLossesApplied, 2)
end)

test("a handCommit before any PvP round, or after the round resolved, is not sent", function()
	setup()
	state["pvp.round"].phase = "resolved"
	PVP.net_route({ action = "handCommit", handsLeft = 3 })
	equal(#roundnet, 0)
end)

test("PVP.ACTIONS.hand_commit routes the hands left after this hand", function()
	setup()
	PVP.ACTIONS.hand_commit(2)
	equal(roundnet[1].kind, "hand_commit")
	equal(roundnet[1].args.handsLeft, 2)
end)

test("the run-out relays are gone: the client reports no run-out of any kind", function()
	setup()
	equal(PVP.ACTIONS.fail_timer, nil)
	equal(PVP.ACTIONS.fail_pvp_timer, nil)
	PVP.net_route({ action = "failTimer", kind = "ante" })
	PVP.net_route({ action = "failPvPTimer" })
	equal(#roundnet, 0)
	equal(#requests, 0)
end)

test("failRound is a blind fact with roundLost", function()
	setup()
	PVP.ACTIONS.fail_round(2)
	equal(#roundnet, 1)
	equal(roundnet[1].kind, "blind")
	equal(roundnet[1].args.roundLost, true)
	equal(roundnet[1].args.beaten, false)
	equal(roundnet[1].args.blindKey, "3:Big")
end)

test("blindResult is a blind fact without roundLost", function()
	setup()
	PVP.net_route({ action = "blindResult", ante = 3, blind = "Small", beaten = true })
	equal(roundnet[1].kind, "blind")
	equal(roundnet[1].args.beaten, true)
	equal(roundnet[1].args.roundLost, false)
	equal(roundnet[1].args.blindKey, "3:Small")
end)

test("setAnte and setFurthestBlind are progress facts; ante 0 is dropped", function()
	setup()
	PVP.net_route({ action = "setAnte", ante = 0 })
	equal(#roundnet, 0)
	PVP.net_route({ action = "setAnte", ante = 3 })
	equal(roundnet[1].kind, "progress")
	equal(roundnet[1].args.ante, 3)
	equal(roundnet[1].args.furthestBlind, 2)
	PVP.net_route({ action = "setFurthestBlind", furthestBlind = 5 })
	equal(roundnet[2].args.furthestBlind, 5)
	equal(roundnet[2].args.ante, 3)
end)

test("setAnte is sent only once the furthest blind is known, and never as 0", function()
	setup()
	PVP.GAME.furthest_blind = nil
	PVP.net_route({ action = "setAnte", ante = 3 })
	equal(#roundnet, 0)
	PVP.GAME.furthest_blind = 0
	PVP.net_route({ action = "setAnte", ante = 3 })
	equal(roundnet[1].args.furthestBlind, 0)
end)

test("forfeit and votes go through the result net", function()
	setup()
	PVP.pvp_forfeit()
	equal(resultnet[1].kind, "forfeit")
	PVP.cast_seed_vote()
	PVP.cast_draw_vote()
	equal(resultnet[2].args.kind, "seed")
	equal(resultnet[2].args.yes, true)
	equal(resultnet[3].args.kind, "draw")
	equal(resultnet[3].args.runId, "r-1")
	equal(#actions, 0)
end)

test("a team pick is a pvp.team request", function()
	setup()
	dofile("pvp_api/actions/_helpers.lua")
	dofile("pvp_api/actions/team_manhunt.lua")
	PVP.pvp_set_team(2)
	equal(requests[1].kind, "pvp.team")
	equal(requests[1].payload.team, 2)
	equal(PVP.LOBBY.team_id, 2)
end)

test("a manhunt voucher loses its suffix on the way to the server", function()
	setup()
	dofile("pvp_api/actions/_helpers.lua")
	dofile("pvp_api/actions/team_manhunt.lua")
	PVP.pvp_redeem_ante_voucher("v_mp_hieroglyph_manhunt")
	equal(roundnet[1].kind, "voucher")
	equal(roundnet[1].args.voucherKey, "v_mp_hieroglyph")
end)

test("a winner declared on the client broadcasts nothing", function()
	setup()
	dofile("pvp_api/gamemodes.lua")
	assert(winner_hook, "on_winner_declared was not hooked")
	winner_hook("u2")
	equal(#actions, 0)
end)

test("deathPending and eliminated are exported and apply the server's facts", function()
	setup()
	local src = read("networking/action_handlers.lua"):gsub("\r\n", "\n")
	assert(src:find("deathPending = action_death_pending", 1, true))
	assert(src:find("eliminated = action_eliminated", 1, true))
	local function local_fn(name)
		local body = src:match("\nlocal function " .. name .. "%b().-\nend\n")
		assert(body, name .. " not found")
		return assert(loadstring(body .. "\nreturn " .. name, "=" .. name))()
	end
	PVP.self_player_id = function()
		return "u1"
	end
	local shown = {}
	PVP.UI = {
		show_pending_death_screen = function()
			shown[#shown + 1] = "screen"
		end,
		show_pending_death_notice = function()
			shown[#shown + 1] = "notice"
		end,
	}
	local death_pending = local_fn("action_death_pending")
	death_pending({ player_id = "u1", opponent_id = "u2", blind_key = "3:Big" })
	equal(shown[1], "screen")
	equal(PVP.GAME.pending_death.blind_key, "3:Big")
	death_pending({ player_id = "u2", opponent_id = "u1", blind_key = "3:Big" })
	equal(shown[2], "notice")
	-- A run-out death has no blind (blind_key nil): the notice still shows, without error.
	death_pending({ player_id = "u2", blind_key = nil })
	equal(shown[3], "notice")
	local lost = {}
	PVP.end_pending_death = function() end
	PVP.dispatch_action = function(name)
		lost[#lost + 1] = name
	end
	local eliminated = local_fn("action_eliminated")
	eliminated({ player_id = "u2" })
	equal(#lost, 0)
	eliminated({ player_id = "u1" })
	equal(lost[1], "loseGame")
	equal(PVP.GAME.eliminated, true)
end)

test("vote counts show once per change", function()
	setup()
	current.get_players = function()
		return { { id = "u1" }, { id = "u2" } }
	end
	PVP.show_vote_counts({ draw = 1, seed = 0 }, "r-1")
	PVP.show_vote_counts({ draw = 1, seed = 0 }, "r-1")
	equal(#chats, 1)
	assert(chats[1]:find("1/2", 1, true), chats[1])
	PVP.show_vote_counts({ draw = 0, seed = 0 }, "r-1")
	equal(#chats, 1)
end)

test("the vote counts start again from 0 in a new run", function()
	setup()
	current.get_players = function()
		return { { id = "u1" }, { id = "u2" } }
	end
	PVP.show_vote_counts({ draw = 1, seed = 0 }, "r-1")
	equal(#chats, 1)
	PVP.show_vote_counts({ draw = 1, seed = 0 }, "r-2")
	equal(#chats, 2)
	PVP.show_vote_counts({ draw = 1, seed = 0 }, "r-2")
	equal(#chats, 2)
end)

test("a reconnect at game end (no run id) does not print the shown counts again", function()
	setup()
	current.get_players = function()
		return { { id = "u1" }, { id = "u2" } }
	end
	PVP.show_vote_counts({ draw = 1, seed = 0 }, "r-1")
	equal(#chats, 1)
	PVP.show_vote_counts({ draw = 1, seed = 0 }, nil)
	equal(#chats, 1)
	PVP.show_vote_counts({ draw = 1, seed = 0 }, "r-1")
	equal(#chats, 1)
end)

if failures > 0 then os.exit(1) end
