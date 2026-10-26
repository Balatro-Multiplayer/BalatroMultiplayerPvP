-- Eeeee: ~40% of RNG poll keys per ante return a fixed value, not the seed-derived one.
MPAPI.Layer("eeeee", {
	calculate = function(self, context)
		if context.apply_bans then G.GAME.modifiers.mp_eeeee = true end
	end,
})

local pseudoseed_ref = pseudoseed
function pseudoseed(key, predict_seed)
	if G.GAME and G.GAME.modifiers and G.GAME.modifiers.mp_eeeee and not G._MP_UNSAVED_PRNG then
		G.GAME.mp_eeeee = G.GAME.mp_eeeee or {}
		local ante = G.GAME.round_resets.mp_real_ante or G.GAME.round_resets.ante
		if not G.GAME.mp_eeeee[ante .. "_" .. key] then
			local seed = pseudohash((G.GAME.pseudorandom.seed or "") .. ante .. "mp_eeeee_" .. key)
			local rng = love.math.newRandomGenerator(math.floor(seed * 2147483647))
			G.GAME.mp_eeeee[ante .. "_" .. key] = {
				poll = rng:random(),
				val = rng:random(),
			}
		end
		if G.GAME.mp_eeeee[ante .. "_" .. key].poll < 0.4 then return G.GAME.mp_eeeee[ante .. "_" .. key].val end
	end
	return pseudoseed_ref(key, predict_seed)
end
