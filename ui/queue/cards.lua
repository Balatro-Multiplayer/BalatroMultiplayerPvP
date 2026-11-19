-- Card effects. The HUD owns a fan; the reveal owns a scatter scene.
local Cards = {}
PVP.QUEUE_CARDS = Cards
local Widgets = PVP.QUEUE_WIDGETS
local now, reduced_motion = Widgets.now, Widgets.reduced_motion
local room_box, clear_root = Widgets.room_box, Widgets.clear_root
local FAN_CARDS, FAN_SCALE = 5, 0.42
local RIFFLE_EVERY, RIFFLE_SECONDS = 1.1, 0.45
local KEEPER_SCALE = 1.5
-- Odds per riffle / match. Cosmetic randomness must not advance gameplay RNG.
Cards.EGGS = { jimbo_peek = 1 / 40, keeper_joker = 1 / 20, keeper_nope = 1 / 50 }

local function rand(n)
	local r = love.math and love.math.random or math.random
	if n then return r(n) end
	return r()
end

local function roll(odds)
	return rand() < odds
end

-- Returns x, y, rotation. Riffle progress moves the top card into the bottom slot.
function Cards.fan_pose(i, n, f, t, riffle, calm)
	local gap, tilt = 0.2 + 0.26 * f, 0.07 + 0.11 * f
	local slot = i - (n + 1) / 2
	local lift = 0
	if riffle then
		local e = riffle * riffle * (3 - 2 * riffle) -- smoothstep
		if i == n then
			slot = slot + (1 - n) * e
			lift = math.sin(riffle * math.pi) * 0.45
		else
			slot = slot + e
		end
	end
	local bob = calm and 0 or math.sin(t * 3 + i * 1.1) * 0.04
	local x = slot * gap
	local y = math.abs(slot) * 0.05 * f + bob - lift
	local r = slot * tilt + (i == n and riffle and math.sin(riffle * math.pi) * 0.35 or 0)
	return x, y, r
end

-- Returns center, rotation, and corner signs; the card extends beyond both screen edges.
function Cards.keeper_spot(room_w, room_h, vw, vh)
	local sx = rand() < 0.5 and -1 or 1
	local sy = rand() < 0.62 and 1 or -1
	local cx = sx < 0 and vw * (0.1 + rand() * 0.12) or room_w - vw * (0.1 + rand() * 0.12)
	local cy = sy < 0 and vh * (0.1 + rand() * 0.12) or room_h - vh * (0.1 + rand() * 0.12)
	local r = sx * sy * -(0.35 + rand() * 0.35) + (rand() - 0.5) * 0.15
	return cx, cy, r, sx, sy
end

-- emplace must receive stay_flipped=true to preserve the card back.
local function face_down_card(x, y, w, h, center)
	local card = Card(x, y, w, h, nil, center, {
		bypass_back = G.P_CENTERS.b_red.pos,
		bypass_discovery_center = true,
		bypass_discovery_ui = true,
		bypass_lock = true,
	})
	card.sprite_facing = "back"
	card.facing = "back"
	card.no_ui = true
	card.states.drag.can = false
	card.states.hover.can = false
	return card
end

-- Card effects place cards explicitly; disable CardArea's automatic layout.
local function free_area(w, h, limit)
	local area = CardArea(0, 0, w, h, { card_limit = limit, type = "title_2", highlight_limit = 0 })
	area.align_cards = function() end
	return area
end

function Cards.create_fan()
	local w, h = G.CARD_W * FAN_SCALE, G.CARD_H * FAN_SCALE
	local area = free_area(3.0, h * 1.35, FAN_CARDS)
	for _ = 1, FAN_CARDS do
		area:emplace(face_down_card(area.T.x, area.T.y, w, h, G.P_CENTERS.j_joker), nil, true)
	end
	return { area = area, next_riffle = now() + RIFFLE_EVERY, riffle_from = nil }
end

local function discovered_joker()
	local found = {}
	for _, center in ipairs((G.P_CENTER_POOLS and G.P_CENTER_POOLS.Joker) or {}) do
		if center.discovered and not center.no_collection then found[#found + 1] = center end
	end
	return #found > 0 and found[rand(#found)] or nil
end

local function swap_card(area, old, center)
	local new = face_down_card(old.T.x, old.T.y, old.T.w, old.T.h, center)
	new.T.r, new.T.scale = old.T.r, old.T.scale
	new.VT.x, new.VT.y, new.VT.r, new.VT.scale = old.VT.x, old.VT.y, old.VT.r, old.VT.scale
	area:remove_card(old)
	old:remove()
	area:emplace(new, nil, true)
	return new
end

local function keeper_egg()
	local wheel = G.P_CENTERS.c_wheel_of_fortune
	if wheel and wheel.discovered and roll(Cards.EGGS.keeper_nope) then return "nope", wheel end
	if roll(Cards.EGGS.keeper_joker) then
		local joker = discovered_joker()
		if joker then return "joker", joker end
	end
	return nil, nil
end

-- schedule belongs to the reveal and suppresses callbacks after its teardown.
function Cards.scatter(cards, schedule, calm)
	local scene = {}
	local W, H = G.ROOM.T.w, G.ROOM.T.h
	scene.area = free_area(W, H, #cards)
	scene.box = room_box(clear_root({ { n = G.UIT.O, config = { object = scene.area } } }), { x = 0, y = 0 }, true)
	for _, card in ipairs(cards) do
		scene.area:emplace(card, nil, true)
	end
	local keeper = cards[#cards]
	local from_x = keeper.T.x + keeper.T.w / 2
	local from_y = keeper.T.y + keeper.T.h / 2

	for k = 1, #cards - 1 do
		local card = cards[k]
		local a = -math.pi * 0.95 + ((k - 1) / math.max(1, #cards - 2)) * math.pi * 1.1 + (rand() - 0.5) * 0.5
		local d = W * (0.8 + rand() * 0.3)
		card.T.x = from_x + math.cos(a) * d - card.T.w / 2
		card.T.y = from_y + math.sin(a) * d * 0.8 + H * 0.3 - card.T.h / 2
		card.T.r = card.T.r + (calm and 0 or (rand() < 0.5 and -1 or 1) * (6 + rand() * 6))
		card.T.scale = 1.3
		schedule(1.0, function()
			scene.area:remove_card(card)
			card:remove()
		end)
	end

	local egg, center = keeper_egg()
	if egg then keeper = swap_card(scene.area, keeper, center) end
	local vw, vh = keeper.T.w * KEEPER_SCALE, keeper.T.h * KEEPER_SCALE
	local cx, cy, r, sx, sy = Cards.keeper_spot(W, H, vw, vh)
	local turn = calm and 0 or math.pi * 2
	keeper.T.scale = KEEPER_SCALE
	keeper.T.x = cx + sx * 0.35 - keeper.T.w / 2
	keeper.T.y = cy + sy * 0.25 - keeper.T.h / 2
	keeper.T.r = r * 1.35 + turn
	schedule(0.6, function()
		keeper.T.x, keeper.T.y, keeper.T.r = cx - keeper.T.w / 2, cy - keeper.T.h / 2, r + turn
	end)
	schedule(1.15, function()
		keeper:juice_up(0.15, 0.06)
		play_sound("cardSlide1", 0.9, 0.4)
	end)
	if egg then schedule(1.5, function()
		keeper:flip()
		play_sound("card1", 1, 0.6)
	end) end
	if egg == "nope" then
		schedule(2.0, function()
			attention_text({
				text = localize("k_nope_ex"),
				scale = 1.1,
				hold = 1.2,
				major = keeper,
				backdrop_colour = G.C.SECONDARY_SET.Tarot,
				align = "cm",
				offset = { x = -sx * 1.2, y = -sy * 0.9 },
				silent = true,
			})
			play_sound("tarot2", 1, 0.4)
		end)
		schedule(3.3, function()
			keeper:flip()
			play_sound("card1", 0.9, 0.5)
		end)
	end
	return scene
end

function Cards.update_fan(fan, t, spread_factor)
	local area = fan and fan.area
	if not (area and area.T and area.cards) then return end
	local calm = reduced_motion()
	if not calm and not fan.riffle_from and t >= fan.next_riffle then
		fan.riffle_from = t
		fan.peek = roll(Cards.EGGS.jimbo_peek)
		fan.peeked = false
		fan.riffle_len = fan.peek and RIFFLE_SECONDS * 2.2 or RIFFLE_SECONDS
	end
	local riffle = fan.riffle_from and math.min(1, (t - fan.riffle_from) / fan.riffle_len)
	local f = spread_factor
	local cards = area.cards -- also the draw order: the top card is drawn last
	local n = #cards
	local cx, cy = area.T.x + area.T.w / 2, area.T.y + area.T.h * 0.12
	for i, card in ipairs(cards) do
		local x, y, r = Cards.fan_pose(i, n, f, t, riffle, calm)
		card.T.x, card.T.y, card.T.r = cx + x - card.T.w / 2, cy + y, r
	end
	if fan.peek and not fan.peeked and riffle and riffle >= 0.25 then
		fan.peeked = true
		cards[n]:flip()
		play_sound("card1", 1.25, 0.5)
	end
	if riffle == 1 then
		if fan.peeked then cards[n]:flip() end
		fan.peek, fan.peeked = false, false
		local moved = table.remove(cards)
		table.insert(cards, 1, moved)
		moved:juice_up(0.08, 0.04)
		fan.riffle_from = nil
		fan.next_riffle = t + RIFFLE_EVERY
	end
end

-- Transfer cards before the HUD recursively removes its old CardArea.
function Cards.detach(fan)
	if not fan or #fan.area.cards == 0 then return nil end
	local cards = {}
	for _, card in ipairs(fan.area.cards) do
		cards[#cards + 1] = card
	end
	for _, card in ipairs(cards) do
		fan.area:remove_card(card)
	end
	return cards
end

function Cards.remove_scatter(scene)
	if scene then Widgets.remove_box(scene.box) end
end
