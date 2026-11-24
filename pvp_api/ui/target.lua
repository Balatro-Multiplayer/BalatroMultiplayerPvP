-- Who I play, asked of the net's view each time (pvp_api/read/target.lua decides). The host and guest slots
-- of PVP.LOBBY name the opponent and the enemy-score label follows the safe half, so both are shown
-- again whenever the view changes the target or the label. It also owns the Boss slot's second look:
-- a Boss built before the view said whether I have a bye is decided here once the answer arrives.
local screen = {}
PVP.UI.target = screen

local function view()
	return PVP.NET and PVP.NET.view
end

-- The player my score and my cards point at, or nil: no target yet, a bye, or no view.
function PVP.READ.target.current_id()
	return PVP.READ.target.target_id(view(), PVP.LOBBY.config.team_based)
end

-- Every player a card of mine reaches.
function PVP.READ.target.card_ids()
	return PVP.READ.target.card_target_ids(view())
end

-- My Boss this ante: "plays", "bye", "no pvp this ante", or "unknown" while the view has not said, or says
-- it about another ante than the one the game is on. Only a Nemesis lobby waits on the view; every
-- other mode never has a bye, and practice and a playback have no partner to wait for.
function PVP.READ.target.my_boss()
	if not PVP.LOBBY.config.nemesis_pairing then return "plays" end
	if not MPAPI.get_current_lobby() then return "plays" end
	local resets = G.GAME and G.GAME.round_resets
	return PVP.READ.target.boss_of(view(), resets and resets.ante)
end

-- The localization key of the enemy-score label.
function PVP.READ.target.enemy_score_label_key()
	local config = PVP.LOBBY.config
	local royale = not (config.nemesis_pairing or config.manhunt or config.team_based)
	return PVP.READ.target.score_label_key(view(), royale)
end

-- Asks the gamemode for the Boss again each frame the view answers about this ante, until the player
-- has picked it (Upcoming or Select), so the slot follows the answer: a bye plays a normal boss, no bye
-- the PvP blind. Only a Boss the gamemode built (pvp_boss is set) is touched. The slot is
-- rebuilt when its key, its PvP flag or its pvp_boss state changed.
local function decide_boss()
	local resets = G.GAME and G.GAME.round_resets
	if not (resets and resets.pvp_boss ~= nil) or PVP.READ.target.my_boss() == "unknown" then return end
	local state = resets.blind_states and resets.blind_states.Boss
	if state ~= "Upcoming" and state ~= "Select" then return end
	local gamemode = PVP.RULES.gamemodes and PVP.RULES.gamemodes[PVP.RULES.active_gamemode()]
	if not gamemode then return end
	local key_before = resets.blind_choices.Boss
	local flag_before = resets.pvp_blind_choices.Boss
	local boss_state_before = resets.pvp_boss
	resets.pvp_blind_choices.Boss = nil
	local _, _, boss = gamemode:get_blinds_by_ante(resets.ante)
	resets.blind_choices.Boss = boss or resets.blind_choices.Boss
	local changed = resets.blind_choices.Boss ~= key_before
		or resets.pvp_blind_choices.Boss ~= flag_before
		or resets.pvp_boss ~= boss_state_before
	if changed and PVP.UI and PVP.UI.rebuild_boss_choice then PVP.UI.rebuild_boss_choice() end
end

function screen.update()
	if not (PVP.LOBBY and PVP.LOBBY.config) then return end
	local lobby = MPAPI.get_current_lobby()
	if not lobby then return end
	decide_boss()
	local shown = PVP.READ.view
	if shown.changed("target shown id", PVP.READ.target.current_id()) then
		PVP.LOBBY.mirror_players(lobby)
		PVP.UI.lobby.refresh_catching_up_badge()
	end
	if shown.changed("target shown label", PVP.READ.target.enemy_score_label_key()) then
		if PVP.GAME and PVP.GAME.enemy and PVP.UI and PVP.UI.refresh_enemy_score_label then
			PVP.UI.refresh_enemy_score_label()
		end
	end
end


return screen
