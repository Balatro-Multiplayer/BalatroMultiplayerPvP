-- Game speed enforcement. The only speeds the game's own settings offer are
-- 0.5, 1, 2 and 4. Anything else (a hand-edited settings file, or a missing/nil value that
-- left the replayer running absurdly fast) is reset to 4, in G.SETTINGS and on disk.
PVP.VALID_GAMESPEEDS = { [0.5] = true, [1] = true, [2] = true, [4] = true }
PVP.DEFAULT_GAMESPEED = 4

function PVP.gamespeed_is_valid(speed)
	return type(speed) == "number" and PVP.VALID_GAMESPEEDS[speed] == true
end

-- Returns true when it had to correct the value.
function PVP.enforce_gamespeed()
	if not G or not G.SETTINGS then
		return false
	end
	-- Replays boost GAMESPEED themselves (2x/4x clock, fast-forward). Leave a sane
	-- boosted number alone; a nil/garbage one is still repaired below.
	if MPAPI and MPAPI.playback and MPAPI.playback._active_drivers and next(MPAPI.playback._active_drivers) then
		if type(G.SETTINGS.GAMESPEED) == "number" and G.SETTINGS.GAMESPEED > 0 then
			return false
		end
	end
	if PVP.gamespeed_is_valid(G.SETTINGS.GAMESPEED) then
		return false
	end
	sendWarnMessage(
		"Invalid game speed " .. tostring(G.SETTINGS.GAMESPEED) .. ", resetting to " .. PVP.DEFAULT_GAMESPEED,
		"MULTIPLAYER"
	)
	G.SETTINGS.GAMESPEED = PVP.DEFAULT_GAMESPEED
	if G.save_settings then
		pcall(G.save_settings, G)
	end
	return true
end
