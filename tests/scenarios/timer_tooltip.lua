-- Real UI and hover lifecycle, with local state and no outgoing player actions.
-- Run with MPAPI's scripts/run_scenario.sh MultiplayerPvP:timer_tooltip and the
-- Dev scenario bootstrap installed. Keep the cursor away from the test HUD.
local hud, timer, saved, stable_popup
local retired = {}
local calls = { start = 0, pause = 0 }

local function copy(source)
	local result = {}
	for key, value in pairs(source) do
		result[key] = value
	end
	return result
end

local function registered(popup)
	for _, candidate in ipairs(G.I.POPUP) do
		if candidate == popup then return true end
	end
	return false
end

local function cleanup()
	if timer then
		timer.states.hover.is = false
		timer:stop_hover()
	end
	if hud then
		hud:remove()
		hud = nil
	end
	if saved then
		PVP.GAME = saved.game
		PVP.LOBBY = saved.lobby
		PVP.ACTIONS.start_ante_timer = saved.start
		PVP.ACTIONS.pause_ante_timer = saved.pause
		saved = nil
	end
end

-- The runner stops on exceptions; restore our state before letting it report one.
local function step(run, wait)
	return {
		wait = wait or 0.1,
		run = function(S)
			local ok, err = xpcall(function()
				run(S)
			end, debug.traceback)
			if not ok then
				cleanup()
				error(err)
			end
		end,
	}
end

local function popup_text(node, parts)
	parts = parts or {}
	if node.config and type(node.config.text) == "string" then parts[#parts + 1] = node.config.text end
	local object = node.config and node.config.object
	if object and object.strings then
		for _, text in ipairs(object.strings) do
			parts[#parts + 1] = text.string
		end
	end
	for _, child in ipairs(node.children or {}) do
		popup_text(child, parts)
	end
	return table.concat(parts)
end

local function check_popup(S, state, keys)
	S.check(timer.config.mp_timer_tooltip_state == state, state .. ": selected state")
	local popup = timer.children.h_popup
	assert(S.check(popup ~= nil, state .. ": real hover popup exists"), "missing popup")
	S.check(registered(popup), state .. ": popup registered with engine")
	local expected = {}
	for _, key in ipairs(keys) do
		local text = localize(key)
		S.check(text ~= key and text ~= "ERROR", state .. ": localized " .. key)
		expected[#expected + 1] = text
	end
	S.check(popup_text(popup.UIRoot) == table.concat(expected), state .. ": rendered popup text")
	local count = 0
	for _, candidate in ipairs(G.I.POPUP) do
		if candidate.config.parent == timer then count = count + 1 end
	end
	S.check(count == 1, state .. ": exactly one owned popup")
	for _, old in ipairs(retired) do
		S.check(not registered(old), state .. ": previous popup removed")
	end
	return popup
end

local function remember_popup()
	if timer.children.h_popup then retired[#retired + 1] = timer.children.h_popup end
end

local function click(S, action)
	timer:click()
	S.check(calls[action] == 1, action .. ": real button dispatched expected action")
end

local idle = { "k_timer_tip_idle_1", "k_timer_tip_idle_2" }
local can_start = { "k_timer_tip_can_start_1", "k_timer_tip_can_start_2" }
local can_pause = { "k_timer_tip_can_pause_1", "k_timer_tip_can_pause_2" }

return {
	step(function(S)
		assert(S.check(PVP and PVP.UI.timer_tooltip_state ~= nil, "tooltip implementation loaded"))
		assert(not PVP.LOBBY.code, "run this scenario from the main menu, outside a lobby")
		assert(not PVP.is_pvp_boss(), "main menu has no active PvP boss")
		saved = {
			game = PVP.GAME,
			lobby = PVP.LOBBY,
			start = PVP.ACTIONS.start_ante_timer,
			pause = PVP.ACTIONS.pause_ante_timer,
		}
		PVP.GAME = copy(saved.game)
		PVP.LOBBY = copy(saved.lobby)
		PVP.LOBBY.config = copy(saved.lobby.config)
		PVP.LOBBY.config.timer = true
		PVP.GAME.timer = 60
		PVP.GAME.timer_started = false
		PVP.GAME.nemesis_timer_started = false
		PVP.GAME.pvp_countdown_in_progress = false
		PVP.GAME.ready_blind = false
		PVP.ACTIONS.start_ante_timer = function()
			calls.start = calls.start + 1
			PVP.GAME.timer_started = true
		end
		PVP.ACTIONS.pause_ante_timer = function()
			calls.pause = calls.pause + 1
			PVP.GAME.timer_started = false
		end
		hud = UIBox({
			definition = {
				n = G.UIT.ROOT,
				config = { align = "cm", colour = G.C.CLEAR },
				nodes = { PVP.UI.timer_hud() },
			},
			config = { align = "cm", offset = { x = -4, y = 0 }, major = G.ROOM_ATTACH },
		})
		timer = assert(hud:get_UIE_by_ID("row_round_text"), "real timer button missing")
	end),
	step(function(S)
		S.check(timer.config.on_demand_tooltip ~= nil, "normal UI update populated tooltip")
		S.check(timer.states.hover.can, "timer accepts hover")
		timer.states.hover.is = true
		timer:hover()
		stable_popup = check_popup(S, "idle", idle)
	end),
	step(function(S)
		S.check(timer.children.h_popup == stable_popup, "idle popup survives unchanged frames")
		check_popup(S, "idle", idle)
		remember_popup()
		PVP.GAME.ready_blind = true
	end, 0.5),
	step(function(S)
		check_popup(S, "can_start", can_start)
		remember_popup()
		click(S, "start")
	end),
	step(function(S)
		stable_popup = check_popup(S, "can_pause", can_pause)
	end),
	step(function(S)
		S.check(timer.children.h_popup == stable_popup, "running popup is not rebuilt every frame")
		remember_popup()
		click(S, "pause")
	end, 0.5),
	step(function(S)
		check_popup(S, "can_start", can_start)
		remember_popup()
		PVP.GAME.ready_blind = false
		PVP.GAME.timer_started = true
	end),
	step(function(S)
		check_popup(S, "running", { "k_timer_tip_running" })
		remember_popup()
		PVP.GAME.nemesis_timer_started = true
	end),
	step(function(S)
		check_popup(S, "nemesis_running", { "k_timer_tip_nemesis_running_1", "k_timer_tip_nemesis_running_2" })
		timer:click()
		S.check(calls.start == 1 and calls.pause == 1, "opponent-started timer cannot be toggled")
		remember_popup()
		PVP.GAME.timer = 0
	end),
	step(function(S)
		check_popup(S, "expired", { "k_timer_tip_expired" })
		timer:click()
		S.check(calls.start == 1 and calls.pause == 1, "expired timer cannot be toggled")
		remember_popup()
		timer.states.hover.is = false
		timer:stop_hover()
		S.check(timer.children.h_popup == nil, "leaving timer removes popup")
		S.check(timer.config.h_popup == nil, "leaving timer clears popup definition")
		PVP.GAME.timer = 60
		PVP.GAME.timer_started = false
		PVP.GAME.nemesis_timer_started = false
	end),
	step(function(S)
		S.check(timer.children.h_popup == nil, "unhovered state change does not open popup")
		timer.states.hover.is = true
		timer:hover()
		check_popup(S, "idle", idle)
		remember_popup()
		local original = saved
		cleanup()
		S.check(PVP.GAME == original.game and PVP.LOBBY == original.lobby, "original state restored")
		S.check(
			PVP.ACTIONS.start_ante_timer == original.start and PVP.ACTIONS.pause_ante_timer == original.pause,
			"original actions restored"
		)
		for _, popup in ipairs(retired) do
			S.check(not registered(popup), "cleanup leaves no scenario popup")
		end
	end),
}
