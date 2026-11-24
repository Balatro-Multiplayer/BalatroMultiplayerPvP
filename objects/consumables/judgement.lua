--[[ gotta redefine the logic
PVP.RULES.ReworkCenter({
	key = "c_judgement",
	ruleset = PVP.UTILS.get_standard_rulesets({'minorleague'}),
	silent = true,
	use = function(self, card, area, copier)
		local _card = copier or card
		G.E_MANAGER:add_event(Event({trigger = 'after', delay = 0.4, func = function()
			play_sound('timpani')
			if PVP.INTEGRATIONS.TheOrder then -- this only matters if order exists
				local done = false
				while not done do -- AHHH we have to do so much boilerplate
					done = true
					
					local card = { stickers = { eternal = false, perishable = false, rental = false } }
					local rarity = SMODS.poll_rarity("Joker", 'rarity0')
					local str_rarity = rarity
					if type(rarity) == 'number' then 
						str_rarity = ({'Common', 'Uncommon', 'Rare', 'Legendary'})[rarity] -- kill me now
					end
					local _pool = get_current_pool('Joker', str_rarity, nil, '')
					local _pool_key = 'Joker'..rarity..'0'
					center = pseudorandom_element(_pool, pseudoseed(_pool_key))
					local it = 1
					while center == 'UNAVAILABLE' do
						it = it + 1
						center = pseudorandom_element(_pool, pseudoseed(_pool_key))
					end
					
					card.key = center
					
					local eternal_perishable_poll = pseudorandom(center..'etperpoll0')
					local rental_poll = pseudorandom(center..'ssjr0')
				
					if G.GAME.modifiers.enable_eternals_in_shop 
					and eternal_perishable_poll > 0.7 
					and G.P_CENTERS[center].eternal_compat then
						card.stickers.eternal = true
						done = false
					end
					
					if G.GAME.modifiers.enable_perishables_in_shop 
					and ((eternal_perishable_poll > 0.4) and (eternal_perishable_poll <= 0.7)) 
					and G.P_CENTERS[center].perishable_compat then
						card.stickers.perishable = true
						done = false
					end
					
					if G.GAME.modifiers.enable_rentals_in_shop 
					and rental_poll > 0.7 then
						card.stickers.rental = true
						done = false
					end
					
					if done then
						table.insert(G.GAME.MP_joker_overrides, 1, card) -- start, so it gets created immediately
					else
						table.insert(G.GAME.MP_joker_overrides, card) -- end
					end
				end
			end
			G.MP_JUDGEMENT_OVERRIDE = true
			local joker = create_card('Joker', G.jokers, nil, nil, nil, nil, nil, 'jud') -- just call create card since override will kick in
			G.MP_JUDGEMENT_OVERRIDE = nil
			joker:add_to_deck()
			G.jokers:emplace(joker)
			_card:juice_up(0.3, 0.5)
			
			return true
		end}))
		delay(0.6)
	end,
})
]]
