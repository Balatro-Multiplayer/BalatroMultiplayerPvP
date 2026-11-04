if SMODS.Mods["ExtraCredit"] and SMODS.Mods["ExtraCredit"].can_load then
	PVP.match_log("debug", "ExtraCredit compatibility detected")
	PVP.DECK.ban_card("j_ExtraCredit_permanentmarker")
end
