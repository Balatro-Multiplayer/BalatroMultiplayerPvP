-- Run from the repo root: luajit tests/unit/net_basics_test.lua
-- lib/_state_value.lua (pure) and pvp_api/_net_basics.lua (the shell helpers every net shares).
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

local lobby, logs
PVP = {
	id = "pvp",
	match_log = function(level, text)
		logs[#logs + 1] = level .. " " .. text
	end,
}
MPAPI = {
	get_current_lobby = function()
		return lobby
	end,
}
dofile("lib/_state_value.lua")
dofile("pvp_api/_net_basics.lua")
local StateValue = PVP.StateValue
local NetBasics = PVP.NetBasics

-- StateValue.same_run: a run id arrives as a string or a number, and both sides compare as strings.
check("same_run: a string run", StateValue.same_run({ runId = "r1" }, "r1"), true)
check("same_run: a number against its string", StateValue.same_run({ runId = 7 }, "7"), true)
check("same_run: a string against its number", StateValue.same_run({ runId = "7" }, 7), true)
check("same_run: another run", StateValue.same_run({ runId = "r1" }, "r2"), false)
check("same_run: a value with no run", StateValue.same_run({}, "r1"), false)
check("same_run: no run asked for", StateValue.same_run({ runId = "r1" }, nil), false)
check("same_run: not a table", StateValue.same_run("r1", "r1"), false)
check("same_run: nil", StateValue.same_run(nil, nil), false)
-- StateValue.of_other_run: positively another run, never for an unknown one.
check("of_other_run: another run", StateValue.of_other_run({ runId = "r1" }, "r2"), true)
check("of_other_run: the same run", StateValue.of_other_run({ runId = "r1" }, "r1"), false)
check("of_other_run: a number against its string", StateValue.of_other_run({ runId = 7 }, "7"), false)
check("of_other_run: a value with no run", StateValue.of_other_run({}, "r1"), false)
check("of_other_run: no run asked for", StateValue.of_other_run({ runId = "r1" }, nil), false)
check("of_other_run: not a table", StateValue.of_other_run("r1", "r2"), false)
check("is_table: a table", StateValue.is_table({}), true)
check("is_table: a string", StateValue.is_table("x"), false)

-- NetBasics.pvp_lobby and PVP.current_run_id: only PvP's own lobby counts.
lobby = nil
check("pvp_lobby: no lobby", NetBasics.pvp_lobby(), nil)
check("current_run_id: no lobby", PVP.current_run_id(), nil)
lobby = { mod_id = "other", _game = { started = { run_id = "r1" } } }
check("pvp_lobby: another mod's lobby", NetBasics.pvp_lobby(), nil)
check("current_run_id: another mod's lobby", PVP.current_run_id(), nil)
lobby = { mod_id = "pvp", _game = { started = { run_id = 12 } } }
check("pvp_lobby: PvP's lobby", NetBasics.pvp_lobby(), lobby)
check("current_run_id: a number comes back as a string", PVP.current_run_id(), "12")
lobby = { mod_id = "pvp", _game = {} }
check("current_run_id: no run started", PVP.current_run_id(), nil)

-- NetBasics.log_refusal / refusal_logger.
logs = {}
check("log_refusal: a table's reason", NetBasics.log_refusal("pvp.vote", { reason = "not_ready" }), "not_ready")
check("log_refusal: a bare reason", NetBasics.log_refusal("pvp.vote", "timeout"), "timeout")
check("log_refusal: a table without reason", NetBasics.log_refusal("pvp.vote", {}), "nil")
check("log_refusal: the line", logs[1], "debug [pvp] pvp.vote refused: not_ready")
check("log_refusal: every call logs", #logs, 3)

logs = {}
local on_answer = NetBasics.refusal_logger("pvp.forfeit")
on_answer(true, { reason = "ignored" })
check("refusal_logger: an accepted request logs nothing", #logs, 0)
on_answer(false, { reason = "no_run" })
check("refusal_logger: a refused request logs once", logs[1], "debug [pvp] pvp.forfeit refused: no_run")

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
