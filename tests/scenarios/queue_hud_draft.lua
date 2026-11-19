-- Walks the queue HUD from a match into the Draft against the simulator's bot, through the
-- real Draft buttons, and on into the practice run on the drafted deck and stake. No server.
-- Drives tests/scenarios/lib/qhud_sim.lua. Shots go to $QHUD_SHOTS (default /tmp/qhud_draft).
local OUT = os.getenv("QHUD_SHOTS") or "/tmp/qhud_draft"
local SIM, DRAFT
local n, picked = 0, nil

local function shot(name)
	n = n + 1
	local file = string.format("%s/%02d_%s.png", OUT, n, name)
	love.graphics.captureScreenshot(function(img)
		local f = io.open(file, "wb")
		f:write(img:encode("png"):getString())
		f:close()
	end)
end

local function setup()
	local lobby = DRAFT and DRAFT.lobby
	return lobby and lobby._game.setup
end

local function draft_over()
	local s = setup()
	return s and s.results.draft ~= nil
end

local function my_turn()
	local s = setup()
	return s and s.open and s.open.actor == "me"
end

-- One of the player's turns: Random fills the selection, Confirm commits it.
local function my_turn_steps(steps, i)
	steps[#steps + 1] = {
		wait = 0.2,
		timeout = 15,
		until_ = function()
			return my_turn() or draft_over()
		end,
		run = function()
			if my_turn() then
				G.FUNCS.mpapi_ban_pick_random()
				shot("my_turn_" .. i)
			end
		end,
	}
	steps[#steps + 1] = {
		wait = 0.6,
		run = function(S)
			if not my_turn() then return end
			local before = #setup().open.banned
			G.FUNCS.mpapi_ban_pick_confirm()
			S.check(draft_over() or #setup().open.banned > before, "turn " .. i .. " confirmed")
		end,
	}
end

local steps = {
	{ wait = 1.0, run = function(S)
		os.execute("mkdir -p '" .. OUT .. "'")
		MPAPI._internal.activate_mod(PVP.id)
		SIM, DRAFT = QHUD_SIM, QHUD_DRAFT
		S.check(SIM ~= nil and DRAFT ~= nil, "sim and Draft loaded")
		SIM.quiet = true
	end },
	{ wait = 1.0, run = function(S)
		S.check(SIM.start("ranked"), "search started")
	end },
	{ wait = 1.5, run = function()
		shot("hud")
		SIM.match()
	end },
	{ wait = 1.5, run = function()
		shot("reveal")
		SIM.join(0.5)
	end },
	{ wait = 1.5, run = function(S)
		local view = PVP.QUEUE_REVEAL.view
		local footer = tostring(view and view.footer_text)
		S.check(footer:match("%d$") ~= nil, "the footer counts down: " .. footer)
		shot("countdown")
	end },
	{ wait = 0.5, timeout = 8, until_ = function()
		return setup() and setup().open ~= nil
	end, run = function(S)
		S.check(PVP.QUEUE_REVEAL.view == nil, "the reveal ended for the Draft")
		S.check(MPAPI.get_current_view() == "lobby_menu", "the Draft shows in the lobby view")
		S.check(MPAPI.BanPick.is_active(), "MPAPI.BanPick runs the Draft")
		S.check(#setup().open.pool == 9, "nine deck and stake tiles")
		S.check(PVP.LOBBY.config.ruleset ~= nil, "lobby config intact")
		shot("draft_open")
	end },
}
my_turn_steps(steps, 1)
steps[#steps + 1] = { wait = 0.8, run = function()
	shot("after_turn_1")
end }
my_turn_steps(steps, 2)
steps[#steps + 1] = { wait = 0.2, timeout = 15, until_ = draft_over, run = function(S)
	local survivor = setup().results.draft.survivors[1]
	picked = { key = survivor.art or survivor.key, stake = survivor.stake }
	S.check(G.P_CENTERS[picked.key] ~= nil, "drafted " .. picked.key .. " on stake " .. tostring(picked.stake))
	shot("drafted")
end }
steps[#steps + 1] = { wait = 0.5, timeout = 20, until_ = function()
	return G.STAGE == G.STAGES.RUN and G.GAME and G.GAME.selected_back and G.STATE == G.STATES.BLIND_SELECT
end, run = function(S)
	S.check(PVP.is_practice_mode(), "a practice run")
	S.check(PVP.SP.ruleset == "ruleset_mp_expanded", "on Expanded")
	S.check(G.GAME.selected_back.name == G.P_CENTERS[picked.key].name, "on the drafted deck: " .. tostring(G.GAME.selected_back.name))
	S.check(G.GAME.stake == picked.stake, "on the drafted stake: " .. tostring(G.GAME.stake))
	S.check(MPAPI.get_current_lobby() ~= DRAFT.lobby and not SIM.active, "the simulator let go")
	shot("run")
end }
steps[#steps + 1] = { wait = 1.0, run = function(S)
	S.check(true, "done")
end }

return steps
