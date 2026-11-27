-- The DETAILS overlay for one tournament: everything about how it is run
-- (round-by-round settings and timetable changes included), who is in it,
-- and a BRACKET button (the bracket page, ui/tournament/bracket_page.lua).

PVP.TUI = PVP.TUI or {}
local TUI = PVP.TUI

-- Stored names -> text keys (looked up when drawn).
local PRESETS = { live_event = "k_tn_preset_live_event", live_fixed_rounds = "k_tn_preset_live_fixed_rounds", league = "k_tn_preset_league" }
local SEEDING = { rating = "k_tn_seeding_rating", random = "k_tn_seeding_random", manual = "k_tn_seeding_manual" }

local function text_of(map, value)
	local key = map[value]
	return key and PVP.T(key) or tostring(value or "?")
end

local overlay_lists = {}

local function close_lists()
	for _, l in ipairs(overlay_lists) do
		l:dispose()
	end
	overlay_lists = {}
end

local function kv(label, value)
	return {
		n = G.UIT.R,
		config = { align = "cl", padding = 0.02 },
		nodes = {
			{ n = G.UIT.C, config = { align = "cl", minw = 2.6 }, nodes = { TUI.text(label, TUI.SMALL, G.C.UI.TEXT_INACTIVE) } },
			{ n = G.UIT.C, config = { align = "cl" }, nodes = { TUI.text(value, TUI.SMALL) } },
		},
	}
end

local function format_text(view)
	local s = view.summary
	local o = view.formatOptions or {}
	local text = TUI.format_name(s.format)
	if s.format == "double_elim" then
		text = PVP.T("k_tn_list2", text, PVP.T(o.grandFinalReset == false and "k_tn_no_gf_reset" or "k_tn_gf_reset"))
	elseif s.format == "swiss" and o.swissRounds then
		text = PVP.T("k_tn_list2", text, TUI.count(o.swissRounds, "k_tn_n_rounds"))
	elseif s.format == "round_robin" and o.groupSize then
		text = PVP.T("k_tn_list2", text, PVP.T("k_tn_groups_of", o.groupSize))
	end
	return text
end

local ORDERS = { lower_seed_first = "k_tn_order_lower_first", lower_seed_last = "k_tn_order_higher_first", random = "k_tn_order_random", previous_loser_first = "k_tn_order_loser_first" }

local function deck_text(deck)
	local text = TUI.deck_rule(deck)
	if type(deck) == "table" and deck.kind == "draft" then
		text = PVP.T("k_tn_cocktail_mix", text, text_of(ORDERS, deck.banOrder))
	end
	return (text:gsub("^%l", string.upper))
end

-- What a round override changes: "Black Deck on Orange Stake, best of 5".
local function override_text(o)
	local parts = {}
	if o.ruleset then
		parts[#parts + 1] = TUI.ruleset_name(o.ruleset)
	end
	if o.deck then
		parts[#parts + 1] = TUI.deck_rule(o.deck)
	end
	if o.bestOf then
		parts[#parts + 1] = PVP.T("k_tn_best_of_lower", o.bestOf)
	end
	return table.concat(parts, PVP.T("k_tn_list_sep"))
end

-- A sub-list under a heading: "  Round 3: 15 min break first".
local function sub_lines(rows, heading, map, describe, format)
	local keys = TUI.sorted_round_keys(map)
	if #keys == 0 then
		return
	end
	rows[#rows + 1] = { n = G.UIT.R, config = { align = "cl", padding = 0.02 }, nodes = { TUI.text(heading, TUI.SMALL, G.C.GOLD) } }
	for _, key in ipairs(keys) do
		rows[#rows + 1] = {
			n = G.UIT.R,
			config = { align = "cl", padding = 0.01 },
			nodes = {
				{ n = G.UIT.C, config = { align = "cl", minw = 2.6 }, nodes = { TUI.text("  " .. TUI.round_key_label(format, key), TUI.SMALL, G.C.UI.TEXT_INACTIVE) } },
				{ n = G.UIT.C, config = { align = "cl" }, nodes = { TUI.text(describe(map[key]), TUI.SMALL) } },
			},
		}
	end
end

-- The DETAILS overlay: at a glance first, everything else on request.
--   cards     STARTS, FORMAT, GAME, DECKS & STAKES: what a player peeking
--             needs to decide
--   then      the organiser's description, BRACKET, MORE DETAILS
--   more      grouped: WHEN (start, check-in, timetable and its changes),
--             HOW IT'S PLAYED (format, seeding, decks, rounds that differ)
--   right     the players
local details = { view = nil, more = false, el = nil, page = 1 }

-- Words over lines of about `width` characters.
local function wrap(text, width)
	local lines, line = {}, ""
	for word in tostring(text):gmatch("%S+") do
		if #line > 0 and #line + 1 + #word > width then
			lines[#lines + 1] = line
			line = word
		else
			line = #line > 0 and (line .. " " .. word) or word
		end
	end
	if #line > 0 then
		lines[#lines + 1] = line
	end
	return lines
end

-- One at-a-glance card: a small heading, the big answer, a detail under it.
local function card(title, big, small, colour)
	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.05 },
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cm", minw = 3.05, minh = 1.45, r = 0.1, colour = mix_colours(G.C.BLACK, G.C.L_BLACK, 0.45), emboss = 0.04, padding = 0.08 },
				nodes = {
					{ n = G.UIT.R, config = { align = "cm" }, nodes = { TUI.text(title, 0.26, colour or G.C.GOLD) } },
					{ n = G.UIT.R, config = { align = "cm", padding = 0.04 }, nodes = { TUI.text(big, 0.4, G.C.UI.TEXT_LIGHT) } },
					{ n = G.UIT.R, config = { align = "cm" }, nodes = { TUI.text(small or "", 0.26, G.C.UI.TEXT_INACTIVE) } },
				},
			},
		},
	}
end

local function starts_card(view)
	local s = view.summary
	local TT = PVP.TournamentTime
	if s.status == "running" then
		return card(PVP.T("k_tn_card_status"), PVP.T("k_tn_status_running"), view.paused and PVP.T("k_tn_paused_lower") or PVP.T("k_tn_started_at", TT.format_local(view.startedAt or s.startsAt)), G.C.GREEN)
	elseif s.status == "finished" then
		return card(PVP.T("k_tn_card_status"), PVP.T("k_tn_status_finished"), view.finishedAt and TT.format_local(view.finishedAt) or "")
	elseif s.status == "cancelled" then
		local why = PVP.TUI.cancel_reason(view)
		return card(PVP.T("k_tn_card_status"), PVP.T("k_tn_status_cancelled"), why and why.who or "", G.C.RED)
	end
	local left = TT.countdown(s.startsAt)
	return card(PVP.T("k_tn_card_starts"), TT.format_local(s.startsAt), left and PVP.T("k_tn_in", left) or PVP.T("k_tn_your_local_time"))
end

local function format_card(view)
	local s = view.summary
	local players = PVP.T("k_tn_n_of_max_players", s.players or 0, s.maxPlayers or 0)
	if (s.waitlist or 0) > 0 then
		players = PVP.T("k_tn_list2", players, PVP.T("k_tn_n_waiting", s.waitlist))
	end
	return card(PVP.T("k_tn_card_format"), TUI.format_name(s.format), players)
end

local function game_card(view)
	local d = view.rounds and view.rounds.defaults or {}
	local differ = next(view.rounds and view.rounds.overrides or {}) ~= nil
	return card(PVP.T("k_tn_card_ruleset"), TUI.ruleset_name(d.ruleset), PVP.T("k_tn_best_of_lower", tostring(d.bestOf or 1)) .. (differ and "*" or ""))
end

local function decks_card(view)
	local d = view.rounds and view.rounds.defaults or {}
	local deck = d.deck
	if type(deck) ~= "table" then
		return card(PVP.T("k_tn_card_decks"), PVP.T("k_tn_random_draft"), PVP.T("k_tn_random_draft_sub"))
	elseif deck.kind == "locked" then
		local name = TUI.deck_name(deck.deck)
		if type(deck.cocktail) == "table" and deck.cocktail.name then
			name = deck.cocktail.name
		end
		return card(PVP.T("k_tn_card_decks"), (name:gsub(" Deck$", "")), TUI.stake_name(deck.stake))
	end
	local cocktails = type(deck.cocktails) == "table" and #deck.cocktails or 0
	return card(PVP.T("k_tn_card_decks"), PVP.T("k_tn_ban_and_pick"), TUI.pool_size(#(deck.decks or {}), cocktails, #(deck.stakes or {})))
end

local function heading(text)
	return { n = G.UIT.R, config = { align = "cl", padding = 0.04 }, nodes = { TUI.text(text, TUI.TEXT, G.C.GOLD) } }
end

-- A ban pool's VIEW POOL button (MORE DETAILS): label names whose pool.
local function pool_button(label, deck)
	return { n = G.UIT.C, config = { align = "cm", padding = 0.02 }, nodes = { TUI.button(PVP.T("k_tn_b_view_pool"), "mp_pvp_tdetails_pool", { label = label, deck = deck }, G.C.BLUE, 1.8, 0.28) } }
end

local function is_pool(deck)
	return type(deck) == "table" and deck.kind == "draft"
end

local function pool_grid(rows, items, per_row, width)
	for i = 1, #items, per_row do
		local cells = {}
		for j = i, math.min(#items, i + per_row - 1) do
			cells[#cells + 1] = { n = G.UIT.C, config = { align = "cl", minw = width, padding = 0.03 }, nodes = { TUI.text(items[j], TUI.SMALL) } }
		end
		rows[#rows + 1] = { n = G.UIT.R, config = { align = "cl", padding = 0.01 }, nodes = cells }
	end
end

local function sub_heading(text)
	return { n = G.UIT.R, config = { align = "cl", padding = 0.04 }, nodes = { TUI.text(text, TUI.SMALL, G.C.GOLD) } }
end

-- VIEW POOL: every deck, Cocktail and stake a round bans and picks from.
local function pool_rows(pool)
	local deck = pool.deck
	local rows = {}
	rows[#rows + 1] = heading(PVP.T("k_tn_pool_heading", pool.label))
	rows[#rows + 1] = { n = G.UIT.R, config = { align = "cl", padding = 0.02 }, nodes = { TUI.text(deck_text(deck), TUI.SMALL, G.C.UI.TEXT_INACTIVE) } }
	local decks = {}
	for _, key in ipairs(deck.decks or {}) do
		decks[#decks + 1] = TUI.deck_name(key)
	end
	rows[#rows + 1] = sub_heading(PVP.T("k_tn_pool_decks", #decks))
	pool_grid(rows, decks, 3, 3.9)
	local cocktails = {}
	for _, c in ipairs(type(deck.cocktails) == "table" and deck.cocktails or {}) do
		local mix = {}
		for _, k in ipairs(c.decks or {}) do
			mix[#mix + 1] = (TUI.deck_name(k):gsub(" Deck$", ""))
		end
		cocktails[#cocktails + 1] = PVP.T("k_tn_pool_cocktail", c.name or PVP.T("k_tn_cocktail"), table.concat(mix, " + "))
	end
	if #cocktails > 0 then
		rows[#rows + 1] = sub_heading(PVP.T("k_tn_pool_cocktails", #cocktails))
		pool_grid(rows, cocktails, 2, 5.9)
	end
	local stakes = {}
	for _, n in ipairs(deck.stakes or {}) do
		stakes[#stakes + 1] = TUI.stake_name(n)
	end
	rows[#rows + 1] = sub_heading(PVP.T("k_tn_pool_stakes", #stakes))
	pool_grid(rows, stakes, 3, 3.9)
	rows[#rows + 1] = {
		n = G.UIT.R,
		config = { align = "cl", padding = 0.04 },
		nodes = { TUI.text(PVP.T("k_tn_pool_note"), 0.24, G.C.UI.TEXT_INACTIVE) },
	}
	rows[#rows + 1] = TUI.hbox({ TUI.button(PVP.T("k_tn_b_back"), "mp_pvp_tdetails_pool_close", nil, G.C.ORANGE, 2.2, 0.3) }, "cm", 0.06)
	return rows
end

-- MORE DETAILS: everything, grouped.
local function more_rows(view)
	local s = view.summary
	local TT = PVP.TournamentTime
	local rows = {}
	rows[#rows + 1] = heading(PVP.T("k_tn_heading_when"))
	rows[#rows + 1] = kv(PVP.T("k_tn_kv_starts"), PVP.T("k_tn_local_time_note", TT.format_local(s.startsAt)))
	rows[#rows + 1] = kv(PVP.T("k_tn_kv_check_in"), s.checkInAt and PVP.T("k_tn_check_in_from", TT.format_local(s.checkInAt)) or PVP.T("k_tn_check_in_none"))
	rows[#rows + 1] = kv(PVP.T("k_tn_kv_timetable"), view.timetable and (view.timetable.kind == "preset" and text_of(PRESETS, view.timetable.preset) or PVP.T("k_tn_custom")) or "?")
	sub_lines(rows, PVP.T("k_tn_rounds_own_timing"), view.timetable and view.timetable.rounds, TUI.timing_text, s.format)
	rows[#rows + 1] = heading(PVP.T("k_tn_heading_how"))
	rows[#rows + 1] = kv(PVP.T("k_tn_kv_format"), format_text(view))
	local seeding = text_of(SEEDING, view.seeding and view.seeding.kind)
	if view.seeding and view.seeding.kind == "rating" then
		seeding = PVP.T("k_tn_cocktail_mix", seeding, TUI.ruleset_name((view.seeding.board or ""):gsub("^ranked:", "")))
	end
	rows[#rows + 1] = kv(PVP.T("k_tn_kv_seeding"), seeding)
	local default_deck = view.rounds and view.rounds.defaults and view.rounds.defaults.deck
	rows[#rows + 1] = kv(PVP.T("k_tn_kv_decks"), deck_text(default_deck))
	-- VIEW POOL on its own line, under the text (beside it, a long rule ran into it).
	if is_pool(default_deck) then
		rows[#rows + 1] = { n = G.UIT.R, config = { align = "cl", padding = 0.01 }, nodes = { { n = G.UIT.C, config = { minw = 2.6 } }, pool_button(PVP.T("k_tn_every_round"), default_deck) } }
	end
	local overrides = view.rounds and view.rounds.overrides or {}
	sub_lines(rows, PVP.T("k_tn_rounds_differ"), overrides, override_text, s.format)
	-- Rounds with a pool of their own: a button each (up to 4 on the line).
	local line = { { n = G.UIT.C, config = { align = "cl", minw = 2.6 }, nodes = { TUI.text("  " .. PVP.T("k_tn_their_pools"), TUI.SMALL, G.C.UI.TEXT_INACTIVE) } } }
	for _, key in ipairs(TUI.sorted_round_keys(overrides)) do
		if is_pool(overrides[key].deck) and #line <= 4 then
			local label = TUI.round_key_label(s.format, key)
			line[#line + 1] = {
				n = G.UIT.C,
				config = { align = "cm", padding = 0.02 },
				nodes = { TUI.button(label, "mp_pvp_tdetails_pool", { label = label, deck = overrides[key].deck }, G.C.BLUE, 2.4, 0.28) },
			}
		end
	end
	if #line > 1 then
		rows[#rows + 1] = { n = G.UIT.R, config = { align = "cl", padding = 0.02 }, nodes = line }
	end
	rows[#rows + 1] = kv(PVP.T("k_tn_kv_organiser"), tostring(s.organiserName))
	return rows
end

-- The players: a paged grid (two columns of ten), seed numbers once seeded.
-- During check-in, players who haven't checked in yet are grey.
local PLAYER_ROWS, PLAYER_COLS = 10, 2

local function player_cell(e, status)
	if not e then
		return { n = G.UIT.C, config = { minw = 2.15, minh = 0.36 }, nodes = {} }
	end
	local faint = e.dropped or (status == "check_in" and not e.checkedIn)
	local name = tostring(e.name)
	if #name > 13 then
		name = name:sub(1, 12) .. "."
	end
	local nodes = {}
	nodes[#nodes + 1] = { n = G.UIT.C, config = { align = "cr", minw = 0.42 }, nodes = { TUI.text(e.seed and tostring(e.seed) or "", 0.26, G.C.UI.TEXT_INACTIVE) } }
	nodes[#nodes + 1] = TUI.spacer(0.1)
	nodes[#nodes + 1] = { n = G.UIT.C, config = { align = "cl" }, nodes = { TUI.text(name, TUI.SMALL, faint and G.C.UI.TEXT_INACTIVE or nil) } }
	return { n = G.UIT.C, config = { align = "cl", minw = 2.15, minh = 0.36 }, nodes = nodes }
end

local function players_panel()
	local view = details.view
	local s = view.summary
	local entrants = view.entrants or {}
	local per_page = PLAYER_ROWS * PLAYER_COLS
	local pages = math.max(1, math.ceil(#entrants / per_page))
	details.page = math.max(1, math.min(details.page or 1, pages))
	local first = (details.page - 1) * per_page
	local rows = {
		{
			n = G.UIT.R,
			config = { align = "cl", padding = 0.04 },
			nodes = {
				TUI.text(PVP.T("k_tn_players"), TUI.TEXT, G.C.GOLD),
				TUI.spacer(0.2),
				TUI.text(string.format("%d / %d", s.players or 0, s.maxPlayers or 0), TUI.SMALL, G.C.UI.TEXT_INACTIVE),
			},
		},
	}
	if #entrants == 0 then
		rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm", minh = PLAYER_ROWS * 0.36, minw = 4.3 }, nodes = { TUI.text(PVP.T("k_tn_nobody_yet"), TUI.SMALL, G.C.UI.TEXT_INACTIVE) } }
	else
		-- Down the first column, then the second.
		for r = 1, PLAYER_ROWS do
			local cells = {}
			for c = 1, PLAYER_COLS do
				cells[#cells + 1] = player_cell(entrants[first + (c - 1) * PLAYER_ROWS + r], s.status)
			end
			rows[#rows + 1] = { n = G.UIT.R, config = { align = "cl" }, nodes = cells }
		end
	end
	if pages > 1 then
		rows[#rows + 1] = TUI.hbox({
			TUI.button("<", "mp_pvp_tdetails_page", { delta = -1 }, details.page > 1 and G.C.RED or G.C.UI.BACKGROUND_INACTIVE, 0.6, 0.3),
			TUI.text(details.page .. " / " .. pages, TUI.SMALL),
			TUI.button(">", "mp_pvp_tdetails_page", { delta = 1 }, details.page < pages and G.C.RED or G.C.UI.BACKGROUND_INACTIVE, 0.6, 0.3),
		}, "cm", 0.06)
	end
	return {
		n = G.UIT.C,
		config = { align = "tm", padding = 0.1, r = 0.1, colour = mix_colours(G.C.BLACK, G.C.L_BLACK, 0.45) },
		nodes = rows,
	}
end

G.FUNCS.mp_pvp_tdetails_page = function(e)
	local delta = e.config.ref_table and e.config.ref_table.delta
	if delta and details.el then
		details.page = (details.page or 1) + delta
		details.el:update()
	end
end

local function build_details()
	local view = details.view
	local s = view.summary
	local title = { TUI.name_line(s, 0.55, true) }
	title[#title + 1] = { n = G.UIT.R, config = { align = "cl" }, nodes = { TUI.text(PVP.T("k_tn_by", tostring(s.organiserName)), TUI.SMALL, G.C.UI.TEXT_INACTIVE) } }
	-- Ranked profile required: and whether this player is on theirs.
	title[#title + 1] = TUI.ranked_lines(s, view.rankedProfile, "cl")
	local left = {
		{ n = G.UIT.R, config = { align = "cm" }, nodes = { starts_card(view), format_card(view), game_card(view), decks_card(view) } },
	}
	if next(view.rounds and view.rounds.overrides or {}) ~= nil then
		left[#left + 1] = { n = G.UIT.R, config = { align = "cr" }, nodes = { TUI.text(PVP.T("k_tn_some_rounds_differ"), 0.24, G.C.UI.TEXT_INACTIVE) } }
	end
	if view.description and view.description ~= "" then
		local desc = {}
		-- The organiser's lines, each wrapped; an empty line is a gap.
		local lines = {}
		for part in (view.description .. "\n"):gmatch("([^\n]*)\n") do
			local wrapped = wrap(part, 70)
			if #wrapped == 0 then
				lines[#lines + 1] = " "
			end
			for _, w in ipairs(wrapped) do
				lines[#lines + 1] = w
			end
		end
		for _, line in ipairs(lines) do
			-- Plain text, no drop shadow: easier to read in a paragraph.
			desc[#desc + 1] = { n = G.UIT.R, config = { align = "cl" }, nodes = { { n = G.UIT.T, config = { text = line, scale = TUI.SMALL, colour = G.C.UI.TEXT_LIGHT } } } }
		end
		left[#left + 1] = { n = G.UIT.R, config = { align = "cl", padding = 0.1 }, nodes = { { n = G.UIT.C, config = { align = "cl" }, nodes = desc } } }
	end
	left[#left + 1] = TUI.hbox({
		TUI.button(PVP.T("k_tn_b_bracket"), "mp_pvp_tournament_bracket", { id = s.id }, G.C.BLUE, 2.6),
		TUI.button(PVP.T(details.more and "k_tn_b_less" or "k_tn_b_more_details"), "mp_pvp_tournament_more", nil, G.C.UI.BACKGROUND_INACTIVE, 2.8),
	}, "cm", 0.06)
	if details.more then
		left[#left + 1] = {
			n = G.UIT.R,
			config = { align = "cl", padding = 0.1, r = 0.1, colour = mix_colours(G.C.BLACK, G.C.L_BLACK, 0.45) },
			nodes = { { n = G.UIT.C, config = { align = "cl", minw = 12.2 }, nodes = details.pool and pool_rows(details.pool) or more_rows(view) } },
		}
	end
	return {
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "tm" },
				nodes = {
					{ n = G.UIT.R, config = { align = "cl", padding = 0.04 }, nodes = { { n = G.UIT.C, config = { align = "cl" }, nodes = title } } },
					{
						n = G.UIT.R,
						config = { align = "tm", padding = 0.06 },
						nodes = {
							{ n = G.UIT.C, config = { align = "tm" }, nodes = left },
							{ n = G.UIT.C, config = { align = "tm", padding = 0.06 }, nodes = { players_panel() } },
						},
					},
				},
			},
		},
	}
end

local function details_contents(view, more)
	details.view = view
	details.more = more or false
	details.pool = nil
	details.page = 1
	details.el = MPAPI.ui_element(build_details)
	return { details.el.node }
end

G.FUNCS.mp_pvp_tdetails_pool = function(e)
	local ref = e.config.ref_table
	if not (ref and ref.deck) then
		return
	end
	details.pool = { label = ref.label, deck = ref.deck }
	if details.el then
		details.el:update()
	end
end

G.FUNCS.mp_pvp_tdetails_pool_close = function()
	details.pool = nil
	if details.el then
		details.el:update()
	end
end

G.FUNCS.mp_pvp_tournament_more = function()
	details.pool = nil
	details.more = not details.more
	if details.el then
		details.el:update()
	end
end

-- instant: in place, without sliding up from the bottom (coming back from
-- the bracket, where the slide made the pane jump in a second time).
local function open_overlay(contents, instant)
	G.FUNCS.overlay_menu({
		config = instant and { offset = { x = 0, y = 0 } } or nil,
		definition = create_UIBox_generic_options({
			back_func = "mp_pvp_tournament_overlay_back",
			contents = { { n = G.UIT.R, config = { align = "cm", padding = 0.15 }, nodes = { { n = G.UIT.C, config = { align = "cm" }, nodes = contents } } } },
		}),
	})
end

G.FUNCS.mp_pvp_tournament_overlay_back = function(e)
	close_lists()
	G.FUNCS.exit_overlay_menu(e)
end

local function with_view(id, fn)
	local cached = PVP.Tournaments.state.views[id]
	PVP.Tournaments.get({ id = id }, function(err, data)
		if not err and data and data.tournament then
			PVP.Tournaments.state.views[id] = data.tournament
			fn(data.tournament)
		elseif cached then
			fn(cached)
		elseif err then
			PVP.Tournaments.state.error = err
			PVP.Tournaments._changed()
		end
	end)
end

-- restore: reopened from the bracket, with MORE DETAILS as it was.
function PVP.open_tournament_details(id, restore)
	local more = restore and details.return_more or false
	local cached = restore and PVP.Tournaments.state.views[id]
	if cached then
		-- Back from the bracket: show what we have at once, in place, and
		-- update it in place when the server answers.
		close_lists()
		open_overlay(details_contents(cached, more), true)
		PVP.Tournaments.get({ id = id }, function(err, data)
			if err or not (data and data.tournament) then
				return
			end
			PVP.Tournaments.state.views[id] = data.tournament
			local shown = details.view and details.view.summary
			if G.OVERLAY_MENU and details.el and shown and shown.id == id then
				details.view = data.tournament
				details.el:update()
			end
		end)
		return
	end
	with_view(id, function(view)
		close_lists()
		open_overlay(details_contents(view, more))
	end)
end

G.FUNCS.mp_pvp_tournament_details = function(e)
	local id = e.config.ref_table and e.config.ref_table.id
	if id then
		PVP.open_tournament_details(id)
	end
end

-- The bracket viewer is its own page (ui/tournament/bracket_page.lua).
G.FUNCS.mp_pvp_tournament_bracket = function(e)
	local id = e.config.ref_table and e.config.ref_table.id
	if not id then
		return
	end
	close_lists()
	-- From DETAILS: the bracket's BACK reopens it.
	local from_details = G.OVERLAY_MENU ~= nil
	details.return_more = from_details and details.more or false
	if G.OVERLAY_MENU then
		G.FUNCS.exit_overlay_menu(e)
	end
	PVP.open_tournament_bracket(id, { back_to_details = from_details })
end
