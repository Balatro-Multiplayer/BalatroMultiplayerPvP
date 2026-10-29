PVP.MOD_HASH = "0000"
PVP.MOD_STRING = ""

function hash(str)
	local str_to_hash = str or "0000"
	local hash = 0
	for i = 1, #str_to_hash do
		local char = string.byte(str_to_hash, i)
		hash = (hash * 31 + char) % 10000
	end
	return string.format("%04d", hash)
end

local function get_mod_data()
	local mod_table = {}
	for key, mod in pairs(SMODS.Mods) do
		if not mod.disabled and key ~= "Balatro" then table.insert(mod_table, key .. "-" .. (mod.version or "UNK")) end
	end
	for key, mod in pairs(PVP.INTEGRATIONS) do
		if mod then table.insert(mod_table, key .. "-MultiplayerIntegration") end
	end
	return mod_table
end

function PVP:generate_hash()
	local mod_data = get_mod_data()
	table.sort(mod_data)
	table.insert(mod_data, 1, "serversideConnectionID=" .. tostring(PVP.UTILS.server_connection_ID()))
	table.insert(mod_data, 1, "encryptID=" .. tostring(PVP.UTILS.encrypt_ID()))
	PVP.config.unlocked = PVP.UTILS.unlock_check()
	table.insert(mod_data, 1, "unlocked=" .. tostring(PVP.config.unlocked))
	table.insert(mod_data, 1, "preview=" .. tostring(PVP.config.integrations.Preview))
	local mod_string = table.concat(mod_data, ";")
	PVP.MOD_STRING = mod_string
	PVP.MOD_HASH = hash(mod_string) or "0000"
    if PVP.ACTIONS.set_username then
        PVP.ACTIONS.set_username(PVP.LOBBY.username)
    end
end

local hash_generated = false

local game_update_ref = Game.update
---@diagnostic disable-next-line: duplicate-set-field
function Game:update(dt)
	game_update_ref(self, dt)

	if not hash_generated and SMODS.booted then
		PVP:generate_hash()
		hash_generated = true
	end
end

function PVP.UTILS.unlock_check()
	local notFullyUnlocked = false

	for k, v in pairs(G.P_CENTER_POOLS.Joker) do
		if not v.unlocked then
			notFullyUnlocked = true
			break -- No need to keep checking once we know it's not fully unlocked
		end
	end

	return not notFullyUnlocked
end

function PVP.UTILS.encrypt_ID()
	local encryptID = 1
	for key, center in pairs(G.P_CENTERS or {}) do
		if type(key) == "string" and key:match("^j_") then
			if center.cost and type(center.cost) == "number" then encryptID = encryptID + center.cost end
			if center.config and type(center.config) == "table" then
				encryptID = encryptID + PVP.UTILS.sum_numbers_in_table(center.config)
			end
		elseif type(key) == "string" and key:match("^[cvp]_") then
			if center.cost and type(center.cost) == "number" then
				if center.cost == 0 then return 0 end
				encryptID = encryptID + center.cost
			end
		end
	end
	for key, value in pairs(G.GAME.starting_params or {}) do
		if type(value) == "number" and value % 1 == 0 then encryptID = encryptID * value end
	end
	local day = tonumber(os.date("%d")) or 1
	encryptID = encryptID * day
	local gameSpeed = G.SETTINGS.GAMESPEED
	if gameSpeed then
		gameSpeed = gameSpeed * 16
		gameSpeed = gameSpeed + 7
		encryptID = encryptID + (gameSpeed / 1000)
	else
		encryptID = encryptID + 0.404
	end
	return encryptID
end

-- Parses a semicolon-delimited hash string containing client configuration data
--
-- Input format: "encryptID=123456;unlocked=true;ModName1-1.0.0;ModName2-2.1.0;serversideConnectionID=abc123"
--
-- Returns:
--   config (table): Parsed configuration object with structure:
--     {
--       encryptID = number,     -- Client's encryption ID
--       unlocked = boolean,     -- Whether client has all content unlocked
--       Mods = table           -- Parsed mod list (see parse_modlist for structure)
--     }
--   mod_string (string): Semicolon-delimited string of mod entries only (for backward compatibility)
function PVP.UTILS.parse_Hash(hash)
	local parts = {}
	for part in string.gmatch(hash, "([^;]+)") do
		table.insert(parts, part)
	end

	local config = {
		encryptID = nil,
		unlocked = nil,
		Mods = {},
	}

	local mod_data = {}

	for _, part in ipairs(parts) do
		local key, val = string.match(part, "([^=]+)=([^=]+)")
		if key == "encryptID" then
			config.encryptID = tonumber(val)
		elseif key == "unlocked" then
			config.unlocked = val == "true"
		elseif key ~= "serversideConnectionID" then
			table.insert(mod_data, part)
		end
	end

	config.Mods = PVP.UTILS.parse_modlist(mod_data)
	-- this is for backwards compatibility
	-- We don't need to return mod_string anymore; can use config.Mods as a cleaner interface for the host/guest's mods
	-- and hash this in what we send to the server instead
	local mod_string = table.concat(mod_data, ";")

	return config, mod_string
end

-- Parses an array of mod entries into a mod table
--
-- Input: Array of mod entry strings: {"ModName1-1.0.0", "ModName2-2.1.0", "ModName3"}
--
-- Returns:
--   mods (table): Key-value pairs where:
--     - key = mod name (string)
--     - value = mod version (string) or nil if no version specified
--
-- Example output:
--   {
--     ModName1 = "1.0.0",
--     ModName2 = "2.1.0",
--     ModName3 = nil
--   }
function PVP.UTILS.parse_modlist(mod_entries)
	if not mod_entries then return {} end

	local mods = {}

	for _, mod_entry in ipairs(mod_entries) do
		local mod_name, mod_version

		-- Split on the LAST dash to handle mod names with dashes (e.g., "lovely-compat-trance-v0.0.0")
		mod_name, mod_version = string.match(mod_entry, "^(.-)%-([^%-]*)$")
		if not mod_name then
			-- No dash found, entire string is mod name
			mod_name = mod_entry
			mod_version = nil
		end

		mods[mod_name] = mod_version
	end

	return mods
end

function PVP.UTILS.resolve_mod_name_and_version(mod_name, mod_version)
    local fullname = mod_name .. "-" .. (mod_version or "")
    local new_mod_name, new_mod_version = fullname:match("^(.*)%-([^~]+~.*)$")
    mod_name = new_mod_name or mod_name
    mod_version = new_mod_version or mod_version
    return mod_name, mod_version
end

-- Other players in the current lobby whose MultiplayerPvP X.Y.Z differs from ours
-- (lib/version_gate.lua). Each is { player, our, their }.
function PVP.UTILS.version_mismatches()
	local lobby = MPAPI.get_current_lobby()
	if not lobby then
		return {}
	end
	return PVP.VersionGate.mismatches(PVP.version, lobby:get_players(), lobby.player_id)
end

-- The line shown for the first version mismatch, from our version and theirs.
function PVP.UTILS.version_mismatch_message(mismatch)
	return localize({ type = "variable", key = "k_version_mismatch", vars = { mismatch.their, mismatch.our } })
end

function PVP.UTILS.get_banned_mods(mods)
	local banned_mods = {}
	if not mods then return banned_mods end

	for mod_name, mod_version in pairs(mods) do
		local ban_info = PVP.BANNED_MODS[mod_name]
		local is_banned = false

		if ban_info then
			if type(ban_info) == "boolean" then
				-- Old format: ban all versions
				is_banned = ban_info
			elseif type(ban_info) == "string" then
				-- New format: ban specific version
				is_banned = (mod_version == ban_info)
			elseif type(ban_info) == "table" then
				-- Table format: ban multiple specific versions
				for _, banned_version in ipairs(ban_info) do
					if mod_version == banned_version then
						is_banned = true
						break
					end
				end
			end
		end

		if is_banned then table.insert(banned_mods, mod_name) end
	end

	return banned_mods
end

function PVP.UTILS.sum_numbers_in_table(t)
	local sum = 0
	for k, v in pairs(t) do
		if type(v) == "number" then
			sum = sum + v
		elseif type(v) == "table" then
			sum = sum + PVP.UTILS.sum_numbers_in_table(v)
		end
		-- ignore other types
	end
	return sum
end
