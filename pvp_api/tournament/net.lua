-- In-client tournaments: the client side of the server's tournament RPCs
-- (BalatroMultiplayerServer nakama/src/tournament/rpc.ts) and of its three
-- tournament notifications. The Tournaments tab (ui/main_menu/tournaments.lua)
-- reads PVP.Tournaments.state and listens for changes; the Organiser mod uses
-- the same calls.
--
-- Every call is cb(err, data): err is the server's message (e.g. "Tournaments
-- are not enabled on this server") or nil. Answers carry serverNow, which
-- keeps PVP.TournamentTime's clock in step with the server's.

PVP.Tournaments = PVP.Tournaments or {}
local TN = PVP.Tournaments

-- Kept in step with the server's NotifyCode (nakama/src/notify.ts).
TN.NotifyCode = {
	-- {tournamentId, name, matchId, kind = "open"|"series"|"reminder", deadline,
	-- minutesLeft, opponent = {id, name}}: ready up for a match.
	MATCH = 112,
	-- {tournamentId, name, matchId, code, game, wins, reused}: the match's
	-- lobby is ready (Phase 8 joins it automatically).
	LOBBY = 113,
	-- {tournamentId, name, kind, matchId}: something changed; refresh.
	UPDATED = 114,
}

TN.FORMAT_NAMES = {
	single_elim = "Single Elim",
	double_elim = "Double Elim",
	round_robin = "Round Robin",
	swiss = "Swiss",
}

-- What the tab shows: refreshed by TN.refresh().
TN.state = TN.state
	or {
		-- Summaries of the player's tournaments (tournament_mine), with the full
		-- view of the ones in check-in or running (views[id]).
		mine = nil,
		views = {},
		-- Public upcoming tournaments (tournament_list).
		browse = nil,
		-- The last refusal to show instead of the lists (nil when fine).
		error = nil,
		loading = false,
		-- What the player last pressed, per tournament id (shown until refreshed).
		busy = {},
	}

local listeners = {}

-- fn() runs after every change to TN.state. Returns a function that removes it.
function TN.on_change(fn)
	listeners[#listeners + 1] = fn
	return function()
		for i, f in ipairs(listeners) do
			if f == fn then
				table.remove(listeners, i)
				return
			end
		end
	end
end

local function changed()
	for _, fn in ipairs(listeners) do
		local ok, err = pcall(fn)
		if not ok then
			sendWarnMessage("Tournaments: listener failed: " .. tostring(err), "MULTIPLAYER")
		end
	end
end
TN._changed = changed

local function observe(data)
	if type(data) ~= "table" then
		return
	end
	PVP.TournamentTime.observe_server_now(data.serverNow or (data.tournament and data.tournament.serverNow))
end

-- One RPC. (An empty body encodes as [], which the server reads as {}.)
function TN.call(rpc_id, body, cb)
	local ok, err = pcall(MPAPI.networking.nakama_lobby.rpc, rpc_id, body or {}, function(rpc_err, data)
		if not rpc_err then
			observe(data)
		end
		if cb then
			cb(rpc_err, data)
		end
	end)
	if not ok and cb then
		cb(tostring(err))
	end
end

function TN.list(status, cb)
	TN.call("tournament_list", { status = status or "upcoming" }, cb)
end

-- {id = ...} or {code = ...}
function TN.get(ref, cb)
	TN.call("tournament_get", ref, cb)
end

function TN.mine(cb)
	TN.call("tournament_mine", {}, cb)
end

-- After any action: refresh the lists and say what failed, if anything.
local function then_refresh(id, cb)
	return function(err, data)
		TN.state.busy[id] = nil
		if err then
			TN.state.error = err
		end
		if cb then
			cb(err, data)
		end
		TN.refresh()
	end
end

local function act(rpc_id, id, body, what, cb)
	TN.state.busy[id] = what
	changed()
	TN.call(rpc_id, body, then_refresh(id, cb))
end

function TN.join(id, cb)
	act("tournament_join", id, { id = id }, "joining", cb)
end

function TN.join_code(code, cb)
	TN.call("tournament_join", { code = code }, then_refresh(code, cb))
end

function TN.leave(id, cb)
	act("tournament_leave", id, { id = id }, "leaving", cb)
end

function TN.check_in(id, cb)
	act("tournament_check_in", id, { id = id }, "checking in", cb)
end

function TN.ready(id, ready, cb)
	act("tournament_ready", id, { id = id, ready = ready ~= false }, ready ~= false and "readying" or "unreadying", cb)
end

-- The tournaments whose full view the tab needs (check-in state, the
-- player's match and its ready-up), at most a handful.
local DETAIL_STATUSES = { check_in = true, running = true }
local MAX_DETAILS = 8

-- Re-reads the player's tournaments and the public list. Calls changed()
-- as the answers arrive.
function TN.refresh()
	if TN.state.loading then
		return
	end
	TN.state.loading = true
	local pending = 2
	local function done()
		pending = pending - 1
		if pending == 0 then
			TN.state.loading = false
		end
		changed()
	end
	TN.mine(function(err, data)
		if err then
			TN.state.error = err
			done()
			return
		end
		TN.state.error = nil
		TN.state.mine = data.tournaments or {}
		local wanted = {}
		for _, t in ipairs(TN.state.mine) do
			if DETAIL_STATUSES[t.status] and #wanted < MAX_DETAILS then
				wanted[#wanted + 1] = t.id
			end
		end
		pending = pending + #wanted
		for _, id in ipairs(wanted) do
			TN.get({ id = id }, function(get_err, view)
				if not get_err and view and view.tournament then
					TN.state.views[id] = view.tournament
				end
				done()
			end)
		end
		done()
	end)
	TN.list("upcoming", function(err, data)
		if not err then
			TN.state.browse = data.tournaments or {}
		end
		done()
	end)
end

-- The player's own match in a tournament view (with its ready-up), or nil.
function TN.my_match(view)
	if not view or not view.you or not view.you.nextMatchId or not view.bracket then
		return nil
	end
	for _, m in ipairs(view.bracket) do
		if m.id == view.you.nextMatchId then
			return m
		end
	end
	return nil
end

-- The player's own entry in a tournament view ({id, name, seed, checkedIn,
-- dropped}), or nil.
function TN.me_in(view)
	local me = MPAPI.connection_state and MPAPI.connection_state.player_id or nil
	for _, e in ipairs(view and view.entrants or {}) do
		if e.id == me then
			return e
		end
	end
	return nil
end

-- My side (1 or 2) in a match view, or nil.
function TN.my_side(match)
	local me = MPAPI.connection_state and MPAPI.connection_state.player_id or nil
	if not match or not me then
		return nil
	end
	for i, p in ipairs(match.players or {}) do
		if type(p) == "table" and p.id == me then
			return i
		end
	end
	return nil
end

-- Server pushes: any of them means something changed for the player.
local notify = MPAPI.networking and MPAPI.networking.nakama_notify
if notify and notify.on then
	notify.on(TN.NotifyCode.MATCH, function(content)
		PVP.match_log("debug", "Tournament " .. tostring(content.name) .. ": ready up (" .. tostring(content.kind) .. ")")
		TN.refresh()
		-- A banner (ui/tournament/banner.lua); never takes the player anywhere.
		if PVP.show_tournament_banner then
			PVP.show_tournament_banner(content)
		end
	end)
	notify.on(TN.NotifyCode.LOBBY, function(content)
		PVP.match_log("debug", "Tournament " .. tostring(content.name) .. ": lobby " .. tostring(content.code))
		-- Joins it (or readies for the next game): pvp_api/tournament/play.lua.
		if PVP.tournament_lobby_ready then
			PVP.tournament_lobby_ready(content)
		end
		TN.refresh()
	end)
	notify.on(TN.NotifyCode.UPDATED, function(content)
		TN.refresh()
		-- Check-in opened and this player isn't on their ranked profile.
		if content and content.kind == "ranked_profile_needed" and PVP.show_tournament_banner then
			PVP.show_tournament_banner(content)
		end
	end)
end
