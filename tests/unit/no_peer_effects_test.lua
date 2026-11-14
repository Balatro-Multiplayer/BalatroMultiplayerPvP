-- Run from the repo root: luajit tests/unit/no_peer_effects_test.lua
-- Opponent effects go through the server (pvp.effect, pvp.trap_*, pvp.sell, pvp.shop), never peer to peer.
-- This guard fails on the peer path coming back in a PvP object: a `receive =` field, a `send` key returned
-- from calculate, or a read of `context.opponent_`. Magnet keeps its sync-bus path for now (SPEC-C section 0
-- item 4), so magnet_sandbox.lua is exempt by name.
local passed, failed = 0, 0
local function check(name, got, want)
	if got == want then
		passed = passed + 1
		print("ok   " .. name)
	else
		failed = failed + 1
		print(("FAIL %s: got %s, wanted %s"):format(name, tostring(got), tostring(want)))
	end
end

local EXEMPT = { ["objects/jokers/sandbox/magnet_sandbox.lua"] = true }

local PATTERNS = {
	{ name = "a receive field", pattern = "receive%s*=" },
	{ name = "a returned send key", pattern = "[{,]%s*send%s*=" },
	{ name = "a read of context.opponent_", pattern = "context%.opponent_" },
}

-- Comments are dropped first, so a note about the old path does not trip the guard.
local function strip_comments(text)
	text = text:gsub("%-%-%[(=*)%[.-%]%1%]", "")
	return (text:gsub("%-%-[^\n]*", ""))
end

local function hits(text)
	local out = {}
	text = strip_comments(text)
	for _, p in ipairs(PATTERNS) do
		if text:find(p.pattern) then out[#out + 1] = p.name end
	end
	return out
end

-- The scanner itself.
check("a receive field is caught", hits("SMODS.Joker({ receive = function(self, context) end })")[1], "a receive field")
check("a returned send is caught", hits("return { send = { type = 'request' } }")[1], "a returned send key")
check("an opponent_ read is caught", hits("if context.opponent_sell then end")[1], "a read of context.opponent_")
check("a local named send is not caught", #hits("local send = 0\nsend = send + 1"), 0)
check("a comment is not caught", #hits("-- receive = function, return { send = ... }"), 0)

local listing = io.popen("git ls-files objects")
local files = {}
for line in listing:lines() do
	if line:match("%.lua$") then files[#files + 1] = line end
end
listing:close()
check("PvP object files were listed", #files > 0, true)

local exempt_seen = 0
for _, path in ipairs(files) do
	if EXEMPT[path] then
		exempt_seen = exempt_seen + 1
	else
		local f = assert(io.open(path, "rb"))
		local found = hits(f:read("*a"))
		f:close()
		check(path .. " has no peer path", table.concat(found, ", "), "")
	end
end
-- Once Magnet moves to the server, drop it from EXEMPT.
check("the Magnet exemption still names a real file", exempt_seen, 1)

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
