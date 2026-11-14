-- Pure view of the enemy's score in the server's "pvp.round" match state.
--
-- While a PvP round is playing, the server leaves `score` and `highestScore` out of every player's
-- entry until this player has played a hand (the score mask), so an absent score means "not known
-- yet", never zero. Nothing is stored here: pvp_api/enemy_score_net.lua gathers the inputs and acts
-- on the answer. A server that does not mask sends the scores at once; the answers are the same.

PVP.EnemyScoreView = {}
local EnemyScoreView = PVP.EnemyScoreView

local same_run = PVP.StateValue.same_run

-- The text field `field` of player `target_id`'s entry in run `run_id`, or nil when the value is
-- not a table, is of another run, has no such player or field, or the field is not a non-empty string that parses as a score.
local function player_field(round_value, run_id, target_id, field)
	if not same_run(round_value, run_id) or type(round_value.players) ~= "table" or target_id == nil then return nil end
	local entry = round_value.players[target_id]
	if type(entry) ~= "table" then return nil end
	local text = entry[field]
	if type(text) ~= "string" or text == "" then return nil end
	-- Malformed text is as good as absent: the HUD must not count up to it.
	return PVP.Score.parse(text)
end

-- The score text of player `target_id` this round, or nil while it is masked or absent.
function EnemyScoreView.score(round_value, run_id, target_id)
	return player_field(round_value, run_id, target_id, "score")
end

-- The highest score text of player `target_id` this run, or nil while it is masked or absent.
function EnemyScoreView.highest(round_value, run_id, target_id)
	return player_field(round_value, run_id, target_id, "highestScore")
end

-- The hands left of player `target_id` this round (never masked), or nil when absent.
function EnemyScoreView.hands(round_value, run_id, target_id)
	if not same_run(round_value, run_id) or type(round_value.players) ~= "table" or target_id == nil then return nil end
	local entry = round_value.players[target_id]
	if type(entry) ~= "table" then return nil end
	return tonumber(entry.handsLeft)
end

-- Whether the value is of run `run_id` and of the round this client is in (`my_round_id`): an older
-- round's push must not stand for this round's score.
function EnemyScoreView.round_is_mine(round_value, run_id, my_round_id)
	if not same_run(round_value, run_id) or my_round_id == nil then return false end
	local id = tonumber(round_value.roundId)
	return id ~= nil and id == tonumber(my_round_id)
end
