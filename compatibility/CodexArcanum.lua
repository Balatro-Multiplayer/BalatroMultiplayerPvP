if SMODS.Mods["CodexArcanum"] and SMODS.Mods["CodexArcanum"].can_load then
	PVP.match_log("debug", "Codex Arcanum compatibility detected")
	PVP.DECK.ban_card("j_breaking_bozo")
	PVP.DECK.ban_card("c_alchemy_terra")
end
