local ease_dollars_ref = ease_dollars
function ease_dollars(mod, instant)
	PVP.match_log("trace", string.format("Client sent message: action:moneyMoved,amount:%s", tostring(mod)))
	-- RLOG's money_delta opcode is now recorded once, generically, by
	-- BalatroMultiplayerAPI/api/replay/generic_codes.lua's own ease_dollars
	-- hook (wrapping the same underlying global) -- nothing left to do here.
	return ease_dollars_ref(mod, instant)
end

-- Certain Steamodded builds still call save_run while saving is disabled
-- In multiplayer runs this can crash when SMODS serializes transient hand data
local save_run_ref = save_run
function save_run(...)
	if G and G.F_NO_SAVING then return end
	return save_run_ref(...)
end

local sell_card_ref = Card.sell_card
function Card:sell_card()
	-- RLOG's sell opcode is now recorded once, generically, by
	-- BalatroMultiplayerAPI/api/replay/generic_codes.lua's own Card:sell_card
	-- hook (wrapping the same underlying method) -- nothing left to do here.
	-- The server counts my sells per ante; Taxes reads the opponent's from the view.
	if PVP.LOBBY.code then PVP.UI.run.sold() end
	return sell_card_ref(self)
end

-- generic_codes.lua's own G.FUNCS.cash_out hook records the cash out itself.
local cash_out_ref = G.FUNCS.cash_out
function G.FUNCS.cash_out(e)
	-- The blind-eval total actually paid. Part of it comes from the live match
	-- only (the comeback bonus after a life loss, no_gold_on_pvp_loss),
	-- which a replay or crash-rejoin fast-forward runs without; its cashout
	-- handler pays this instead (lib/playback_handlers.lua). Recorded here, the
	-- outer wrapper, so it lands just before MPAPI's own `cashout` event.
	if PVP.REPLAY.logging() and G.GAME.current_round then
		PVP.REPLAY.log.record(MPAPI.OPCODE.ROUND_DOLLARS, G.GAME.current_round.dollars or 0)
	end
	return cash_out_ref(e)
end

local reroll_shop_ref = G.FUNCS.reroll_shop
function G.FUNCS.reroll_shop(e)
	-- RLOG's reroll opcode is now recorded once, generically, by
	-- generic_codes.lua's own G.FUNCS.reroll_shop hook -- this override stays
	-- only for PvP's own reroll stats tracking below.

	-- Update reroll stats if in a multiplayer game
	if PVP.LOBBY.code and PVP.GAME.stats then
		PVP.GAME.stats.reroll_count = PVP.GAME.stats.reroll_count + 1
		PVP.GAME.stats.reroll_cost_total = PVP.GAME.stats.reroll_cost_total + G.GAME.current_round.reroll_cost
	end

	return reroll_shop_ref(e)
end

-- buy_from_shop/use_card/skip_booster/reorder(CardArea:update) had no
-- PvP-specific side effect beyond their own RLOG capture -- all four are now
-- covered purely by generic_codes.lua's own hooks (buy/open_pack/voucher,
-- use/pack_pick, pack_skip, reorder respectively), so those overrides are
-- removed entirely rather than kept as no-op pass-throughs.

-- Hook for end of pvp context (slightly scuffed)
local evaluate_round_ref = G.FUNCS.evaluate_round
G.FUNCS.evaluate_round = function()
	if G.after_pvp then
		G.after_pvp = nil
		SMODS.calculate_context({ mp_end_of_pvp = true })
	end
	local ok, err = pcall(function() PVP.NET.before_blind_eval() end)
	if not ok then sendWarnMessage("[inbox] blind evaluation: " .. tostring(err), "MULTIPLAYER") end
	evaluate_round_ref()
end
