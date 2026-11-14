-- Host and guest meet in a Nemesis lobby, play one PvP blind, and must agree afterwards.
-- Ante 2 is a fixture (P.jump_to_pvp); the PvP blind itself is played.
-- Run with scripts/run_pair.sh pair_pvp_blind.
local P = assert(SMODS.load_file("tests/scenarios/lib/pair.lua", "MultiplayerPvP"))()

return P.steps(
	P.connect(),
	P.lobby(PVP.GamemodeKey.PVP_NEMESIS),
	P.sync("in_lobby"),
	P.start(),
	P.reach_blind_select(),
	P.jump_to_pvp(2),
	P.play_pvp_blind(),
	P.sync("pvp_blind_resolved", 180),
	P.snapshot("after_pvp_1")
)
