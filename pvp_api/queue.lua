-- Matchmaking queue (ranked + casual), mirroring the Speedrun mod's _join_queue.
-- Casual queues by FORMAT (gamemode key, e.g. "pvp_nemesis"/"pvp_royale") via
-- PVP._join_queue below. Ranked queues by RULESET instead (always Nemesis-shaped)
-- via PVP._join_ranked_ruleset, with a ruleset-scoped ticket string (e.g.
-- "pvp_ranked_balanced") so the server's ELO ladder is per-ruleset. On a
-- match MPAPI auto-joins the matched lobby and fires lobby_ready; the host stamps
-- metadata and, after a short settle delay, starts the match.

-- Searching-state flag drives the Find Game button label (see the menu).
PVP._searching = false

-- Which single queue (if any) is currently active -- { kind = PVP.LobbyAccess.RANKED|CASUAL,
-- key = ruleset_key (ranked) or gamemode_key (casual) }, or nil when idle. PvP only ever tracks
-- one live matchmaking handle at a time (PVP._match_handle, singular -- unlike SPDRN's
-- per-game_mode _queue_handles table), so this is the one piece of state the Find Game pillar
-- page (ui/main_menu/find_game.lua) needs to know which single pillar, if any, should show
-- CANCEL instead of QUEUE. Set right before every PVP._show_searching(true) call below, cleared
-- right before every PVP._show_searching(false) call, so PVP._refresh_find_game_queue_ui (fired
-- from inside _show_searching) always sees the correct value at the moment it re-renders.
PVP._active_queue_id = nil

function PVP._show_searching(on)
	PVP._searching = on and true or false
	if PVP._show_searching_state then
		PVP._show_searching_state(on)
	end
	if PVP._refresh_find_game_queue_ui then
		PVP._refresh_find_game_queue_ui()
	end
end

function PVP._is_searching()
	return PVP._searching
end

-- True if `kind`+`key` (a ruleset_key for ranked, a gamemode_key for casual) is the one active
-- queue right now. Used by find_game.lua to decide which single pillar's SELECT button, if any,
-- should render as CANCEL.
function PVP._active_queue_matches(kind, key)
	return PVP._active_queue_id ~= nil and PVP._active_queue_id.kind == kind and PVP._active_queue_id.key == key
end

function PVP._is_queue_active()
	return PVP._active_queue_id ~= nil
end

function PVP._join_queue(kind, gamemode_key)
	gamemode_key = gamemode_key or PVP.GamemodeKey.PVP_NEMESIS
	PVP._pvp_kind = kind
	PVP.reset_ruleset_to_gamemode_default(gamemode_key)

	local gm = MPAPI.GameModes[gamemode_key]
	local mm_max_key = (kind == PVP.LobbyAccess.RANKED) and "ranked" or "public"
	local mm_max = (gm and gm.max_players and gm.max_players[mm_max_key]) or 2
	local game_mode = (kind == PVP.LobbyAccess.RANKED) and (PVP.LobbyAccess.RANKED_PREFIX .. gamemode_key) or gamemode_key

	local handle = MPAPI.matchmaking.queue({
		mod_id = PVP.id,
		game_mode = game_mode,
		min_players = 2,
		max_players = mm_max,
		-- Without this, MPAPI.matchmaking.queue() has no way to know this is a
		-- ranked attempt (it can't infer that from game_mode's "ranked:" prefix
		-- alone - see that function's own doc comment), so its launcher-anti-cheat
		-- gate silently never ran for a real ranked PvP queue attempt. Same gap
		-- already fixed on the SPDRN side (BalatroMultiplayerSpeed/objects/
		-- matchmaking/queue.lua) but never ported here.
		ranked = kind == PVP.LobbyAccess.RANKED,
		-- A Teams ticket says so, so a group queueing Teams can match it
		-- (MPAPI's _nakama_ticket: teams=1, even counts).
		teams = (PVP.PVP_GAMEMODES[gamemode_key] or {}).team_based or nil,
	})
	if not handle then
		sendWarnMessage("[pvp] failed to create matchmaking handle", "MULTIPLAYER")
		PVP._pvp_kind = nil
		return
	end
	PVP._match_handle = handle
	PVP._active_queue_id = { kind = kind, key = gamemode_key }
	PVP._show_searching(true)

	handle:on("error", function(err)
		sendWarnMessage("[pvp] matchmaking error: " .. tostring(err), "MULTIPLAYER")
		PVP._match_handle = nil
		PVP._active_queue_id = nil
		PVP._show_searching(false)
	end)

	handle:on("queued", function(pos)
		sendDebugMessage("[pvp] queued at " .. tostring(pos), "MULTIPLAYER")
		PVP._show_searching(true)
	end)

	handle:on("match_found", function(data)
		sendDebugMessage("[pvp] match_found " .. tostring(data and data.lobbyCode), "MULTIPLAYER")
	end)

	handle:on("lobby_ready", function(lobby)
		PVP._pvp_kind = kind
		PVP.setup_lobby_mirror(lobby)
		if lobby.is_host then
			lobby:set_metadata(PVP.pvp_lobby_metadata(gamemode_key, kind))
		end
		-- lobby_ready fires from inside the lobby's own 'connected' handler, so signal
		-- ready now; the host auto-starts once every client has reported in (see
		-- PVP.maybe_autostart). Re-announce a few times to cover the match-join race.
		PVP.signal_ready(true)
		PVP.start_ready_resync()
		PVP._active_queue_id = nil
		PVP._show_searching(false)
	end)

	handle:on("match_resolved", function(_ratings)
		PVP._match_handle = nil
	end)

	handle:on("left", function()
		PVP._match_handle = nil
		PVP._pvp_kind = nil
		PVP._active_queue_id = nil
		PVP._show_searching(false)
	end)
end

-- The finished match's placements for `player_ids`: the winner first, everyone else
-- second. `opts.team` makes `winner` a team id (Manhunt/Teams, resolved through
-- PVP.LOBBY.roster); `opts.draw` places everyone first. `opts.places` (id -> place)
-- overrides all of that: tied players share a place, and a tie for first is no win.
-- metric = each player's best PvP score (the leaderboard's season-best column).
function PVP.build_placements(player_ids, winner, opts)
	opts = opts or {}
	local tied_first = 0
	for _, id in ipairs(player_ids) do
		if opts.places and opts.places[id] == 1 then
			tied_first = tied_first + 1
		end
	end
	local placements = {}
	for _, id in ipairs(player_ids) do
		local place, performance
		if opts.places then
			place = opts.places[id] or #player_ids
			performance = (place == 1 and tied_first == 1) and 1 or 0
		else
			local won
			if opts.draw then
				won = true
			elseif opts.team then
				won = PVP.LOBBY.roster and PVP.LOBBY.roster[id] == winner
			else
				won = id == winner
			end
			place = won and 1 or 2
			performance = (won and not opts.draw) and 1 or 0
		end
		placements[#placements + 1] = {
			playerId = id,
			place = place,
			performance = performance,
			metric = (PVP.pvp_score_metric and PVP.pvp_score_metric(id)) or 0,
			metricText = PVP.pvp_score_text and PVP.pvp_score_text(id) or PVP.Score.ZERO,
		}
	end
	return placements
end

-- A server-refereed lobby: every client reports the same placements for the players
-- the game started with. Once per game.
function PVP.report_server_result(lobby, winner, opts)
	local started = lobby._game.started
	if not started or PVP._reported_run_id == started.run_id then
		return
	end
	PVP._reported_run_id = started.run_id
	local ids = {}
	for _, p in ipairs(started.players or {}) do
		ids[#ids + 1] = p.id
	end
	lobby:report_result(PVP.build_placements(ids, winner, opts), function(err)
		if err then
			sendWarnMessage("report_result error: " .. tostring(err), "MULTIPLAYER")
		end
	end)
end

-- A ranked ruleset's queue ticket, "ranked:pvp_ranked_<ruleset short>": the
-- game mode the server counts it under and the key of its rating board.
function PVP.ranked_ticket(ruleset_key)
	return PVP.LobbyAccess.RANKED_PREFIX .. "pvp_ranked_" .. ruleset_key:gsub("^ruleset_mp_", "")
end

-- Ranked-only entry point: ranked queues by RULESET directly now, not by a
-- per-ruleset gamemode key (see pvp_api/gamemodes.lua's PVP.PVP_GAMEMODES
-- header comment) -- ranked always plays Nemesis pairing regardless of which
-- ruleset is picked, so this bypasses
-- PVP.reset_ruleset_to_gamemode_default (which resolves off a gamemode key)
-- and stamps the ruleset straight onto PVP.LOBBY.config. The ticket string
-- passed as `game_mode` is ruleset-scoped (e.g. "ranked:pvp_ranked_balanced";
-- the server only treats a "ranked:"-prefixed game mode as ranked) so the
-- server's ELO ladder is per-ruleset, matching the separate leaderboard tabs
-- (ui/pvp_leaderboard.lua).
function PVP._join_ranked_ruleset(ruleset_key)
	local gamemode_key = PVP.GamemodeKey.PVP_NEMESIS
	PVP._pvp_kind = PVP.LobbyAccess.RANKED
	PVP.LOBBY.config.ruleset = ruleset_key
	PVP.LOBBY.config.gamemode = "gamemode_mp_attrition"

	local gm = MPAPI.GameModes[gamemode_key]
	local mm_max = (gm and gm.max_players and gm.max_players.ranked) or 2
	local ticket = PVP.ranked_ticket(ruleset_key)

	local handle = MPAPI.matchmaking.queue({
		mod_id = PVP.id,
		game_mode = ticket,
		min_players = 2,
		max_players = mm_max,
		ranked = true,
	})
	if not handle then
		sendWarnMessage("[pvp] failed to create matchmaking handle", "MULTIPLAYER")
		PVP._pvp_kind = nil
		return
	end
	PVP._match_handle = handle
	PVP._active_queue_id = { kind = PVP.LobbyAccess.RANKED, key = ruleset_key }
	PVP._show_searching(true)

	handle:on("error", function(err)
		sendWarnMessage("[pvp] matchmaking error: " .. tostring(err), "MULTIPLAYER")
		PVP._match_handle = nil
		PVP._active_queue_id = nil
		PVP._show_searching(false)
	end)

	handle:on("queued", function(pos)
		sendDebugMessage("[pvp] queued at " .. tostring(pos), "MULTIPLAYER")
		PVP._show_searching(true)
	end)

	handle:on("match_found", function(data)
		sendDebugMessage("[pvp] match_found " .. tostring(data and data.lobbyCode), "MULTIPLAYER")
	end)

	handle:on("lobby_ready", function(lobby)
		PVP._pvp_kind = PVP.LobbyAccess.RANKED
		PVP.setup_lobby_mirror(lobby)
		if lobby.is_host then
			lobby:set_metadata(PVP.pvp_lobby_metadata(gamemode_key, PVP.LobbyAccess.RANKED))
		end
		PVP.signal_ready(true)
		PVP.start_ready_resync()
		PVP._active_queue_id = nil
		PVP._show_searching(false)
	end)

	handle:on("match_resolved", function(_ratings)
		PVP._match_handle = nil
	end)

	handle:on("left", function()
		PVP._match_handle = nil
		PVP._pvp_kind = nil
		PVP._active_queue_id = nil
		PVP._show_searching(false)
	end)
end

function PVP._cancel_queue()
	if PVP._match_handle then
		PVP._match_handle:leave()
		PVP._match_handle = nil
	end
	PVP._pvp_kind = nil
	PVP._active_queue_id = nil
	PVP._show_searching(false)
end

-- ── Find Game entry point ─────────────────────────────────────────────────────
-- Routes to the pillar-based gamemode-select page (ui/main_menu/find_game.lua,
-- MPAPI.Page 'pvp_find_game', registered core.lua) instead of this file's old dedicated
-- Ranked/Casual -> ruleset grid overlay (removed 2026-09-08).
G.FUNCS.mp_pvp_find_game = function()
	MPAPI.pages.show("pvp_find_game")
end

G.FUNCS.mp_pvp_queue_ranked_balanced = function()
	G.FUNCS.exit_overlay_menu()
	PVP._join_ranked_ruleset("ruleset_mp_balanced")
end
G.FUNCS.mp_pvp_queue_ranked_expanded = function()
	G.FUNCS.exit_overlay_menu()
	PVP._join_ranked_ruleset("ruleset_mp_expanded")
end
G.FUNCS.mp_pvp_queue_ranked_vanilla = function()
	G.FUNCS.exit_overlay_menu()
	PVP._join_ranked_ruleset("ruleset_mp_vanilla")
end
G.FUNCS.mp_pvp_queue_ranked_majorleague = function()
	G.FUNCS.exit_overlay_menu()
	PVP._join_ranked_ruleset("ruleset_mp_majorleague")
end
G.FUNCS.mp_pvp_queue_ranked_smallworld = function()
	G.FUNCS.exit_overlay_menu()
	PVP._join_ranked_ruleset("ruleset_mp_smallworld")
end

G.FUNCS.mp_pvp_queue_casual_nemesis = function()
	G.FUNCS.exit_overlay_menu()
	PVP._join_queue(PVP.LobbyAccess.CASUAL, PVP.GamemodeKey.PVP_NEMESIS)
end
G.FUNCS.mp_pvp_queue_casual_royale = function()
	G.FUNCS.exit_overlay_menu()
	PVP._join_queue(PVP.LobbyAccess.CASUAL, "pvp_royale")
end
G.FUNCS.mp_pvp_queue_casual_manhunt = function()
	G.FUNCS.exit_overlay_menu()
	PVP._join_queue(PVP.LobbyAccess.CASUAL, "pvp_manhunt")
end
G.FUNCS.mp_pvp_queue_casual_teams = function()
	G.FUNCS.exit_overlay_menu()
	PVP._join_queue(PVP.LobbyAccess.CASUAL, "pvp_teams")
end
G.FUNCS.mp_pvp_queue_casual_smallworld = function()
	G.FUNCS.exit_overlay_menu()
	PVP._join_queue(PVP.LobbyAccess.CASUAL, "pvp_smallworld")
end

G.FUNCS.mp_pvp_cancel_queue = function()
	PVP._cancel_queue()
end
