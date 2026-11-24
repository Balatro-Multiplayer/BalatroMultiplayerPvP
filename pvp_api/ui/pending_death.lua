-- Pending deaths as the view lists them (run.waitingDeaths: a player out of lives who waits for others to
-- beat the same blind). The readers take a view and give plain facts; update() opens the waiting screen while
-- the view lists me, closes it when it no longer does, and tells me when another player's pending death waits
-- on me. Never opens during a playback.
local screen = PVP.UI.pending_death or {}
PVP.UI.pending_death = screen

local function entries(view)
	local run = PVP.READ.view.run(view)
	local list = type(run) == "table" and run.waitingDeaths
	return type(list) == "table" and list or {}
end

-- My own pending death (player, blindKey, waitingFor), or nil: none listed, or no view yet.
function screen.mine(view)
	if not (view and view.me) then return nil end
	for _, entry in ipairs(entries(view)) do
		if entry.player == view.me then return entry end
	end
	return nil
end

-- A teammate's pending death (the view lists one death per team, and every member is out when the team's
-- shared lives are gone), or nil: no team, or none listed.
function screen.teammates(view)
	local players = view and view.players
	local team = type(players) == "table" and type(players[view.me]) == "table" and players[view.me].team
	if not team then return nil end
	for _, entry in ipairs(entries(view)) do
		local other = players[entry.player]
		if entry.player ~= view.me and type(other) == "table" and other.team == team then return entry end
	end
	return nil
end

-- Why I wait: my listed pending death or my team's, or nil. Being out of the run with neither listed is not
-- a wait: it shows the loss (pvp_api/read/finish.lua).
function screen.waiting(view)
	return screen.mine(view) or screen.teammates(view)
end

-- The localization key of the wait line: one player to wait for, or several. The server always lists them.
function screen.wait_key(entry)
	local waiting_for = entry and entry.waitingFor
	if type(waiting_for) == "table" and #waiting_for == 1 then return "k_pvp_pending_death_wait" end
	return "k_pvp_pending_death_wait_many"
end

-- The localization key of the survivor notice. Only a two-player match ends with the pending death; with
-- more players (or no player list yet) finishing the blind settles one death, so the wording does not
-- promise the end of the game.
function screen.survivor_key(view)
	local count = 0
	for _ in pairs(type(view) == "table" and type(view.players) == "table" and view.players or {}) do
		count = count + 1
	end
	return count == 2 and "k_pvp_pending_death_survivor" or "k_pvp_pending_death_survivor_many"
end

-- The pending deaths that wait on me to beat their blind, as "player:blindKey" marks.
function screen.waiting_on_me(view)
	local marks = {}
	if not (view and view.me) then return marks end
	for _, entry in ipairs(entries(view)) do
		if entry.player ~= view.me and PVP.READ.view.contains(entry.waitingFor, view.me) then
			marks[#marks + 1] = tostring(entry.player) .. ":" .. tostring(entry.blindKey)
		end
	end
	return marks
end

function screen.update()
	local view = PVP.NET and PVP.NET.view
	local run = PVP.READ.view.run(view)
	if not run then return end
	if not (G.STAGE == G.STAGES.RUN and PVP.LOBBY.in_session()) or PVP.PRACTICE.is_on() then return end
	local mine = screen.waiting(view)
	local open = PVP.GAME.pending_death_screen
	if mine and not open then
		if PVP.GAME.end_shown ~= "not yet" or MPAPI.playback.is_driving("pvp") then return end
		PVP.GAME.pending_death = mine
		PVP.UI.show_pending_death_screen()
	elseif mine then
		PVP.GAME.pending_death = mine
	elseif open then
		PVP.UI.pending_death.close()
	end
	-- Told once per run (a new run clears the marks): a death that leaves the list and comes back is not told twice.
	for _, mark in ipairs(screen.waiting_on_me(view)) do
		if PVP.READ.view.once("death told " .. mark) then PVP.UI.show_pending_death_notice(screen.survivor_key(view)) end
	end
end

return screen
