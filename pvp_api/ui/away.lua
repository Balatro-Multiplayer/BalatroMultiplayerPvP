-- The notice that a player I am playing with is away (pvp_api/read/away.lua decides).
-- One banner at the top of the game, shown while the view says they are away and gone the frame it does not: the
-- view alone says when they are back. In a run it is the only away line (pvp_api/ui/reconnect.lua keeps the rest);
-- its countdown to the forfeit comes from the lobby roster's forfeits_at_local.
local screen = {}
PVP.UI.away = screen

local shown
local clock_words = { text = "" }

local function name_of(id)
	local lobby = MPAPI.get_current_lobby()
	for _, player in ipairs(lobby and lobby:get_players() or {}) do
		if player.id == id then return player.displayName end
	end
	return nil
end

-- Soonest forfeit among `ids` on this client's clock, or nil when the server named none.
local function soonest_forfeit(ids)
	local lobby = MPAPI.get_current_lobby()
	local soonest
	for _, player in ipairs(lobby and lobby:get_players() or {}) do
		local at = player.forfeits_at_local
		if at and (not soonest or at < soonest) then
			for _, id in ipairs(ids) do
				if id == player.id then soonest = at end
			end
		end
	end
	return soonest
end

-- The banner's rows: the away line, the live countdown, the held-timers line.
local function rows(names, timers_held, timed)
	local row = PVP.UI.reconnect.banner_row
	local title = localize({ type = "variable", key = "k_pvp_player_away", vars = { names } })
	local out = { row(title, 0.45) }
	if timed then out[#out + 1] = row(clock_words, 0.35) end
	if timers_held then out[#out + 1] = row(localize("k_pvp_timers_held"), 0.35) end
	return out
end

function screen.hide()
	if not shown then return end
	if not shown.box.REMOVED then shown.box:remove() end
	shown = nil
end

-- Whether this banner owns the away line: a PvP run being played, not a playback.
function screen.in_run()
	return G.STAGE == G.STAGES.RUN and PVP.LOBBY.in_session() and not PVP.PRACTICE.is_on() and not MPAPI.playback.is_driving("pvp")
end

function screen.update()
	local view = PVP.NET and PVP.NET.view
	local ids, timers_held
	if screen.in_run() then ids, timers_held = PVP.READ.away.away_players(view) end
	if not ids then return screen.hide() end
	local names = PVP.READ.away.names_line(ids, name_of, localize("k_pvp_player_unknown_name"))
	local held = timers_held == true
	local forfeits_at = soonest_forfeit(ids)
	local timed = forfeits_at ~= nil
	if timed then
		clock_words.text = localize({
			type = "variable",
			key = "k_pvp_player_reconnecting_timed",
			vars = { names, PVP.UI.reconnect.clock(forfeits_at, love.timer.getTime()) },
		})
	end
	local box_alive = shown and shown.room == G.ROOM and not shown.box.REMOVED
	if box_alive and shown.names == names and shown.held == held and shown.timed == timed then return end
	screen.hide()
	shown = {
		held = held,
		timed = timed,
		room = G.ROOM,
		names = names,
		box = PVP.UI.reconnect.banner(rows(names, held, timed), 0.15),
	}
end

return screen
