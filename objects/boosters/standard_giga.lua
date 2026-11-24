SMODS.Atlas({
	key = "standard_giga",
	path = "standard_giga.png",
	px = 71,
	py = 95,
})

SMODS.Booster({
	key = "standard_giga",
	kind = "Standard",
	group_key = "k_standard_pack",
	atlas = "standard_giga",
	pos = { x = 0, y = 0 },
	config = { extra = 10, choose = 4 },
	cost = 16,
	weight = 0,
	unskippable = true,
	create_card = function(self, card, i)
		local s_append = ""
		local b_append = PVP.RULES.ante_based() .. s_append

		local _edition = poll_edition("standard_edition" .. b_append, 2, true)
		local _seal = SMODS.poll_seal({ mod = 10, key = "stdseal" .. b_append })

		return {
			set = (pseudorandom(pseudoseed("stdset" .. b_append)) > 0.6) and "Enhanced" or "Base",
			edition = _edition,
			seal = _seal,
			area = G.pack_cards,
			skip_materialize = true,
			soulable = true,
			key_append = "sta" .. s_append,
		}
	end,
})

-- unskippable pack hook here, why not
local can_skip_ref = G.FUNCS.can_skip_booster
G.FUNCS.can_skip_booster = function(e)
	if SMODS.OPENED_BOOSTER and SMODS.OPENED_BOOSTER.config.center.unskippable then
		e.config.colour = G.C.UI.BACKGROUND_INACTIVE
		e.config.button = nil
	else
		return can_skip_ref(e)
	end
end
