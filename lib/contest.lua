-- Pure rules for the Forfeit or Contest modal. No game state, broadcasts or UI
-- here: ui/contest_modal.lua feeds this module and acts on the answer.

PVP.Contest = {}
local Contest = PVP.Contest

-- Only a matchmade (Ranked or Casual) match of exactly 2 players on a server
-- referee offers a Contest. Every other match keeps the plain forfeit.
function Contest.should_offer(kind, player_count, has_server_referee)
	if not has_server_referee or player_count ~= 2 then
		return false
	end
	return kind == PVP.LobbyAccess.RANKED or kind == PVP.LobbyAccess.CASUAL
end

local ERROR_KEYS = {
	already_contested = "k_pvp_contest_already",
	not_in_game = "k_pvp_contest_over",
	server_too_old = "k_pvp_contest_old_server",
}

-- The localization key of the short message for a refused Contest.
function Contest.error_key(err)
	local reason = err
	if type(err) == "table" then
		reason = err.message or err.kind
		if ERROR_KEYS[err.kind] then
			reason = err.kind
		end
	end
	return ERROR_KEYS[reason] or "k_pvp_contest_failed"
end
