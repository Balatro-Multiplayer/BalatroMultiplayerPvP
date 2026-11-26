-- §17.10: end-of-run roster -- every player's jokers, deck, and highest
-- PvP-blind score, not just the local player's own. Modeled directly on
-- SPDRN's own spdrn_player_result (built earlier this session, §16.10):
-- a one-shot broadcast every player sends once their own match involvement
-- ends, collected into a table keyed by SENDER id.
--
-- This replaces the existing get_end_game_jokers/get_nemesis_deck pair as
-- the roster's data source -- those are, despite their "pull" framing,
-- already full lobby broadcasts under the hood (pvp_api/net.lua's
-- get_end_game_jokers/receive_end_game_jokers), but the receiver writes into
-- a SINGLE scalar (PVP.end_game_jokers_payload) with no sender id at all, so
-- in any N>2 lobby whichever response lands last silently clobbers every
-- other player's data. Keying by sender id here avoids that outright, the
-- same fix already applied to SPDRN's Enemy Location Indicator (§16.11) and
-- PvP's own Enemy Location HUD (§17.11) this session. The result also carries
-- the player's cards, which the end screen's View Deck shows: a player still in
-- the match has sent no result, so their deck stays hidden.
PVP._collected_results = PVP._collected_results or {}

local function capture_local_jokers()
	local jokers = {}
	if G.jokers and G.jokers.cards then
		for _, card in ipairs(G.jokers.cards) do
			local center = card.config and card.config.center
			if center then
				jokers[#jokers + 1] = {
					key = center.key,
					edition = card.edition,
					eternal = card.ability and card.ability.eternal or false,
					perishable = card.ability and card.ability.perishable or false,
				}
			end
		end
	end
	return jokers
end

-- The whole joker area as one encoded string (G.jokers:save(), the same payload
-- the 0.5.5 end-game jokers message sent). Unlike the plain list above it keeps
-- everything a card carries -- editions, every sticker, the perishable tally --
-- and the area's real slot limit. Nil when there is nothing usable to send.
local function capture_local_jokers_save()
	if not (G.jokers and G.jokers.cards) then
		return nil
	end
	local ok, encoded = pcall(function()
		return MPAPI.encode(G.jokers:save())
	end)
	if not ok or type(encoded) ~= "string" then
		PVP.match_log("debug", "Failed to encode end game jokers: " .. tostring(encoded))
		return nil
	end
	if #encoded > MPAPI.MAX_ENCODED_BYTES then
		-- MPAPI.decode would refuse it on the other side anyway.
		PVP.match_log("debug", string.format("End game jokers too large to send (%d bytes)", #encoded))
		return nil
	end
	return encoded
end

-- The server drops an action whose params pass 16 KiB, which would lose the whole
-- result. Stay under that with room for JSON escaping; past it the saved joker
-- area is left out and receivers fall back to the plain `jokers` list.
local MAX_ACTION_PARAMS_BYTES = 14 * 1024

local function fit_to_server_cap(params)
	if not params.jokers_save then
		return params
	end
	local ok, encoded = pcall(function()
		return require("json").encode(params)
	end)
	if ok and type(encoded) == "string" and #encoded <= MAX_ACTION_PARAMS_BYTES then
		return params
	end
	PVP.match_log("debug", "End game jokers save left out: payload would pass the server cap")
	params.jokers_save = nil
	return params
end

-- Fills `area` from a collected result: the saved joker area when there is one,
-- else the plain list an older client sends. Cards are marked as never added to
-- the deck first so clearing or replacing them can't run their removal effects
-- (a negative joker would otherwise shrink the real joker slots).
function PVP.rebuild_result_jokers_area(area, result)
	if not area then
		return
	end
	MPAPI.rebuild_jokers_area(area, nil)
	if not result then
		return
	end
	if result.jokers_save then
		local save, err = MPAPI.decode(result.jokers_save)
		local ok = save ~= nil
		if ok then
			ok, err = pcall(area.load, area, save)
		end
		if ok then
			for _, card in ipairs(area.cards or {}) do
				card.added_to_deck = false
			end
			return
		end
		PVP.match_log("debug", "Failed to load end game jokers: " .. tostring(err))
		for _, card in ipairs(area.cards or {}) do
			card.added_to_deck = false
		end
		MPAPI.rebuild_jokers_area(area, nil)
	end
	MPAPI.rebuild_jokers_area(area, result.jokers)
end

-- Called once, when this client's own match involvement ends (win or loss --
-- see action_win_game/action_lose_game in networking/action_handlers.lua).
-- `on_delivered` (optional) runs once the server has relayed the roster back to
-- us, or after ROSTER_ECHO_TIMEOUT seconds, whichever comes first.
local ROSTER_ECHO_TIMEOUT = 2
function PVP.report_roster_result(on_delivered)
	local lobby = MPAPI.get_current_lobby()
	if not lobby then
		if on_delivered then on_delivered() end
		return
	end
	local jokers = capture_local_jokers()
	local jokers_save = capture_local_jokers_save()
	local deck_back = PVP.LOBBY.deck and PVP.LOBBY.deck.back
	local highest_pvp_score = PVP.Score.or_zero(PVP.GAME.highest_pvp_score)
	local cards = PVP.UTILS.deck_to_string(G.playing_cards)

	PVP._collected_results[lobby.player_id] = {
		jokers = jokers,
		jokers_save = jokers_save,
		deck_back = deck_back,
		highest_pvp_score = highest_pvp_score,
		cards = cards,
	}
	if on_delivered then
		-- A leave sent right behind the roster can reach the server first and
		-- get the roster dropped, so the caller waits for the echo.
		local delivered = false
		PVP._roster_delivered = function()
			if delivered then return end
			delivered = true
			PVP._roster_delivered = nil
			on_delivered()
		end
		G.E_MANAGER:add_event(Event({
			trigger = "after",
			delay = ROSTER_ECHO_TIMEOUT,
			timer = "REAL",
			blocking = false,
			blockable = false,
			func = function()
				if PVP._roster_delivered then PVP._roster_delivered() end
				return true
			end,
		}))
	end
	lobby:action(MPAPI.ActionTypes["pvp_player_result"]):broadcast(fit_to_server_cap({
		jokers = jokers,
		jokers_save = jokers_save,
		deck_back = deck_back,
		highest_pvp_score = highest_pvp_score,
		cards = cards,
	}))
end

-- Interim roster: the last jokers other players saw. Sent when this player leaves
-- the shop. If this client later drops and relaunches (a Leave from the reconnect
-- prompt), it has no run state to send, so the others keep this one for the end
-- screen. Not sent while a Replay is driving (it would resend old jokers).
function PVP.report_roster_snapshot()
	local lobby = MPAPI.get_current_lobby()
	if not lobby or not MPAPI.ActionTypes["pvp_player_result"] or MPAPI.playback.is_driving("pvp") then
		return
	end
	lobby:action(MPAPI.ActionTypes["pvp_player_result"]):broadcast(fit_to_server_cap({
		jokers = capture_local_jokers(),
		jokers_save = capture_local_jokers_save(),
		interim = true,
	}))
end

MPAPI.ActionType({
	key = "pvp_player_result",
	prefix_config = { key = false },
	on_receive = function(_at, from_player_id, params)
		if not params then
			return
		end
		local kept = PVP._collected_results[from_player_id]
		if params.interim and kept and not kept.interim then
			return
		end
		if params.interim then
			-- Keep the deck and score of the earlier roster, if any.
			PVP._collected_results[from_player_id] = {
				jokers = params.jokers,
				jokers_save = params.jokers_save,
				deck_back = kept and kept.deck_back,
				highest_pvp_score = kept and kept.highest_pvp_score,
				interim = true,
			}
			return
		end
		PVP._collected_results[from_player_id] = {
			jokers = params.jokers,
			jokers_save = params.jokers_save,
			deck_back = params.deck_back,
			highest_pvp_score = params.highest_pvp_score,
			cards = params.cards,
		}
		if PVP.UI.refresh_roster then
			PVP.UI.refresh_roster()
		end
		if PVP.UI.refresh_end_screen_player then
			PVP.UI.refresh_end_screen_player(from_player_id)
		end
		local lobby = MPAPI.get_current_lobby()
		if PVP._roster_delivered and lobby and from_player_id == lobby.player_id then
			PVP._roster_delivered()
		end
	end,
})
