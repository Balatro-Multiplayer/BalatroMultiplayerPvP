-- Multiplayer Cards: the Jokers, Planet card and Vouchers made for multiplayer.
-- These checks pin down which rulesets use them, which of them each ruleset
-- bans, and how the lobby's "Multiplayer Cards" setting (Default / On / Off)
-- changes that.
--
-- "Appear" means the card can show up in the shop and in packs during a run.
-- A banned card never appears, the same as a challenge's banned cards.
--
-- The real MPAPI and PvP code runs; the game itself is stubbed
-- (tests/support/harness.lua). Shops are not rolled and no hands are played;
-- tests/scenarios/multiplayer_content.lua checks real shops in-game.
--
-- Run from PvP's root, pointing at the matching MPAPI checkout:
--   lua tests/test_multiplayer_content.lua /path/to/BalatroMultiplayerAPI
--   luajit tests/test_multiplayer_content.lua /path/to/BalatroMultiplayerAPI
local H = dofile("tests/support/harness.lua")
local check, section = H.check, H.section
local Setting = PVP.ContentMode

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
local SETTING_NAMES = { [Setting.DEFAULT] = "Default", [Setting.ON] = "On", [Setting.OFF] = "Off" }

local list = MPAPI.Layers[PVP.LayerKey.MULTIPLAYER_CONTENT]

-- The Jokers and Asteroid. The Manhunt Vouchers are left out here: they only
-- ever appear in Manhunt, which has its own check below.
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

-- Checks each Multiplayer Card in the current run: none appear when the run
-- has no Multiplayer Cards; otherwise the banned ones are banned and the rest appear.
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
	expect_list(list.included_vouchers, { "v_mp_hieroglyph_manhunt", "v_mp_petroglyph_manhunt" }, "the Vouchers")
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

	-- Expanded with the Multiplayer Cards taken out of it.
	local expanded = MPAPI.Rulesets.ruleset_mp_expanded
	local order = expanded._layer_order
	expanded._layer_order = { "standard" }
	local ok, err = pcall(expect_cards, "Expanded without Multiplayer Cards", false)
	expanded._layer_order = order
	if not ok then error(err, 0) end

	-- A ruleset that is only the Multiplayer Cards, and nothing else.
	PVP.Ruleset({ key = "cards_only", multiplayer_content = true, layers = { PVP.LayerKey.MULTIPLAYER_CONTENT } })
		:inject()
	H.start_run("cards_only", "lobby")
	check(
		#PVP.current_ruleset().reworked_jokers == 0,
		"adding Multiplayer Cards should not rework any base-game Jokers"
	)
	expect_cards("a ruleset of only Multiplayer Cards", true)
end)

-- Which rulesets use the Multiplayer Cards, and which of those cards each one bans.
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

-- The lobby's "Multiplayer Cards" setting. Default follows the ruleset, On adds
-- the cards even to Vanilla, and Off removes them even from Expanded.
-- stylua: ignore start
local SETTING = {
	--  ruleset      Default  On     Off
	{ "vanilla",     false,   true,  false },
	{ "expanded",    true,    true,  false },
}
-- stylua: ignore end

section("The Multiplayer Cards setting: Default, On and Off", function()
	for _, row in ipairs(SETTING) do
		local ruleset = row[1]
		for i, setting in ipairs({ Setting.DEFAULT, Setting.ON, Setting.OFF }) do
			for _, kind in ipairs(H.RUN_KINDS) do
				local where = ("%s set to %s, %s run"):format(ruleset, SETTING_NAMES[setting], kind)
				H.start_run(ruleset, kind)
				PVP.set_multiplayer_content_mode(setting)
				check(PVP.multiplayer_content_mode() == setting, where .. ": the setting should read back the same")
				expect_cards(where, row[i + 1], BANNED[ruleset])
			end
		end
	end

	H.start_run("vanilla", "lobby")
	PVP.set_multiplayer_content_mode(Setting.ON)
	check(
		MPAPI.Rulesets.ruleset_mp_vanilla.multiplayer_content == false,
		"turning the setting On in one lobby should not change the Vanilla ruleset itself"
	)
	return "Vanilla and Expanded, in lobby and Practice runs"
end)

section("Changing the setting keeps the ruleset's own timers", function()
	for _, setting in ipairs({ Setting.DEFAULT, Setting.ON, Setting.OFF }) do
		H.start_run("experimental", "lobby")
		PVP.set_multiplayer_content_mode(setting)
		local where = "Experimental set to " .. SETTING_NAMES[setting]
		check(MPAPI.has_modifier("pvp_timer"), where .. ": should keep its PvP timer")
		check(MPAPI.has_modifier("pressure_timer"), where .. ": should keep its pressure timer")
	end
end)

section("A normal run after a multiplayer lobby has no Multiplayer Cards", function()
	H.start_run("expanded", "lobby")
	PVP.set_multiplayer_content_mode(Setting.ON)
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
	rotation.active = true
	local ok, err = pcall(function()
		check(appears(magnet), "Magnet should be able to appear in Sandbox while it is in rotation")
		PVP.set_multiplayer_content_mode(Setting.OFF)
		check(not appears(magnet), "Magnet should not appear in Sandbox with the setting Off")
	end)
	rotation.active = false
	if not ok then error(err, 0) end
	return "Manhunt Vouchers, Let's Go Gambling, Magnet"
end)

section("Only the host of a private lobby can change the setting, before the run starts", function()
	H.open_private_lobby({ ruleset = "ruleset_mp_vanilla", modifier_layers = "" })
	local picker = H.picker("mp_pvp_content_pick")
	check(picker and #picker.options == 3, "a private lobby should offer Default, On and Off")
	check(picker.current_option == 1, "the setting should start on Default")

	G.FUNCS.mp_pvp_change_content({ to_key = 2 })
	check(PVP.multiplayer_content_enabled(), "the host turning it On should add the cards")
	G.FUNCS.mp_pvp_change_ruleset({ to_key = 3 })
	check(PVP.multiplayer_content_mode() == Setting.ON, "switching ruleset should keep the setting On")
	G.FUNCS.mp_pvp_change_content({ to_key = 3 })
	check(not PVP.multiplayer_content_enabled(), "the host turning it Off should remove Expanded's cards")
	G.FUNCS.mp_pvp_change_ruleset({ to_key = 1 })
	check(PVP.multiplayer_content_mode() == Setting.OFF, "switching ruleset should keep the setting Off")
	G.FUNCS.mp_pvp_change_content({ to_key = 1 })

	local function cannot_change(who)
		G.FUNCS.mp_pvp_change_content({ to_key = 2 })
		check(PVP.multiplayer_content_mode() == Setting.DEFAULT, who .. " should not be able to change the setting")
	end
	H.lobby.is_host = false
	cannot_change("a player who isn't the host")
	H.lobby.is_host, H.lobby.started = true, true
	cannot_change("the host, once the run has started,")
	H.lobby.started, PVP._pvp_kind = false, PVP.LobbyAccess.RANKED
	cannot_change("the host of a ranked lobby")
end)

section("Other players, replays and reconnects get the same setting", function()
	local OFF = PVP.LayerKey.NO_MULTIPLAYER_CONTENT

	H.open_private_lobby({ ruleset = "ruleset_mp_vanilla", modifier_layers = "" })
	G.FUNCS.mp_pvp_change_content({ to_key = 2 })
	local shared = H.lobby.meta.modifier_layers
	H.open_private_lobby({ ruleset = "ruleset_mp_vanilla", modifier_layers = shared })
	check(PVP.multiplayer_content_mode() == Setting.ON, "a player joining should get the host's On")
	H.lobby:set_metadata({ _ref = {} })
	check(PVP.multiplayer_content_mode() == Setting.ON, "an unrelated lobby update should keep the setting")

	H.receive_metadata({ ruleset = "ruleset_mp_expanded", modifier_layers = OFF })
	check(not PVP.multiplayer_content_enabled(), "a player should get the host's Off")
	H.receive_metadata({ ruleset = "ruleset_mp_vanilla" })
	check(
		PVP.multiplayer_content_mode() == Setting.DEFAULT,
		"a lobby from a version without the setting should use Default"
	)

	PVP.set_multiplayer_content_mode(Setting.ON)
	PVP._join_ranked_ruleset("ruleset_mp_vanilla")
	check(PVP.multiplayer_content_mode() == Setting.DEFAULT, "a ranked match should not keep a private lobby's On")

	check(H.replay_bootstrap({ modifier_layers = OFF }).modifier_layers == OFF, "a replay should keep the setting Off")
	check(
		H.rejoin_bootstrap({ modifier_layers = OFF }).modifier_layers == OFF,
		"a reconnect should keep the setting Off"
	)
	return "joining, lobby updates, ranked, replays, reconnects"
end)

H.finish()
