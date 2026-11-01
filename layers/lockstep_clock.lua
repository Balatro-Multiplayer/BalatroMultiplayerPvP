-- Lockstep clock layer: game adapter for lib/lockstep.lua.
--
-- * maps G.STATE onto lockstep phases / turns (see the diagram in lib/lockstep.lua)
-- * ticks the clock only while the player can actually act
-- * telegraphs the last few seconds (cards jitter harder, countdown goes red)
-- * on timeout, rolls PVP.Lockstep.TIMEOUTS and lets chaos make the decision
--
-- Network seam: the barrier itself lives in the referee. This layer only needs
-- two signals, exposed as PVP.Lockstep.signal_ready / signal_others_ready.
-- Blind readiness is wired to PVP.GAME.ready_blind already; shop / cash-out
-- "others are done" still needs a referee broadcast (TODO: pvp_lockstep_ready).

MPAPI.Layer("lockstep_clock", {})

local L = PVP.Lockstep
local P = L.PHASE

local STATE = {} -- adapter-local runtime state
PVP.LOCKSTEP_STATE = STATE

local function reset()
	if STATE.ui then STATE.ui:remove() end
	for k in pairs(STATE) do
		STATE[k] = nil
	end
end

-- ---------------------------------------------------------------------------
-- signals (call from networking)
-- ---------------------------------------------------------------------------
function L.signal_ready(ready)
	if STATE.clock then STATE.clock:set_ready(ready) end
end

function L.signal_others_ready(ready)
	if STATE.clock then STATE.clock:set_others_ready(ready) end
end

-- ---------------------------------------------------------------------------
-- helpers
-- ---------------------------------------------------------------------------
local function rng(n)
	return pseudorandom("mp_lockstep_timeout", 1, n)
end

local function shuffled(list, key)
	local out = {}
	for i, v in ipairs(list) do
		out[i] = v
	end
	pseudoshuffle(out, pseudoseed(key))
	return out
end

-- press a UI button the way a click would, so mod overrides of the
-- button's G.FUNCS (e.g. pvp_ready_button -> mp_toggle_ready) still apply
local function press(uie)
	if uie and uie.config and uie.config.button and G.FUNCS[uie.config.button] then
		G.FUNCS[uie.config.button](uie)
		return true
	end
	return false
end

local function close_overlay()
	if G.OVERLAY_MENU then G.FUNCS.exit_overlay_menu() end
end

local function cards_of(...)
	local out = {}
	for _, area in ipairs({ ... }) do
		if area and area.cards then
			for _, c in ipairs(area.cards) do
				out[#out + 1] = c
			end
		end
	end
	return out
end

local function spendable()
	return G.GAME.dollars - G.GAME.bankrupt_at
end

local function affordable_shop_cards()
	local out = {}
	-- boosters are excluded on purpose: no chaos-inside-chaos pack chains
	for _, c in ipairs(cards_of(G.shop_jokers, G.shop_vouchers)) do
		if c.cost <= spendable() then
			if c.ability.set == "Voucher" or G.FUNCS.check_for_buy_space(c) then out[#out + 1] = c end
		end
	end
	return out
end

-- is this pack card something chaos can take right now?
local function pack_pickable(c)
	if c.ability.consumeable then
		if c:can_use_consumeable() then return true end
		-- targeting consumables (tarots etc.) get a random target set at pick time
		local max = c.ability.consumeable.max_highlighted
		return max and G.hand and #G.hand.cards > 0
	end
	if c.ability.set == "Joker" then return #G.jokers.cards < G.jokers.config.card_limit end
	return true -- playing cards (standard packs)
end

local function pickable_pack_cards()
	local out = {}
	for _, c in ipairs(cards_of(G.pack_cards)) do
		if pack_pickable(c) then out[#out + 1] = c end
	end
	return out
end

-- ---------------------------------------------------------------------------
-- timeout executors
-- ---------------------------------------------------------------------------
local function random_selection(limit_key)
	G.hand:unhighlight_all() -- keeps forced selections (cerulean bell)
	local already = #G.hand.highlighted
	local limit = math.min(5, G.hand.config.highlighted_limit or 5, #G.hand.cards)
	local want = math.max(already, pseudorandom("mp_lockstep_" .. limit_key, 1, limit))
	local pool = {}
	for _, c in ipairs(G.hand.cards) do
		if not c.highlighted then pool[#pool + 1] = c end
	end
	for _, c in ipairs(shuffled(pool, "mp_lockstep_cards")) do
		if #G.hand.highlighted >= want then break end
		G.hand:add_to_highlighted(c, true)
	end
end

local EXEC = {
	take_blind = function()
		if PVP.GAME.ready_blind then return end -- already readied; pressing would unready
		local opts = G.blind_select_opts and G.blind_select_opts[string.lower(G.GAME.blind_on_deck or "")]
		press(opts and opts:get_UIE_by_ID("select_blind_button"))
	end,

	random_hand = function()
		random_selection("hand")
		G.FUNCS.play_cards_from_highlighted()
	end,

	random_discard = function()
		random_selection("discard")
		G.FUNCS.discard_cards_from_highlighted()
	end,

	cash_out = function()
		local btn = G.round_eval and G.round_eval:get_UIE_by_ID("cash_out_button")
		if not press(btn) then G.FUNCS.cash_out({ config = {} }) end
	end,

	leave_shop = function()
		G.FUNCS.toggle_shop()
	end,

	impulse_buy = function()
		local pool = affordable_shop_cards()
		if #pool > 0 then
			local c = pseudorandom_element(pool, pseudoseed("mp_lockstep_buy"))
			local e = { config = { ref_table = c } }
			if c.ability.set == "Voucher" then
				G.FUNCS.use_card(e)
			else
				G.FUNCS.buy_from_shop(e)
			end
		end
		-- leave after the buy animation settles
		G.E_MANAGER:add_event(Event({
			trigger = "after",
			delay = 1.2,
			func = function()
				if G.STATE == G.STATES.SHOP then G.FUNCS.toggle_shop() end
				return true
			end,
		}))
	end,

	random_pick = function()
		local pool = pickable_pack_cards()
		if #pool == 0 then return G.FUNCS.skip_booster() end
		local c = pseudorandom_element(pool, pseudoseed("mp_lockstep_pick"))
		local cons = c.ability.consumeable
		if cons and cons.max_highlighted and not c:can_use_consumeable() then
			G.hand:unhighlight_all()
			local n = pseudorandom("mp_lockstep_targets", cons.min_highlighted or 1, cons.max_highlighted)
			for _, h in ipairs(shuffled(G.hand.cards, "mp_lockstep_target_cards")) do
				if #G.hand.highlighted >= n then break end
				G.hand:add_to_highlighted(h, true)
			end
			if not c:can_use_consumeable() then
				G.hand:unhighlight_all()
				return G.FUNCS.skip_booster()
			end
		end
		G.FUNCS.use_card({ config = { ref_table = c } })
	end,

	skip_pack = function()
		G.FUNCS.skip_booster()
	end,
}
L.EXEC = EXEC

local function timeout_ctx(phase)
	if phase == P.ROUND then
		return {
			hands_left = G.GAME.current_round.hands_left,
			discards_left = G.GAME.current_round.discards_left,
		}
	elseif phase == P.SHOP then
		return { affordable = #affordable_shop_cards() }
	elseif phase == P.PACK then
		return { pickable = #pickable_pack_cards() }
	end
	return {}
end

local function fire(phase, retry)
	close_overlay()
	local key = L.pick_timeout(phase, timeout_ctx(phase), rng)
	if not key or not EXEC[key] then return end
	if not retry then
		play_sound("tarot1", 0.9, 0.8)
		attention_text({
			text = localize("k_mp_lockstep_chaos"),
			scale = 1.3,
			hold = 1.2,
			major = G.play,
			align = "cm",
			offset = { x = 0, y = -2.7 },
			backdrop_colour = G.C.RED,
			silent = true,
		})
	end
	sendDebugMessage("lockstep timeout: " .. phase .. " -> " .. key, "MULTIPLAYER")
	local ok, err = pcall(EXEC[key])
	if not ok then sendWarnMessage("lockstep timeout " .. key .. " failed: " .. tostring(err), "MULTIPLAYER") end
end

-- ---------------------------------------------------------------------------
-- G.STATE -> phase mapping
-- ---------------------------------------------------------------------------
-- built lazily: G.STATES is only guaranteed once the game is up
local PACK_STATES, TOP_LEVEL
local function state_tables()
	if PACK_STATES then return end
	PACK_STATES = {}
	for _, name in ipairs({
		"TAROT_PACK",
		"PLANET_PACK",
		"SPECTRAL_PACK",
		"STANDARD_PACK",
		"BUFFOON_PACK",
		"SMODS_BOOSTER_OPENED",
	}) do
		if G.STATES[name] then PACK_STATES[G.STATES[name]] = true end
	end
	TOP_LEVEL = {
		[G.STATES.BLIND_SELECT] = P.BLIND_SELECT,
		[G.STATES.SELECTING_HAND] = P.ROUND,
		[G.STATES.ROUND_EVAL] = P.CASH_OUT,
		[G.STATES.SHOP] = P.SHOP,
	}
end

local function sync_phase(clock)
	state_tables()
	local s = G.STATE
	local top = clock:current()

	if s == G.STATES.GAME_OVER then
		clock:stop()
	elseif PACK_STATES[s] then
		if not (top and top.phase == P.PACK) then clock:enter(P.PACK) end
	elseif TOP_LEVEL[s] then
		local phase = TOP_LEVEL[s]
		if top and top.phase == P.PACK then
			clock:exit() -- back from a pack into its parent
			top = clock:current()
		end
		if not top or top.phase ~= phase then
			clock:enter(phase)
		elseif phase == P.ROUND and STATE.drew_since_turn then
			clock:turn() -- next hand
		end
		if phase == P.ROUND then STATE.drew_since_turn = false end
	elseif s == G.STATES.DRAW_TO_HAND or s == G.STATES.HAND_PLAYED then
		-- only a real play/discard starts a new turn; using a tarot mid-round
		-- (PLAY_TAROT -> SELECTING_HAND) must not refill anything
		STATE.drew_since_turn = true
	end
end

local function can_tick()
	return G.STATE_COMPLETE and not G.CONTROLLER.locked and not (G.CONTROLLER.locks and next(G.CONTROLLER.locks))
end

-- ---------------------------------------------------------------------------
-- telegraph
-- ---------------------------------------------------------------------------
local function telegraph_targets(phase)
	if phase == P.ROUND then return cards_of(G.hand) end
	if phase == P.SHOP then return cards_of(G.shop_jokers, G.shop_vouchers, G.shop_booster) end
	if phase == P.PACK then return cards_of(G.pack_cards) end
	return {}
end

local function telegraph_boxes(phase)
	if phase == P.BLIND_SELECT and G.blind_select_opts then
		local o = G.blind_select_opts[string.lower(G.GAME.blind_on_deck or "")]
		return o and { o } or {}
	end
	if phase == P.CASH_OUT and G.round_eval then return { G.round_eval } end
	return {}
end

local function run_telegraph(clock, dt)
	local t = clock:telegraph()
	STATE.intensity = t
	if t <= 0 then
		STATE.jitter_in, STATE.last_tick = nil, nil
		return
	end
	-- jitter cadence: 0.5s apart at the start of the window, 0.12s at the end
	STATE.jitter_in = (STATE.jitter_in or 0) - dt
	if STATE.jitter_in <= 0 then
		STATE.jitter_in = 0.5 - 0.38 * t
		local scale, rot = 0.04 + 0.16 * t, 0.02 + 0.1 * t
		local targets = telegraph_targets(clock:phase())
		-- more of the cards join in as it gets closer
		local n = math.max(1, math.ceil(#targets * (0.3 + 0.7 * t)))
		for i, c in ipairs(shuffled(targets, "mp_lockstep_jitter")) do
			if i > n then break end
			c:juice_up(scale, rot)
		end
		for _, box in ipairs(telegraph_boxes(clock:phase())) do
			box:juice_up(scale * 0.5, rot * 0.3)
		end
	end
	-- one tick sound per whole second, rising pitch
	local sec = math.ceil(clock:remaining())
	if sec ~= STATE.last_tick and sec > 0 then
		STATE.last_tick = sec
		play_sound("tarot2", 0.8 + 0.25 * t, 0.4 + 0.3 * t)
	end
end

-- ---------------------------------------------------------------------------
-- ui: bank always visible, countdown takes over when telegraphing
-- ---------------------------------------------------------------------------
local function build_ui()
	STATE.display = { text = "" }
	STATE.ui = UIBox({
		definition = {
			n = G.UIT.ROOT,
			config = { align = "cm", colour = G.C.CLEAR, padding = 0.1 },
			nodes = {
				{
					n = G.UIT.O,
					config = {
						func = "mp_lockstep_ui",
						object = DynaText({
							scale = 0.7,
							string = { { ref_table = STATE.display, ref_value = "text" } },
							colours = { G.C.WHITE },
							shadow = true,
							silent = true,
							pop_in = 0,
						}),
					},
				},
			},
		},
		config = { align = "cm", offset = { x = 0.3, y = -2.9 }, major = G.deck },
	})
end

G.FUNCS.mp_lockstep_ui = function(e)
	local obj = e.config.object
	if not obj or not STATE.clock then return end
	local t = STATE.intensity or 0
	obj.colours[1] = t > 0 and G.C.RED or G.C.WHITE
	obj.scale = 0.7 + 0.35 * t + (t > 0 and 0.05 * math.sin(G.TIMERS.REAL * (6 + 14 * t)) or 0)
end

local function refresh_display(clock)
	if not STATE.display then return end
	local f = clock:current()
	if not f then
		STATE.display.text = ""
	elseif (STATE.intensity or 0) > 0 then
		STATE.display.text = string.format("%.1f", clock:remaining())
	elseif f.ready then
		STATE.display.text = localize("k_mp_lockstep_waiting")
	else
		STATE.display.text = tostring(math.floor(clock.bank))
	end
end

-- ---------------------------------------------------------------------------
-- main loop
-- ---------------------------------------------------------------------------
local game_update_ref = Game.update
function Game:update(dt)
	game_update_ref(self, dt)
	if not (G.STAGE == G.STAGES.RUN and PVP.is_layer_active("lockstep_clock")) then
		if STATE.clock then reset() end
		return
	end
	if not STATE.clock then
		STATE.clock = L.new()
		build_ui()
	end
	local clock = STATE.clock

	sync_phase(clock)
	if clock:phase() == P.BLIND_SELECT then clock:set_ready(PVP.GAME.ready_blind) end

	for _, ev in ipairs(clock:update(dt, can_tick())) do
		if ev.type == "warn" then
			play_sound("timpani", 0.9, 0.7)
		elseif ev.type == "timeout" then
			fire(ev.phase, ev.retry)
		end
	end
	run_telegraph(clock, dt)
	refresh_display(clock)
end
