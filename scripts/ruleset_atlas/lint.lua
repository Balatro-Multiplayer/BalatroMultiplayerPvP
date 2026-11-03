-- Problems the atlas can see without running the game: names that match no card,
-- reworks that never spawn, cards nothing can roll, missing names.
-- Returns { errors, warnings, notes }, each a list of strings.

local here = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$") or "."
local Model = dofile(here .. "/model.lua")

local function sorted(set)
	local out = {}
	for k in pairs(set) do out[#out + 1] = k end
	table.sort(out)
	return out
end

return function(world, model)
	local errors, warnings, notes = {}, {}, {}
	local function err(m) errors[#errors + 1] = m end
	local function warn(m) warnings[#warnings + 1] = m end
	local function note(m) notes[#notes + 1] = m end

	for _, e in ipairs(model.load_errors) do err("load: " .. e) end

	local layer_names = {}
	for _, n in ipairs(world.layer_order) do layer_names[n] = true end
	local ruleset_shorts = {}
	for _, rs in ipairs(model.rulesets) do ruleset_shorts[rs.short] = true end

	-- A layer's stickers list names "persistent" for SMODS.Stickers["mp_sticker_persistent"]
	-- (objects/stickers/_stickers.lua).
	local sticker_keys = {}
	for k, e in pairs(world.content) do
		if e.class == "Sticker" then sticker_keys[(k:gsub("^mp_sticker_", ""))] = true end
	end

	local function set_matches(card_set, cat_set)
		if not cat_set or card_set == "Unknown" then return true end
		if cat_set == "Consumable" then return card_set == "Consumable" or card_set == "Tarot" or card_set == "Planet" or card_set == "Spectral" end
		return card_set == cat_set
	end

	local function check_list(owner, field, list, cat)
		local seen = {}
		for _, key in ipairs(list) do
			if seen[key] then warn(("%s: %s lists %s twice"):format(owner, field, key)) end
			seen[key] = true
			local c = model.cards[key]
			if not c or c.origin == "unknown" then
				err(("%s: %s names %s, which is not a vanilla or Multiplayer key"):format(owner, field, key))
			elseif not set_matches(c.set, cat.set) then
				err(("%s: %s names %s, a %s"):format(owner, field, key, c.set))
			end
		end
	end

	local modifier_layers = {}
	for _, name in ipairs(world.layer_order) do
		local def = world.raw_layers[name]
		local owner = ("layer %s (%s)"):format(name, world.layer_files[name])
		for _, cat in ipairs(Model.ARRAY_CATEGORIES) do
			if type(def[cat.field]) == "table" then check_list(owner, cat.field, def[cat.field], cat) end
		end
		for _, s in ipairs(type(def.stickers) == "table" and def.stickers or {}) do
			if not sticker_keys[s] then err(("%s: stickers names %s, which is not a registered sticker"):format(owner, s)) end
		end
		if #model.layers[name].used_by == 0 then
			local empty = next(def) == nil
			modifier_layers[#modifier_layers + 1] = name .. (empty and " (empty)" or "")
		end
	end

	if #modifier_layers > 0 then
		note(("%d layers are in no ruleset (lobby modifiers, or unused): %s"):format(#modifier_layers, table.concat(modifier_layers, ", ")))
	end

	for _, rs in ipairs(model.rulesets) do
		local own = world.rulesets[rs.key]._own or {}
		local owner = ("ruleset %s (%s)"):format(rs.short, rs.file)
		for _, cat in ipairs(Model.ARRAY_CATEGORIES) do
			if type(own[cat.field]) == "table" and #own[cat.field] > 0 then
				check_list(owner, cat.field, own[cat.field], cat)
				warn(("%s: declares %s itself instead of through a layer"):format(owner, cat.field))
			end
		end
		if rs.scalars.forced_gamemode and not world.gamemodes[rs.scalars.forced_gamemode] then
			err(("%s: forced_gamemode %s is not a registered gamemode"):format(owner, rs.scalars.forced_gamemode))
		end
		-- Both banned and reworked/included in one ruleset: the ban wins at runtime.
		local s = Model.summary(model, rs)
		for _, bucket in ipairs({ "reworked", "included" }) do
			for _, key in ipairs(sorted(s[bucket])) do
				if (s.banned[key] or s.silent[key]) and model.cards[key].origin == "mp" then
					warn(("%s: %s is %s by %s and banned by %s"):format(owner, key, bucket, s[bucket][key], s.banned[key] or s.silent[key]))
				end
			end
		end
		-- A rework listed here that the pool still excludes. When it replaces a card this
		-- ruleset bans silently, the card is simply gone from the run.
		local inert = {}
		for _, key in ipairs(sorted(s.reworked)) do
			local p = rs.pool[key]
			if p and p.status == "out" and not s.banned[key] and not s.silent[key] then
				local original = key:gsub("^(%a+)_mp_", "%1_")
				if s.silent[original] then
					warn(("%s: bans %s silently for the rework %s (listed by %s), but %s keeps the rework out of the pool, so neither can appear"):format(
						owner, original, key, s.reworked[key], p.why
					))
				else
					inert[#inert + 1] = key
				end
			end
		end
		if #inert > 0 then
			note(("%s: %d listed reworks never enter the pool (overview only?): %s"):format(owner, #inert, table.concat(inert, ", ")))
		end
		if #rs.offered_at == 0 then
			note(("%s: nothing in ui/, pvp_api/, lib/ or networking/ names this ruleset, so no menu, queue or vote offers it"):format(owner))
		end
		if not rs.description then
			warn(("%s: no k_mp_ruleset_%s_description / k_%s_description in en-us"):format(owner, rs.short, rs.short))
		end
	end

	for _, rw in ipairs(world.reworks) do
		local owner = ("ReworkCenter %s (%s)"):format(rw.key, rw.file)
		if #rw.layers == 0 then err(owner .. ": no layers") end
		for _, l in ipairs(rw.layers) do
			if not layer_names[l] and not ruleset_shorts[l] then
				err(("%s: layer %s is neither a layer nor a ruleset"):format(owner, l))
			elseif #(model.layers[l] and model.layers[l].used_by or {}) == 0 and not ruleset_shorts[l] then
				warn(("%s: layer %s is in no ruleset, so this rework only applies as a modifier"):format(owner, l))
			end
		end
		local c = model.cards[rw.key]
		if not c or c.origin == "unknown" then err(owner .. ": not a known center key") end
	end

	-- Multiplayer cards no ruleset can ever roll.
	local unpooled_hidden = {}
	for _, key in ipairs(model.mp_content) do
		local c = model.cards[key]
		local poolable = ({ Joker = true, Tarot = true, Planet = true, Spectral = true, Consumable = true, Tag = true, Voucher = true })[c.set]
		if poolable then
			local anywhere = false
			for _, rs in ipairs(model.rulesets) do
				if rs.pool[key].status ~= "out" then anywhere = true break end
			end
			if not anywhere then
				local via = {}
				for _, layer_name in ipairs(world.layer_order) do
					if #model.layers[layer_name].used_by == 0 then
						for _, rs in ipairs(model.rulesets) do
							if world.simulate(rs.key, { layer_name })[key].verdict ~= "out" then
								via[#via + 1] = layer_name
								break
							end
						end
					end
				end
				if #via > 0 then
					c.modifier_only = via
				elseif c.hidden_in_collection then
					local by_file = unpooled_hidden[c.file] or {}
					unpooled_hidden[c.file] = by_file
					by_file[#by_file + 1] = key
				else
					warn(("%s (%s) is in no ruleset's pool and shows in the collection"):format(key, c.file))
				end
			end
		end
		-- A sticker with hide_badge never shows its name.
		local nameless_ok = c.class == "Sticker" and world.content[key].init.hide_badge
		if not c.name and not nameless_ok then
			warn(("%s (%s): no en-us name, so the game shows ERROR"):format(key, c.file))
		end
	end

	local hidden_lines, hidden_count = {}, 0
	for _, file in ipairs(sorted(unpooled_hidden)) do
		local keys = unpooled_hidden[file]
		hidden_count = hidden_count + #keys
		hidden_lines[#hidden_lines + 1] = #keys > 2 and (("%s..%s (%d)"):format(keys[1], keys[#keys], #keys)) or table.concat(keys, ", ")
	end
	if hidden_count > 0 then
		note(("%d cards hidden from the collection are in no ruleset's pool (out of rotation?): %s"):format(hidden_count, table.concat(hidden_lines, ", ")))
	end

	return { errors = errors, warnings = warnings, notes = notes }
end
