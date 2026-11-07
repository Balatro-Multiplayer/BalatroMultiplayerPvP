-- The catalogue is mirrored by the server's RULE_ANTES. Rules compose without
-- pair exclusions; eligibility is only by encounter ante, never by build.
PVP.SHARED_RULES = { definitions = {} }
local R = PVP.SHARED_RULES
for _, entry in ipairs({
	{ "manacle", "The Manacle", "-1 hand size.", 3 },
	{ "psychic", "The Psychic", "Must play exactly 5 cards.", 3 },
	{ "house", "The House", "Initial hand drawn face down.", 3 },
	{ "club", "The Club", "Clubs are debuffed.", 3 },
	{ "goad", "The Goad", "Spades are debuffed.", 3 },
	{ "window", "The Window", "Diamonds are debuffed.", 3 },
	{ "head", "The Head", "Hearts are debuffed.", 3 },
	{ "glass_cannon", "Glass Cannon", "-2 hands (minimum 1); X4 Mult.", 3 },
	{ "tooth", "The Tooth", "Lose $1 per card played.", 3 },
	{ "arm", "The Arm", "Played hand loses 1 level before scoring (minimum 1).", 3 },
	{ "leaf", "Verdant Leaf", "Playing cards debuffed until you sell a Joker.", 4 },
	{ "hook", "The Hook", "Discard 2 random held cards after each played hand.", 5 },
	{ "plant", "The Plant", "Face cards are debuffed.", 5 },
	{ "water", "The Water", "Start with 0 discards.", 5 },
}) do
	R.definitions[entry[1]] = { label = entry[2], text = entry[3], ante = entry[4] }
end

function R.supported(lobby)
	return lobby and lobby.server_features and lobby.server_features.shared_pvp_rules == 1
end

function R.enabled(lobby)
	return lobby
		and R.supported(lobby)
		and MPAPI.has_server_referee(lobby)
		and #lobby:get_players() == 2
		and (lobby:get_metadata() or {}).kind == PVP.LobbyAccess.PRIVATE
		and (lobby:get_metadata() or {}).shared_pvp_rules == true
end

function R.prepare(result)
	if type(result) ~= "table" or type(result.id) ~= "string" or type(result.rules) ~= "table" then return false end
	if type(result.ante) ~= "number" or result.ante < 3 or #result.rules ~= 2 then return false end
	local current_ante = G.GAME.round_resets and G.GAME.round_resets.ante
	if current_ante and result.ante ~= current_ante then return false end
	if result.rules[1] == result.rules[2] then return false end
	for _, key in ipairs(result.rules) do
		local def = R.definitions[key]
		if not def or def.ante > result.ante then return false end
	end
	local previous = G.GAME.pvp_shared_rules
	if previous and previous.id == result.id then return not previous.active and not previous.finished end
	if previous and previous.active then return false end
	G.GAME.pvp_shared_rules = { id = result.id, ante = result.ante, rules = copy_table(result.rules) }
	return true
end

function R.can_start(result)
	return G.STATE == G.STATES.BLIND_SELECT
		and G.blind_select ~= nil
		and G.GAME.round_resets.ante == result.ante
		and (not MPAPI.playback._queues_empty or MPAPI.playback._queues_empty())
end

function R.has(key)
	local state = G.GAME and G.GAME.pvp_shared_rules
	if not state or not state.active or state.finished then return false end
	for _, rule in ipairs(state.rules) do
		if rule == key then return true end
	end
	return false
end

function R.refresh_debuffs()
	for _, card in ipairs(G.playing_cards or {}) do
		SMODS.recalc_debuff(card)
	end
end

function R.activate()
	local state = G.GAME.pvp_shared_rules
	if not state or state.active or state.finished then return end
	state.active = true
	if R.has("manacle") then
		G.hand:change_size(-1)
		state.hand_size_delta = -1
	end
	if R.has("glass_cannon") then
		local hands = G.GAME.current_round.hands_left
		ease_hands_played(math.max(1, hands - 2) - hands)
	end
	if R.has("water") then ease_discard(-G.GAME.current_round.discards_left) end
	R.refresh_debuffs()
end

function R.finish()
	local state = G.GAME and G.GAME.pvp_shared_rules
	if not state or state.finished then return end
	state.finished, state.active = true, false
	if state.hand_size_delta and G.hand then
		G.hand:change_size(-state.hand_size_delta)
		state.hand_size_delta = nil
	end
	-- Hands/discards were encounter-local balances, not round_resets changes.
	-- Debuffs are recalculated through all owners, not cleared unconditionally.
	R.refresh_debuffs()
end
