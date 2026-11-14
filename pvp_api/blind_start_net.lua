-- The PvP blind's starting hands over the server's "pvp.blind_start".
--
-- One request per PvP round, sent once the blind's setup effects ran, so a hands joker
-- (Burglar, Skip-Off) is counted. `pvp.hand` is then only a hand that was played, and the
-- opponent's count comes only from the server's "pvp.round" (pvp_api/enemy_score_net.lua).
-- A refusal is only logged: the state shows the truth.

PVP.BlindStartNet = PVP.BlindStartNet or {}
local N = PVP.BlindStartNet

-- The count is what the blind started with, before any server timer loss: timerLossesApplied is 0.
-- The score is the chips held at that moment, in the wire format of pvp.hand.
local function send(run_id, round_id, hands, score)
	MPAPI.request(
		"pvp.blind_start",
		{ runId = run_id, roundId = round_id, handsLeft = hands, score = score, timerLossesApplied = 0 },
		PVP.NetBasics.refusal_logger("pvp.blind_start")
	)
end

-- Whether any event other than `own` is still queued that can still change the hands. A
-- non-blocking event never holds back the ones behind it, so it is not setup work to wait for.
local function others_queued(own)
	local queue = G.E_MANAGER and G.E_MANAGER.queues and G.E_MANAGER.queues.base
	for _, event in ipairs(queue or {}) do
		if event ~= own and event.blocking ~= false then return true end
	end
	return false
end

-- Reads the hands and the score and sends them, unless this round's was already sent. An unknown
-- count (not a number) is never sent: the server validates the range of a real one. What is sent is
-- kept with the round, so a resend repeats it and never reads the game again.
local function read_and_send(ctx)
	local round = G.GAME and G.GAME.current_round
	if not round then return end
	local sent = PVP.GAME.blind_start
	if sent and sent.run_id == ctx.run_id and sent.round_id == ctx.round_id then return end
	local hands = round.hands_left
	if type(hands) ~= "number" then
		PVP.match_log("info", "[pvp] error: pvp.blind_start not sent: the hands left are unknown")
		return
	end
	local score = PVP.Score.from_game_value(G.GAME.chips)
	PVP.GAME.blind_start = { run_id = ctx.run_id, round_id = ctx.round_id, hands = hands, score = score }
	send(ctx.run_id, ctx.round_id, hands, score)
end

-- Whether the blind the send waits for is still the one being played: the same run, round id and
-- blind, and still facing it.
local function still_current(ctx)
	return PVP.current_run_id() == ctx.run_id
		and PVP.GAME.round_id == ctx.round_id
		and G.GAME ~= nil
		and G.GAME.blind_on_deck == ctx.blind
		and G.GAME.facing_blind == true
end

-- Queues the read. An event that is not done blocks the ones behind it, so a wait is a new
-- event at the end of the queue, behind whatever the queued events just added. The send waits
-- as long as the setup queue has not drained, one check per event; it stops only when the blind
-- it waits for is no longer the current one, and then sends nothing.
local function queue_read(ctx)
	local event
	event = Event({
		func = function()
			if not still_current(ctx) then
				PVP.match_log("info", "[pvp] error: pvp.blind_start not sent: the blind it waited for is over")
			elseif others_queued(event) then
				queue_read(ctx)
			else
				read_and_send(ctx)
			end
			return true
		end,
	})
	G.E_MANAGER:add_event(event)
end

-- The first frame of a PvP blind (ui/game/game_state.lua): sends once the events queued by
-- the blind's setup have run. Never on practice or a lobby that is not PvP's own.
function N.start()
	if PVP.is_practice_mode() or not PVP.NetBasics.pvp_lobby() then return end
	local run_id, round_id = PVP.current_run_id(), PVP.GAME.round_id
	if not run_id or not round_id or not G.GAME then return end
	queue_read({ run_id = run_id, round_id = round_id, blind = G.GAME.blind_on_deck })
end

-- After a socket rejoin or a crash rejoin the server may have lost the count: send the one
-- this round started with again while the server has none for this player (its state
-- `players[me].handsLeft` is null until their blind_start; the server ignores a repeat anyway).
-- The count and score are the ones first sent, not the hands left or the chips now.
function N.resend()
	if PVP.is_practice_mode() then return end
	local lobby = PVP.NetBasics.pvp_lobby()
	local sent = PVP.GAME.blind_start
	if not lobby or not sent then return end
	if sent.run_id ~= PVP.current_run_id() or sent.round_id ~= PVP.GAME.round_id then return end
	local round = MPAPI.get_state("pvp.round")
	if not PVP.RoundFacts.hand_counts(round, sent.run_id, sent.round_id) then return end
	local entry = type(round.players) == "table" and round.players[lobby.player_id] or nil
	if type(entry) ~= "table" or entry.handsLeft ~= nil then return end
	send(sent.run_id, sent.round_id, sent.hands, sent.score)
end
