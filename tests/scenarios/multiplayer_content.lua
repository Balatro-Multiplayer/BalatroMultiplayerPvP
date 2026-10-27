local function contains(pool, key)
	for _, value in ipairs(pool) do
		if value == key then return true end
	end
	return false
end

local function snapshot()
	local result = {}
	for _, rarity in ipairs({ "Common", "Uncommon", "Rare" }) do
		local pool = get_current_pool("Joker", rarity)
		result[rarity] = {}
		for i, key in ipairs(pool) do
			result[rarity][i] = key
		end
	end
	local planets = get_current_pool("Planet")
	result.Planet = {}
	for i, key in ipairs(planets) do
		result.Planet[i] = key
	end
	return result
end

return {
	{
		until_ = function()
			return MPAPI.is_ready()
		end,
		run = function()
			PVP._start_practice("ruleset_mp_expanded")
		end,
	},
	{
		until_ = function()
			return PVP.is_practice_mode() and G.STATE == G.STATES.BLIND_SELECT and G.blind_select_opts
		end,
		timeout = 30,
		run = function(S)
			S.check(PVP.LOBBY.code == nil, "Practice has no network lobby code")
			S.check(PVP.multiplayer_content_enabled(), "Expanded explicitly includes multiplayer content")
			local layer = MPAPI.Layers[PVP.LayerKey.MULTIPLAYER_CONTENT]
			local keys = { c_mp_asteroid = "Planet" }
			for _, key in ipairs(layer.included_jokers) do
				keys[key] = ({ "Common", "Uncommon", "Rare" })[G.P_CENTERS[key].rarity]
			end
			local enabled = snapshot()
			for key, pool in pairs(keys) do
				S.check(type(G.P_CENTERS[key].mp_include) == "function", key .. " has a content gate")
				local center = G.P_CENTERS[key]
				local eligible = not G.GAME.banned_keys[key] and (not center.in_pool or center:in_pool())
				if eligible then S.check(contains(enabled[pool], key), key .. " appears in its real pool") end
			end

			local ruleset = MPAPI.Rulesets.ruleset_mp_expanded
			local order = ruleset._layer_order
			local content_mode = PVP.multiplayer_content_mode()
			local ok, err = pcall(function()
				local without = {}
				for _, name in ipairs(order) do
					if name ~= PVP.LayerKey.MULTIPLAYER_CONTENT then without[#without + 1] = name end
				end
				ruleset._layer_order = without
				S.check(PVP.current_ruleset().multiplayer_content == true, "removing layer leaves the flag unchanged")
				local disabled = snapshot()
				for key, pool in pairs(keys) do
					S.check(not contains(disabled[pool], key), key .. " absent without the layer")
				end
				for pool, values in pairs(enabled) do
					local other_slots = {}
					for _, key in ipairs(values) do
						if not keys[key] and key ~= "UNAVAILABLE" then other_slots[#other_slots + 1] = key end
					end
					local disabled_slots = {}
					for _, key in ipairs(disabled[pool]) do
						if key ~= "UNAVAILABLE" then disabled_slots[#disabled_slots + 1] = key end
					end
					S.check(
						table.concat(other_slots, ",") == table.concat(disabled_slots, ","),
						pool .. " other slots unchanged"
					)
				end
				ruleset._layer_order = order
				PVP.set_multiplayer_content_mode(PVP.ContentMode.OFF)
				local switched_off = snapshot()
				for key, pool in pairs(keys) do
					S.check(not contains(switched_off[pool], key), key .. " respects the Off layer")
				end
			end)
			ruleset._layer_order = order
			PVP.set_multiplayer_content_mode(content_mode)
			assert(ok, err)
			S.check(PVP.multiplayer_content_enabled(), "content configuration restored")
		end,
	},
}
