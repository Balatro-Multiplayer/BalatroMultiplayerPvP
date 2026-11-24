SMODS.Atlas({
	key = "gambling_sandbox",
	path = "tag_gambling_sandbox.png",
	px = 32,
	py = 32,
})

-- Gambling Tag: 1 in 2 chance to generate a rare joker in shop
SMODS.Tag({
	key = "gambling_sandbox",
	atlas = "gambling_sandbox",
	object_type = "Tag",
	dependencies = {
		items = {},
	},
	name = "Gambling Tag",
	discovered = true,
	min_ante = 2, -- less degeneracy
	no_collection = PVP.SANDBOX.no_collection,
	config = {
		type = "store_joker_create",
		odds = 2,
	},
	requires = "j_blueprint",
	loc_vars = function(self)
		return { vars = { G.GAME.probabilities.normal or 1, self.config.odds } }
	end,
	apply = function(self, tag, context)
		if context.type == "store_joker_create" then
			local card = nil
			-- 1 in 2 chance to proc
			if pseudorandom("tagroll") < G.GAME.probabilities.normal / tag.config.odds then
				-- count owned rare jokers to prevent duplicates
				local rares_owned = { 0 }
				for k, v in ipairs(G.jokers.cards) do
					if v.config.center.rarity == 3 and not rares_owned[v.config.center.key] then
						rares_owned[1] = rares_owned[1] + 1
						rares_owned[v.config.center.key] = true
					end
				end

				-- only proc if unowned rares exist
				-- funny edge case that i've never seen happen, but if localthunk saw it i will obey
				if #G.P_JOKER_RARITY_POOLS[3] > rares_owned[1] then
					card = create_card("Joker", context.area, nil, 1, nil, nil, nil, "rta")
					create_shop_card_ui(card, "Joker", context.area)
					card.states.visible = false
					tag:yep("+", G.C.RED, function()
						card:start_materialize()
						card.ability.couponed = true -- free card
						card:set_cost()
						return true
					end)
				else
					tag:nope() -- all rares owned
				end
			else
				tag:nope() -- failed roll
			end
			tag.triggered = true
			return card
		end
	end,
})
