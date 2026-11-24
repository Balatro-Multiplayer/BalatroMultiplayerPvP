-- PVP.ACTIONS.*: the game-side steps of a run that the screens in pvp_api/ call.

function PVP.ACTIONS.set_username(username)
	PVP.LOBBY.username = username or "Guest"
end
function PVP.ACTIONS.set_blind_col(num)
	PVP.LOBBY.blind_col = num or 1
end

-- ── Run start (relocated from the removed legacy ui/lobby/lobby.lua) ──────────────
-- G.FUNCS.lobby_start_run is the actual multiplayer run-starter. It is called by
-- UI.match.start_game and by the API bridge gamemode's (required, but never invoked)
-- start_run in pvp_api/gamemodes.lua. The `mp_start` contract it passes to
-- G.FUNCS.start_run is interpreted by the start_run wrapper relocated to overrides/game.lua.
local function get_random_back_pool()
	local names, seen = {}, {}
	local cocktail_keys = PVP.COCKTAIL.decks(false)
	for i = 1, #cocktail_keys do
		local key = cocktail_keys[i]
		if G.P_CENTERS[key] and not seen[key] then
			seen[key] = true
			names[#names + 1] = G.P_CENTERS[key].name
		end
	end
	if G.P_CENTERS["b_mp_cocktail"] and not seen["b_mp_cocktail"] then
		names[#names + 1] = G.P_CENTERS["b_mp_cocktail"].name
	end
	return names
end

local function scoped_random(seed, salt, max)
	if seed then
		math.randomseed(pseudohash(seed .. "_mp_random_" .. salt))
	end
	return math.random(1, max)
end

local function roll_random_back_name(seed, salt)
	local names = get_random_back_pool()
	if #names == 0 then return "Red Deck" end
	return names[scoped_random(seed, "deck_" .. (salt or ""), #names)]
end

local function roll_random_stake(seed, salt)
	local cap = PVP.DECK.MAX_STAKE > 0 and PVP.DECK.MAX_STAKE or 8
	return scoped_random(seed, "stake_" .. (salt or ""), cap)
end

function G.FUNCS.copy_host_deck()
	PVP.LOBBY.deck.back = PVP.LOBBY.config.back
	-- The lobby config's cocktail is "" until the picker is edited. Keep it unset so every
	-- client builds the default pool, not its own saved selection.
	PVP.LOBBY.deck.cocktail = PVP.LOBBY.config.cocktail or ""
	PVP.LOBBY.deck.sleeve = PVP.LOBBY.config.sleeve
	PVP.LOBBY.deck.stake = PVP.LOBBY.config.stake
	PVP.LOBBY.deck.challenge = PVP.LOBBY.config.challenge
end

---@type fun(e: table | nil, args: { deck: string, stake: number | nil, seed: string | nil })
function G.FUNCS.lobby_start_run(e, args)
	if PVP.LOBBY.config.different_decks == false then G.FUNCS.copy_host_deck() end

	if PVP.LOBBY.config.different_decks and PVP.LOBBY.config.random_loadout then
		PVP.LOBBY.deck.back = roll_random_back_name(args.seed, PVP.LOBBY.username)
		PVP.LOBBY.deck.challenge = ""
		PVP.LOBBY.deck.stake = roll_random_stake(args.seed, PVP.LOBBY.username)
	end

	local challenge = nil
	if PVP.LOBBY.deck.back == "Challenge Deck" then
		challenge = G.CHALLENGES[get_challenge_int_from_id(PVP.LOBBY.deck.challenge)]
	else
		G.GAME.viewed_back = MPAPI.back_for_key(PVP.UTILS.get_deck_key_from_name(PVP.LOBBY.deck.back))
	end

	G.FUNCS.start_run(e, {
		mp_start = true,
		challenge = challenge,
		stake = tonumber(PVP.LOBBY.deck.stake),
		seed = args.seed,
	})
end

-- The Ready press leaves its button; a blind entered without one (after a restart) takes the
-- boss blind's own select button.
function PVP.UI.boss_select_button()
	local choice = G.blind_select_opts and G.blind_select_opts.boss
	return choice and choice:get_UIE_by_ID("select_blind_button")
end

-- `blind` (optional) names the blind when it is no longer the one on deck, as after a skip.
-- `result` is "beaten" or "lost" (a blind failed on the cards: it costs a life where the rules say so).
function PVP.ACTIONS.blind_result(result, blind)
	blind = blind or G.GAME.blind_on_deck
	if MPAPI.get_current_lobby() then PVP.UI.run.blind_result(blind, result) end
end

function PVP.ACTIONS.fail_blind(hands_used)
	if PVP.LOBBY.config.no_gold_on_pvp_loss then G.GAME.blind.dollars = 0 end
	if hands_used == 0 then return end
	PVP.ACTIONS.blind_result("lost")
end

function PVP.ACTIONS.set_location(location, blind)
	local location_type = location
	local location_blind = blind
	if string.find(location, "-") then
		local split = {}
		for str in string.gmatch(location, "([^-]+)") do
			table.insert(split, str)
		end
		location_type = split[1]
		location_blind = split[2] or ""
	else
		location_blind = PVP.UTILS.get_blind_to_display(blind) or ""
	end
	location = location_type .. "-" .. location_blind

	if PVP.GAME.location == location then return end
	PVP.GAME.location = location
	PVP.GAME.location_type = location_type
	PVP.GAME.location_blind = location_blind
	PVP.GAME.location_full = location
	PVP.UI.run.progress(location)
end

function PVP.ACTIONS.update_location(keep_blind)
	if PVP.GAME.location_type then
		PVP.ACTIONS.set_location(PVP.GAME.location_type, keep_blind and PVP.GAME.location_blind or nil)
	end
end

---@param score number
---@param hands_left number
function PVP.ACTIONS.play_hand(score, hands_left)
	local score_text = PVP.SCORE.from_game_value(score)
	PVP.GAME.score = score_text
	if PVP.SCORE.greater(score_text, PVP.GAME.highest_score) then
		PVP.GAME.highest_score = score_text
	end
	-- The end-of-run roster's "highest PvP-blind score" is PvP-blind-only,
	-- unlike the any-blind figure just above.
	if PVP.UTILS.is_pvp_blind() and PVP.SCORE.greater(score_text, PVP.GAME.highest_pvp_score) then
		PVP.GAME.highest_pvp_score = score_text
	end

	-- The replay log keeps each hand's result.
	if PVP.REPLAY.log then PVP.REPLAY.log.record(MPAPI.OPCODE.HAND_RESULT, { score_text, hands_left }) end
	PVP.UI.pvp_blind.hand_scored(score_text, hands_left)
end

function PVP.ACTIONS.set_ante(ante)
	PVP.UI.run.ante_changed(ante)
end

function PVP.ACTIONS.new_round()
	PVP.GAME.duplicate_end = false
	PVP.GAME.blind_ended = false
end
