-- The end of the game on the match net: votes, forfeit and my endGame go out as inputs; the result, the
-- places and the other players' jokers and decks are read back from the view (finish_reader.lua decides).
-- Nothing the server decides is shown before the view says so: a pressed button only waits.
local screen = {}
PVP.finish_screen = screen

local function net()
	return PVP.match_net
end

local function send(kind, body)
	return net().send_live(kind, body)
end

local function warn(text)
	sendWarnMessage("[finish_screen] " .. text, "MULTIPLAYER")
end

-- What this screen has already done for the game on screen: the forfeit and the endGame sent, the end
-- shown, the vote counts seen, the players whose end came (the "finish " marks of PVP.view). A load or a
-- new game is a new G.GAME and starts them empty; a reconnect in the same game keeps them.
local marks = {}
local function marks_of_game()
	if marks.game ~= G.GAME then
		marks = { game = G.GAME }
		PVP.view.forget("finish ")
	end
	return marks
end

local function run_id()
	local view = net().view
	local run = PVP.view.run(view)
	return type(run) == "table" and run.id or nil
end

-- Whether the view is of the run this game is playing: the game's own record names it. After a game ends
-- the net keeps its last view, so a new game can meet the old run's view for a frame.
local function is_my_run(view)
	return PVP.view.is_my_run(view, G.GAME and G.GAME.pvp_net)
end

-- The jokers I hold, in the form the end screen and the roster rebuild them from.
local function my_jokers()
	local jokers = {}
	for _, card in ipairs(G.jokers and G.jokers.cards or {}) do
		local center = card.config and card.config.center
		if center then
			jokers[#jokers + 1] = {
				key = center.key,
				edition = card.edition,
				eternal = card.ability and card.ability.eternal or false,
				perishable = card.ability and card.ability.perishable or false,
			}
		end
	end
	return jokers
end

local function my_deck_text()
	local cards = {}
	for _, card in ipairs(G.playing_cards or {}) do
		cards[#cards + 1] = PVP.UTILS.card_to_string(card)
	end
	return table.concat(cards, ";")
end

function screen.vote(topic)
	if net().waiting("vote") then return nil end
	return send("vote", PVP.finish_reader.vote(topic, true))
end

function screen.forfeit()
	local id = run_id()
	local done = marks_of_game()
	if id == nil or done.forfeited_run == id or net().waiting("forfeit") then return nil end
	local sent = send("forfeit", PVP.finish_reader.forfeit())
	if sent then done.forfeited_run = id end
	return sent
end

-- True while an input of that kind is not confirmed yet: the button shows a neutral waiting look.
function screen.waiting(kind)
	return net().waiting(kind) and true or false
end

-- My endGame goes out once per run, from the first view that has me out or gone, or the match ended.
-- The mark is set when it is queued: the server sends no refusal back.
local function send_end_game(view)
	if not is_my_run(view) then return end
	local done = marks_of_game()
	local due = PVP.finish_reader.end_game_due(done.end_game_sent_for, view)
	if not due or G.STAGE ~= G.STAGES.RUN then return end
	local stats = PVP.GAME and PVP.GAME.stats
	local jokers = MPAPI.encode(my_jokers())
	if not (stats and type(jokers) == "string") then return end
	local body = PVP.finish_reader.end_game(jokers, my_deck_text(), stats.reroll_count, stats.reroll_cost_total)
	if send("endGame", body) then done.end_game_sent_for = due end
end

-- On leaving a shop my jokers go up, so a player who finishes first can see mine on their end screen
-- while I am still playing or if I crash. The server keeps the newest; my endGame replaces them.
function screen.send_jokers()
	local body = PVP.finish_reader.jokers(MPAPI.encode(my_jokers()))
	if not body then warn("my jokers could not be encoded (too big); the last ones sent stay") end
	return send("jokers", body)
end

-- The jokers of one player for the end screen and the roster: my own from my game, another's from the
-- game the view shows (the ended one once the lobby is back). nil jokers = unknown.
function screen.jokers_of(player_id)
	local live = net().view
	if not live then return nil end
	if player_id == live.me then return my_jokers() end
	local view = PVP.view.game(live)
	local other = view and PVP.finish_reader.other_end(view, player_id, MPAPI.decode)
	return other and other.jokers
end

-- A player's best score over the closed PvP blinds as score text, or nil while the view has none.
function screen.best_score_of(player_id)
	return PVP.finish_reader.best_score(PVP.view.game(net().view), player_id, PVP.Score.greater)
end

-- Another player's deck as text, or nil while the view has none (they are still in the run, or it
-- came as "").
function screen.deck_of(player_id)
	local view = PVP.view.game(net().view)
	local other = view and PVP.finish_reader.other_end(view, player_id, MPAPI.decode)
	return other and other.deck
end

local VOTE_KEYS = { seed = "k_seed_vote", draw = "k_draw_vote" }

local function show_end(ended)
	PVP.GAME.end_shown = ended.by == "out" and "by out" or "by result"
	PVP.GAME.end_rank = ended.rank
	PVP.end_pending_death()
	PVP.game_effects[ended.screen]()
end

-- Another player's end, or newer jokers of theirs, arrives after mine: the open end screen takes it when it does.
local function show_other_ends(view)
	local fresh = false
	for id in pairs(view.players or {}) do
		local other = id ~= view.me and PVP.finish_reader.other_end(view, id, MPAPI.decode)
		if other and PVP.view.changed("finish other " .. id, other.mark) then fresh = true end
	end
	if fresh and PVP.UI.refresh_end_game_jokers then PVP.UI.refresh_end_game_jokers() end
end

-- A vote's count changing says so in chat. A replay moves the marker and says nothing.
local function show_vote_progress(view)
	local done = marks_of_game()
	local lines
	done.votes, lines = PVP.finish_reader.vote_progress(done.votes, view)
	if MPAPI.playback.is_driving("pvp") or not (MPAPI.chat and MPAPI.chat.addMessage) then return end
	for _, line in ipairs(lines) do
		MPAPI.chat.addMessage(localize(VOTE_KEYS[line.topic]) .. ": " .. line.count .. "/" .. line.total, G.C.BLUE)
	end
end

function screen.update()
	local view = PVP.view.game(net().view)
	local run = PVP.view.run(view)
	if not run then return end
	if not (G.STAGE == G.STAGES.RUN and PVP.in_session()) or PVP.is_practice_mode() then return end
	if not is_my_run(view) then return end
	marks_of_game()
	send_end_game(view)
	-- A contest owns its own end screen.
	if PVP.GAME.end_shown ~= "by contest" then
		local ended = PVP.finish_reader.my_end(view)
		if ended and not PVP.view.changed("finish end", run.id) then ended = nil end
		if ended and PVP.GAME.end_shown == "not yet" then
			show_end(ended)
		elseif PVP.GAME.end_shown ~= "not yet" then
			-- The end is already shown (out first): the result only says whether the game counts.
			local late = PVP.finish_reader.my_end(view)
			if late and late.rank ~= "unsaid" then PVP.GAME.end_rank = late.rank end
		end
	end
	show_other_ends(view)
	show_vote_progress(view)
end


return screen
