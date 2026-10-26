-- Real menu -> manual setup -> Black Deck blind -> normal loss -> clean exit.
-- No Steam/session registration or network server is required.
local function click(id)
	local element = assert(G.OVERLAY_MENU:get_UIE_by_ID(id), "missing UI: " .. id)
	element:click()
end

return {
	{
		run = function(S)
			S.check(PVP and PVP.SOLO ~= nil, "solo implementation loaded")
			S.check(not MPAPI.get_current_lobby(), "no lobby before setup")
			G.FUNCS.pvp_custom_solo()
		end,
	},
	{
		run = function(S)
			S.check(G.OVERLAY_MENU:get_UIE_by_ID("pvp_solo_glass_cannon") ~= nil, "real mutator wall rendered")
			click("pvp_solo_glass_cannon")
			click("pvp_solo_no_uncommons")
			click("pvp_solo_flipped_cards")
			S.check(not MPAPI.has_modifier("glass_cannon"), "draft does not mutate active modifiers")
			-- Deck and seed are fixture inputs; effects and Play use real UI elements.
			for i, key in ipairs(PVP.CUSTOM.decks) do
				if key == "b_black" then PVP.CUSTOM.draft.deck = i end
			end
			PVP.CUSTOM.draft.seed = "SOLOTEST"
			click("pvp_solo_play")
		end,
	},
	{
		until_ = function()
			return G.STATE == G.STATES.BLIND_SELECT and G.blind_select_opts and G.blind_select_opts.small
		end,
		timeout = 20,
		run = function(S)
			S.check(PVP.is_singleplayer() and not PVP.is_practice_mode(), "solo is not no-fail practice")
			S.check(not PVP.is_mp_or_practice(), "PvP blind/loss overrides are disabled")
			S.check(G.GAME.seeded, "custom run cannot earn unlocks")
			S.check(G.GAME.round_resets.hands == 1, "Black Deck and Glass Cannon leave one hand")
			S.check(G.GAME.modifiers.flipped_cards == 1, "Blind Poker uses a numeric denominator")
			S.check(G.GAME.pvp_solo ~= nil, "solo configuration is attached to saveable game state")
			S.check(MPAPI.get_current_lobby().code == nil, "solo has no network lobby code")
			local all_banned = true
			for key, center in pairs(G.P_CENTERS) do
				if center.set == "Joker" and center.rarity == 2 and not G.GAME.banned_keys[key] then
					all_banned = false
				end
			end
			S.check(all_banned, "all registered Uncommon Jokers are banned")
			G.FUNCS.select_blind(G.blind_select_opts.small:get_UIE_by_ID("select_blind_button"))
		end,
	},
	{
		until_ = function()
			return G.STATE == G.STATES.SELECTING_HAND and G.hand and #G.hand.cards > 0
		end,
		timeout = 20,
		run = function(S)
			S.check(G.GAME.current_round.hands_left == 1, "first blind receives the modified hand count")
			S.check(not PVP.is_pvp_boss(), "normal singleplayer blind")
			local face_down = true
			for _, card in ipairs(G.hand.cards) do
				if card.facing ~= "back" then face_down = false end
			end
			S.check(face_down, "Blind Poker actually draws face-down cards")
			-- Force an unreachable target, then play a real hand to exercise loss.
			G.GAME.blind.chips = 1e12
			G.hand:add_to_highlighted(G.hand.cards[1])
			G.FUNCS.play_cards_from_highlighted()
		end,
	},
	{
		until_ = function()
			return G.STATE == G.STATES.GAME_OVER
		end,
		timeout = 30,
		run = function(S)
			S.check(true, "solo can lose rather than continuing as practice")
			G.FUNCS.go_to_menu()
		end,
	},
	{
		until_ = function()
			return G.STATE == G.STATES.MENU
		end,
		timeout = 20,
		run = function(S)
			S.check(not MPAPI.get_current_lobby(), "solo local lobby is released")
			S.check(not PVP.in_session() and not PVP.is_singleplayer(), "solo session is cleared")
			S.check(#MPAPI.MODIFIERS == 0, "house rules do not leak into vanilla")
		end,
	},
}
