-- Real UI and hover lifecycle, with local state and no outgoing player actions.
-- Run with MPAPI's scripts/run_scenario.sh MultiplayerPvP:timer_tooltip and the
-- Dev scenario bootstrap installed. Keep the cursor away from the test HUD.
local hud, timer, saved, stable_popup
local retired = {}
local calls = { start = 0, pause = 0 }
-- What the stubbed timer screen answers: the seconds shown, whose clock runs, whether I started it, and
-- whether the button has an action.
local fake = { seconds = 60, clock = "none", timing = false, can_act = false }
local screen_names = { "seconds", "clock", "timing", "timed", "button", "press", "text" }

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
		for _, name in ipairs(screen_names) do
			PVP.UI.timer[name] = saved.screen[name]
		end
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
		assert(S.check(PVP and PVP.UI.timer and PVP.UI.timer.tip ~= nil, "tooltip implementation loaded"))
		assert(not PVP.LOBBY.code, "run this scenario from the main menu, outside a lobby")
		assert(not PVP.UTILS.is_pvp_blind(), "main menu has no active PvP boss")
		saved = {
			game = PVP.GAME,
			lobby = PVP.LOBBY,
			screen = {},
		}
		PVP.GAME = copy(saved.game)
		PVP.LOBBY = copy(saved.lobby)
		PVP.LOBBY.config = copy(saved.lobby.config)
		PVP.LOBBY.config.timer = true
		PVP.GAME.pvp_countdown_in_progress = false
		for _, name in ipairs(screen_names) do
			saved.screen[name] = PVP.UI.timer[name]
		end
		PVP.UI.timer.seconds = function() return fake.seconds end
		PVP.UI.timer.clock = function() return fake.clock end
		PVP.UI.timer.timing = function() return fake.timing end
		PVP.UI.timer.timed = function() return fake.timing or fake.clock == "against me" end
		PVP.UI.timer.button = function()
			if not fake.can_act then return nil end
			return fake.timing and "pause" or "start"
		end
		PVP.UI.timer.text = function() return "60.00" end
		PVP.UI.timer.press = function()
			local action = PVP.UI.timer.button()
			if action == "start" then
				calls.start = calls.start + 1
				fake.timing = true
			elseif action == "pause" then
				calls.pause = calls.pause + 1
				fake.timing = false
			end
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
		fake.can_act = true
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
		fake.can_act = false
		fake.timing = true
	end),
	step(function(S)
		check_popup(S, "running", { "k_timer_tip_running" })
		remember_popup()
		fake.clock = "against me"
	end),
	step(function(S)
		check_popup(S, "nemesis_running", { "k_timer_tip_nemesis_running_1", "k_timer_tip_nemesis_running_2" })
		timer:click()
		S.check(calls.start == 1 and calls.pause == 1, "opponent-started timer cannot be toggled")
		remember_popup()
		fake.seconds = 0
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
		fake.seconds = 60
		fake.timing = false
		fake.clock = "none"
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
		S.check(PVP.UI.timer.press ~= nil and PVP.UI.timer.tip ~= nil, "timer screen restored")
		for _, popup in ipairs(retired) do
			S.check(not registered(popup), "cleanup leaves no scenario popup")
		end
	end),
}
