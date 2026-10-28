-- Other tags can be added between the skip and the trap's skip_blind context, so the tag the Nemesis got
-- from the skip is recorded here, from the tag shown on the blind being skipped, before vanilla runs.
local skip_blind_ref = G.FUNCS.skip_blind
function G.FUNCS.skip_blind(e)
	if PVP.in_session() then
		local blind_tags = G.GAME.round_resets.blind_tags
		G.GAME.mp_skipped_tag_key = blind_tags and blind_tags[G.GAME.blind_on_deck]
	end
	return skip_blind_ref(e)
end
