-- Playing a tournament match: no joining or leaving lobbies by hand.
--
-- When both players are ready, the server makes the match's PvP lobby (one
-- per match, reused for every game of a series) and sends TOURNAMENT_LOBBY
-- (113) with its code. This file then:
--   * joins that lobby (from the menus), as kind TOURNAMENT -- which plays
--     like a matchmade game (PVP.is_matchmaking): everyone readies, the host
--     starts, and the Draft runs unless the round locks the deck and stake;
--   * for the next game of a series, when the player is already in the
--     lobby, just readies again so the host starts it;
--   * the host applies the round's settings (ruleset, game type, deck);
--   * a ban-and-pick round drafts from the round's own pool (its decks,
--     Cocktails and stakes); the server decides who bans first from the
--     round's ban order (tournament/lobby_draft.ts);
--   * between games the lobby shows the series and its ready-up
--     (PVP.build_tournament_lobby_status, in the matchmade status panel);
--   * when the server closes the lobby after the match, the player lands on
--     the tournament's screen (MPAPI.set_lobby_exit_page), also when it
--     closes during the run.

PVP.TUI = PVP.TUI or {}
local TUI = PVP.TUI

-- The tournament match the current lobby plays: { id, match_id, code }.
PVP._tournament_lobby = PVP._tournament_lobby or nil

local function in_menus()
	return G.STAGE == G.STAGES.MAIN_MENU
end

-- Defined further down; the series panel (above them) calls it.
local ensure_ticking

local function current_code()
	local lobby = MPAPI.get_current_lobby()
	return lobby and lobby.code or nil
end

-- The round's settings the server put in the lobby (metadata.tournament).
local function round_of(lobby)
	local meta = lobby and lobby:get_metadata() or {}
	return type(meta.tournament) == "table" and meta.tournament or nil
end

-- Ban and pick ----------------------------------------------------------------

local DRAFT_TILES = 9 -- PvP's board (gamemodes.lua BAN_PICK)

-- The round's deck rule when it is ban and pick.
local function draft_rule(round)
	local deck = round and type(round.deck) == "table" and round.deck or nil
	return deck and deck.kind == "draft" and deck or nil
end

-- The pool as tile keys ("cocktail:2" for a pool Cocktail) and stake numbers.
local function pool_of(deck)
	local keys, stakes = {}, {}
	for _, key in ipairs(deck.decks or {}) do
		if G.P_CENTERS[key] then
			keys[#keys + 1] = key
		end
	end
	if G.P_CENTERS.b_mp_cocktail then
		for i, recipe in ipairs(deck.cocktails or {}) do
			if type(recipe) == "table" then
				keys[#keys + 1] = "cocktail:" .. i
			end
		end
	end
	for _, s in ipairs(deck.stakes or {}) do
		if G.P_CENTER_POOLS.Stake[s] then
			stakes[#stakes + 1] = s
		end
	end
	return keys, stakes
end

-- A board of tiles from the pool: { id, key, stake } (a Cocktail tile is the
-- Cocktail deck with `cocktail` = its place in the round's list).
local function tiles(keys, stakes, size)
	local board = PVP.DRAFT.board(keys, stakes, { size = size })
	for _, tile in ipairs(board) do
		local i = tostring(tile.key):match("^cocktail:(%d+)$")
		if i then
			tile.key = "b_mp_cocktail"
			tile.cocktail = tonumber(i)
		end
	end
	return board
end

-- The Draft for a ban-and-pick round: PvP's own Draft (base: its look and
-- schedule) drawn from the round's pool. 9 tiles and the usual schedule, or
-- with a smaller pool every tile and single bans down to one. nil when the
-- round isn't ban and pick, or its pool is one deck and stake (no Draft).
function PVP.tournament_ban_pick(base, meta)
	local deck = draft_rule(meta and type(meta.tournament) == "table" and meta.tournament or nil)
	if not deck then
		return nil
	end
	local keys, stakes = pool_of(deck)
	local total = #keys * #stakes
	if total < 2 then
		return nil
	end
	local config = {}
	for k, v in pairs(base or {}) do
		config[k] = v
	end
	config.id = config.id or PVP.SETUP.Step.DRAFT
	config.tile_order = config.tile_order or PVP.DRAFT.tile_order
	local size = math.min(DRAFT_TILES, total)
	config.pool_size = size
	config.build_pool = function()
		return tiles(keys, stakes, size)
	end
	if size < DRAFT_TILES or not config.schedule then
		config.schedule = nil
		config.keep = 1
	end
	return config
end

-- A ban-and-pick round whose pool is one deck and stake: that tile.
local function single_tile(round)
	local deck = draft_rule(round)
	if not deck then
		return nil
	end
	local keys, stakes = pool_of(deck)
	if #keys * #stakes ~= 1 then
		return nil
	end
	return tiles(keys, stakes, 1)[1]
end

-- The picked tile is a pool Cocktail: play the mix the organiser chose. Every
-- client applies it from the round; returns it so the host also publishes it
-- (the metadata mirror clears a mix the lobby metadata doesn't carry).
function PVP.tournament_pick_cocktail(picked, meta)
	local deck = draft_rule(meta and type(meta.tournament) == "table" and meta.tournament or nil)
	local recipe = deck and type(picked) == "table" and picked.cocktail and (deck.cocktails or {})[picked.cocktail]
	if type(recipe) == "table" and type(recipe.decks) == "table" then
		local mix = { name = recipe.name, decks = recipe.decks }
		PVP.receive_cocktail_recipe(mix)
		return mix
	end
	return nil
end

-- The host stamps the PvP metadata from the round's settings; the metadata
-- mirror then applies it on every client.
local function apply_round(lobby)
	local round = round_of(lobby)
	if not round or not lobby.is_host then
		return
	end
	local gamemode_key = round.gameMode or PVP.GamemodeKey.PVP_NEMESIS
	local def = PVP.PVP_GAMEMODES[gamemode_key] or PVP.PVP_GAMEMODES.pvp_nemesis
	PVP._pvp_gamemode = gamemode_key
	PVP.LOBBY.config.gamemode = def.gamemode
	PVP.LOBBY.config.ruleset = round.ruleset or def.ruleset
	local deck = type(round.deck) == "table" and round.deck or nil
	-- A pool of one deck and stake is just that deck and stake.
	local single = single_tile(round)
	if single then
		local recipe = single.cocktail and deck.cocktails[single.cocktail]
		deck = { kind = "locked", deck = single.key, stake = single.stake, cocktail = recipe }
	end
	if deck and deck.kind == "locked" then
		local center = G.P_CENTERS[deck.deck]
		PVP.LOBBY.config.back = center and center.name or PVP.LOBBY.config.back
		PVP.LOBBY.config.stake = tonumber(deck.stake) or 1
	end
	local meta = PVP.pvp_lobby_metadata(gamemode_key, PVP.LobbyAccess.TOURNAMENT)
	-- The Cocktail mixes the decks the organiser chose (the same on every
	-- client: objects/decks/ZZ_cocktail.lua reads cocktail_recipe).
	if deck and type(deck.cocktail) == "table" and type(deck.cocktail.decks) == "table" then
		meta.cocktail_recipe = { name = deck.cocktail.name, decks = deck.cocktail.decks }
	end
	lobby:set_metadata(meta)
end

-- run_lifecycle.lua asks this before the Setup: a locked deck and stake mean
-- no Draft.
function PVP.tournament_setup_plan(plan, meta)
	local round = meta and type(meta.tournament) == "table" and meta.tournament or nil
	if round and type(round.deck) == "table" and round.deck.kind == "locked" then
		plan.draft = false
	elseif draft_rule(round) then
		-- Ban and pick: a Draft from the round's pool, unless there is only one
		-- tile (then it is played like a locked deck, apply_round).
		local lobby = MPAPI.get_current_lobby()
		plan.draft = single_tile(round) == nil and lobby ~= nil and MPAPI.has_server_referee(lobby)
	end
	return plan
end

-- Shows the lobby page if the player isn't on it. MPAPI switches pages when a
-- lobby connects, but only for the mod in focus; in a live test one of two
-- clients stayed on the tournament screen while its game started. Never from
-- a run.
function PVP.show_tournament_lobby_page()
	if in_menus() and MPAPI.get_current_lobby() and MPAPI.pages.current_key() ~= "pvp_lobby" then
		PVP.match_log("debug", "Tournament: showing the lobby page (was " .. tostring(MPAPI.pages.current_key()) .. ")")
		MPAPI.pages.show("pvp_lobby", {})
	end
end

local function ready_up_in_lobby()
	PVP.signal_ready(true)
	PVP.start_ready_resync()
	if PVP.lobby and PVP.lobby.refresh_mm_status then
		PVP.lobby.refresh_mm_status()
	end
end

-- Where the player lands once the match's lobby closes, also after the run it
-- closed during (MPAPI.set_lobby_exit_page): the tournament's screen when PvP
-- has it (ui/tournament/screen.lua), else the PvP main menu.
local function set_exit_page(lobby, id)
	if not MPAPI.set_lobby_exit_page then
		return
	end
	if MPAPI.Pages and MPAPI.Pages.pvp_tournament then
		MPAPI.set_lobby_exit_page(lobby, "pvp_tournament", { id = id })
	else
		MPAPI.set_lobby_exit_page(lobby, "pvp_main_menu")
	end
end

-- TOURNAMENT_LOBBY: { tournamentId, matchId, code, game, wins, reused }.
function PVP.tournament_lobby_ready(content)
	if not content or not content.code then
		return
	end
	-- Already in it (the next game of a series): ready, the host starts.
	if current_code() == content.code then
		PVP._tournament_lobby = { id = content.tournamentId, match_id = content.matchId, code = content.code }
		ready_up_in_lobby()
		return
	end
	-- Only from the menus, and not from inside another lobby: never pull a
	-- player out of what they are doing (the banner and JOIN GAME remain).
	if not in_menus() or MPAPI.get_current_lobby() then
		return
	end
	if PVP._is_queue_active and PVP._is_queue_active() and PVP._cancel_queue then
		PVP._cancel_queue()
	end
	PVP.match_log("debug", "Tournament: joining lobby " .. tostring(content.code) .. " from page " .. tostring(MPAPI.pages.current_key()))
	local lobby = MPAPI.join_lobby(PVP.id, content.code)
	if not lobby then
		sendWarnMessage("Tournament: could not join lobby " .. tostring(content.code), "MULTIPLAYER")
		return
	end
	PVP._tournament_lobby = { id = content.tournamentId, match_id = content.matchId, code = content.code }
	PVP._pvp_kind = PVP.LobbyAccess.TOURNAMENT
	PVP.setup_lobby_mirror(lobby)
	set_exit_page(lobby, content.tournamentId)
	lobby:on(MPAPI.LobbyEvent.CONNECTED, function()
		PVP.match_log("debug", "Tournament: lobby connected (host: " .. tostring(lobby.is_host) .. ", page: " .. tostring(MPAPI.pages.current_key()) .. ")")
		PVP._pvp_kind = PVP.LobbyAccess.TOURNAMENT
		-- The match (and its Draft) is on: the ranked match-found cue, so a
		-- player who readied and looked away hears it.
		if PVP._play_match_found_sound then
			PVP._play_match_found_sound()
		end
		apply_round(lobby)
		ready_up_in_lobby()
		-- After MPAPI's own page switch has had its chance.
		G.E_MANAGER:add_event(Event({
			trigger = "after",
			delay = 0.2,
			timer = "REAL",
			blockable = false,
			blocking = false,
			func = function()
				PVP.show_tournament_lobby_page()
				return true
			end,
		}))
	end)
	-- The server closes the lobby once the match is decided; MPAPI shows the
	-- exit page.
	lobby:on(MPAPI.LobbyEvent.DISCONNECTED, function()
		PVP._tournament_lobby = nil
	end)
end

-- READY / UNREADY for the player's match (the series panel; the tournament
-- screen uses them too).
G.FUNCS.mp_pvp_tournament_ready = function(e)
	local id = e.config.ref_table and e.config.ref_table.id
	if id then
		PVP.Tournaments.ready(id, true)
	end
end

G.FUNCS.mp_pvp_tournament_unready = function(e)
	local id = e.config.ref_table and e.config.ref_table.id
	if id then
		PVP.Tournaments.ready(id, false)
	end
end

-- The tournament screen's JOIN GAME (a missed notification).
G.FUNCS.mp_pvp_tournament_join_game = function(e)
	local ref = e.config.ref_table
	if ref and ref.code then
		PVP.tournament_lobby_ready({ tournamentId = ref.id, matchId = ref.match_id, code = ref.code })
	end
end

-- The match the lobby plays, from the tournament's view.
local function lobby_match()
	local tl = PVP._tournament_lobby
	local view = tl and PVP.Tournaments.state.views[tl.id]
	if not view or not view.bracket then
		return nil, view
	end
	for _, m in ipairs(view.bracket) do
		if m.id == tl.match_id then
			return m, view
		end
	end
	return nil, view
end

local status_live = { text = "", colour = { 1, 1, 1, 1 } }

-- The series panel shown in the lobby between games (inside the matchmade
-- status panel, ui/lobby/controls.lua).
function PVP.build_tournament_lobby_status()
	ensure_ticking()
	local m, view = lobby_match()
	local rows = {}
	if view then
		rows[#rows + 1] = TUI.name_line(view.summary, 0.45)
	end
	if not m then
		rows[#rows + 1] = TUI.message(PVP.T("k_tn_lobby_starting_match"), G.C.UI.TEXT_LIGHT)
		return rows
	end
	local a = type(m.players[1]) == "table" and m.players[1].name or "?"
	local b = type(m.players[2]) == "table" and m.players[2].name or "?"
	rows[#rows + 1] = TUI.title(string.format("%s   %d - %d   %s", a, m.wins[1] or 0, m.wins[2] or 0, b), G.C.UI.TEXT_LIGHT, 0.5)
	if (m.bestOf or 1) > 1 then
		rows[#rows + 1] = TUI.message(PVP.T("k_tn_best_of", m.bestOf))
	end
	local clock = m.clock
	local side = PVP.Tournaments.my_side(m)
	if m.status == "done" then
		rows[#rows + 1] = TUI.message(PVP.T("k_tn_lobby_match_over"), G.C.GREEN)
	elseif clock and clock.phase == "ready_up" then
		local readied = side and clock.ready and clock.ready[side]
		local left = clock.deadline and PVP.TournamentTime.clock(clock.deadline) or nil
		TUI.set_live(status_live, left and PVP.T("k_tn_lobby_next_game_left", left) or PVP.T("k_tn_lobby_next_game"), readied and G.C.GREEN or G.C.GOLD)
		rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.06 }, nodes = { TUI.live_text(status_live, 0.42) } }
		local id = PVP._tournament_lobby.id
		rows[#rows + 1] = {
			n = G.UIT.R,
			config = { align = "cm", padding = 0.08 },
			nodes = {
				readied and TUI.button(PVP.T("k_tn_b_unready"), "mp_pvp_tournament_unready", { id = id }, G.C.ORANGE, 3, 0.5)
					or TUI.button(PVP.T("k_tn_b_ready"), "mp_pvp_tournament_ready", { id = id }, G.C.GREEN, 3, 0.5),
			},
		}
	else
		rows[#rows + 1] = TUI.message(PVP.T("k_tn_lobby_starting_game"), G.C.UI.TEXT_LIGHT)
	end
	return rows
end

-- Keep the lobby's series panel current: data changes rebuild it, the clock ticks in place.
PVP.Tournaments.on_change(function()
	if PVP._tournament_lobby and PVP.lobby and PVP.lobby.refresh_mm_status then
		PVP.lobby.refresh_mm_status()
	end
end)

-- The series panel's countdown, once a second, only while the player is in a
-- tournament match's lobby: the panel starts it when it is built. Balatro also
-- clears its event queue when a run starts, which stops it; the panel then
-- restarts it when it hasn't ticked for a while.
local last_tick = 0
local tick

ensure_ticking = function()
	if love.timer.getTime() - last_tick > 3 then
		tick()
	end
end

tick = function()
	last_tick = love.timer.getTime()
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = 1,
		timer = "REAL",
		blockable = false,
		blocking = false,
		func = function()
			if not PVP._tournament_lobby then
				return true
			end
			local m = lobby_match()
			if m and m.clock and m.clock.phase == "ready_up" and m.clock.deadline then
				local side = PVP.Tournaments.my_side(m)
				local readied = side and m.clock.ready and m.clock.ready[side]
				TUI.set_live(status_live, PVP.T("k_tn_lobby_next_game_left", PVP.TournamentTime.clock(m.clock.deadline)), readied and G.C.GREEN or G.C.GOLD)
			end
			tick()
			return true
		end,
	}))
end
