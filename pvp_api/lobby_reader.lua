-- What the lobby stage shows, from the server's view and nothing else: who is Ready, what the Ready
-- button says, and the answer to a Start. Pure: no game, no net. lobby_screen.lua is the shell.
local reader = {}
PVP.lobby_reader = reader

-- The lobby part of a view, nil in any other stage (and before the first view).
function reader.lobby_of(view)
	local match = type(view) == "table" and view.match
	if type(match) ~= "table" or match.stage ~= "lobby" or type(match.lobby) ~= "table" then return nil end
	return match.lobby
end

-- True when the view says this player is Ready; nil-safe, false with no view.
function reader.is_ready(view, player_id)
	local lobby = reader.lobby_of(view)
	return lobby ~= nil and type(lobby.ready) == "table" and lobby.ready[player_id] == true
end

-- "waiting" while there is no lobby view or a Ready is unconfirmed; else the view's state:
-- "ready" (shown as Unready to press) or "not_ready".
function reader.ready_state(view, player_id, ready_unconfirmed)
	if reader.lobby_of(view) == nil or ready_unconfirmed then return "waiting" end
	return reader.is_ready(view, player_id) and "ready" or "not_ready"
end

-- What a press asks the server for, from the view: the opposite of what it shows.
function reader.next_ready(view, player_id)
	return not reader.is_ready(view, player_id)
end

-- The tally the Start button and the auto-start read: every present player's Ready, as the view has it.
function reader.ready_by_player(view, player_ids)
	local out = {}
	for _, id in ipairs(player_ids) do
		out[id] = reader.is_ready(view, id)
	end
	return out
end

-- How many seated players are not away, as the view has it; 0 with no lobby view.
function reader.present_count(view)
	local lobby = reader.lobby_of(view)
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
function reader.start_answer(view, number)
	local lobby = reader.lobby_of(view)
	local answer = lobby and lobby.start
	if type(answer) ~= "table" or number == nil or answer.number ~= number then return nil end
	return { refused = type(answer.refused) == "string" and answer.refused or nil }
end

return reader
