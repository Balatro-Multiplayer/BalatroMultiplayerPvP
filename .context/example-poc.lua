-- PvP-local content definitions, NOT a scheduler. See CHAOS_CLOCK_DESIGN.md.
-- Ordinary entries compete inside cadence budgets; never roll each independently.
-- absolute_chance is per eligible played blind, inside the incident budget.
-- Claims prohibit overlapping owners, including static/legacy layer effects.
PVP.CHAOS_TASTE = { effects = {} }
local pack, presets = PVP.CHAOS_TASTE, { "calm", "normal", "mayhem" }
pack.tuning = {
	ante_chance = { calm = 0.45, normal = 0.65, mayhem = 0.85 },
	encounter_chance = { calm = 0.20, normal = 0.35, mayhem = 0.50 },
	incident_chance = { calm = 0.08, normal = 0.16, mayhem = 0.26 },
	lasting_share_of_ante = { calm = 0, normal = 0.06, mayhem = 0.12 },
	lasting_cap = { calm = 0, normal = 2, mayhem = 3 },
	mayhem_identity_chance = 0.10, -- playtest starting values, not implemented rolls
}

local function recipe(key, label, kind, at, lasts, effect, options)
	options = options or {}
	local def = {
		key = key,
		label = label,
		kind = kind,
		tiers = {},
		grant = options.grant,
		roll_scope = options.roll_scope,
		replay = options.replay,
	}
	local layer, claims
	if type(effect) == "table" then
		layer, claims = "clock_taste_" .. key, {}
		for field, values in pairs(effect) do
			for name in pairs(values) do
				claims[#claims + 1] = field .. "." .. name
			end
		end
		table.sort(claims)
		MPAPI.Layer(layer, effect)
	end
	for i, preset in ipairs(presets) do
		local override = (options.profiles or {})[preset]
		if override ~= false then
			local entry = {
				at = at,
				lasts = lasts,
				layer = layer,
				claims = claims,
				run = type(effect) == "function" and effect or nil,
				pending = effect == nil,
			}
			for field, value in pairs(override or {}) do
				entry[field] = value
			end
			def.tiers[i] = entry
		end
	end
	pack.effects[key] = def
end

function pack.profile(key, preset)
	local def = assert(pack.effects[key], "Unknown Clock recipe: " .. tostring(key))
	local index = ({ calm = 1, normal = 2, mayhem = 3 })[preset]
	assert(index, "Unknown Clock preset: " .. tostring(preset))
	return def.tiers[index]
end

local normal_up = { calm = false }
local mayhem_only = { calm = false, normal = false }
local function cash(amount)
	return function()
		ease_dollars(amount)
	end
end
local function selected(rng, coord, amount, apply)
	for _, card in ipairs(rng:pick(G.hand.cards, amount, "clock_taste", coord)) do
		apply(card)
	end
end
local function seal(key)
	return function(rng, coord)
		selected(rng, coord, 1, function(card)
			card:set_seal(key, nil, true)
		end)
	end
end

-- Fixed cores. Mayhem changes exposure/identity, not every numeric parameter.
recipe(
	"second_wind",
	"Second Wind",
	"buff",
	"blind",
	"blind",
	{ round_deltas = { hands = 1 } },
	{ profiles = { mayhem = { at = "ante", lasts = "ante" } } }
)
recipe("fresh_start", "Fresh Start", "buff", "blind", "blind", { round_deltas = { discards = 1 } })
-- Same family as the original wall's frugal effect: never draw both separately.
recipe(
	"waste_not",
	"Waste Not",
	"buff",
	"blind_entry",
	"blind",
	{ game_modifiers = { money_per_discard = 1 } },
	{ profiles = { mayhem = { at = "ante", lasts = "ante" } } }
)
recipe("shop_subsidy", "Shop Subsidy", "buff", "shop", "instant", cash(5))
recipe("pocket_change", "Pocket Change", "buff", "first_hand", "instant", cash(3))
recipe("gold_rush", "Gold Rush", "buff", "first_hand", "instant", seal("Gold"))
recipe(
	"all_in",
	"All In",
	"tradeoff",
	"blind",
	"blind",
	{ round_deltas = { hands = 1, discards = -1 } },
	{ profiles = { mayhem = { at = "ante", lasts = "ante" } } }
)
recipe(
	"paid_overtime",
	"Paid Overtime",
	"tradeoff",
	"first_hand",
	"blind",
	{ round_deltas = { hands = 1 }, game_modifiers = { no_extra_hand_money = true } }
)
recipe(
	"discard_dividend",
	"Discard Dividend",
	"tradeoff",
	"blind_entry",
	"blind",
	{ round_deltas = { discards = 1 }, game_modifiers = { discard_cost = 1, money_per_discard = 2 } },
	{ profiles = { mayhem = { at = "ante", lasts = "ante" } } }
)
recipe(
	"working_capital",
	"Working Capital",
	"tradeoff",
	"ante",
	"ante",
	{ round_deltas = { hands = 1 }, game_modifiers = { no_interest = true } },
	{ profiles = normal_up }
)

-- Explicit lasting versions enter the ante slot's lasting pool, not a bonus roll.
recipe(
	"fresh_start_lasting",
	"Fresh Start",
	"buff",
	"ante",
	"run",
	{ round_deltas = { discards = 1 } },
	{ profiles = normal_up }
)
recipe(
	"second_wind_lasting",
	"Second Wind",
	"buff",
	"ante",
	"run",
	{ round_deltas = { hands = 1 } },
	{ profiles = mayhem_only }
)
recipe(
	"waste_not_lasting",
	"Waste Not",
	"buff",
	"ante",
	"run",
	{ game_modifiers = { money_per_discard = 1 } },
	{ profiles = normal_up }
)
recipe(
	"working_capital_lasting",
	"Working Capital",
	"tradeoff",
	"ante",
	"run",
	{ round_deltas = { hands = 1 }, game_modifiers = { no_interest = true } },
	{ profiles = mayhem_only }
)
-- Tentative corruption candidate: pending until balance is confirmed.
recipe("no_interest_lasting", "No Interest", "hostile", "ante", "run", nil, { profiles = mayhem_only })

-- Instants finish; changed cards remain. Storm is a distinct whole-hand variant.
local function suit_change(amount)
	return function(rng, coord)
		local suit = rng:element({ "Spades", "Hearts", "Clubs", "Diamonds" }, "suit_drift", coord)
		selected(rng, coord, amount or #G.hand.cards, function(card)
			SMODS.change_base(card, suit)
		end)
	end
end
recipe("suit_drift", "Suit Drift", "weird", "first_hand", "instant", suit_change(1))
recipe("suit_storm", "Suit Storm", "weird", "first_hand", "instant", suit_change(), { profiles = mayhem_only })
recipe("blue_hour", "Blue Hour", "buff", "first_hand", "instant", seal("Blue"))
recipe("red_letter_day", "Red Letter Day", "buff", "first_hand", "instant", function(rng, coord)
	if not G.GAME.modifiers.mp_no_red_seals then seal("Red")(rng, coord) end
end, { profiles = normal_up })

recipe("polymorph", "Polymorph", "wildcard", "first_hand", "instant", function(rng, coord)
	for i, card in ipairs(rng:pick(G.jokers.cards, 1, "polymorph_cards", coord)) do
		local pool = {}
		for _, center in ipairs(G.P_CENTER_POOLS.Joker) do
			if
				center ~= card.config.center
				and center.rarity == card.config.center.rarity
				and not G.GAME.banned_keys[center.key]
				and not MPAPI.should_exclude_from_pool(center)
			then
				pool[#pool + 1] = center
			end
		end
		table.sort(pool, function(a, b)
			return a.key < b.key
		end)
		local center = rng:element(pool, "polymorph_center", coord, i)
		if center then
			card:remove_from_deck()
			card:set_ability(center)
			card:add_to_deck()
			card:set_cost()
		end
	end
end, { profiles = { calm = false, normal = false, mayhem = { absolute_chance = 0.01 } } })

-- Approved concepts, not working layers. See effect-shortlist.md for contracts.
-- nil keeps these pending; never select a stub as an active effect.
-- Preset coverage is provisional except Bonfire (Normal/Mayhem).
recipe("loaded_dice", "Loaded Dice", "weird", "blind", "blind", nil)
recipe("everybody_counts", "Everybody Counts", "buff", "blind", "blind", nil)
recipe("clearance_sale", "Clearance Sale", "tradeoff", "shop", "shop", nil)
recipe("bonfire", "Bonfire", "tradeoff", "blind", "blind", nil, { profiles = normal_up })

-- Grant stubs: delivery/capacity and recorded MP interactions are not implemented.
-- pending entries MUST be excluded from selection; never count a silent no-op.
recipe("fool", "A Fool Appears", "buff", "first_hand", "instant", nil, {
	grant = { key = "c_fool", amount = 1 }, -- no prior-card requirement
	profiles = {
		calm = { absolute_chance = 0.02 },
		normal = { absolute_chance = 0.03 },
		mayhem = { absolute_chance = 0.04 },
	},
})
recipe("fistful_of_fools", "Fistful of Fools", "wildcard", "first_hand", "instant", nil, {
	grant = { key = "c_fool", amount = 3 },
	profiles = { calm = false, normal = false, mayhem = { absolute_chance = 0.003 } },
})
recipe("negative_death", "Negative Death", "wildcard", "first_hand", "instant", nil, {
	grant = { key = "c_death", edition = "e_negative", amount = 1 },
	profiles = { calm = false, normal = { absolute_chance = 0.002 }, mayhem = { absolute_chance = 0.005 } },
})
recipe("negative_magnet", "Animal Magnetism", "wildcard", "first_hand", "instant", nil, {
	grant = { key = "j_mp_magnet_sandbox", edition = "e_negative", amount = 1 },
	roll_scope = "multiplayer",
	replay = "recorded_multiplayer",
	profiles = { calm = false, normal = false, mayhem = { absolute_chance = 0.005 } },
})
