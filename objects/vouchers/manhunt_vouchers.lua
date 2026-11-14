-- Manhunt-only replacements for the vanilla ante-skip vouchers (Hieroglyph/
-- Petroglyph, already banned repo-wide for every PvP mode -- see
-- gamemodes/attrition.lua's banned_vouchers). Same vanilla effect, plus: when the
-- RUNNER redeems one, every Hunter gains +1 life (compensation for the Runner
-- buying themselves more time to evade) -- see pvp_api/actions/team_manhunt.lua's
-- pvp_redeem_ante_voucher, which asks the server for the Hunters' lives.
SMODS.Voucher({
	key = "hieroglyph_manhunt",
	pos = { x = 5, y = 2 },
	cost = 10,
	unlocked = true,
	discovered = true,
	config = { extra = 1, mp_balanced = true },
	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra } }
	end,
	in_pool = function(self)
		return PVP.LOBBY.config.manhunt
	end,
	redeem = function(self, card)
		ease_ante(-card.ability.extra)
		G.GAME.round_resets.blind_ante = G.GAME.round_resets.blind_ante or G.GAME.round_resets.ante
		G.GAME.round_resets.blind_ante = G.GAME.round_resets.blind_ante - card.ability.extra
		G.GAME.round_resets.hands = G.GAME.round_resets.hands - card.ability.extra
		ease_hands_played(-card.ability.extra)

		if PVP.LOBBY.team_id == "RUNNER" then PVP.pvp_redeem_ante_voucher(self.key) end
	end,
})

SMODS.Voucher({
	key = "petroglyph_manhunt",
	pos = { x = 5, y = 3 },
	cost = 10,
	unlocked = true,
	discovered = true,
	config = { extra = 1, mp_balanced = true },
	requires = { "v_mp_hieroglyph_manhunt" },
	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra } }
	end,
	in_pool = function(self)
		return PVP.LOBBY.config.manhunt
	end,
	redeem = function(self, card)
		ease_ante(-card.ability.extra)
		G.GAME.round_resets.blind_ante = G.GAME.round_resets.blind_ante or G.GAME.round_resets.ante
		G.GAME.round_resets.blind_ante = G.GAME.round_resets.blind_ante - card.ability.extra
		G.GAME.round_resets.discards = G.GAME.round_resets.discards - card.ability.extra
		ease_discard(-card.ability.extra)

		if PVP.LOBBY.team_id == "RUNNER" then PVP.pvp_redeem_ante_voucher(self.key) end
	end,
})
