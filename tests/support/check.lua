-- Checks for the plain Lua unit tests, which run from the repo root:
--   local T = dofile("tests/support/check.lua")
--   local eq, same = T.eq, T.same
--   ...
--   T.done("my_test")
local T = { checks = 0 }

local BUILT_IN = {}
for name in pairs(_G) do BUILT_IN[name] = true end

-- Drops every global a test set, so the next part of a file starts as a fresh process would.
function T.fresh()
	for name in pairs(_G) do
		if not BUILT_IN[name] then _G[name] = nil end
	end
end

-- A table as text with its keys sorted, so two tables compare by content.
function T.show(value)
	if type(value) ~= "table" then return tostring(value) end
	local keys = {}
	for key in pairs(value) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local parts = {}
	for _, key in ipairs(keys) do parts[#parts + 1] = tostring(key) .. "=" .. T.show(value[key]) end
	return "{" .. table.concat(parts, ",") .. "}"
end

function T.eq(actual, expected, message)
	T.checks = T.checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

function T.same(actual, expected, message)
	T.checks = T.checks + 1
	local got, want = T.show(actual), T.show(expected)
	if got ~= want then error(string.format("%s: expected %s, got %s", message, want, got), 2) end
end

function T.check(condition, message)
	T.checks = T.checks + 1
	if not condition then error(message, 2) end
end

function T.done(name)
	print(string.format("%s: ok (%d checks)", name, T.checks))
end

-- Wraps a screen's update as the screens tick runs it each frame: follow the run, then update.
function T.ticked(screen)
	local update = screen.update
	screen.update = function()
		PVP.READ.view.follow_run(PVP.NET.view)
		return update()
	end
	return screen
end

return T
