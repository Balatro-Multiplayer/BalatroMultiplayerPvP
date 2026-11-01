-- The queue HUD and the match-found reveal.
--
-- While PvP's one queue is searching, a small box sits top-right over every menu screen: the
-- time waited, how many are in that queue, and for Ranked the rating range being searched (the
-- window MPAPI.matchmaking.ranked_spread widens every RANKED_SPREAD_EXPAND_SECS). A player still
-- in placements isn't shown their rating, so their range reads as a step count instead. The
-- queue keeps running wherever the player goes, so the HUD is how they get back to cancelling.
--
-- On a match: a sound, a screen jiggle, the taskbar asks for attention, and MATCH FOUND pops in
-- over the screen. Once the lobby is joined the two players' cards fill in (name, Elo or
-- placement progress, board rank), and it stays up until the run starts or the lobby goes.
--
-- Driven from pvp_api/queue.lua: PVP._show_searching starts/stops the HUD, the handle's
-- match_found / lobby_ready events drive the reveal.

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
	hud = nil,
	reveal = nil,
	reveal_lobby = nil,
	reveal_until = 0,
	reveal_ratings = {},
	particles = nil,
}
PVP.QUEUE_HUD = Q

local COUNTS_POLL_SECONDS = 5
-- The reveal goes on its own if the run never starts (a failed autostart leaves the lobby UI).
local REVEAL_MAX_SECONDS = 15

local function now()
	return love.timer.getTime()
end

-- Pure helpers (tests/queue_hud_test.lua) ------------------------------------------------------

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

-- Queue HUD ------------------------------------------------------------------------------------

-- Live text: DynaText reads these through a ref_table every frame.
local live = setmetatable({}, {
	__index = function(_, k)
		if k == "timer" then
			return Q.format_elapsed(now() - Q.started_at)
		elseif k == "status" then
			return localize("k_pvp_queue_searching") .. string.rep(".", math.floor(now() * 2) % 4)
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

local function live_text(key, scale, colour, opts)
	opts = opts or {}
	return { n = G.UIT.O, config = { id = "pvp_queue_hud_" .. key, object = DynaText({
		string = { { ref_table = live, ref_value = key } },
		colours = { colour },
		scale = scale,
		shadow = true,
		float = opts.float,
		maxw = opts.maxw,
	}) } }
end

local function hud_definition()
	local rows = {
		{ n = G.UIT.R, config = { align = "cm" }, nodes = {
			{ n = G.UIT.C, config = { align = "cl", minw = 1.9 }, nodes = { live_text("status", 0.38, G.C.UI.TEXT_LIGHT) } },
			{ n = G.UIT.C, config = { align = "cr", minw = 1.3 }, nodes = { live_text("timer", 0.6, G.C.IMPORTANT, { float = true }) } },
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

local function remove_hud()
	if Q.hud then
		pcall(function() Q.hud:remove() end)
		Q.hud = nil
	end
end

local function show_hud()
	remove_hud()
	Q.hud = UIBox({
		definition = hud_definition(),
		config = { align = "tri", offset = { x = -0.25, y = 0.25 }, major = G.ROOM_ATTACH, bond = "Weak" },
	})
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
		Q.in_queue = c and tonumber(c.queued) or Q.in_queue
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
	Q.ranked = queue_id.kind == PVP.LobbyAccess.RANKED
	Q.label = title_for(queue_id)
	Q.ticket = Q.ranked and PVP.ranked_ticket(queue_id.key) or nil
	Q.count_key = Q.ticket or queue_id.key
	Q.spread = Q.ranked and MPAPI.matchmaking.ranked_spread(0) or nil
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
	show_hud()
end

function Q.stop()
	Q.active = false
	Q.queue_id = nil
	remove_hud()
end

-- Match-found reveal -----------------------------------------------------------------------------

local seen_players = 0

local function remove_reveal()
	seen_players = 0
	if Q.particles then
		pcall(function() Q.particles:remove() end)
		Q.particles = nil
	end
	if Q.reveal then
		pcall(function() Q.reveal:remove() end)
		Q.reveal = nil
	end
	Q.reveal_lobby = nil
end

local function player_card(name, rating, colour)
	-- A casual match has no ratings to show.
	local elo_line, rank_line = "", ""
	if Q.reveal_ranked then
		elo_line, rank_line = Q.card_lines(rating)
	end
	return { n = G.UIT.C, config = { align = "cm", padding = 0.1, r = 0.12, minw = 2.4, minh = 2.9, colour = G.C.WHITE, emboss = 0.08 }, nodes = {
		{ n = G.UIT.R, config = { align = "cm", maxw = 2.2 }, nodes = {
			{ n = G.UIT.T, config = { text = name, scale = 0.42, colour = G.C.UI.TEXT_DARK } },
		} },
		{ n = G.UIT.R, config = { align = "cm", minw = 1.4, minh = 1.2, r = 0.1, colour = colour }, nodes = {
			{ n = G.UIT.T, config = { text = string.upper(string.sub(name, 1, 1)), scale = 0.9, colour = G.C.WHITE, shadow = true } },
		} },
		{ n = G.UIT.R, config = { align = "cm" }, nodes = {
			{ n = G.UIT.T, config = { text = elo_line, scale = 0.36, colour = G.C.UI.TEXT_DARK } },
		} },
		{ n = G.UIT.R, config = { align = "cm" }, nodes = {
			{ n = G.UIT.T, config = { text = rank_line, scale = 0.3, colour = G.C.UI.TEXT_INACTIVE } },
		} },
	} }
end

-- The two cards, or a placeholder until the lobby is joined and the opponent is in it.
local vs_el = MPAPI.ui_element(function()
	local lobby = Q.reveal_lobby
	if not lobby then
		return { nodes = { { n = G.UIT.R, config = { align = "cm", minh = 2.9 }, nodes = {} } } }
	end
	local self_id = lobby.player_id
	local me, opp
	for _, p in ipairs(lobby:get_players()) do
		if p.id == self_id then
			me = p
		else
			opp = opp or p
		end
	end
	local nodes = {
		player_card(localize("k_pvp_you"), me and Q.reveal_ratings[me.id], G.C.BLUE),
		{ n = G.UIT.C, config = { align = "cm", padding = 0.3 }, nodes = {
			{ n = G.UIT.T, config = { text = "VS", scale = 1, colour = G.C.RED, shadow = true } },
		} },
		opp and player_card(opp.displayName or "?", Q.reveal_ratings[opp.id], G.C.RED)
			or player_card("...", nil, G.C.UI.BACKGROUND_INACTIVE),
	}
	return { nodes = { { n = G.UIT.R, config = { align = "cm" }, nodes = nodes } } }
end)

local function reveal_definition()
	return { n = G.UIT.ROOT, config = { align = "cm", padding = 0.2, r = 0.2, colour = { 0, 0, 0, 0.55 } }, nodes = {
		{ n = G.UIT.C, config = { align = "cm", padding = 0.15 }, nodes = {
			{ n = G.UIT.R, config = { align = "cm" }, nodes = {
				{ n = G.UIT.O, config = { object = DynaText({
					string = { localize("k_pvp_match_found") },
					colours = { G.C.GOLD },
					scale = 1.4,
					shadow = true,
					float = true,
					bump = true,
					pop_in = 0,
					pop_in_rate = 8,
					silent = true,
				}) } },
			} },
			{ n = G.UIT.R, config = { align = "cm" }, nodes = { vs_el.node } },
			{ n = G.UIT.R, config = { align = "cm" }, nodes = {
				{ n = G.UIT.T, config = { text = localize("k_pvp_shuffling"), scale = 0.35, colour = G.C.UI.TEXT_LIGHT } },
			} },
		} },
	} }
end

function Q.match_found()
	local ranked = Q.ranked
	local ticket = Q.ticket
	Q.stop()
	remove_reveal()
	Q.reveal_ratings = {}
	Q.reveal_ranked, Q.reveal_ticket = ranked, ticket
	Q.reveal_until = now() + REVEAL_MAX_SECONDS

	play_sound("timpani", 1, 0.8)
	play_sound("holo1", 1.3, 0.5)
	if G.ROOM then
		G.ROOM.jiggle = G.ROOM.jiggle + 4
	end
	-- Flashes the taskbar / bounces the dock icon if the game is in the background.
	pcall(love.window.requestAttention, false)

	Q.reveal = UIBox({
		definition = reveal_definition(),
		config = { align = "cm", offset = { x = 0, y = -0.5 }, major = G.ROOM_ATTACH, bond = "Weak", instance_type = "POPUP" },
	})
	Q.particles = Particles(0, 0, 0, 0, {
		timer_type = "TOTAL",
		timer = 0.01,
		pulse_max = 40,
		max = 0,
		scale = 0.25,
		speed = 5,
		lifespan = 1.2,
		fill = true,
		padding = 0.5,
		attach = Q.reveal.UIRoot,
		colours = { G.C.RED, G.C.BLUE, G.C.GOLD, G.C.WHITE },
	})
end

-- Fills the cards in once the matched lobby is joined. Ratings are read per player as they
-- appear (an opponent can join a moment after us); a casual match shows no Elo lines.
function Q.lobby_ready(lobby)
	if not Q.reveal then
		return
	end
	Q.reveal_lobby = lobby
	vs_el:update()
	play_sound("card1", 1.1, 0.7)
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
				vs_el:update()
			end)
		end
	end
end

-- Per-frame upkeep ------------------------------------------------------------------------------

local function tick()
	if Q.active then
		local t = now()
		if Q.ranked then
			local spread = MPAPI.matchmaking.ranked_spread(t - Q.started_at)
			if spread ~= Q.spread then
				Q.spread = spread
				play_sound("chips1", 1.2, 0.4)
				local range = Q.hud and Q.hud:get_UIE_by_ID("pvp_queue_hud_range")
				if range and range.config.object then
					range.config.object:pulse(0.6)
				end
				if Q.hud then
					Q.hud.UIRoot:juice_up(0.05, 0.02)
				end
			end
		end
		if t >= Q.next_poll then
			Q.next_poll = t + COUNTS_POLL_SECONDS
			poll_counts()
		end
	end
	if Q.reveal then
		local lobby = Q.reveal_lobby
		if now() >= Q.reveal_until or (lobby and lobby._destroyed) then
			remove_reveal()
			return
		end
		if lobby then
			local n = #lobby:get_players()
			if n ~= seen_players then
				seen_players = n
				read_reveal_ratings()
				vs_el:update()
			end
		end
	end
end

local game_update_ref = Game.update
---@diagnostic disable-next-line: duplicate-set-field
function Game:update(dt)
	game_update_ref(self, dt)
	local ok, err = pcall(tick)
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
