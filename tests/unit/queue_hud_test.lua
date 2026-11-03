-- Run from the repo root: lua5.4 tests/unit/queue_hud_test.lua
-- Queue formatting, card motion, and lifecycle checks against engine stubs.
local function noop() end
love = { timer = {
	getTime = function()
		return 0
	end,
} }
Game = { update = noop, start_run = noop }
G = {
	C = {
		BLACK = { 0.2, 0.2, 0.2, 1 },
		BLUE = { 0, 0, 1, 1 },
		RED = { 1, 0, 0, 1 },
		PURPLE = { 0.5, 0, 0.5, 1 },
		SECONDARY_SET = { Spectral = { 0, 0.5, 1, 1 } },
	},
}
darken = function(c)
	return c
end
PVP = { config = {} }
SMODS = { Sound = {
	get_current_music = function()
		return "other_mod_music"
	end,
} }
MPAPI = {
	register_card_info_provider = noop,
	ui_element = function()
		return { update = noop }
	end,
	matchmaking = {
		RANKED_SPREAD_INITIAL = 150,
		RANKED_SPREAD_EXPAND_RATE = 50,
		RANKED_SPREAD_EXPAND_SECS = 30,
		RANKED_SPREAD_CAP = 600,
	},
}
localize = function(args)
	if type(args) == "table" then return args.key .. ":" .. table.concat(args.vars, ",") end
	return args
end
dofile("ui/game/card_info_provider.lua")
dofile("ui/_queue_widgets.lua")
dofile("ui/queue_backdrop.lua")
dofile("ui/queue_cards.lua")
dofile("ui/queue_hud.lua")
dofile("ui/queue_reveal.lua")
local Q = PVP.QUEUE_HUD
local Cards, Reveal = PVP.QUEUE_CARDS, PVP.QUEUE_REVEAL

local function eq(got, want, what)
	if got ~= want then error(what .. ": got " .. tostring(got) .. ", want " .. tostring(want), 2) end
end

eq(Q.format_elapsed(0), "0:00", "elapsed at start")
eq(Q.format_elapsed(65.9), "1:05", "elapsed rounds down")
eq(Q.format_elapsed(-3), "0:00", "elapsed never negative")

local step, total = Q.search_step(150)
eq(step, 1, "first step")
eq(total, 10, "step count from +-150 to +-600 by 50")
eq((Q.search_step(600)), 10, "last step at the cap")
assert(Q.swirl_for(150) < Q.swirl_for(400), "the swirl speeds up as the search widens")
eq(Q.swirl_for(600), Q.swirl_for(10000), "the swirl stops speeding up at the cap")
assert(Q.swirl_for(150) > 1, "the swirl runs faster than the menu's from the first step")

-- The reveal's palettes map like ease_background_colour's.
local Backdrop = PVP.QUEUE_BACKDROP
local p = Backdrop.palette_of({ new_colour = { 1, 1, 1, 1 }, contrast = 3 })
eq(p.L[1], 1.3, "light colour is the new colour x1.3")
eq(p.C[1], 0.9, "main colour is the new colour x0.9")
eq(p.D[1], 0.7, "dark colour is the new colour x0.7")
eq(p.contrast, 3, "contrast carried over")
p = Backdrop.palette_of({
	new_colour = { 1, 1, 1, 1 },
	special_colour = { 0.5, 0.5, 0.5, 1 },
	tertiary_colour = { 0.1, 0.1, 0.1, 1 },
})
eq(p.C[1], 0.5, "special colour taken as is")
eq(p.D[1], 0.1, "tertiary colour taken as is")
for key, preset in pairs(Backdrop.PRESETS) do
	assert(Backdrop.palette_of(preset).L, "preset " .. key .. " maps to a palette")
end
assert(Backdrop.PRESETS[Backdrop.REVEAL], "the reveal's backdrop is a preset")

-- The fan: a finished riffle leaves every card exactly where the next resting fan puts it, so
-- reordering the cards after it doesn't jump.
do
	local n, f, close = 5, 0.5, function(a, b)
		return math.abs(a - b) < 1e-9
	end
	for i = 1, n do
		local x, _, r = Cards.fan_pose(i, n, f, 0, 1, true)
		local j = i == n and 1 or i + 1 -- where the card sits after the reorder
		local rx, _, rr = Cards.fan_pose(j, n, f, 0, nil, true)
		assert(close(x, rx) and close(r, rr), "riffle lands card " .. i .. " on slot " .. j)
	end
	local _, y_top = Cards.fan_pose(n, n, f, 0, 0.5, true)
	local _, y_rest = Cards.fan_pose(n, n, f, 0, nil, true)
	assert(y_top < y_rest, "the riffling card lifts over the fan")
	local wide = Cards.fan_pose(1, n, 1, 0, nil, true)
	local tight = Cards.fan_pose(1, n, 0, 0, nil, true)
	assert(wide < tight, "the fan opens up as the search widens")
end

-- The corner card rests near a corner, partly past both edges, tilted in toward the middle.
for _ = 1, 200 do
	local cx, cy, r, sx, sy = Cards.keeper_spot(20, 11, 2, 2.6)
	assert(cx > 0 and cx < 20 and cy > 0 and cy < 11, "the corner card's centre stays on screen")
	assert(sx < 0 and cx - 1 < 0 or sx > 0 and cx + 1 > 20, "the corner card hangs past the side edge")
	assert(sy < 0 and cy - 1.3 < 0 or sy > 0 and cy + 1.3 > 11, "the corner card hangs past the top or bottom edge")
	assert(math.abs(r) > 0.25 and math.abs(r) < 0.8, "the corner card is tilted, not flat or sideways")
end

local placed = { rating = 1432, isPlacement = false, gamesPlayed = 9, rank = 42 }
local placing = { rating = 640, isPlacement = true, gamesPlayed = 2, placementGames = 5 }
eq(Q.range_text(nil, 150), "...", "range before the rating is read")
eq(Q.range_text(placed, 200), "1232-1632", "range around a placed rating")
eq(Q.range_text(placing, 250), "k_pvp_queue_widening:3,10", "a placing player's range hides the rating")

local elo, rank = Reveal.card_lines(placed)
eq(elo, "Elo 1432", "placed card Elo")
eq(rank, "#42", "placed card rank")
elo, rank = Reveal.card_lines(placing)
eq(elo, "k_pvp_placement_progress:2/5", "placing card progress")
eq(rank, "k_pvp_rank_after_placements", "placing card rank line")
eq((Reveal.card_lines(nil)), "...", "card before the rating is read")
eq((Reveal.card_lines({ unknown = true })), "", "card whose rating could not be read")

print("queue_hud_test: ok")

-- Smoke: drive queue -> widen -> match -> lobby -> run against stub engine objects, running every
-- delayed event at once, to catch nil indexing in the HUD and reveal paths.
do
	local clock = 0
	love.timer.getTime = function()
		return clock
	end
	love.window = { requestAttention = noop }
	local boxes = {}
	local owned = {}
	local function track(object)
		owned[#owned + 1] = object
		return object
	end
	remove_all = function(children)
		for _, child in pairs(children) do
			child:remove()
		end
	end
	local function element(definition)
		local node = { config = definition.config or {}, juice_up = noop, children = {} }
		for _, child in ipairs(definition.nodes or {}) do
			node.children[#node.children + 1] = element(child)
		end
		function node:remove()
			if self.config.object then
				self.config.object:remove()
				self.config.object = nil
			end
			remove_all(self.children)
		end
		return node
	end
	local function find(node, id)
		if node.config.id == id then return node end
		for _, child in ipairs(node.children) do
			local found = find(child, id)
			if found then return found end
		end
	end
	rebuilds = 0
	UIBox = function(args)
		local b = {
			alignment = { offset = args.config.offset },
			UIRoot = element(args.definition),
			states = { collide = {} },
			removed = false,
		}
		function b:align_to_major() end
		function b:remove()
			self.removed = true
			self.UIRoot:remove()
		end
		function b:get_UIE_by_ID(id)
			return find(self.UIRoot, id)
		end
		function b:set_parent_child(definition, parent)
			rebuilds = rebuilds + 1
			parent.children[#parent.children + 1] = element(definition)
		end
		function b:recalculate() end
		boxes[#boxes + 1] = b
		return b
	end
	DynaText = function()
		return { pulse = noop, remove = noop }
	end
	local function moveable(w, h)
		return track({
			T = { x = 0, y = 0, w = w or 1, h = h or 1, r = 0, scale = 1 },
			VT = { x = 0, y = 0, w = w or 1, h = h or 1, r = 0, scale = 1 },
			states = { drag = {}, hover = {} },
			juice_up = noop,
			remove = function(self)
				self.removed = true
				self.removals = (self.removals or 0) + 1
			end,
		})
	end
	CardArea = function(_, _, w, h)
		local a = moveable(w, h)
		a.cards = {}
		local remove = a.remove
		function a:remove()
			remove(self)
			remove_all(self.cards)
			self.cards = {}
		end
		-- Like CardArea:emplace, turns a face-down card up unless told to stay flipped.
		function a:emplace(card, _, stay_flipped)
			if card.facing == "back" and not stay_flipped then card:flip() end
			self.cards[#self.cards + 1] = card
		end
		function a:remove_card(card)
			for i, c in ipairs(self.cards) do
				if c == card then return table.remove(self.cards, i) end
			end
		end
		return a
	end
	flips = 0
	avatars = {}
	Card = function(_, _, w, h, _, center, params)
		local c = moveable(w, h)
		c.center = center
		if params and params.bypass_lock then avatars[#avatars + 1] = center.key end
		function c:flip()
			flips = flips + 1
			self.facing = self.facing == "back" and "front" or "back"
		end
		return c
	end
	nopes = 0
	attention_text = function()
		nopes = nopes + 1
	end
	Particles = function()
		return { remove = noop }
	end
	UIBox_button = function()
		return {}
	end
	Event = function(e)
		return e
	end
	mix_colours = function(a)
		return a
	end
	local sounds = {}
	play_sound = function(key)
		sounds[#sounds + 1] = key
	end
	sendWarnMessage = function(msg)
		error(msg)
	end
	G = {
		UIT = { ROOT = 0, R = 1, C = 2, T = 3, O = 4 },
		C = setmetatable({ UI = setmetatable({}, {
			__index = function()
				return {}
			end,
		}) }, {
			__index = function()
				return {}
			end,
		}),
		ROOM = { jiggle = 0, T = { w = 20, h = 11 } },
		ROOM_ATTACH = {},
		I = { UIBOX = {}, CARDAREA = {} },
		TIMERS = { REAL_SHADER = 12 },
		CARD_W = 2,
		CARD_H = 2.7,
		P_CARDS = { S_A = {} },
		P_CENTERS = {
			c_base = {},
			b_red = { pos = {} },
			j_joker = { key = "j_joker" },
			j_blueprint = { key = "j_blueprint" },
			j_turtle_bean = { key = "j_turtle_bean" },
			c_wheel_of_fortune = { key = "c_wheel_of_fortune", discovered = true },
		},
		P_CENTER_POOLS = {
			Joker = {
				{ key = "j_joker", discovered = true },
				{ key = "j_blueprint", discovered = true },
				{ key = "j_secret", discovered = false },
			},
		},
		SETTINGS = {},
		E_MANAGER = {
			add_event = function(_, e)
				if e.trigger == "after" then e.func() end
			end,
		},
	}
	PVP.LobbyAccess = { RANKED = "ranked", CASUAL = "casual" }
	PVP.ruleset_display_name = function()
		return "Balanced"
	end
	PVP.ranked_ticket = function(key)
		return "ranked:pvp_ranked_" .. key
	end
	PVP.PVP_GAMEMODES = {}
	PVP.id = "MultiplayerPvP"
	MPAPI.connection_state = { preferred_joker = "j_blueprint" }
	MPAPI.matchmaking.ranked_spread = function(t)
		return math.min(150 + math.floor(t / 30) * 50, 600)
	end
	MPAPI.matchmaking.get_rating = function(_, _, _, player_id, cb)
		cb(nil, { rating = player_id == "opp" and 1500 or 1432, isPlacement = false, rank = 7 })
	end
	MPAPI.matchmaking.get_queue_counts = function(_, cb)
		cb(nil, { ["ranked:pvp_ranked_balanced"] = { queued = 6 } })
	end

	local function shader()
		return G.SPLASH_BACK.draw_steps[1].shader
	end
	G.SPLASH_BACK = { draw_steps = { { shader = "splash" } } }
	function G.SPLASH_BACK:define_draw_steps(steps)
		self.draw_steps = steps
	end
	local menu_box = { states = { visible = true } }
	local menu_area = { states = { visible = true }, cards = { { states = { visible = true } } } }
	G.I.UIBOX[1], G.I.CARDAREA[1] = menu_box, menu_area

	Q.start({ kind = "ranked", key = "balanced" })
	eq(Q.active, true, "queue HUD starts")
	Game.update({}, 0)
	eq(Q.in_queue, 6, "queue count read on the first frame")
	eq(shader(), "splash", "the menu keeps its swirl while searching")
	local rate_at_start = Backdrop.target_rate
	assert(rate_at_start > 1, "the swirl runs faster once searching")
	clock = 95
	Game.update({}, 0)
	eq(Q.spread, 300, "range widened after 95 s")
	assert(Backdrop.target_rate > rate_at_start, "the swirl sped up with the range")
	Backdrop.update(1)
	assert(Backdrop.clock > 12 + 1, "the swirl's clock runs faster than real time")
	eq(#Q.fan.area.cards, 5, "the fan has its card backs")
	for i, c in ipairs(Q.fan.area.cards) do
		eq(c.facing, "back", "fan card " .. i .. " is face down")
	end
	local top = Q.fan.area.cards[5]
	clock = 95 + 1.2
	Game.update({}, 0) -- a riffle starts
	clock = 95 + 1.2 + 0.5
	Game.update({}, 0) -- and finishes
	eq(Q.fan.area.cards[1], top, "the riffled top card went to the bottom")

	Cards.EGGS.keeper_nope, Cards.EGGS.keeper_joker = 0, 0
	local fan_cards = { table.unpack(Q.fan.area.cards) }
	Q.match_found()
	eq(Q.active, false, "HUD stops on a match")
	local kept = 0
	for i, c in ipairs(fan_cards) do
		if not c.removed then kept = kept + 1 end
		if i < 5 then assert(c.removed, "flier " .. i .. " is removed once off-screen") end
	end
	eq(kept, 1, "one card stays behind")
	assert(fan_cards[5].T.scale > 1, "the corner card grows as it lands")
	eq(fan_cards[5].facing, "back", "the corner card lands face down")
	assert(Reveal.view and Reveal.view.left and Reveal.view.right and Reveal.view.vs, "reveal dealt both cards and VS")
	eq(shader(), "background", "the reveal plays over the backdrop preset")
	eq(menu_box.states.visible, false, "the menu's UI is hidden during the reveal")
	eq(menu_area.cards[1].states.visible, false, "the menu's cards are hidden during the reveal")
	G.I.UIBOX[2] = { states = { visible = true } }
	Game.update({}, 0)
	eq(G.I.UIBOX[2].states.visible, false, "UI opened mid-reveal is hidden too")
	G.I.UIBOX[2] = nil
	local players = { { id = "me", displayName = "Me" } }
	local lobby = {
		player_id = "me",
		get_players = function()
			return players
		end,
	}
	Q.lobby_ready(lobby)
	Game.update({}, 0)
	eq(avatars[#avatars], "j_blueprint", "our card shows our chosen avatar")
	players[2] = { id = "opp", displayName = "Rival", preferredJoker = "j_turtle_bean" }
	local rebuilds_before = rebuilds
	Game.update({}, 0)
	eq(Reveal.ratings.opp.rating, 1500, "opponent rating read once they joined")
	assert(rebuilds > rebuilds_before, "the player cards were rebuilt when the opponent joined")
	eq(avatars[#avatars], "j_turtle_bean", "the opponent's card shows their avatar")
	eq(Reveal.view.footer_text, "k_pvp_starting_in:4", "the footer counts down from the opponent's arrival")
	clock = clock + 3.5
	Game.update({}, 0)
	eq(Reveal.view.footer_text, "k_pvp_starting_in:1", "the countdown reaches 1")
	clock = clock + 2
	Game.update({}, 0)
	eq(Reveal.view.footer_text, "k_pvp_starting_in:1", "and holds there until the game starts")

	Game.start_run({}, {})
	eq(Reveal.view, nil, "the run starting ends the reveal")
	eq(SMODS.Sound:get_current_music(), "other_mod_music", "run start restores music selection")
	eq(menu_box.states.visible, true, "the menu's UI comes back with the reveal's end")
	eq(menu_area.cards[1].states.visible, true, "and its cards")
	eq(shader(), "splash", "the menu's swirl is back")
	eq(Backdrop.target_rate, 1, "at its normal speed")
	-- Eggs, forced. The Wheel of Fortune: lands, turns over, says Nope!, turns back.
	local function queue_and_match()
		Q.start({ kind = "ranked", key = "balanced" })
		clock = clock + 1
		Game.update({}, 0)
		Q.match_found()
		return Reveal.view.scatter.area.cards[#Reveal.view.scatter.area.cards]
	end
	Cards.EGGS.keeper_nope = 1
	flips, nopes = 0, 0
	local keeper = queue_and_match()
	eq(keeper.center.key, "c_wheel_of_fortune", "nope egg: the corner card is The Wheel of Fortune")
	eq(nopes, 1, "nope egg: it says Nope!")
	eq(flips, 2, "nope egg: it turns over, then back")
	Game.start_run({}, {})

	-- A discovered Joker, never an undiscovered one.
	Cards.EGGS.keeper_nope, Cards.EGGS.keeper_joker = 0, 1
	for _ = 1, 20 do
		flips = 0
		keeper = queue_and_match()
		assert(keeper.center.key == "j_joker" or keeper.center.key == "j_blueprint", "joker egg: a discovered Joker")
		eq(flips, 1, "joker egg: it turns over")
		Game.start_run({}, {})
	end
	Cards.EGGS.keeper_joker = 0

	-- Jimbo in the shuffle: the riffling card flips up mid-arc and back down as it lands.
	Cards.EGGS.jimbo_peek = 1
	Q.start({ kind = "ranked", key = "balanced" })
	flips = 0
	local t0 = clock
	clock = t0 + 1.2
	Game.update({}, 0) -- the riffle starts
	clock = t0 + 1.2 + 0.4
	Game.update({}, 0) -- past a quarter of its (slowed) arc
	eq(flips, 1, "jimbo egg: the card flips up mid-arc")
	clock = t0 + 1.2 + 1.1
	Game.update({}, 0) -- it lands
	eq(flips, 2, "jimbo egg: and back down as it lands")
	Q.stop()
	-- Deferred teardown must remove the old HUD without removing transferred cards,
	-- then cancel reveal events before they can act on the removed scene.
	local events = {}
	G.E_MANAGER.add_event = function(_, event)
		events[#events + 1] = event
	end
	Cards.EGGS.jimbo_peek = 0
	Q.start({ kind = "ranked", key = "balanced" })
	local old_area = Q.fan.area
	local transferred = { table.unpack(old_area.cards) }
	Q.match_found()
	local scene = Reveal.view.scatter
	eq(#old_area.cards, 0, "fan relinquishes cards before HUD removal")
	eq(#scene.area.cards, 5, "scatter owns transferred cards")
	Q.dismiss_reveal()
	eq(SMODS.Sound:get_current_music(), "other_mod_music", "dismissal restores music selection")
	local sounds_after_dismiss = #sounds
	local box_count = #boxes
	for _, event in ipairs(events) do
		if event.trigger == "after" then event.func() end
	end
	eq(#sounds, sounds_after_dismiss, "dismissed reveal cannot play delayed opening release")
	eq(#boxes, box_count, "dismissed reveal cannot create delayed player panels")
	eq(old_area.removals, 1, "old HUD recursively removes its area once")
	eq(scene.area.removals, 1, "reveal recursively removes its scatter area once")
	for _, card in ipairs(transferred) do
		eq(card.removals, 1, "transferred card has exactly one cleanup owner")
	end
	for _, object in ipairs(owned) do
		eq(object.removals, 1, "all cards and areas are removed exactly once")
	end
	-- Responses from a cancelled search must not overwrite a restart on the same board.
	G.E_MANAGER.add_event = function(_, event)
		if event.trigger == "after" then event.func() end
	end
	local ratings, counts = {}, {}
	MPAPI.matchmaking.get_rating = function(_, _, _, _, callback)
		ratings[#ratings + 1] = callback
	end
	MPAPI.matchmaking.get_queue_counts = function(_, callback)
		counts[#counts + 1] = callback
	end
	Q.start({ kind = "ranked", key = "balanced" })
	Game.update({}, 0)
	Q.stop()
	Q.start({ kind = "ranked", key = "balanced" })
	Game.update({}, 0)
	ratings[2](nil, { rating = 1600 })
	ratings[1](nil, { rating = 1200 })
	counts[2](nil, { [Q.count_key] = { queued = 9 } })
	counts[1](nil, { [Q.count_key] = { queued = 3 } })
	eq(Q.rating.rating, 1600, "old rating response ignored after restart")
	eq(Q.in_queue, 9, "old count response ignored after restart")
	Q.stop()
	ratings[2](nil, { rating = 1000 })
	eq(Q.rating.rating, 1600, "rating response ignored after stop")
	PVP.config.queue_match_sound = false
	local first_sound = #sounds + 1
	Q.match_found()
	for i = first_sound, #sounds do
		assert(not sounds[i]:match("^explosion_"), "match sound toggle suppresses pack opening")
	end
	eq(SMODS.Sound:get_current_music(), "music3", "music selection is independent of effect toggle")
	clock = clock + 16
	Game.update({}, 0)
	eq(SMODS.Sound:get_current_music(), "other_mod_music", "timeout restores music selection")
	print("queue_hud_test smoke: ok")
end
