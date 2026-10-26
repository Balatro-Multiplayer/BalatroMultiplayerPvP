-- Real Balance wall and run setup, then controlled rolls through native card
-- methods. This tests probability thresholds, not observed random frequencies.
local space, eight_ball, lucky, saved
local function click(id)
	assert(G.OVERLAY_MENU:get_UIE_by_ID(id), "missing UI: " .. id):click()
end

local function with_roll(seed, value, run)
	local original = pseudorandom
	pseudorandom = function(key, ...)
		if key == seed then return value end
		return original(key, ...)
	end
	local ok, result = pcall(run)
	pseudorandom = original
	assert(ok, result)
	return result
end

local function probability(S, card, denominator, identifier, expected_numerator, expected_denominator)
	local numerator, actual_denominator = SMODS.get_probability_vars(card, 1, denominator, identifier)
	S.check(
		math.abs(numerator - expected_numerator) < 1e-9 and actual_denominator == expected_denominator,
		identifier .. " odds = " .. tostring(numerator) .. "/" .. tostring(actual_denominator)
	)
end

return {
	{
		run = function(S)
			local balance = PVP.mutators_in(PVP.MutatorCategory.BALANCE)
			S.check(
				#balance == 2 and balance[1].key == "wraith_rework" and balance[2].key == "dice_patch",
				"Balance contains Kind Wraith and Dice Patch"
			)
			S.check(PVP.MUTATORS.wraith_rework.category ~= PVP.MutatorCategory.CHAOS, "Kind Wraith moved out of Chaos")
			G.FUNCS.pvp_custom_solo()
		end,
	},
	{
		run = function(S)
			click("pvp_solo_dice_patch")
			S.check(PVP.CUSTOM.draft.selected.dice_patch, "Dice Patch selected through real wall button")
		end,
	},
	{
		run = function()
			local directory = os.getenv("BMP_SCENARIO_SCREENSHOT_DIR")
			if directory then
				love.graphics.captureScreenshot(function(image)
					NFS.write(directory .. "/dice-patch-wall.png", image:encode("png"):getString())
				end)
			end
		end,
	},
	{
		run = function()
			PVP.CUSTOM.draft.seed = "DICEPATC"
			click("pvp_solo_play")
		end,
	},
	{
		until_ = function()
			return G.STATE == G.STATES.BLIND_SELECT and G.blind_select_opts
		end,
		timeout = 20,
		run = function(S)
			S.check(MPAPI.has_modifier("dice_patch"), "selected patch survived launch")
			space = SMODS.add_card({ key = "j_space" })
			eight_ball = SMODS.add_card({ key = "j_8_ball" })
			lucky = G.playing_cards[1]
			lucky:set_ability(G.P_CENTERS.m_lucky)
			SMODS.change_base(lucky, nil, "8")
			S.check(
				space.config.center.key == "j_space" and eight_ball.config.center.key == "j_8_ball",
				"Jokers keep vanilla keys"
			)
			S.check(
				space.ability.extra == 3 and eight_ball.ability.extra == 3,
				"Space Joker and 8 Ball use denominator 3"
			)
			S.check(lucky.ability.p_dollars == 20 and lucky.ability.mult == 20, "Lucky rewards stay unchanged")
			probability(S, lucky, 15, "lucky_money", 1, 10)
			probability(S, lucky, 5, "lucky_mult", 1, 5)
			local vars = G.P_CENTERS.m_lucky:loc_vars({}, lucky).vars
			S.check(
				vars[3] == 5 and vars[4] == 20 and vars[5] == 10,
				"Lucky tooltip shows correct reward and both denominators"
			)
			local payout = with_roll("lucky_money", 0.09, function()
				return lucky:get_p_dollars()
			end)
			S.check(payout == 20, "Lucky 0.09 roll pays $20")
			payout = with_roll("lucky_money", 0.11, function()
				return lucky:get_p_dollars()
			end)
			S.check(payout == 0, "Lucky 0.11 roll does not pay")
			local effect = with_roll("space", 0.3, function()
				return space:calculate_joker({
					before = true,
					cardarea = G.jokers,
					full_hand = { lucky },
					scoring_name = "High Card",
				})
			end)
			S.check(effect and effect.level_up, "Space Joker succeeds on a 0.3 roll")
			effect = with_roll("8ball", 0.3, function()
				return eight_ball:calculate_joker({ individual = true, cardarea = G.play, other_card = lucky })
			end)
			S.check(effect and effect.extra and effect.extra.func, "8 Ball succeeds on a 0.3 roll")
			if effect and effect.extra and effect.extra.func then effect.extra.func() end
		end,
	},
	{
		until_ = function()
			return G.consumeables and #G.consumeables.cards == 1
		end,
		timeout = 10,
		run = function(S)
			S.check(G.consumeables.cards[1].ability.set == "Tarot", "8 Ball actually delivers a Tarot")
			local first = SMODS.add_card({ key = "j_oops" })
			S.check(first.config.center.key == "j_oops", "Oops keeps vanilla key")
			S.check(G.GAME.probabilities.normal == 1.75, "legacy probability readers also get X1.75")
			probability(S, lucky, 15, "lucky_money", 1.75, 10)
			probability(S, space, space.ability.extra, "space", 1.75, 3)
			local vars = first.config.center:loc_vars({}, first).vars
			S.check(vars[1] == 1.75, "Oops tooltip displays multiplier 1.75")
			local second = SMODS.add_card({ key = "j_oops" })
			S.check(G.GAME.probabilities.normal == 1.75 ^ 2, "legacy probability multipliers stack")
			probability(S, lucky, 15, "lucky_money", 1.75 ^ 2, 10)
			second:remove()
			probability(S, lucky, 15, "lucky_money", 1.75, 10)
			first:remove()
			S.check(G.GAME.probabilities.normal == 1, "legacy probability baseline restored after removal")
			probability(S, lucky, 15, "lucky_money", 1, 10)
			SMODS.add_card({ key = "j_oops" })
			save_run()
			S.check(
				G.ARGS.save_run and G.ARGS.save_run.GAME.pvp_solo,
				"save includes the active Dice Patch configuration"
			)
			saved = STR_UNPACK(STR_PACK(G.ARGS.save_run))
			G.FUNCS.go_to_menu()
		end,
	},
	{
		until_ = function()
			return G.STATE == G.STATES.MENU
		end,
		timeout = 20,
		run = function()
			G:start_run({ savetext = saved })
		end,
	},
	{
		until_ = function()
			return G.STATE == G.STATES.BLIND_SELECT and G.blind_select_opts
		end,
		timeout = 20,
		run = function(S)
			S.check(MPAPI.has_modifier("dice_patch"), "Dice Patch restored before run reconstruction")
			S.check(G.GAME.probabilities.normal == 1.75, "owned Oops multiplier survives save/reload exactly once")
			probability(S, G.playing_cards[1], 15, "lucky_money", 1.75, 10)
			G.FUNCS.go_to_menu()
		end,
	},
	{
		until_ = function()
			return G.STATE == G.STATES.MENU
		end,
		timeout = 20,
		run = function(S)
			G.GAME.viewed_back = Back(G.P_CENTERS.b_red)
			G.FUNCS.start_run(nil, { stake = 1, seed = "DICEOFF" })
			S.check(not PVP.in_session(), "unpatched fixture is an ordinary vanilla run")
		end,
	},
	{
		until_ = function()
			return G.STATE == G.STATES.BLIND_SELECT and G.blind_select_opts
		end,
		timeout = 20,
		run = function(S)
			S.check(
				G.P_CENTERS.j_space.config.extra == 4 and G.P_CENTERS.j_8_ball.config.extra == 4,
				"vanilla Joker odds restored"
			)
			S.check(G.P_CENTERS.m_lucky.config.pvp_money_odds == nil, "Lucky config restored")
			S.check(
				type(G.P_CENTERS.j_oops.add_to_deck) ~= "string"
					and type(G.P_CENTERS.j_oops.remove_from_deck) ~= "string"
					and type(G.P_CENTERS.j_oops.loc_vars) ~= "string",
				"missing vanilla hooks restored to nil, not a sentinel"
			)
			lucky = G.playing_cards[1]
			lucky:set_ability(G.P_CENTERS.m_lucky)
			probability(S, lucky, 15, "lucky_money", 1, 15)
			local oops = SMODS.add_card({ key = "j_oops" })
			probability(S, lucky, 15, "lucky_money", 2, 15)
			S.check(oops:generate_UIBox_ability_table() ~= nil, "vanilla Oops tooltip still renders")
			G.FUNCS.go_to_menu()
		end,
	},
}
