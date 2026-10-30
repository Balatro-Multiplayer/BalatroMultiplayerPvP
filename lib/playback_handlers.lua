-- §22.2/§22.3: PvP's own opcode semantics for MPAPI's generic playback engine
-- (BalatroMultiplayerAPI/api/playback/{registry,driver,timeline}.lua). One
-- MPAPI.playback.register_handler("pvp", opcode, fn) per opcode PVP.RLOG.record
-- ever emits (see lib/replay_log.lua's own header comment for the full
-- vocabulary), so nothing recorded is silently dropped during playback.
--
-- FULL CARD-LEVEL FIDELITY (Connor's explicit requirement, logged in full in
-- AUTONOMOUS_DECISIONS.md): every POV opcode is replayed by calling the exact
-- real function a live click would call, fed the exact real Card/CardArea
-- objects the recording's positional indices point to. This works because
-- PVP.RLOG's `manifest` event already captures {seed, deck, sleeve, stake,
-- challenge, ruleset, gamemode} (lib/replay_log.lua's REQUIRED_MANIFEST_KEYS),
-- and Balatro's own RNG is a pure deterministic hash chain keyed only by seed
-- + call sequence -- so PVP._start_playback (lib/playback_launch.lua)
-- starting a fresh local run from that same manifest reproduces the exact
-- same cards/shops at every point, making the original recording's
-- positional args (1-based CardArea indices) valid references again. Real
-- vanilla functions then advance G.STATE themselves (e.g.
-- play_cards_from_highlighted already sets G.STATE=HAND_PLAYED) -- no forced
-- state hack needed for card-bearing actions, only for the couple of pure
-- navigation opcodes with no associated card (select_blind/skip_blind).
--
-- Non-POV projection is unchanged from the original scope: HUD-only, via the
-- same direct PVP.GAME.enemy.* writes as before -- there is only one real
-- board to drive (the POV's), the opponent side is still just a display.
--
-- Recording is already silenced automatically during any of this: a replay/
-- spectate session always runs through PVP._start_playback's local lobby
-- (MPAPI.create_local_lobby), which never sets PVP.LOBBY.code -- and
-- RLOG.is_active() (lib/replay_log.lua) already gates on that field, exactly
-- like it already does for a human practicing. Confirmed live; no change
-- needed to replay_log.lua.

local AREA = PVP.UTILS.AREA

local function area_object(area_id)
	if area_id == AREA.shop_jokers then return G.shop_jokers end
	if area_id == AREA.shop_booster then return G.shop_booster end
	if area_id == AREA.shop_vouchers then return G.shop_vouchers end
	if area_id == AREA.jokers then return G.jokers end
	if area_id == AREA.consumeables then return G.consumeables end
	if area_id == AREA.hand then return G.hand end
	if area_id == AREA.pack_cards then return G.pack_cards end
	return nil
end

-- Confirmed live in MPAPI/SPDRN's own copy of this function (see
-- BalatroMultiplayerAPI/api/replay/generic_codes.lua's 'play'-area comment
-- for the reproduced crash trace): G.hand can be nil, not just empty, at the
-- moment a recorded opcode fires (it's torn down and rebuilt across round/run
-- transitions) -- indexing G.hand.cards below would crash outright before any
-- per-index lookup even ran. Not separately reproduced against a PvP
-- recording, but ported the same guard rather than waiting for a PvP-specific
-- crash to prove an already-unambiguous gap.
local function highlight_hand_indices(indices)
	if not (G.hand and G.hand.cards) then return end
	for _, i in ipairs(indices or {}) do
		local card = G.hand.cards[i]
		if card then G.hand:add_to_highlighted(card) end
	end
end

-- Non-POV projection: NOT via MPAPI.calculate_blind -- that dispatches to the
-- blind's `calculate` (the SEND decision on the ACTING player's own client,
-- see objects/blinds/nemesis.lua and api/synced/core.lua), which only takes
-- effect by broadcasting over a live sync bus to a connected opponent. A
-- playback/spectate session has no such live opponent, so that call would be
-- a silent no-op here -- confirmed by reading api/synced/core.lua's
-- perform_send/broadcast_raw, which both bail out with no lobby. What a live
-- match's RECEIVING client actually applies to PVP.GAME.enemy.* is the
-- blind's `receive` (nemesis.lua), so this mirrors receive's own core score/
-- hands assignment directly instead. Deliberately omits receive's skips/lives
-- fields and side effects (sounds, timer-stop logic): the `hand_result`
-- opcode's own recorded args never carried skips/lives (see net.lua's
-- RLOG.record call), so writing them here from absent data would incorrectly
-- null out values `skip_blind`'s own handler (below) is responsible for.
local function project_enemy_hand_result(args)
	local score_str, hands_left = args and args[1], args and args[2]
	if not score_str or not hands_left then
		return
	end
	local score = PVP.INSANE_INT.from_string(score_str)
	if PVP.INSANE_INT.greater_than(score, PVP.GAME.enemy.highest_score) then
		PVP.GAME.enemy.highest_score = score
	end
	PVP.GAME.enemy.real_score = score
	PVP.GAME.enemy.hands = hands_left
	PVP.GAME.enemy.info_received = true
end

MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.MANIFEST, function(args, _ctx)
	-- Framing event -- PVP._start_playback (lib/playback_launch.lua) reads the
	-- manifest directly from the timeline/run metadata before playback starts,
	-- not through this dispatch path. No-op here.
end)

MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.END, function(args, _ctx)
	-- Framing event; the viewer's own on_complete (Driver opts) handles
	-- end-of-playback UI, not this handler.
end)

MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.CHK, function(args, _ctx)
	-- Framing event (hash trailer) -- nothing to apply during playback.
end)

MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.MONEY_DELTA, function(_args, _ctx)
	-- Pure bookkeeping (see overrides/game.lua's ease_dollars hook) -- the
	-- real dollar change already happens as a side effect of whatever action
	-- caused it (buy/sell/etc, each already replayed by its own handler),
	-- nothing to apply.
end)

-- §22.2/§22.3 full-fidelity: navigation into a blind. Real vanilla state
-- transition is `new_round()`, reached via the real (PvP-wrapped)
-- G.FUNCS.select_blind -- NOT a from-scratch reimplementation, so every real
-- side effect (tag application, SMODS contexts) fires exactly as it would
-- live. Its one crash risk (e.UIBox:get_UIE_by_ID('tag_container')) is
-- avoided by passing the REAL, currently-on-screen G.blind_select UIBox --
-- valid because a playback session always has a real UI on screen, this
-- isn't headless. Recording re-fires safely (see file header: RLOG is
-- already inactive for any PVP._start_playback session).
-- Real crash found live during verification: toggle_shop()'s SHOP->
-- BLIND_SELECT state flip happens synchronously, but the actual G.blind_select
-- UIBox is only (re)built later, off a queued event Game:update processes on
-- a subsequent frame (mirrors the same "STATE flips before the screen exists"
-- timing already found for round_eval/shop). Calling select_blind
-- synchronously right after toggle_shop would hand it a stale/nil UIBox.
-- Deferred via PVP._playback_wait_for (lib/playback_launch.lua) -- the same
-- one-shot condition-poll already used to reach BLIND_SELECT at bootstrap --
-- rather than a blocking wait, since a registry handler is a plain
-- synchronous function with no coroutine to yield from.
local function do_select_blind()
	local blind_key = G.GAME.round_resets.blind_choices[G.GAME.blind_on_deck]
	G.FUNCS.select_blind({ config = { ref_table = G.P_BLINDS[blind_key] }, UIBox = G.blind_select })
end

-- The driver dispatches the next entry as soon as no blocking event is queued, and a fast-forward
-- (the checkpoint index of a crash rejoin) dispatches many in one frame. A deferred blind action
-- therefore pauses the driver until it has applied: else the recorded play after a select_blind
-- runs before the hand is dealt, finds no card, and the whole catch-up desyncs. Both waits are
-- bounded, so a replay that already moved past the screen cannot hang.
local BLIND_WAIT_TIMEOUT_SECONDS = 10

local function on_blind_select_screen()
	return G.STATE == G.STATES.BLIND_SELECT and G.blind_select ~= nil and G.blind_select.alignment.offset.x == 0
end

-- Pauses the driver, waits for the blind-select screen, runs `act`, then waits for `applied`
-- (when given) before the driver plays on.
local function blind_action(ctx, act, applied)
	local driver = ctx.driver
	if driver then
		driver:pause()
	end
	local function resume()
		if driver then
			driver:play()
		end
	end
	local deadline = love.timer.getTime() + BLIND_WAIT_TIMEOUT_SECONDS
	PVP._playback_wait_for(function()
		if on_blind_select_screen() then
			return true
		end
		if love.timer.getTime() >= deadline then
			MPAPI.sendWarnMessage('[replay] blind-select screen never appeared after ' .. BLIND_WAIT_TIMEOUT_SECONDS .. 's, skipping this action')
			return true
		end
		return false
	end, function()
		if not on_blind_select_screen() then
			resume()
			return
		end
		act()
		if not applied then
			resume()
			return
		end
		local applied_by = love.timer.getTime() + BLIND_WAIT_TIMEOUT_SECONDS
		PVP._playback_wait_for(function()
			return applied() or love.timer.getTime() >= applied_by
		end, resume)
	end)
end

local function hand_dealt()
	return G.STATE == G.STATES.SELECTING_HAND and G.hand ~= nil and #G.hand.cards > 0
end

MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.SELECT_BLIND, function(_args, ctx)
	if not ctx.is_pov then
		return
	end
	MPAPI.playback.leave_shop_if_needed()
	blind_action(ctx, do_select_blind, hand_dealt)
end)

MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.SKIP_BLIND, function(args, ctx)
	if ctx.is_pov then
		MPAPI.playback.leave_shop_if_needed()
		-- Same real-UIBox technique as select_blind -- skip_blind's entire
		-- state-advance (blind_on_deck/blind_states) lives inside vanilla's own
		-- `if _tag then ... end`, so a stubbed/absent UIBox would silently skip
		-- it entirely (confirmed by reading button_callbacks.lua) -- the real
		-- G.blind_select genuinely has a real tag_container here for the same
		-- "there's always a real UI on screen" reason as select_blind above.
		-- Deferred for the same reason select_blind is: BLIND_SELECT's own
		-- UIBox may not have finished (re)building yet when this dispatches.
		-- skip_blind moves blind_on_deck at once and queues a blocking event for the tags, so the
		-- driver can play on right after the click.
		blind_action(ctx, function()
			G.FUNCS.skip_blind({ UIBox = MPAPI.playback.current_blind_panel() })
		end)
	else
		-- Direct projection, same reasoning as project_enemy_hand_result above
		-- -- MPAPI.calculate_blind would be a silent no-op here.
		PVP.GAME.enemy.skips = (PVP.GAME.enemy.skips or 0) + 1
	end
end)

-- Same crash class as MPAPI/SPDRN's own play/discard handlers (see
-- BalatroMultiplayerAPI/api/replay/generic_codes.lua's 'play' comment for the
-- reproduced-live crash trace): highlight_hand_indices is purely positional
-- here (no ref-based resolution in this port yet), so a desynced replay
-- pointing at out-of-range/stale indices can silently highlight nothing at
-- all, and calling play_cards_from_highlighted()/discard_cards_from_highlighted()
-- with an empty G.hand.highlighted crashes vanilla's evaluate_play (no
-- empty-hand guard exists outside the real UI's disabled Play button). Not
-- separately reproduced against a PvP recording, but the exact same
-- unconditional-call structure is unambiguously present, so ported the same
-- guard rather than waiting for a PvP-specific crash to prove it.
MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.PLAY, function(args, ctx)
	if not ctx.is_pov then
		return
	end
	local indices = args and args[1]
	if not indices then
		return
	end
	highlight_hand_indices(indices)
	local highlighted = G.hand and G.hand.highlighted
	if not highlighted or #highlighted == 0 then
		if G.hand then
			MPAPI.sendWarnMessage('[replay] play: no cards resolved out of ' .. #indices .. ' -- replay has desynced from the recording, skipping this play entirely')
		end
		return
	end
	G.FUNCS.play_cards_from_highlighted()
end)

MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.DISCARD, function(args, ctx)
	if not ctx.is_pov then
		return
	end
	local indices = args and args[1]
	if not indices then
		return
	end
	highlight_hand_indices(indices)
	local highlighted = G.hand and G.hand.highlighted
	if not highlighted or #highlighted == 0 then
		if G.hand then
			MPAPI.sendWarnMessage('[replay] discard: no cards resolved out of ' .. #indices .. ' -- replay has desynced from the recording, skipping this discard entirely')
		end
		return
	end
	G.FUNCS.discard_cards_from_highlighted(nil, false)
end)

MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.SELL, function(args, ctx)
	if ctx.is_pov then
		local area_id, idx = args and args[1], args and args[2]
		local area = area_object(area_id)
		local card = area and area.cards and area.cards[idx]
		if card then
			card:sell_card()
			SMODS.calculate_context({ selling_card = true, card = card })
		end
	else
		PVP.GAME.enemy.sells = (PVP.GAME.enemy.sells or 0) + 1
	end
end)

local function with_shop_ready(ctx, fn)
	MPAPI.playback.with_shop_ready(ctx, fn, PVP._playback_wait_for)
end

local function replay_buy(args, ctx)
	if not ctx.is_pov then
		return
	end
	with_shop_ready(ctx, function()
		local area_id, idx = args and args[1], args and args[2]
		local area = area_object(area_id)
		local card = area and area.cards and area.cards[idx]
		if card then
			G.FUNCS.buy_from_shop({ config = { id = MPAPI.playback.buy_button_id(card, args), ref_table = card } })
		end
	end)
end
MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.BUY, replay_buy)
MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.OPEN_PACK, replay_buy)
MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.VOUCHER, replay_buy)

MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.USE, function(args, ctx)
	if not ctx.is_pov then
		return
	end
	local idx, targets = args and args[1], args and args[2]
	local card = G.consumeables and G.consumeables.cards and G.consumeables.cards[idx]
	if not card then
		return
	end
	if targets then
		highlight_hand_indices(targets)
	end
	G.FUNCS.use_card({ config = { ref_table = card } })
end)

MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.PACK_PICK, function(args, ctx)
	if not ctx.is_pov then
		return
	end
	local idx, targets = args and args[1], args and args[2]
	local card = G.pack_cards and G.pack_cards.cards and G.pack_cards.cards[idx]
	if not card then
		return
	end
	if targets then
		highlight_hand_indices(targets)
	end
	G.FUNCS.use_card({ config = { ref_table = card } })
end)

MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.PACK_SKIP, function(_args, ctx)
	if ctx.is_pov then
		G.FUNCS.skip_booster({ config = {} })
	end
end)

MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.REROLL, function(_args, ctx)
	if ctx.is_pov then
		with_shop_ready(ctx, function()
			G.FUNCS.reroll_shop({ config = {} })
		end)
	end
end)

-- reorder's perm is "new-position -> old-index" (PVP.UTILS.reorder_permutation,
-- lib/card_utils.lua): new_cards[j] = old_cards[perm[j]]. Splicing the array
-- directly mirrors vanilla's own sort-button pattern (CardArea:sort just does
-- table.sort(self.cards,...) with no drag simulation, confirmed via research
-- against cardarea.lua) -- align_cards() re-derives visual position from
-- array order on its own next frame, so no explicit animation is needed here.
MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.REORDER, function(args, ctx)
	if not ctx.is_pov then
		return
	end
	local area_id, perm = args and args[1], args and args[2]
	local area = area_object(area_id)
	if not (area and perm) then
		return
	end
	local old_cards = area.cards
	-- PVP.UTILS.reorder_permutation only ever produces a perm when the
	-- recorder's own old/new card counts matched exactly, so any mismatch
	-- here means this replay has already desynced from the recording.
	-- Splicing anyway either writes nils into area.cards (old_cards shorter
	-- than perm) or silently drops every card beyond #perm (old_cards
	-- longer) -- same class of bug found and fixed in SPDRN's and MPAPI's
	-- own copies of this handler. Skip the whole opcode rather than corrupt
	-- the area.
	if not old_cards or #old_cards ~= #perm then
		return
	end
	local new_cards = {}
	for j = 1, #perm do
		new_cards[j] = old_cards[perm[j]]
	end
	area.cards = new_cards
	if area.set_ranks then area:set_ranks() end
end)

MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.READY_BLIND, function(args, ctx)
	if ctx.is_pov then
		PVP.GAME.ready_blind = (args == 1)
	end
	-- Non-POV: no live equivalent projects the opponent's ready state onto
	-- the HUD today (only via the lobby player-list, out of scope here).
end)

MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.SET_ANTE_KEY, function(args, ctx)
	if ctx.is_pov then
		PVP.GAME.ante_key = args
	end
	-- Non-POV: the ante-key itself has no display meaning for the opponent
	-- side (see functions.lua's own comment -- it's a dedup guard, not
	-- player-facing state), so nothing to project.
end)

-- hand_result is no longer a forcing mechanism -- with real card-level
-- replay, the real scoring engine already produces the real outcome from the
-- real cards played. This is now purely an integrity check: a mismatch means
-- a determinism assumption broke (wrong seed, mismatched mod/joker set --
-- manifest.mod_hash/smods_version exist precisely to detect this, though
-- surfacing that cleanly to the viewer isn't solved this pass).
MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.HAND_RESULT, function(args, ctx)
	if ctx.is_pov then
		local score_str = args and args[1]
		if score_str then
			local recorded = PVP.INSANE_INT.from_string(score_str)
			if not PVP.INSANE_INT.equal(recorded, PVP.GAME.score or PVP.INSANE_INT.empty()) then
				MPAPI.sendWarnMessage(
					'playback hand_result mismatch: recorded=' .. score_str
					.. ' real=' .. PVP.INSANE_INT.to_string(PVP.GAME.score or PVP.INSANE_INT.empty())
				)
			end
		end
	else
		project_enemy_hand_result(args)
	end
end)

-- The live round-eval total (overrides/game.lua's cash_out wrapper), kept for
-- the cashout that follows it.
local recorded_round_dollars = nil
MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.ROUND_DOLLARS, function(args, ctx)
	if ctx.is_pov then
		recorded_round_dollars = tonumber(type(args) == 'table' and args[1] or args)
	end
end)

MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.CASHOUT, function(_args, ctx)
	if ctx.is_pov then
		-- Pay what the live player was paid: playback runs as practice, with no
		-- referee life loss, so its own round eval misses the comeback bonus
		-- (and pays a blind no_gold_on_round_loss withheld). Recordings from
		-- before round_dollars existed keep the replay's own total.
		if recorded_round_dollars and G.GAME.current_round then
			G.GAME.current_round.dollars = recorded_round_dollars
		end
		recorded_round_dollars = nil
		G.FUNCS.cash_out({ config = {} })
	end
end)

-- Mod-specific joker opcodes (Pizza/Magnet) -- best-effort/deferred, see
-- AUTONOMOUS_DECISIONS.md. Bespoke per-joker handling, low priority vs. the
-- vanilla core loop above.
MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.NET_PIZZA, function(_args, _ctx) end)
MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.NET_MAGNET, function(_args, _ctx) end)

-- life_lost {lost, lives}: bookkeeping for the server's achievements (Mr Bones).
-- The lives themselves replay through the referee's own events.
MPAPI.playback.register_handler('pvp', MPAPI.OPCODE.LIFE_LOST, function(_args, _ctx) end)
