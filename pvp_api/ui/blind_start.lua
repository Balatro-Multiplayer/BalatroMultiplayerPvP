-- The Ready button, the team pick and the start of the PvP blind, on the match net. Pressing sends an
-- input; every look and every start is read back from the net's view (pvp_api/read/blind_start.lua decides).
-- Nothing here sets a shared fact itself.
local screen = {}
PVP.UI.blind_start = screen

local LOOK_TEXT = { waiting = "b_ready_waiting", held = "b_ready_held", ready = "b_unready", not_ready = "b_ready" }

-- The blind this game already entered, as run id and blind key, and the game (G.GAME) that entered it: the
-- same view again must not enter twice. Kept while the view is gone (a rejoin forgets it for a moment), or its
-- countdown would get a twin; a run started or loaded since is another game and enters again.
local entered, entered_game

local function my_entered()
	return entered_game == G.GAME and entered or nil
end

local function net()
	return PVP.NET
end

function screen.ready_pending()
	return net().waiting("ready")
end

-- The button shows my latest press while the server has not confirmed it.
function screen.ready_button()
	local resets = G.GAME and G.GAME.round_resets
	return PVP.READ.blind_start.ready_button(net().view, net().latest_waiting("ready"), my_entered(), resets and resets.ante)
end

function screen.ready_colour()
	local look = screen.ready_button()
	if look == "waiting" or look == "held" then return G.C.UI.BACKGROUND_INACTIVE end
	return look == "ready" and G.C.GREEN or G.C.RED
end

-- Sends the press. Returns the Ready it asked for, or nil when nothing was sent.
function screen.press_ready(button)
	local ante = G.GAME.round_resets.ante
	local body = PVP.READ.blind_start.press(net().view, net().latest_waiting("ready"), ante)
	if not (body and net().send("ready", body)) then return nil end
	PVP.GAME.next_blind_context = button
	return body.ready
end

-- The team picker's look: { waiting, team }.
function screen.team_look()
	return PVP.READ.blind_start.team_look(net().view, net().waiting("team"))
end

-- Sends the pick; nothing while an earlier pick is unconfirmed.
function screen.pick_team(team)
	if net().waiting("team") then return nil end
	local number = net().send("team", { team = team })
	if number then PVP.UI.lobby_options.refresh_team_pickers() end
	return number
end

-- Dispatches the start and says where the blind's hands come from (PVP.GAME.hands_source; pvp_api/ui/pvp_blind.lua
-- acts on it). A fresh blind's blindStart is due, and the blind counts as entered for good, only once
-- select_blind ran; a blind the server already has takes its hands and score from the view at once. With
-- no button left at the end of the countdown the entry is tried again.
local function enter_blind(entry, key)
	local function take_hands_source(entry_key)
		PVP.GAME.hands_source = PVP.READ.pvp_blind.hands_source_entered(entry.kind, entry_key)
	end
	if entry.kind ~= "fresh" then take_hands_source(key) end
	PVP.UI.match.start_pvp_blind(function()
		local pvp_net = G.GAME.pvp_net
		if entry.kind == "fresh" and pvp_net then take_hands_source(PVP.READ.view.entry_key(pvp_net.runId, entry.blind_key)) end
	end, function()
		if entered == key then entered = nil end
	end)
end

function screen.update()
	local view = net().view
	if not view then return end
	local reader = PVP.READ.blind_start
	PVP.GAME.ready_blind_text = localize(LOOK_TEXT[screen.ready_button()])
	-- What the rest of the game reads as my Ready is what the server holds, not a press on its way.
	local resets = G.GAME and G.GAME.round_resets
	PVP.GAME.ready_blind = reader.ready_button(view, nil, my_entered(), resets and resets.ante) == "ready"
	local pvp_net = G.GAME and G.GAME.pvp_net
	if not (pvp_net and G.STAGE == G.STAGES.RUN) then return end
	local entry
	local game = {
		run = MPAPI and MPAPI.playback and MPAPI.playback.is_driving("pvp") and "replaying" or "live",
		at_blind_select = G.STATE == G.STATES.BLIND_SELECT,
		inbox_done = pvp_net.inboxDone,
		on_boss = G.GAME.blind_on_deck == "Boss",
		blind_key = PVP.READ.view.pvp_blind_key(G.GAME.round_resets.ante),
		saved_button = PVP.GAME.next_blind_context ~= nil,
		boss_button = PVP.UI.boss_select_button() ~= nil,
	}
	game.button = reader.entry_button(game)
	local key, entry = reader.next_entry(my_entered(), view, game)
	if entry then
		entered, entered_game = key, G.GAME
		enter_blind(entry, key)
	end
end


-- Teams are read when a view arrives, not every frame.
function screen.install(net)
	net.add_view_listener(function(view)
		local teams = PVP.READ.blind_start.teams(view)
		PVP.LOBBY.roster = teams
		PVP.LOBBY.team_id = teams[view.me]
		PVP.UI.lobby_options.refresh_team_pickers()
	end)
end

return screen
