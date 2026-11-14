-- Pure rules for the Forfeit or Contest modal. No game state, broadcasts or UI
-- here: ui/contest_modal.lua feeds this module and acts on the answer.

PVP.Contest = {}
local Contest = PVP.Contest

-- The run status the server gives a contested run (GAME_ENDED).
-- DODGED: the opponent left during the Draft of a ranked game; the server ends it unrated.
Contest.RunStatus = { CONTESTED = "contested", DODGED = "dodged", RESTARTED = "restarted" }

-- The end screens a GAME_ENDED status can open.
-- DODGE_AWAY: a dodge this client learned of after being away (it cannot tell who left, so the text
-- fits both). ENDED_AWAY: any other end learned after being away.
Contest.EndScreen = {
	CONTESTED = "contested",
	DODGE_NOTICE = "dodge_notice",
	DODGE_AWAY = "dodge_away",
	ENDED_AWAY = "ended_away",
}

-- Which end screen a GAME_ENDED status gets, or nil for none.
-- ctx: { in_run = G.STAGE is the run, contested = contested screen already shown,
-- dodge_shown = dodge notice already shown, ended_away_shown = an away notice already shown,
-- while_away = the end was learned from a snapshot after being away }. A contest needs a run to
-- end; the dodge notice also works from the Draft (no run yet) and from any other stage.
function Contest.end_screen(status, ctx)
	ctx = ctx or {}
	if status == Contest.RunStatus.CONTESTED then
		if ctx.in_run and not ctx.contested then
			return Contest.EndScreen.CONTESTED
		end
	elseif status == Contest.RunStatus.DODGED then
		if ctx.while_away then
			if not ctx.ended_away_shown and not ctx.dodge_shown and not ctx.contested then
				return Contest.EndScreen.DODGE_AWAY
			end
		elseif not ctx.dodge_shown and not ctx.contested then
			return Contest.EndScreen.DODGE_NOTICE
		end
	elseif ctx.while_away and status ~= nil and status ~= Contest.RunStatus.RESTARTED then
		-- Away when it ended: say so, and take the player back to the menu.
		if not ctx.ended_away_shown and not ctx.dodge_shown and not ctx.contested then
			return Contest.EndScreen.ENDED_AWAY
		end
	end
	return nil
end

-- Only a matchmade (Ranked or Casual) match of 2 players or more offers a Contest.
-- Every other match keeps the plain forfeit.
function Contest.should_offer(kind, player_count)
	if player_count < 2 then
		return false
	end
	return kind == PVP.LobbyAccess.RANKED or kind == PVP.LobbyAccess.CASUAL
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

-- The players the contester can name: everyone else still in the match.
-- lives_cache[id] is the last lives count heard for a player; a player never
-- heard from counts as in. Each entry is {id, displayName}.
function Contest.opponents(players, self_id, lives_cache)
	local list = {}
	for _, p in ipairs(players or {}) do
		local lives = lives_cache and lives_cache[p.id]
		if p.id ~= self_id and not (lives and lives <= 0) then
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
