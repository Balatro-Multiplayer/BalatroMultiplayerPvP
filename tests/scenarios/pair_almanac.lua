-- Almanac end to end: private Nemesis lobby on the Almanac ruleset, server-run
-- stake Draft, the ante-2 deck draft (same three offers on both sides, different
-- picks) and PvP blind, then ante 3 through the real shop: deck draft excluding
-- both acquisitions, shared boss-rule pick, PvP blind under the two rules.
-- Ante 2 and skipping to each boss are fixtures; the rest is real.
-- Run with scripts/run_pair.sh pair_almanac.
local P = assert(SMODS.load_file("tests/scenarios/lib/pair.lua", "MultiplayerPvP"))()
local R = PVP.SHARED_RULES

local function pending()
	local state = G.GAME.almanac_draft
	return G.OVERLAY_MENU and state and state.pending and state.pending.choices
end

-- One deck draft. Host and guest pick different decks, skipping Orange (its
-- gift pack has a separate lifecycle). Every earlier pick of either side must
-- be off the board.
local function deck_draft(ante)
	local key = "picked_" .. ante .. "_" .. P.role
	return {
		{
			until_ = pending,
			timeout = 30,
			run = function(S)
				local choices = G.GAME.almanac_draft.pending.choices
				S.check(#choices == 3, P.role .. " got three ante-" .. ante .. " offers")
				for earlier = 2, ante - 1 do
					for _, who in ipairs({ "host", "guest" }) do
						local taken = P.get("picked_" .. earlier .. "_" .. who)
						for _, choice in ipairs(choices) do
							S.check(choice ~= taken, P.role .. " offer " .. choice .. " is not " .. who .. "'s " .. tostring(taken))
						end
					end
				end
				P.offers = table.concat(choices, ",")
			end,
		},
		P.snapshot("ante_" .. ante .. "_offers"),
		{
			run = function(S)
				local eligible = {}
				for _, choice in ipairs(G.GAME.almanac_draft.pending.choices) do
					if choice ~= "b_mp_orange" then eligible[#eligible + 1] = choice end
				end
				local picked = eligible[P.role == "host" and 1 or 2] or eligible[1]
				P.put(key, picked)
				local cell = G.OVERLAY_MENU:get_UIE_by_ID("almanac_offer_" .. picked)
				assert(S.check(cell ~= nil, P.role .. " offer cell rendered"), "no offer cell")
				cell:click()
			end,
		},
		{
			run = function()
				G.OVERLAY_MENU:get_UIE_by_ID("almanac_offer_" .. P.get(key)):click()
			end,
		},
		{
			until_ = function()
				local state = G.GAME.almanac_draft
				return not state.busy and not state.pending and state.acquired[#state.acquired] == P.get(key)
			end,
			timeout = 30,
			run = function(S)
				S.check(#G.GAME.almanac_draft.acquired == ante - 1, P.role .. " acquired " .. P.get(key))
			end,
		},
		P.sync("drafted_" .. ante),
	}
end

-- Each side locks the first rule of its own four-rule offer; the server settles
-- the two encounter rules once both are locked.
local rule_pick = {
	{
		until_ = function()
			return R.offer and R.offer.choices and G.OVERLAY_MENU
		end,
		timeout = 30,
		run = function(S)
			S.check(#R.offer.choices == 4, P.role .. " got four rule offers")
			local rule = R.offer.choices[1]
			P.put("rule_" .. P.role, rule)
			local button = G.OVERLAY_MENU:get_UIE_by_ID("pvp_shared_" .. rule)
			assert(S.check(button ~= nil, P.role .. " rule button rendered"), "no rule button")
			button:click()
		end,
	},
	{
		until_ = function()
			local state = G.GAME.pvp_shared_rules
			return state and state.ante == 3 and state.rules
		end,
		timeout = 30,
		run = function(S)
			local rules = G.GAME.pvp_shared_rules.rules
			S.check(#rules == 2 and rules[1] ~= rules[2], P.role .. " two distinct rules: " .. table.concat(rules, ","))
			for _, who in ipairs({ "host", "guest" }) do
				local pick = P.get("rule_" .. who)
				S.check(pick == rules[1] or pick == rules[2], P.role .. " rules include " .. who .. "'s pick " .. tostring(pick))
			end
			local sorted = { rules[1], rules[2] }
			table.sort(sorted)
			P.rules = table.concat(sorted, ",")
		end,
	},
}

return P.steps(
	P.connect(),
	P.lobby(PVP.GamemodeKey.PVP_NEMESIS, function(config)
		config.ruleset = PVP.RulesetKey.ALMANAC
	end),
	{
		run = function(S)
			local lobby = MPAPI.get_current_lobby()
			S.check(lobby.server_features and lobby.server_features.almanac_draft == 1, "server offers almanac_draft = 1")
			S.check(R.supported(lobby), "server offers shared_pvp_rules = 2")
		end,
	},
	P.sync("in_lobby"),
	P.start(),
	P.reach_blind_select(),
	{
		run = function(S)
			S.check(G.GAME.selected_back.effect.center.key == "b_mp_almanac", P.role .. " plays the Almanac deck")
			S.check(#G.GAME.almanac_draft.acquired == 0, P.role .. " ante 1 is deckless")
		end,
	},
	-- Ante 2: deck draft, PvP blind without rules.
	P.jump_to_pvp(2),
	deck_draft(2),
	P.play_pvp_blind(),
	{
		run = function(S)
			S.check(G.GAME.pvp_shared_rules == nil, P.role .. " ante 2 PvP had no shared rules")
		end,
	},
	P.sync("pvp_2_resolved", 180),
	P.snapshot("after_pvp_2"),
	-- Ante 3: through the real cash out and shop; the deck draft gates the shop.
	P.next_round(pending),
	deck_draft(3),
	P.next_round(),
	P.jump_to_pvp(3),
	P.play_pvp_blind(rule_pick),
	P.sync("pvp_3_resolved", 180),
	P.snapshot("after_pvp_3")
)
