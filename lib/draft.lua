PVP.DRAFT = {}
local D = PVP.DRAFT

-- Challenge Deck is only playable inside a challenge.
local NON_DRAFT_BASE_DECKS = { b_challenge = true }

local function key_set(list)
	local set = {}
	for _, key in ipairs(list or {}) do
		set[key] = true
	end
	return set
end

function D.candidates(backs, allowed, banned)
	local allowed_set, banned_set = key_set(allowed), key_set(banned)
	local keys = {}
	for _, back in ipairs(backs) do
		local base = back.mod_id == nil and not NON_DRAFT_BASE_DECKS[back.key]
		if (base or allowed_set[back.key]) and not banned_set[back.key] then keys[#keys + 1] = back.key end
	end
	return keys
end

-- nil asks the builder for the default stake range.
function D.stakes(allowed_stakes, stake_keys, cap)
	if not allowed_stakes or #allowed_stakes == 0 then return nil end
	local allowed_set = key_set(allowed_stakes)
	local indices = {}
	for index, key in ipairs(stake_keys) do
		if index <= cap and allowed_set[key] then indices[#indices + 1] = index end
	end
	return #indices > 0 and indices or nil
end

local DRAFT_SIZE, MAX_PER_STAKE, MAX_PER_DECK, WHITE = 9, 4, 3, 1

local deck_rank, ranked_pool = {}, nil
local function deck_order(key)
	local pool = G and G.P_CENTER_POOLS and G.P_CENTER_POOLS.Back
	if pool ~= ranked_pool then
		deck_rank, ranked_pool = {}, pool
		for i, center in ipairs(pool or {}) do
			deck_rank[center.key] = i
		end
	end
	return deck_rank[key] or math.huge
end

function D.tile_order(a, b)
	if a.stake ~= b.stake then return a.stake < b.stake end
	return deck_order(a.key) < deck_order(b.key)
end

local board_rng = PVP.new_rng()

function D.board(decks, stakes, opts)
	opts = opts or {}
	local rng = opts.rng or board_rng
	local size = opts.size or DRAFT_SIZE
	local weights = opts.weights or {}
	local options = {}
	for _, stake in ipairs(stakes) do
		for _, key in ipairs(decks) do
			options[#options + 1] = { key = key, stake = stake, weight = weights[stake] or 1 }
		end
	end
	-- Relax the stake cap when too few stakes are available to fill the board.
	local per_stake_max = math.max(MAX_PER_STAKE, math.ceil(size / math.max(#stakes, 1)))

	local board, per_stake, per_deck, used = {}, {}, {}, {}
	local function open(only_white)
		local out = {}
		for _, o in ipairs(options) do
			if
				not used[o]
				and (per_stake[o.stake] or 0) < per_stake_max
				and (per_deck[o.key] or 0) < MAX_PER_DECK
				and (o.stake == WHITE or not only_white)
			then
				out[#out + 1] = o
			end
		end
		return out
	end
	local function take(list)
		local total = 0
		for _, item in ipairs(list) do
			total = total + item.weight
		end
		local r, o = rng() * total, list[#list]
		for _, item in ipairs(list) do
			r = r - item.weight
			if r < 0 then
				o = item
				break
			end
		end
		used[o] = true
		per_stake[o.stake] = (per_stake[o.stake] or 0) + 1
		per_deck[o.key] = (per_deck[o.key] or 0) + 1
		board[#board + 1] = { id = o.key .. "@" .. o.stake, key = o.key, stake = o.stake }
	end

	-- Reserve one White tile when White is allowed.
	local whites = open(true)
	if #whites > 0 and size > 0 then take(whites) end
	while #board < size do
		local left = open(false)
		if #left == 0 then break end
		take(left)
	end
	table.sort(board, D.tile_order)
	return board
end

function D.build(opts)
	local backs, stake_keys = {}, {}
	for _, center in ipairs(G.P_CENTER_POOLS.Back or {}) do
		backs[#backs + 1] = { key = center.key, mod_id = center.mod and center.mod.id }
	end
	for i, center in ipairs(G.P_CENTER_POOLS.Stake or {}) do
		stake_keys[i] = center.key
	end
	local function field(key)
		return MPAPI.resolve_ruleset_field(opts.ruleset, key)
	end
	-- Explicitly allowed stakes may exceed the vanilla default of 8.
	-- A compatibility cap still limits both explicit and default stakes.
	local cap = opts.max_stake and opts.max_stake > 0 and opts.max_stake or nil
	local stakes = D.stakes(field("allowed_stakes"), stake_keys, cap or math.huge)
	if not stakes then
		stakes = {}
		for i = 1, math.min(cap or 8, #stake_keys) do
			stakes[i] = i
		end
	end
	local declared_weights = field("stake_weights") or {}
	local weights = {}
	for i, key in ipairs(stake_keys) do
		weights[i] = declared_weights[key]
	end
	local decks = D.candidates(backs, field("allowed_backs"), field("banned_backs"))
	return D.board(decks, stakes, { size = opts.size, weights = weights, rng = opts.rng })
end
