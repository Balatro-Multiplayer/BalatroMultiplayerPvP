-- The lobby stage on screen: the Ready and Start buttons and the Ready tally. Ready and Start go up as
-- numbered inputs (net, kinds lobbyReady and lobbyStart); everything shown comes from the server's
-- view, plus "waiting" while an input is not yet confirmed. No local copy of Ready. The readers below take a
-- view and give plain facts: who is Ready, what the Ready button says, and the answer to a Start.
local screen = PVP.UI.lobby or {}
PVP.UI.lobby = screen

-- The lobby part of a view, nil in any other stage (and before the first view).
function screen.lobby_of(view)
	local match = type(view) == "table" and view.match
	if type(match) ~= "table" or match.stage ~= "lobby" or type(match.lobby) ~= "table" then return nil end
	return match.lobby
end

-- True when the view says this player is Ready; nil-safe, false with no view.
function screen.is_ready(view, player_id)
	local lobby = screen.lobby_of(view)
	return lobby ~= nil and type(lobby.ready) == "table" and lobby.ready[player_id] == true
end

-- "waiting" while there is no lobby view or a Ready is unconfirmed; else the view's state:
-- "ready" (shown as Unready to press) or "not_ready".
function screen.ready_state_of(view, player_id, ready_unconfirmed)
	if screen.lobby_of(view) == nil or ready_unconfirmed then return "waiting" end
	return screen.is_ready(view, player_id) and "ready" or "not_ready"
end

-- What a press asks the server for, from the view: the opposite of what it shows.
function screen.next_ready(view, player_id)
	return not screen.is_ready(view, player_id)
end

-- The tally the Start button and the auto-start read: every present player's Ready, as the view has it.
function screen.ready_by_player(view, player_ids)
	local out = {}
	for _, id in ipairs(player_ids) do
		out[id] = screen.is_ready(view, id)
	end
	return out
end

-- How many seated players are not away, as the view has it; 0 with no lobby view.
function screen.present_count(view)
	local lobby = screen.lobby_of(view)
	if lobby == nil or type(lobby.ready) ~= "table" then return 0 end
	local away = {}
	for _, id in ipairs(type(lobby.away) == "table" and lobby.away or {}) do
		away[id] = true
	end
	local count = 0
	for id in pairs(lobby.ready) do
		if not away[id] then count = count + 1 end
	end
	return count
end

-- The answer to the Start sent as input `number`: nil while the view has none for it, else
-- { refused = reason | nil }. A Start that went through leaves the lobby stage, so it is never seen here.
function screen.start_answer(view, number)
	local lobby = screen.lobby_of(view)
	local answer = lobby and lobby.start
	if type(answer) ~= "table" or number == nil or answer.number ~= number then return nil end
	return { refused = type(answer.refused) == "string" and answer.refused or nil }
end

-- The number of the Start input that has no answer yet.
local start_asked

local function my_id()
	local lobby = MPAPI.get_current_lobby()
	return lobby and lobby.player_id
end

local function warn(text)
	sendWarnMessage("[lobby] " .. text, "MULTIPLAYER")
end

-- "waiting", "ready" or "not_ready" for this player.
function screen.ready_state()
	local net = PVP.NET
	return screen.ready_state_of(net.view, my_id(), net.waiting("lobbyReady"))
end

-- True while the view is there and no Start is waiting for its answer.
function screen.start_askable()
	local net = PVP.NET
	return screen.lobby_of(net.view) ~= nil and not net.waiting("lobbyStart")
end

-- Sets the Ready button's look from the state and rebuilds the lobby buttons.
function screen.refresh_buttons()
	local lobby = PVP.UI.lobby
	local b = lobby and lobby.buttons
	if not b then return end
	local state = screen.ready_state()
	if b.ready_args then
		if state == "waiting" then
			b.ready_args.label = { localize("b_ready_waiting_cap") }
			b.ready_args.colour = G.C.UI.BACKGROUND_INACTIVE
		elseif state == "ready" then
			b.ready_args.label = { localize("b_unready_cap") }
			b.ready_args.colour = G.C.ORANGE
		else
			b.ready_args.label = { localize("b_ready_cap") }
			b.ready_args.colour = G.C.GREEN
		end
	end
	for _, name in ipairs({ "ready", "start_game", "party_find_game" }) do
		if b[name] then b[name]:update() end
	end
end

-- Asks the server for this Ready state; the button shows "waiting" until the view confirms it.
function screen.send_ready(ready)
	local number, problem = PVP.NET.send("lobbyReady", { ready = ready })
	if not number then warn("Ready not sent: " .. tostring(problem)) end
	screen.refresh_buttons()
end

-- The Ready button: asks for the opposite of what the view shows.
function screen.press_ready()
	if screen.ready_state() == "waiting" then return end
	screen.send_ready(screen.next_ready(PVP.NET.view, my_id()))
end

-- The host's lobby settings (a patch of the lobby metadata) go up as a numbered input, before and during
-- the game; every player, the host too, takes them from the metadata the server sends back. A local lobby
-- (practice, playback) has no server and merges them itself.
function screen.send_settings(lobby, patch)
	if not (lobby and lobby.is_host) then return end
	if lobby._local_mode then return lobby:set_metadata(patch) end
	local number, problem = PVP.NET.send("lobbySettings", { settings = patch })
	if not number and problem ~= "held for the first view" then warn("settings not sent: " .. tostring(problem)) end
end

-- Asks the server to start the game; its answer comes back in the view.
function screen.send_start(body)
	local number, problem = PVP.NET.send("lobbyStart", body)
	if not number then
		warn("Start not sent: " .. tostring(problem))
		return
	end
	start_asked = number
	screen.refresh_buttons()
end

local function show_refusal(reason)
	if PVP.NET.version_gate.is_server_refusal(reason) then
		PVP.UI.UTILS.overlay_message(PVP.NET.version_gate.refused_message())
	else
		PVP.UI.refusal.show(reason, "k_start_refused")
	end
end

function screen.on_view(view)
	local lobby_view = screen.lobby_of(view)
	if lobby_view then
		local ids = {}
		for id in pairs(lobby_view.ready) do
			ids[#ids + 1] = id
		end
		PVP.UI.lobby.apply_ready(screen.ready_by_player(view, ids), screen.present_count(view))
	end
	local answer = screen.start_answer(view, start_asked)
	if answer then
		start_asked = nil
		if answer.refused then
			PVP.UI.lobby.start_broadcasted = false
			show_refusal(answer.refused)
		end
	end
	-- A matchmade lobby is Ready on arrival: the view not showing it is all it takes to ask.
	if PVP.LOBBY.is_matchmaking() and screen.ready_state() == "not_ready" then
		screen.send_ready(true)
		return
	end
	screen.refresh_buttons()
end

-- A new lobby starts with no Start waiting.
function screen.reset()
	start_asked = nil
end

function screen.install(net)
	net.add_view_listener(screen.on_view)
end

return screen
