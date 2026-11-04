-- Adjust Judgement's outcome chances: Rare 5% becomes 10%, for example.
-- Reduce other outcomes to keep the total chance at 100%.
local C = PVP.CHAOS
local H = {}
C.HigherCalling = H

function H.boost(entries, multipliers, donor)
	local result, target, other = {}, 0, 0
	-- Copy the outcomes, boost selected chances, and total boosted versus unchanged chances.
	for i, entry in ipairs(entries) do
		local p = entry.p
		if multipliers[entry.key] then
			p = math.min(1, p * multipliers[entry.key])
			target = target + p
		else
			other = other + p
		end
		result[i] = { key = entry.key, p = p, pool = entry.pool }
	end
	-- Extreme external modifiers may leave insufficient mass for both boosted
	-- editions. Cap their combined probability, preserving their relative shares.
	if target > 1 then
		for _, entry in ipairs(result) do
			entry.p = multipliers[entry.key] and entry.p / target or 0
		end
		return result
	end
	local remaining = 1 - target
	if donor then
		-- Spend the plain-Joker probability first; retain Foil/Holo at their
		-- native rates unless even the entire plain mass is insufficient.
		for _, entry in ipairs(result) do
			if entry.key == donor then
				local kept = math.max(0, entry.p - math.max(0, other - remaining))
				other = other - entry.p
				remaining = remaining - kept
				entry.p = kept
			end
		end
	end
	local scale = other > 0 and math.min(1, remaining / other) or 0
	for _, entry in ipairs(result) do
		if not multipliers[entry.key] and entry.key ~= donor then entry.p = entry.p * scale end
	end
	return result
end

function H.pick(entries, roll)
	local total = 0
	for _, entry in ipairs(entries) do
		total = total + entry.p
		if roll < total then return entry end
	end
	return entries[#entries]
end

local vanilla = { Common = 1, Uncommon = 2, Rare = 3, Legendary = 4 }
local function pool(rarity, legendary)
	local result = {}
	for _, key in ipairs(get_current_pool("Joker", rarity, legendary, "jud")) do
		local center = G.P_CENTERS[key]
		local duplicate_ok = true
		if center and G.GAME.used_jokers[key] then
			local _, options = SMODS.add_to_pool(center, { source = "jud" })
			duplicate_ok = (options and options.allow_duplicates) or SMODS.showman(key)
		end
		-- Empty pools can contain a Common fallback. Do not promote it into an
		-- empty Legendary/Rare pool, or resample UNAVAILABLE indefinitely.
		if center and duplicate_ok and center.rarity == (vanilla[rarity] or rarity) and not G.GAME.banned_keys[key] then
			result[#result + 1] = key
		end
	end
	return result
end

local function roll(kind)
	return pseudorandom("pvp_higher_calling_" .. kind .. G.GAME.round_resets.ante)
end

function H.joker()
	local odds = C.effects.higher_calling.payload
	if roll("legendary") < odds.legendary then
		local legendary = pool("Legendary", true)
		if #legendary > 0 then
			return pseudorandom_element(legendary, pseudoseed("pvp_higher_calling_joker" .. G.GAME.round_resets.ante))
		end
	end
	local entries, total = {}, 0
	local object_type = SMODS.ObjectTypes.Joker
	for _, rarity in ipairs(object_type.rarities) do
		if rarity.key ~= "Legendary" then
			local eligible = pool(rarity.key)
			local weight = rarity.weight
			local definition = SMODS.Rarities[rarity.key]
			if definition and definition.get_weight then weight = definition:get_weight(weight, object_type) end
			weight = weight * (G.GAME[rarity.key:lower() .. "_mod"] or 1)
			if #eligible > 0 and weight > 0 then
				entries[#entries + 1] = { key = rarity.key, p = weight, pool = eligible }
				total = total + weight
			end
		end
	end
	if total == 0 then return nil end -- retain the engine's native empty-pool fallback
	for _, entry in ipairs(entries) do
		entry.p = entry.p / total
	end
	local selected = H.pick(H.boost(entries, { Rare = odds.rare }), roll("rarity"))
	return pseudorandom_element(selected.pool, pseudoseed("pvp_higher_calling_joker" .. G.GAME.round_resets.ante))
end

function H.edition(key, modifier)
	-- Mirror Steamodded's normal, non-guaranteed edition distribution, including
	-- Hone/Glow Up and Edition:get_weight. Preserve its vanilla-reversed order.
	local options, total = {}, 0
	for _, name in ipairs(get_current_pool("Edition", nil, nil, key)) do
		local center = G.P_CENTERS[name]
		if center then
			if center.vanilla then
				table.insert(options, 1, name)
			else
				options[#options + 1] = name
			end
			total = total + center.weight
		end
	end
	if total <= 0 then return nil end
	local entries, used = {}, 0
	for _, name in ipairs(options) do
		local p = math.min(1 - used, math.max(0, G.P_CENTERS[name]:get_weight() * (modifier or 1) / (25 * total)))
		entries[#entries + 1] = { key = name, p = p }
		used = used + p
	end
	entries[#entries + 1] = { key = "none", p = 1 - used }
	local odds = C.effects.higher_calling.payload
	local selected = H.pick(
		H.boost(entries, { e_negative = odds.negative, e_polychrome = odds.polychrome }, "none"),
		roll("edition")
	)
	if selected.key ~= "none" then return selected.key end
end
