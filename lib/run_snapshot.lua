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

local NEXT_BLIND = { Small = "Big", Big = "Boss", Boss = "Small" }
local VANILLA_BLIND = { Small = "bl_small", Big = "bl_big" }

local function blank_blind()
	return {
		name = "",
		dollars = 0,
		debuff = {},
		mult = 0,
		disabled = false,
		boss = false,
		config_blind = "",
		chips = 0,
		chip_text = "",
		hands = {},
		triggered = false,
	}
end

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
-- resume. The PvP blind (or a game over) is treated as finished: the run
-- resumes at blind select of the next round of the same ante, with every PvP
-- blind replaced by a vanilla one. A save that is not in a PvP blind or game
-- over is returned unchanged.
--   ctx.states        { GAME_OVER = n, BLIND_SELECT = n } (G.STATES)
--   ctx.nemesis_key   key of the PvP blind
--   ctx.fallback_boss key of a vanilla boss for the Boss slot (optional)
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

	local states = game.round_resets.blind_states
	local on_deck = game.blind_on_deck or "Small"
	local next_on_deck = NEXT_BLIND[on_deck]
	if next_on_deck == "Small" then
		-- The boss was the PvP blind: start the same ante's blinds again.
		states.Small, states.Big, states.Boss = "Select", "Upcoming", "Upcoming"
	else
		states[on_deck] = "Defeated"
		states[next_on_deck] = "Select"
	end
	game.blind_on_deck = next_on_deck

	snap.STATE = ctx.states.BLIND_SELECT
	snap.ACTION = nil
	snap.BLIND = blank_blind()
	return_cards_to_deck(snap.cardAreas)
	return snap
end
