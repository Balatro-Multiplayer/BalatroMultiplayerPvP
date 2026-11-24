-- The trap inputs and what the view says of my traps. Pure: plain values in, plain values out, no
-- game and no net. pvp_api/ui/trap.lua is the shell that sends and shows. Every body builder answers
-- nil for a value of the wrong shape, so nothing malformed is sent; the server owns the limits.
local reader = {}
PVP.READ.trap = reader
local trap_data = PVP.READ.trap_record

local STATES = { live = true, lost = true, fired = true }

local function text(value)
	return type(value) == "string" and value ~= ""
end

-- total is the traps of this key planted this run, this one included.
function reader.plant(key, total)
	if not (text(key) and key:sub(1, 5) == "c_mp_" and PVP.READ.view.whole(total, 1)) then return nil end
	return { key = key, total = total }
end

-- values are the fields the firing trap names (pvp_api/read/_trap_record.lua); nil with why when it cannot be sent.
function reader.fire(trap_number, trap_key, values)
	if not PVP.READ.view.whole(trap_number, 1) then return nil, "the trap has no number from the server" end
	local record, problem = trap_data.build(trap_key, values)
	if not record then return nil, problem end
	return { trapId = trap_number, data = record }
end

function reader.lost(trap_number)
	if not PVP.READ.view.whole(trap_number, 1) then return nil end
	return { trapId = trap_number }
end


-- My traps as the view lists them (the ones I planted and the ones I hold), or nil when the view has
-- no list. A trap that is not whole in the view is left out: unknown.
function reader.traps(view)
	local list = view and view.onlyMine and view.onlyMine.traps
	if type(list) ~= "table" then return nil end
	local out = {}
	for _, trap in ipairs(list) do
		if
			type(trap) == "table"
			and PVP.READ.view.whole(trap.id, 1)
			and text(trap.key)
			and text(trap.owner)
			and text(trap.holder)
			and STATES[trap.state]
		then
			out[#out + 1] = { id = trap.id, key = trap.key, owner = trap.owner, holder = trap.holder, state = trap.state }
		end
	end
	return out
end

-- What my own consumables must do to match the traps I hold. cards are the trap cards there as
-- { id, fired }; is_gone(id) says a trap has already gone off or been lost here. add: traps I hold
-- that have no card yet. reveal: traps the server says have gone off (an Arcane Lock that bounced a
-- card) whose card has not.
function reader.reconcile(traps, me, cards, is_gone)
	local present = {}
	for _, card in ipairs(cards) do present[card.id] = card end
	local add, reveal = {}, {}
	for _, trap in ipairs(traps) do
		local card = present[trap.id]
		if trap.holder == me and not is_gone(trap.id) then
			if trap.state == "live" and not card then add[#add + 1] = trap end
			if trap.state == "fired" and card and not card.fired then reveal[#reveal + 1] = trap.id end
		end
	end
	return { add = add, reveal = reveal }
end

-- The traps I planted that the players next to me hold: shown, the live ones; fired, a set of the
-- numbers of those that have gone off.
function reader.row(traps, me, nearby)
	local near = {}
	for _, player in ipairs(nearby) do near[player] = true end
	local shown, fired = {}, {}
	for _, trap in ipairs(traps or {}) do
		if trap.owner == me and near[trap.holder] then
			if trap.state == "live" then shown[#shown + 1] = trap end
			if trap.state == "fired" then fired[trap.id] = true end
		end
	end
	return { shown = shown, fired = fired }
end

-- Changes whenever a trap is added or changes who holds it or its state.
function reader.signature(traps)
	local parts = {}
	for _, trap in ipairs(traps or {}) do
		parts[#parts + 1] = trap.id .. ":" .. trap.holder .. ":" .. trap.state
	end
	return table.concat(parts, "|")
end

return reader
