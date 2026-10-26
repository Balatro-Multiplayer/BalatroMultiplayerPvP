-- Multiplayer content contract: which rulesets and lobby choices put PvP's
-- original cards in a run's pools. Uses the real MPAPI layer/pool code and PvP
-- content; the game, SMODS and networking are stubbed (tests/support/harness.lua).
-- Does not simulate gameplay, real networking, saves or full replay.
--
-- Run from PvP's root, against the matching MPAPI checkout, under both runtimes:
--   lua tests/test_multiplayer_content.lua /path/to/BalatroMultiplayerAPI
--   luajit tests/test_multiplayer_content.lua /path/to/BalatroMultiplayerAPI
--
-- Real pool generation runs in-game: tests/scenarios/multiplayer_content.lua.
local H = dofile("tests/support/harness.lua")
local check, section = H.check, H.section

local CONTENT = PVP.LayerKey.MULTIPLAYER_CONTENT
local OFF = PVP.LayerKey.NO_MULTIPLAYER_CONTENT
local layer = MPAPI.Layers[CONTENT]
local Mode = PVP.ContentMode

-- Every card the content layer owns, across its included_* lists.
local OWNED = {}
for _, field in ipairs({ "included_jokers", "included_consumables", "included_vouchers" }) do
	for _, key in ipairs(layer[field]) do
		OWNED[#OWNED + 1] = key
	end
end
-- Manhunt vouchers are owned but also restricted to their format by in_pool.
local POOLED = { "c_mp_asteroid" }
for _, key in ipairs(layer.included_jokers) do
	POOLED[#POOLED + 1] = key
end

-- One check over every pooled card, naming the first in the wrong state.
local function expect_pool(included, where)
	local wrong
	for _, key in ipairs(POOLED) do
		wrong = wrong or (H.excluded(key) == included and key)
	end
	check(not wrong, ("%s: %s should be %s"):format(where, tostring(wrong), included and "included" or "excluded"))
end

print("Multiplayer content")

section("Layer owns 9 Jokers, Asteroid and 2 Manhunt vouchers; each is pool-gated", function()
	check(#layer.included_jokers == 9, "expected 9 included Jokers, got " .. #layer.included_jokers)
	check(layer.included_consumables[1] == "c_mp_asteroid", "Asteroid is not in included_consumables")
	check(#layer.included_vouchers == 2, "expected 2 included vouchers")
	check(layer.reworked_jokers == nil, "originals are listed as reworks")
	for _, key in ipairs(OWNED) do
		check(G.P_CENTERS[key], key .. " is not registered")
		check(type(G.P_CENTERS[key].mp_include) == "function", key .. " has no generated pool gate")
	end
end)

section("Only layer membership admits PvP content (default-deny)", function()
	H.enter("expanded", "live")
	local unlisted = { key = "j_mp_unlisted", mod = { id = PVP.id } }
	SMODS.Joker.register(unlisted)
	check(H.excluded(unlisted), "an unlisted PvP Joker reached the pool")

	-- Expanded minus the content layer: the inherited flag stays true but
	-- admits nothing.
	local expanded = MPAPI.Rulesets.ruleset_mp_expanded
	local order = expanded._layer_order
	expanded._layer_order = { "standard" }
	check(PVP.current_ruleset().multiplayer_content == true, "standard no longer sets the content flag")
	local ok, err = pcall(expect_pool, false, "flag without layer")
	expanded._layer_order = order
	if not ok then error(err, 0) end

	PVP.Ruleset({ key = "content_only", multiplayer_content = true, layers = { CONTENT } }):inject()
	H.enter("content_only", "live")
	check(#PVP.current_ruleset().reworked_jokers == 0, "the content layer brought balance reworks with it")
	expect_pool(true, "content layer alone")
end)

-- stylua: ignore start
--  ruleset                composes  Conjoined banned
local RULESETS = {
	{ "balanced",            true,     true  },
	{ "expanded",            true,     true  },
	{ "smallworld",          true,     true  },
	{ "speedlatro",          true,     true  },
	{ "traditional",         true,     true  },
	{ "sandbox",             true,     true  },
	{ "chaos",               true,     true  },
	{ "badlatro",            true,     false },
	{ "experimental",        true,     false },
	{ "experimental_legacy", true,     false },
	{ "vanilla",             false },
	{ "legacy_ranked",       false },
	{ "majorleague",         false },
	{ "minorleague",         false },
	{ "wsob",                false },
}
-- stylua: ignore end

section("Rulesets compose the content layer", function()
	for _, row in ipairs(RULESETS) do
		local short, composes, conjoined_banned = row[1], row[2], row[3]
		for _, run in ipairs(H.CONTEXTS) do
			local where = short .. " / " .. run
			H.enter(short, run)
			check(PVP.is_layer_active(CONTENT) == composes, where .. ": layer composition differs from the table")
			check(PVP.multiplayer_content_enabled() == composes, where .. ": content enabled differs from the table")
			expect_pool(composes, where)
			if composes then
				local banned = false
				for _, key in ipairs(PVP.current_ruleset().banned_jokers) do
					banned = banned or key == "j_mp_conjoined_joker"
				end
				check(banned == conjoined_banned, where .. ": Conjoined ban differs from the table")
			end
		end
	end
	return ("%d rulesets × live/Practice"):format(#RULESETS)
end)

-- stylua: ignore start
--  ruleset       Default  On     Off      (same in live and Practice)
local CHOICES = {
	{ "vanilla",  false,   true,  false },
	{ "expanded", true,    true,  false },
}
-- stylua: ignore end

section("Lobby choice resolves per ruleset", function()
	for _, row in ipairs(CHOICES) do
		local short = row[1]
		for i, mode in ipairs({ Mode.DEFAULT, Mode.ON, Mode.OFF }) do
			local expected = row[i + 1]
			for _, run in ipairs(H.CONTEXTS) do
				local where = ("%s / %s / %s"):format(short, mode, run)
				H.enter(short, run)
				PVP.set_multiplayer_content_mode(mode)
				check(PVP.multiplayer_content_mode() == mode, where .. ": choice not read back from modifiers")
				check(
					PVP.multiplayer_content_enabled() == expected,
					where .. ": content enabled differs from the table"
				)
				expect_pool(expected, where)
			end
		end
	end

	H.enter("vanilla", "live")
	PVP.set_multiplayer_content_mode(Mode.ON)
	check(MPAPI.Rulesets.ruleset_mp_vanilla.multiplayer_content == false, "On mutated the Vanilla ruleset")
	PVP.set_multiplayer_content_mode(Mode.OFF)
	check(not MPAPI.has_modifier(CONTENT), "On and Off are both selected")

	-- Off works by resolving the flag false; any layer doing that vetoes content.
	H.enter("expanded", "live")
	MPAPI.Layer("content_off", { multiplayer_content = false })
	MPAPI.add_modifier("content_off")
	expect_pool(false, "expanded with a false-flag modifier")
	return "2 rulesets × 3 choices × live/Practice"
end)

section("Choices serialize to modifier layers", function()
	local function expect(ruleset, mode, serialized)
		local got = PVP.modifier_layers_for(ruleset, mode)
		check(
			got == serialized,
			("%s / %s: expected %q, got %q"):format(tostring(ruleset), tostring(mode), serialized, got)
		)
	end
	expect("ruleset_mp_vanilla", Mode.DEFAULT, "")
	expect("ruleset_mp_vanilla", Mode.ON, CONTENT)
	expect("ruleset_mp_experimental", Mode.DEFAULT, "pvp_timer,pressure_timer")
	expect("ruleset_mp_experimental", Mode.OFF, "pvp_timer,pressure_timer," .. OFF)
	expect(nil, Mode.ON, CONTENT)

	H.enter("expanded", "live")
	PVP.set_multiplayer_content_mode(Mode.OFF)
	local serialized = PVP.LOBBY.config.modifier_layers
	MPAPI.MODIFIERS = {}
	PVP.set_modifier_layers(serialized)
	check(PVP.multiplayer_content_mode() == Mode.OFF, "Off did not survive a serialize/parse round trip")
end)

section("Content stays out of vanilla runs; no bans created", function()
	H.enter("expanded", "live")
	PVP.set_multiplayer_content_mode(Mode.ON)
	H.enter("expanded", "vanilla")
	expect_pool(false, "vanilla run after an Expanded lobby")
	check(next(G.GAME.banned_keys) == nil, "a membership decision wrote to banned_keys")
end)

section("Format- and layer-specific cards", function()
	H.enter("expanded", "live")
	local hieroglyph = G.P_CENTERS.v_mp_hieroglyph_manhunt
	check(not hieroglyph:in_pool(), "Manhunt voucher offered outside Manhunt")
	PVP.LOBBY.config.manhunt = true
	check(hieroglyph:in_pool(), "Manhunt voucher withheld in Manhunt")
	check(not H.excluded(hieroglyph), "Manhunt voucher not admitted by the content layer")

	H.enter("experimental_legacy", "live")
	check(not H.excluded("j_mp_lets_go_gambling"), "legacy Experimental lost Let's Go Gambling")
	check(
		#MPAPI.Rulesets.ruleset_mp_experimental_legacy.reworked_jokers == 1,
		"legacy Experimental lists an original as a rework"
	)

	H.enter("sandbox", "live")
	local magnet = G.P_CENTERS.j_mp_magnet_sandbox
	local mapping
	for _, candidate in ipairs(PVP.SANDBOX.joker_mappings) do
		if candidate.sandbox == magnet.key then mapping = candidate end
	end
	mapping.active = true
	local ok, err = pcall(function()
		check(not H.excluded(magnet), "Magnet excluded while in Sandbox rotation")
		PVP.set_multiplayer_content_mode(Mode.OFF)
		check(H.excluded(magnet), "Magnet ignores the Off choice")
	end)
	mapping.active = false
	if not ok then error(err, 0) end
	return "Manhunt vouchers, legacy LGG, Magnet"
end)

section("Private-lobby host can edit; guest, started and ranked cannot", function()
	H.open_private_lobby({ ruleset = "ruleset_mp_vanilla", modifier_layers = "" })
	local picker = H.picker("mp_pvp_content_pick")
	check(picker and #picker.options == 3, "private lobby has no Default/On/Off picker")
	check(picker.current_option == 1, "picker does not start on Default")

	G.FUNCS.mp_pvp_change_content({ to_key = 2 })
	check(H.lobby.meta.modifier_layers == CONTENT, "On did not reach shared metadata")
	check(PVP.multiplayer_content_enabled(), "On did not enable content for the host")
	G.FUNCS.mp_pvp_change_ruleset({ to_key = 3 })
	check(PVP.multiplayer_content_mode() == Mode.ON, "changing ruleset dropped On")
	G.FUNCS.mp_pvp_change_content({ to_key = 3 })
	check(not PVP.multiplayer_content_enabled(), "Off did not suppress Expanded's content")
	G.FUNCS.mp_pvp_change_ruleset({ to_key = 1 })
	check(PVP.multiplayer_content_mode() == Mode.OFF, "changing ruleset dropped Off")
	G.FUNCS.mp_pvp_change_content({ to_key = 1 })
	check(H.lobby.meta.modifier_layers == "", "Default left a content layer in metadata")

	local function refused(who)
		G.FUNCS.mp_pvp_change_content({ to_key = 2 })
		check(PVP.multiplayer_content_mode() == Mode.DEFAULT, who .. " changed the content choice")
	end
	H.lobby.is_host = false
	refused("guest")
	H.lobby.is_host, H.lobby.started = true, true
	refused("host mid-run")
	H.lobby.started, PVP._pvp_kind = false, PVP.LobbyAccess.RANKED
	refused("ranked host")
end)

section("Metadata, replay and rejoin carry the choice", function()
	H.open_private_lobby({ ruleset = "ruleset_mp_vanilla", modifier_layers = CONTENT })
	check(PVP.multiplayer_content_enabled(), "metadata On not applied on join")
	H.lobby:set_metadata({ _ref = {} })
	check(PVP.multiplayer_content_enabled(), "an unrelated metadata update reset the choice")

	H.receive_metadata({ ruleset = "ruleset_mp_expanded", modifier_layers = OFF })
	check(not PVP.multiplayer_content_enabled(), "metadata Off not applied")
	H.receive_metadata({ ruleset = "ruleset_mp_vanilla" })
	check(PVP.multiplayer_content_mode() == Mode.DEFAULT, "metadata without a choice did not fall back to Default")

	PVP.set_multiplayer_content_mode(Mode.ON)
	PVP._join_ranked_ruleset("ruleset_mp_vanilla")
	check(PVP.multiplayer_content_mode() == Mode.DEFAULT, "ranked entry kept a private lobby's On")

	check(H.replay_bootstrap({ modifier_layers = OFF }).modifier_layers == OFF, "replay dropped the recorded choice")
	check(H.rejoin_bootstrap({ modifier_layers = OFF }).modifier_layers == OFF, "rejoin dropped the recorded choice")
	return "lobby metadata, ranked entry, replay, rejoin"
end)

H.finish()
