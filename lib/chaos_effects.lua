-- Catalogue, not a second scheduler. The adapter excludes static layer claims
-- before a timed recipe can be activated.
local C = PVP.CHAOS
local blind = { boundary = "blind_end", count = 1 }

local function recipe(key, label, description, deltas, modifiers)
	local claims = {}
	for field in pairs(deltas or {}) do
		claims[#claims + 1] = "round." .. field
	end
	for field in pairs(modifiers or {}) do
		claims[#claims + 1] = "modifier." .. field
	end
	table.sort(claims)
	C.define({
		key = key,
		label = label,
		description = description,
		at = "blind_select",
		duration = blind,
		claims = claims,
		payload = { round_deltas = deltas, modifiers = modifiers },
	})
end

recipe("second_wind", "Second Wind", "+1 hand for the next blind.", { hands = 1 })
recipe("fresh_start", "Fresh Start", "+1 discard for the next blind.", { discards = 1 })
recipe("all_in", "All In", "+1 hand, -1 discard for the next blind.", { hands = 1, discards = -1 })
recipe(
	"paid_overtime",
	"Paid Overtime",
	"+1 hand; no unused-hand money this blind.",
	{ hands = 1 },
	{ no_extra_hand_money = true }
)
recipe(
	"discard_dividend",
	"Discard Dividend",
	"+1 discard; discards cost $1 and unused discards pay $2 this blind.",
	{ discards = 1 },
	{ discard_cost = 1, money_per_discard = 2 }
)
recipe("working_capital", "Working Capital", "+1 hand; no interest this blind.", { hands = 1 }, { no_interest = true })
recipe("waste_not", "Waste Not", "Unused discards pay $1 this blind.", nil, { money_per_discard = 1 })

C.define({
	key = "everybody_counts",
	label = "Everybody Counts",
	description = "Every played card scores this blind. Poker-hand recognition is unchanged.",
	at = "blind_select",
	duration = blind,
	claims = { "all_cards_score" },
	payload = { rule = "all_cards_score" },
})

C.define({
	key = "higher_calling",
	label = "Higher Calling",
	description = "Judgement produces unusually good Jokers this ante.",
	at = "ante",
	duration = { boundary = "ante_end", count = 1 },
	claims = { "judgement_quality" },
	payload = {
		rule = "higher_calling",
		rare = 2,
		legendary = 0.005,
		negative = 2.5,
		polychrome = 3,
	},
})

C.define({
	key = "one_of_each",
	label = "One of Each",
	description = "Only the leftmost played card of each rank can score this blind. Rankless cards are exempt.",
	at = "blind_select",
	duration = blind,
	claims = { "one_of_each" },
	payload = { rule = "one_of_each" },
})

for _, entry in ipairs({
	{ "shop_subsidy", "Shop Subsidy", "Gain $5 now. Expiry does not reclaim it.", 5, "shop" },
	{ "pocket_change", "Pocket Change", "Gain $3 now. Expiry does not reclaim it.", 3, "blind_select" },
}) do
	C.define({
		key = entry[1],
		label = entry[2],
		description = entry[3],
		at = entry[5],
		duration = "instant",
		payload = { cash = entry[4] },
	})
end

-- Visible contracts, never functioning empty layers or random candidates.
for _, entry in ipairs({
	{
		"loaded_dice",
		"Loaded Dice",
		"Double listed probabilities, including adverse outcomes, for one blind.",
		"Pending: probability coverage and composition contract",
		"blind_select",
	},
	{
		"clearance_sale",
		"Short Shelf Life",
		"Jokers offered here are free and Perishable; stickers persist.",
		"Pending: sticker compatibility, pre-generation reveal and resale protection",
		"shop",
	},
	{
		"bonfire",
		"Bonfire",
		"Destroy the first hand's scoring cards after scoring, once this blind.",
		"Pending: safe deck eligibility, destruction timing and saved card targets",
		"blind_select",
	},
	{
		"face_tax",
		"Face Tax",
		"Destroy scored face cards after every hand this blind.",
		"Pending: face-status snapshot, destruction timing and safe deck eligibility",
		"blind_select",
	},
	{
		"bankruptcy_protection",
		"Bankruptcy Protection",
		"Cannot gain money this blind; spending and losses remain.",
		"Pending: end-of-round payout boundary",
		"blind_select",
	},
	{
		"bad_investment",
		"Bad Investment",
		"Jokers offered here are Rental; stickers persist.",
		"Pending: offer generation, price and sticker compatibility",
		"shop",
	},
}) do
	C.define({
		key = entry[1],
		label = entry[2],
		description = entry[3],
		pending = entry[4],
		at = entry[5],
		duration = entry[5] == "shop" and { boundary = "shop_end", count = 1 } or blind,
	})
end
