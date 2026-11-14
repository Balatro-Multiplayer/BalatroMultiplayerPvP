-- Lives over the server's "pvp.lives" match state.
--
-- Nothing is requested here: the server decides every life change. On every STATE or
-- SNAPSHOT this writes PVP._player_lives_cache (lives by player id, which the HUD, card
-- info, lobby and Contest read) and applies this player's new life events, each exactly
-- once (lib/lives_view.lua and lib/applied_effects.lua decide; this file acts). The count of
-- applied events is PVP.GAME.applied, saved with the run (lib/run_save.lua saves all of
-- PVP.GAME). Effects wait until the run is live (pvp_api/run_gate.lua); a rejoin re-reads the
-- state at CONNECTED (pvp_api/lobby_bridge.lua).

local KEY = "pvp.lives"

PVP.LivesNet = PVP.LivesNet or {}
local N = PVP.LivesNet
local pvp_lobby = PVP.NetBasics.pvp_lobby

local RULES_KEY = "pvp.rules"

local apply_pending = false
-- The run this client was already told it is out of, so a repeated STATE or a rejoin's replay
-- of the same state tells it once.
local eliminated_run = nil

local function context(lobby)
	local config = PVP.LOBBY.config
	return {
		my_id = lobby.player_id,
		run_id = PVP.current_run_id(),
		gold_on_life_loss = config.gold_on_life_loss,
		no_gold_on_round_loss = config.no_gold_on_round_loss,
		blind_key = PVP.AppliedEffects.blind_key(
			PVP.is_pvp_boss(),
			PVP.GAME.round_id,
			G.GAME.round_resets.ante,
			G.GAME.blind_on_deck
		),
	}
end

local function apply(effect)
	if effect.type == "comebackBonus" then
		PVP.GAME.comeback_bonus_given = false
		PVP.GAME.comeback_bonus = (PVP.GAME.comeback_bonus or 0) + 1
	elseif effect.type == "easeLives" then
		PVP.GAME.lives = effect.lives
		if effect.delta < 0 and PVP.RLOG then
			PVP.RLOG.record(MPAPI.OPCODE.LIFE_LOST, { lost = -effect.delta, lives = effect.lives })
		end
		PVP.UI.ease_lives(effect.delta, true)
	elseif effect.type == "zeroBlindDollars" then
		if G.GAME.blind and G.GAME.blind.dollars then G.GAME.blind.dollars = 0 end
	end
end

-- Tells this client it is out of a match of 3 or more players, once per run (R31). The result
-- path would otherwise run the loss again when "pvp.result" arrives: result_handled keeps the
-- end screen to one, and the run is recorded as result_net does (pvp_api/result_net.lua). A run
-- recorded already (a crash rejoin into the live run) shows nothing, as result_net does.
local function check_eliminated(lobby)
	local run_id = PVP.current_run_id()
	local result_set = PVP.ResultView.result_run(MPAPI.get_state("pvp.result"), run_id) ~= nil
	local result_over = PVP.GAME.result_handled or result_set
	if
		not PVP.LivesView.should_eliminate(
			MPAPI.get_state(KEY),
			MPAPI.get_state(RULES_KEY),
			run_id,
			lobby.player_id,
			eliminated_run,
			result_over
		)
	then
		return
	end
	-- Latched before the handler runs: a handler that errors must not run twice.
	eliminated_run = run_id
	local recorded = PVP.ResultView.record_once(PVP.config.recordedRuns, run_id)
	if recorded == nil then return end
	PVP.GAME.result_handled = true
	PVP.config.recordedRuns = recorded
	-- recordedRuns is saved by PVP.STATS.record_match, which the eliminated handler reaches through loseGame (not for a contested match: action_eliminated skips loseGame then).
	PVP.HANDLERS.eliminated({ player_id = lobby.player_id })
end

-- Applies the events not applied yet, once the run is loaded; until then the work stays pending.
function N.apply_new()
	local lobby = pvp_lobby()
	if not lobby then
		apply_pending = false
		return
	end
	if not PVP.RunGate.loaded() then return end
	apply_pending = false
	local effects, applied, rejected = PVP.AppliedEffects.step(MPAPI.get_state(KEY), PVP.GAME.applied, context(lobby))
	if rejected then PVP.match_log("info", "[pvp] lives events not applied: " .. rejected) end
	PVP.GAME.applied = applied
	for _, effect in ipairs(effects) do
		apply(effect)
	end
	-- The server's total is the truth for the HUD, also for a catch-up with nothing saved.
	local total = PVP.LivesView.total_to_show(
		MPAPI.get_state(KEY),
		PVP._player_lives_cache,
		PVP.current_run_id(),
		lobby.player_id
	)
	if total ~= nil then PVP.GAME.lives = total end
	check_eliminated(lobby)
end

-- CONNECTED: reads the state again, the run may have gone live (a crash rejoin's lobby attach)
-- after the last push.
function N.on_connected()
	N.evaluate(MPAPI.get_state(KEY))
end

-- The target's lives last seen, so only a drop (not the first sight, a repeat or a SNAPSHOT
-- of the same value) plays the opponent's life-lost signal.
local seen = { lobby = nil, run = nil, lives = {} }

-- The HUD enemy lives follow the target; a drop in them is the opponent losing a life.
local function follow_target(lobby, cache)
	local run = PVP.current_run_id()
	if seen.lobby ~= lobby or seen.run ~= run then seen = { lobby = lobby, run = run, lives = {} } end
	PVP.refresh_target_lives()
	local target = PVP.current_target_id()
	local lives = target and cache[target]
	if lives ~= nil and PVP.OPPONENT_SIGNALS.lives_dropped(seen.lives[target], lives) then
		PVP.OPPONENT_SIGNALS.play_life_lost()
		if PVP.UI.juice_up_pvp_hud then pcall(PVP.UI.juice_up_pvp_hud) end
	end
	-- Every player's value is kept, so a target switch compares with what that player had last.
	for id, value in pairs(cache) do
		seen.lives[id] = value
	end
end

function N.evaluate(value)
	local lobby = pvp_lobby()
	if not lobby then return end
	local cache = PVP.LivesView.cache(value, PVP.current_run_id())
	if cache then
		PVP._player_lives_cache = cache
		follow_target(lobby, cache)
	end
	apply_pending = true
	N.apply_new()
end

-- Per frame (pvp_api/frame.lua): applies what the run not being loaded yet left pending.
function N.update()
	if apply_pending then N.apply_new() end
end

if MPAPI.on_state then MPAPI.on_state(KEY, N.evaluate) end
