-- Credit to @MathIsFun_ and the Balatro Multiplayer project for the ruleset system this is based on.
-- Thin delegating wrapper around MPAPI.Ruleset: registers PvP rulesets into the
-- shared MPAPI.Rulesets registry (dupe-key checking, required_params validation,
-- `inject`'s G.P_CENTER_POOLS.Ruleset registration, and the default no-op
-- is_disabled/force_lobby_options methods all come from MPAPI's own RulesetBase
-- for free) while keeping PvP's own active-ruleset/gamemode
-- resolution (lobby / practice-mode -- MPAPI only knows about the lobby case,
-- so this stays PvP-owned).
--
-- Key prefixing: PvP ruleset files pass short keys (key = "vanilla") and have
-- always relied on a "ruleset_mp_" prefix (class "ruleset" + this mod's "mp") to
-- get the full key used everywhere else in the codebase. MPAPI.Ruleset's own
-- class sets no class_prefix (Speed's rulesets are already fully-qualified, e.g.
-- "spdrn_order", and don't want one), so PvP computes the "ruleset_" segment
-- itself and tells SMODS not to touch the key further.
--
-- PVP.RULES.rulesets stays as a direct alias: read elsewhere (networking/action_handlers.lua)
-- expecting a key -> ruleset lookup table, which MPAPI.Rulesets now IS.
PVP.RULES.rulesets = MPAPI.Rulesets

-- The full keys of the rulesets the menus name.
PVP.RULES.RulesetKey = {
	VANILLA = "ruleset_mp_vanilla",
	BALANCED = "ruleset_mp_balanced",
	EXPANDED = "ruleset_mp_expanded",
	SMALLWORLD = "ruleset_mp_smallworld",
	EXPERIMENTAL = "ruleset_mp_experimental",
	MAJORLEAGUE = "ruleset_mp_majorleague",
}

local RULESET_NAME_KEY = {
	[PVP.RULES.RulesetKey.VANILLA] = "k_vanilla",
	[PVP.RULES.RulesetKey.BALANCED] = "k_mp_ruleset_balanced",
	[PVP.RULES.RulesetKey.EXPANDED] = "k_mp_ruleset_expanded",
	[PVP.RULES.RulesetKey.SMALLWORLD] = "k_smallworld",
	[PVP.RULES.RulesetKey.EXPERIMENTAL] = "k_experimental",
	[PVP.RULES.RulesetKey.MAJORLEAGUE] = "k_majorleague",
}

-- The ruleset's name as the menus show it. Every menu that names a ruleset goes through here.
function PVP.RULES.display_name(ruleset_key)
	return localize(RULESET_NAME_KEY[ruleset_key])
end

-- The ruleset's long description (its name key + "_description"), or nil when it has none.
function PVP.RULES.description(ruleset_key)
	local name_key = RULESET_NAME_KEY[ruleset_key]
	local dictionary = G.localization and G.localization.misc and G.localization.misc.dictionary or {}
	return name_key and dictionary[name_key .. "_description"] or nil
end

function PVP.RULES.Ruleset(init)
	init.key = "ruleset_mp_" .. init.key
	init.prefix_config = init.prefix_config or { key = false }
	return MPAPI.Ruleset(init)
end

-- "Active" meaning both a live lobby and the configuration-in-progress phase.
-- PVP.LOBBY.config.ruleset always holds a value (LOBBY.reset_config's default
-- included), so outside a PvP session it says nothing: no ruleset is active,
-- and none of PvP's layers may run in a vanilla run or another mod's game.
function PVP.RULES.active_ruleset()
	if not PVP.LOBBY.in_session() then
		return nil
	end
	if PVP.LOBBY.config.ruleset then
		return PVP.LOBBY.config.ruleset
	elseif PVP.PRACTICE.is_on() then
		return PVP.PRACTICE.ruleset
	end
	return nil
end

function PVP.RULES.active_gamemode()
	if PVP.LOBBY.code then
		return PVP.LOBBY.config.gamemode
	elseif PVP.PRACTICE.is_on() then
		return PVP.RULES.current().forced_gamemode or PVP.PRACTICE.playback_gamemode
	end
	return nil
end

-- The gamemode a live match of this match format plays. A replay playback has no lobby code and a
-- ruleset such as Balanced forces no gamemode, so the playback needs it from the recorded format.
function PVP.REPLAY.gamemode_of(queue_key)
	return (PVP.RULES.MODES[queue_key] or PVP.RULES.MODES.pvp_nemesis).gamemode
end

-- ----------------------------------------------------------------------------
-- Active context: the resolved view of (ruleset + active modifiers)
-- ----------------------------------------------------------------------------
-- Field-kind merging delegates to MPAPI.resolve_ruleset_field (the single shared
-- implementation, also used by Speed) -- only the active-KEY resolution above
-- stays PvP-owned (lobby/practice), threaded through as an explicit
-- argument since MPAPI's own equivalent only knows about the lobby case.

local _resolver = setmetatable({}, {
	__index = function(_, field)
		return MPAPI.resolve_ruleset_field(PVP.RULES.active_ruleset(), field)
	end,
})

-- The answer to "what's in the active ruleset?".
-- Safe with no active ruleset: arrays read as {}, the rest as nil.
function PVP.RULES.current()
	return _resolver
end

PVP.RULES.ReworkCenter = MPAPI.ReworkCenter
PVP.RULES.load_reworks = MPAPI.LoadReworks
