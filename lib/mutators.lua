-- Manual house rules share MPAPI's layers and modifier list. The editor keeps
-- its draft separate so opening or cancelling it cannot change another session.
PVP.MUTATORS = {}
PVP.MutatorCategory = {
	ECONOMY = "economy",
	MAYHEM = "mayhem",
	HAZARDS = "hazards",
	CHAOS = "chaos",
	RESOURCES = "resources",
	BALANCE = "balance",
	CONTENT = "content",
}
PVP.MUTATOR_CATEGORIES = {
	PVP.MutatorCategory.ECONOMY,
	PVP.MutatorCategory.MAYHEM,
	PVP.MutatorCategory.HAZARDS,
	PVP.MutatorCategory.CHAOS,
	PVP.MutatorCategory.RESOURCES,
	PVP.MutatorCategory.BALANCE,
	PVP.MutatorCategory.CONTENT,
}

function PVP.Mutator(key, category, order)
	assert(not PVP.MUTATORS[key], "Duplicate mutator: " .. key)
	PVP.MUTATORS[key] = { key = key, category = category, order = order }
end

function PVP.mutators_in(category)
	local result = {}
	for _, definition in pairs(PVP.MUTATORS) do
		if definition.category == category then result[#result + 1] = definition end
	end
	table.sort(result, function(a, b)
		if a.order ~= b.order then return a.order < b.order end
		return a.key < b.key
	end)
	return result
end

-- Resource changes are relative to the deck/stake, not replacement starting
-- values. Save the actual clamped movement to make repeated setup idempotent.
function PVP.apply_round_deltas(key, deltas)
	if not PVP.in_session() then return end
	local game = G.GAME
	game.pvp_round_deltas = game.pvp_round_deltas or {}
	if game.pvp_round_deltas[key] then return end
	local applied = {}
	for field, delta in pairs(deltas) do
		local floor = field == "hands" and 1 or 0
		local before = game.round_resets[field]
		applied[field] = math.max(floor, before + delta) - before
		game.round_resets[field] = before + applied[field]
	end
	game.pvp_round_deltas[key] = applied
end
