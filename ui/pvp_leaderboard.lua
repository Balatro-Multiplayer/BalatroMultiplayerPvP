-- PvP leaderboard overlay, built on the generic MPAPI.ui_leaderboard. Tabs are the
-- ruleset-scoped ranked ticket strings (pvp_api/queue.lua's PVP._join_ranked_ruleset
-- builds these same "pvp_ranked_<ruleset>" strings); the metric is season-best single-blind
-- score (kind='score', higher is better). Pagination / own-rank footer / tabs live in MPAPI.

local DEFAULT_TAB = "pvp_ranked_balanced"

-- Built lazily on first open (G.C colours + localization must be ready; this file
-- loads during the mod's main_file pass, before the game is fully up).
local _leaderboard
local function get_leaderboard()
	if _leaderboard then
		return _leaderboard
	end
	_leaderboard = MPAPI.ui_leaderboard({
		tabs = {
			{ key = "pvp_ranked_balanced", label = PVP.ruleset_display_name(PVP.RulesetKey.BALANCED), colour = G.C.RED },
			{ key = "pvp_ranked_expanded", label = PVP.ruleset_display_name(PVP.RulesetKey.EXPANDED), colour = G.C.ORANGE },
			{ key = "pvp_ranked_vanilla", label = PVP.ruleset_display_name(PVP.RulesetKey.VANILLA), colour = G.C.BLUE },
			{ key = "pvp_ranked_majorleague", label = "MLBa", colour = G.C.BLACK },
			{ key = "pvp_ranked_smallworld", label = PVP.ruleset_display_name(PVP.RulesetKey.SMALLWORLD), colour = G.C.GREEN },
		},
		columns = {
			{ header = function() return localize("k_rating_cap") end, colour = G.C.BLUE, width = 0.95, value = function(e) return tostring(e.rating or "?") end },
			{ header = function() return localize("k_best_score_cap") end, colour = G.C.PURPLE, width = 1.25, value = function(e) return e.seasonBest and PVP.Score.parse(tostring(e.seasonBest)) and PVP.Score.display(tostring(e.seasonBest)) or "-" end },
			{ header = "W", header_colour = G.C.GREEN, colour = G.C.GREEN, width = 0.5, value = function(e) return tostring(e.wins or 0) end },
			{ header = "L", header_colour = G.C.RED, colour = G.C.RED, width = 0.5, value = function(e) return tostring(e.losses or 0) end },
		},
		empty_text = "No ranked players yet.",
		web_url = "https://new.balatromp.com/leaderboards",
		-- The tab key IS the exact ranked matchmaking ticket string ranked queueing
		-- passes as `game_mode` (PVP._join_ranked_ruleset, pvp_api/queue.lua's
		-- "pvp_ranked_<ruleset>" tickets, e.g. "pvp_ranked_balanced") -- no separate
		-- "ranked:" prefix needed here, unlike the old per-gamemode-key ranked queue
		-- convention this replaced (game_mode was a bare gamemode key there, so the
		-- prefix was the only thing distinguishing it as ranked).
		fetch = function(tab_key, cb)
			MPAPI.matchmaking.get_leaderboard(PVP.id, tab_key, nil, {}, cb)
		end,
	})
	return _leaderboard
end

PVP.open_leaderboard = function(gamemode_key, page)
	get_leaderboard():open(gamemode_key or DEFAULT_TAB, page)
end

G.FUNCS.mp_pvp_open_leaderboard = function()
	get_leaderboard():open()
end
