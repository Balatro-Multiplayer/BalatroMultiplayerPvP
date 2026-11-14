-- Skips and the Ante time bank over the server's "pvp.skips" match state.
--
-- A skip and a Score Preview cost are requests (MPAPI.request: pvp.skip, pvp.timer_spend): the
-- server keeps every player's skip count and derives their Ante bank. On every STATE or SNAPSHOT
-- this shows the target's skips (PVP.GAME.enemy.skips, nil while unknown) and keeps this player's
-- bank for the timer box (N.bank_seconds). lib/skips_view.lua decides what the state says; this file
-- gathers and acts. A personal-clock ruleset has no bank: its clock is the server's "pvp.clocks".

local KEY = "pvp.skips"

PVP.SkipsNet = PVP.SkipsNet or {}
local N = PVP.SkipsNet
local pvp_lobby = PVP.NetBasics.pvp_lobby

local function request(kind, payload)
	MPAPI.request(kind, payload, PVP.NetBasics.refusal_logger(kind))
end

-- Reports the run's skip total after a skip. A resend is harmless: the server keeps the total.
function N.skip(skips, blind_key)
	if not pvp_lobby() then return end
	local run_id = PVP.current_run_id()
	if not run_id then return end
	if type(skips) ~= "number" then return PVP.match_log("info", "[pvp] skip not sent: no skip count") end
	if type(blind_key) ~= "string" then return PVP.match_log("info", "[pvp] skip not sent: no blind key") end
	request("pvp.skip", { runId = run_id, skips = skips, blindKey = blind_key })
end

-- A cost the player pays out of their own Ante bank (a Score Preview), in milliseconds.
function N.spend(ms)
	if not pvp_lobby() then return end
	local run_id = PVP.current_run_id()
	if not run_id then return end
	if type(ms) ~= "number" or ms ~= ms or ms <= 0 then return end
	request("pvp.timer_spend", { runId = run_id, ms = math.floor(ms + 0.5) })
end

-- What was last seen of each player's skips (SkipsView.remember), for the run it belongs to: only a
-- rise from a seen value is a skip to react to, the first sight is a baseline.
local seen = { lobby = nil, run = nil, skips = {} }

-- The target the shown enemy.skips was read for.
local applied_target = nil

-- This player's Ante bank in milliseconds as the server last said it, nil while unknown.
local my_bank_ms = nil

-- The target skipped: the signal. The Penny Pincher reads the server's record of the slot, not this.
local function opponent_skipped()
	if not PVP.current_ruleset().enemy_location_disabled then
		play_sound("negative", 0.865, 0.4)
		play_sound("gong", 0.765, 0.4)
	end
	if PVP.UI.juice_up_pvp_hud then PVP.UI.juice_up_pvp_hud() end
end

-- This player's Ante bank in seconds, nil while the server has not said it.
function N.bank_seconds()
	return my_bank_ms ~= nil and my_bank_ms / 1000 or nil
end

function N.evaluate(value)
	my_bank_ms = nil
	local lobby = pvp_lobby()
	if not lobby then return end
	local run = PVP.current_run_id()
	local players = PVP.SkipsView.players(value, run)
	if not players then return end
	my_bank_ms = players[lobby.player_id] and players[lobby.player_id].bank_ms or nil
	if not PVP.GAME or not PVP.GAME.enemy then return end
	if seen.lobby ~= lobby or seen.run ~= run then seen = { lobby = lobby, run = run, skips = {} } end

	local target = PVP.current_target_id()
	local tracked = target and not PVP.LOBBY.config.team_based and not PVP.is_byed()
	local switched = target ~= applied_target
	applied_target = target
	local count = 0
	-- A target switch is a baseline: the new target's count shows, nothing is signalled.
	if tracked and not switched and players[target] then count = PVP.SkipsView.rise(seen.skips[target], players[target]) end
	if tracked then PVP.GAME.enemy.skips = players[target] and players[target].skips or nil end
	-- Every player's value is kept, so a target switch compares with what that player had last.
	for id, player in pairs(players) do
		seen.skips[id] = PVP.SkipsView.remember(player)
	end
	if count > 0 then opponent_skipped() end
end

-- Per frame (pvp_api/frame.lua): the state is read again when the target changed (the count shown
-- is the new target's).
function N.update()
	if pvp_lobby() and PVP.current_target_id() ~= applied_target then N.evaluate(MPAPI.get_state(KEY)) end
end

-- CONNECTED: reads the state again, the run may have gone live after the last push.
function N.on_connected()
	N.evaluate(MPAPI.get_state(KEY))
end

if MPAPI.on_state then MPAPI.on_state(KEY, N.evaluate) end
