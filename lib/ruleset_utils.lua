function PVP.UTILS.get_weekly()
	return PVP.config.weekly
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

-- The clock rules the server froze for run `run_id`: the `clocks` of the "pvp.rules" state value, as
-- { ante = "bank"|"personal"|"none", pvp = { baseMs, handMs } or nil, personal = { kind, ... } or nil },
-- or nil while they are not known (no value, another run, a value that is not a clock table). A nil
-- `pvp` or `personal` is the server saying the ruleset has no such clock.
local ANTE_CLOCKS = { bank = true, personal = true, none = true }

function PVP.UTILS.clocks_of(rules_value, run_id)
	if not PVP.StateValue.same_run(rules_value, run_id) then return nil end
	local clocks = rules_value.clocks
	if type(clocks) ~= "table" or not ANTE_CLOCKS[clocks.ante] then return nil end
	local pvp, personal = clocks.pvp, clocks.personal
	-- A clock that is present must be well-formed, and the personal ante needs its personal clock: else unknown.
	if pvp ~= nil and (type(pvp) ~= "table" or type(pvp.baseMs) ~= "number" or type(pvp.handMs) ~= "number") then return nil end
	if personal ~= nil and (type(personal) ~= "table" or type(personal.kind) ~= "string") then return nil end
	if clocks.ante == "personal" and personal == nil then return nil end
	return { ante = clocks.ante, pvp = pvp, personal = personal }
end

-- The clock rules of the open run, read from the match state; nil while unknown.
function PVP.clocks_rules()
	return PVP.UTILS.clocks_of(MPAPI.get_state("pvp.rules"), PVP.current_run_id())
end

-- Whether the server's clock rules give the PvP blind a hand timer; false while they are unknown.
function PVP.has_pvp_clock()
	local clocks = PVP.clocks_rules()
	return clocks ~= nil and clocks.pvp ~= nil
end
