-- Live picker + save/reload smoke. Ante advancement is a fixture, not a claim
-- that this scenario played a complete ante or a network match.
local saved, offered, picked, count
return {
	{
		run = function(S)
			local back = MPAPI.back_for_key("b_mp_chaos")
			S.check(back ~= nil, "Almanac carrier is registered")
			PVP._start_practice("ruleset_mp_vanilla", {
				back = back.name,
				stake = 1,
				seed = "DRAFT123",
			})
		end,
	},
	{
		until_ = function()
			return G.STATE == G.STATES.BLIND_SELECT and G.blind_select_opts and G.blind_select_opts.small
		end,
		timeout = 20,
		run = function(S)
			local state = G.GAME.chaos_draft
			S.check(state and #state.acquired == 0 and not state.pending, "ante 1 is deckless")
			S.check(G.GAME.round_resets.hands == 4 and G.GAME.round_resets.discards == 3, "base resources")
			S.check(#G.playing_cards == 52, "ordinary 52-card start")
			G.GAME.round_resets.ante = 2
		end,
	},
	{
		until_ = function()
			return G.OVERLAY_MENU and G.GAME.chaos_draft.pending
		end,
		timeout = 20,
		run = function(S)
			offered = table.concat(G.GAME.chaos_draft.pending.choices, ",")
			S.check(#G.GAME.chaos_draft.pending.choices == 3, "three ante-2 offers")
			save_run()
			saved = STR_UNPACK(STR_PACK(G.ARGS.save_run))
			S.check(saved.GAME.chaos_draft.pending ~= nil, "pending offer serialized")
			G.FUNCS.exit_overlay_menu()
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
			return G.OVERLAY_MENU and G.GAME.chaos_draft.pending
		end,
		timeout = 20,
		run = function(S)
			local pending = G.GAME.chaos_draft.pending
			S.check(table.concat(pending.choices, ",") == offered, "reload preserves offers")
			-- Prefer a non-pack offer for this smoke; Orange has a separate lifecycle.
			for _, key in ipairs(pending.choices) do
				if key ~= "b_mp_orange" then
					picked = key
					break
				end
			end
			local cell = G.OVERLAY_MENU:get_UIE_by_ID("almanac_offer_" .. picked)
			S.check(cell ~= nil, "real offered deck cell rendered")
			cell:click()
		end,
	},
	{
		run = function(S)
			local cell = G.OVERLAY_MENU:get_UIE_by_ID("almanac_offer_" .. picked)
			S.check(cell ~= nil, "selected deck remains clickable")
			S.check(G.OVERLAY_MENU:get_UIE_by_ID("almanac_confirm") == nil, "no separate confirm button")
			cell:click()
		end,
	},
	{
		until_ = function()
			return G.GAME.chaos_draft and not G.GAME.chaos_draft.busy and not G.GAME.chaos_draft.pending
		end,
		timeout = 30,
		run = function(S)
			local state = G.GAME.chaos_draft
			S.check(#state.acquired == 1 and state.acquired[1] == picked, "selection acquired exactly once")
			count = G.GAME.dollars
			save_run()
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
			S.check(
				#G.GAME.chaos_draft.acquired == 1 and not G.GAME.chaos_draft.pending,
				"completed acquisition not offered again"
			)
			S.check(G.GAME.dollars == count, "reload does not replay cash grants")
			G.GAME.round_resets.ante = 3
		end,
	},
	{
		until_ = function()
			return G.OVERLAY_MENU and G.GAME.chaos_draft.pending
		end,
		timeout = 20,
		run = function(S)
			for _, key in ipairs(G.GAME.chaos_draft.pending.choices) do
				S.check(key ~= picked, "next ante excludes acquired deck")
			end
			G.FUNCS.exit_overlay_menu()
			G.FUNCS.go_to_menu()
		end,
	},
}
