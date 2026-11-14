-- The money spent in a shop visit, reported to the server on leaving the shop (lovely/game.toml,
-- PVP.OpponentNet.report_shop): spent_total - spent_before_shop. spent_total counts every spend of the
-- run, spent_before_shop is its value when the visit opened, and shop_marked says this visit's
-- mark is set. All three live in PVP.GAME, so the run save holds them and a crash rejoin carries them
-- (lib/rejoin.lua CARRIED).
--
-- They count in any PvP session, not only with a lobby code: a crash rejoin replays the run log as a
-- practice playback (PVP._start_playback), where the lobby has no code yet, and a purchase made before
-- the crash that the run save does not hold is replayed there. Only the report is live-only
-- (pvp_api/opponent_net.lua).

-- A spend is a negative change of the player's dollars (ease_dollars).
function PVP.count_spend(mod)
	if not PVP.is_mp_or_practice() then return end
	if to_big(mod) < to_big(0) then
		PVP.GAME.spent_total = to_big(PVP.GAME.spent_total) + (to_big(mod) * to_big(-1))
	end
end

-- The shop opens: the spend before it is not this visit's. A visit already marked (the run save
-- restored it, or the live run resumes in the shop the catch-up replayed) keeps its mark.
function PVP.open_shop_visit()
	if not PVP.is_mp_or_practice() or PVP.GAME.shop_marked then return end
	PVP.GAME.spent_before_shop = to_big(PVP.GAME.spent_total) + to_big(0)
	PVP.GAME.shop_marked = true
end

-- Leaving the shop: this visit's spend, and the mark is cleared for the next visit.
function PVP.close_shop_visit()
	local spent = to_number(to_big(PVP.GAME.spent_total) - to_big(PVP.GAME.spent_before_shop))
	PVP.GAME.shop_marked = false
	return spent
end
