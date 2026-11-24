-- Pending deaths as the view lists them (run.waitingDeaths: a player out of lives who waits for others to
-- beat the same blind). Pure: a view in, plain facts out. pending_death_screen.lua is the shell that shows.
local reader = {}
PVP.pending_death_reader = reader

local function entries(view)
	local run = PVP.view.run(view)
	local list = type(run) == "table" and run.waitingDeaths
	return type(list) == "table" and list or {}
end

-- My own pending death (player, blindKey, waitingFor), or nil: none listed, or no view yet.
function reader.mine(view)
	if not (view and view.me) then return nil end
	for _, entry in ipairs(entries(view)) do
		if entry.player == view.me then return entry end
	end
	return nil
end

-- A teammate's pending death (the view lists one death per team, and every member is out when the team's
-- shared lives are gone), or nil: no team, or none listed.
function reader.teammates(view)
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
-- a wait: it shows the loss (finish_reader.lua).
function reader.waiting(view)
	return reader.mine(view) or reader.teammates(view)
end

-- The localization key of the wait line: one player to wait for, or several. The server always lists them.
function reader.wait_key(entry)
	local waiting_for = entry and entry.waitingFor
	if type(waiting_for) == "table" and #waiting_for == 1 then return "k_pvp_pending_death_wait" end
	return "k_pvp_pending_death_wait_many"
end

-- The localization key of the survivor notice. Only a two-player match ends with the pending death; with
-- more players (or no player list yet) finishing the blind settles one death, so the wording does not
-- promise the end of the game.
function reader.survivor_key(view)
	local count = 0
	for _ in pairs(type(view) == "table" and type(view.players) == "table" and view.players or {}) do
		count = count + 1
	end
	return count == 2 and "k_pvp_pending_death_survivor" or "k_pvp_pending_death_survivor_many"
end

-- The pending deaths that wait on me to beat their blind, as "player:blindKey" marks.
function reader.waiting_on_me(view)
	local marks = {}
	if not (view and view.me) then return marks end
	for _, entry in ipairs(entries(view)) do
		if entry.player ~= view.me and PVP.view.contains(entry.waitingFor, view.me) then
			marks[#marks + 1] = tostring(entry.player) .. ":" .. tostring(entry.blindKey)
		end
	end
	return marks
end

return reader
