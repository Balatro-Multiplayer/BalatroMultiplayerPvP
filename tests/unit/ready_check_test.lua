-- Plain Lua test for lib/ready_check.lua (pure decision logic, no game needed).
-- Run from the repo root: lua5.4 tests/unit/ready_check_test.lua
PVP = {}
dofile("lib/ready_check.lua")
local RC = PVP.ReadyCheck
local O = RC.Outcome

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local A, B = "player_a", "player_b"

do
	local c = RC.new("n1", { A, B }, B)
	check("nobody answered: pending", RC.status(c), O.PENDING)
	check("one yes: still pending", RC.answer(c, "n1", A, true), O.PENDING)
	check("both yes: confirmed", RC.answer(c, "n1", B, true), O.CONFIRMED)
end

do
	-- The reported hang: B's stored Ready is stale, B is still inside the previous blind.
	local c = RC.new("n1", { A, B }, A)
	RC.answer(c, "n1", A, true)
	local outcome, refuser = RC.answer(c, "n1", B, false)
	check("a no refuses the start", outcome, O.REFUSED)
	check("the refuser is the player who said no", refuser, B)
end

do
	local c = RC.new("n1", { A, B }, A)
	RC.answer(c, "n1", B, false)
	check("a no is final once another yes comes in", RC.answer(c, "n1", A, true), O.REFUSED)
end

do
	local c = RC.new("n2", { A, B }, A)
	check("an answer under another nonce is ignored", RC.answer(c, "n1", B, false), O.PENDING)
	check("an answer from a player who was not asked is ignored", RC.answer(c, "n2", "player_c", false), O.PENDING)
end

do
	local c = RC.new("n1", { A, B }, A)
	RC.answer(c, "n1", A, true)
	check("a silent player (older client) counts as ready at the timeout", RC.on_timeout(c), O.CONFIRMED)
end

do
	local c = RC.new("n1", { A, B }, A)
	RC.answer(c, "n1", B, false)
	local outcome, refuser = RC.on_timeout(c)
	check("a no still refuses at the timeout", outcome, O.REFUSED)
	check("the timeout names the refuser", refuser, B)
end

do
	local c = RC.new("n1", { A, B, "player_c" }, A)
	RC.answer(c, "n1", A, true)
	RC.answer(c, "n1", B, true)
	check("three players: two yes is not enough", RC.status(c), O.PENDING)
	check("three players: all yes confirms", RC.answer(c, "n1", "player_c", true), O.CONFIRMED)
end

if failures > 0 then
	print(("%d failure(s)"):format(failures))
	os.exit(1)
end
print("all ready_check tests passed")
