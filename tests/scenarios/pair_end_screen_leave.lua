-- Finish a one-life match, then leave while the opponent still reads the results.
-- Run with scripts/run_pair.ps1 -Name pair_end_screen_leave (Windows) or run_pair.sh.
local P = assert(SMODS.load_file("tests/scenarios/lib/pair.lua", "MultiplayerPvP"))()

local restore_stats_requests = 0

local function overlay_button(name)
	local function find(node)
		if node.config and node.config.button == name then return node end
		for _, child in pairs(node.children or {}) do
			local found = find(child)
			if found then return found end
		end
	end
	local overlay = G.OVERLAY_MENU
	return type(overlay) == "table" and overlay.UIRoot and find(overlay.UIRoot) or nil
end

return P.steps(
	P.connect(),
	P.lobby(PVP.GamemodeKey.PVP_NEMESIS, function(config)
		config.starting_lives = 1
	end),
	P.sync("in_lobby"),
	P.start(),
	P.reach_blind_select(),
	P.sync("first_blind"),
	P.snapshot("before_pvp"),
	P.sync("before_pvp"),
	P.jump_to_pvp(2),
	P.play_pvp_blind(),
	P.next_round(function()
		return overlay_button("mp_pvp_leave_from_game") ~= nil
	end),
	{
		until_ = function()
			local lobby = MPAPI.get_current_lobby()
			return lobby and not lobby:is_game_started() and overlay_button("mp_pvp_leave_from_game") ~= nil
		end,
		timeout = 90,
		run = function(S)
			S.check(overlay_button("mp_pvp_return_to_lobby") ~= nil, P.role .. " has results exit buttons")
			P.screenshot("results")
			local request_stats = PVP.ACTIONS.request_nemesis_stats
			PVP.ACTIONS.request_nemesis_stats = function(...)
				restore_stats_requests = restore_stats_requests + 1
				return request_stats(...)
			end
		end,
	},
	P.sync("results_open"),
	{
		run = function()
			G.FUNCS.options()
		end,
	},
	{
		run = function()
			G.FUNCS.exit_overlay_menu()
		end,
	},
	{
		run = function(S)
			S.check(overlay_button("mp_pvp_leave_from_game") ~= nil, P.role .. " closing Options restores results")
			S.check(restore_stats_requests == 0, P.role .. " restoring results does not request stats again")
		end,
	},
	P.sync("before_leave"),
	P.only("host", {
		run = function()
			assert(overlay_button("mp_pvp_leave_from_game")):click()
		end,
	}),
	P.only("host", {
		until_ = function()
			return MPAPI.get_current_lobby() == nil
		end,
		timeout = 20,
		run = function(S)
			S.check(true, "host left the lobby")
		end,
	}),
	P.only("guest", {
		until_ = function()
			local lobby = MPAPI.get_current_lobby()
			return lobby and #lobby:get_players() == 1 and overlay_button("exit_overlay_menu") ~= nil
		end,
		timeout = 20,
		run = function(S)
			S.check(overlay_button("mp_pvp_leave_from_game") == nil, "departure notice replaced the results")
			P.screenshot("departure_notice")
		end,
	}),
	P.only("guest", {
		wait = 1,
		run = function()
			G.FUNCS.exit_overlay_menu()
		end,
	}),
	P.only("guest", {
		wait = 1,
		run = function(S)
			S.check(overlay_button("mp_pvp_leave_from_game") ~= nil, "dismissing departure notice restores Leave Lobby")
			S.check(
				overlay_button("mp_pvp_return_to_lobby") ~= nil,
				"dismissing departure notice restores Return to Lobby"
			)
			S.check(restore_stats_requests == 0, "departure restoration does not request stats again")
			P.note(
				"after dismissal: stage="
					.. tostring(G.STAGE)
					.. " state="
					.. tostring(G.STATE)
					.. " lobby="
					.. tostring(MPAPI.get_current_lobby() ~= nil)
			)
			P.screenshot("after_dismissal")
		end,
	}),
	P.only("guest", {
		wait = 1,
		run = function()
			assert(overlay_button("mp_pvp_return_to_lobby")):click()
		end,
	}),
	P.only("guest", {
		until_ = function()
			local lobby = MPAPI.get_current_lobby()
			return G.STAGE == G.STAGES.MAIN_MENU and lobby and #lobby:get_players() == 1
		end,
		timeout = 20,
		run = function(S)
			S.check(MPAPI._restorable_overlay == nil, "Return to Lobby clears results restoration")
			G.FUNCS.options()
		end,
	}),
	P.only("guest", {
		run = function()
			G.FUNCS.exit_overlay_menu()
		end,
	}),
	P.only("guest", {
		run = function(S)
			S.check(overlay_button("mp_pvp_leave_from_game") == nil, "closing menu Options does not resurrect results")
			G.FUNCS.mp_pvp_leave_lobby()
		end,
	}),
	P.only("guest", {
		until_ = function()
			return MPAPI.get_current_lobby() == nil
		end,
		timeout = 20,
		run = function(S)
			S.check(MPAPI._restorable_overlay == nil, "guest left without retaining old results")
		end,
	}),
	P.sync("finished")
)
