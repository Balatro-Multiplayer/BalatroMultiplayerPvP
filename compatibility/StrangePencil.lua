if next(SMODS.find_mod("StrangePencil")) then
	PVP.match_log("debug", "Strange Pencil compatibility detected")
	PVP.DECK.ban_card("j_pencil_calendar") -- potential desync
	PVP.DECK.ban_card("j_pencil_stonehenge") -- unfair advantage, also potential desync
	PVP.DECK.ban_card("c_pencil_chisel") -- might break phantom
	PVP.DECK.ban_card("c_pencil_peek") -- same reason as Matador

	-- cannot insta-win in multiplayer
	PVP.DECK.ban_card("j_pencil_forbidden_one")
	PVP.DECK.ban_card("j_pencil_left_arm")
	PVP.DECK.ban_card("j_pencil_left_leg")
	PVP.DECK.ban_card("j_pencil_right_arm")
	PVP.DECK.ban_card("j_pencil_right_leg")
end
