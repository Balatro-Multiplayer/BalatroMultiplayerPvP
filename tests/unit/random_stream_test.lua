-- Standalone: luajit tests/unit/random_stream_test.lua
PVP = {}
dofile("lib/_random.lua")

local streams = {}
love = {
	timer = {
		getTime = function()
			return 1.25
		end,
	},
	math = {
		newRandomGenerator = function(seed)
			local stream = { seed = seed, draws = 0 }
			function stream:random(n)
				self.draws = self.draws + 1
				self.limit = n
				return n or self.draws / 10
			end
			streams[#streams + 1] = stream
			return stream
		end,
	},
}
local board, recipe = PVP.new_rng(), PVP.new_rng()
assert(#streams == 0, "generators are lazy")
assert(board() == 0.1)
assert(recipe(3) == 3)
assert(#streams == 2, "each consumer gets its own generator")
math.randomseed(123)
assert(board() == 0.2, "run reseeding does not restart the stream")
assert(streams[2].draws == 1, "board draws do not advance the recipe stream")
assert(streams[2].limit == 3, "integer bounds reach the generator")
assert(#streams == 2, "each generator is seeded only once")

love = nil
local fallback = PVP.new_rng()
assert(fallback(1) == 1, "standalone tests can use math.random")
print("ok")
