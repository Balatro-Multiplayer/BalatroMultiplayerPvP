-- Global values that must be present for the rest of this mod to work.

if not FN then FN = {} end

FN.PRE = {
	data = {
		score = { min = 0, exact = 0, max = 0 },
		dollars = { min = 0, exact = 0, max = 0 },
        empty = true,
	},
	text = {
		score = { l = "", r = "", m = "" },
		dollars = { top = "", bot = "" },
	},
	joker_order = {},
	hand_order = {},
	show_preview = false,
	lock_updates = false,
	on_startup = true,
	five_second_coroutine = nil,
    calculate_request = nil,
}


function FN.PRE.start_new_coroutine()
    -- Defaults are vanilla: free preview, slow (5s) delay.
    -- The delay comes from the ruleset scalars of a layer like pressure_timer; the cost is the server's.
    local timer_delay = 0
    if PVP.LOBBY and PVP.LOBBY.code and PVP.LOBBY.config.timer and not PVP.is_pvp_boss() then
        timer_delay = 5
        local ruleset = PVP.current_ruleset()
        timer_delay = PVP.LOBBY.config.preview_calculate_delay or ruleset.preview_calculate_delay or timer_delay
    end

    if not FN.PRE.calculate_request then
        FN.PRE.lock_updates = true
        FN.PRE.show_preview = true
        local func = function()
            FN.PRE.calculate_request = nil
            FN.PRE.lock_updates = false
            FN.PRE.show_preview = true
            FN.PRE.data = FN.PRE.simulate()

            -- The cost is the server's rule (clocks.personal.previewCostMs, only a personal-clock ruleset has
            -- one): the server takes it off the player's clock, which the box then shows.
            local clocks = PVP.clocks_rules()
            local cost_ms = clocks ~= nil and clocks.personal ~= nil and clocks.personal.previewCostMs or nil
            if
                type(cost_ms) == "number" and cost_ms > 0
                and FN.PRE.data and not FN.PRE.data.empty
                and PVP.LOBBY.code and not PVP.is_pvp_boss()
                and PVP.LOBBY.config.timer
                and not PVP.GAME.timer_started
                and not PVP.GAME.nemesis_timer_started
            then
                PVP.SkipsNet.spend(cost_ms)
            end
            return true
        end
        FN.PRE.calculate_request = Event({
            trigger = "after", delay = timer_delay, timer = "REAL",
            blockable = false, blocking = false,
            func = func
        })
        G.E_MANAGER:add_event(FN.PRE.calculate_request)
    end
end

-- Preview is a PvP feature: switched on, it still only runs inside a PvP
-- session, never in a vanilla run or another mod's game (an SPDRN race,
-- where racers without it would be at a disadvantage).
function FN.PRE.in_play()
    return PVP.INTEGRATIONS.Preview and PVP.in_session()
end

function FN.PRE.stop_current_coroutine(no_interrupt)
    if not FN.PRE.in_play() then return end
    if no_interrupt and FN.PRE.lock_updates then return end
    if FN.PRE.show_preview then
        FN.PRE.show_preview = false
        FN.PRE.data = FN.PRE.cleanup()
    end
    if FN.PRE.calculate_request then
        FN.PRE.calculate_request.func = function() return true end
        FN.PRE.calculate_request.complete = true
        FN.PRE.calculate_request = nil
        FN.PRE.lock_updates = false
    end
end

--[[
function FN.PRE.start_new_coroutine()
	if FN.PRE.five_second_coroutine and coroutine.status(FN.PRE.five_second_coroutine) ~= "dead" then
		FN.PRE.five_second_coroutine = nil -- Reset the coroutine
	end

	-- Create and start a new coroutine
	FN.PRE.five_second_coroutine = coroutine.create(function()
		-- Show UI updates
		FN.PRE.lock_updates = true
		FN.PRE.show_preview = true
		FN.PRE.add_update_event("immediate") -- Force UI refresh

		local start_time = os.time()
		if PVP.LOBBY.code and not PVP.is_pvp_boss() then
			while os.time() - start_time < 5 do
				FN.PRE.simulate() -- Force a simulation run
				FN.PRE.add_update_event("immediate") -- Ensure UI updates
				coroutine.yield() -- Allow game to continue running
			end
		end
		-- Delay for 5 seconds
		FN.PRE.lock_updates = false
		FN.PRE.show_preview = true
		FN.PRE.add_update_event("immediate") -- Refresh UI again
	end)

	coroutine.resume(FN.PRE.five_second_coroutine) -- Start it immediately
end
]]

FN.PRE._start_up = Game.start_up
function Game:start_up()
	FN.PRE._start_up(self)

	if not PVP.INTEGRATIONS.Preview then return end

	if not G.SETTINGS.FN then G.SETTINGS.FN = {} end
	if not G.SETTINGS.FN.PRE then
		G.SETTINGS.FN.PRE = true

		G.SETTINGS.FN.preview_score = true
		G.SETTINGS.FN.preview_dollars = true
		G.SETTINGS.FN.hide_face_down = true
		G.SETTINGS.FN.show_min_max = true
	end
end
