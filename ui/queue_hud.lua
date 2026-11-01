-- The queue HUD and the match-found reveal.
--
-- While PvP's one queue is searching, a small box slides in top-right over every menu screen:
-- the time waited, how many are in that queue, and for Ranked the rating range being searched
-- (the window MPAPI.matchmaking.ranked_spread widens every RANKED_SPREAD_EXPAND_SECS). A player
-- still in placements isn't shown their rating, so their range reads as a step count instead.
-- The queue keeps running wherever the player goes, so the HUD is how they get back to
-- cancelling. The menu's background swirl spins a little faster for each widening step, and a
-- fan of card backs in the HUD riffles while it searches (the top card arcs over to the bottom
-- of the fan), spreading wider with each step too.
--
-- On a match: a white flash, a screen jiggle, a chip burst and a spin spike on the swirl, the
-- taskbar asks for attention, and the fan scatters: four cards spin off-screen, and the top one
-- glides into a random corner, half off the screen, and stays there framing the reveal. MATCH
-- FOUND drops in, and two player cards slide in from the sides with VS stamped between them. The opponent's card shows a wobbling "?" until they're in
-- the lobby, then flips to their name, Elo or placement progress and board rank. It all goes
-- when the run starts, the lobby goes, or after REVEAL_MAX_SECONDS.
--
-- Easter eggs, rare and never announced (odds in Q.EGGS, rolled on LÖVE's generator so the
-- game's seeded RNG is never touched): now and then a riffling card flips to show Jimbo mid-arc; the
-- corner card sometimes lands and turns over as a Joker from the player's own discovered
-- collection; and very rarely it's The Wheel of Fortune, which says "Nope!" and turns back.
--
-- Reduced motion (G.SETTINGS.reduced_motion) drops the flash, jiggle, particles, spin and the
-- riffle; the slides stay, they're short.
--
-- Driven from pvp_api/queue.lua: PVP._show_searching starts/stops the HUD, the handle's
-- match_found / lobby_ready events drive the reveal. The match sound itself is
-- PVP._play_match_found_sound (its own config toggle), not played here.

local Q = {
	active = false,
	queue_id = nil, -- the PVP._active_queue_id it was started for
	started_at = 0,
	ranked = false,
	label = "",
	count_key = nil, -- the key queue_counts counts this queue under
	ticket = nil, -- Ranked: the rating board (PVP.ranked_ticket)
	rating = nil, -- Ranked: own rating_get record; false while in flight
	spread = nil,
	in_queue = nil,
	next_poll = 0,
	last_minute = 0,
	hud = nil,
	saved_spin = nil, -- the swirl's spin before the queue touched it
	-- the reveal: its pieces, the lobby it shows, ratings read for it
	rv = nil,
	reveal_lobby = nil,
	reveal_until = 0,
	reveal_ranked = false,
	reveal_ticket = nil,
	reveal_ratings = {},
	reveal_gen = 0, -- bumped on every reveal teardown, so its delayed steps know they're stale
}
PVP.QUEUE_HUD = Q

local COUNTS_POLL_SECONDS = 5
-- The reveal goes on its own if the run never starts (a failed autostart leaves the lobby UI).
local REVEAL_MAX_SECONDS = 15
local HUD_OFFSET = { x = -0.25, y = 0.25 }
local OFFSCREEN_Y = -5
local CARD_X = 2.6
-- The swirl's spin while searching: the first step and the cap, eased between by step.
local SPIN_MIN, SPIN_MAX, SPIN_FOUND = 0.08, 0.45, 1.2
-- The searching fan: how many card backs, their size against a real card, and the riffle.
local FAN_CARDS, FAN_SCALE = 5, 0.42
local RIFFLE_EVERY, RIFFLE_SECONDS = 1.1, 0.45
-- The corner card: its size against a fan card once it lands.
local KEEPER_SCALE = 1.5

-- Chance per riffle (jimbo_peek) or per match (the two keeper eggs; nope is rolled first).
Q.EGGS = { jimbo_peek = 1 / 40, keeper_joker = 1 / 20, keeper_nope = 1 / 50 }

-- LÖVE seeds its own generator at startup; LuaJIT's math.random starts from the same seed every
-- launch. Neither is the game's seeded pseudorandom, which these effects must never advance.
local function rand(n)
	local r = love.math and love.math.random or math.random
	if n then
		return r(n)
	end
	return r()
end

local function roll(odds)
	return rand() < odds
end

local function now()
	return love.timer.getTime()
end

local function reduced_motion()
	return G.SETTINGS and G.SETTINGS.reduced_motion
end

-- Pure helpers (tests/unit/queue_hud_test.lua) ---------------------------------------------------

function Q.format_elapsed(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- Which widening step the search is on (1 = the starting window), and how many there are.
function Q.search_step(spread)
	local M = MPAPI.matchmaking
	local total = math.floor((M.RANKED_SPREAD_CAP - M.RANKED_SPREAD_INITIAL) / M.RANKED_SPREAD_EXPAND_RATE) + 1
	local step = math.floor(((spread or M.RANKED_SPREAD_INITIAL) - M.RANKED_SPREAD_INITIAL) / M.RANKED_SPREAD_EXPAND_RATE) + 1
	return math.min(step, total), total
end

-- How fast the swirl spins at a search step: SPIN_MIN on the first, SPIN_MAX at the cap.
function Q.spin_for(spread)
	local step, total = Q.search_step(spread)
	return SPIN_MIN + (SPIN_MAX - SPIN_MIN) * (step - 1) / math.max(1, total - 1)
end

-- 0 on the first search step, 1 at the cap.
function Q.spread_factor(spread)
	local step, total = Q.search_step(spread)
	return (step - 1) / math.max(1, total - 1)
end

-- Where fan card `i` of `n` sits, relative to the fan's centre: x, y and tilt. `f` is the
-- spread factor (the fan opens up as the search widens), `t` the clock for the bob, `riffle`
-- the riffle's progress (nil between riffles). During a riffle the top card (i == n) arcs up
-- and over to the bottom slot while the others each slide up one slot.
function Q.fan_pose(i, n, f, t, riffle, calm)
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

-- Where the corner card comes to rest, in room units: its centre and tilt. `vw`/`vh` are its
-- drawn size; roughly 40% of it ends up past the two screen edges of a random corner (the
-- bottom corners a bit more often), tilted in toward the middle. Also returns which corner
-- (sx, sy: -1 left/top, 1 right/bottom).
function Q.keeper_spot(room_w, room_h, vw, vh)
	local sx = rand() < 0.5 and -1 or 1
	local sy = rand() < 0.62 and 1 or -1
	local cx = sx < 0 and vw * (0.1 + rand() * 0.12) or room_w - vw * (0.1 + rand() * 0.12)
	local cy = sy < 0 and vh * (0.1 + rand() * 0.12) or room_h - vh * (0.1 + rand() * 0.12)
	local r = sx * sy * -(0.35 + rand() * 0.35) + (rand() - 0.5) * 0.15
	return cx, cy, r, sx, sy
end

-- The Ranked range line: "1282-1582" around a placed player's rating, a step count for a
-- player still placing (whose rating stays hidden), "..." until the rating is read.
function Q.range_text(rating, spread)
	if not rating then
		return "..."
	end
	if PVP.placement_progress(rating) then
		local step, total = Q.search_step(spread)
		return localize({ type = "variable", key = "k_pvp_queue_widening", vars = { step, total } })
	end
	local r = math.floor((tonumber(rating.rating) or 0) + 0.5)
	return string.format("%d-%d", r - spread, r + spread)
end

-- A player card's Elo line and rank line from a rating_get record (nil or false while unread,
-- { unknown = true } when the read failed).
function Q.card_lines(rating)
	if not rating then
		return "...", ""
	end
	if rating.unknown then
		return "", ""
	end
	local placement = PVP.placement_progress(rating)
	if placement then
		return localize({ type = "variable", key = "k_pvp_placement_progress", vars = { placement } }), localize("k_pvp_rank_after_placements")
	end
	local elo = "Elo " .. math.floor((tonumber(rating.rating) or 0) + 0.5)
	return elo, tonumber(rating.rank) and ("#" .. rating.rank) or ""
end

-- Juice plumbing ---------------------------------------------------------------------------------

-- Runs fn after `delay` real seconds, unless the reveal it belongs to (gen) was torn down first.
-- no_delete: a run starting clears the event queue, and the steps check gen themselves.
local function after(delay, gen, fn)
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = delay,
		timer = "REAL",
		blockable = false,
		blocking = false,
		no_delete = true,
		func = function()
			if gen == nil or gen == Q.reveal_gen then
				fn()
			end
			return true
		end,
	}))
end

local function ease_to(ref_table, ref_value, value, duration)
	G.E_MANAGER:add_event(Event({
		trigger = "ease",
		ref_table = ref_table,
		ref_value = ref_value,
		ease_to = value,
		delay = duration,
		timer = "REAL",
		blockable = false,
		blocking = false,
		no_delete = true,
		func = function(t)
			return t
		end,
	}))
end

local function set_spin(value)
	if not (G.ARGS and G.ARGS.spin) then
		return
	end
	if Q.saved_spin == nil then
		Q.saved_spin = G.ARGS.spin.real
	end
	G.ARGS.spin.real = reduced_motion() and Q.saved_spin or value
end

local function restore_spin()
	if Q.saved_spin ~= nil and G.ARGS and G.ARGS.spin then
		G.ARGS.spin.real = Q.saved_spin
	end
	Q.saved_spin = nil
end

-- Moves a Weak-bonded UIBox to a new offset; its drawn position eases there on its own.
local function slide(uibox, x, y)
	if not uibox or not uibox.alignment then
		return
	end
	if x then
		uibox.alignment.offset.x = x
	end
	if y then
		uibox.alignment.offset.y = y
	end
	uibox:align_to_major()
end

local function juice(uibox, amount, rot)
	if uibox and uibox.UIRoot then
		uibox.UIRoot:juice_up(amount or 0.1, rot or 0.05)
	end
end

local function remove_box(uibox)
	if uibox then
		pcall(function() uibox:remove() end)
	end
end

-- Queue HUD ------------------------------------------------------------------------------------

-- Live text: DynaText reads these through a ref_table every frame.
local live = setmetatable({}, {
	__index = function(_, k)
		if k == "timer" then
			return Q.format_elapsed(now() - Q.started_at)
		elseif k == "dots" then
			return string.rep(".", math.floor(now() * 2) % 4)
		elseif k == "sub" then
			if Q.in_queue == nil then
				return Q.label
			end
			return Q.label .. "  " .. localize({ type = "variable", key = "k_pvp_queue_in_queue", vars = { Q.in_queue } })
		elseif k == "range" then
			return Q.range_text(Q.rating, Q.spread or MPAPI.matchmaking.RANKED_SPREAD_INITIAL)
		end
		return ""
	end,
})

local function text_object(id, string, scale, colour, opts)
	opts = opts or {}
	return { n = G.UIT.O, config = { id = id, object = DynaText({
		string = string,
		colours = { colour },
		scale = scale,
		shadow = true,
		float = opts.float,
		bump = opts.bump,
		pop_in = opts.pop_in,
		pop_in_rate = opts.pop_in_rate,
		silent = true,
		maxw = opts.maxw,
	}) } }
end

local function live_text(key, scale, colour, opts)
	return text_object("pvp_queue_hud_" .. key, { { ref_table = live, ref_value = key } }, scale, colour, opts)
end

-- The fan lives in a CardArea whose own layout is switched off: tick_fan places every card
-- itself each frame, and each card's drawn position eases after it like a hand card's does.
local function remove_fan()
	local fan = Q.fan
	Q.fan = nil
	if fan then
		pcall(function() fan.area:remove() end)
	end
end

-- A face-down card with the red deck's back: the fan's, and the corner card's eggs. Its face is
-- `center` (Jimbo for the fan, so any fan card can flip to him). Emplace it with stay_flipped, or
-- CardArea:emplace turns it face up.
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

-- A CardArea that never lays its cards out: whoever owns it places them.
local function free_area(w, h, limit)
	local area = CardArea(0, 0, w, h, { card_limit = limit, type = "title_2", highlight_limit = 0 })
	area.align_cards = function() end
	return area
end

local function build_fan()
	remove_fan()
	local w, h = G.CARD_W * FAN_SCALE, G.CARD_H * FAN_SCALE
	local area = free_area(3.0, h * 1.35, FAN_CARDS)
	for _ = 1, FAN_CARDS do
		area:emplace(face_down_card(area.T.x, area.T.y, w, h, G.P_CENTERS.j_joker), nil, true)
	end
	Q.fan = { area = area, next_riffle = now() + RIFFLE_EVERY, riffle_from = nil }
	return { n = G.UIT.O, config = { object = area } }
end

local function hud_definition()
	local rows = {
		{ n = G.UIT.R, config = { align = "cm" }, nodes = { build_fan() } },
		{ n = G.UIT.R, config = { align = "cm" }, nodes = {
			{ n = G.UIT.C, config = { align = "cl", minw = 1.9 }, nodes = {
				{ n = G.UIT.R, config = { align = "cl" }, nodes = {
					-- float: the letters bob one after another, Balatro's own "alive" text.
					text_object("pvp_queue_hud_status", { localize("k_pvp_queue_searching") }, 0.38, G.C.UI.TEXT_LIGHT, { float = true }),
					live_text("dots", 0.38, G.C.UI.TEXT_LIGHT),
				} },
			} },
			{ n = G.UIT.C, config = { align = "cr", minw = 1.3 }, nodes = { live_text("timer", 0.6, G.C.IMPORTANT) } },
		} },
		{ n = G.UIT.R, config = { align = "cm" }, nodes = { live_text("sub", 0.3, G.C.UI.TEXT_INACTIVE, { maxw = 3.2 }) } },
	}
	if Q.ranked then
		rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.04, r = 0.08, colour = mix_colours(G.C.BLACK, G.C.L_BLACK, 0.5), minw = 3.2 }, nodes = {
			live_text("range", 0.36, G.C.GOLD, { maxw = 3.0 }),
		} }
	end
	rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.04 }, nodes = {
		UIBox_button({ button = "mp_pvp_cancel_queue", label = { localize("b_cancel_search_cap") }, colour = G.C.RED, minw = 3.2, minh = 0.45, scale = 0.32 }),
	} }
	return { n = G.UIT.ROOT, config = { align = "cm", padding = 0.1, r = 0.12, colour = G.C.L_BLACK, emboss = 0.08 }, nodes = {
		{ n = G.UIT.C, config = { align = "cm", padding = 0.04 }, nodes = rows },
	} }
end

-- Slides the HUD up off the screen, then removes it.
local function hide_hud()
	local hud = Q.hud
	Q.hud = nil
	if not hud then
		return
	end
	local fan = Q.fan
	Q.fan = nil
	slide(hud, nil, OFFSCREEN_Y)
	after(0.5, nil, function()
		remove_box(hud)
		-- Removing a UIBox doesn't remove the objects in its G.UIT.O nodes.
		if fan then
			pcall(function() fan.area:remove() end)
		end
	end)
end

local function show_hud()
	remove_box(Q.hud)
	remove_fan()
	Q.hud = UIBox({
		definition = hud_definition(),
		config = { align = "tri", offset = { x = HUD_OFFSET.x, y = OFFSCREEN_Y }, major = G.ROOM_ATTACH, bond = "Weak" },
	})
	slide(Q.hud, nil, HUD_OFFSET.y)
	local hud = Q.hud
	after(0.35, nil, function()
		if Q.hud == hud then
			juice(hud, 0.15, 0.05)
		end
	end)
end

local function title_for(queue_id)
	if queue_id.kind == PVP.LobbyAccess.RANKED then
		return PVP.ruleset_display_name(queue_id.key) .. " " .. localize("k_pvp_ranked")
	end
	local def = PVP.PVP_GAMEMODES[queue_id.key]
	return def and def.display or tostring(queue_id.key)
end

local function poll_counts()
	local key = Q.count_key
	MPAPI.matchmaking.get_queue_counts(PVP.id, function(err, game_modes)
		if err or not Q.active or Q.count_key ~= key then
			return
		end
		local c = game_modes and game_modes[key]
		local n = c and tonumber(c.queued)
		if n and n ~= Q.in_queue then
			Q.in_queue = n
			local sub = Q.hud and Q.hud:get_UIE_by_ID("pvp_queue_hud_sub")
			if sub and sub.config.object then
				sub.config.object:pulse(0.3)
			end
		end
	end)
end

function Q.start(queue_id)
	if not queue_id then
		return
	end
	-- PVP._show_searching(true) also fires on every 'queued' event: same queue, same clock.
	if Q.active and Q.queue_id and Q.queue_id.kind == queue_id.kind and Q.queue_id.key == queue_id.key then
		return
	end
	Q.active = true
	Q.queue_id = { kind = queue_id.kind, key = queue_id.key }
	Q.started_at = now()
	Q.last_minute = 0
	Q.ranked = queue_id.kind == PVP.LobbyAccess.RANKED
	Q.label = title_for(queue_id)
	Q.ticket = Q.ranked and PVP.ranked_ticket(queue_id.key) or nil
	Q.count_key = Q.ticket or queue_id.key
	Q.spread = MPAPI.matchmaking.ranked_spread(0)
	Q.in_queue = nil
	Q.next_poll = now()
	Q.rating = nil
	if Q.ranked then
		Q.rating = false
		local ticket = Q.ticket
		MPAPI.matchmaking.get_rating(PVP.id, ticket, nil, nil, function(err, data)
			if Q.ticket == ticket then
				Q.rating = (not err and data) or nil
			end
		end)
	end
	play_sound("highlight2", 1.1, 0.6)
	set_spin(Q.spin_for(Q.spread))
	show_hud()
end

function Q.stop()
	if not Q.active then
		return
	end
	Q.active = false
	Q.queue_id = nil
	hide_hud()
	if not Q.rv then
		restore_spin()
	end
end

-- Match-found reveal -----------------------------------------------------------------------------

local seen_players = 0

local function remove_reveal()
	Q.reveal_gen = Q.reveal_gen + 1
	seen_players = 0
	local rv = Q.rv
	Q.rv = nil
	Q.reveal_lobby = nil
	if rv then
		if rv.particles then
			pcall(function() rv.particles:remove() end)
		end
		if rv.table_area then
			pcall(function() rv.table_area:remove() end)
		end
		remove_box(rv.table)
		remove_box(rv.flash)
		remove_box(rv.title)
		remove_box(rv.left)
		remove_box(rv.right)
		remove_box(rv.vs)
		remove_box(rv.footer)
	end
	if not Q.active then
		restore_spin()
	end
end

local function face(letter, colour, unknown)
	local glyph = unknown
			and text_object(nil, { "?" }, 0.9, G.C.WHITE, { float = true, bump = true })
		or { n = G.UIT.T, config = { text = letter, scale = 0.9, colour = G.C.WHITE, shadow = true } }
	return { n = G.UIT.R, config = { align = "cm", minw = 1.4, minh = 1.2, r = 0.1, colour = colour }, nodes = { glyph } }
end

local function player_card(name, rating, colour, unknown)
	-- A casual match has no ratings to show.
	local elo_line, rank_line = "", ""
	if Q.reveal_ranked and not unknown then
		elo_line, rank_line = Q.card_lines(rating)
	end
	return { n = G.UIT.C, config = { align = "cm", padding = 0.1, r = 0.12, minw = 2.4, minh = 2.9, colour = G.C.WHITE, emboss = 0.08 }, nodes = {
		{ n = G.UIT.R, config = { align = "cm", maxw = 2.2 }, nodes = {
			{ n = G.UIT.T, config = { text = name, scale = 0.42, colour = G.C.UI.TEXT_DARK } },
		} },
		face(string.upper(string.sub(name, 1, 1)), colour, unknown),
		{ n = G.UIT.R, config = { align = "cm" }, nodes = {
			{ n = G.UIT.T, config = { text = elo_line, scale = 0.36, colour = G.C.UI.TEXT_DARK } },
		} },
		{ n = G.UIT.R, config = { align = "cm" }, nodes = {
			{ n = G.UIT.T, config = { text = rank_line, scale = 0.3, colour = G.C.UI.TEXT_INACTIVE } },
		} },
	} }
end

local function players_of(lobby)
	if not lobby then
		return nil, nil
	end
	local me, opp
	for _, p in ipairs(lobby:get_players()) do
		if p.id == lobby.player_id then
			me = p
		else
			opp = opp or p
		end
	end
	return me, opp
end

-- Our own card: before the lobby is joined, the rating the queue already read.
local function left_card()
	local me = players_of(Q.reveal_lobby)
	local rating = (me and Q.reveal_ratings[me.id]) or Q.rating
	return player_card(localize("k_pvp_you"), rating, G.C.BLUE)
end

local function right_card()
	local _, opp = players_of(Q.reveal_lobby)
	if not opp then
		return player_card("...", nil, G.C.UI.BACKGROUND_INACTIVE, true)
	end
	return player_card(opp.displayName or "?", Q.reveal_ratings[opp.id], G.C.RED)
end

local CARD_BUILDERS = { left = left_card, right = right_card }

-- A player card wrapped in a container refresh_card can find again.
local function card_node(side)
	return { n = G.UIT.C, config = { id = "pvp_reveal_" .. side, align = "cm" }, nodes = { CARD_BUILDERS[side]() } }
end

-- Rebuilds a dealt player card in place. Not MPAPI.ui_element: its update() looks only in
-- G.I.UIBOX, and the reveal's boxes are POPUPs.
local function refresh_card(side)
	local box = Q.rv and Q.rv[side]
	local container = box and box:get_UIE_by_ID("pvp_reveal_" .. side)
	if not container then
		return
	end
	remove_all(container.children)
	container.children = {}
	box:set_parent_child(CARD_BUILDERS[side](), container)
	box:recalculate()
end

local function refresh_cards()
	refresh_card("left")
	refresh_card("right")
end

local function room_box(definition, offset, popup)
	return UIBox({
		definition = definition,
		config = { align = "cm", offset = offset, major = G.ROOM_ATTACH, bond = "Weak", instance_type = popup and "POPUP" or nil },
	})
end

local function clear_root(nodes, padding)
	return { n = G.UIT.ROOT, config = { align = "cm", padding = padding or 0, colour = G.C.CLEAR }, nodes = nodes }
end

-- A discovered Joker for the corner card to turn over as, or nil before any are discovered.
local function discovered_joker()
	local found = {}
	for _, center in ipairs((G.P_CENTER_POOLS and G.P_CENTER_POOLS.Joker) or {}) do
		if center.discovered and not center.no_collection then
			found[#found + 1] = center
		end
	end
	return #found > 0 and found[rand(#found)] or nil
end

-- Swaps `old` for a face-down card of `center`, where `old` is drawn right now.
local function swap_card(area, old, center)
	local new = face_down_card(old.T.x, old.T.y, old.T.w, old.T.h, center)
	new.T.r, new.T.scale = old.T.r, old.T.scale
	new.VT.x, new.VT.y, new.VT.r, new.VT.scale = old.VT.x, old.VT.y, old.VT.r, old.VT.scale
	area:remove_card(old)
	old:remove()
	area:emplace(new, nil, true)
	return new
end

-- The corner card's egg, rolled once per match: "nope", "joker" or nil, and its center.
local function keeper_egg()
	local wheel = G.P_CENTERS.c_wheel_of_fortune
	if wheel and wheel.discovered and roll(Q.EGGS.keeper_nope) then
		return "nope", wheel
	end
	if roll(Q.EGGS.keeper_joker) then
		local joker = discovered_joker()
		if joker then
			return "joker", joker
		end
	end
	return nil, nil
end

-- The fan scatters from where it is in the HUD: its cards move to a full-screen area of the
-- reveal's own (the HUD and its CardArea are on their way out), four are sent spinning far
-- off-screen and removed, and the top card goes to a corner. Every card's drawn position eases
-- after its target, so one far target is a fling and a target past the corner, then the corner,
-- is an overshoot and settle.
local function scatter(cards, rv, gen, calm)
	local W, H = G.ROOM.T.w, G.ROOM.T.h
	rv.table_area = free_area(W, H, #cards)
	rv.table = room_box(clear_root({ { n = G.UIT.O, config = { object = rv.table_area } } }), { x = 0, y = 0 }, true)
	for _, card in ipairs(cards) do
		rv.table_area:emplace(card, nil, true)
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
		after(1.0, gen, function()
			rv.table_area:remove_card(card)
			card:remove()
		end)
	end

	local egg, center = keeper_egg()
	if egg then
		keeper = swap_card(rv.table_area, keeper, center)
	end
	local vw, vh = keeper.T.w * KEEPER_SCALE, keeper.T.h * KEEPER_SCALE
	local cx, cy, r, sx, sy = Q.keeper_spot(W, H, vw, vh)
	local turn = calm and 0 or math.pi * 2
	keeper.T.scale = KEEPER_SCALE
	keeper.T.x = cx + sx * 0.35 - keeper.T.w / 2
	keeper.T.y = cy + sy * 0.25 - keeper.T.h / 2
	keeper.T.r = r * 1.35 + turn
	after(0.6, gen, function()
		keeper.T.x, keeper.T.y, keeper.T.r = cx - keeper.T.w / 2, cy - keeper.T.h / 2, r + turn
	end)
	after(1.15, gen, function()
		keeper:juice_up(0.15, 0.06)
		play_sound("cardSlide1", 0.9, 0.4)
	end)
	if egg then
		after(1.5, gen, function()
			keeper:flip()
			play_sound("card1", 1, 0.6)
		end)
	end
	if egg == "nope" then
		-- Vanilla's own Wheel of Fortune miss, nudged in from the corner so it's on screen.
		after(2.0, gen, function()
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
		after(3.3, gen, function()
			keeper:flip()
			play_sound("card1", 0.9, 0.5)
		end)
	end
end

-- The match-found sequence. Each step is a delayed event tied to this reveal's gen, so tearing
-- the reveal down (run start, lobby gone) cancels whatever hasn't played yet.
function Q.match_found()
	local ranked, ticket = Q.ranked, Q.ticket
	-- Take the fan's cards before the HUD (and its CardArea) goes.
	local fan_cards
	if Q.fan and Q.fan.area and Q.fan.area.cards and #Q.fan.area.cards > 0 then
		fan_cards = {}
		for _, card in ipairs(Q.fan.area.cards) do
			fan_cards[#fan_cards + 1] = card
		end
		for _, card in ipairs(fan_cards) do
			Q.fan.area:remove_card(card)
		end
	end
	Q.stop()
	remove_reveal()
	local gen = Q.reveal_gen
	Q.rv = {}
	Q.reveal_ratings = {}
	Q.reveal_ranked, Q.reveal_ticket = ranked, ticket
	Q.reveal_until = now() + REVEAL_MAX_SECONDS
	local rv = Q.rv
	local calm = reduced_motion()

	-- Flashes the taskbar / bounces the dock icon if the game is in the background.
	pcall(love.window.requestAttention, false)

	-- 0.0s: flash, jiggle, spin spike.
	if not calm then
		local flash_colour = { 1, 1, 1, 0.75 }
		rv.flash = room_box({ n = G.UIT.ROOT, config = { align = "cm", minw = 40, minh = 30, colour = flash_colour }, nodes = {} }, { x = 0, y = 0 }, true)
		ease_to(flash_colour, 4, 0, 0.45)
		if G.ROOM then
			G.ROOM.jiggle = G.ROOM.jiggle + 6
		end
		set_spin(SPIN_FOUND)
		after(0.7, gen, function()
			set_spin(SPIN_MAX)
		end)
	end

	-- 0.0s: the fan scatters, under everything that follows.
	if fan_cards then
		scatter(fan_cards, rv, gen, calm)
	end

	-- 0.0s: MATCH FOUND drops in from above, letters popping in one by one.
	rv.title = room_box(clear_root({
		text_object(nil, { localize("k_pvp_match_found") }, 1.4, G.C.GOLD, { float = true, bump = true, pop_in = 0, pop_in_rate = 8 }),
	}), { x = 0, y = OFFSCREEN_Y }, true)
	slide(rv.title, nil, -2.6)
	if not calm then
		rv.particles = Particles(0, 0, 0, 0, {
			timer_type = "TOTAL",
			timer = 0.01,
			pulse_max = 50,
			max = 0,
			scale = 0.25,
			speed = 6,
			lifespan = 1.3,
			fill = true,
			padding = 0.6,
			attach = rv.title.UIRoot,
			colours = { G.C.RED, G.C.BLUE, G.C.GOLD, G.C.WHITE },
		})
	end

	-- 0.35s / 0.5s: the two cards fly in from either side, and land with a bump and a card sound.
	local function deal(side, x, delay)
		after(delay, gen, function()
			rv[side] = room_box(clear_root({ card_node(side) }), { x = x * 5, y = 0.4 }, true)
			slide(rv[side], x, nil)
			after(0.3, gen, function()
				juice(rv[side], 0.25, 0.1)
				play_sound("card1", side == "left" and 1 or 1.15, 0.7)
			end)
		end)
	end
	deal("left", -CARD_X, 0.35)
	deal("right", CARD_X, 0.5)

	-- 0.9s: VS stamps in between them.
	after(0.9, gen, function()
		rv.vs = room_box(clear_root({
			text_object(nil, { "VS" }, 1.1, G.C.RED, { bump = true, pop_in = 0, pop_in_rate = 10 }),
		}), { x = 0, y = 0.4 }, true)
		juice(rv.vs, 0.4, 0.15)
		play_sound("generic1", 0.9, 0.6)
		if G.ROOM and not calm then
			G.ROOM.jiggle = G.ROOM.jiggle + 2
		end
	end)

	-- 1.3s: the footer, until the run takes over.
	after(1.3, gen, function()
		rv.footer = room_box(clear_root({
			text_object(nil, { localize("k_pvp_shuffling") }, 0.38, G.C.UI.TEXT_LIGHT, { float = true, pop_in = 0, pop_in_rate = 4 }),
		}), { x = 0, y = 2.5 }, true)
	end)
end

-- Fills the cards in once the matched lobby is joined. Ratings are read per player as they
-- appear (an opponent can join a moment after us); a casual match shows no Elo lines.
function Q.lobby_ready(lobby)
	if not Q.rv then
		return
	end
	Q.reveal_lobby = lobby
end

local function read_reveal_ratings()
	local lobby = Q.reveal_lobby
	if not lobby or not Q.reveal_ranked then
		return
	end
	for _, p in ipairs(lobby:get_players()) do
		if Q.reveal_ratings[p.id] == nil then
			Q.reveal_ratings[p.id] = false
			local id, ticket = p.id, Q.reveal_ticket
			MPAPI.matchmaking.get_rating(PVP.id, ticket, nil, id, function(err, data)
				if Q.reveal_lobby ~= lobby then
					return
				end
				Q.reveal_ratings[id] = (not err and data) or { unknown = true }
				refresh_cards()
			end)
		end
	end
end

-- Per-frame upkeep ------------------------------------------------------------------------------

local function tick_fan(t)
	local fan = Q.fan
	local area = fan and fan.area
	if not (area and area.T and area.cards) then
		return
	end
	local calm = reduced_motion()
	if not calm and not fan.riffle_from and t >= fan.next_riffle then
		fan.riffle_from = t
		-- Egg: this riffle's card shows Jimbo at the top of its arc. It riffles slower, so he's seen.
		fan.peek = roll(Q.EGGS.jimbo_peek)
		fan.peeked = false
		fan.riffle_len = fan.peek and RIFFLE_SECONDS * 2.2 or RIFFLE_SECONDS
	end
	local riffle = fan.riffle_from and math.min(1, (t - fan.riffle_from) / fan.riffle_len)
	local f = Q.spread_factor(Q.spread)
	local cards = area.cards -- also the draw order: the top card is drawn last
	local n = #cards
	local cx, cy = area.T.x + area.T.w / 2, area.T.y + area.T.h * 0.12
	for i, card in ipairs(cards) do
		local x, y, r = Q.fan_pose(i, n, f, t, riffle, calm)
		card.T.x, card.T.y, card.T.r = cx + x - card.T.w / 2, cy + y, r
	end
	if fan.peek and not fan.peeked and riffle and riffle >= 0.25 then
		fan.peeked = true
		cards[n]:flip()
		play_sound("card1", 1.25, 0.5)
	end
	if riffle == 1 then
		if fan.peeked then
			cards[n]:flip()
		end
		fan.peek, fan.peeked = false, false
		-- The top card is now the bottom one: first in the list, so drawn under the rest.
		local moved = table.remove(cards)
		table.insert(cards, 1, moved)
		moved:juice_up(0.08, 0.04)
		fan.riffle_from = nil
		fan.next_riffle = t + RIFFLE_EVERY
	end
end

local function tick_hud()
	local t = now()
	local elapsed = t - Q.started_at
	local spread = MPAPI.matchmaking.ranked_spread(elapsed)
	if spread ~= Q.spread then
		Q.spread = spread
		set_spin(Q.spin_for(spread))
		if Q.ranked then
			play_sound("chips1", 1.2, 0.4)
			local range = Q.hud and Q.hud:get_UIE_by_ID("pvp_queue_hud_range")
			if range and range.config.object then
				range.config.object:pulse(0.6)
			end
		end
		juice(Q.hud, 0.08, 0.03)
		if Q.fan then
			for _, card in ipairs(Q.fan.area.cards or {}) do
				card:juice_up(0.12, 0.08)
			end
		end
	end
	tick_fan(t)
	-- A little bump on the timer each full minute waited.
	local minute = math.floor(elapsed / 60)
	if minute > Q.last_minute then
		Q.last_minute = minute
		local timer = Q.hud and Q.hud:get_UIE_by_ID("pvp_queue_hud_timer")
		if timer and timer.config.object then
			timer.config.object:pulse(0.8)
		end
		juice(Q.hud, 0.12, 0.04)
	end
	if t >= Q.next_poll then
		Q.next_poll = t + COUNTS_POLL_SECONDS
		poll_counts()
	end
end

local function tick_reveal()
	local lobby = Q.reveal_lobby
	if now() >= Q.reveal_until or (lobby and lobby._destroyed) then
		remove_reveal()
		return
	end
	if lobby then
		local n = #lobby:get_players()
		if n ~= seen_players then
			local had_opp = seen_players > 1
			seen_players = n
			read_reveal_ratings()
			refresh_cards()
			-- The opponent's card flipping from "?" to them.
			if n > 1 and not had_opp and Q.rv and Q.rv.right then
				juice(Q.rv.right, 0.35, 0.12)
				play_sound("card1", 0.85, 0.8)
			end
		end
	end
end

local game_update_ref = Game.update
---@diagnostic disable-next-line: duplicate-set-field
function Game:update(dt)
	game_update_ref(self, dt)
	local ok, err = pcall(function()
		if Q.active then
			tick_hud()
		end
		if Q.rv then
			tick_reveal()
		end
	end)
	if not ok then
		sendWarnMessage("[pvp] queue HUD: " .. tostring(err), "MULTIPLAYER")
		Q.stop()
		remove_reveal()
	end
end

-- The run starting is the reveal's natural end.
local start_run_ref = Game.start_run
---@diagnostic disable-next-line: duplicate-set-field
function Game:start_run(args)
	remove_reveal()
	return start_run_ref(self, args)
end

Q.dismiss_reveal = remove_reveal
