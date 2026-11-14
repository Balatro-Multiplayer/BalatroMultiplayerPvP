-- Almanac end to end: private Nemesis lobby on the Almanac ruleset, server-run
-- stake Draft, the ante-2 deck draft (same three offers on both sides, different
-- picks), then a played PvP blind. Ante 2 is a fixture; the rest is real.
-- Run with scripts/run_pair.sh pair_almanac.
local P = assert(SMODS.load_file("tests/scenarios/lib/pair.lua", "MultiplayerPvP"))()

-- Host and guest pick different decks, skipping Orange (its gift pack has a
-- separate lifecycle).
local function pick_index()
	return P.role == "host" and 1 or 2
end

return P.steps(
	P.connect(),
	P.lobby(PVP.GamemodeKey.PVP_NEMESIS, function(config)
		config.ruleset = PVP.RulesetKey.ALMANAC
	end),
	{
		run = function(S)
			local lobby = MPAPI.get_current_lobby()
			S.check(lobby.server_features and lobby.server_features.almanac_draft == 1, "server offers almanac_draft = 1")
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
	P.jump_to_pvp(2),
	{
		until_ = function()
			local state = G.GAME.almanac_draft
			return G.OVERLAY_MENU and state.pending and state.pending.choices
		end,
		timeout = 30,
		run = function(S)
			local choices = G.GAME.almanac_draft.pending.choices
			S.check(#choices == 3, P.role .. " got three offers")
			P.offers = table.concat(choices, ",")
		end,
	},
	P.snapshot("ante_2_offers"),
	{
		run = function(S)
			local eligible = {}
			for _, key in ipairs(G.GAME.almanac_draft.pending.choices) do
				if key ~= "b_mp_orange" then eligible[#eligible + 1] = key end
			end
			local picked = eligible[pick_index()] or eligible[1]
			P.put("picked_" .. P.role, picked)
			local cell = G.OVERLAY_MENU:get_UIE_by_ID("almanac_offer_" .. picked)
			assert(S.check(cell ~= nil, P.role .. " offer cell rendered"), "no offer cell")
			cell:click()
		end,
	},
	{
		run = function()
			G.OVERLAY_MENU:get_UIE_by_ID("almanac_offer_" .. P.get("picked_" .. P.role)):click()
		end,
	},
	{
		until_ = function()
			local state = G.GAME.almanac_draft
			return not state.busy and not state.pending and #state.acquired == 1
		end,
		timeout = 30,
		run = function(S)
			local picked = P.get("picked_" .. P.role)
			S.check(G.GAME.almanac_draft.acquired[1] == picked, P.role .. " acquired " .. picked)
		end,
	},
	P.sync("drafted"),
	P.play_pvp_blind(),
	P.sync("pvp_blind_resolved", 180),
	P.snapshot("after_pvp_1")
)
