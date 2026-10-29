PVP.SANDBOX = {}

-- Centralized joker mappings: defines sandbox variants, their vanilla counterparts, and rotation status
PVP.SANDBOX.joker_mappings = {
	-- Active jokers in rotation
	{ sandbox = "j_mp_misprint_sandbox", vanilla = "j_misprint", active = true },
	{ sandbox = "j_mp_castle_sandbox", vanilla = "j_castle", active = true },
	{ sandbox = "j_mp_mail_sandbox", vanilla = "j_mail", active = true },
	{ sandbox = "j_mp_square_sandbox", vanilla = "j_square", active = true },
	{ sandbox = "j_mp_throwback_sandbox", vanilla = "j_throwback", active = true },
	{ sandbox = "j_mp_vampire_sandbox", vanilla = "j_vampire", active = true },
	{ sandbox = "j_mp_steel_joker_sandbox", vanilla = "j_steel_joker", active = true },
	{ sandbox = "j_mp_baseball_sandbox", vanilla = "j_baseball", active = true },
	{ sandbox = "j_mp_hit_the_road_sandbox", vanilla = "j_hit_the_road", active = true },
	{ sandbox = "j_mp_golden_ticket_sandbox", vanilla = "j_ticket", active = true },
	-- Idol variants (all map to same vanilla joker)
	{ sandbox = "j_mp_idol_sandbox_zealot", vanilla = "j_idol", active = true },
	{ sandbox = "j_mp_idol_sandbox_collector", vanilla = "j_idol", active = true },

	-- Out of rotation
	{ sandbox = "j_mp_bloodstone_sandbox", vanilla = "j_bloodstone", active = false },
	{ sandbox = "j_mp_cloud_9_sandbox", vanilla = "j_cloud_9", active = false },
	{ sandbox = "j_mp_constellation_sandbox", vanilla = "j_constellation", active = false },
	{ sandbox = "j_mp_faceless_sandbox", vanilla = "j_faceless", active = false },
	{ sandbox = "j_mp_juggler_sandbox", vanilla = "j_juggler", active = false },
	{ sandbox = "j_mp_loyalty_card_sandbox", vanilla = "j_loyalty_card", active = false },
	{ sandbox = "j_mp_lucky_cat_sandbox", vanilla = "j_lucky_cat", active = false },
	{ sandbox = "j_mp_magnet_sandbox", vanilla = nil, active = false },
	{ sandbox = "j_mp_order_sandbox", vanilla = "j_order", active = false },
	{ sandbox = "j_mp_photograph_sandbox", vanilla = "j_photograph", active = false },
	{ sandbox = "j_mp_ride_the_bus_sandbox", vanilla = "j_ride_the_bus", active = false },
	{ sandbox = "j_mp_runner_sandbox", vanilla = "j_runner", active = false },
	{ sandbox = "j_mp_satellite_sandbox", vanilla = "j_satellite", active = false },

	-- Extra Credit jokers
	-- { sandbox = "j_mp_alloy_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_ambrosia_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_bobby_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_candynecklace_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_chainlightning_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_clowncar_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_clowncollege_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_couponsheet_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_doublerainbow_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_espresso_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_farmer_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_forklift_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_gofish_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_hoarder_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_jokalisa_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_jokeroftheyear_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_lucky7_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_montehaul_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_pocketaces_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_pyromancer_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_shipoftheseus_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_starfruit_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_trafficlight_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_tuxedo_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_warlock_sandbox", vanilla = nil, active = true, group = "extra_credit" },
	{ sandbox = "j_mp_werewolf_sandbox", vanilla = nil, active = true, group = "extra_credit" },
}

--- Returns list of active sandbox joker keys
--- @return table List of sandbox joker keys that are active
function PVP.SANDBOX.get_active_sandbox_jokers()
	local active = {}
	for _, mapping in ipairs(PVP.SANDBOX.joker_mappings) do
		if mapping.active then table.insert(active, mapping.sandbox) end
	end
	return active
end

--- Returns list of unique vanilla joker keys to ban
--- @return table List of vanilla joker keys to silently ban
function PVP.SANDBOX.get_vanilla_bans()
	local bans = {}
	local seen = {}
	for _, mapping in ipairs(PVP.SANDBOX.joker_mappings) do
		if mapping.active and mapping.vanilla and not seen[mapping.vanilla] then
			table.insert(bans, mapping.vanilla)
			seen[mapping.vanilla] = true
		end
	end
	return bans
end

--- Centralized allowlist check for sandbox jokers
--- @param joker_key string The key of the joker to check (e.g., "j_mp_mail_sandbox")
--- @return boolean true if the joker is allowed in the sandbox ruleset and in a multiplayer lobby
function PVP.SANDBOX.is_joker_allowed(joker_key)
	if not PVP.is_layer_active(PVP.LayerKey.SANDBOX) then return false end

	for _, mapping in ipairs(PVP.SANDBOX.joker_mappings) do
		if mapping.active and mapping.sandbox == joker_key then return true end
	end

	return false
end

--- Randomly selects one idol variant to be available in the sandbox layer
--- Bans the other idol variants to ensure only one is available per game
--- Uses pseudorandom selection based on the lobby seed for consistency across players
local function select_random_idol()
	local idol_keys = {
		"j_mp_idol_sandbox_zealot",
		"j_mp_idol_sandbox_collector",
	}
	table.sort(idol_keys)

	-- Pseudorandom shuffle using the lobby seed so all players get the same idol
	pseudoshuffle(idol_keys, pseudoseed("idol_selection_mp_sandbox"))

	-- Ban all idols except the first one (which is now randomly selected)
	for i = 2, #idol_keys do
		G.GAME.banned_keys[idol_keys[i]] = true
	end
end

MPAPI.Layer(PVP.LayerKey.SANDBOX, {
	multiplayer_content = true,
	banned_jokers = { "j_hanging_chad", "j_mp_conjoined_joker" },
	banned_silent = PVP.SANDBOX.get_vanilla_bans(),
	banned_consumables = { "c_ouija", "c_ectoplasm" },
	banned_tags = { "tag_rare", "tag_juggle", "tag_investment" },
	-- Sandbox jokers gate themselves through mp_include; Hanging Chad has none.
	reworked_jokers = { "j_mp_hanging_chad" },
	reworked_consumables = { "c_mp_ouija_standard", "c_mp_ectoplasm_sandbox" },
	reworked_enhancements = { "m_glass" },
	reworked_tags = { "tag_mp_gambling_sandbox", "tag_mp_juggle_sandbox", "tag_mp_investment_sandbox" },
	calculate = function(self, context)
		if not context.apply_bans then return end
		select_random_idol()

		if SMODS.Mods["extracredit"] and SMODS.Mods["extracredit"].can_load then
			print("Banning sandbox jokers")
			for _, mapping in ipairs(PVP.SANDBOX.joker_mappings) do
				if mapping.group == "extra_credit" then G.GAME.banned_keys[mapping.sandbox] = true end
			end
		end
	end,
})

-- debugging hotswitch
PVP.sandbox_no_collection = not PVP.EXPERIMENTAL.show_sandbox_collection
