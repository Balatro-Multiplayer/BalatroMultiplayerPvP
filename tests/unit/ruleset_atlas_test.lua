-- Plain Lua test for the ruleset atlas (scripts/ruleset_atlas): it loads the real
-- layer, ruleset and card files, so these checks pin what the rulesets contain today
-- and that the lint catches a mistyped key and a rework that can never spawn.
-- Run from the repo root: luajit tests/unit/ruleset_atlas_test.lua
-- MPAPI_DIR points at the BalatroMultiplayerAPI checkout (default ../BalatroMultiplayerAPI/).
local api = os.getenv("MPAPI_DIR") or "../BalatroMultiplayerAPI/"
if api:sub(-1) ~= "/" then api = api .. "/" end

local load = dofile("scripts/ruleset_atlas/load.lua")
local Model = dofile("scripts/ruleset_atlas/model.lua")
local Lint = dofile("scripts/ruleset_atlas/lint.lua")

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

local function any(list, pattern)
	for _, s in ipairs(list) do
		if s:find(pattern) then return true end
	end
	return false
end

-- The real tree ----------------------------------------------------------------
local world = load("./", api)
local model = Model.build(world)

check("the real files load with no errors", #world.load_errors, 0)
check("every ruleset file registers", #model.rulesets >= 15, true)

local balanced = Model.find_ruleset(model, "balanced")
local expanded = Model.find_ruleset(model, "Expanded")
local vanilla = Model.find_ruleset(model, "ruleset_mp_vanilla")
local majorleague = Model.find_ruleset(model, "majorleague")
local sandbox = Model.find_ruleset(model, "sandbox")

check("Expanded's chain is its layers in order", table.concat(expanded.chain, ","), "balanced,expanded,expanded_draft,pvp_timer")

local exp = Model.summary(model, expanded)
check("Expanded bans Conjoined Joker (from the expanded layer)", exp.banned.j_mp_conjoined_joker, "expanded")
check("Expanded bans Justice (from the balanced layer)", exp.banned.c_justice, "balanced")
check("Expanded silently bans vanilla Seltzer", exp.silent.j_selzer, "expanded")
check("Expanded rolls the Seltzer rework", exp.pool.j_mp_seltzer ~= nil, true)
check("Expanded rolls Let's Go Gambling", exp.pool.j_mp_lets_go_gambling ~= nil, true)
check("Expanded's banned Conjoined Joker is out of the pool", exp.pool.j_mp_conjoined_joker, nil)
check("Expanded's Glass rework comes from ReworkCenter on balanced", exp.reworked.m_glass, "balanced")

local bal = Model.summary(model, balanced)
check("Balanced rolls the Hanging Chad rework", bal.pool.j_mp_hanging_chad ~= nil, true)
check("Balanced has no Multiplayer-original jokers", bal.pool.j_mp_lets_go_gambling, nil)

local van = Model.summary(model, vanilla)
local van_pool = 0
for _ in pairs(van.pool) do van_pool = van_pool + 1 end
check("Vanilla rolls no Multiplayer cards", van_pool, 0)
check("Vanilla forces The Order off", vanilla.forced_options.the_order, false)

check("Major League forces a 180 second timer", majorleague.forced_options.timer_base_seconds, 180)
check("Major League forces Attrition", majorleague.scalars.forced_gamemode, "gamemode_mp_attrition")
local mlb = Model.summary(model, majorleague)
check("Major League carries Attrition's Mr. Bones ban", mlb.banned.j_mr_bones, "gamemode")

local sb = Model.summary(model, sandbox)
check("Sandbox rolls an in-rotation sandbox joker", sb.pool.j_mp_mail_sandbox ~= nil, true)
check("Sandbox leaves out an out-of-rotation one", sb.pool.j_mp_runner_sandbox, nil)
check("Sandbox keeps Conjoined Joker out (its own mp_include)", sb.pool.j_mp_conjoined_joker, nil)

check("a vanilla key gets its name", model.cards.j_bloodstone.name, "Bloodstone")
check("a Multiplayer key gets its en-us name", model.cards.j_mp_taxes.name, "Taxes")
check("a challenge key gets its name", model.cards.c_mp_eeeee ~= nil and model.cards.c_mp_eeeee.name, "EEEEE")
check("the trap consumables are reachable through the traps modifier", world.simulate("ruleset_mp_expanded", { "traps" }).c_mp_trap_snare.verdict, "in")

local clean = Lint(world, model)
check("the real tree lints with no errors", #clean.errors, 0)

-- A broken layer and ruleset -------------------------------------------------------
local broken = load("./", api)
broken.MPAPI.Layer("atlas_test_layer", {
	banned_jokers = { "j_bloodstnoe" },
	banned_consumables = { "j_joker" },
	reworked_jokers = { "j_mp_hanging_chad" },
	banned_silent = { "j_hanging_chad" },
})
broken.MPAPI.Ruleset({ key = "ruleset_mp_atlas_test", layers = { "atlas_test_layer" } })
broken.rulesets.ruleset_mp_atlas_test._forced_options = {}
local r = Lint(broken, Model.build(broken))
check("lint flags a mistyped key", any(r.errors, "atlas_test_layer.*j_bloodstnoe"), true)
check("lint flags a key in the wrong category", any(r.errors, "banned_consumables names j_joker, a Joker"), true)
-- j_mp_hanging_chad spawns only where balanced/experimental/sandbox/wsob is on, and
-- listing it in a new layer's reworked_jokers indexes it there too, so it's in.
check("a rework listed by the ruleset's own layer is in its pool", any(r.warnings, "^ruleset atlas_test .*neither can appear"), false)

-- The same rework declared on the ruleset itself: rulesets don't index into pool gating.
local inert = load("./", api)
inert.MPAPI.Ruleset({
	key = "ruleset_mp_atlas_inert",
	banned_silent = { "j_hanging_chad" },
	reworked_jokers = { "j_mp_hanging_chad" },
})
inert.rulesets.ruleset_mp_atlas_inert._forced_options = {}
local r2 = Lint(inert, Model.build(inert))
check("lint flags a silent ban whose rework never spawns", any(r2.warnings, "^ruleset atlas_inert .*j_hanging_chad.*neither can appear"), true)

if failures > 0 then
	print(("%d failure(s)"):format(failures))
	os.exit(1)
end
print("all passed")
