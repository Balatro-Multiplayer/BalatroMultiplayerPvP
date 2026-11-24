-- Who I am playing with that the server's view says is away, and whether their absence is holding the
-- countdowns. Pure: a view in, player ids out. Only while the match is in its run. Who counts: my
-- opponents this run, my teammates (the players on my team) and any player an away pause names, since
-- that pause holds my countdowns. Away is view.players[id].status == "away"; no status is not away. The hold is a
-- pause with reason "away" naming that player in view.timers.pauses. Me is never listed: my own screen
-- is the one that went away.
local reader = {}
PVP.READ.away = reader

local function is_away(view, id)
	local player = type(view.players) == "table" and view.players[id]
	return type(player) == "table" and player.status == "away"
end

local function held_players(view)
	local held = {}
	local timers = view.timers
	if type(timers) ~= "table" or type(timers.pauses) ~= "table" then return held end
	for _, pause in ipairs(timers.pauses) do
		if type(pause) == "table" and pause.reason == "away" and type(pause.players) == "table" then
			for _, id in ipairs(pause.players) do
				held[id] = true
			end
		end
	end
	return held
end

local function playing_with(view)
	local ids = {}
	for id in pairs(held_players(view)) do
		ids[id] = true
	end
	local run = PVP.READ.view.run(view)
	local targets = type(run) == "table" and run.targets
	local opponents = type(targets) == "table" and targets.opponents
	for _, id in ipairs(type(opponents) == "table" and opponents or {}) do
		ids[id] = true
	end
	local mine = type(view.players) == "table" and view.players[view.me]
	local team = type(mine) == "table" and mine.team
	if team then
		for id, player in pairs(view.players) do
			if type(player) == "table" and player.team == team then ids[id] = true end
		end
	end
	ids[view.me] = nil
	return ids
end

-- The away ids, sorted, and whether any of them holds the countdowns; nil when none is away.
function reader.away_players(view)
	if type(view) ~= "table" or type(view.me) ~= "string" then return nil end
	if not (type(view.match) == "table" and view.match.stage == "run") then return nil end
	local held = held_players(view)
	local ids, timers_held = {}, false
	for id in pairs(playing_with(view)) do
		if is_away(view, id) then
			ids[#ids + 1] = id
			if held[id] then timers_held = true end
		end
	end
	if #ids == 0 then return nil end
	table.sort(ids)
	return ids, timers_held
end

-- The names to show for those ids, in order. A name the lobby does not give is shown as unknown_name.
function reader.names_line(ids, name_of, unknown_name)
	local names = {}
	for _, id in ipairs(ids) do
		names[#names + 1] = name_of(id) or unknown_name
	end
	return table.concat(names, ", ")
end

return reader
