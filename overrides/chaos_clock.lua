-- Prototype is deliberately local Custom Solo only. Network/replay authority
-- and the production cadence budgets are NOT implemented by this lab.
local C = PVP.CHAOS

function C.available()
	return G and G.GAME and G.STAGE == G.STAGES.RUN and PVP.is_singleplayer() and not PVP.LOBBY.code
end

function C.safe_point()
	return C.available() and not G.CONTROLLER.locked and (G.STATE == G.STATES.BLIND_SELECT or G.STATE == G.STATES.SHOP)
end

local adapter = {}
C.adapter = adapter

function adapter.allowed(def)
	if not C.safe_point() then return false, "Use Custom Solo at blind selection or in a shop" end
	local point = G.STATE == G.STATES.SHOP and "shop" or "blind_select"
	if point ~= def.at then return false, "Requires " .. def.at end
	-- Manual resource layers record their actual adjustments in this ledger.
	-- This also covers Glass Cannon and resources inherited from rulesets.
	for _, applied in pairs(G.GAME.pvp_round_deltas or {}) do
		for field in pairs((def.payload or {}).round_deltas or {}) do
			if applied[field] ~= nil then return false, "Resource already owned by a manual layer" end
		end
	end
	for field in pairs((def.payload or {}).modifiers or {}) do
		if G.GAME.modifiers[field] ~= nil then return false, "Modifier already owned by a ruleset/layer" end
	end
	return true
end

function adapter.apply(payload)
	local game = G.GAME
	local receipt = { deltas = {}, modifiers = {} }
	for field, delta in pairs(payload.round_deltas or {}) do
		local before = game.round_resets[field]
		local after = math.max(field == "hands" and 1 or 0, before + delta)
		receipt.deltas[field] = after - before
		game.round_resets[field] = after
	end
	for field, value in pairs(payload.modifiers or {}) do
		receipt.modifiers[field] = {
			present = game.modifiers[field] ~= nil,
			value = game.modifiers[field],
			applied = value,
		}
		game.modifiers[field] = value
	end
	if payload.cash then ease_dollars(payload.cash, true) end
	return receipt
end

function adapter.remove(receipt)
	for field, delta in pairs(receipt.deltas) do
		-- Subtract our actual movement, not an old snapshot that would erase
		-- vouchers or other permanent changes earned during the window.
		G.GAME.round_resets[field] = math.max(field == "hands" and 1 or 0, G.GAME.round_resets[field] - delta)
	end
	for field, previous in pairs(receipt.modifiers) do
		-- Do not overwrite a later external writer's value.
		if G.GAME.modifiers[field] == previous.applied then
			if previous.present then
				G.GAME.modifiers[field] = previous.value
			else
				G.GAME.modifiers[field] = nil
			end
		end
	end
end

function C.for_run(create)
	if not C.available() then return nil end
	local game = G.GAME
	if not game.pvp_chaos and create then
		game.pvp_chaos = C.new_state(game.pseudorandom and game.pseudorandom.seed or "CHAOS")
	end
	if game.pvp_chaos then return C.runtime(game.pvp_chaos, adapter) end
end

function C.has_rule(rule)
	local runtime = C.for_run()
	if not runtime then return false end
	for _, instance in ipairs(runtime.state.active) do
		if (C.effects[instance.key].payload or {}).rule == rule then return true end
	end
	return false
end

local always_scores = SMODS.always_scores
function SMODS.always_scores(card)
	return C.has_rule("all_cards_score") or always_scores(card)
end

local calculate_context = SMODS.calculate_context
local function after_context(runtime, context, ...)
	if runtime and context.after then runtime:event("after_scoring", context) end
	return ...
end

function SMODS.calculate_context(context, ...)
	local runtime = C.for_run()
	if runtime and context.ending_shop then runtime:boundary("shop_end", tostring(G.GAME.round)) end
	return after_context(runtime, context, calculate_context(context, ...))
end

-- Keep blind rules through round evaluation so unused-resource payouts and
-- interest use the announced rule. Cash-out is the end of this window.
local cash_out = G.FUNCS.cash_out
function G.FUNCS.cash_out(...)
	local runtime = C.for_run()
	if runtime then runtime:boundary("blind_end", tostring(G.GAME.round)) end
	return cash_out(...)
end
