-- Steamodded draws the owning mod's name ("Multiplayer PvP") as a badge under any modded
-- blind in the HUD and shifts the whole HUD down to fit it, which pushes the bottom of the
-- HUD off-screen during the PvP blind. Older Steamodded builds didn't.
local hud_blind_badge_ref = G.FUNCS.HUD_blind_badge
if hud_blind_badge_ref then
	G.FUNCS.HUD_blind_badge = function(e)
		if PVP.is_pvp_boss() then return end
		return hud_blind_badge_ref(e)
	end
end
