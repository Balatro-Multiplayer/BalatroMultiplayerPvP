if SMODS.Mods["Pokermon"] and SMODS.Mods["Pokermon"].can_load then
	PVP.match_log("debug", "Pokermon compatibility detected")
	PVP.DECK.ban_card("j_poke_koffing")
	PVP.DECK.ban_card("j_poke_weezing")
	PVP.DECK.ban_card("j_poke_mimikyu")
end
