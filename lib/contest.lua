-- Pure rules for the Forfeit or Contest modal. No game state, broadcasts or UI
-- here: ui/contest_modal.lua feeds this module and acts on the answer.

local Contest = PVP.CONTEST

-- The run status the server gives a contested run (GAME_ENDED).
Contest.RunStatus = { CONTESTED = "contested" }

-- Only a matchmade (Ranked or Casual) match of 2 players or more offers a Contest. Every other
-- match keeps the plain forfeit.
function Contest.should_offer(kind, player_count)
	if player_count < 2 then
		return false
	end
	return kind == PVP.LOBBY.Access.RANKED or kind == PVP.LOBBY.Access.CASUAL
end

-- Who a Contest ends the match for. A match of 2 players ends for both. In a
-- larger match only the contester leaves; the others play on.
Contest.Scope = { EVERYONE = "everyone", CONTESTER = "contester", BYSTANDER = "bystander" }

-- match_size: players who started the match (nil when unknown, counted as 2).
function Contest.scope(match_size, contester_id, self_id)
	if (match_size or 2) <= 2 then
		return Contest.Scope.EVERYONE
	end
	return contester_id == self_id and Contest.Scope.CONTESTER or Contest.Scope.BYSTANDER
end

-- The path of the page the game opens after a Contest (the website's Contest
-- page for the run). nil when the run id is not known.
function Contest.page_path(run_id)
	if type(run_id) ~= "string" or run_id == "" then
		return nil
	end
	return "/contests/" .. run_id
end

-- The players the contester can name: everyone else in the lobby except a player the view says is
-- out (the server refuses a contest against one). A player the view does not list stays. Each entry
-- is {id, displayName}.
function Contest.opponents(players, self_id, view)
	local list = {}
	local seen = view and view.players or {}
	for _, p in ipairs(players or {}) do
		local out = seen[p.id] ~= nil and seen[p.id].status == "out"
		if p.id ~= self_id and not out then
			list[#list + 1] = { id = p.id, displayName = p.displayName or p.id }
		end
	end
	return list
end

local ERROR_KEYS = {
	already_contested = "k_pvp_contest_already",
	not_in_game = "k_pvp_contest_over",
	server_too_old = "k_pvp_contest_old_server",
}

-- The localization key of the short message for a refused Contest.
function Contest.error_key(err)
	local reason = err
	if type(err) == "table" then
		reason = err.message or err.kind
		if ERROR_KEYS[err.kind] then
			reason = err.kind
		end
	end
	return ERROR_KEYS[reason] or "k_pvp_contest_failed"
end
