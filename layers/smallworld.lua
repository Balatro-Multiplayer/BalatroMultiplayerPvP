MPAPI.Layer("smallworld", {
	calculate = function(self, context)
		if not context.apply_bans or G.GAME.pvp_smallworld_applied then return end
		G.GAME.pvp_smallworld_applied = true
		local tables = {}
		local requires = {}
		for k, v in pairs(G.P_CENTERS) do
			if
				v.set
				and not G.GAME.banned_keys[k]
				and not (v.requires or v.hidden)
				and k ~= "j_cavendish"
				and not MPAPI.should_exclude_from_pool(v)
			then
				local index = v.set .. (v.rarity or "")
				tables[index] = tables[index] or {}
				local t = tables[index]
				t[#t + 1] = k
			end
			if v.set == "Voucher" and v.requires then requires[#requires + 1] = k end
		end
		for k, v in pairs(G.P_TAGS) do -- tag exemption
			if not G.GAME.banned_keys[k] and not MPAPI.should_exclude_from_pool(v) then
				tables["Tag"] = tables["Tag"] or {}
				local t = tables["Tag"]
				t[#t + 1] = k
			end
		end
		for k, v in pairs(tables) do
			if k ~= "Back" and k ~= "Edition" and k ~= "Enhanced" and k ~= "Default" then
				table.sort(v)
				pseudoshuffle(v, pseudoseed(k .. "_mp_smallworld"))
				local threshold = math.floor(0.5 + (#v * 0.75))
				local ii = 1
				if k == "Voucher" and not PVP.legacy_smallworld() then ii = ii + 1 end
				for i, vv in ipairs(v) do
					if ii <= threshold then
						G.GAME.banned_keys[vv] = true
						ii = ii + 1
					else
						break
					end
				end
			end
		end
		-- below bans shouldn't matter (except for blank placeholder) but whatever
		for i, v in ipairs(requires) do
			if G.GAME.banned_keys[G.P_CENTERS[v].requires[1]] then G.GAME.banned_keys[v] = true end
		end
		if G.GAME.banned_keys["j_gros_michel"] then G.GAME.banned_keys["j_cavendish"] = true end
	end,
})

local showman_ref = SMODS.showman
function SMODS.showman(card_key)
	if PVP.is_layer_active("smallworld") then return true end
	return showman_ref(card_key)
end

-- replace banned tags
local tag_init_ref = Tag.init
function Tag:init(_tag, for_collection, _blind_type)
	local orbital = false
	local old = G.orbital_hand -- i think this is always nil here but just to be safe
	if PVP.is_layer_active("smallworld") and not PVP.legacy_smallworld() then
		if G.GAME.banned_keys[_tag] and not G.OVERLAY_MENU then
			local a = G.GAME.round_resets.ante

			if PVP.should_use_the_order() then G.GAME.round_resets.ante = 10 end

			_tag = get_next_tag_key("replace")
			if _tag == "tag_orbital" then orbital = true end

			G.GAME.round_resets.ante = a
		end
	end
	if orbital then G.orbital_hand = pseudorandom_element(PVP.sorted_hand_list(), pseudoseed("orbital_replace")) end
	tag_init_ref(self, _tag, for_collection, _blind_type)
	G.orbital_hand = old
end

local apply_to_run_ref = Back.apply_to_run
function Back:apply_to_run()
	if PVP.is_layer_active("smallworld") and not PVP.legacy_smallworld() then PVP.apply_fake_back_vouchers(self) end
	return apply_to_run_ref(self)
end

function PVP.apply_fake_back_vouchers(back)
	local vouchers = {}
	if back.effect.config.voucher then vouchers = { back.effect.config.voucher } end
	if back.effect.config.vouchers or #vouchers > 0 then
		vouchers = back.effect.config.vouchers or vouchers
		local fake_back = { effect = { config = { vouchers = copy_table(vouchers) } } }
		fake_back.effect.center = G.P_CENTERS["b_red"]
		fake_back.name = "FAKE"
		back.effect.config.vouchers = nil
		back.effect.config.voucher = nil
		G.E_MANAGER:add_event(Event({
			func = function()
				for i, v in ipairs(fake_back.effect.config.vouchers) do
					local voucher = v
					if G.GAME.banned_keys[v] or G.GAME.used_vouchers[v] then voucher = get_next_voucher_key() end
					G.GAME.used_vouchers[voucher] = true
					fake_back.effect.config.vouchers[i] = voucher
				end
				G.GAME.current_round.voucher = SMODS.get_next_vouchers() -- the extreme jank doesn't matter as long as it's synced ig
				apply_to_run_ref(fake_back)
				return true
			end,
		}))
	end
end

local add_joker_ref = add_joker
function add_joker(joker, edition, silent, eternal)
	if PVP.is_layer_active("smallworld") and G.GAME.banned_keys[joker] then
		local _pool = nil
		local _pool_key = nil
		local rarities = { [1] = 0, [2] = 0.9, [3] = 1, [4] = 1 }
		if G.P_CENTERS[joker].set == "Joker" then
			_pool, _pool_key = get_current_pool(
				"Joker",
				rarities[G.P_CENTERS[joker].rarity] or G.P_CENTERS[joker].rarity,
				G.P_CENTERS[joker].rarity == 4 and true or false
			)
		else
			_pool, _pool_key = get_current_pool(G.P_CENTERS[joker].set, nil)
		end
		local it = 1
		local center = "UNAVAILABLE"
		while center == "UNAVAILABLE" do
			it = it + 1
			center = pseudorandom_element(
				_pool,
				pseudoseed(_pool_key .. (PVP.should_use_the_order() and "" or ("_resample" .. it)))
			)
		end
		joker = center
	end
	return add_joker_ref(joker, edition, silent, eternal)
end

local card_apply_to_run_ref = Card.apply_to_run
function Card:apply_to_run(center)
	if PVP.is_layer_active("smallworld") then
		if not self and center and G.GAME.banned_keys[center.key] then
			G.GAME.used_vouchers[center.key] = nil
			center = G.P_CENTERS[get_next_voucher_key()]
			G.GAME.used_vouchers[center.key] = true
		end
	end
	return card_apply_to_run_ref(self, center)
end

function PVP.legacy_smallworld()
	return PVP.LOBBY.code and PVP.LOBBY.config and PVP.LOBBY.config.legacy_smallworld
end
