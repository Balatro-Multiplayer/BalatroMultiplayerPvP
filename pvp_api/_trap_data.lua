-- What a trap tells the server when it goes off, by trap key. The server passes the record on as
-- sent (nakama/src/lobby/pvp/parts/traps.ts), so these names are the only agreement: the sender
-- (trap_reader.lua) builds the record from this table and the receiving handler (inbox_handlers.lua)
-- reads it with the same table. Pure: plain values in, plain values out.
local data = {}
PVP.trap_data = data

-- The server's cap on a record (MAX_FIRE_DATA_SIZE), in bytes of its JSON text.
local MOST_SIZE = 1024

local TEXT = { kind = "text" }
local WHOLE = { kind = "whole" }
local MAYBE_TEXT = { kind = "text", optional = true }
-- Only the sender names it. The receiver is the owner, and the server's Arcane Lock bounce sends none.
local OWNER = { kind = "text", sender_only = true }

-- Every record the sender builds names the trap's owner: an empty Lua table is sent as []
-- and the server refuses a record that is not an object.
local function fields(own)
	own.owner = OWNER
	return own
end

data.FIELDS = {
	c_mp_trap_glyph_of_warding = fields({}),
	c_mp_trap_symbol = fields({}),
	c_mp_trap_alarm = fields({ rerolls = WHOLE }),
	c_mp_trap_explosive_runes = fields({}),
	c_mp_trap_sepia_snake_sigil = fields({ key = TEXT }),
	c_mp_trap_fire_trap = fields({}),
	c_mp_trap_guards_and_wards = fields({}),
	c_mp_trap_magic_mouth = fields({ card = TEXT }),
	c_mp_trap_snare = fields({ tag_key = MAYBE_TEXT, orbital_hand = MAYBE_TEXT }),
	c_mp_trap_arcane_lock = fields({}),
	c_mp_trap_programmed_illusion = fields({}),
	c_mp_trap_web = fields({ key = TEXT, set = TEXT }),
	c_mp_trap_forbiddance = fields({}),
	c_mp_trap_faithful_hound = fields({ hand_type = TEXT }),
	c_mp_trap_phase_door = fields({ dollars = WHOLE }),
	c_mp_trap_mental_prison = fields({}),
}

local function fits(spec, value)
	if spec.kind == "text" then return type(value) == "string" and value ~= "" end
	return PVP.view.whole(value, 1)
end

-- The fields as plain values, or nil and what is wrong. Only the fields of the table are kept; a
-- missing field is fine only where the table says it may be. Fields only the sender names are
-- skipped when receiving.
-- direction: "sent" or "received".
local function check(trap_key, record, direction)
	local wanted = data.FIELDS[trap_key]
	if not wanted then return nil, "no data fields for the trap " .. tostring(trap_key) end
	if type(record) ~= "table" then return nil, "the trap data must be a table" end
	local out = {}
	for name, spec in pairs(wanted) do
		if not (direction == "received" and spec.sender_only) then
			local value = record[name]
			if value ~= nil then
				if not fits(spec, value) then return nil, "data." .. name .. " must be a " .. spec.kind end
				out[name] = value
			elseif not spec.optional then
				return nil, "data." .. name .. " is missing"
			end
		end
	end
	return out
end

-- What the sender has: every field the trap names, the owner too.
function data.checked(trap_key, record)
	return check(trap_key, record, "sent")
end

-- What the owner's inbox item carries: the trap's own fields, which may be none.
function data.received(trap_key, record)
	return check(trap_key, record, "received")
end

-- The size of the record as the server counts it: its JSON text, with a quote or backslash as two bytes.
local function json_size(values)
	local size, count = 2, 0
	for name, value in pairs(values) do
		count = count + 1
		local text = type(value) == "string" and value or string.format("%.0f", value)
		local _, escaped = text:gsub('[\\"]', "")
		size = size + #name + 3 + #text + escaped + (type(value) == "string" and 2 or 0)
	end
	return size + math.max(count - 1, 0)
end

-- What goes in the fire input: the checked fields, and nil with why when the server would refuse them.
function data.build(trap_key, values)
	local record, problem = data.checked(trap_key, values)
	if not record then return nil, problem end
	if json_size(record) > MOST_SIZE then return nil, "the trap data is over " .. MOST_SIZE .. " bytes" end
	return record
end

return data
