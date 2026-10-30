-- Pure rule for whether the deck, stake and challenge pickers hide PvP-only content.
-- No game state here: overrides/hide_content.lua feeds this module.

PVP.MpContentVisibility = {}

-- in_lobby: a real lobby is live. kind: the PVP.LobbyAccess of that lobby.
-- ruleset_has_mp_content: the active Ruleset's `multiplayer_content` flag.
-- show_anyway: the player's explicit opt-in to see everything.
function PVP.MpContentVisibility.should_hide(in_lobby, kind, ruleset_has_mp_content, show_anyway)
	if in_lobby and (kind == PVP.LobbyAccess.PRIVATE or ruleset_has_mp_content) then
		return false
	end
	return not show_anyway
end
