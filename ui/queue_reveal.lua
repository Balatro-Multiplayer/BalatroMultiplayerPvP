-- Match reveal: player data, animation lifetime, and temporary UI visibility.
local Reveal = { generation = 0, ratings = {} }
PVP.QUEUE_REVEAL = Reveal
-- Seconds between the opponent's card turning up and the game starting. The matchmaking host
-- holds its auto-start this long (ui/lobby/_ready.lua); the footer counts it down.
Reveal.HOLD_SECONDS = 4
-- The engine crossfades music and applies the player's music volume.
local get_current_music = SMODS.Sound.get_current_music
function SMODS.Sound:get_current_music(...)
	if Reveal.view then return "music3" end
	return get_current_music(self, ...)
end

local Cards, Backdrop, Widgets = PVP.QUEUE_CARDS, PVP.QUEUE_BACKDROP, PVP.QUEUE_WIDGETS
local now, reduced_motion = Widgets.now, Widgets.reduced_motion
local slide, juice, remove_box = Widgets.slide, Widgets.juice, Widgets.remove_box
local text_object, room_box, clear_root = Widgets.text_object, Widgets.room_box, Widgets.clear_root
local ease_to = Widgets.ease_to
-- Failed autostart must eventually release the lobby UI: a lobby join or an opponent that
-- never arrives ends the reveal after JOIN_SECONDS, a start that never comes START_GRACE_SECONDS
-- after the countdown ends (the host's hold starts once every ready signal is in, a little
-- later than the opponent appearing here).
local JOIN_SECONDS, START_GRACE_SECONDS = 15, 5
local OFFSCREEN_Y, CARD_X, AVATAR_SCALE, SPIN_FOUND = -5, 2.6, 0.6, 1.2
-- The last seconds of the countdown land on the VS, one beat each.
local BEATS_FROM = 3
-- How long the player cards take to leave once the game starts.
local OUTRO_SECONDS = 0.5

local function after(delay, generation, fn)
	Widgets.after(delay, function()
		return Reveal.generation == generation
	end, fn)
end

function Reveal.card_lines(rating)
	if not rating then return "...", "" end
	if rating.unknown then return "", "" end
	local placement = PVP.placement_progress(rating)
	if placement then
		return localize({ type = "variable", key = "k_pvp_placement_progress", vars = { placement } }),
			localize("k_pvp_rank_after_placements")
	end
	local elo = "Elo " .. math.floor((tonumber(rating.rating) or 0) + 0.5)
	return elo, tonumber(rating.rank) and ("#" .. rating.rank) or ""
end

local seen_players = 0
-- Reveal boxes use POPUP; leave attention text visible and hide newly opened menus each frame.
local function hide_ui(view)
	local hidden = view.hidden
	local function hide(obj)
		if obj and obj.states and obj.states.visible and not hidden[obj] then
			obj.states.visible = false
			hidden[obj] = true
		end
	end
	for _, box in pairs(G.I.UIBOX) do
		if not box.attention_text then hide(box) end
	end
	for _, area in pairs(G.I.CARDAREA) do
		if area ~= (view.scatter and view.scatter.area) then
			hide(area)
			for _, card in ipairs(area.cards or {}) do
				hide(card)
			end
		end
	end
	hide(G.SPLASH_LOGO)
end

local function show_ui(view)
	for obj in pairs(view.hidden) do
		obj.states.visible = true
	end
	view.hidden = {}
end

-- Every box and scene the view made. Safe to call again: each piece is removed once.
local function remove_view(view)
	if view.particles then pcall(function()
		view.particles:remove()
	end) end
	Cards.remove_scatter(view.scatter)
	for _, key in ipairs({ "flash", "title", "left", "right", "vs", "footer" }) do
		remove_box(view[key])
		view[key] = nil
	end
	view.particles, view.scatter = nil, nil
end

-- Gives the screen back: cancels the view's pending events, shows the menus it hid, and
-- restores the swirl. Returns the view, whose boxes are still up.
local function close()
	Reveal.generation = Reveal.generation + 1
	seen_players = 0
	local view = Reveal.view
	Reveal.view = nil
	Reveal.lobby = nil
	if view then
		show_ui(view)
		if Backdrop.mode == "reveal" then Backdrop.restore() end
	end
	return view
end

-- Ends the reveal at once, and an outro still playing. For a failed match, a menu opening, and
-- the run starting (which deletes the menu stage's objects, these boxes among them).
function Reveal.dismiss()
	local view = close()
	if view then remove_view(view) end
	if Reveal.leaving then
		remove_view(Reveal.leaving)
		Reveal.leaving = nil
	end
end

-- Ends the reveal for the game starting. The menus come back at once (the votes and the Draft
-- open in them) and the player cards slide off over them. Reduced motion ends it at once.
function Reveal.finish()
	if not Reveal.view or reduced_motion() then return Reveal.dismiss() end
	if Reveal.leaving then remove_view(Reveal.leaving) end
	local view = close()
	Reveal.leaving = view
	if view.particles then pcall(function()
		view.particles:remove()
	end) end
	Cards.remove_scatter(view.scatter)
	remove_box(view.flash)
	remove_box(view.vs)
	view.particles, view.scatter, view.flash, view.vs = nil, nil, nil, nil
	slide(view.left, -CARD_X * 5, nil)
	slide(view.right, CARD_X * 5, nil)
	slide(view.title, nil, OFFSCREEN_Y)
	slide(view.footer, nil, -OFFSCREEN_Y)
	play_sound("cardSlide1", 1.1, 0.5)
	Widgets.after(OUTRO_SECONDS, nil, function()
		remove_view(view)
		if Reveal.leaving == view then Reveal.leaving = nil end
	end)
end

local function face(avatar, unknown)
	local w, h = G.CARD_W * AVATAR_SCALE, G.CARD_H * AVATAR_SCALE
	if unknown then
		return {
			n = G.UIT.R,
			config = { align = "cm", minw = w, minh = h, r = 0.1, colour = G.C.UI.BACKGROUND_INACTIVE },
			nodes = {
				text_object(nil, { "?" }, 0.9, G.C.WHITE, { float = true, bump = true }),
			},
		}
	end
	local center = G.P_CENTERS[avatar or "j_joker"] or G.P_CENTERS.j_joker
	local card = Card(
		0,
		0,
		w,
		h,
		nil,
		center,
		{ bypass_discovery_center = true, bypass_discovery_ui = true, bypass_lock = true }
	)
	card.no_ui = true
	card.states.drag.can = false
	card.states.hover.can = false
	return { n = G.UIT.R, config = { align = "cm" }, nodes = { { n = G.UIT.O, config = { object = card } } } }
end

local function player_card(name, rating, avatar, unknown)
	local elo_line, rank_line = "", ""
	if Reveal.ranked and not unknown then
		elo_line, rank_line = Reveal.card_lines(rating)
	end
	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.1, r = 0.12, minw = 2.4, minh = 2.9, colour = G.C.WHITE, emboss = 0.08 },
		nodes = {
			{
				n = G.UIT.R,
				config = { align = "cm", maxw = 2.2 },
				nodes = {
					{ n = G.UIT.T, config = { text = name, scale = 0.42, colour = G.C.UI.TEXT_DARK } },
				},
			},
			face(avatar, unknown),
			{
				n = G.UIT.R,
				config = { align = "cm" },
				nodes = {
					{ n = G.UIT.T, config = { text = elo_line, scale = 0.36, colour = G.C.UI.TEXT_DARK } },
				},
			},
			{
				n = G.UIT.R,
				config = { align = "cm" },
				nodes = {
					{ n = G.UIT.T, config = { text = rank_line, scale = 0.3, colour = G.C.UI.TEXT_INACTIVE } },
				},
			},
		},
	}
end

local function players_of(lobby)
	if not lobby then return nil, nil end
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

local function left_card()
	local me = players_of(Reveal.lobby)
	local rating = (me and Reveal.ratings[me.id]) or Reveal.own_rating
	local avatar = (me and me.preferredJoker) or Reveal.own_avatar
	return player_card(localize("k_pvp_you"), rating, avatar)
end

local function right_card()
	local _, opp = players_of(Reveal.lobby)
	if not opp then return player_card("...", nil, nil, true) end
	return player_card(opp.displayName or "?", Reveal.ratings[opp.id], opp.preferredJoker)
end

local CARD_BUILDERS = { left = left_card, right = right_card }
local function card_node(side)
	return { n = G.UIT.C, config = { id = "pvp_reveal_" .. side, align = "cm" }, nodes = { CARD_BUILDERS[side]() } }
end
-- POPUP boxes are outside MPAPI.ui_element's UIBOX lookup.
local function refresh_card(side)
	local box = Reveal.view and Reveal.view[side]
	local container = box and box:get_UIE_by_ID("pvp_reveal_" .. side)
	if not container then return end
	remove_all(container.children)
	container.children = {}
	box:set_parent_child(CARD_BUILDERS[side](), container)
	box:recalculate()
end

local function refresh_cards()
	refresh_card("left")
	refresh_card("right")
end

function Reveal.start(search, fan_cards)
	Reveal.dismiss()
	local generation = Reveal.generation
	Reveal.view = { hidden = {} }
	Reveal.ratings = {}
	Reveal.ranked, Reveal.ticket = search.ranked, search.ticket
	Reveal.own_rating = search.rating
	Reveal.own_avatar = search.avatar
	Reveal.expires_at = now() + JOIN_SECONDS
	local view = Reveal.view
	-- A menu opened after this one (a notice, the version overlay) ends the reveal.
	view.overlay = G.OVERLAY_MENU
	view.footer_text = localize("k_pvp_shuffling")
	view.vs_text = "VS"
	local calm = reduced_motion()
	if PVP.config.queue_match_sound ~= false then
		play_sound("explosion_buildup1")
		after(1.17, generation, function()
			play_sound("explosion_release1")
		end)
	end
	pcall(love.window.requestAttention, false)
	hide_ui(view)
	Backdrop.reveal(SPIN_FOUND)
	after(0.7, generation, Backdrop.settle)
	if not calm then
		local flash_colour = { 1, 1, 1, 0.75 }
		view.flash = room_box(
			{ n = G.UIT.ROOT, config = { align = "cm", minw = 40, minh = 30, colour = flash_colour }, nodes = {} },
			{ x = 0, y = 0 },
			true
		)
		ease_to(flash_colour, 4, 0, 0.45)
		if G.ROOM then G.ROOM.jiggle = G.ROOM.jiggle + 6 end
	end
	if fan_cards then
		view.scatter = Cards.scatter(fan_cards, function(delay, fn)
			after(delay, generation, fn)
		end, calm)
	end
	view.title = room_box(
		clear_root({
			text_object(
				nil,
				{ localize("k_pvp_match_found") },
				1.4,
				G.C.GOLD,
				{ float = true, bump = true, pop_in = 0, pop_in_rate = 8 }
			),
		}),
		{ x = 0, y = OFFSCREEN_Y },
		true
	)
	slide(view.title, nil, -2.6)
	if not calm then
		view.particles = Particles(0, 0, 0, 0, {
			timer_type = "TOTAL",
			timer = 0.01,
			pulse_max = 50,
			max = 0,
			scale = 0.25,
			speed = 6,
			lifespan = 1.3,
			fill = true,
			padding = 0.6,
			attach = view.title.UIRoot,
			colours = { G.C.RED, G.C.BLUE, G.C.GOLD, G.C.WHITE },
		})
	end
	local function deal(side, x, delay)
		after(delay, generation, function()
			view[side] = room_box(clear_root({ card_node(side) }), { x = x * 5, y = 0.4 }, true)
			slide(view[side], x, nil)
			after(0.3, generation, function()
				juice(view[side], 0.25, 0.1)
				play_sound("card1", side == "left" and 1 or 1.15, 0.7)
			end)
		end)
	end
	deal("left", -CARD_X, 0.35)
	deal("right", CARD_X, 0.5)
	after(0.9, generation, function()
		view.vs = room_box(
			clear_root({
				text_object(
					nil,
					{ { ref_table = view, ref_value = "vs_text" } },
					1.1,
					G.C.RED,
					{ bump = true, pop_in = 0, pop_in_rate = 10 }
				),
			}),
			{ x = 0, y = 0.4 },
			true
		)
		juice(view.vs, 0.4, 0.15)
		play_sound("generic1", 0.9, 0.6)
		if G.ROOM and not calm then G.ROOM.jiggle = G.ROOM.jiggle + 2 end
	end)
	after(1.3, generation, function()
		view.footer = room_box(
			clear_root({
				text_object(
					nil,
					{ { ref_table = view, ref_value = "footer_text" } },
					0.38,
					G.C.UI.TEXT_LIGHT,
					{ float = true, pop_in = 0, pop_in_rate = 4 }
				),
			}),
			{ x = 0, y = 2.5 },
			true
		)
	end)
end

function Reveal.lobby_ready(lobby)
	if not Reveal.view then return end
	Reveal.lobby = lobby
end

local function read_reveal_ratings()
	local lobby = Reveal.lobby
	if not lobby or not Reveal.ranked then return end
	for _, p in ipairs(lobby:get_players()) do
		if Reveal.ratings[p.id] == nil then
			Reveal.ratings[p.id] = false
			local id, ticket = p.id, Reveal.ticket
			MPAPI.matchmaking.get_rating(PVP.id, ticket, nil, id, function(err, data)
				if Reveal.lobby ~= lobby then return end
				Reveal.ratings[id] = (not err and data) or { unknown = true }
				refresh_cards()
			end)
		end
	end
end

-- One beat of the countdown: the number takes the VS's place and both cards feel it.
local function beat(view, secs)
	view.vs_text = tostring(secs)
	juice(view.vs, 0.5, 0.18)
	juice(view.left, 0.12, 0.04)
	juice(view.right, 0.12, 0.04)
	play_sound("multhit1", 0.8 + (BEATS_FROM - secs) * 0.15, 0.5)
	if G.ROOM and not reduced_motion() then G.ROOM.jiggle = G.ROOM.jiggle + 1.5 end
end

function Reveal.update()
	if not Reveal.view then return end
	local lobby = Reveal.lobby
	local overlay = G.OVERLAY_MENU
	if now() >= Reveal.expires_at or (lobby and lobby._destroyed) or (overlay and overlay ~= Reveal.view.overlay) then
		Reveal.dismiss()
		return
	end
	hide_ui(Reveal.view)
	if lobby then
		local n = #lobby:get_players()
		if n ~= seen_players then
			local had_opp = seen_players > 1
			-- The opponent left before the game started: the lobby's own UI says so.
			if had_opp and n < 2 then
				Reveal.dismiss()
				return
			end
			seen_players = n
			read_reveal_ratings()
			refresh_cards()
			if n > 1 and not had_opp and Reveal.view then
				Reveal.view.starts_at = now() + Reveal.HOLD_SECONDS
				Reveal.expires_at = Reveal.view.starts_at + START_GRACE_SECONDS
				if Reveal.view.right then
					juice(Reveal.view.right, 0.35, 0.12)
					play_sound("card1", 0.85, 0.8)
				end
			end
		end
	end
	local view = Reveal.view
	if view and view.starts_at then
		local secs = math.max(1, math.ceil(view.starts_at - now()))
		view.footer_text = localize({ type = "variable", key = "k_pvp_starting_in", vars = { secs } })
		if secs ~= view.beat then
			view.beat = secs
			if secs <= BEATS_FROM then beat(view, secs) end
		end
	end
end
