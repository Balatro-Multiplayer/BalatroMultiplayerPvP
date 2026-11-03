if SMODS.Mods["jen"] and SMODS.Mods["jen"].can_load then
	MPAPI.match_log("debug", "Jen's compatibility detected", "MULTIPLAYER")
	PVP.DECK.ban_card("j_jen_hydrangea")
	PVP.DECK.ban_card("j_jen_gamingchair")
	PVP.DECK.ban_card("j_jen_kosmos")
	PVP.DECK.ban_card("c_jen_entropy")
end
