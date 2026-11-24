-- Run from the repo root: luajit tests/unit/lobby_screen_test.lua
-- pvp_api/ui/lobby.lua: what the lobby stage shows from literal views; Ready and Start are numbered
-- inputs; the button shows the server view, "waiting" while an input is unconfirmed; a refused Start is shown once.
local T = dofile("tests/support/check.lua")
local eq = T.eq

local sent, unconfirmed, refusals, applied, updates = {}, {}, {}, {}, 0
local function lobby_view(ready, start)
	return { me = "me", match = { stage = "lobby", lobby = { ready = ready, away = {}, start = start } } }
end

sendWarnMessage = function() end
localize = function(key) return key end
G = { C = { UI = { BACKGROUND_INACTIVE = "inactive" }, GREEN = "green", ORANGE = "orange" } }
MPAPI = { get_current_lobby = function() return { player_id = "me" } end }
local net = { view = nil }
net.send = function(kind, body)
	sent[#sent + 1] = { kind = kind, body = body }
	unconfirmed[kind] = true
	return #sent
end
net.waiting = function(kind) return unconfirmed[kind] == true end
net.add_view_listener = function(fn) net.listener = fn end
PVP = {
	READ = {},
	NET = setmetatable({ version_gate = { is_server_refusal = function() return false end } }, { __index = net }),
	LOBBY = { is_matchmaking = function() return false end },
	UI = {
		refusal = { show = function(reason) refusals[#refusals + 1] = reason end },
		lobby = { apply_ready = function(by_player, present) applied = { by_player = by_player, present = present } end, start_broadcasted = true, buttons = { ready_args = {}, ready = { update = function() updates = updates + 1 end } } },
	},
}
dofile("pvp_api/ui/lobby.lua")
local screen = PVP.UI.lobby
screen.install(net)

eq(screen.ready_state(), "waiting", "before the first view the button waits")
eq(screen.start_askable(), false, "and Start cannot be asked")
screen.press_ready()
eq(#sent, 0, "a press with no view sends nothing: it would be lost")

net.view = lobby_view({ me = false, opp = true })
net.listener(net.view)
eq(screen.ready_state(), "not_ready", "the view's state shows")
eq(PVP.UI.lobby.buttons.ready_args.label[1], "b_ready_cap", "the label follows the view")
eq(applied.present, 2, "the tally and the present count come from the view")
screen.press_ready()
eq(sent[1].kind, "lobbyReady", "a press is a lobbyReady input")
eq(sent[1].body.ready, true, "asking for the opposite of the view")
eq(screen.ready_state(), "waiting", "waiting while unconfirmed")
eq(PVP.UI.lobby.buttons.ready_args.label[1], "b_ready_waiting_cap", "the button says waiting")
screen.press_ready()
eq(#sent, 1, "no second press while waiting")

unconfirmed.lobbyReady = nil
net.view = lobby_view({ me = true, opp = true })
net.listener(net.view)
eq(screen.ready_state(), "ready", "confirmed: the view's Ready")
eq(PVP.UI.lobby.buttons.ready_args.label[1], "b_unready_cap", "and the button offers Unready")

-- Start: the answer comes back in the view, once.
screen.send_start({ stake = 1, options = {} })
eq(sent[2].kind, "lobbyStart", "Start is a lobbyStart input")
eq(screen.start_askable(), false, "no second Start while one waits")
unconfirmed.lobbyStart = nil
net.view = lobby_view({ me = true, opp = true }, { number = 2, refused = "too_few_players" })
net.listener(net.view)
eq(refusals[1], "too_few_players", "a refused Start is shown from the view")
eq(PVP.UI.lobby.start_broadcasted, false, "and the auto-start may look again")
net.listener(net.view)
eq(#refusals, 1, "the same answer is not shown twice")
eq(screen.start_askable(), true, "Start can be asked again")

-- Settings: the host's patch is a numbered lobbySettings input; a guest sends none; a local lobby (no
-- server) merges its own.
local before = #sent
screen.send_settings({ is_host = false }, { stake = "3" })
eq(#sent, before, "a guest sends no settings")
screen.send_settings({ is_host = true }, { stake = "3" })
eq(sent[#sent].kind, "lobbySettings", "the host's settings are a lobbySettings input")
eq(sent[#sent].body.settings.stake, "3", "carrying the patch")
local merged
screen.send_settings({ is_host = true, _local_mode = true, set_metadata = function(_, patch) merged = patch end }, { stake = "5" })
eq(merged.stake, "5", "a local lobby merges the patch itself")
eq(sent[#sent].body.settings.stake, "3", "and sends nothing")

-- Readers: what the lobby stage shows, from literal views.
local function reader_view(ready, away, start)
	return { me = "a", match = { stage = "lobby", lobby = { ready = ready, away = away or {}, start = start } } }
end

eq(screen.lobby_of(nil), nil, "no view, no lobby")
eq(screen.lobby_of({ match = { stage = "run", run = {} } }), nil, "another stage is not the lobby")
eq(screen.ready_state_of(nil, "a", false), "waiting", "no view: waiting, never a guess")
local view = reader_view({ a = false, b = true })
eq(screen.ready_state_of(view, "a", false), "not_ready", "the view says not ready")
eq(screen.ready_state_of(reader_view({ a = true, b = true }), "a", false), "ready", "the view says ready")
eq(screen.ready_state_of(view, "a", true), "waiting", "an unconfirmed Ready: waiting")
eq(screen.next_ready(view, "a"), true, "a press asks for the opposite")
eq(screen.next_ready(reader_view({ a = true }), "a"), false, "and back again")
eq(screen.next_ready(nil, "a"), true, "no view reads as not ready")
local by = screen.ready_by_player(view, { "a", "b" })
eq(by.a, false, "the tally follows the view (a)")
eq(by.b, true, "the tally follows the view (b)")
eq(screen.present_count(view), 2, "both seated players are here")
eq(screen.present_count(reader_view({ a = true, b = true }, { "b" })), 1, "an away player is not counted")
eq(screen.present_count(nil), 0, "no view, nobody")

local answered = reader_view({ a = true, b = true }, {}, { number = 3, refused = "not_all_ready" })
eq(screen.start_answer(answered, 3).refused, "not_all_ready", "the answer to my Start")
eq(screen.start_answer(answered, 4), nil, "an answer to another input is not mine")
eq(screen.start_answer(answered, nil), nil, "no Start asked, no answer read")
eq(screen.start_answer(reader_view({ a = true }), 3), nil, "no answer yet")
eq(screen.start_answer(reader_view({ a = true }, {}, { number = 3 }), 3).refused, nil, "an answer with no refusal")


T.done("lobby_screen_test")
