-- In-memory save of the current run. Vanilla save_run() builds the save table
-- at once in G.ARGS.save_run and only queues the file write for later, so the
-- table is the safe thing to resume from. The save file is not: it is written
-- a frame later, and game over removes it. Saving is switched on here because
-- a lobby switches it off.
function PVP.take_run_snapshot(game, save_run_fn)
	game.F_NO_SAVING = false
	game.ARGS.save_run = nil
	save_run_fn()
	return game.ARGS.save_run
end

local VANILLA_BLIND = { Small = "bl_small", Big = "bl_big" }

-- Moves the playing cards of the hand, play and discard areas back into the
-- deck, so a run saved mid-blind resumes with a full deck at blind select.
local function return_cards_to_deck(card_areas)
	local deck = card_areas.deck
	if not deck then return end
	for _, name in ipairs({ "hand", "play", "discard" }) do
		local area = card_areas[name]
		if area then
			for _, card in ipairs(area.cards) do
				deck.cards[#deck.cards + 1] = card
			end
			area.cards = {}
		end
	end
end

-- Turns a save made at the end of a PvP match into a save a solo run can
-- resume. The PvP blind (or a game over) counts as beaten: the run resumes at
-- ROUND_EVAL, as vanilla saves it right after a blind is won, so vanilla shows
-- the cash out and then the shop. After a Boss blind the ante goes up here,
-- the way end_round() does it before ROUND_EVAL; vanilla's cash out then
-- resets the blinds for the new ante. Every PvP blind choice is replaced by a
-- vanilla one. A save that is not in a PvP blind or game over is returned
-- unchanged.
--   ctx.states           { GAME_OVER = n, ROUND_EVAL = n } (G.STATES)
--   ctx.nemesis_key      key of the PvP blind
--   ctx.fallback_boss    key of a vanilla boss for the Boss slot (optional)
--   ctx.next_vouchers    function giving the shop vouchers a Boss blind unlocks, as the
--                        table Steamodded keeps in current_round.voucher (optional)
function PVP.solo_resume_snapshot(snap, ctx)
	local game = snap.GAME
	local in_pvp_blind = snap.BLIND and snap.BLIND.config_blind == ctx.nemesis_key
	local game_over = snap.STATE == ctx.states.GAME_OVER

	if game.round_resets then
		game.round_resets.pvp_blind_choices = {}
		local choices = game.round_resets.blind_choices or {}
		for slot, key in pairs(choices) do
			if key == ctx.nemesis_key then choices[slot] = VANILLA_BLIND[slot] or ctx.fallback_boss or key end
		end
	end
	if not (in_pvp_blind or game_over) then return snap end

	return_cards_to_deck(snap.cardAreas)
	local on_deck = game.blind_on_deck or "Small"
	game.round_resets.blind_states[on_deck] = "Defeated"
	if on_deck == "Boss" then
		game.round_resets.ante = game.round_resets.ante + 1
		if ctx.next_vouchers then game.current_round.voucher = ctx.next_vouchers() end
		for _, card in ipairs(snap.cardAreas.deck.cards) do
			if type(card) == "table" and card.ability then card.ability.played_this_ante = nil end
		end
	end

	-- Beaten, so the blind's reward is paid on the cash out screen.
	local needed = snap.BLIND.chips or 0
	if (game.chips or 0) < needed then game.chips = needed end
	snap.STATE = ctx.states.ROUND_EVAL
	snap.ACTION = nil
	return snap
end
