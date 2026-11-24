-- The run-side inputs and what the view says of the opponent's run. Pure: plain values in, plain values
-- out, no game and no net. pvp_api/ui/run.lua is the shell that sends and shows. Every body builder answers
-- nil for a value of the wrong shape, so nothing malformed is sent; the server owns the limits.
local reader = {}
PVP.READ.run = reader
local views = PVP.READ.view

local MOST_SPENT = 1000000
local BLINDS = { Small = true, Big = true, Boss = true }
local EFFECTS = { asteroid = true, pizza = true, gambling = true }

local function text(value)
	return type(value) == "string" and value ~= ""
end

-- The server's blind key: "<ante>:Small|Big|Boss".
function reader.blind_key(ante, blind)
	if not (views.whole(ante) and BLINDS[blind]) then return nil end
	return views.blind_key(ante, blind)
end

function reader.progress(ante, location)
	if not (views.whole(ante) and text(location)) then return nil end
	return { ante = ante, location = location }
end

local BLIND_RESULTS = { ["beaten"] = true, ["failed on the clock"] = true, ["lost"] = true }

-- result: "beaten", "failed on the clock", or "lost" (a blind failed on the cards). A skip has its own input.
function reader.blind_result(ante, blind, result)
	local key = reader.blind_key(ante, blind)
	if not (key and BLIND_RESULTS[result]) then return nil end
	return { blindKey = key, result = result }
end

-- Only a Small or Big blind can be skipped; total is the skips of this run.
function reader.skip(ante, blind, total)
	local key = blind ~= "Boss" and reader.blind_key(ante, blind)
	if not (key and views.whole(total, 1)) then return nil end
	return { blindKey = key, total = total }
end

function reader.sell(ante, total)
	if not (views.whole(ante) and views.whole(total, 1)) then return nil end
	return { ante = ante, total = total }
end

-- total is the shops closed this run; spent is the whole dollars spent in this one (0 for a skipped
-- shop: the server counts a missing spend as 0 and Lua cannot send null). A bigger spend counts as the most.
function reader.shop(ante, total, spent)
	if not (views.whole(ante) and views.whole(total, 1)) then return nil end
	if type(spent) ~= "number" or spent ~= spent or spent < 0 then return nil end
	return { ante = ante, total = total, spent = math.min(math.floor(spent), MOST_SPENT) }
end

function reader.voucher(key)
	if not text(key) then return nil end
	return { voucherKey = key }
end

function reader.effect(effect, total)
	if not (EFFECTS[effect] and views.whole(total, 1)) then return nil end
	return { effect = effect, total = total }
end

local function number_or_nil(value)
	return type(value) == "number" and value or nil
end

-- Sells by ante number; a count or an ante that is not a number is left out.
local function sells_by_ante(sells)
	if type(sells) ~= "table" then return nil end
	local out = {}
	for ante, count in pairs(sells) do
		if tonumber(ante) and type(count) == "number" then out[tonumber(ante)] = count end
	end
	return out
end

-- The opponent lives the HUD shows: the opponent's when the view names one, else the highest lives of
-- the other players, or nil while the view has none.
function reader.opponent_lives(view)
	local id = views.opponent_id(view)
	if id then return views.lives_of(view, id) end
	local run = views.run(view)
	local players = run and type(run.players) == "table" and run.players or {}
	local highest
	for other, player in pairs(players) do
		local lives = other ~= view.me and type(player) == "table" and number_or_nil(player.lives) or nil
		if lives and (highest == nil or lives > highest) then highest = lives end
	end
	return highest
end

-- The opponent's run as the view shows it, or nil with no view, no run or no opponent. A field the
-- view lacks is nil here: unknown. shop_spends[n] is the dollars spent in shop n, nil if the view has no total.
function reader.opponent_facts(view)
	local id = views.opponent_id(view)
	local player = id and views.run_player(view, id)
	if not player then return nil end
	local spends
	if type(player.shopSpends) == "table" then
		spends = {}
		-- A shop without a total is a null in the list: a hole here, so # cannot be trusted.
		for place, spent in pairs(player.shopSpends) do
			if type(place) == "number" then spends[place] = number_or_nil(spent) end
		end
	end
	return {
		lives = number_or_nil(player.lives),
		ante = number_or_nil(player.ante),
		location = type(player.location) == "string" and player.location or nil,
		skips = number_or_nil(player.skips),
		sells = sells_by_ante(player.sells),
		shop_spends = spends,
	}
end

reader.FACTS = { "lives", "ante", "location", "skips", "sells", "shop_spends" }

-- True when the opponent's skip count was known before and is higher now: a blind skipped since the
-- last view. Never for the first view of a run (nothing known before).
function reader.skips_gained(before, now)
	return type(before) == "number" and type(now) == "number" and now > before
end

local function same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for key, value in pairs(a) do
		if not same(value, b[key]) then return false end
	end
	for key in pairs(b) do
		if a[key] == nil then return false end
	end
	return true
end

-- The names of the facts that differ from what was shown last. Nothing shown yet (nil): every name,
-- so the first view also clears what the game held before it. The same facts again: none.
function reader.changed(shown, facts)
	if shown == nil then return { unpack(reader.FACTS) } end
	local names = {}
	for _, name in ipairs(reader.FACTS) do
		if not same(shown[name], (facts or {})[name]) then names[#names + 1] = name end
	end
	return names
end

local function without_lives(facts)
	local copy = {}
	for name, value in pairs(facts) do copy[name] = value end
	copy.lives = nil
	return copy
end

-- What to show of the opponent's run this frame, and what to remember for the next.
-- before: { facts, id, lives_guess = "none" | "highest of others" } as returned in `next`, nil facts
-- while nothing is shown; table_is: "same" | "new" (the game's enemy record is a new one).
-- Returns { lives_from, reset, show, next }:
--   lives_from: where this frame's lives came from, "opponent" | "out opponent" | "highest of others" | "none".
--   reset: "keep" | "new opponent" | "guessed lives dropped"; the last two clear the enemy lives shown.
--   show: { name, value, before } in order.
-- A gap with no opponent keeps what is shown, except the lives. The server drops a player who is out of
-- the run from the targets, so the last opponent's last life is lost in this gap: while they are out,
-- their lives stay the ones shown. Any other gap (a bye, an unpaired ante, before the first pairing)
-- shows the highest lives of the other players, and that guess is dropped when an opponent arrives.
function reader.opponent_shown(before, view, table_is)
	local id = views.opponent_id(view)
	if table_is == "new" then before = { facts = nil, id = id, lives_guess = "none" } end
	if id == nil then
		local lives, from, guess = nil, "out opponent", before.lives_guess
		if before.id ~= nil and views.is_out(view, before.id) then
			lives = views.lives_of(view, before.id)
		else
			lives = reader.opponent_lives(view)
			from = lives ~= nil and "highest of others" or "none"
			if lives ~= nil then guess = "highest of others" end
		end
		local facts, shows = before.facts, {}
		local prior = facts and facts.lives
		if lives ~= nil and prior ~= lives then
			shows[1] = { name = "lives", value = lives, before = prior }
			facts = facts and without_lives(facts) or {}
			facts.lives = lives
		end
		return { lives_from = from, reset = "keep", show = shows, next = { facts = facts, id = before.id, lives_guess = guess } }
	end
	local reset, facts_before = "keep", before.facts
	if table_is ~= "new" then
		if before.id ~= nil and before.id ~= id then
			reset, facts_before = "new opponent", nil
		elseif before.lives_guess == "highest of others" and facts_before then
			reset, facts_before = "guessed lives dropped", without_lives(facts_before)
		end
	end
	local facts = reader.opponent_facts(view)
	local shows = {}
	for _, name in ipairs(reader.changed(facts_before, facts)) do
		shows[#shows + 1] = { name = name, value = facts and facts[name], before = facts_before and facts_before[name] }
	end
	return {
		lives_from = "opponent",
		reset = reset,
		show = shows,
		next = { facts = facts or {}, id = id, lives_guess = "none" },
	}
end

return reader
