-- The lobby stage on screen: the Ready and Start buttons and the Ready tally. Ready and Start go up as
-- numbered inputs (match_net, kinds lobbyReady and lobbyStart); everything shown comes from the server's
-- view (lobby_reader.lua), plus "waiting" while an input is not yet confirmed. No local copy of Ready.
local screen = {}
PVP.lobby_screen = screen

-- The number of the Start input that has no answer yet.
local start_asked

local function my_id()
	local lobby = MPAPI.get_current_lobby()
	return lobby and lobby.player_id
end

local function warn(text)
	sendWarnMessage("[lobby_screen] " .. text, "MULTIPLAYER")
end

-- "waiting", "ready" or "not_ready" for this player.
function screen.ready_state()
	local net = PVP.match_net
	return PVP.lobby_reader.ready_state(net.view, my_id(), net.waiting("lobbyReady"))
end

-- True while the view is there and no Start is waiting for its answer.
function screen.start_askable()
	local net = PVP.match_net
	return PVP.lobby_reader.lobby_of(net.view) ~= nil and not net.waiting("lobbyStart")
end

-- Sets the Ready button's look from the state and rebuilds the lobby buttons.
function screen.refresh_buttons()
	local lobby = PVP.lobby
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
	local number, problem = PVP.match_net.send("lobbyReady", { ready = ready })
	if not number then warn("Ready not sent: " .. tostring(problem)) end
	screen.refresh_buttons()
end

-- The Ready button: asks for the opposite of what the view shows.
function screen.press_ready()
	if screen.ready_state() == "waiting" then return end
	screen.send_ready(PVP.lobby_reader.next_ready(PVP.match_net.view, my_id()))
end

-- The host's lobby settings (a patch of the lobby metadata) go up as a numbered input, before and during
-- the game; every player, the host too, takes them from the metadata the server sends back. A local lobby
-- (practice, playback) has no server and merges them itself.
function screen.send_settings(lobby, patch)
	if not (lobby and lobby.is_host) then return end
	if lobby._local_mode then return lobby:set_metadata(patch) end
	local number, problem = PVP.match_net.send("lobbySettings", { settings = patch })
	if not number and problem ~= "held for the first view" then warn("settings not sent: " .. tostring(problem)) end
end

-- Asks the server to start the game; its answer comes back in the view.
function screen.send_start(body)
	local number, problem = PVP.match_net.send("lobbyStart", body)
	if not number then
		warn("Start not sent: " .. tostring(problem))
		return
	end
	start_asked = number
	screen.refresh_buttons()
end

local function show_refusal(reason)
	if PVP.VersionGate.is_server_refusal(reason) then
		PVP.UI.UTILS.overlay_message(PVP.VersionGate.refused_message())
	else
		PVP.refusal_screen.show(reason, "k_start_refused")
	end
end

function screen.on_view(view)
	local lobby_view = PVP.lobby_reader.lobby_of(view)
	if lobby_view then
		local ids = {}
		for id in pairs(lobby_view.ready) do
			ids[#ids + 1] = id
		end
		PVP.apply_ready_view(PVP.lobby_reader.ready_by_player(view, ids), PVP.lobby_reader.present_count(view))
	end
	local answer = PVP.lobby_reader.start_answer(view, start_asked)
	if answer then
		start_asked = nil
		if answer.refused then
			PVP.lobby.start_broadcasted = false
			show_refusal(answer.refused)
		end
	end
	-- A matchmade lobby is Ready on arrival: the view not showing it is all it takes to ask.
	if PVP.is_matchmaking() and screen.ready_state() == "not_ready" then
		screen.send_ready(true)
		return
	end
	screen.refresh_buttons()
end

-- A new lobby starts with no Start waiting.
function screen.reset()
	start_asked = nil
end

function screen.install(match_net)
	match_net.add_view_listener(screen.on_view)
end

return screen
