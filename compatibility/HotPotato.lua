if SMODS.Mods["HotPotato"] and SMODS.Mods["HotPotato"].can_load then
	PVP.match_log("debug", "HotPotato compatibility detected")
	PVP.DECK.ban_card("j_hpot_antidsestablishmentarianism") -- sic
	PVP.DECK.ban_card("j_hpot_brainfuck")
	PVP.DECK.ban_card("j_hpot_goldenchicot")
	PVP.DECK.ban_card("j_hpot_lockin")
	PVP.DECK.ban_card("j_joker")
	PVP.DECK.ban_card("j_hpot_lotus")
	PVP.DECK.ban_card("j_hpot_c_sharp")

	PVP.DECK.ban_card("j_hpot_goblin_tinkerer") -- too easy to infinite

	-- essentially we're just hooking a bunch of functions to separate and normalise rng
	-- i was gonna hook more but it ended up only being 2 so whatever

	local hooks = {
		{ tbl = _G, str = "hotpot_delivery_refresh_card" },
		{ tbl = _G, str = "hotpot_jtem_generate_special_deals" },
	}

	local function hook(orig, ante)
		return function(...)
			local temp_ante = G.GAME.round_resets.ante
			G.GAME.round_resets.ante = 89

			local temp_used_jokers = G.GAME.used_jokers
			G.GAME.used_jokers = {}

			-- Suppress Order-mode determinism during this fake-ante reward roll: base-game
			-- lovely patches (TheOrder.toml, now shipped from BalatroMultiplayerAPI) call
			-- MPAPI.should_use_the_order() directly, not PVP.should_use_the_order -- monkeypatch
			-- MPAPI's function or this suppression silently does nothing.
			local temp_should_use_the_order = MPAPI.should_use_the_order
			MPAPI.should_use_the_order = function()
				return false
			end

			local results = orig(...)

			G.GAME.round_resets.ante = temp_ante
			G.GAME.used_jokers = temp_used_jokers
			MPAPI.should_use_the_order = temp_should_use_the_order

			return results
		end
	end
	for i, v in pairs(hooks) do
		local orig = v.tbl[v.str]
		v.tbl[v.str] = hook(orig)
	end
	local grant_wheel_reward_ref = grant_wheel_reward
	function grant_wheel_reward(card)
		if not card then
			print("this should never happen")
			card = G.wheel_rewards.cards[1]
		end
		if card.ability.set ~= "bottlecap" then
			G.GAME.used_jokers[card.config.center.key] = true -- if there's no room, card will be removed so this is safe
		end
		return grant_wheel_reward_ref(card)
	end
	local generate_wheel_rewards_ref = generate_wheel_rewards
	function generate_wheel_rewards(_amount)
		-- randomise rotation
		local rot = pseudorandom("hpot_wheel_rotation") * 2 * math.pi
		G.wheel_arrow.cards[1].T.r = rot
		G.GAME.keep_rotation = rot

		-- constants from experimentation
		-- this range encompasses an entire wheel spin, making every endpos equally likely
		local min = 0.486225001705432
		local max = 0.502020498677871
		Wheel.starting_accel = (pseudorandom("hpot_wheel_starting_accel") * (max - min)) + min

		-- nullify any vval (idk what this does exactly but it's annoying)
		G.GAME.vval = 0
		G.GAME.winning_vval = (G.GAME.vval / 10)
		Wheel.KeepVval = G.GAME.vvals

		-- basic rng isolation stuff
		local temp_used_jokers = G.GAME.used_jokers
		G.GAME.used_jokers = {}

		local temp_ante = G.GAME.round_resets.ante
		G.GAME.round_resets.ante = 78

		-- See the hook() function above for why this targets MPAPI's function, not PVP's.
		local temp_should_use_the_order = MPAPI.should_use_the_order
		MPAPI.should_use_the_order = function()
			return false
		end

		local ret = generate_wheel_rewards_ref(_amount)

		G.GAME.round_resets.ante = temp_ante
		G.GAME.used_jokers = temp_used_jokers
		MPAPI.should_use_the_order = temp_should_use_the_order

		return ret
	end
	local spin_wheel_ref = spin_wheel
	function spin_wheel(...) -- this function name sucks
		local ret = spin_wheel_ref(...)
		Wheel.accel = Wheel.starting_accel
		return ret
	end
	local set_ability_ref = Card.set_ability
	function Card:set_ability(center, initial, delay_sprites)
		if not G.OVERLAY_MENU then
			if
				(center.mp_include and type(center.mp_include) == "function" and not center:mp_include())
				or G.GAME.banned_keys[center.key]
			then
				local swap = false
				local done = false
				while not done do
					for i, v in ipairs(G.P_CENTER_POOLS[center.set]) do
						if swap then
							return self:set_ability(v, initial, delay_sprites) -- do not return ref
						end
						if v == center then swap = true end
					end
				end
			end
		end
		return set_ability_ref(self, center, initial, delay_sprites)
	end
end
