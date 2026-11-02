-- Host and guest meet in a lobby, play one PvP blind, and must agree afterwards.
-- Run with scripts/run_pair.sh pair_pvp_blind. TODO steps fail until filled in,
-- but barriers and snapshots still run, so the plumbing is exercised end to end.
local P = assert(SMODS.load_file("tests/scenarios/lib/pair.lua", "MultiplayerPvP"))()

local function todo(S, what)
	S.check(false, "TODO " .. P.role .. ": " .. what)
end

return {
	{
		until_ = function()
			return MPAPI.is_ready()
		end,
		run = function(S)
			S.check(true, P.role .. " ready")
			todo(S, "log in to the server without Steam")
		end,
	},
	P.only("host", {
		run = function(S)
			todo(S, "create a lobby")
			P.put("lobby", "TODO")
		end,
	}),
	P.only("guest", {
		until_ = function()
			return P.get("lobby") ~= nil
		end,
		run = function(S)
			todo(S, "join lobby " .. P.get("lobby"))
		end,
	}),
	P.sync("in_lobby"),
	P.only("host", {
		run = function(S)
			todo(S, "start the run")
		end,
	}),
	P.sync("pvp_blind_resolved", 120),
	P.snapshot("after_pvp_1"),
}
