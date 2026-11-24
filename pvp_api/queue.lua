-- Matchmaking queue (ranked + casual), mirroring the Speedrun mod's join.
-- Casual queues by FORMAT (gamemode key, e.g. "pvp_nemesis"/"pvp_royale") via
-- PVP.QUEUE.join below. Ranked queues by RULESET instead (always Nemesis-shaped)
-- via PVP.QUEUE.join_ranked, with a ruleset-scoped ticket string (e.g.
-- "pvp_ranked_balanced") so the server's ELO ladder is per-ruleset. On a
-- match MPAPI auto-joins the matched lobby and fires lobby_ready; the host stamps
-- metadata and, after a short settle delay, starts the match.

-- Searching-state flag drives the Find Game button label (see the menu).
PVP.QUEUE.searching = false

-- Which single queue (if any) is currently active -- { kind = PVP.LOBBY.Access.RANKED|CASUAL,
-- key = ruleset_key (ranked) or gamemode_key (casual) }, or nil when idle. PvP only ever tracks
-- one live matchmaking handle at a time (PVP.QUEUE.match_handle, singular -- unlike SPDRN's
-- per-game_mode _queue_handles table), so this is the one piece of state the Find Game pillar
-- page (ui/main_menu/find_game.lua) needs to know which single pillar, if any, should show
-- CANCEL instead of QUEUE. Set right before every PVP.UI.queue.show_searching(true) call below, cleared
-- right before every PVP.UI.queue.show_searching(false) call, so PVP.UI.find_game.refresh_queue (fired
-- from inside UI.queue.show_searching) always sees the correct value at the moment it re-renders.
PVP.QUEUE.active_id = nil

function PVP.UI.queue.show_searching(on)
	PVP.QUEUE.searching = on and true or false
	if PVP.UI.queue.hud then
		if on then
			PVP.UI.queue.hud.start(PVP.QUEUE.active_id, PVP.QUEUE.match_handle)
		else
			PVP.UI.queue.hud.stop()
		end
	end
	if PVP.UI.queue.show_searching_state then
		PVP.UI.queue.show_searching_state(on)
	end
	if PVP.UI.find_game.refresh_queue then
		PVP.UI.find_game.refresh_queue()
	end
end

-- True if `kind`+`key` (a ruleset_key for ranked, a gamemode_key for casual) is the one active
-- queue right now. Used by find_game.lua to decide which single pillar's SELECT button, if any,
-- should render as CANCEL.
function PVP.QUEUE.active_matches(kind, key)
	return PVP.QUEUE.active_id ~= nil and PVP.QUEUE.active_id.kind == kind and PVP.QUEUE.active_id.key == key
end

function PVP.QUEUE.is_active()
	return PVP.QUEUE.active_id ~= nil
end

function PVP.QUEUE.join(kind, gamemode_key)
	gamemode_key = gamemode_key or PVP.RULES.GamemodeKey.PVP_NEMESIS
	PVP.LOBBY.kind = kind
	PVP.RULES.reset_to_gamemode_default(gamemode_key)

	local gm = MPAPI.GameModes[gamemode_key]
	local mm_max_key = (kind == PVP.LOBBY.Access.RANKED) and "ranked" or "public"
	local mm_max = (gm and gm.max_players and gm.max_players[mm_max_key]) or 2
	local game_mode = (kind == PVP.LOBBY.Access.RANKED) and (PVP.LOBBY.Access.RANKED_PREFIX .. gamemode_key) or gamemode_key

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
		ranked = kind == PVP.LOBBY.Access.RANKED,
		-- A Teams ticket says so, so a group queueing Teams can match it
		-- (MPAPI's _nakama_ticket: teams=1, even counts).
		teams = (PVP.RULES.MODES[gamemode_key] or {}).team_based or nil,
	})
	if not handle then
		sendWarnMessage("[pvp] failed to create matchmaking handle", "MULTIPLAYER")
		PVP.LOBBY.kind = nil
		return
	end
	PVP.QUEUE.match_handle = handle
	PVP.QUEUE.active_id = { kind = kind, key = gamemode_key }
	PVP.UI.queue.show_searching(true)

	handle:on("error", function(err)
		sendWarnMessage("[pvp] matchmaking error: " .. tostring(err), "MULTIPLAYER")
		-- An error after match_found is a failed lobby join
		PVP.UI.queue.hud.dismiss_reveal()
		PVP.QUEUE.match_handle = nil
		PVP.QUEUE.active_id = nil
		PVP.UI.queue.show_searching(false)
		PVP.UI.refusal.show(err)
	end)

	handle:on("queued", function(pos)
		PVP.match_log("debug", "[pvp] queued at " .. tostring(pos))
		PVP.UI.queue.show_searching(true)
	end)

	handle:on("match_found", function(data)
		PVP.match_log("debug", "[pvp] match_found " .. tostring(data and data.lobbyCode))
		PVP.UI.queue.hud.match_found()
	end)

	handle:on("lobby_ready", function(lobby)
		PVP.UI.queue.hud.lobby_ready(lobby)
		PVP.LOBBY.kind = kind
		PVP.LOBBY.mirror(lobby)
		-- After the match: back to the Find Game tab it was queued from.
		PVP.LOBBY.set_exit_page(lobby, "pvp_find_game", { category = kind == PVP.LOBBY.Access.RANKED and "ranked" or "casual" })
		if lobby.is_host then
			PVP.UI.lobby.send_settings(lobby, PVP.LOBBY.metadata(gamemode_key, kind))
		end
		-- Ready goes up from the lobby view (pvp_api/ui/lobby.lua); the host auto-starts once the view shows all ready.
		PVP.QUEUE.active_id = nil
		PVP.UI.queue.show_searching(false)
	end)

	handle:on("match_resolved", function(_ratings)
		PVP.QUEUE.match_handle = nil
	end)

	handle:on("left", function()
		PVP.UI.queue.hud.dismiss_reveal()
		PVP.QUEUE.match_handle = nil
		PVP.LOBBY.kind = nil
		PVP.QUEUE.active_id = nil
		PVP.UI.queue.show_searching(false)
	end)
end

-- A ranked ruleset's queue ticket, "ranked:pvp_ranked_<ruleset short>": the
-- game mode the server counts it under and the key of its rating board.
function PVP.QUEUE.ranked_ticket(ruleset_key)
	return PVP.LOBBY.Access.RANKED_PREFIX .. "pvp_ranked_" .. ruleset_key:gsub("^ruleset_mp_", "")
end

-- Ranked-only entry point: ranked queues by RULESET directly now, not by a
-- per-ruleset gamemode key (see pvp_api/gamemodes.lua's PVP.RULES.MODES
-- header comment) -- ranked always plays Nemesis pairing regardless of which
-- ruleset is picked, so this bypasses
-- PVP.RULES.reset_to_gamemode_default (which resolves off a gamemode key)
-- and stamps the ruleset straight onto PVP.LOBBY.config. The ticket string
-- passed as `game_mode` is ruleset-scoped (e.g. "ranked:pvp_ranked_balanced";
-- the server only treats a "ranked:"-prefixed game mode as ranked) so the
-- server's ELO ladder is per-ruleset, matching the separate leaderboard tabs
-- (ui/pvp_leaderboard.lua).
function PVP.QUEUE.join_ranked(ruleset_key)
	local gamemode_key = PVP.RULES.GamemodeKey.PVP_NEMESIS
	PVP.LOBBY.kind = PVP.LOBBY.Access.RANKED
	PVP.LOBBY.config.ruleset = ruleset_key
	PVP.LOBBY.config.gamemode = "gamemode_mp_attrition"

	local gm = MPAPI.GameModes[gamemode_key]
	local mm_max = (gm and gm.max_players and gm.max_players.ranked) or 2
	local ticket = PVP.QUEUE.ranked_ticket(ruleset_key)

	local handle = MPAPI.matchmaking.queue({
		mod_id = PVP.id,
		game_mode = ticket,
		min_players = 2,
		max_players = mm_max,
		ranked = true,
	})
	if not handle then
		sendWarnMessage("[pvp] failed to create matchmaking handle", "MULTIPLAYER")
		PVP.LOBBY.kind = nil
		return
	end
	PVP.QUEUE.match_handle = handle
	PVP.QUEUE.active_id = { kind = PVP.LOBBY.Access.RANKED, key = ruleset_key }
	PVP.UI.queue.show_searching(true)

	handle:on("error", function(err)
		sendWarnMessage("[pvp] matchmaking error: " .. tostring(err), "MULTIPLAYER")
		-- An error after match_found is a failed lobby join
		PVP.UI.queue.hud.dismiss_reveal()
		PVP.QUEUE.match_handle = nil
		PVP.QUEUE.active_id = nil
		PVP.UI.queue.show_searching(false)
		PVP.UI.refusal.show(err)
	end)

	handle:on("queued", function(pos)
		PVP.match_log("debug", "[pvp] queued at " .. tostring(pos))
		PVP.UI.queue.show_searching(true)
	end)

	handle:on("match_found", function(data)
		PVP.match_log("debug", "[pvp] match_found " .. tostring(data and data.lobbyCode))
		PVP.UI.queue.hud.match_found()
	end)

	handle:on("lobby_ready", function(lobby)
		PVP.UI.queue.hud.lobby_ready(lobby)
		PVP.LOBBY.kind = PVP.LOBBY.Access.RANKED
		PVP.LOBBY.mirror(lobby)
		PVP.LOBBY.set_exit_page(lobby, "pvp_find_game", { category = "ranked" })
		if lobby.is_host then
			PVP.UI.lobby.send_settings(lobby, PVP.LOBBY.metadata(gamemode_key, PVP.LOBBY.Access.RANKED))
		end
		PVP.QUEUE.active_id = nil
		PVP.UI.queue.show_searching(false)
	end)

	handle:on("match_resolved", function(_ratings)
		PVP.QUEUE.match_handle = nil
	end)

	handle:on("left", function()
		PVP.UI.queue.hud.dismiss_reveal()
		PVP.QUEUE.match_handle = nil
		PVP.LOBBY.kind = nil
		PVP.QUEUE.active_id = nil
		PVP.UI.queue.show_searching(false)
	end)
end

function PVP.QUEUE.cancel()
	if PVP.QUEUE.match_handle then
		PVP.QUEUE.match_handle:leave()
		PVP.QUEUE.match_handle = nil
	end
	PVP.LOBBY.kind = nil
	PVP.QUEUE.active_id = nil
	PVP.UI.queue.show_searching(false)
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
	PVP.QUEUE.join_ranked("ruleset_mp_balanced")
end
G.FUNCS.mp_pvp_queue_ranked_expanded = function()
	G.FUNCS.exit_overlay_menu()
	PVP.QUEUE.join_ranked("ruleset_mp_expanded")
end
G.FUNCS.mp_pvp_queue_ranked_vanilla = function()
	G.FUNCS.exit_overlay_menu()
	PVP.QUEUE.join_ranked("ruleset_mp_vanilla")
end
G.FUNCS.mp_pvp_queue_ranked_majorleague = function()
	G.FUNCS.exit_overlay_menu()
	PVP.QUEUE.join_ranked("ruleset_mp_majorleague")
end
G.FUNCS.mp_pvp_queue_ranked_smallworld = function()
	G.FUNCS.exit_overlay_menu()
	PVP.QUEUE.join_ranked("ruleset_mp_smallworld")
end

G.FUNCS.mp_pvp_queue_casual_nemesis = function()
	G.FUNCS.exit_overlay_menu()
	PVP.QUEUE.join(PVP.LOBBY.Access.CASUAL, PVP.RULES.GamemodeKey.PVP_NEMESIS)
end
G.FUNCS.mp_pvp_queue_casual_royale = function()
	G.FUNCS.exit_overlay_menu()
	PVP.QUEUE.join(PVP.LOBBY.Access.CASUAL, "pvp_royale")
end
G.FUNCS.mp_pvp_queue_casual_manhunt = function()
	G.FUNCS.exit_overlay_menu()
	PVP.QUEUE.join(PVP.LOBBY.Access.CASUAL, "pvp_manhunt")
end
G.FUNCS.mp_pvp_queue_casual_teams = function()
	G.FUNCS.exit_overlay_menu()
	PVP.QUEUE.join(PVP.LOBBY.Access.CASUAL, "pvp_teams")
end
G.FUNCS.mp_pvp_queue_casual_smallworld = function()
	G.FUNCS.exit_overlay_menu()
	PVP.QUEUE.join(PVP.LOBBY.Access.CASUAL, "pvp_smallworld")
end

G.FUNCS.mp_pvp_cancel_queue = function()
	PVP.QUEUE.cancel()
end
