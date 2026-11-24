-- The run-side inputs (progress, blind results, skips, sells, shops, vouchers, effect cards) and the
-- opponent's run shown from the net's view (run_reader.lua decides). Each sender is called from the
-- place in the game where the thing happens and sends once. Nothing here changes my run: an effect card
-- reaches the other player through their inbox only (inbox_handlers.lua).
local screen = {}
PVP.run_screen = screen

local function net()
	return PVP.match_net
end

local function send(kind, body)
	return net().send_live(kind, body)
end

-- One counted input: the run total under `key` goes up only when the input was sent. `build(total)`
-- makes the body.
local function send_counted(key, kind, build)
	return (PVP.run_totals.count_sent(G.GAME and G.GAME.pvp_net, key, function(total)
		return send(kind, build(total))
	end))
end

local function ante()
	return G.GAME.round_resets.ante
end

local function send_progress(new_ante, location)
	return send("progress", PVP.run_reader.progress(new_ante, location))
end

function screen.progress(location)
	return send_progress(ante(), location)
end

-- The ante I am about to be in, with the location I last reported; nothing while that is unknown.
function screen.ante_changed(new_ante)
	return send_progress(new_ante, PVP.GAME.location_full)
end

function screen.blind_result(blind, result)
	return send("blindResult", PVP.run_reader.blind_result(ante(), blind, result))
end

-- The server records a skipped blind as skipped, and it has no shop: that shop counts as spent 0.
function screen.skipped(blind)
	send("skip", PVP.run_reader.skip(ante(), blind, G.GAME.skips))
	screen.shop_closed(0)
end

function screen.sold()
	local at = ante()
	return send_counted("sell:" .. at, "sell", function(total) return PVP.run_reader.sell(at, total) end)
end

function screen.shop_closed(spent)
	local at = ante()
	return send_counted("shop", "shop", function(total) return PVP.run_reader.shop(at, total, spent) end)
end

function screen.voucher_redeemed(voucher_key)
	return send("voucher", PVP.run_reader.voucher(voucher_key))
end

-- "asteroid", "pizza" or "gambling": one card played.
function screen.effect(effect)
	return send_counted("effect:" .. tostring(effect), "effect", function(total) return PVP.run_reader.effect(effect, total) end)
end

-- What I show of the opponent's run, once per change in the view. The location goes through the same
-- enemyLocation the ready feed uses.
local shown = { facts = nil, id = nil, lives_guess = "none" }
local shown_for

local function show(name, value, before)
	local enemy = PVP.GAME.enemy
	if name == "skips" and PVP.run_reader.skips_gained(before, value) and not PVP.current_ruleset().enemy_location_disabled then
		play_sound("negative", 0.865, 0.4)
		play_sound("gong", 0.765, 0.4)
	end
	if name == "lives" then
		if PVP.OPPONENT_SIGNALS.lives_dropped(enemy.lives, value) then
			PVP.OPPONENT_SIGNALS.play_life_lost()
			if PVP.UI.juice_up_pvp_hud then PVP.UI.juice_up_pvp_hud() end
		end
		enemy.lives = value
	elseif name == "sells" then
		enemy.sells_per_ante = value
	elseif name == "shop_spends" then
		enemy.spent_in_shop = value
	elseif name == "location" then
		if value and not PVP.current_ruleset().enemy_location_disabled then
			PVP.game_effects.show_enemy_location(value)
		end
	else
		enemy[name] = value
	end
end

function screen.update()
	local view = PVP.view.game(net().view)
	if not (view and PVP.GAME and PVP.GAME.enemy) then
		shown.facts = nil
		return
	end
	local table_is = shown_for ~= PVP.GAME.enemy and "new" or "same"
	shown_for = PVP.GAME.enemy
	local decision = PVP.run_reader.opponent_shown(shown, view, table_is)
	if decision.reset ~= "keep" then PVP.GAME.enemy.lives = nil end
	for _, change in ipairs(decision.show) do
		show(change.name, change.value, change.before)
	end
	shown = decision.next
end


return screen
