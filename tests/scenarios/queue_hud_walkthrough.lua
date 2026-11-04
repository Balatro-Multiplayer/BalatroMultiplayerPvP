-- Walks the queue HUD and match-found reveal with no server, saving screenshots along the way.
-- Drives tests/scenarios/lib/qhud_sim.lua (faked ratings and counts). Shots go to $QHUD_SHOTS (default /tmp/qhud).
local REPO = SMODS.Mods.MultiplayerPvP.path
local OUT = os.getenv("QHUD_SHOTS") or "/tmp/qhud"
local Q = PVP.QUEUE_HUD
local SIM
local n = 0

local function shot(name)
	n = n + 1
	local file = string.format("%s/%02d_%s.png", OUT, n, name)
	love.graphics.captureScreenshot(function(img)
		local f = io.open(file, "wb")
		f:write(img:encode("png"):getString())
		f:close()
	end)
end

local function at(wait, name, fn)
	return { wait = wait, run = function(S)
		if fn then
			fn(S)
		end
		if name then
			shot(name)
		end
	end }
end

-- A burst of shots `every` seconds apart.
local function burst(steps, count, every, name)
	for i = 1, count do
		steps[#steps + 1] = at(every, name .. "_" .. i)
	end
end

local function reset()
	SIM.keys.x()
	SIM.quiet = true
end

local steps = {
	at(1.0, "00_menu", function(S)
		os.execute("mkdir -p '" .. OUT .. "'")
		dofile(REPO .. "tests/scenarios/lib/qhud_sim.lua")
		SIM = QHUD_SIM
		SIM.quiet = true
		S.check(Q ~= nil and SIM.start ~= nil, "sim loaded")
	end),
	at(0.1, nil, function() SIM.start("ranked") end),
}
burst(steps, 4, 0.1, "01_hud_in")
steps[#steps + 1] = at(1.0, "02_hud_settled", function(S) S.check(Q.active and Q.hud ~= nil, "HUD up") end)
-- the riffle: every 1.1s, 0.45s long
burst(steps, 12, 0.08, "03_riffle")
steps[#steps + 1] = at(0.3, nil, function() SIM.skip(30) end)
burst(steps, 3, 0.15, "04_step2")
steps[#steps + 1] = at(0.5, "05_step3", function() SIM.skip(30) end)
steps[#steps + 1] = at(1.0, "06_cap", function(S)
	SIM.skip(600)
	local B = PVP.QUEUE_BACKDROP
	S.check(G.SPLASH_BACK.draw_steps[1].shader == "splash" and B.mode == "splash", "menu keeps its swirl while searching")
	S.check(B.rate > 1.2, "swirl runs faster while searching: x" .. string.format("%.2f", B.rate))
end)
steps[#steps + 1] = at(1.0, "07_count_bump", function() SIM.keys.c() end)
steps[#steps + 1] = at(0.5, nil, function() SIM.match() end)
burst(steps, 14, 0.1, "08_match")
burst(steps, 4, 0.3, "09_match_late")
steps[#steps + 1] = at(0.3, "10_joined_me", function() SIM.join(1.0) end)
steps[#steps + 1] = at(1.5, "11_opponent", function(S) S.check(PVP.QUEUE_REVEAL.view ~= nil, "reveal up") end)
steps[#steps + 1] = at(1.5, "12_settled", function(S)
	S.check(G.SPLASH_BACK.draw_steps[1].shader == "background", "reveal plays over the backdrop")
	S.check(G.MAIN_MENU_UI and not G.MAIN_MENU_UI.states.visible, "main menu hidden")
	S.check(G.SPLASH_LOGO and not G.SPLASH_LOGO.states.visible, "logo hidden")
end)
steps[#steps + 1] = at(0.5, nil, function()
	SIM.lobby._destroyed = true
end)
burst(steps, 3, 0.2, "13_teardown")
steps[#steps + 1] = at(0.2, nil, function(S)
	S.check(G.SPLASH_BACK.draw_steps[1].shader == "splash", "menu swirl back after teardown")
	S.check(G.MAIN_MENU_UI.states.visible and G.SPLASH_LOGO.states.visible, "menu back after teardown")
end)

-- failures: each ends the reveal and gives the menu back
steps[#steps + 1] = at(0.5, nil, function() reset(); SIM.start("ranked") end)
steps[#steps + 1] = at(1.0, nil, function() SIM.match() end)
steps[#steps + 1] = at(1.0, nil, function() SIM.fail() end)
steps[#steps + 1] = at(0.3, "13a_join_failed", function(S)
	S.check(not PVP.QUEUE_REVEAL.view and not Q.active, "a failed lobby join ends the reveal")
	S.check(not PVP._is_searching() and PVP._match_handle == nil, "and the search")
	S.check(G.MAIN_MENU_UI.states.visible, "menu back after a failed join")
end)
steps[#steps + 1] = at(0.5, nil, function() reset(); SIM.start("ranked") end)
steps[#steps + 1] = at(1.0, nil, function() SIM.match() end)
steps[#steps + 1] = at(0.3, nil, function() SIM.join(0.5) end)
steps[#steps + 1] = at(1.0, nil, function() SIM.keys.l() end)
steps[#steps + 1] = at(0.3, "13b_opponent_left", function(S)
	S.check(not PVP.QUEUE_REVEAL.view, "the opponent leaving ends the reveal")
end)
steps[#steps + 1] = at(0.5, nil, function() reset(); SIM.start("ranked") end)
steps[#steps + 1] = at(1.0, nil, function() SIM.match() end)
steps[#steps + 1] = at(1.0, nil, function() PVP.UI.UTILS.overlay_message("Simulated notice") end)
steps[#steps + 1] = at(0.3, "13c_notice", function(S)
	S.check(not PVP.QUEUE_REVEAL.view, "a notice opening ends the reveal")
	S.check(G.OVERLAY_MENU and G.OVERLAY_MENU.states.visible, "and the notice shows")
	G.FUNCS.exit_overlay_menu()
end)

-- placements
steps[#steps + 1] = at(0.5, nil, function() reset(); SIM.start("placing") end)
steps[#steps + 1] = at(1.5, "14_placing")
steps[#steps + 1] = at(0.3, nil, function() SIM.match() end)
steps[#steps + 1] = at(0.3, nil, function() SIM.join(0.5) end)
steps[#steps + 1] = at(2.0, "15_placing_reveal")

-- casual
steps[#steps + 1] = at(0.5, nil, function() reset(); SIM.start("casual") end)
steps[#steps + 1] = at(1.5, "16_casual")
steps[#steps + 1] = at(0.3, nil, function() SIM.match() end)
steps[#steps + 1] = at(0.3, nil, function() SIM.join(0.5) end)
steps[#steps + 1] = at(2.0, "17_casual_reveal")

-- eggs
steps[#steps + 1] = at(0.5, nil, function() reset(); SIM.egg = "off"; SIM.keys.e(); SIM.start("ranked") end) -- jimbo
burst(steps, 16, 0.1, "18_jimbo")
steps[#steps + 1] = at(0.3, nil, function() SIM.keys.e(); SIM.match() end) -- joker
burst(steps, 6, 0.4, "19_joker_keeper")
steps[#steps + 1] = at(0.5, nil, function() reset(); SIM.egg = "joker"; SIM.keys.e(); SIM.start("ranked") end) -- nope
steps[#steps + 1] = at(1.5, nil, function() SIM.match() end)
burst(steps, 10, 0.4, "20_nope")

-- reduced motion
steps[#steps + 1] = at(0.5, nil, function() reset(); G.SETTINGS.reduced_motion = true; SIM.start("ranked") end)
steps[#steps + 1] = at(1.5, "21_calm_hud")
steps[#steps + 1] = at(0.3, nil, function() SIM.match() end)
burst(steps, 4, 0.3, "22_calm_match")
steps[#steps + 1] = at(0.5, nil, function(S)
	G.SETTINGS.reduced_motion = false
	reset()
	S.check(not Q.active and not PVP.QUEUE_REVEAL.view, "torn down")
end)
steps[#steps + 1] = { wait = 1.0, run = function(S) S.check(true, "done") end }

return steps
