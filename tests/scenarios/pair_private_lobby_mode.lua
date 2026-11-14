-- A private Nemesis lobby opens on Expanded and both players see what it plays; a host
-- ruleset change reaches the guest's banner.
local P = assert(SMODS.load_file("tests/scenarios/lib/pair.lua", "MultiplayerPvP"))()

local function parts()
	local lobby = MPAPI.get_current_lobby()
	local queue_mode = lobby and (lobby:get_metadata() or {}).queue_mode
	return PVP.lobby_mode_parts(queue_mode, PVP.LOBBY.config.ruleset)
end

return P.steps(
	P.connect(),
	{
		-- Open the PvP menu as the player's click would, so the lobby page shows on join.
		run = function()
			MPAPI._internal.activate_mod(PVP.id)
		end,
		wait = 1,
	},
	P.lobby("pvp_nemesis"),
	{
		wait = 1.5,
		run = function(S)
			S.check(PVP.LOBBY.config.ruleset == PVP.RulesetKey.EXPANDED, P.role .. " lobby is on Expanded, got " .. tostring(PVP.LOBBY.config.ruleset))
			local p = parts()
			S.check(#p == 2 and p[1].name_key == "k_pvp_gamemode_nemesis", P.role .. " banner names Nemesis")
			P.screenshot("expanded")
		end,
	},
	{ wait = 0.5 },
	P.sync("shot1"),
	P.only("host", {
		run = function()
			G.FUNCS.mp_pvp_change_ruleset({ to_key = 1 })
		end,
	}),
	{
		until_ = function()
			return PVP.LOBBY.config.ruleset == PVP.RulesetKey.VANILLA
		end,
		timeout = 15,
		wait = 1.5,
		run = function(S)
			local p = parts()
			S.check(p[2] and p[2].ruleset_key == PVP.RulesetKey.VANILLA, P.role .. " banner follows the change to Vanilla")
			P.screenshot("vanilla")
		end,
	},
	{ wait = 0.5 },
	P.sync("done")
)
