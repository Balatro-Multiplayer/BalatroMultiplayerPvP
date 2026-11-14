-- The private lobby's "what are we playing" banner, above the lobby controls: the
-- gamemode and the ruleset, each with its chip and colour from the Create Lobby
-- pillars (ui/main_menu/_mode_chips.lua). Every player sees it; it follows a
-- Lobby Options ruleset change because METADATA_CHANGED rebuilds the view
-- (pvp_api/lobby_bridge.lua).

-- gamemode key -> its name and its MODE_COLOUR / MODE_CHIP_ROW key. Small World
-- and Experimental are absent: their ruleset is the mode, so the banner names it once.
local GAMEMODES = {
	pvp_nemesis = { name_key = "k_pvp_gamemode_nemesis", style = "nemesis" },
	pvp_royale = { name_key = "k_pvp_gamemode_royale", style = "royale" },
	pvp_manhunt = { name_key = "k_pvp_gamemode_manhunt", style = "manhunt" },
	pvp_teams = { name_key = "k_pvp_gamemode_teams", style = "teams" },
}

-- ruleset key -> its MODE_COLOUR / MODE_CHIP_ROW key (nil: no art, a plain plate).
local RULESET_STYLES = {
	ruleset_mp_vanilla = "vanilla",
	ruleset_mp_balanced = "balanced",
	ruleset_mp_expanded = "expanded",
	ruleset_mp_majorleague = "mlba",
	ruleset_mp_smallworld = "smallworld",
}

-- What the banner shows, as plain data: one part per thing to name, in order.
-- A part is { caption_key, name_key | ruleset_key, style }. An unknown gamemode
-- (nil before the host's metadata arrives) is left out rather than guessed.
function PVP.lobby_mode_parts(queue_mode, ruleset_key)
	local parts = {}
	local gamemode = queue_mode and GAMEMODES[queue_mode]
	if gamemode then
		parts[#parts + 1] = { caption_key = "k_pvp_lobby_gamemode_caption", name_key = gamemode.name_key, style = gamemode.style }
	end
	if ruleset_key then
		parts[#parts + 1] = { caption_key = "k_pvp_lobby_ruleset_caption", ruleset_key = ruleset_key, style = RULESET_STYLES[ruleset_key] }
	end
	return parts
end

local function part_node(part)
	local colour = part.style and PVP.MODE_COLOUR[part.style] and HEX(PVP.MODE_COLOUR[part.style]) or G.C.UI.TEXT_INACTIVE
	local name = part.name_key and localize(part.name_key) or PVP.ruleset_display_name(part.ruleset_key) or part.ruleset_key
	local nodes = {}
	local chip_row = part.style and PVP.MODE_CHIP_ROW[part.style]
	if chip_row then
		nodes[#nodes + 1] = { n = G.UIT.C, config = { align = "cm" }, nodes = {
			{ n = G.UIT.O, config = { object = PVP.mode_chip_sprite(chip_row, 0.8) } },
		} }
	end
	nodes[#nodes + 1] = { n = G.UIT.C, config = { align = "cm", padding = 0.05 }, nodes = {
		{ n = G.UIT.R, config = { align = "cm" }, nodes = {
			{ n = G.UIT.T, config = { text = localize(part.caption_key), scale = 0.3, colour = G.C.UI.TEXT_LIGHT } },
		} },
		{ n = G.UIT.R, config = { align = "cm" }, nodes = {
			{ n = G.UIT.T, config = { text = name, scale = 0.5, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
		} },
	} }
	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.08, r = 0.1, minw = 3, colour = mix_colours(colour, G.C.BLACK, 0.3), outline = 1.2, outline_colour = colour },
		nodes = nodes,
	}
end

-- The banner row, or nil when there is nothing known to name yet. The gamemode is
-- read from the lobby's own metadata, so a key left over from an earlier lobby is
-- never shown; the host's own key covers the moment before its first write lands.
function PVP.lobby.build_mode_banner(lobby)
	local queue_mode = (lobby:get_metadata() or {}).queue_mode or (lobby.is_host and PVP._pvp_gamemode) or nil
	local parts = PVP.lobby_mode_parts(queue_mode, PVP.LOBBY.config.ruleset)
	if #parts == 0 then
		return nil
	end
	local nodes = {}
	for _, part in ipairs(parts) do
		nodes[#nodes + 1] = part_node(part)
	end
	return { n = G.UIT.R, config = { align = "cm", padding = 0.1 }, nodes = nodes }
end
