-- texlua tests/unit/cashout_score_test.lua
-- Load the real HUD override and easing code without starting the game.
local events, rows = {}, {}
G = {
	FUNCS = {},
	GAME = { blind = { config = { blind = { key = "bl_mp_nemesis" } } } },
	P_BLINDS = { bl_mp_nemesis = {}, bl_small = { pos = {} } },
	E_MANAGER = { add_event = function(_, event) events[#events + 1] = event end },
}
Blind = {}
Event = function(spec) return spec end
PVP = {
	UI = {},
	GAME = {},
	UTILS = { get_nemesis_key = function() return "bl_small" end },
	is_pvp_boss = function()
		return G.GAME.blind.config.blind.key == "bl_mp_nemesis" or G.GAME.blind.pvp
	end,
}
MPAPI = {}
number_format = tostring
math.pow = math.pow or function(a, b) return a ^ b end
dofile((os.getenv("MPAPI_DIR") or "../BalatroMultiplayerAPI/") .. "lib/big_score.lua")
dofile("lib/score.lua")
add_round_eval_row = function(config)
	rows[#rows + 1] = { name = config.name, chips = G.GAME.blind.chip_text }
end
dofile("ui/game/blind_hud.lua")

local passed = 0
local function equal(got, want)
	assert(got == want, ("got %s, wanted %s"):format(tostring(got), tostring(want)))
end
local function setup(final_score)
	events, rows = {}, {}
	G.GAME.blind = { config = { blind = { key = "bl_mp_nemesis" } } }
	PVP.GAME = {
		enemy = { score = "0", real_score = "8000" },
		round_result = final_score and { enemy_score = final_score },
	}
end
local function cashout()
	add_round_eval_row({ name = "blind1" })
	return rows[#rows].chips
end
local function test(name, fn)
	fn()
	passed = passed + 1
	print("ok   " .. name)
end

test("cash-out uses the referee score while the opponent counter is still at 462", function()
	setup("8000")
	PVP.UI.ease_enemy_score("8000")
	local animation = events[1]
	animation.func(462)
	equal(PVP.GAME.enemy.score, "462")
	equal(cashout(), PVP.Score.display("8000"))
	animation.func(8000)
	equal(G.GAME.blind.chip_text, PVP.Score.display("8000"))
end)

test("a late stale display relay cannot overwrite the final cash-out score", function()
	setup("8000")
	PVP.GAME.enemy.real_score = "100"
	PVP.UI.ease_enemy_score("100")
	events[1].func(50)
	equal(cashout(), PVP.Score.display("8000"))
end)

test("a final zero score takes priority over stale nonzero displays", function()
	setup("0")
	PVP.GAME.enemy.score = "462"
	equal(cashout(), PVP.Score.display("0"))
end)

test("large final scores stay in score-text representation", function()
	setup("2e1000")
	equal(cashout(), PVP.Score.display("2e1000"))
end)

test("an older host falls back to the uneased score rather than the counter", function()
	setup()
	PVP.GAME.enemy.score = "462"
	equal(cashout(), PVP.Score.display("8000"))
end)

test("a result from an older protocol-1 host without scores uses the uneased fallback", function()
	setup()
	PVP.GAME.round_result = { scores = {} }
	PVP.GAME.enemy.score = "462"
	equal(cashout(), PVP.Score.display("8000"))
end)

test("PvP-marked normal blinds also use the final score without changing their atlas", function()
	setup("8000")
	G.GAME.blind.config.blind.key = "bl_small"
	G.GAME.blind.pvp = true
	equal(cashout(), PVP.Score.display("8000"))
	equal(#events, 0)
end)

test("non-PvP blind targets are untouched", function()
	setup("8000")
	G.GAME.blind.config.blind.key = "bl_small"
	G.GAME.blind.chip_text = "300"
	equal(cashout(), "300")
end)

test("other cash-out rows are untouched", function()
	setup("8000")
	G.GAME.blind.chip_text = "300"
	add_round_eval_row({ name = "hands" })
	equal(rows[1].name, "hands")
	equal(rows[1].chips, "300")
end)

print(("all %d cash-out score tests passed"):format(passed))
