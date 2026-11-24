-- What the Ready button, the team pick and the start of the PvP blind show, decided from the server's
-- view and plain game values. Pure: no game, no net. entry_screen.lua is the shell that calls these.
local reader = {}
PVP.entry_reader = reader
local views = PVP.view

-- The PvP blind's entry key, run id and blind key, the same text next_entry marks as entered.
function reader.entry_key(view, game_ante)
	local open = views.my_pvp_blind(view, views.pvp_blind_key(game_ante))
	return open and views.entry_key(view.match.run.id, open.blindKey) or nil
end

-- Whether the first Ready is held: with no PvP blind of mine open, until the view says my Boss plays
-- (targets.myBoss), and says it about the ante the game is on (game_ante; the ante the server has me
-- on must match). Only "plays" and "bye" release it (a bye presses Ready too); "no pvp this ante" and
-- an unknown answer hold.
function reader.ready_held(view, game_ante)
	local run = views.run(view)
	if not run or select(2, views.my_pvp_blind(view, views.pvp_blind_key(game_ante))) then return false end
	local mine = type(run.players) == "table" and run.players[view.me]
	if not (type(mine) == "table" and mine.ante ~= nil and mine.ante == game_ante) then return true end
	local boss = run.targets and run.targets.myBoss
	return not (boss == "plays" or boss == "bye")
end

-- "waiting" while the view has no run yet (a press would send nothing); "held" while my Boss does not
-- play yet; else my latest press of this blind the server has not confirmed (`pending`, the input as
-- sent), so a second press cancels the first at once; else what the view says. My Ready stands from the waiting blind until it is entered, so a PvP blind that already
-- plays but that I have not entered (`entered` is the key marked entered) still reads "ready": a playing
-- blind holds only players who were Ready.
function reader.ready_button(view, pending, entered, game_ante)
	if not views.run(view) then return "waiting" end
	if reader.ready_held(view, game_ante) then return "held" end
	local blind_key = views.pvp_blind_key(game_ante)
	if type(pending) == "table" and pending.blindKey == blind_key then return pending.ready and "ready" or "not_ready" end
	local open, me = views.my_pvp_blind(view, blind_key)
	if not (open and me) then return "not_ready" end
	if open.stage == "waiting" then return me == "ready" and "ready" or "not_ready" end
	if open.stage == "playing" and me.stage ~= "done" and entered ~= reader.entry_key(view, game_ante) then return "ready" end
	return "not_ready"
end

-- Whether the server has already closed a PvP blind for this blind key.
local function blind_closed(run, blind_key)
	for _, result in ipairs(type(run.finishedPvpBlinds) == "table" and run.finishedPvpBlinds or {}) do
		if result.blindKey == blind_key then return true end
	end
	return false
end

-- Away is how the view shows me until the server sees me back after a rejoin; the server takes my Ready then.
local MAY_READY = { playing = true, away = true }

-- The ready input a press sends, or nil: the other side of what the button shows, my unconfirmed press
-- included. Ready can only be changed while the PvP blind waits; with none of mine open a press goes out
-- unless this blind's is closed, I am out of the run, or the button is held (ready_held).
function reader.press(view, pending, game_ante)
	if type(view) ~= "table" then return nil end
	local run = views.run(view)
	if not run then return nil end
	local blind_key = views.pvp_blind_key(game_ante)
	local open, me = views.my_pvp_blind(view, blind_key)
	if not open then
		local player = view.players and view.players[view.me]
		if not (player and MAY_READY[player.status]) then return nil end
		if blind_closed(run, blind_key) or reader.ready_held(view, game_ante) then return nil end
	elseif not (me and open.stage == "waiting") then
		return nil
	end
	return { ready = reader.ready_button(view, pending, nil, game_ante) ~= "ready", blindKey = blind_key }
end

-- Everyone's team, id to team; a player with none picked has no entry.
function reader.teams(view)
	local teams = {}
	for id, player in pairs(view and view.players or {}) do
		teams[id] = player.team
	end
	return teams
end

-- The team picker: { state = "waiting" | "picked" | "not picked", team }. "waiting" is the neutral
-- state, with no presses, while my team pick is unconfirmed; else the team the view says I am on.
function reader.team_look(view, input_waiting)
	if input_waiting then return { state = "waiting", team = nil } end
	local player = view and view.players and view.players[view.me]
	local team = player and player.team or nil
	return { state = team and "picked" or "not picked", team = team }
end

-- Which select button enters the blind: the one the Ready press left, else (after a restart) the
-- boss blind's own. Nothing when neither exists, and then nothing is entered yet.
function reader.entry_button(game)
	if game.saved_button then return "saved" end
	if game.on_boss and game.boss_button then return "boss" end
	return nil
end

-- Entering a PvP blind the view has playing: only when I am not done in it, it is not entered yet, my
-- game is at blind select with a button to enter by (game.button), and every item the server wrote for
-- me is done. "fresh": the view has me as not entered, so a blindStart is due; "already playing": the
-- server has me in it.
local function playing_entry(entered, view, game)
	local open, me = views.my_pvp_blind(view, game.blind_key)
	if not (open and open.stage == "playing" and type(me) == "table") or me.stage == "done" then return entered, nil end
	local key = views.entry_key(view.match.run.id, open.blindKey)
	if key == entered or not game.at_blind_select or not game.button then return entered, nil end
	if game.inbox_done ~= view.onlyMine.inboxNewest then return entered, nil end
	return key, { kind = me.stage == "not entered" and "fresh" or "already playing", blind_key = open.blindKey }
end

-- Entering the PvP blind of a blind the view has already closed ("already over"): the same entry as a
-- Ready'd one, with no Ready and no blindStart, at blind select on the Boss with a button.
local function closed_entry(entered, view, game)
	if not (game.at_blind_select and game.on_boss and game.button) or game.inbox_done ~= view.onlyMine.inboxNewest then
		return entered, nil
	end
	local key = views.entry_key(view.match.run.id, game.blind_key)
	if key == entered or not views.my_pvp_result(view, game.blind_key) then return entered, nil end
	return key, { kind = "already over", blind_key = game.blind_key }
end

-- Returns the entered key and, when it is time to enter, { kind = "fresh" | "already playing" |
-- "already over", blind_key }. The same view again changes nothing, and so does a run a rejoin's replay
-- drives (game.run == "replaying"): the replay plays its recorded select_blind itself.
function reader.next_entry(entered, view, game)
	if game.run == "replaying" then return entered, nil end
	local key, entry = playing_entry(entered, view, game)
	if entry then return key, entry end
	return closed_entry(entered, view, game)
end

return reader
