-- The shared reads of the match net's view: the run, a player's part of it, my PvP blind, the opponent,
-- who is out. Pure: plain values in, plain values out, no game and no net. Every reader module asks
-- here instead of walking view.match.run itself.
local view = {}
PVP.view = view

-- A whole number of at least `least` (default 0): the shape of an input number.
function view.whole(value, least)
	return type(value) == "number" and value >= (least or 0) and value == math.floor(value) and value < 2 ^ 53
end

-- Whether `id` is in `list`; a list that is not a table has none.
function view.contains(list, id)
	for _, entry in ipairs(type(list) == "table" and list or {}) do
		if entry == id then return true end
	end
	return false
end

-- What the screens have already shown. once(key) is true the first time a key is asked; changed(name, value)
-- is true when value is not what the name last held (nothing held is nil) and holds it from then on.
-- forget(prefix) drops every mark whose key or name starts with prefix: a screen's reset points.
-- follow_run drops them all when the game shown is a new run, so no mark outlives its game.
local once_keys, held_values, marks_run = {}, {}, nil

function view.once(key)
	if once_keys[key] then return false end
	once_keys[key] = true
	return true
end

function view.changed(name, value)
	if held_values[name] == value then return false end
	held_values[name] = value
	return true
end

function view.forget(prefix)
	for _, marks in ipairs({ once_keys, held_values }) do
		for key in pairs(marks) do
			if key:sub(1, #prefix) == prefix then marks[key] = nil end
		end
	end
end

function view.follow_run(from)
	local run = view.run(view.game(from))
	local id = run and run.id
	if id == nil or id == marks_run then return end
	marks_run = id
	once_keys, held_values = {}, {}
end

-- The game the screens read: the live view while it runs; back in the lobby, the game that ended,
-- which the server keeps in the lobby view until the next game starts. nil when there is none.
function view.game(from)
	local match = from and from.match
	if match and match.stage == "lobby" then return match.ended end
	return from
end

-- The run the view shows, or nil.
function view.run(from)
	local run = from and from.match and from.match.run
	return type(run) == "table" and run or nil
end

-- One player's part of the run (ante, lives, ...), or nil.
function view.run_player(from, player_id)
	local run = view.run(from)
	local player = run and type(run.players) == "table" and run.players[player_id]
	return type(player) == "table" and player or nil
end

-- The server's blind key: "<ante>:Small|Big|Boss".
function view.blind_key(ante, blind)
	return string.format("%d:%s", ante, blind)
end

-- The key of the PvP blind of an ante, or nil while the ante is unknown.
function view.pvp_blind_key(ante)
	return ante ~= nil and view.blind_key(ante, "Boss") or nil
end

-- The open PvP blind and my part of it, only when it is the PvP blind of the blind the game is on
-- (blind_key); both nil between PvP blinds and for another blind's. A waiting blind's part is "ready"
-- or "not ready"; a playing blind's part is a table with its stage.
function view.my_pvp_blind(from, blind_key)
	local run = view.run(from)
	local open = run and run.currentPvpBlind
	if not (open and blind_key ~= nil and open.blindKey == blind_key) then return nil, nil end
	return open, open.players and open.players[from.me]
end

-- The mark of one PvP blind of one run, as "<run id>/<blind key>": what is already shown or entered.
function view.entry_key(run_id, blind_key)
	return run_id .. "/" .. blind_key
end

-- The result of this blind's closed PvP blind, only when I was in it.
function view.my_pvp_result(from, blind_key)
	local run = view.run(from)
	for _, entry in ipairs(run and run.finishedPvpBlinds or {}) do
		if entry.blindKey == blind_key and ((entry.scores or {})[from.me] ~= nil or (entry.endedBy or {})[from.me] ~= nil) then
			return entry
		end
	end
	return nil
end

-- A player's score as a part of the open PvP blind shows it, or nil while it is hidden from me or not there.
function view.shown_score(part)
	local score = type(part) == "table" and part.score
	return type(score) == "table" and score.kind == "shown" and score.score or nil
end

-- THE current score of one player in the PvP blind of blind_key, open or closed, in every mode: the open
-- blind's shown score, else the closed entry's. nil while hidden from me or not there.
function view.score_of(from, blind_key, player_id)
	local open = view.run(from) and view.run(from).currentPvpBlind
	if open and open.blindKey == blind_key then
		return view.shown_score(open.players and open.players[player_id])
	end
	local entry = view.my_pvp_result(from, blind_key)
	local score = entry and type(entry.scores) == "table" and entry.scores[player_id]
	return type(score) == "string" and score or nil
end

-- The same for a team's total (Teams); side is "A" or "B".
function view.team_score_of(from, blind_key, side)
	local run = view.run(from)
	local open = run and run.currentPvpBlind
	local sums
	if open and open.blindKey == blind_key then
		sums = run.targets and run.targets.teamScores
	else
		local entry = view.my_pvp_result(from, blind_key)
		sums = entry and entry.teamScores
	end
	local total = type(sums) == "table" and sums[side]
	return type(total) == "string" and total or nil
end

-- The player the view names as my opponent, or nil.
function view.opponent_id(from)
	local run = view.run(from)
	local opponents = run and run.targets and run.targets.opponents
	return opponents and opponents[1] or nil
end

-- One player's lives as the view has them, or nil while it has none.
function view.lives_of(from, player_id)
	local player = view.run_player(from, player_id)
	local lives = player and player.lives
	return type(lives) == "number" and lives or nil
end

-- Whether a player is out of the game shown (the live one; back in the lobby, the one that ended): status
-- out or left, or no lives left. No view and no ended game are not out.
function view.is_out(from, player_id)
	local game = view.game(from)
	local player = game and type(game.players) == "table" and game.players[player_id]
	local status = type(player) == "table" and player.status
	return status == "out" or status == "left" or view.lives_of(game, player_id) == 0
end

-- Whether the view is of the run this game is playing; the game's own record (G.GAME.pvp_net) names it.
-- After a game ends the net keeps its last view, so a new game can meet the old run's view for a frame.
function view.is_my_run(from, record)
	local run = view.run(from)
	return type(record) == "table" and run ~= nil and run.id ~= nil and record.runId == run.id
end

return view
