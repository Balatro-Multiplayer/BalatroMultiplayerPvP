-- Run from the repo root: lua5.4 tests/unit/preview_expected_dollars_test.lua
-- Load the actual Preview utils with minimal game stubs; check expected money and its formatting.
G = { GAME = { probabilities = { normal = 1 } } }
FN = { SIM = { JOKERS = {} }, PRE = {} }
dofile("compatibility/Preview/UtilsSimulate.lua")
dofile("compatibility/Preview/UtilsPreview.lua")

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

-- What the preview shows: '~' when min and max differ, so luck is involved
local function preview(normal, lucky_cards)
	G.GAME.probabilities.normal = normal
	FN.SIM.running = { min = { dollars = 0 }, exact = { dollars = 0 }, max = { dollars = 0 }, expected_dollars = 0 }
	for _ = 1, lucky_cards do
		FN.SIM.add_dollars(FN.SIM.get_probabilistic_extremes(0.99, 15, 20, 0)) -- Lucky Card: $20 at 1 in 15
	end
	FN.SIM.add_dollars(3) -- Gold Seal
	local run = FN.SIM.running
	return FN.PRE.format_dollars(run.expected_dollars, run.min.dollars ~= run.max.dollars)
end

check("fixed money is guaranteed", preview(1, 0), "+$3")
check("lucky card is weighted by its odds", preview(1, 1), "~$4.33")
check("oops all 6s doubles the odds", preview(2, 1), "~$5.67")
check("guaranteed odds pay in full", preview(15, 1), "+$23")

G.GAME.probabilities.normal = 1
local exact, min, max = FN.SIM.get_probabilistic_extremes(0.99, 15, 20, 0)
check("exact/min/max unchanged", ("%s/%s/%s"):format(exact, min, max), "0/0/20")

check("whole dollars", FN.PRE.format_dollars(10), "+$10")
check("zero", FN.PRE.format_dollars(0), "+$0")
check("negative", FN.PRE.format_dollars(-3), "-$3")
check("negative with luck", FN.PRE.format_dollars(-1.5, true), "~-$1.5")
check("trailing zero trimmed", FN.PRE.format_dollars(1.5), "+$1.5")

if failures > 0 then os.exit(1) end
