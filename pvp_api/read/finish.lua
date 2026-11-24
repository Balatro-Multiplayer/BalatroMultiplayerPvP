-- The end of the game: the inputs a player sends (vote, forfeit, endGame) and what the view says of the
-- result and of the other players' end. Pure: plain values in, plain values out, no game and no net.
-- pvp_api/ui/finish.lua is the shell that sends and shows. Every body builder answers nil for a value of the
-- wrong shape; the server owns the limits, except the size of an endGame, which is cut to fit.
local reader = {}
PVP.READ.finish = reader

local MOST_BYTES = 6000
-- What the server adds around the body of an endGame (kind, input number, run id, ...).
local ENVELOPE_BYTES = 300
local TOPICS = { draw = true, seed = true }
local VOTE_ORDER = { "seed", "draw" }

function reader.vote(topic, yes)
	if not (TOPICS[topic] and type(yes) == "boolean") then return nil end
	return { topic = topic, yes = yes }
end

function reader.forfeit()
	return {}
end

-- jokers and deck are text. Too much text for the server's limit goes out as "": the longer part is
-- left out first, then the other if it is still too much; the view then shows an empty part as unknown.
function reader.end_game(jokers, deck, reroll_count, reroll_cost_total)
	if not (type(jokers) == "string" and type(deck) == "string" and PVP.READ.view.whole(reroll_count) and PVP.READ.view.whole(reroll_cost_total)) then
		return nil
	end
	for _ = 1, 2 do
		if #jokers + #deck + ENVELOPE_BYTES > MOST_BYTES then
			if #deck >= #jokers then deck = "" else jokers = "" end
		end
	end
	return { jokers = jokers, deck = deck, stats = { rerollCount = reroll_count, rerollCostTotal = reroll_cost_total } }
end

-- The jokers I hold on leaving a shop, as text. nil for no text, so an older one stays.
-- The server shows the newest only for a player with no endGame; an endGame with no jokers text shows none.
function reader.jokers(text)
	if not (type(text) == "string" and text ~= "") then return nil end
	return { jokers = text }
end

-- What the end means for me, or nil while there is nothing to show: I am still in and the match has no
-- result, the result is not a screen of mine (a restart, a contest), or the result lacks a field it needs.
-- Out of the run (lives gone, forfeited) or left with no result yet: the loss at once, as the live game
-- does; the match's own result later adds no second screen. In Teams, out is no end: the team's
-- result can still be a win or a draw, and the live game sends no elimination there; a leaver still loses.
-- screen: "win" | "lose" | "draw". rank: "counts" | "not_counted" | "unsaid" (the result did not say).
-- place: my place when the server gave one.
local function rank_of(rated)
	if rated == true then return "counts" end
	if rated == false then return "not_counted" end
	return "unsaid"
end

-- Teams is the mode whose run has shared team lives.
local function teams_run(run)
	return type(run.teamLives) == "table"
end


function reader.my_end(view)
	local run = PVP.READ.view.run(view)
	if not (run and type(view.me) == "string") then return nil end
	local mine = view.players and view.players[view.me]
	local place = type(mine) == "table" and mine.place or nil
	local result = view.match.result
	if type(result) ~= "table" then
		local status = type(mine) == "table" and mine.status
		if status == "left" or (status == "out" and not teams_run(run)) then
			return { screen = "lose", rank = "unsaid", place = place, by = "out" }
		end
		return nil
	end
	local kind = result.kind
	if kind == "win" then
		if type(result.winners) ~= "table" then return nil end
		return { screen = PVP.READ.view.contains(result.winners, view.me) and "win" or "lose", rank = rank_of(result.rated), place = place, by = "result" }
	elseif kind == "draw" then
		return { screen = "draw", rank = rank_of(result.rated), place = place, by = "result" }
	elseif kind == "abandoned" then
		return { screen = "draw", rank = "not_counted", place = place, by = "result" }
	end
	return nil
end

-- The run id when my endGame is due and not yet sent for it: I am out or gone, or the match has a result.
function reader.end_game_due(sent_for, view)
	local run = PVP.READ.view.run(view)
	local run_id = run and run.id
	if type(run_id) ~= "string" or run_id == sent_for then return nil end
	local mine = view.players and view.players[view.me]
	local status = type(mine) == "table" and mine.status
	if type(view.match.result) == "table" or status == "out" or status == "left" then return run_id end
	return nil
end

-- Another player's end of game from the view: { jokers = list or nil, deck = text or nil, mark = text }, or
-- nil while the view has nothing of theirs. The jokers are their endGame's; while that has none (not sent, or
-- it came as ""), the newest jokers they sent on leaving a shop (the view has none once their endGame is in). A part that came as "" is unknown, not empty.
-- decode turns the jokers text into a list (nil when it cannot). mark changes whenever any of it does.
function reader.other_end(view, player_id, decode)
	local player = view and view.players and view.players[player_id]
	if type(player) ~= "table" then return nil end
	local sent = type(player.endGame) == "table" and player.endGame or nil
	local latest = type(player.jokers) == "string" and player.jokers ~= "" and player.jokers or nil
	if not (sent or latest) then return nil end
	local function list_of(text)
		if type(text) ~= "string" or text == "" then return nil end
		local list = decode(text)
		return type(list) == "table" and list or nil
	end
	local jokers = sent and list_of(sent.jokers) or list_of(latest)
	local deck = sent and type(sent.deck) == "string" and sent.deck ~= "" and sent.deck or nil
	local mark = (sent and sent.jokers or "-") .. "|" .. (deck or "-") .. "|" .. (latest or "-")
	return { jokers = jokers, deck = deck, mark = mark }
end

-- A player's best score over the run's closed PvP blinds, as score text, or nil while they have none.
-- greater(a, b) is the score compare.
function reader.best_score(view, player_id, greater)
	local run = PVP.READ.view.run(view)
	local best
	for _, entry in ipairs(type(run) == "table" and type(run.finishedPvpBlinds) == "table" and run.finishedPvpBlinds or {}) do
		local score = type(entry) == "table" and type(entry.scores) == "table" and entry.scores[player_id]
		if type(score) == "string" and (best == nil or greater(score, best)) then best = score end
	end
	return best
end

-- Vote progress chat lines: the new marker and { topic, count, total } for each vote whose count
-- changed to more than none. A view with no marker for its run (the first after a load, a rejoin or a new run)
-- only sets the marker; a missing vote list leaves the marker as it was. total is the players still in the
-- run, playing or away: the server's vote counts no others.
function reader.vote_progress(marker, view)
	local run = PVP.READ.view.run(view)
	local votes = type(run) == "table" and run.votes
	if not (type(votes) == "table" and type(run.id) == "string" and type(view.players) == "table") then return marker, {} end
	if not (type(votes.draw) == "table" and type(votes.seed) == "table") then return marker, {} end
	local fresh = { run = run.id, draw = #votes.draw, seed = #votes.seed }
	if not marker or marker.run ~= run.id then return fresh, {} end
	local total = 0
	for _, player in pairs(view.players) do
		if type(player) == "table" and (player.status == "playing" or player.status == "away") then total = total + 1 end
	end
	local lines = {}
	for _, topic in ipairs(VOTE_ORDER) do
		if fresh[topic] ~= marker[topic] and fresh[topic] > 0 then
			lines[#lines + 1] = { topic = topic, count = fresh[topic], total = total }
		end
	end
	return fresh, lines
end

return reader
