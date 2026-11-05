-- SMODS resolves never_scores after hand recognition and before scoring.
-- Its exclusion wins over Splash/always_scores without changing the hand type.
local C = PVP.CHAOS

function C.duplicate_played_rank(card, played)
	if SMODS.has_no_rank(card) then return false end
	local rank = card:get_id()
	for _, earlier in ipairs(played or {}) do
		if earlier == card then return false end
		if not SMODS.has_no_rank(earlier) and earlier:get_id() == rank then return true end
	end
	return false
end

local never_scores = SMODS.never_scores
function SMODS.never_scores(card)
	if never_scores(card) then return true end
	if not C.has_rule("one_of_each") then return false end
	-- This hook may also be queried for cards outside the played hand.
	local played = G.play and G.play.cards or {}
	for _, played_card in ipairs(played) do
		if played_card == card then return C.duplicate_played_rank(card, played) end
	end
	return false
end
