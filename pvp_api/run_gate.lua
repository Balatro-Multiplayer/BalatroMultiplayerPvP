-- Whether the run in play is live: effects that the server's match state decides may only
-- apply then. Derived from the game each time it is asked, so nothing can leave it closed.
--
-- During a crash rejoin the catch-up runs as a local playback (an offline lobby, no server
-- behind it), and the live server lobby is attached to the rebuilt run afterwards
-- (lib/rejoin.lua `attach`). Applying lives or a result to the playback would be wiped by
-- that attach, and would run twice. A server lobby that is still detached (`_holding`, its
-- messages held) is not live either.

PVP.RunGate = PVP.RunGate or {}
local RG = PVP.RunGate

-- True when the current lobby is the live server lobby (`_nakama`, api/lobby/state.lua: every
-- lobby but an offline one) and the run is in play.
function RG.loaded()
	local lobby = MPAPI.get_current_lobby()
	if not lobby or lobby._nakama ~= true or lobby._holding then return false end
	return G.STAGE == G.STAGES.RUN and G.GAME ~= nil and G.GAME.round_resets ~= nil
end
