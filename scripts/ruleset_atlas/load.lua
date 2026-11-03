-- Loads the real gamemode, layer, ruleset and object files outside the game and
-- records what they register. Nothing here runs a card's game logic: every global
-- the files touch at load time that the game would provide is a stub that soaks up
-- reads, calls and arithmetic, so only the registrations themselves come out.
--
-- Usage: local world = dofile("scripts/ruleset_atlas/load.lua")(pvp_dir, api_dir)

return function(pvp_dir, api_dir)
	pvp_dir = pvp_dir or "./"
	api_dir = api_dir or "../BalatroMultiplayerAPI/"
	if pvp_dir:sub(-1) ~= "/" then pvp_dir = pvp_dir .. "/" end
	if api_dir:sub(-1) ~= "/" then api_dir = api_dir .. "/" end

	-- ------------------------------------------------------------------
	-- The stub: any field, call, or operator on it gives back a stub.
	-- ------------------------------------------------------------------
	local stub_mt = {}
	local function stub()
		return setmetatable({}, stub_mt)
	end
	stub_mt.__index = function(t, k)
		local s = stub()
		rawset(t, k, s)
		return s
	end
	stub_mt.__call = function() return stub() end
	stub_mt.__concat = function() return "" end
	stub_mt.__tostring = function() return "<stub>" end
	for _, op in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm" }) do
		stub_mt[op] = function() return 0 end
	end
	stub_mt.__lt = function() return false end
	stub_mt.__le = function() return false end
	stub_mt.__len = function() return 0 end

	local function is_stub(v) return type(v) == "table" and getmetatable(v) == stub_mt end

	local world = {
		content = {}, -- full key -> { key, set, file, mp_include, no_collection, ... }
		content_order = {},
		reworks = {}, -- { key, layers = {...}, file, fields = {...} }
		rulesets = {}, -- full key -> resolved ruleset table
		ruleset_order = {},
		ruleset_files = {},
		layer_files = {},
		layer_order = {},
		raw_layers = {}, -- name -> a shallow copy of the definition as registered
		gamemodes = {}, -- full key -> { key, file, init }
		isolation_gates = {},
		load_errors = {},
		current_file = nil,
	}

	-- ------------------------------------------------------------------
	-- SMODS: every class call records the registration.
	-- ------------------------------------------------------------------
	-- Class -> the key prefix SMODS gives this mod's objects (manifest prefix "mp").
	local CLASS_PREFIX = {
		Joker = "j",
		Consumable = "c",
		Tag = "tag",
		Voucher = "v",
		Enhancement = "m",
		Blind = "bl",
		Back = "b",
		Stake = "stake",
		Edition = "e",
		Booster = "p",
		Seal = false, -- seals key as "mp_<key>"
		Sticker = false,
		Challenge = "c",
	}
	local RECORDED_SET = {
		Joker = "Joker",
		Consumable = nil, -- taken from init.set
		Tag = "Tag",
		Voucher = "Voucher",
		Enhancement = "Enhanced",
		Blind = "Blind",
		Back = "Back",
		Stake = "Stake",
		Edition = "Edition",
		Booster = "Booster",
		Seal = "Seal",
		Sticker = "Sticker",
		Challenge = "Challenge",
	}

	local function full_key(class, init)
		local key = init.key
		if type(key) ~= "string" then return nil end
		local pc = init.prefix_config
		local skip_mod = (pc == false) or (type(pc) == "table" and pc.key == false) or init.raw_key
		local class_prefix = CLASS_PREFIX[class]
		if skip_mod then
			if class_prefix and not key:find("^" .. class_prefix .. "_") then return class_prefix .. "_" .. key end
			return key
		end
		-- SMODS.modify_key adds each prefix only when the key doesn't already start with it.
		local function with(prefix, k)
			if k:sub(1, #prefix + 1) == prefix .. "_" then return k end
			return prefix .. "_" .. k
		end
		if class_prefix == nil then return key end
		key = with("mp", key)
		if class_prefix == false then return key end
		return with(class_prefix, key)
	end

	local function shallow(t)
		local c = {}
		for k, v in pairs(t) do c[k] = v end
		return c
	end

	local function record(class, init)
		if type(init) ~= "table" then return stub() end
		local set = RECORDED_SET[class] or (class == "Consumable" and init.set) or class
		local key = full_key(class, init)
		if key and CLASS_PREFIX[class] ~= nil then
			local entry = {
				key = key,
				class = class,
				set = type(set) == "string" and set or class,
				file = world.current_file,
				has_mp_include = type(init.mp_include) == "function",
				no_collection = init.no_collection == true,
				rarity = type(init.rarity) == "number" and init.rarity or nil,
				cost = type(init.cost) == "number" and init.cost or nil,
				credits = type(init.mp_credits) == "table" and init.mp_credits or nil,
				init = init,
			}
			if world.content[key] then
				world.load_errors[#world.load_errors + 1] =
					("duplicate registration %s (%s and %s)"):format(key, world.content[key].file, world.current_file)
			else
				world.content_order[#world.content_order + 1] = key
			end
			world.content[key] = entry
		end
		local obj = stub()
		for k, v in pairs(init) do rawset(obj, k, v) end
		return obj
	end

	local smods_class_mt = {
		__call = function(self, init) return record(self.__class, init) end,
		__index = function(self, k)
			local s = stub()
			rawset(self, k, s)
			return s
		end,
	}
	local SMODS_real = { Mods = {}, current_mod = stub() }
	setmetatable(SMODS_real, {
		__index = function(t, k)
			local cls = setmetatable({ __class = k }, smods_class_mt)
			rawset(t, k, cls)
			return cls
		end,
	})

	-- ------------------------------------------------------------------
	-- Globals.
	-- ------------------------------------------------------------------
	local env_mt = {
		__index = function(t, k)
			local s = stub()
			rawset(t, k, s)
			return s
		end,
	}
	local env = setmetatable({}, env_mt)
	for _, name in ipairs({
		"print", "pairs", "ipairs", "next", "type", "tostring", "tonumber", "select", "unpack",
		"error", "assert", "pcall", "xpcall", "rawget", "rawset", "rawequal", "setmetatable",
		"getmetatable", "string", "table", "math", "os", "io", "bit", "jit", "loadstring", "load",
	}) do
		env[name] = _G[name]
	end
	env._G = env
	env.SMODS = SMODS_real
	env.print = function() end
	env.sendInfoMessage = function() end
	env.sendWarnMessage = function() end
	env.sendDebugMessage = function() end
	env.copy_table = function(t)
		local function copy(v)
			if type(v) ~= "table" or is_stub(v) then return v end
			local c = {}
			for k, vv in pairs(v) do c[k] = copy(vv) end
			return c
		end
		return copy(t)
	end
	env.localize = function(k) return type(k) == "string" and k or "" end

	local function run_file(path, label)
		local chunk, err = loadfile(path)
		if not chunk then
			world.load_errors[#world.load_errors + 1] = ("%s: %s"):format(label, err)
			return
		end
		setfenv(chunk, env)
		local prev = world.current_file
		world.current_file = label
		local ok, run_err = pcall(chunk)
		world.current_file = prev
		if not ok then world.load_errors[#world.load_errors + 1] = ("%s: %s"):format(label, tostring(run_err)) end
	end

	local function list_dir(dir)
		local files, dirs = {}, {}
		local p = io.popen(('ls -1p "%s" 2>/dev/null'):format(dir))
		for line in p:lines() do
			if line:sub(-1) == "/" then
				dirs[#dirs + 1] = line:sub(1, -2)
			elseif line:match("%.lua$") then
				files[#files + 1] = line
			end
		end
		p:close()
		return files, dirs
	end

	-- PVP.load_mp_dir's order: "_" files, "_" dirs, files, dirs; each group sorted.
	local function load_dir(rel, recursive)
		local files, dirs = list_dir(pvp_dir .. rel)
		local items = {}
		for _, f in ipairs(files) do items[#items + 1] = { name = f, dir = false } end
		if recursive then
			for _, d in ipairs(dirs) do items[#items + 1] = { name = d, dir = true } end
		end
		local function rank(it)
			local underscore = it.name:sub(1, 1) == "_"
			if underscore then return it.dir and 1 or 0 end
			return it.dir and 3 or 2
		end
		table.sort(items, function(a, b)
			local ra, rb = rank(a), rank(b)
			if ra ~= rb then return ra < rb end
			return a.name < b.name
		end)
		for _, it in ipairs(items) do
			local path = rel .. "/" .. it.name
			if it.dir then
				load_dir(path, recursive)
			else
				run_file(pvp_dir .. path, path)
			end
		end
	end

	-- ------------------------------------------------------------------
	-- MPAPI: the real layer registry and merge rules, a recording Ruleset.
	-- ------------------------------------------------------------------
	local MPAPI = setmetatable({}, env_mt)
	env.MPAPI = MPAPI
	-- The registry's own `X = X or {}` defaults would see a stub, so seed them.
	for _, name in ipairs({
		"Layers", "Rulesets", "_JOKER_LAYERS", "_CONSUMABLE_LAYERS", "_TAG_LAYERS",
		"_VOUCHER_LAYERS", "_ENHANCEMENT_LAYERS", "_BLIND_LAYERS",
	}) do
		MPAPI[name] = {}
	end
	run_file(api_dir .. "api/layers/registry.lua", "MPAPI api/layers/registry.lua")
	run_file(api_dir .. "api/layers/fields.lua", "MPAPI api/layers/fields.lua")
	MPAPI.MODIFIERS = {}
	-- Synced objects (api/synced/objects.lua) register through SMODS under the calling mod.
	MPAPI.Joker = function(init) return record("Joker", init) end
	MPAPI.Consumable = function(init) return record("Consumable", init) end
	MPAPI.Blind = function(init) return record("Blind", init) end

	local real_layer = MPAPI.Layer
	MPAPI.Layer = function(name, def)
		if type(name) == "string" and type(def) == "table" and not world.raw_layers[name] then
			world.layer_order[#world.layer_order + 1] = name
			world.layer_files[name] = world.current_file
			world.raw_layers[name] = shallow(def)
		end
		return real_layer(name, def)
	end

	MPAPI.Ruleset = function(init)
		local declared = type(init.layers) == "table" and shallow(init.layers) or nil
		local own = shallow(init)
		local resolved = MPAPI.resolve_layers(init)
		resolved._declared_layers = declared or {}
		resolved._own = own
		if world.rulesets[resolved.key] then
			world.load_errors[#world.load_errors + 1] = "duplicate ruleset " .. resolved.key
		else
			world.ruleset_order[#world.ruleset_order + 1] = resolved.key
		end
		world.rulesets[resolved.key] = resolved
		world.ruleset_files[resolved.key] = world.current_file
		local obj = shallow(resolved)
		obj.inject = function() end
		return obj
	end

	MPAPI.ReworkCenter = function(key, opts)
		opts = opts or {}
		local layers = opts.layers
		if type(layers) == "string" then layers = { layers } end
		local fields = {}
		for k in pairs(opts) do
			if k ~= "layers" then fields[#fields + 1] = k end
		end
		table.sort(fields)
		world.reworks[#world.reworks + 1] = {
			key = key,
			layers = type(layers) == "table" and layers or {},
			file = world.current_file,
			fields = fields,
			silent = opts.silent == true,
			loc_key = type(opts.loc_key) == "string" and opts.loc_key or nil,
		}
	end
	MPAPI.LoadReworks = function() end
	MPAPI.register_mod_isolation = function(mod_id, fn) world.isolation_gates[mod_id] = fn end
	MPAPI.mod_isolation_active = function(mod_id)
		local gate = world.isolation_gates[mod_id]
		return gate ~= nil and gate() or false
	end

	MPAPI.GameMode = function(init)
		if type(init) == "table" and type(init.key) == "string" then
			world.gamemodes[init.key] = { key = init.key, file = world.current_file, init = init }
		end
		return stub()
	end

	-- ------------------------------------------------------------------
	-- PVP: a table the real _rulesets.lua / _layers.lua fill in.
	-- ------------------------------------------------------------------
	local PVP = setmetatable({ id = "MultiplayerPvP" }, env_mt)
	env.PVP = PVP
	PVP.EXPERIMENTAL = {}
	PVP.UTILS = setmetatable({}, env_mt)

	load_dir("gamemodes")
	load_dir("layers")
	load_dir("rulesets", true)
	for _, dir in ipairs({
		"objects/editions", "objects/enhancements", "objects/seals", "objects/stickers",
		"objects/blinds", "objects/decks", "objects/jokers", "objects/jokers/sandbox",
		"objects/jokers/sandbox/extra-credit", "objects/jokers/standard", "objects/jokers/experimental",
		"objects/stakes", "objects/tags", "objects/consumables", "objects/consumables/sandbox",
		"objects/boosters", "objects/challenges", "objects/vouchers",
	}) do
		load_dir(dir)
	end

	-- Forced lobby options: run each ruleset's hook against a config that records writes.
	for _, key in ipairs(world.ruleset_order) do
		local rs = world.rulesets[key]
		if type(rs.force_lobby_options) == "function" then
			local writes = {}
			local config = setmetatable({}, {
				__index = function() return nil end,
				__newindex = function(_, k, v) writes[k] = v end,
			})
			local saved = rawget(PVP, "LOBBY")
			rawset(PVP, "LOBBY", { config = config })
			local ok, run_err = pcall(rs.force_lobby_options, rs)
			rawset(PVP, "LOBBY", saved)
			if not ok then
				world.load_errors[#world.load_errors + 1] = ("%s force_lobby_options: %s"):format(key, tostring(run_err))
			end
			rs._forced_options = writes
		else
			rs._forced_options = {}
		end
	end

	-- ------------------------------------------------------------------
	-- Pool simulation: put a ruleset in a live lobby and ask each piece of
	-- content whether it would be in the pool, the way pool_gating.lua does.
	-- ------------------------------------------------------------------
	local current, current_modifiers
	local function chain_for(key, modifiers)
		local rs = world.rulesets[key]
		local out, seen = {}, {}
		local function add(n)
			if n and not seen[n] then
				seen[n] = true
				out[#out + 1] = n
			end
		end
		for _, n in ipairs(rs._layer_order or {}) do add(n) end
		add((key:gsub("^ruleset_mp_", "")))
		for _, n in ipairs(modifiers or {}) do add(n) end
		return out
	end
	world.chain_for = chain_for

	rawset(PVP, "get_active_ruleset", function() return current end)
	rawset(PVP, "in_session", function() return current ~= nil end)
	rawset(PVP, "is_mp_or_practice", function() return current ~= nil end)
	rawset(PVP, "is_practice_mode", function() return false end)
	rawset(PVP, "active_layer_chain", function() return current and chain_for(current, current_modifiers) or {} end)
	rawset(PVP, "current_ruleset", function()
		local rs = current and world.rulesets[current] or {}
		return setmetatable({}, { __index = function(_, k) return rs[k] end })
	end)
	MPAPI.is_layer_active = PVP.is_layer_active
	MPAPI.is_any_layer_active = PVP.is_any_layer_active

	local INDEX_FOR_SET = {
		Joker = MPAPI._JOKER_LAYERS,
		Tarot = MPAPI._CONSUMABLE_LAYERS,
		Planet = MPAPI._CONSUMABLE_LAYERS,
		Spectral = MPAPI._CONSUMABLE_LAYERS,
		Tag = MPAPI._TAG_LAYERS,
		Voucher = MPAPI._VOUCHER_LAYERS,
		Enhanced = MPAPI._ENHANCEMENT_LAYERS,
		Blind = MPAPI._BLIND_LAYERS,
	}
	world.layer_index_for = function(entry)
		local idx = INDEX_FOR_SET[entry.set] or (entry.class == "Consumable" and MPAPI._CONSUMABLE_LAYERS)
		return idx and idx[entry.key] or nil
	end

	-- Returns "in" / "out" / "unknown", plus how it was decided.
	-- `modifiers`: lobby modifier layers on top of the ruleset (MPAPI.MODIFIERS).
	world.simulate = function(ruleset_key, modifiers)
		current, current_modifiers = ruleset_key, modifiers
		rawset(PVP, "LOBBY", {
			code = "ATLAS",
			config = { ruleset = ruleset_key, multiplayer_jokers = true },
		})
		local result = {}
		for _, key in ipairs(world.content_order) do
			local entry = world.content[key]
			local verdict, why
			if entry.has_mp_include then
				local self_obj = setmetatable({ key = key }, { __index = entry.init })
				local ok, ret = pcall(entry.init.mp_include, self_obj)
				if ok and type(ret) == "boolean" then
					verdict, why = ret and "in" or "out", "mp_include"
				elseif ok and ret == nil then
					verdict, why = "out", "mp_include"
				else
					verdict, why = "unknown", "mp_include"
				end
			elseif world.layer_index_for(entry) then
				local owning = world.layer_index_for(entry)
				verdict = PVP.is_any_layer_active(owning) and "in" or "out"
				why = "layer:" .. table.concat(owning, ",")
			elseif world.isolation_gates[PVP.id] then
				local ok, ret = pcall(world.isolation_gates[PVP.id])
				verdict = (ok and ret and not world.is_stub(ret)) and "in" or "out"
				why = "multiplayer_content"
			else
				verdict, why = "out", "mp_prefix"
			end
			result[key] = { verdict = verdict, why = why }
		end
		current, current_modifiers = nil, nil
		rawset(PVP, "LOBBY", nil)
		return result
	end

	world.pvp_dir = pvp_dir
	world.PVP = PVP
	world.MPAPI = MPAPI
	world.is_stub = is_stub
	world.vanilla = dofile(pvp_dir .. "scripts/ruleset_atlas/vanilla_keys.lua")
	world.loc = dofile(pvp_dir .. "localization/en-us.lua")
	return world
end
