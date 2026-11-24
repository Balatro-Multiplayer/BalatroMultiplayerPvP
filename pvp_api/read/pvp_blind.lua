-- What the PvP blind allows and shows, decided from the server's view and plain game values: may I play,
-- where its hands come from, how it ended, lives lost, what the opponent shows. Pure: no game, no net.
-- pvp_api/ui/pvp_blind.lua is the shell that calls these.
local reader = {}
PVP.READ.pvp_blind = reader
local views = PVP.READ.view

-- No hand once the view says my PvP blind is over, and none without a view (an unsent input is lost).
function reader.may_play(view, blind_key)
	local open, me = views.my_pvp_blind(view, blind_key)
	return open ~= nil and type(me) == "table" and open.stage == "playing" and me.stage ~= "done"
end

-- The handPlayed a Play press sends, or nil when the press plays no hand. handsLeft is after the play.
function reader.hand_played(game)
	if not (game.selecting_hand and game.highlighted > 0 and game.hands_left > 0) then return nil end
	return { blindKey = game.blind_key, handsLeft = game.hands_left - 1 }
end

-- Where the hands and score of the PvP blind on screen come from (PVP.GAME.hands_source):
--   { kind = "game" }: the game's own; nothing is waiting.
--   { kind = "blind start due", key }: a fresh entry; its blindStart goes out at the first pick-a-hand.
--   { kind = "from server", key }: a load, or an entry into a blind the server already has; the first
--     pick-a-hand takes hands and score from the view. key is nil until the first frame, which reads
--     it from the game that was loaded.
-- key is the run id and blind key (views.entry_key) the source belongs to; another blind's is dropped.
function reader.hands_source_loaded()
	return { kind = "from server", key = nil }
end

-- entry_kind: "fresh" | "already playing" | "already over" (READ.blind_start.next_entry).
function reader.hands_source_entered(entry_kind, key)
	if entry_kind == "fresh" then return { kind = "blind start due", key = key } end
	return { kind = "from server", key = key }
end

-- Each frame: the source binds its key to the game's, or is dropped once the game is on another blind.
-- game_key is nil without a run record: nothing waits then.
function reader.hands_source_at(source, game_key)
	if game_key == nil then return { kind = "game" } end
	if source.kind == "game" then return source end
	if source.key == nil then return { kind = source.kind, key = game_key } end
	if source.key ~= game_key then return { kind = "game" } end
	return source
end

-- Whether the blind on screen (game_key) still waits for its hands from the view.
function reader.hands_from_server_waiting(source, game_key)
	return source.kind == "from server" and (source.key == nil or source.key == game_key)
end

-- Whether the blindStart of the blind on screen has not gone out yet.
function reader.blind_start_waiting(source, game_key)
	return source.kind == "blind start due" and source.key == game_key
end

-- step: "blind start sent" | "hands settled" | "result shown". The source is spent by the step it waited for.
function reader.hands_source_done(source, step)
	if step == "blind start sent" and source.kind == "blind start due" then return { kind = "game" } end
	if step ~= "blind start sent" and source.kind == "from server" then return { kind = "game" } end
	return source
end

-- The blindStart of a blind just entered, due at its first pick-a-hand: by then the blind's own hand
-- changes (Burglar, Skip-Off) have run, so it carries the hands the player really starts with. Nothing
-- before that pick-a-hand, nothing for another blind. The caller sends it once.
function reader.blind_start(source, game)
	if source.kind ~= "blind start due" or source.key ~= game.key or not game.selecting_hand then return nil end
	return { blindKey = game.blind_key, handsLeft = game.hands_left, score = game.score }
end

-- After a load or an entry into a blind the server already has: what to set from the view. Returns
--   { kind = "not yet" }: the view and the game do not line up yet; ask again next frame.
--   { kind = "nothing to set" }: final, the view has nothing for the hands.
--   { kind = "set hands", hands_left, score }: final.
-- Never final until every item the server wrote for me is done. A blind the view has already closed
-- needs nothing set. A blindStart or handScored the server has not got yet is the input queue's to
-- send; until it arrives the view has me not entered, and this asks again.
function reader.hands_after_load(view, game)
	local run = views.run(view)
	if not (run and game.inbox_done == view.onlyMine.inboxNewest) then return { kind = "not yet" } end
	local open, me = views.my_pvp_blind(view, game.blind_key)
	local mine = open and open.stage == "playing" and type(me) == "table"
	if not mine then
		return { kind = views.my_pvp_result(view, game.blind_key) ~= nil and "nothing to set" or "not yet" }
	end
	if me.stage == "not entered" then return { kind = "not yet" } end
	if me.handsLeft == nil then return { kind = "nothing to set" } end
	local score = views.shown_score(me)
	if score == nil then return { kind = "not yet" } end
	return { kind = "set hands", hands_left = me.handsLeft, score = score }
end

-- The blind's result when the view carries one of mine for this blind: its entry key and
-- { lost, timer_lost }; nil otherwise. The screen shows it once per key.
function reader.result_of(view, game)
	local run = views.run(view)
	local entry = run and views.my_pvp_result(view, game.blind_key)
	if not entry then return nil, nil end
	local lost = false
	for _, id in ipairs(entry.losers or {}) do
		lost = lost or id == view.me
	end
	return views.entry_key(run.id, game.blind_key), { lost = lost, timer_lost = (entry.endedBy or {})[view.me] == "timer" }
end

-- The entry key of this blind when my own timer ended my part of it; nil otherwise. The screen shows it once per key.
function reader.timer_out(view, game)
	local open, me = views.my_pvp_blind(view, game.blind_key)
	local mine = open and open.stage == "playing" and type(me) == "table"
	if not (mine and me.stage == "done" and me.endedBy == "timer") then return nil end
	return views.entry_key(view.match.run.id, open.blindKey)
end

-- Lives against the lives the game shows. A drop is shown (once, as the game then shows the new
-- number); a rise is set quietly, its own item shows it. Returns { lives, show } or nil.
function reader.lives_change(shown, view)
	local lives = views.lives_of(view, view and view.me)
	if lives == nil or lives == shown then return nil end
	return { lives = lives, show = shown ~= nil and lives < shown }
end

-- In Teams (team A or B) the other team's side, else nil.
local function other_team(view)
	local mine = view.players and view.players[view.me] and view.players[view.me].team
	if mine == "A" then return "B" end
	if mine == "B" then return "A" end
	return nil
end

-- What the PvP blind says of the opponent: { waiting, ready, hands, score } or nil. Hands and Ready are
-- the paired opponent's; in Teams the score is the other team's total. The score is views.score_of /
-- team_score_of for the open and the closed blind alike (nil while the view hides it).
function reader.opponent_now(view, blind_key)
	local open = views.my_pvp_blind(view, blind_key)
	local id = views.opponent_id(view)
	local team = other_team(view)
	local score
	if team then
		score = views.team_score_of(view, blind_key, team)
	elseif id then
		score = views.score_of(view, blind_key, id)
	end
	if not open then
		if score == nil then return nil end
		return { waiting = false, ready = false, hands = nil, score = score }
	end
	local part = id and open.players[id]
	if not (part or team) then return nil end
	local waiting = open.stage == "waiting"
	local playing = type(part) == "table" and part or {}
	-- A hand still scoring has its hands counted but not its score: the hands wait, as on main.
	local hands = playing.stage ~= "scoring a hand" and playing.handsLeft or nil
	return { waiting = waiting, ready = waiting and part == "ready", hands = hands, score = score }
end

-- The opponent's Ready as the game shows it: their location reads Ready while it holds and Selecting
-- when it lifts. "shown" while they are Ready in a waiting blind, nil otherwise (nil = not shown,
-- the store's empty value, so a first waiting frame shows nothing). Once the blind
-- plays, their location is the progress feed's.
function reader.ready_look(opponent)
	return opponent and opponent.waiting and opponent.ready == true and "shown" or nil
end

return reader
