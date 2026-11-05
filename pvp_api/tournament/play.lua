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
--   * between games the lobby shows the series and its ready-up
--     (PVP.build_tournament_lobby_status, in the matchmade status panel);
--   * when the server closes the lobby after the match, the player lands on
--     the tournament's screen.

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
	lobby:on(MPAPI.LobbyEvent.CONNECTED, function()
		PVP.match_log("debug", "Tournament: lobby connected (host: " .. tostring(lobby.is_host) .. ", page: " .. tostring(MPAPI.pages.current_key()) .. ")")
		PVP._pvp_kind = PVP.LobbyAccess.TOURNAMENT
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
	-- The server closes the lobby once the match is decided: back to the
	-- tournament (after PvP's own teardown has run).
	lobby:on(MPAPI.LobbyEvent.DISCONNECTED, function()
		local id = PVP._tournament_lobby and PVP._tournament_lobby.id
		PVP._tournament_lobby = nil
		if id then
			PVP.return_to_tournament(id)
		end
	end)
end

-- After a tournament lobby is left (or closed by the server), the player
-- should land on the tournament's screen, not the PvP or Balatro main menu.
-- Three things get in the way: a server lobby's leave only completes after a
-- round trip; PvP's teardown then rebuilds the lobby page, which without a
-- lobby draws the PvP main menu; and when the lobby goes while the player is
-- in a run, MPAPI unfocuses PvP so the run ends on Balatro's own main menu
-- (MPAPI api/mod_registry/focus.lua on_lobby_disconnected) -- and Balatro
-- clears its event queue on the way back, so a timer started during the run
-- dies there.
--
-- So leaving records where to go back to (for RETURN_WITHIN_SECONDS), and
-- every main-menu rebuild (set_main_menu_UI, hooked below) or a leave from
-- the menus starts a short check: once the player is out of the lobby, in
-- the menus, and the menu has been quiet for SETTLE_SECONDS, PvP is focused
-- again if it isn't, and the tournament's screen opens. A player already on
-- one of the tournament pages is left where they are.
local RETURN_POLL = 0.25
local SETTLE_SECONDS = 0.75
local CHECK_SECONDS = 8
local RETURN_WITHIN_SECONDS = 15 * 60
local TOURNAMENT_PAGES = { pvp_tournament = true, pvp_tournament_browse = true, pvp_tournament_organise = true }

PVP._tournament_return = nil -- { id, since }

local checking = false

local function check_return()
	if checking then
		return
	end
	checking = true
	local waited, quiet = 0, 0
	local function poll()
		G.E_MANAGER:add_event(Event({
			trigger = "after",
			delay = RETURN_POLL,
			timer = "REAL",
			blockable = false,
			blocking = false,
			func = function()
				local pending = PVP._tournament_return
				waited = waited + RETURN_POLL
				if not pending or love.timer.getTime() - pending.since > RETURN_WITHIN_SECONDS then
					PVP._tournament_return = nil
					checking = false
					return true
				end
				if not in_menus() or MPAPI.get_current_lobby() or not G.MAIN_MENU_UI then
					quiet = 0
				else
					quiet = quiet + RETURN_POLL
				end
				if quiet >= SETTLE_SECONDS then
					PVP._tournament_return = nil
					checking = false
					local page = MPAPI.pages.current_key()
					if TOURNAMENT_PAGES[page] and MPAPI.get_focused_mod() == PVP.id then
						PVP.match_log("debug", "Tournament: already on " .. tostring(page) .. " after leaving the lobby")
						return true
					end
					PVP.match_log("debug", "Tournament: back to the tournament (page was " .. tostring(page) .. ", focus " .. tostring(MPAPI.get_focused_mod()) .. ")")
					if MPAPI.get_focused_mod() ~= PVP.id then
						MPAPI._internal.activate_mod(PVP.id)
					end
					PVP.open_tournament(pending.id)
					return true
				end
				if waited < CHECK_SECONDS then
					poll()
				else
					-- Still in a run (or another lobby): the next menu rebuild checks again.
					checking = false
				end
				return true
			end,
		}))
	end
	poll()
end

function PVP.return_to_tournament(id)
	PVP._tournament_return = { id = id, since = love.timer.getTime() }
	PVP.match_log("debug", "Tournament: left the lobby; will return to the tournament")
	checking = false
	check_return()
end

-- Every main-menu rebuild (returning from a run included) checks for a
-- pending return. MPAPI wraps set_main_menu_UI too; this wraps its wrapper.
local set_main_menu_UI_ref = set_main_menu_UI
set_main_menu_UI = function(...)
	local result = set_main_menu_UI_ref(...)
	if PVP._tournament_return then
		checking = false
		check_return()
	end
	return result
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
		rows[#rows + 1] = TUI.message("Starting your match...", G.C.UI.TEXT_LIGHT)
		return rows
	end
	local a = type(m.players[1]) == "table" and m.players[1].name or "?"
	local b = type(m.players[2]) == "table" and m.players[2].name or "?"
	rows[#rows + 1] = TUI.title(string.format("%s   %d - %d   %s", a, m.wins[1] or 0, m.wins[2] or 0, b), G.C.UI.TEXT_LIGHT, 0.5)
	if (m.bestOf or 1) > 1 then
		rows[#rows + 1] = TUI.message("Best of " .. m.bestOf)
	end
	local clock = m.clock
	local side = PVP.Tournaments.my_side(m)
	if m.status == "done" then
		rows[#rows + 1] = TUI.message("Match over. Back to the tournament...", G.C.GREEN)
	elseif clock and clock.phase == "ready_up" then
		local readied = side and clock.ready and clock.ready[side]
		local left = clock.deadline and PVP.TournamentTime.clock(clock.deadline) or nil
		TUI.set_live(status_live, left and ("Next game  -  ready up  " .. left) or "Next game  -  ready up", readied and G.C.GREEN or G.C.GOLD)
		rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.06 }, nodes = { TUI.live_text(status_live, 0.42) } }
		local id = PVP._tournament_lobby.id
		rows[#rows + 1] = {
			n = G.UIT.R,
			config = { align = "cm", padding = 0.08 },
			nodes = {
				readied and TUI.button("UNREADY", "mp_pvp_tournament_unready", { id = id }, G.C.ORANGE, 3, 0.5)
					or TUI.button("READY", "mp_pvp_tournament_ready", { id = id }, G.C.GREEN, 3, 0.5),
			},
		}
	else
		rows[#rows + 1] = TUI.message("Starting the game...", G.C.UI.TEXT_LIGHT)
	end
	return rows
end

-- Keep the lobby's series panel current: data changes rebuild it, the clock ticks in place.
PVP.Tournaments.on_change(function()
	if PVP._tournament_lobby and PVP.lobby and PVP.lobby.refresh_mm_status then
		PVP.lobby.refresh_mm_status()
	end
end)

-- Balatro clears its event queue when a run starts, which stops this loop:
-- the panel restarts it when it hasn't ticked for a while.
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
			local m = PVP._tournament_lobby and lobby_match()
			if m and m.clock and m.clock.phase == "ready_up" and m.clock.deadline then
				local side = PVP.Tournaments.my_side(m)
				local readied = side and m.clock.ready and m.clock.ready[side]
				TUI.set_live(status_live, "Next game  -  ready up  " .. PVP.TournamentTime.clock(m.clock.deadline), readied and G.C.GREEN or G.C.GOLD)
			end
			tick()
			return true
		end,
	}))
end
tick()
