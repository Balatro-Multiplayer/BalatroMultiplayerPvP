-- Real Judgement use, controlled namespaced rolls, actual save reconstruction.
-- Does not estimate outcome frequencies or prove network/replay behavior.
local saved, native_random, created, existing
local function controlled(legendary, rarity, edition)
	native_random = native_random or pseudorandom
	pseudorandom = function(seed, ...)
		if type(seed) == "string" then
			if seed:find("^pvp_higher_calling_legendary") then return legendary end
			if seed:find("^pvp_higher_calling_rarity") then return rarity end
			if seed:find("^pvp_higher_calling_edition") then return edition end
		end
		return native_random(seed, ...)
	end
end
local function use_judgement()
	local tarot = SMODS.create_card({ key = "c_judgement", area = G.consumeables })
	tarot:add_to_deck()
	G.consumeables:emplace(tarot)
	assert(tarot:can_use_consumeable(), "Judgement must have a free Joker slot")
	G.FUNCS.use_card({ config = { ref_table = tarot } })
end
local function selector_ready()
	return G.STATE == G.STATES.BLIND_SELECT
		and G.blind_select
		and not G.CONTROLLER.locked
		and (not G.GAME.STOP_USE or G.GAME.STOP_USE <= 0)
end
return {
	{
		run = function(S)
			S.check(
				PVP.SOLO.start({
					ruleset = "ruleset_mp_vanilla",
					deck = "b_red",
					stake = 1,
					seed = "CALLING",
					modifiers = {},
				}),
				"Higher Calling solo starts"
			)
		end,
	},
	{
		until_ = selector_ready,
		timeout = 20,
		run = function(S)
			G.FUNCS.options()
			G.OVERLAY_MENU:get_UIE_by_ID("pvp_chaos_lab_open"):click()
			local keys = {}
			for key in pairs(PVP.CHAOS.effects) do
				keys[#keys + 1] = key
			end
			table.sort(keys)
			for i, key in ipairs(keys) do
				if key == "higher_calling" then G.FUNCS.pvp_chaos_choose({ to_key = i }) end
			end
			G.OVERLAY_MENU:get_UIE_by_ID("pvp_chaos_activate"):click()
			S.check(PVP.CHAOS.has_rule("higher_calling"), "Real lab button activates Higher Calling")
			G.FUNCS.exit_overlay_menu()
			controlled(0, 0.99, 0)
			use_judgement()
		end,
	},
	{
		until_ = function()
			return #G.jokers.cards == 1 and selector_ready()
		end,
		timeout = 20,
		run = function(S)
			created = G.jokers.cards[1]
			S.check(created.config.center.rarity == 4, "Actual Judgement creates a Legendary on the controlled roll")
			S.check(created.edition and created.edition.negative, "Actual Judgement result receives Negative")
			existing = created.config.center.key
			G.GAME.banned_keys[existing] = true
			-- Ban all Legendary identities to exercise the real pool's fallback.
			for _, center in ipairs(G.P_JOKER_RARITY_POOLS[4]) do
				G.GAME.banned_keys[center.key] = true
			end
			controlled(0, 0.99, 0.008)
			use_judgement()
		end,
	},
	{
		until_ = function()
			return #G.jokers.cards == 2 and selector_ready()
		end,
		timeout = 20,
		run = function(S)
			local second = G.jokers.cards[2]
			S.check(second.config.center.rarity == 3, "Empty Legendary pool falls back to boosted ordinary rarity")
			S.check(second.edition and second.edition.polychrome, "Actual Judgement result receives Polychrome")
			save_run()
			saved = STR_UNPACK(STR_PACK(G.ARGS.save_run))
			S.check(saved.GAME.pvp_chaos.ante == 1, "Save records the effect's ante anchor")
			pseudorandom = native_random
			G.FUNCS.go_to_menu()
		end,
	},
	{
		until_ = function()
			return G.STATE == G.STATES.MENU
		end,
		run = function()
			G:start_run({ savetext = saved })
		end,
	},
	{
		until_ = selector_ready,
		timeout = 20,
		run = function(S)
			S.check(PVP.CHAOS.has_rule("higher_calling"), "Higher Calling survives real save reconstruction")
			S.check(#G.jokers.cards == 2, "Reconstruction does not duplicate grants")
			S.check(G.jokers.cards[1].config.center.key == existing, "Earned Legendary persists")
			ease_ante(1)
		end,
	},
	{
		until_ = function()
			return G.GAME.round_resets.ante == 2 and not PVP.CHAOS.has_rule("higher_calling")
		end,
		timeout = 20,
		run = function(S)
			S.check(#G.jokers.cards == 2, "Expiry keeps earned Jokers")
			S.check(G.jokers.cards[1].edition.negative, "Expiry keeps earned editions")
			controlled(0, 0.99, 0)
			local helper, called = PVP.CHAOS.HigherCalling.joker, false
			PVP.CHAOS.HigherCalling.joker = function()
				called = true
				return helper()
			end
			local native = create_card("Joker", G.jokers, nil, nil, nil, nil, nil, "jud")
			PVP.CHAOS.HigherCalling.joker = helper
			S.check(not called and native.config.center ~= nil, "Expired Judgement uses native creation")
			native:remove()
			pseudorandom = native_random
			G.FUNCS.go_to_menu()
		end,
	},
}
