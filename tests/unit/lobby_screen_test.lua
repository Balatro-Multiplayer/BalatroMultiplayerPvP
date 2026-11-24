-- Run from the repo root: luajit tests/unit/lobby_screen_test.lua
-- pvp_api/lobby_screen.lua: Ready and Start are numbered inputs; the button shows the server's view,
-- "waiting" while an input is unconfirmed; a refused Start is shown once, from the view.
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

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
	match_net = net,
	VersionGate = { is_server_refusal = function() return false end },
	refusal_screen = { show = function(reason) refusals[#refusals + 1] = reason end },
	apply_ready_view = function(by_player, present) applied = { by_player = by_player, present = present } end,
	is_matchmaking = function() return false end,
	lobby = { start_broadcasted = true, buttons = { ready_args = {}, ready = { update = function() updates = updates + 1 end } } },
}
dofile("pvp_api/lobby_reader.lua")
dofile("pvp_api/lobby_screen.lua")
local screen = PVP.lobby_screen
screen.install(net)

eq(screen.ready_state(), "waiting", "before the first view the button waits")
eq(screen.start_askable(), false, "and Start cannot be asked")
screen.press_ready()
eq(#sent, 0, "a press with no view sends nothing: it would be lost")

net.view = lobby_view({ me = false, opp = true })
net.listener(net.view)
eq(screen.ready_state(), "not_ready", "the view's state shows")
eq(PVP.lobby.buttons.ready_args.label[1], "b_ready_cap", "the label follows the view")
eq(applied.present, 2, "the tally and the present count come from the view")
screen.press_ready()
eq(sent[1].kind, "lobbyReady", "a press is a lobbyReady input")
eq(sent[1].body.ready, true, "asking for the opposite of the view")
eq(screen.ready_state(), "waiting", "waiting while unconfirmed")
eq(PVP.lobby.buttons.ready_args.label[1], "b_ready_waiting_cap", "the button says waiting")
screen.press_ready()
eq(#sent, 1, "no second press while waiting")

unconfirmed.lobbyReady = nil
net.view = lobby_view({ me = true, opp = true })
net.listener(net.view)
eq(screen.ready_state(), "ready", "confirmed: the view's Ready")
eq(PVP.lobby.buttons.ready_args.label[1], "b_unready_cap", "and the button offers Unready")

-- Start: the answer comes back in the view, once.
screen.send_start({ stake = 1, options = {} })
eq(sent[2].kind, "lobbyStart", "Start is a lobbyStart input")
eq(screen.start_askable(), false, "no second Start while one waits")
unconfirmed.lobbyStart = nil
net.view = lobby_view({ me = true, opp = true }, { number = 2, refused = "too_few_players" })
net.listener(net.view)
eq(refusals[1], "too_few_players", "a refused Start is shown from the view")
eq(PVP.lobby.start_broadcasted, false, "and the auto-start may look again")
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

print(string.format("lobby_screen_test: ok (%d checks)", checks))
