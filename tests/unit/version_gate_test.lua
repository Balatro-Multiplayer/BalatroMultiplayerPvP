-- Plain Lua test for lib/version_gate.lua (pure rules, no game needed).
-- Run from the repo root: lua5.4 tests/unit/version_gate_test.lua
PVP = {}
dofile("lib/version_gate.lua")
local G = PVP.VersionGate

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

check("prefix of a plain version", G.prefix("1.0.3"), "1.0.3")
check("prefix drops a suffix", G.prefix("1.0.3-beta.1"), "1.0.3")
check("prefix drops a leading v", G.prefix("v1.2.0"), "1.2.0")
check("prefix of text without a version", G.prefix("UNK"), nil)

local mods = { "Steamodded-1.0.0~BETA-1814a", "MultiplayerPvP-1.0.4-rc1", "MultiplayerPvPExtra-9.9.9" }
check("pvp prefix from a mod list", G.pvp_prefix(mods), "1.0.4")
check("pvp prefix absent", G.pvp_prefix({ "Steamodded-1.0.0" }), nil)
check("pvp prefix of no list", G.pvp_prefix(nil), nil)

local me = { id = "me", mods = { "MultiplayerPvP-1.0.3" } }
local same = { id = "a", mods = { "MultiplayerPvP-1.0.3-dev" } }
local older = { id = "b", mods = { "MultiplayerPvP-1.0.2" } }
local silent = { id = "c", mods = { "Steamodded-1.0.0" } }

check("equal prefixes do not mismatch", #G.mismatches("1.0.3", { me, same }, "me"), 0)
local found = G.mismatches("1.0.3", { me, same, older, silent }, "me")
check("one other version mismatches", #found, 1)
check("names the player", found[1].player.id, "b")
check("names our version", found[1].our, "1.0.3")
check("names their version", found[1].their, "1.0.2")
check("our own entry is never judged", #G.mismatches("1.0.9", { me }, "me"), 0)
check("no own version, no verdict", #G.mismatches(nil, { older }, "me"), 0)

check("server reason as text", G.is_server_refusal("version_mismatch"), true)
check("server reason in an error", G.is_server_refusal({ message = "version_mismatch" }), true)
check("another reason", G.is_server_refusal("not_host"), false)

if failures > 0 then
	os.exit(1)
end
