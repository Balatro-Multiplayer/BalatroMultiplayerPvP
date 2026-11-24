SMODS.Joker({
	key = "couponsheet_sandbox",
	no_collection = PVP.SANDBOX.no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = false,
	eternal_compat = true,

	rarity = 3,
	cost = 7,
	atlas = "ec_jokers_sandbox",
	pos = { x = 8, y = 3 },

	config = {
		extra = {},

		mp_sticker_extra_credit = true,
	},

	loc_vars = function(self, info_queue, card)
		info_queue[#info_queue + 1] = { key = "tag_coupon", set = "Tag" }
		info_queue[#info_queue + 1] = { key = "tag_voucher", set = "Tag" }
		return { vars = {} }
	end,

	calculate = function(self, card, context)
		if
			context.end_of_round
			and not context.repetition
			and not context.individual
			and G.GAME.blind.boss
			and not context.blueprint
		then
			card_eval_status_text(
				context.blueprint_card or card,
				"extra",
				nil,
				nil,
				nil,
				{ message = "+1 Coupon Tag!", colour = G.C.FILTER }
			)
			G.E_MANAGER:add_event(Event({
				func = function()
					add_tag(Tag("tag_coupon"))
					play_sound("generic1", 0.9 + math.random() * 0.1, 0.8)
					play_sound("holo1", 1.2 + math.random() * 0.1, 0.4)
					return true
				end,
			}))
			delay(0.3)
			card_eval_status_text(
				context.blueprint_card or card,
				"extra",
				nil,
				nil,
				nil,
				{ message = "+1 Voucher Tag!", colour = G.C.FILTER }
			)
			G.E_MANAGER:add_event(Event({
				func = function()
					add_tag(Tag("tag_voucher"))
					play_sound("generic1", 0.9 + math.random() * 0.1, 0.8)
					play_sound("holo1", 1.2 + math.random() * 0.1, 0.4)
					return true
				end,
			}))
		end
	end,

	mp_credits = {
		code = { "CampfireCollective" },
		art = { "neatoqueen" },
	},
	mp_include = function(self)
		return PVP.SANDBOX.is_joker_allowed(self.key)
	end,
})
