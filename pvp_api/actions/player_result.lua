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
-- PvP's own Enemy Location HUD (§17.11) this session. The old pair is left
-- in place for the existing single-nemesis toggle/deck-view UI.
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
	local deck_back = PVP.LOBBY.deck and PVP.LOBBY.deck.back
	local highest_pvp_score = PVP.INSANE_INT.to_string(PVP.GAME.highest_pvp_score)

	PVP._collected_results[lobby.player_id] = {
		jokers = jokers,
		deck_back = deck_back,
		highest_pvp_score = highest_pvp_score,
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
	lobby:action(MPAPI.ActionTypes["pvp_player_result"]):broadcast({
		jokers = jokers,
		deck_back = deck_back,
		highest_pvp_score = highest_pvp_score,
	})
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
	lobby:action(MPAPI.ActionTypes["pvp_player_result"]):broadcast({
		jokers = capture_local_jokers(),
		interim = true,
	})
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
				deck_back = kept and kept.deck_back,
				highest_pvp_score = kept and kept.highest_pvp_score,
				interim = true,
			}
			return
		end
		PVP._collected_results[from_player_id] = {
			jokers = params.jokers,
			deck_back = params.deck_back,
			highest_pvp_score = params.highest_pvp_score,
		}
		if PVP.UI.refresh_roster then
			PVP.UI.refresh_roster()
		end
		local lobby = MPAPI.get_current_lobby()
		if PVP._roster_delivered and lobby and from_player_id == lobby.player_id then
			PVP._roster_delivered()
		end
	end,
})
