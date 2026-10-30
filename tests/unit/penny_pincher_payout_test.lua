-- Plain Lua test: the real Penny Pincher pays for the opponent's shop it points at,
-- whether or not a Pincher was held when that shop's spend arrived, and however
-- many copies are held. The opponent context is dispatched the way MPAPI's
-- mpapi_opponent_context on_receive does it (each held card's center:calculate).
-- Run from the repo root: luajit tests/unit/penny_pincher_payout_test.lua
local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end

-- Mirrors api/context/opponent.lua's on_receive.
local function api_on_receive(_, from, params)
	local context = params or {}
	context.from = from
	for _, area in ipairs({ G.jokers, G.consumeables }) do
		for _, card in ipairs(area.cards) do
			local center = card.config.center
			if center.calculate then
				center:calculate(card, context)
			end
		end
	end
end

local pincher
MPAPI = {
	ActionTypes = { mpapi_opponent_context = { on_receive = api_on_receive } },
	sendWarnMessage = function() end,
	Joker = function(def)
		pincher = def
	end,
}
SMODS = { Atlas = function() end }
PVP = {
	UTILS = { add_nemesis_info = function() end },
	self_player_id = function()
		return "me"
	end,
	current_target_id = function()
		return "them"
	end,
	is_byed = function()
		return false
	end,
}

local function new_game()
	PVP.GAME = { enemy = { sells = 0, sells_per_ante = {}, spent_in_shop = {} }, pincher_index = 1 }
	G = { GAME = { round_resets = { ante = 1 } }, jokers = { cards = {} }, consumeables = { cards = {} } }
end
local function hold_pincher()
	local card = { config = { center = pincher }, ability = { extra = { dollars = 1, nemesis_dollars = 3 } } }
	G.jokers.cards[#G.jokers.cards + 1] = card
	return card
end
local function opponent_leaves_shop(spent)
	MPAPI.ActionTypes.mpapi_opponent_context.on_receive(nil, "them", { opponent_spent_in_shop = spent })
end

new_game()
dofile("objects/jokers/penny_pincher.lua")
for _, f in ipairs({ "lib/opponent_record.lua", "pvp_api/actions/opponent_context.lua" }) do
	local file = io.open(f)
	if file then
		file:close()
		dofile(f)
	end
end

-- Bought after the opponent's first shop: the second shop still pays for itself.
new_game()
opponent_leaves_shop(9)
local card = hold_pincher()
opponent_leaves_shop(6)
PVP.GAME.pincher_index = 2
check("Pincher bought late pays for shop 2 ($6 / 3)", pincher.calc_dollar_bonus(pincher, card), 2)

-- Two copies: each shop is counted once, so shop 2 is still the $6 one.
new_game()
local a = hold_pincher()
hold_pincher()
opponent_leaves_shop(9)
opponent_leaves_shop(6)
PVP.GAME.pincher_index = 2
check("two Pinchers: shop 2 pays $2", pincher.calc_dollar_bonus(pincher, a), 2)
check("two Pinchers: one record per shop", #PVP.GAME.enemy.spent_in_shop, 2)
local total = 0
for _, c in ipairs(G.jokers.cards) do
	total = total + (pincher.calc_dollar_bonus(pincher, c) or 0)
end
check("two Pinchers: each pays, $4 in total", total, 4)

if failures > 0 then
	print(failures .. " failure(s)")
	os.exit(1)
end
print("all passed")
