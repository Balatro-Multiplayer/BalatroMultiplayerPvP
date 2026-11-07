-- Temporary Ouija: swaps vanilla Ouija for c_mp_ouija_temporary (convert all cards to one
-- rank, -1 hand size for 3 blinds instead of for the rest of the run).
MPAPI.Layer("ouija_temporary", {
	reworked_consumables = {
		"c_mp_ouija_temporary",
	},
	banned_silent = {
		"c_ouija",
	},
})
