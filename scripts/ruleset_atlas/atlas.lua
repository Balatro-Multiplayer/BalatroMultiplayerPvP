-- Ruleset atlas: what every PvP ruleset actually contains, read from the real
-- layer, ruleset and card files with no game running.
--
-- Run from the repo root (MPAPI_DIR defaults to ../BalatroMultiplayerAPI/):
--   luajit scripts/ruleset_atlas/atlas.lua show <ruleset>      bans, reworks, options, pool
--   luajit scripts/ruleset_atlas/atlas.lua diff <a> <b>        what changes going from a to b
--   luajit scripts/ruleset_atlas/atlas.lua lint                problems; exits 1 on any error
--   luajit scripts/ruleset_atlas/atlas.lua json                the whole model as JSON
--   luajit scripts/ruleset_atlas/atlas.lua html [out.html]     a self-contained browsable page
-- A ruleset is named by its key (ruleset_mp_balanced), short key (balanced) or display name.

local here = (arg and arg[0] or ""):match("^(.*)/[^/]*$") or "."
local pvp_dir = os.getenv("PVP_DIR") or "./"
local api_dir = os.getenv("MPAPI_DIR") or "../BalatroMultiplayerAPI/"

local world = dofile(here .. "/load.lua")(pvp_dir, api_dir)
local Model = dofile(here .. "/model.lua")
local model = Model.build(world)

-- ---------------------------------------------------------------------------
-- JSON
-- ---------------------------------------------------------------------------
local function json(v, out)
	out = out or {}
	local t = type(v)
	if t == "table" then
		local n = #v
		local is_array = n > 0 or next(v) == nil
		if is_array then
			for k in pairs(v) do
				if type(k) ~= "number" then is_array = false break end
			end
		end
		if is_array and next(v) == nil then
			out[#out + 1] = "[]"
		elseif is_array then
			out[#out + 1] = "["
			for i = 1, n do
				if i > 1 then out[#out + 1] = "," end
				json(v[i], out)
			end
			out[#out + 1] = "]"
		else
			local keys = {}
			for k in pairs(v) do keys[#keys + 1] = tostring(k) end
			table.sort(keys)
			out[#out + 1] = "{"
			for i, k in ipairs(keys) do
				if i > 1 then out[#out + 1] = "," end
				json(k, out)
				out[#out + 1] = ":"
				local val = v[k]
				if val == nil then val = v[tonumber(k)] end
				json(val, out)
			end
			out[#out + 1] = "}"
		end
	elseif t == "string" then
		out[#out + 1] = '"'
			.. v:gsub('[%c"\\]', function(c)
				local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\t"] = "\\t", ["\r"] = "\\r" }
				return map[c] or ("\\u%04x"):format(c:byte())
			end)
			.. '"'
	elseif t == "number" then
		out[#out + 1] = (v ~= v or v == math.huge or v == -math.huge) and "null" or tostring(v)
	elseif t == "boolean" then
		out[#out + 1] = tostring(v)
	else
		out[#out + 1] = "null"
	end
	return out
end
local function to_json(v) return table.concat(json(v)) end

-- ---------------------------------------------------------------------------
-- Text output
-- ---------------------------------------------------------------------------
-- "*" marks a card whose own in_pool can still keep it out (e.g. Manhunt-only).
local function label(key)
	local c = model.cards[key]
	local mark = c and c.has_in_pool and " *" or ""
	if c and c.name then return ("%s (%s)%s"):format(c.name, key, mark) end
	return key .. mark
end

local function sorted(set)
	local out = {}
	for k in pairs(set) do out[#out + 1] = k end
	table.sort(out)
	return out
end

local function need_ruleset(name)
	local rs = name and Model.find_ruleset(model, name)
	if not rs then
		io.stderr:write(("unknown ruleset %q; one of:\n"):format(tostring(name)))
		for _, r in ipairs(model.rulesets) do io.stderr:write(("  %-22s %s\n"):format(r.short, r.name)) end
		os.exit(2)
	end
	return rs
end

local function fmt_value(v)
	if type(v) == "table" then return to_json(v) end
	return tostring(v)
end

local BUCKETS = {
	{ "banned", "Banned (shown to players)" },
	{ "silent", "Banned silently (replaced by a rework)" },
	{ "reworked", "Reworked / added" },
	{ "included", "Included" },
	{ "spectral", "Spectrals can't create" },
}

local function show(name)
	local rs = need_ruleset(name)
	local s = Model.summary(model, rs)
	print(("%s  [%s]  %s"):format(rs.name, rs.key, rs.file or ""))
	print(("layer chain: %s"):format(#rs.chain > 0 and table.concat(rs.chain, " > ") or "(none)"))
	if #rs.runtime_hooks > 0 then
		print(("runtime hooks (change the run when it starts): %s"):format(table.concat(rs.runtime_hooks, ", ")))
	end
	print("")
	print("settings:")
	for _, k in ipairs(sorted(rs.scalars)) do
		print(("  %-28s %-12s  from %s"):format(k, fmt_value(rs.scalars[k]), rs.scalar_source[k] or "?"))
	end
	if next(rs.forced_options) then
		-- pvp_api/flow.lua (Ranked, private) and pvp_api/setup.lua (after the Casual vote) run it.
		print(("forced lobby options (from %s; Ranked, private, and after the Casual vote):"):format(
			rs.forced_options_source or "?"
		))
		for _, k in ipairs(sorted(rs.forced_options)) do
			print(("  %-28s %s"):format(k, fmt_value(rs.forced_options[k])))
		end
	end
	if #rs.stickers > 0 then print(("stickers: %s"):format(table.concat(rs.stickers, ", "))) end
	for _, b in ipairs(BUCKETS) do
		local keys = sorted(s[b[1]])
		if #keys > 0 then
			print("")
			print(("%s: %d"):format(b[2], #keys))
			for _, k in ipairs(keys) do print(("  %-48s %s"):format(label(k), s[b[1]][k])) end
		end
	end
	local pool = sorted(s.pool)
	print("")
	print(("Multiplayer cards in the pool: %d  (* = its own in_pool can still keep it out)"):format(#pool))
	for _, k in ipairs(pool) do
		print(("  %-48s %s"):format(label(k), model.cards[k].set))
	end
end

local function diff(a_name, b_name)
	local a, b = need_ruleset(a_name), need_ruleset(b_name)
	local sa, sb = Model.summary(model, a), Model.summary(model, b)
	print(("%s -> %s"):format(a.name, b.name))
	print(("chain: %s  ->  %s"):format(table.concat(a.chain, " > "), table.concat(b.chain, " > ")))
	local any = false
	local function section(title, lines)
		if #lines == 0 then return end
		any = true
		print("")
		print(title)
		for _, l in ipairs(lines) do print("  " .. l) end
	end
	local function set_diff(bucket)
		local lines = {}
		for _, k in ipairs(sorted(sb[bucket])) do
			if not sa[bucket][k] then lines[#lines + 1] = "+ " .. label(k) end
		end
		for _, k in ipairs(sorted(sa[bucket])) do
			if not sb[bucket][k] then lines[#lines + 1] = "- " .. label(k) end
		end
		return lines
	end
	local function map_diff(ma, mb)
		local lines, keys = {}, {}
		for k in pairs(ma) do keys[k] = true end
		for k in pairs(mb) do keys[k] = true end
		for _, k in ipairs(sorted(keys)) do
			local va, vb = ma[k], mb[k]
			if fmt_value(va) ~= fmt_value(vb) then
				lines[#lines + 1] = ("%-28s %s -> %s"):format(k, va == nil and "-" or fmt_value(va), vb == nil and "-" or fmt_value(vb))
			end
		end
		return lines
	end
	section("settings", map_diff(a.scalars, b.scalars))
	section("forced lobby options", map_diff(a.forced_options, b.forced_options))
	for _, bk in ipairs(BUCKETS) do section(bk[2], set_diff(bk[1])) end
	section("Multiplayer cards in the pool", set_diff("pool"))
	if not any then print("\n(no differences)") end
end

-- ---------------------------------------------------------------------------
-- Lint
-- ---------------------------------------------------------------------------
local function lint()
	local r = dofile(here .. "/lint.lua")(world, model)
	for _, m in ipairs(r.errors) do print("error   " .. m) end
	for _, m in ipairs(r.warnings) do print("warning " .. m) end
	for _, m in ipairs(r.notes) do print("note    " .. m) end
	print(("\n%d error(s), %d warning(s), %d note(s)"):format(#r.errors, #r.warnings, #r.notes))
	return #r.errors == 0
end

-- ---------------------------------------------------------------------------
-- HTML
-- ---------------------------------------------------------------------------
local function html(out_path)
	local f = assert(io.open(here .. "/atlas_template.html", "r"))
	local template = f:read("*a")
	f:close()
	local commit = io.popen("git -C '" .. pvp_dir .. "' rev-parse --short HEAD 2>/dev/null"):read("*l") or "?"
	local lint_result = dofile(here .. "/lint.lua")(world, model)
	local data = to_json({ model = model, commit = commit, lint = lint_result })
	-- Keep "</script>" in card text from closing the data block.
	data = data:gsub("</", "<\\/")
	local page = template:gsub("/%*ATLAS_DATA%*/", function() return data end)
	if out_path then
		local o = assert(io.open(out_path, "w"))
		o:write(page)
		o:close()
		io.stderr:write(("wrote %s (%d bytes)\n"):format(out_path, #page))
	else
		io.write(page)
	end
end

local cmd = arg[1]
if cmd == "show" then
	show(arg[2])
elseif cmd == "diff" then
	diff(arg[2], arg[3])
elseif cmd == "lint" then
	os.exit(lint() and 0 or 1)
elseif cmd == "json" then
	print(to_json(model))
elseif cmd == "html" then
	html(arg[2])
elseif cmd == "list" or cmd == nil then
	for _, rs in ipairs(model.rulesets) do
		print(("%-22s %-24s %s"):format(rs.short, rs.name, table.concat(rs.chain, " > ")))
	end
else
	io.stderr:write("usage: atlas.lua list | show <ruleset> | diff <a> <b> | lint | json | html [out]\n")
	os.exit(2)
end
