-- Independent streams survive Balatro reseeding math.random for each run.
function PVP.new_rng()
	local generator
	return function(...)
		if not (love and love.math) then return math.random(...) end
		if not generator then
			local seed = os.time() + math.floor((love.timer.getTime() % 1) * 1e6)
			generator = love.math.newRandomGenerator(seed)
		end
		return generator:random(...)
	end
end
