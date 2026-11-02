-- Queue-HUD simulator. No server, no queue handle: drives PVP.QUEUE_HUD directly, with faked
-- ratings and queue counts. tests/scenarios/queue_hud_walkthrough.lua scripts it; by hand, load
-- it from the DebugPlus console (ctrl+/ or `):
--   eval dofile(SMODS.Mods.MultiplayerPvP.path .. "tests/scenarios/lib/qhud_sim.lua")
-- Re-running it is fine (it replaces itself).
--
-- Hold alt (option) and press:
--   p  play the whole thing (ranked): search, 3 widening steps, match, opponent joins
--   1  start Ranked (placed, Elo 1432 #57)   2  start Ranked (placing, 3/10)   3  start Casual (Nemesis)
--   s  skip 30s (next widening step)          c  bump the in-queue count
--   m  match found                            j  lobby joined (opponent arrives 1.5s later)
--   d  lobby destroyed (reveal teardown)      e  cycle forced egg: off > jimbo > joker > nope
--   r  toggle reduced motion                  x  stop everything, restore real API calls
--   b  cycle the reveal's backdrop preset (PVP.QUEUE_BACKDROP.PRESETS, then off)

local Q = PVP.QUEUE_HUD
local SIM = rawget(_G, "QHUD_SIM") or {}
QHUD_SIM = SIM

local M = MPAPI.matchmaking
SIM.real = SIM.real or { get_rating = M.get_rating, get_queue_counts = M.get_queue_counts, cancel = G.FUNCS.mp_pvp_cancel_queue }
SIM.real_eggs = SIM.real_eggs or { jimbo_peek = Q.EGGS.jimbo_peek, keeper_joker = Q.EGGS.keeper_joker, keeper_nope = Q.EGGS.keeper_nope }
SIM.me_rating = SIM.me_rating or { rating = 1432, rank = 57, isPlacement = false }
SIM.count = SIM.count or 7
SIM.egg = SIM.egg or "off"

local function log(msg)
	print("[qhud sim] " .. msg)
	if G.E_MANAGER and not SIM.quiet then
		pcall(attention_text, { text = msg, scale = 0.5, hold = 1.2, major = G.ROOM_ATTACH, align = "cm", offset = { x = 0, y = 3.4 }, colour = G.C.UI.TEXT_DARK })
	end
end

local function after(delay, fn)
	G.E_MANAGER:add_event(Event({ trigger = "after", delay = delay, timer = "REAL", blockable = false, blocking = false, func = function()
		fn()
		return true
	end }))
end

local function install_fakes()
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
	G.FUNCS.mp_pvp_cancel_queue = function()
		Q.stop()
	end
end

local function restore()
	M.get_rating, M.get_queue_counts = SIM.real.get_rating, SIM.real.get_queue_counts
	G.FUNCS.mp_pvp_cancel_queue = SIM.real.cancel
	for k, v in pairs(SIM.real_eggs) do
		Q.EGGS[k] = v
	end
	SIM.egg = "off"
end

local function apply_egg()
	for k, v in pairs(SIM.real_eggs) do
		Q.EGGS[k] = v
	end
	if SIM.egg == "jimbo" then
		Q.EGGS.jimbo_peek = 1
	elseif SIM.egg == "joker" then
		Q.EGGS.keeper_nope, Q.EGGS.keeper_joker = 0, 1
	elseif SIM.egg == "nope" then
		Q.EGGS.keeper_nope = 1
	end
end

local function start(kind)
	install_fakes()
	Q.stop()
	Q.dismiss_reveal()
	Q.active = false
	if kind == "casual" then
		Q.start({ kind = PVP.LobbyAccess.CASUAL, key = "pvp_nemesis" })
	else
		SIM.me_rating = kind == "placing" and { isPlacement = true, gamesPlayed = 3, placementGames = 10 }
			or { rating = 1432, rank = 57, isPlacement = false }
		Q.start({ kind = PVP.LobbyAccess.RANKED, key = PVP.RulesetKey.VANILLA })
	end
	log("start " .. kind)
end

local function skip(secs)
	if not Q.active then
		return log("not searching")
	end
	Q.started_at = Q.started_at - (secs or 30)
end

local function match()
	install_fakes()
	SIM.lobby = nil
	Q.match_found()
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

local function join(opp_delay)
	local players = { { id = "me", displayName = "You" } }
	local lobby = { player_id = "me", _destroyed = false, get_players = function() return players end }
	SIM.lobby = lobby
	Q.lobby_ready(lobby)
	after(opp_delay or 1.5, function()
		if SIM.lobby == lobby then
			local opp = OPPONENTS[love.math.random(#OPPONENTS)]
			players[2] = { id = "opp", displayName = opp[1], preferredJoker = opp[2] }
		end
	end)
end

local function play()
	start("ranked")
	after(1.5, function() skip() end)
	after(2.5, function() skip() end)
	after(3.5, function() skip() end)
	after(5.5, match)
	after(7.0, function() join(1.5) end)
end

local keys = {
	p = play,
	["1"] = function() start("ranked") end,
	["2"] = function() start("placing") end,
	["3"] = function() start("casual") end,
	s = function() skip(30) end,
	c = function()
		SIM.count = SIM.count + 3
		Q.next_poll = 0
	end,
	m = match,
	j = function() join(1.5) end,
	d = function()
		if SIM.lobby then
			SIM.lobby._destroyed = true
		end
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
		for k in pairs(B.PRESETS) do keys[#keys + 1] = k end
		table.sort(keys)
		keys[#keys + 1] = false
		local i = 1
		for j, k in ipairs(keys) do if k == B.REVEAL then i = j % #keys + 1 end end
		B.REVEAL = keys[i]
		log("backdrop: " .. tostring(B.REVEAL))
	end,
	x = function()
		Q.stop()
		Q.dismiss_reveal()
		restore()
		log("stopped")
	end,
}

SIM.keys = keys
SIM.start, SIM.skip, SIM.match, SIM.join = start, skip, match, join

SIM.orig_keypressed = SIM.orig_keypressed or love.keypressed
love.keypressed = function(key, scancode, isrepeat)
	if not isrepeat and keys[key] and love.keyboard.isDown("lalt", "ralt") then
		local ok, err = pcall(keys[key])
		if not ok then
			print("[qhud sim] " .. tostring(err))
		end
		return
	end
	return SIM.orig_keypressed(key, scancode, isrepeat)
end

log("qhud sim loaded: alt+p to play")
return "qhud sim loaded"
