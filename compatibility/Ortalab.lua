if SMODS.Mods["ortalab"] and SMODS.Mods["ortalab"].can_load then
	PVP.match_log("debug", "Ortalab compatibility detected")
	PVP.DECK.ban_card("j_ortalab_miracle_cure")
	PVP.DECK.ban_card("j_ortalab_grave_digger")
	PVP.DECK.ban_card("v_ortalab_abacus")
	PVP.DECK.ban_card("v_ortalab_calculator")
end
