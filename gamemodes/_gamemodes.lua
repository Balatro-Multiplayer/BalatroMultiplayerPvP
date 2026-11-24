-- Thin delegating wrapper around MPAPI.GameMode. PvP's internal Gamemode objects
-- (survival/showdown/attrition) are content/blind-selection profiles, not run-
-- starters -- run-starting for the public matchmaking surface is owned by the
-- separate bridge GameModes in pvp_api/gamemodes.lua (keys like "pvp_nemesis").
-- MPAPI.GameMode requires `start_run`; none of these three ever call it, so
-- default it to a no-op rather than forcing every gamemode file to define one it
-- doesn't need.
--
-- Key prefixing: PvP gamemode files pass short keys (key = "attrition") and have
-- always relied on a "gamemode_mp_" prefix (class "gamemode" + this mod's "mp")
-- for the full key used everywhere else in the codebase -- same reasoning as
-- rulesets/_rulesets.lua's PVP.RULES.Ruleset.

PVP.RULES.gamemodes = MPAPI.GameModes

local function noop_start_run() end

function PVP.RULES.Gamemode(init)
	init.key = "gamemode_mp_" .. init.key
	init.prefix_config = init.prefix_config or { key = false }
	init.start_run = init.start_run or noop_start_run
	return MPAPI.GameMode(init)
end
