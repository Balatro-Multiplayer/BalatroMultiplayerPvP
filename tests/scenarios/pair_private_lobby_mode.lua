-- A private Nemesis lobby opens on Expanded and both players see what it plays; a host
-- ruleset change reaches the guest's banner.
local P = assert(SMODS.load_file("tests/scenarios/lib/pair.lua", "MultiplayerPvP"))()

-- The banner plate with this id, from whichever UIBox holds the lobby view.
local function plate(id)
	for _, box in ipairs(G.I.UIBOX or {}) do
		local element = box.get_UIE_by_ID and box:get_UIE_by_ID(id)
		if element then
			return element
		end
	end
end

-- Hovers a plate, screenshots its tooltip next frame, then lets go.
local function hover_shot(id, name)
	return {
		{
			run = function(S)
				local element = plate(id)
				S.check(element ~= nil and element.config.on_demand_tooltip ~= nil, P.role .. " " .. id .. " has a tooltip")
				if element then
					element:hover()
				end
			end,
			wait = 0.5,
		},
		{
			run = function()
				P.screenshot(name)
			end,
			wait = 0.5,
		},
		{
			run = function()
				local element = plate(id)
				if element then
					element:stop_hover()
				end
			end,
			wait = 0.3,
		},
	}
end

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
	hover_shot("pvp_lobby_mode_gamemode", "hover_gamemode"),
	hover_shot("pvp_lobby_mode_ruleset", "hover_ruleset"),
	P.sync("shot1"),
	P.only("host", {
		run = function()
			-- The Lobby Options header's ruleset arrow, two steps back: Expanded -> Vanilla.
			G.FUNCS.mp_pvp_opt_ruleset({ config = { ref_table = { dir = -2 } } })
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
