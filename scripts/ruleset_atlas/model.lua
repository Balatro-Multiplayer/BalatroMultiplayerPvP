-- Turns the loaded world (load.lua) into the atlas model: every ruleset with its
-- layer chain, where each ban and rework comes from, the forced lobby options, and
-- which Multiplayer cards are in its pool; plus a name and text for every key.

local M = {}

local ARRAY_CATEGORIES = {
	{ field = "banned_jokers", kind = "ban", set = "Joker" },
	{ field = "banned_consumables", kind = "ban", set = "Consumable" },
	{ field = "banned_vouchers", kind = "ban", set = "Voucher" },
	{ field = "banned_enhancements", kind = "ban", set = "Enhanced" },
	{ field = "banned_tags", kind = "ban", set = "Tag" },
	{ field = "banned_blinds", kind = "ban", set = "Blind" },
	{ field = "banned_silent", kind = "silent_ban", set = nil },
	{ field = "spectral_banned_enhancements", kind = "spectral_ban", set = "Enhanced" },
	{ field = "included_jokers", kind = "include", set = "Joker" },
	{ field = "included_consumables", kind = "include", set = "Consumable" },
	{ field = "included_vouchers", kind = "include", set = "Voucher" },
	{ field = "included_enhancements", kind = "include", set = "Enhanced" },
	{ field = "included_tags", kind = "include", set = "Tag" },
	{ field = "included_blinds", kind = "include", set = "Blind" },
	{ field = "reworked_jokers", kind = "rework", set = "Joker" },
	{ field = "reworked_consumables", kind = "rework", set = "Consumable" },
	{ field = "reworked_vouchers", kind = "rework", set = "Voucher" },
	{ field = "reworked_enhancements", kind = "rework", set = "Enhanced" },
	{ field = "reworked_tags", kind = "rework", set = "Tag" },
	{ field = "reworked_blinds", kind = "rework", set = "Blind" },
}
M.ARRAY_CATEGORIES = ARRAY_CATEGORIES

-- Sets a run draws from pools (shops, packs, tags); decks, stakes, blinds and challenges are picked.
M.POOLED_SETS = {
	Joker = true, Tarot = true, Planet = true, Spectral = true, Consumable = true,
	Tag = true, Voucher = true, Booster = true, Enhanced = true,
}

local CONSUMABLE_SETS = { Tarot = true, Planet = true, Spectral = true, Consumable = true }

-- Fields that are a ruleset's or layer's identity or plumbing, not a rule.
-- forced_lobby_options is a flag nothing reads: the hook runs whenever it exists
-- (pvp_api/flow.lua, pvp_api/setup.lua).
local SKIP_SCALAR = {
	key = true, layers = true, inject = true, prefix_config = true, stickers = true, forced_lobby_options = true,
	is_disabled = true, force_lobby_options = true, calculate = true, pool_enabled = true,
}

local function sorted_keys(t)
	local out = {}
	for k in pairs(t) do out[#out + 1] = k end
	table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
	return out
end

local function plain(v, is_stub, depth)
	depth = depth or 0
	if is_stub(v) or depth > 4 then return nil end
	local t = type(v)
	if t == "string" or t == "number" or t == "boolean" then return v end
	if t == "table" then
		local out, n = {}, 0
		for k, vv in pairs(v) do
			local p = plain(vv, is_stub, depth + 1)
			if p ~= nil and (type(k) == "string" or type(k) == "number") then
				out[k] = p
				n = n + 1
			end
		end
		return n > 0 and out or nil
	end
	return nil
end

-- "{C:mult}+#1#{} Mult" -> "+4 Mult"
local function render_text(lines, vars)
	if type(lines) ~= "table" then return nil end
	local flat = {}
	for _, line in ipairs(lines) do
		if type(line) == "table" then
			for _, l in ipairs(line) do flat[#flat + 1] = l end
		else
			flat[#flat + 1] = line
		end
	end
	local text = table.concat(flat, " ")
	text = text:gsub("#(%d+)#", function(i)
		local v = vars and vars[tonumber(i)]
		if type(v) == "number" or type(v) == "string" then return tostring(v) end
		return "X"
	end)
	text = text:gsub("{[^}]*}", "")
	text = text:gsub("%s+", " ")
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function deep_copy(v, is_stub)
	if type(v) ~= "table" or is_stub(v) then return v end
	local c = {}
	for k, vv in pairs(v) do c[k] = deep_copy(vv, is_stub) end
	return c
end

-- Fill a Multiplayer card's description from its own loc_vars against its config.
local function try_vars(entry, is_stub)
	local init = entry.init
	if type(init.loc_vars) ~= "function" then return nil end
	local card = { ability = deep_copy(init.config or {}, is_stub), config = { center = init } }
	if card.ability.extra == nil then card.ability.extra = {} end
	local ok, ret = pcall(init.loc_vars, setmetatable({ key = entry.key }, { __index = init }), {}, card)
	if ok and type(ret) == "table" then
		local vars = {}
		for i, v in ipairs(type(ret.vars) == "table" and ret.vars or {}) do
			vars[i] = (not is_stub(v)) and v or nil
		end
		return vars, type(ret.key) == "string" and ret.key or nil
	end
	return nil
end

-- Where the game offers each ruleset: every line outside rulesets/ and localization/
-- that names its key or its PVP.RulesetKey constant, plus the Casual vote's options.
local function find_offers(pvp_dir, rulesets)
	local const_for = {}
	local f = io.open(pvp_dir .. "rulesets/_rulesets.lua")
	if f then
		for line in f:lines() do
			local const, key = line:match("^%s*([A-Z_]+)%s*=%s*\"(ruleset_mp_[%w_]+)\"")
			if const then const_for[key] = const end
		end
		f:close()
	end
	local offers = {}
	local p = io.popen(('cd "%s" && grep -rn --include=*.lua -e "ruleset_mp_" -e "RulesetKey%%." -e "RULESET_OPTIONS =" ui pvp_api lib networking core.lua 2>/dev/null'):format(pvp_dir))
	local lines = {}
	for line in p:lines() do lines[#lines + 1] = line end
	p:close()
	for _, short in ipairs(rulesets) do
		local key = "ruleset_mp_" .. short
		local const = const_for[key]
		local found = {}
		for _, line in ipairs(lines) do
			local file, ln, text = line:match("^([^:]+):(%d+):(.*)$")
			if file and not text:match("^%s*%-%-") then
				local hit = text:find('"' .. key .. '"', 1, true)
					or (const and text:find("RulesetKey." .. const, 1, true) and not text:find("RulesetKey." .. const .. "_", 1, true))
					or (text:find("RULESET_OPTIONS =", 1, true) and text:find('"' .. short .. '"', 1, true))
				if hit then found[#found + 1] = file .. ":" .. ln end
			end
		end
		offers[short] = found
	end
	return offers
end

local VANILLA_SET_ORDER = { "Joker", "Tarot", "Planet", "Spectral", "Voucher", "Tag", "Enhanced", "Blind", "Back", "Booster" }

function M.build(world)
	local is_stub = world.is_stub
	local loc = world.loc.descriptions or {}
	local dict = (world.loc.misc and world.loc.misc.dictionary) or {}

	-- ---------------------------------------------------------------
	-- Cards: every key a ruleset could name.
	-- ---------------------------------------------------------------
	local cards = {}
	for _, set in ipairs(VANILLA_SET_ORDER) do
		for key, name in pairs(world.vanilla[set] or {}) do
			cards[key] = { key = key, name = name, set = set, origin = "vanilla" }
		end
	end
	local function loc_entry(key)
		for _, group in pairs(loc) do
			if type(group) == "table" and group[key] then return group[key] end
		end
		return nil
	end
	for _, key in ipairs(world.content_order) do
		local e = world.content[key]
		local vars, vars_key = try_vars(e, is_stub)
		local l = loc_entry(vars_key or key) or loc_entry(key)
		if not l and type(e.init.loc_txt) == "table" and not is_stub(e.init.loc_txt) then l = e.init.loc_txt end
		if not l and e.class == "Challenge" then
			local cn = world.loc.misc and world.loc.misc.challenge_names or {}
			if cn[key] then l = { name = cn[key] } end
		end
		local set = e.set
		if e.class == "Consumable" and not CONSUMABLE_SETS[set] then set = "Consumable" end
		cards[key] = {
			key = key,
			name = l and type(l.name) == "string" and l.name or nil,
			text = l and render_text(l.text, vars) or nil,
			set = set,
			class = e.class,
			origin = "mp",
			file = e.file,
			rarity = e.rarity,
			cost = e.cost,
			hidden_in_collection = e.no_collection or nil,
			gated_by = e.has_mp_include and "mp_include" or nil,
			has_in_pool = type(e.init.in_pool) == "function" or nil,
			credits = plain(e.credits, is_stub),
		}
	end
	-- A vanilla key a rework or overview names, with no MP definition, still gets a name.
	local function card(key)
		if not cards[key] then
			cards[key] = { key = key, set = "Unknown", origin = "unknown" }
		end
		return cards[key]
	end

	-- ---------------------------------------------------------------
	-- Layers.
	-- ---------------------------------------------------------------
	local layers = {}
	local used_by = {}
	for _, rk in ipairs(world.ruleset_order) do
		for _, name in ipairs(world.chain_for(rk)) do
			used_by[name] = used_by[name] or {}
			table.insert(used_by[name], rk)
		end
	end
	for _, name in ipairs(world.layer_order) do
		local def = world.raw_layers[name]
		local arrays, scalars = {}, {}
		for _, cat in ipairs(ARRAY_CATEGORIES) do
			if type(def[cat.field]) == "table" and #def[cat.field] > 0 then arrays[cat.field] = def[cat.field] end
		end
		if type(def.stickers) == "table" then arrays.stickers = def.stickers end
		for _, k in ipairs(sorted_keys(def)) do
			local v = def[k]
			if not SKIP_SCALAR[k] and not arrays[k] and type(v) ~= "function" then
				local p = plain(v, is_stub)
				if p ~= nil then scalars[k] = p end
			end
		end
		layers[name] = {
			name = name,
			file = world.layer_files[name],
			arrays = arrays,
			scalars = scalars,
			runtime_hook = type(def.calculate) == "function" or nil,
			pool_hook = type(def.pool_enabled) == "function" or nil,
			force_lobby_options = type(def.force_lobby_options) == "function" or nil,
			is_disabled = type(def.is_disabled) == "function" or nil,
			used_by = used_by[name] or {},
		}
	end

	-- ---------------------------------------------------------------
	-- Rulesets.
	-- ---------------------------------------------------------------
	local function display_name(short)
		return dict["k_mp_ruleset_" .. short] or dict["k_" .. short] or short
	end
	local function description(short)
		return dict["k_mp_ruleset_" .. short .. "_description"] or dict["k_" .. short .. "_description"]
	end

	local shorts = {}
	for i, rk in ipairs(world.ruleset_order) do shorts[i] = (rk:gsub("^ruleset_mp_", "")) end
	local offers = find_offers(world.pvp_dir, shorts)

	local rulesets = {}
	for _, rk in ipairs(world.ruleset_order) do
		local rs = world.rulesets[rk]
		local short = rk:gsub("^ruleset_mp_", "")
		-- The chain as the game walks it, minus a self-name nothing registers under.
		local chain = {}
		for _, n in ipairs(world.chain_for(rk)) do
			local targeted = false
			for _, rw in ipairs(world.reworks) do
				for _, l in ipairs(rw.layers) do
					if l == n then targeted = true end
				end
			end
			if world.raw_layers[n] or targeted then chain[#chain + 1] = n end
		end
		local own = rs._own or {}

		-- Every array entry, with the layer(s) that put it there.
		local entries = {}
		local function add_entry(field, key, source)
			entries[field] = entries[field] or {}
			local list = entries[field]
			for _, e in ipairs(list) do
				if e.key == key then
					table.insert(e.sources, source)
					return
				end
			end
			list[#list + 1] = { key = key, sources = { source } }
			card(key)
		end
		for _, layer_name in ipairs(rs._layer_order or {}) do
			local def = world.raw_layers[layer_name] or {}
			for _, cat in ipairs(ARRAY_CATEGORIES) do
				for _, key in ipairs(type(def[cat.field]) == "table" and def[cat.field] or {}) do
					add_entry(cat.field, key, layer_name)
				end
			end
		end
		for _, cat in ipairs(ARRAY_CATEGORIES) do
			for _, key in ipairs(type(own[cat.field]) == "table" and own[cat.field] or {}) do
				add_entry(cat.field, key, "(ruleset)")
			end
		end

		local scalars = {}
		for _, k in ipairs(sorted_keys(rs)) do
			local v = rs[k]
			if not SKIP_SCALAR[k] and k:sub(1, 1) ~= "_" and type(v) ~= "function" then
				local is_array_field = false
				for _, cat in ipairs(ARRAY_CATEGORIES) do
					if cat.field == k then is_array_field = true end
				end
				if not is_array_field then
					local p = plain(v, is_stub)
					if p ~= nil then scalars[k] = p end
				end
			end
		end
		-- Where each scalar came from: the ruleset itself, or the last layer that set it.
		local scalar_source = {}
		for k in pairs(scalars) do
			if own[k] ~= nil then
				scalar_source[k] = "(ruleset)"
			else
				for _, layer_name in ipairs(rs._layer_order or {}) do
					if (world.raw_layers[layer_name] or {})[k] ~= nil then scalar_source[k] = layer_name end
				end
			end
		end

		local forced_source
		if own.force_lobby_options then
			forced_source = "(ruleset)"
		else
			for _, layer_name in ipairs(rs._layer_order or {}) do
				if type((world.raw_layers[layer_name] or {}).force_lobby_options) == "function" then
					forced_source = layer_name
				end
			end
		end

		local stickers = {}
		for _, s in ipairs(type(rs.stickers) == "table" and rs.stickers or {}) do stickers[#stickers + 1] = s end

		-- Bans as the run applies them: ruleset + forced gamemode.
		local banned = {}
		for field, list in pairs(entries) do
			if field:match("^banned_") then
				for _, e in ipairs(list) do banned[e.key] = true end
			end
		end
		local gamemode_bans = {}
		local gm = rs.forced_gamemode and world.gamemodes[rs.forced_gamemode]
		if gm then
			for k, v in pairs(gm.init) do
				if type(k) == "string" and k:match("^banned_") and type(v) == "table" then
					for _, key in ipairs(v) do
						gamemode_bans[#gamemode_bans + 1] = { key = key, field = k }
						banned[key] = true
						card(key)
					end
				end
			end
			table.sort(gamemode_bans, function(a, b) return a.key < b.key end)
		end

		-- Multiplayer cards in this ruleset's pool.
		local sim = world.simulate(rk)
		local pool = {}
		for _, key in ipairs(world.content_order) do
			local s = sim[key]
			local status = s.verdict
			if status == "in" and banned[key] then status = "banned" end
			pool[key] = { status = status, why = s.why }
		end

		-- Center reworks (PVP.ReworkCenter) live on this chain.
		local chain_set = {}
		for _, n in ipairs(chain) do chain_set[n] = true end
		local center_reworks = {}
		for _, rw in ipairs(world.reworks) do
			for _, l in ipairs(rw.layers) do
				if chain_set[l] then
					center_reworks[#center_reworks + 1] = { key = rw.key, layer = l, fields = rw.fields, file = rw.file }
					card(rw.key)
				end
			end
		end

		local runtime_hooks = {}
		for _, n in ipairs(chain) do
			local def = world.raw_layers[n]
			if def and type(def.calculate) == "function" then runtime_hooks[#runtime_hooks + 1] = n end
		end

		rulesets[#rulesets + 1] = {
			key = rk,
			short = short,
			name = display_name(short),
			description = description(short),
			file = world.ruleset_files[rk],
			offered_at = offers[short] or {},
			declared_layers = rs._declared_layers,
			chain = chain,
			entries = entries,
			scalars = scalars,
			scalar_source = scalar_source,
			forced_options = rs._forced_options,
			forced_options_source = forced_source,
			has_is_disabled = type(rs.is_disabled) == "function" and (own.is_disabled ~= nil or scalar_source.is_disabled ~= nil) or nil,
			stickers = stickers,
			gamemode_bans = gamemode_bans,
			pool = pool,
			center_reworks = center_reworks,
			runtime_hooks = runtime_hooks,
		}
	end

	local gamemodes = {}
	for _, gk in ipairs(sorted_keys(world.gamemodes)) do
		local gm = world.gamemodes[gk]
		gamemodes[#gamemodes + 1] = { key = gk, file = gm.file }
	end

	local reworks = {}
	for _, rw in ipairs(world.reworks) do
		reworks[#reworks + 1] = { key = rw.key, layers = rw.layers, fields = rw.fields, file = rw.file }
	end

	return {
		rulesets = rulesets,
		layers = layers,
		layer_order = world.layer_order,
		cards = cards,
		mp_content = world.content_order,
		gamemodes = gamemodes,
		center_reworks = reworks,
		load_errors = world.load_errors,
	}
end

function M.find_ruleset(model, name)
	for _, rs in ipairs(model.rulesets) do
		if rs.key == name or rs.short == name or rs.name:lower() == name:lower() then return rs end
	end
	return nil
end

-- Every key a ruleset changes or removes, by status, for show/diff.
function M.summary(model, rs)
	local out = { banned = {}, silent = {}, reworked = {}, included = {}, spectral = {}, pool = {} }
	local function add(bucket, key, sources)
		out[bucket][key] = sources
	end
	for field, list in pairs(rs.entries) do
		local bucket = (field == "banned_silent" and "silent")
			or (field == "spectral_banned_enhancements" and "spectral")
			or (field:match("^banned_") and "banned")
			or (field:match("^reworked_") and "reworked")
			or "included"
		for _, e in ipairs(list) do add(bucket, e.key, table.concat(e.sources, "+")) end
	end
	for _, gb in ipairs(rs.gamemode_bans) do
		if not out.banned[gb.key] then add("banned", gb.key, "gamemode") end
	end
	for _, rw in ipairs(rs.center_reworks) do
		if not out.reworked[rw.key] then add("reworked", rw.key, rw.layer) end
	end
	for key, p in pairs(rs.pool) do
		if p.status == "in" and M.POOLED_SETS[model.cards[key].set] then out.pool[key] = p.why end
	end
	return out
end

return M
