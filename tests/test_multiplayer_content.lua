local H = dofile("tests/support/harness.lua")
local check, section = H.check, H.section

local NAMES = {
	j_mp_speedrun = "SPEEDRUN",
	j_mp_conjoined_joker = "Conjoined Joker",
	j_mp_defensive_joker = "Defensive Joker",
	j_mp_pizza = "Pizza",
	j_mp_penny_pincher = "Penny Pincher",
	j_mp_pacifist = "Pacifist",
	j_mp_lets_go_gambling = "Let's Go Gambling",
	j_mp_taxes = "Taxes",
	j_mp_skip_off = "Skip-Off",
	c_mp_asteroid = "Asteroid",
	v_mp_hieroglyph_manhunt = "Hieroglyph (Manhunt)",
	v_mp_petroglyph_manhunt = "Petroglyph (Manhunt)",
}

local list = MPAPI.Layers[PVP.LayerKey.MULTIPLAYER_CONTENT]

local CARDS = { "c_mp_asteroid" }
for _, key in ipairs(list.included_jokers) do
	CARDS[#CARDS + 1] = key
end

local function is_banned(key)
	local ruleset = PVP.current_ruleset()
	for _, banned in ipairs(key:match("^j_") and ruleset.banned_jokers or ruleset.banned_consumables) do
		if banned == key then return true end
	end
	return false
end

local function appears(card)
	card = type(card) == "string" and G.P_CENTERS[card] or card
	return not MPAPI.should_exclude_from_pool(card) and not is_banned(card.key)
end

local function expect_cards(where, has_cards, banned_names)
	local banned = {}
	for _, name in ipairs(banned_names or {}) do
		banned[name] = true
	end
	for _, key in ipairs(CARDS) do
		local name = NAMES[key]
		if not has_cards then
			check(not appears(key), ("%s: %s should not appear"):format(where, name))
		elseif banned[name] then
			check(is_banned(key), ("%s: %s should be banned"):format(where, name))
		else
			check(appears(key), ("%s: %s should be able to appear"):format(where, name))
		end
	end
end

print("Multiplayer Cards")

section("The Multiplayer Cards are 9 Jokers, Asteroid and 2 Manhunt Vouchers", function()
	local function names(keys)
		local result = {}
		for i, key in ipairs(keys or {}) do
			result[i] = NAMES[key] or key
		end
		table.sort(result)
		return table.concat(result, ", ")
	end
	local function expect_list(keys, expected, what)
		check(names(keys) == names(expected), ("%s should be %s, not %s"):format(what, names(expected), names(keys)))
	end
	expect_list(list.included_jokers, {
		"j_mp_speedrun",
		"j_mp_conjoined_joker",
		"j_mp_defensive_joker",
		"j_mp_pizza",
		"j_mp_penny_pincher",
		"j_mp_pacifist",
		"j_mp_lets_go_gambling",
		"j_mp_taxes",
		"j_mp_skip_off",
	}, "the Jokers")
	expect_list(list.included_consumables, { "c_mp_asteroid" }, "the Planet cards")
	expect_list(list.reworked_vouchers, { "v_mp_hieroglyph_manhunt", "v_mp_petroglyph_manhunt" }, "the Vouchers")
	check(list.reworked_jokers == nil, "Multiplayer Cards should be new cards, not reworked base-game Jokers")
	for key, name in pairs(NAMES) do
		check(G.P_CENTERS[key], name .. " should exist in the game")
	end
end)

section("Only cards on the Multiplayer Cards list can appear", function()
	H.start_run("expanded", "lobby")
	local unlisted = { key = "j_mp_unlisted", mod = { id = PVP.id } }
	SMODS.Joker.register(unlisted)
	check(not appears(unlisted), "a new multiplayer Joker missing from the list should not appear")

	local expanded = MPAPI.Rulesets.ruleset_mp_expanded
	local order = expanded._layer_order
	expanded._layer_order = { "standard" }
	local ok, err = pcall(expect_cards, "Expanded without Multiplayer Cards", false)
	expanded._layer_order = order
	if not ok then error(err, 0) end

	PVP.Ruleset({ key = "cards_only", layers = { PVP.LayerKey.MULTIPLAYER_CONTENT } }):inject()
	H.start_run("cards_only", "lobby")
	check(
		#PVP.current_ruleset().reworked_jokers == 0,
		"adding Multiplayer Cards should not rework any base-game Jokers"
	)
	expect_cards("a ruleset of only Multiplayer Cards", true)
end)

-- stylua: ignore start
local RULESETS = {
	--  ruleset                uses them  banned
	{ "balanced",              true,      { "SPEEDRUN", "Conjoined Joker", "Defensive Joker" } },
	{ "expanded",              true,      { "SPEEDRUN", "Conjoined Joker", "Defensive Joker" } },
	{ "smallworld",            true,      { "SPEEDRUN", "Conjoined Joker", "Defensive Joker" } },
	{ "speedlatro",            true,      { "SPEEDRUN", "Conjoined Joker", "Defensive Joker" } },
	{ "traditional",           true,      { "SPEEDRUN", "Conjoined Joker", "Defensive Joker" } },
	{ "chaos",                 true,      { "SPEEDRUN", "Conjoined Joker", "Defensive Joker" } },
	{ "sandbox",               true,      { "Conjoined Joker" } },
	{ "badlatro",              true,      { "Defensive Joker" } },
	{ "experimental",          true,      { "SPEEDRUN" } },
	{ "experimental_legacy",   true,      { "Asteroid" } },
	{ "vanilla",               false },
	{ "legacy_ranked",         false },
	{ "majorleague",           false },
	{ "minorleague",           false },
	{ "wsob",                  false },
}
-- stylua: ignore end
local BANNED = {}
for _, row in ipairs(RULESETS) do
	BANNED[row[1]] = row[3]
end

section("Each ruleset uses or leaves out the Multiplayer Cards, and bans the right ones", function()
	for _, row in ipairs(RULESETS) do
		local ruleset, uses_them, banned = row[1], row[2], row[3]
		for _, kind in ipairs(H.RUN_KINDS) do
			H.start_run(ruleset, kind)
			expect_cards(("%s, %s run"):format(ruleset, kind), uses_them, banned)
		end
	end
	return ("%d rulesets, in lobby and Practice runs"):format(#RULESETS)
end)

section("A normal run after a multiplayer lobby has no Multiplayer Cards", function()
	H.start_run("expanded", "lobby")
	H.start_run("expanded", "normal")
	expect_cards("normal run after an Expanded lobby", false)
	check(next(G.GAME.banned_keys) == nil, "deciding which cards appear should never add to the run's banned cards")
end)

section("Cards with their own rules", function()
	H.start_run("expanded", "lobby")
	local hieroglyph = G.P_CENTERS.v_mp_hieroglyph_manhunt
	check(not hieroglyph:in_pool(), "Hieroglyph (Manhunt) should not appear outside Manhunt")
	PVP.LOBBY.config.manhunt = true
	check(hieroglyph:in_pool() and appears(hieroglyph), "Hieroglyph (Manhunt) should be able to appear in Manhunt")

	H.start_run("experimental_legacy", "lobby")
	for _, key in ipairs(PVP.current_ruleset().reworked_jokers) do
		check(
			key ~= "j_mp_lets_go_gambling",
			"Experimental Legacy should use the original Let's Go Gambling, not a reworked one"
		)
	end

	H.start_run("sandbox", "lobby")
	local magnet = G.P_CENTERS.j_mp_magnet_sandbox
	local rotation
	for _, joker in ipairs(PVP.SANDBOX.joker_mappings) do
		if joker.sandbox == magnet.key then rotation = joker end
	end
	local sandbox = MPAPI.Rulesets.ruleset_mp_sandbox
	local order = sandbox._layer_order
	rotation.active = true
	local ok, err = pcall(function()
		check(appears(magnet), "Magnet should be able to appear in Sandbox while it is in rotation")
		sandbox._layer_order = { PVP.LayerKey.SANDBOX }
		check(not appears(magnet), "Magnet should not appear in Sandbox without the Multiplayer Cards")
	end)
	sandbox._layer_order = order
	rotation.active = false
	if not ok then error(err, 0) end
	return "Manhunt Vouchers, Let's Go Gambling, Magnet"
end)

H.finish()
