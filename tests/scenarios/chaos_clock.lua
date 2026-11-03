-- Live lab UI, actual save reconstruction, played-hand membership and cash-out
-- expiry. Uses a deliberately trivial blind to avoid testing fixture luck.
local saved, baseline, scoring_count, scoring_name, original_context
local function click(id)
	assert(G.OVERLAY_MENU:get_UIE_by_ID(id), "Missing lab UI: " .. id):click()
end

return {
	{
		run = function(S)
			local ok, err = PVP.SOLO.start({
				ruleset = "ruleset_mp_vanilla",
				deck = "b_red",
				stake = 1,
				seed = "CLOCKLAB",
				modifiers = {},
			})
			S.check(ok, "Solo fixture starts: " .. tostring(err))
		end,
	},
	{
		until_ = function()
			return G.STATE == G.STATES.BLIND_SELECT and G.blind_select_opts and PVP.CHAOS.safe_point()
		end,
		timeout = 20,
		run = function(S)
			baseline = G.GAME.round_resets.hands
			G.FUNCS.options()
			click("pvp_chaos_lab_open")
			S.check(G.OVERLAY_MENU:get_UIE_by_ID("pvp_chaos_random") ~= nil, "Lab renders random control")
			click("pvp_chaos_random")
			S.check(G.GAME.pvp_chaos.last ~= nil, "Real random control activates")
			click("pvp_chaos_clear")
			S.check(#G.GAME.pvp_chaos.active == 0, "Real clear control expires active rules")
			S.check(G.GAME.round_resets.hands == baseline, "Lab cleanup restores hands")
			G.FUNCS.exit_overlay_menu()
			local runtime = PVP.CHAOS.for_run(true)
			assert(runtime:activate("second_wind"))
			assert(runtime:activate("everybody_counts"))
			save_run()
			S.check(G.ARGS.save_run.GAME.pvp_chaos ~= nil, "Real save contains instances and receipts")
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
			-- Restoring a save can leave the previous options table around before
			-- the live blind selector is rebuilt. select_blind is a no-op then.
			return G.STATE == G.STATES.BLIND_SELECT
				and G.blind_select
				and G.blind_select_opts
				and G.blind_select_opts.small
				and not G.CONTROLLER.locked
		end,
		timeout = 20,
		run = function(S)
			S.check(G.GAME.round_resets.hands == baseline + 1, "Restore does not reapply resource delta")
			S.check(#G.GAME.pvp_chaos.active == 2, "Both saved rules remain active")
			G.FUNCS.select_blind(G.blind_select_opts.small:get_UIE_by_ID("select_blind_button"))
		end,
	},
	{
		until_ = function()
			return G.STATE == G.STATES.SELECTING_HAND and G.hand and #G.hand.cards >= 3 and not G.CONTROLLER.locked
		end,
		timeout = 20,
		run = function()
			G.GAME.blind.chips = 1
			local ranks, suits = { "2", "5", "9" }, { "Spades", "Hearts", "Clubs" }
			G.hand:unhighlight_all()
			for i = 1, 3 do
				local card = G.hand.cards[i]
				card:set_ability(G.P_CENTERS.c_base)
				SMODS.change_base(card, suits[i], ranks[i])
				G.hand:add_to_highlighted(card)
			end
			original_context = SMODS.calculate_context
			SMODS.calculate_context = function(context, ...)
				if context.before and context.scoring_hand then
					scoring_count, scoring_name = #context.scoring_hand, context.scoring_name
				end
				return original_context(context, ...)
			end
			G.FUNCS.play_cards_from_highlighted()
		end,
	},
	{
		until_ = function()
			return G.STATE == G.STATES.ROUND_EVAL and G.round_eval
		end,
		timeout = 30,
		run = function(S)
			SMODS.calculate_context = original_context
			S.check(scoring_count == 3, "Three distinct played cards actually enter scoring")
			S.check(scoring_name == "High Card", "All-card scoring does not change hand recognition")
			S.check(#G.GAME.pvp_chaos.active == 2, "Blind rules survive round evaluation")
			G.FUNCS.cash_out({ config = {} })
		end,
	},
	{
		until_ = function()
			return G.STATE == G.STATES.SHOP and G.shop
		end,
		timeout = 20,
		run = function(S)
			S.check(#G.GAME.pvp_chaos.active == 0, "Cash-out expires blind rules")
			S.check(G.GAME.round_resets.hands == baseline, "Hands return to baseline")
			S.check(not PVP.CHAOS.has_rule("all_cards_score"), "Scoring interpretation expires")
			G.FUNCS.go_to_menu()
		end,
	},
}
