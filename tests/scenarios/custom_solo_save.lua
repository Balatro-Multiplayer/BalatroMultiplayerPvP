-- Save/reload a real hand. Setup, bans, resources and shop size must not rerun.
local saved, hands, shop_size, banned_count
local function count(keys)
	local total = 0
	for _ in pairs(keys) do
		total = total + 1
	end
	return total
end

return {
	{
		run = function(S)
			local ok, err = PVP.SOLO.start({
				ruleset = "ruleset_mp_vanilla",
				deck = "b_red",
				stake = 1,
				seed = "SOLOSAVE",
				modifiers = { "second_wind", "fresh_start", "bigger_shop", "smallworld", "dice_patch" },
			})
			S.check(ok, "solo fixture starts: " .. tostring(err))
		end,
	},
	{
		until_ = function()
			return G.STATE == G.STATES.BLIND_SELECT and G.blind_select_opts and G.blind_select_opts.small
		end,
		timeout = 20,
		run = function(S)
			S.check(G.GAME.round_resets.hands == 5, "Second Wind adds one hand")
			S.check(
				G.GAME.round_resets.discards == G.GAME.starting_params.discards + 1,
				"Fresh Start adds one discard on top of Red Deck"
			)
			hands = G.GAME.round_resets.hands
			shop_size = G.GAME.shop.joker_max
			banned_count = count(G.GAME.banned_keys)
			G.FUNCS.select_blind(G.blind_select_opts.small:get_UIE_by_ID("select_blind_button"))
		end,
	},
	{
		until_ = function()
			return G.STATE == G.STATES.SELECTING_HAND and G.hand and #G.hand.cards > 0
		end,
		timeout = 20,
		run = function(S)
			save_run()
			S.check(G.ARGS.save_run and G.ARGS.save_run.GAME.pvp_solo, "real save_run includes solo config")
			saved = STR_UNPACK(STR_PACK(G.ARGS.save_run))
			G.FUNCS.go_to_menu()
		end,
	},
	{
		until_ = function()
			return G.STATE == G.STATES.MENU
		end,
		timeout = 20,
		run = function(S)
			S.check(not PVP.in_session(), "session ended before restore")
			G:start_run({ savetext = saved })
		end,
	},
	{
		until_ = function()
			return G.STATE == G.STATES.SELECTING_HAND and G.hand and #G.hand.cards > 0
		end,
		timeout = 20,
		run = function(S)
			S.check(PVP.is_singleplayer() and not PVP.is_practice_mode(), "solo context restored before run creation")
			S.check(G.GAME.round_resets.hands == hands, "resource deltas not applied twice")
			S.check(G.GAME.shop.joker_max == shop_size, "Bigger Shop not applied twice")
			S.check(count(G.GAME.banned_keys) == banned_count, "Small World does not cull again")
			S.check(MPAPI.has_modifier("second_wind") and MPAPI.has_modifier("smallworld"), "selected layers restored")
			local numerator, denominator = SMODS.get_probability_vars(G.playing_cards[1], 1, 15, "lucky_money")
			S.check(numerator == 1 and denominator == 10, "Dice Patch odds survive save/reload")
			G.FUNCS.go_to_menu()
		end,
	},
}
