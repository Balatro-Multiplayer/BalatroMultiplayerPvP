-- Queue lifecycle, polling, and the searching HUD. Public entry points serve pvp_api/queue.lua.
local Hud =
	{ active = false, started_at = 0, ranked = false, label = "", next_poll = 0, last_minute = 0, generation = 0 }
PVP.QUEUE_HUD = Hud
local Cards, Backdrop, Widgets = PVP.QUEUE_CARDS, PVP.QUEUE_BACKDROP, PVP.QUEUE_WIDGETS
local now, after = Widgets.now, Widgets.after
local slide, juice, remove_box, text_object = Widgets.slide, Widgets.juice, Widgets.remove_box, Widgets.text_object
local COUNTS_POLL_SECONDS = 5
local HUD_OFFSET = { x = -0.25, y = 0.25 }
local OFFSCREEN_Y = -5
local SWIRL_MIN, SWIRL_MAX = 1.25, 2.5

function Hud.format_elapsed(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function Hud.search_step(spread)
	local M = MPAPI.matchmaking
	local total = math.floor((M.RANKED_SPREAD_CAP - M.RANKED_SPREAD_INITIAL) / M.RANKED_SPREAD_EXPAND_RATE) + 1
	local step = math.floor(
		((spread or M.RANKED_SPREAD_INITIAL) - M.RANKED_SPREAD_INITIAL) / M.RANKED_SPREAD_EXPAND_RATE
	) + 1
	return math.min(step, total), total
end

function Hud.swirl_for(spread)
	local step, total = Hud.search_step(spread)
	return SWIRL_MIN + (SWIRL_MAX - SWIRL_MIN) * (step - 1) / math.max(1, total - 1)
end

function Hud.spread_factor(spread)
	local step, total = Hud.search_step(spread)
	return (step - 1) / math.max(1, total - 1)
end

-- `centre`: the rating the ticket carries, when known; else the rating record's.
function Hud.range_text(rating, spread, centre)
	if not rating then return "..." end
	if PVP.placement_progress(rating) then
		local step, total = Hud.search_step(spread)
		return localize({ type = "variable", key = "k_pvp_queue_widening", vars = { step, total } })
	end
	local r = math.floor((centre or tonumber(rating.rating) or 0) + 0.5)
	return string.format("%d-%d", r - spread, r + spread)
end

-- The handle's queue time, ticket rating, and server-side window (nil until the first ticket
-- is in). All three are MPAPI privates (api/matchmaking/api.lua); nothing else here reads them.
-- Reaching into another mod's underscores is dumb. TODO: expose these through MPAPI's API.
local function ticket()
	local h = Hud.handle
	if not h then return nil end
	return h._queued_at, h._nakama_rating, h._nakama_spread
end

local function elapsed()
	return now() - (ticket() or Hud.started_at)
end

-- Casual tickets have no window, so the swirl and fan pace off the wait instead.
local function search_spread()
	local M = MPAPI.matchmaking
	if not Hud.ranked then return M.ranked_spread(elapsed()) end
	local _, _, spread = ticket()
	return spread or M.RANKED_SPREAD_INITIAL
end

-- DynaText resolves these references every frame.
local live = setmetatable({}, {
	__index = function(_, k)
		if k == "timer" then
			return Hud.format_elapsed(elapsed())
		elseif k == "dots" then
			return string.rep(".", math.floor(now() * 2) % 4)
		elseif k == "sub" then
			if Hud.in_queue == nil then return Hud.label end
			return Hud.label
				.. "  "
				.. localize({ type = "variable", key = "k_pvp_queue_in_queue", vars = { Hud.in_queue } })
		elseif k == "range" then
			local _, centre = ticket()
			return Hud.range_text(Hud.rating, Hud.spread or MPAPI.matchmaking.RANKED_SPREAD_INITIAL, centre)
		end
		return ""
	end,
})

local function live_text(key, scale, colour, opts)
	return text_object("pvp_queue_hud_" .. key, { { ref_table = live, ref_value = key } }, scale, colour, opts)
end

local function hud_definition()
	local rows = {
		{ n = G.UIT.R, config = { align = "cm" }, nodes = { { n = G.UIT.O, config = { object = Hud.fan.area } } } },
		{
			n = G.UIT.R,
			config = { align = "cm" },
			nodes = {
				{
					n = G.UIT.C,
					config = { align = "cl", minw = 1.9 },
					nodes = {
						{
							n = G.UIT.R,
							config = { align = "cl" },
							nodes = {
								text_object(
									"pvp_queue_hud_status",
									{ localize("k_pvp_queue_searching") },
									0.38,
									G.C.UI.TEXT_LIGHT,
									{ float = true }
								),
								live_text("dots", 0.38, G.C.UI.TEXT_LIGHT),
							},
						},
					},
				},
				{
					n = G.UIT.C,
					config = { align = "cr", minw = 1.3 },
					nodes = { live_text("timer", 0.6, G.C.IMPORTANT) },
				},
			},
		},
		{
			n = G.UIT.R,
			config = { align = "cm" },
			nodes = { live_text("sub", 0.3, G.C.UI.TEXT_INACTIVE, { maxw = 3.2 }) },
		},
	}
	if Hud.ranked then
		rows[#rows + 1] = {
			n = G.UIT.R,
			config = {
				align = "cm",
				padding = 0.04,
				r = 0.08,
				colour = mix_colours(G.C.BLACK, G.C.L_BLACK, 0.5),
				minw = 3.2,
			},
			nodes = {
				live_text("range", 0.36, G.C.GOLD, { maxw = 3.0 }),
			},
		}
	end
	rows[#rows + 1] = {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.04 },
		nodes = {
			UIBox_button({
				button = "mp_pvp_cancel_queue",
				label = { localize("b_cancel_search_cap") },
				colour = G.C.RED,
				minw = 3.2,
				minh = 0.45,
				scale = 0.32,
			}),
		},
	}
	return {
		n = G.UIT.ROOT,
		config = { align = "cm", padding = 0.1, r = 0.12, colour = G.C.L_BLACK, emboss = 0.08 },
		nodes = {
			{ n = G.UIT.C, config = { align = "cm", padding = 0.04 }, nodes = rows },
		},
	}
end
-- UIBox recursively owns its embedded CardArea and text objects.
local function hide_hud()
	local hud = Hud.hud
	Hud.hud = nil
	if not hud then return end
	Hud.fan = nil
	slide(hud, nil, OFFSCREEN_Y)
	after(0.5, nil, function()
		remove_box(hud)
	end)
end

local function show_hud()
	remove_box(Hud.hud)
	Hud.fan = Cards.create_fan()
	Hud.hud = UIBox({
		definition = hud_definition(),
		config = { align = "tri", offset = { x = HUD_OFFSET.x, y = OFFSCREEN_Y }, major = G.ROOM_ATTACH, bond = "Weak" },
	})
	slide(Hud.hud, nil, HUD_OFFSET.y)
	local hud = Hud.hud
	after(0.35, nil, function()
		if Hud.hud == hud then juice(hud, 0.15, 0.05) end
	end)
end

local function title_for(queue_id)
	if queue_id.kind == PVP.LobbyAccess.RANKED then
		return PVP.ruleset_display_name(queue_id.key) .. " " .. localize("k_pvp_ranked")
	end
	local def = PVP.PVP_GAMEMODES[queue_id.key]
	return def and def.display or tostring(queue_id.key)
end

-- How many a queue's lobby holds: ranked is two, a casual mode its public size.
local function capacity_of(queue_id)
	if queue_id.kind == PVP.LobbyAccess.RANKED then return 2 end
	local gm = MPAPI.GameModes and MPAPI.GameModes[queue_id.key]
	return (gm and gm.max_players and gm.max_players.public) or 2
end

local function poll_counts()
	local key, generation = Hud.count_key, Hud.generation
	MPAPI.matchmaking.get_queue_counts(PVP.id, function(err, game_modes)
		if err or not Hud.active or Hud.generation ~= generation then return end
		local c = game_modes and game_modes[key]
		local n = c and tonumber(c.queued)
		if n and n ~= Hud.in_queue then
			Hud.in_queue = n
			local sub = Hud.hud and Hud.hud:get_UIE_by_ID("pvp_queue_hud_sub")
			if sub and sub.config.object then sub.config.object:pulse(0.3) end
		end
	end)
end

-- Repeated queued events must preserve the existing search clock. `handle` supplies the clock
-- and window when present (see ticket()).
function Hud.start(queue_id, handle)
	if not queue_id then return end
	if Hud.active and Hud.queue_id and Hud.queue_id.kind == queue_id.kind and Hud.queue_id.key == queue_id.key then
		return
	end
	Hud.generation = Hud.generation + 1
	Hud.active = true
	Hud.queue_id = { kind = queue_id.kind, key = queue_id.key }
	Hud.handle = handle
	Hud.started_at = now()
	Hud.last_minute = 0
	Hud.ranked = queue_id.kind == PVP.LobbyAccess.RANKED
	Hud.label = title_for(queue_id)
	Hud.ticket = Hud.ranked and PVP.ranked_ticket(queue_id.key) or nil
	Hud.count_key = Hud.ticket or queue_id.key
	Hud.capacity = capacity_of(queue_id)
	Hud.spread = search_spread()
	Hud.in_queue = nil
	Hud.next_poll = now()
	Hud.rating = nil
	if Hud.ranked then
		Hud.rating = false
		local ticket, generation = Hud.ticket, Hud.generation
		MPAPI.matchmaking.get_rating(PVP.id, ticket, nil, nil, function(err, data)
			if Hud.active and Hud.generation == generation then Hud.rating = (not err and data) or nil end
		end)
	end
	play_sound("highlight2", 1.1, 0.6)
	Backdrop.set_speed(Hud.swirl_for(Hud.spread))
	show_hud()
end

function Hud.stop()
	if not Hud.active then return end
	Hud.active = false
	Hud.queue_id = nil
	Hud.handle = nil
	hide_hud()
	if not PVP.QUEUE_REVEAL.view then Backdrop.restore() end
end

local function tick_hud()
	local t = now()
	local waited = elapsed()
	local spread = search_spread()
	if spread ~= Hud.spread then
		Hud.spread = spread
		Backdrop.set_speed(Hud.swirl_for(spread))
		if Hud.ranked then
			play_sound("chips1", 1.2, 0.4)
			local range = Hud.hud and Hud.hud:get_UIE_by_ID("pvp_queue_hud_range")
			if range and range.config.object then range.config.object:pulse(0.6) end
		end
		juice(Hud.hud, 0.08, 0.03)
		if Hud.fan then
			for _, card in ipairs(Hud.fan.area.cards or {}) do
				card:juice_up(0.12, 0.08)
			end
		end
	end
	Cards.update_fan(Hud.fan, t, Hud.spread_factor(Hud.spread))
	local minute = math.floor(waited / 60)
	if minute > Hud.last_minute then
		Hud.last_minute = minute
		local timer = Hud.hud and Hud.hud:get_UIE_by_ID("pvp_queue_hud_timer")
		if timer and timer.config.object then timer.config.object:pulse(0.8) end
		juice(Hud.hud, 0.12, 0.04)
	end
	if t >= Hud.next_poll then
		Hud.next_poll = t + COUNTS_POLL_SECONDS
		poll_counts()
	end
end

local game_update_ref = Game.update
---@diagnostic disable-next-line: duplicate-set-field
function Game:update(dt)
	game_update_ref(self, dt)
	local ok, err = pcall(function()
		if Hud.active then tick_hud() end
		PVP.QUEUE_REVEAL.update()
		Backdrop.update(G.real_dt or dt)
	end)
	if not ok then
		sendWarnMessage("[pvp] queue HUD: " .. tostring(err), "MULTIPLAYER")
		Hud.stop()
		PVP.QUEUE_REVEAL.dismiss()
	end
end

local start_run_ref = Game.start_run
---@diagnostic disable-next-line: duplicate-set-field
function Game:start_run(args)
	PVP.QUEUE_REVEAL.dismiss()
	return start_run_ref(self, args)
end

function Hud.dismiss_reveal()
	PVP.QUEUE_REVEAL.dismiss()
end

function Hud.finish_reveal()
	PVP.QUEUE_REVEAL.finish()
end

function Hud.lobby_ready(lobby)
	PVP.QUEUE_REVEAL.lobby_ready(lobby)
end

-- `queue_id` names the queue for a search the HUD didn't show: a group queue's
-- (pvp_api/group_queue.lua), which waits in its own lobby.
function Hud.match_found(queue_id)
	local cards = Cards.detach(Hud.fan)
	local search = { ranked = false, capacity = queue_id and capacity_of(queue_id) or 2 }
	if Hud.active then
		search = { ranked = Hud.ranked, ticket = Hud.ticket, rating = Hud.rating, capacity = Hud.capacity }
	end
	search.avatar = MPAPI.connection_state.preferred_joker
	Hud.stop()
	PVP.QUEUE_REVEAL.start(search, cards)
end
