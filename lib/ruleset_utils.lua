function PVP.UTILS.get_weekly()
	return PVP.config.weekly
end

-- Base timer in seconds, accounting for the active context's timer_base_multiplier
-- (set by layers like pressure_timer). The multiplier is applied at timer-init sites,
-- so the lobby UI keeps showing the unmultiplied base.
function PVP.UTILS.timer_base()
    local ruleset = PVP.current_ruleset()
	local base = PVP.LOBBY.config.timer_base_seconds or ruleset.timer_base_seconds or 150
	local mult = ruleset.timer_base_multiplier or 1
	return base * mult
end

-- Base PvP timer in seconds, accounting for the active ruleset's pvp_timer_base_multiplier
-- (set by layers like pvp_timer). The multiplier is applied at timer-init sites,
-- so the lobby UI keeps showing the unmultiplied base.
function PVP.UTILS.pvp_timer_base()
    if not PVP.is_layer_active("pvp_timer") then return PVP.UTILS.timer_base() end
    local ruleset = PVP.current_ruleset()
	local base = PVP.LOBBY.config.pvp_timer_base_seconds or ruleset.pvp_timer_base_seconds or 90
	local mult = ruleset.pvp_timer_base_multiplier or 1
	return base * mult
end

-- True when an active layer is driving the timer locally (not server-synced).
-- pvp_timer only counts during a PvP boss; outside PvP it's dormant.
function PVP.timer_is_local()
	return PVP.is_layer_active("pressure_timer")
		or PVP.is_layer_active("no_animation_timer")
		or (PVP.is_pvp_boss() and PVP.is_layer_active("pvp_timer"))
end

function PVP.UTILS.check_smods_version()
	if V(SMODS.version) < V(PVP.MIN_SMODS_VERSION) then
		return localize({ type = "variable", key = "k_ruleset_disabled_smods_version", vars = { PVP.MIN_SMODS_VERSION } })
	end
	return false
end

function PVP.UTILS.check_lovely_version()
	local lovely_ver = SMODS.Mods["Lovely"] and SMODS.Mods["Lovely"].version or ""
	-- V() cannot parse a version that does not start with a number (Lovely missing or unversioned).
	if not lovely_ver:match("^%d") or V(lovely_ver) < V(PVP.MIN_LOVELY_VERSION) then
		return localize({
			type = "variable",
			key = "k_ruleset_disabled_lovely_version",
			vars = { PVP.MIN_LOVELY_VERSION },
		})
	end
	return false
end
