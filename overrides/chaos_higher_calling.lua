-- Vanilla Judgement marks its deferred create_card call with the "jud" source.
-- Restrict the override to that ordinary roll, not Soul, Wraith, shops, copies
-- or explicit/guaranteed creation. Do not replace Judgement's use/slot behavior.
local C = PVP.CHAOS
local creating = false
local edition = poll_edition
function poll_edition(key, modifier, no_negative, guaranteed, options)
	if
		creating
		and key == "edijud" .. G.GAME.round_resets.ante
		and not no_negative
		and not guaranteed
		and not options
	then
		return C.HigherCalling.edition(key, modifier)
	end
	return edition(key, modifier, no_negative, guaranteed, options)
end

local create = create_card
function create_card(kind, area, legendary, rarity, skip_materialize, soulable, forced_key, source)
	if
		kind ~= "Joker"
		or source ~= "jud"
		or legendary
		or rarity
		or forced_key
		or not C.has_rule("higher_calling")
		or (SMODS.optional_features and SMODS.optional_features.object_weights)
	then
		return create(kind, area, legendary, rarity, skip_materialize, soulable, forced_key, source)
	end
	local key = C.HigherCalling.joker()
	-- An empty ordinary pool keeps the engine's original fallback behavior.
	if not key then return create(kind, area, legendary, rarity, skip_materialize, soulable, forced_key, source) end
	local previous = creating
	creating = true
	local ok, card = pcall(create, kind, area, legendary, rarity, skip_materialize, soulable, key, source)
	creating = previous
	if not ok then error(card, 0) end
	return card
end
