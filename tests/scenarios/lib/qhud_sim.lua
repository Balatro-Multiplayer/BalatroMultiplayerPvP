-- Loaded with qhud_sim=true in .env (pvp_api/zz_qhud_dev.lua); the scenario runner may also
-- load this file directly. Alt+P restarts the preview; Alt+X cancels it and restores the API.
-- The search runs through pvp_api/queue.lua's real handlers on a fake matchmaking handle;
-- only the lobby is faked, so lobby_ready's lobby half (the mirror, ready signals) is skipped.
--
-- Hold alt (option) and press:
--   p  play the whole thing (Ranked Expanded): search, 3 widening steps, match, opponent joins,
--      the reveal's countdown, the Draft against a bot (qhud_draft.lua), then a practice run
--      on the drafted deck and stake
--   1  start Ranked (placed, Elo 1432 #57)   2  start Ranked (placing, 3/10)   3  start Casual (Nemesis)
--   s  skip 30s (next widening step)          c  bump the in-queue count
--   m  match found                            j  lobby joined (opponent 1.5s later, Draft after the countdown)
--   d  straight to the Draft                  k  lobby destroyed (reveal teardown)
--   f  lobby join fails (handle error)        l  opponent leaves the lobby
--   e  cycle forced egg: off > jimbo > joker > nope
--   x  stop everything, restore real API calls
--   b  cycle the reveal's backdrop preset (PVP.QUEUE_BACKDROP.PRESETS, then off)

local Q = PVP.QUEUE_HUD
local Cards = PVP.QUEUE_CARDS
local SIM = rawget(_G, "QHUD_SIM") or {}
QHUD_SIM = SIM
local DRAFT = PVP.load_mp_file("tests/scenarios/lib/qhud_draft.lua")

local M = MPAPI.matchmaking
SIM.generation = SIM.generation or 0
SIM.real_eggs = SIM.real_eggs
	or {
		jimbo_peek = Cards.EGGS.jimbo_peek,
		keeper_joker = Cards.EGGS.keeper_joker,
		keeper_nope = Cards.EGGS.keeper_nope,
	}
SIM.me_rating = SIM.me_rating or { rating = 1432, rank = 57, isPlacement = false }
SIM.count = SIM.count or 7
SIM.egg = SIM.egg or "off"

local function log(msg)
	print("[qhud sim] " .. msg)
	if G.E_MANAGER and not SIM.quiet then
		pcall(attention_text, {
			text = msg,
			scale = 0.5,
			hold = 1.2,
			major = G.ROOM_ATTACH,
			align = "cm",
			offset = { x = 0, y = 3.4 },
			colour = G.C.UI.TEXT_DARK,
		})
	end
end

local function after(delay, fn)
	local generation = SIM.generation
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = delay,
		timer = "REAL",
		blockable = false,
		blocking = false,
		func = function()
			if SIM.generation == generation then fn() end
			return true
		end,
	}))
end

local function install_fakes()
	if not SIM.real then SIM.real = { get_rating = M.get_rating, get_queue_counts = M.get_queue_counts } end
	M.get_rating = function(_, _, _, player_id, cb)
		after(0.4, function()
			if player_id == "opp" then
				cb(nil, { rating = 1488, rank = 41, isPlacement = false })
			else
				cb(nil, SIM.me_rating)
			end
		end)
	end
	M.get_queue_counts = function(_, cb)
		after(0.2, function()
			cb(nil, { [Q.count_key or ""] = { queued = SIM.count } })
		end)
	end
end

local function restore()
	if SIM.real then
		M.get_rating, M.get_queue_counts = SIM.real.get_rating, SIM.real.get_queue_counts
		SIM.real = nil
	end
	for k, v in pairs(SIM.real_eggs) do
		Cards.EGGS[k] = v
	end
	SIM.egg = "off"
end

local function apply_egg()
	for k, v in pairs(SIM.real_eggs) do
		Cards.EGGS[k] = v
	end
	if SIM.egg == "jimbo" then
		Cards.EGGS.jimbo_peek = 1
	elseif SIM.egg == "joker" then
		Cards.EGGS.keeper_nope, Cards.EGGS.keeper_joker = 0, 1
	elseif SIM.egg == "nope" then
		Cards.EGGS.keeper_nope = 1
	end
end

-- A matchmaking handle like MPAPI's (api/matchmaking/handle.lua) that never reaches a server:
-- the simulator fires its events. Cancelling it (the HUD's button) stops the simulator. Ranked
-- handles carry the private fields the HUD reads, the window widening on MPAPI's requeue schedule.
local function fake_handle(ranked)
	local handle = { _left = false, _event_handlers = {}, _queued_at = love.timer.getTime() }
	if ranked then
		handle._nakama_rating = tonumber(SIM.me_rating.rating)
		setmetatable(handle, {
			__index = function(h, k)
				if k == "_nakama_spread" then return M.ranked_spread(love.timer.getTime() - h._queued_at) end
			end,
		})
	end
	function handle:on(event, fn)
		self._event_handlers[event] = self._event_handlers[event] or {}
		table.insert(self._event_handlers[event], fn)
	end
	function handle:_fire(event, ...)
		for _, fn in ipairs(self._event_handlers[event] or {}) do
			fn(...)
		end
	end
	function handle:leave()
		if self._left then return end
		self._left = true
		self:_fire("left")
		if SIM.handle == self then
			SIM.handle = nil
			SIM.stop()
		end
	end
	return handle
end

-- Leave the simulator's queue the way the cancel button does, if it is still the live one.
local function drop_handle()
	local handle = SIM.handle
	SIM.handle = nil
	if handle and PVP._match_handle == handle then PVP._cancel_queue() end
end

-- lobby_ready's queue half: the search is over.
local function end_search()
	PVP._active_queue_id = nil
	PVP._show_searching(false)
end

local function start(kind)
	drop_handle()
	if PVP._match_handle or (PVP.LOBBY and PVP.LOBBY.code) then
		log("leave the live queue or lobby before starting the simulator")
		return false
	end
	SIM.generation = SIM.generation + 1
	SIM.active, SIM.lobby = true, nil
	DRAFT.stop({ keep_page = true })
	install_fakes()
	Q.stop()
	Q.dismiss_reveal()
	Q.active = false
	if kind ~= "casual" then
		SIM.me_rating = kind == "placing" and { isPlacement = true, gamesPlayed = 3, placementGames = 10 }
			or { rating = 1432, rank = 57, isPlacement = false }
	end
	local real_queue = M.queue
	M.queue = function(opts)
		SIM.handle = fake_handle(opts.ranked)
		return SIM.handle
	end
	local ok, err = pcall(function()
		if kind == "casual" then
			PVP._join_queue(PVP.LobbyAccess.CASUAL, "pvp_nemesis")
		else
			PVP._join_ranked_ruleset(PVP.RulesetKey.EXPANDED)
		end
	end)
	M.queue = real_queue
	if not ok then error(err, 0) end
	SIM.handle:_fire("queued", 1)
	log("start " .. kind)
	return true
end

local function skip(secs)
	if not (Q.active and SIM.handle) then return log("not searching") end
	SIM.handle._queued_at = SIM.handle._queued_at - (secs or 30)
end

local function match()
	if not (SIM.active and SIM.handle) then return end
	install_fakes()
	SIM.lobby = nil
	SIM.handle:_fire("match_found", { lobbyCode = "SIM" })
end

-- The matched lobby can't be joined: MPAPI fires error after match_found (dispatch.lua).
-- queue.lua's handler alone must end the search and the reveal.
local function fail()
	local handle = SIM.handle
	if not (SIM.active and handle) then return end
	SIM.generation = SIM.generation + 1
	SIM.active, SIM.lobby, SIM.handle = false, nil, nil
	handle:_fire("error", "lobby join failed: simulated")
	restore()
	log("lobby join failed")
end

-- Mock opponents: the people with their own privilege avatar (BalatroMultiplayerServer
-- nakama/src/shared/avatars/catalog.ts; the staff one isn't a person's). One per join.
local OPPONENTS = {
	{ "Virtualized", "j_perkeo" },
	{ "Bean", "j_turtle_bean" },
	{ "Vagabond", "j_vagabond" },
	{ "Sizaak", "j_dusk" },
	{ "Lava", "j_burnt" },
	{ "Twelve", "j_stone" },
}

local function me()
	return { id = "me", displayName = "You", preferredJoker = MPAPI.connection_state.preferred_joker }
end

local function opponent()
	local opp = OPPONENTS[love.math.random(#OPPONENTS)]
	return { id = "opp", displayName = opp[1], preferredJoker = opp[2] }
end

-- After the Draft: a practice run on the drafted deck and stake, as the match would have been.
local function picked(item)
	local center = item and G.P_CENTERS[item.key]
	local stake = item and G.P_CENTER_POOLS.Stake[item.stake]
	if not (center and stake) then return log("the Draft ended with no pick") end
	log(
		"drafted "
			.. localize({ type = "name_text", set = "Back", key = center.key })
			.. " on "
			.. localize({ type = "name_text", set = "Stake", key = stake.key })
	)
	after(1.5, function()
		SIM.stop()
		G.E_MANAGER:add_event(Event({
			trigger = "after",
			delay = 0.2,
			timer = "REAL",
			blockable = false,
			blocking = false,
			func = function()
				PVP._start_practice(DRAFT.RULESET, { back = center.name, stake = item.stake })
				return true
			end,
		}))
	end)
end

-- What the game start does in a matchmade lobby: the reveal ends and the Draft opens.
local function draft(players)
	if not SIM.active then
		if not start("ranked") then return end
		end_search()
	end
	Q.dismiss_reveal()
	DRAFT.start(players or { me(), opponent() }, picked)
end

local function join(opp_delay)
	if not SIM.active then return end
	local players = { me() }
	local lobby = {
		player_id = "me",
		_destroyed = false,
		get_players = function()
			return players
		end,
	}
	SIM.lobby, SIM.players = lobby, players
	Q.lobby_ready(lobby)
	end_search()
	after(opp_delay or 1.5, function()
		if SIM.lobby == lobby then players[2] = opponent() end
	end)
	-- The host's start hold (ui/lobby/_ready.lua) runs from the opponent's arrival.
	after((opp_delay or 1.5) + PVP.QUEUE_REVEAL.HOLD_SECONDS, function()
		if SIM.lobby == lobby and not lobby._destroyed and players[2] then draft(players) end
	end)
end

local function play()
	if not start("ranked") then return end
	after(1.5, function()
		skip()
	end)
	after(2.5, function()
		skip()
	end)
	after(3.5, function()
		skip()
	end)
	after(5.5, match)
	after(7.0, function()
		join(1.5)
	end)
end

function SIM.stop()
	SIM.generation = SIM.generation + 1
	SIM.active, SIM.lobby = false, nil
	drop_handle()
	DRAFT.stop()
	Q.stop()
	Q.dismiss_reveal()
	restore()
	log("stopped")
end

local keys = {
	p = play,
	["1"] = function()
		start("ranked")
	end,
	["2"] = function()
		start("placing")
	end,
	["3"] = function()
		start("casual")
	end,
	s = function()
		skip(30)
	end,
	c = function()
		SIM.count = SIM.count + 3
		Q.next_poll = 0
	end,
	m = match,
	j = function()
		join(1.5)
	end,
	d = function()
		draft()
	end,
	k = function()
		if SIM.lobby then SIM.lobby._destroyed = true end
	end,
	f = fail,
	l = function()
		if SIM.lobby then SIM.players[2] = nil end
	end,
	e = function()
		local order = { off = "jimbo", jimbo = "joker", joker = "nope", nope = "off" }
		SIM.egg = order[SIM.egg]
		apply_egg()
		log("egg: " .. SIM.egg)
	end,
	r = function()
		G.SETTINGS.reduced_motion = not G.SETTINGS.reduced_motion
		log("reduced motion: " .. tostring(G.SETTINGS.reduced_motion))
	end,
	b = function()
		local B = PVP.QUEUE_BACKDROP
		local keys = {}
		for k in pairs(B.PRESETS) do
			keys[#keys + 1] = k
		end
		table.sort(keys)
		keys[#keys + 1] = false
		local i = 1
		for j, k in ipairs(keys) do
			if k == B.REVEAL then i = j % #keys + 1 end
		end
		B.REVEAL = keys[i]
		log("backdrop: " .. tostring(B.REVEAL))
	end,
	x = SIM.stop,
}

SIM.keys = keys
SIM.start, SIM.skip, SIM.match, SIM.join, SIM.draft, SIM.fail = start, skip, match, join, draft, fail
DRAFT.on_leave = SIM.stop

SIM.orig_keypressed = SIM.orig_keypressed or love.keypressed
love.keypressed = function(key, scancode, isrepeat)
	if
		not isrepeat
		and keys[key]
		and love.keyboard.isDown("lalt", "ralt")
		and G.STAGE == G.STAGES.MAIN_MENU
		and MPAPI.get_focused_mod() == PVP.id
	then
		local ok, err = pcall(keys[key])
		if not ok then print("[qhud sim] " .. tostring(err)) end
		return
	end
	return SIM.orig_keypressed(key, scancode, isrepeat)
end

print("[qhud sim] loaded: alt+p to play")
return "qhud sim loaded"
