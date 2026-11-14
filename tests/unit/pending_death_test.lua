-- Plain Lua test for lib/pending_death.lua (the blind key, no game needed).
-- Run from the repo root: luajit tests/unit/pending_death_test.lua
PVP = {}
dofile("lib/pending_death.lua")
local PendingDeath = PVP.PendingDeath

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

check("blind key joins ante and slot", PendingDeath.blind_key(3, "Boss"), "3:Boss")
check(
	"blind key separates ante and blind",
	PendingDeath.blind_key(1, "Small") ~= PendingDeath.blind_key(2, "Small"),
	true
)
check(
	"blind key separates the slots of one ante",
	PendingDeath.blind_key(2, "Small") ~= PendingDeath.blind_key(2, "Big"),
	true
)

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("all passed")
