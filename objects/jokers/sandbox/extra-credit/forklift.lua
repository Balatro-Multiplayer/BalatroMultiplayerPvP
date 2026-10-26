-- Forklift - Extra Credit Joker ported to Sandbox
-- +2 Consumable Slots

SMODS.Joker({
	key = "forklift_sandbox",
	no_collection = PVP.sandbox_no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = false,
	eternal_compat = true,
	rarity = 1,
	cost = 5,
	atlas = "ec_jokers_sandbox",
	pos = { x = 0, y = 0 },
	config = { extra = { card_limit = 2 }, mp_sticker_extra_credit = true },

	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.card_limit } }
	end,

	add_to_deck = function(self, card, from_debuff)
		G.E_MANAGER:add_event(Event({
			func = function()
				G.consumeables.config.card_limit = G.consumeables.config.card_limit + card.ability.extra.card_limit
				return true
			end,
		}))
	end,

	remove_from_deck = function(self, card, from_debuff)
		G.E_MANAGER:add_event(Event({
			func = function()
				G.consumeables.config.card_limit = G.consumeables.config.card_limit - card.ability.extra.card_limit
				return true
			end,
		}))
	end,

	mp_credits = { code = { "CampfireCollective" }, art = { "DottyKitty" } },
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
