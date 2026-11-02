-- Two-client scenario helpers. scripts/run_pair.sh launches a host and a guest on the
-- same scenario file; these build ordinary runner steps, so the MPAPI runner is unchanged.
local role = os.getenv("BMP_ROLE")
local dir = os.getenv("BMP_PAIR_DIR")
local other = ({ host = "guest", guest = "host" })[role]
assert(other and dir, "pair scenarios run under scripts/run_pair.sh")

local P = { role = role }

local function path(name)
	return dir .. "/" .. name
end

local function write(name, value)
	local file = assert(io.open(path(name), "w"))
	file:write(value or "")
	file:close()
end

local function read(name)
	local file = io.open(path(name), "r")
	if not file then return nil end
	local value = file:read("*a")
	file:close()
	return value
end

-- Values one side hands the other, e.g. a lobby code.
function P.put(key, value)
	write("value." .. key, tostring(value))
end

function P.get(key)
	return read("value." .. key)
end

-- A step only one side performs; the other passes straight through.
function P.only(who, step)
	if who == role then return step end
	return { wait = 0 }
end

-- Both sides wait here until the other arrives.
function P.sync(label, timeout)
	local arrived = false
	return {
		wait = 0,
		timeout = timeout or 60,
		until_ = function()
			if not arrived then
				write("sync." .. label .. "." .. role)
				arrived = true
			end
			return read("sync." .. label .. "." .. other) ~= nil
		end,
	}
end

-- TODO: the fields both clients must agree on. Key per-player fields by role
-- (lives_host, lives_guest), never mine/theirs, so the two lines compare byte for byte.
local function project()
	return {
		ante = G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante,
	}
end

local function encode(fields)
	local keys = {}
	for key in pairs(fields) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	for i, key in ipairs(keys) do
		keys[i] = key .. "=" .. tostring(fields[key])
	end
	return table.concat(keys, " ")
end

-- Logs this side's view; run_pair.sh diffs host against guest per label.
function P.snapshot(label)
	return {
		run = function()
			sendInfoMessage("BMP_SCENARIO STATE " .. label .. " " .. encode(project()), "MPAPI")
		end,
	}
end

return P
