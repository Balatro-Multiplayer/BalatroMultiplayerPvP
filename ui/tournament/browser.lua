-- The tournament browser (page pvp_tournament_browse): every public upcoming
-- tournament, searchable by name or organiser and filtered by format, game
-- type, official, open spots and "starts today", in a scrollable list.
-- Official tournaments come first (the server sorts them). Each row has
-- DETAILS (ui/tournament/details.lua) and JOIN / WAITLIST / JOINED / CLOSED.
-- JOIN WITH CODE joins a private tournament by its invite code.

PVP.TUI = PVP.TUI or {}
local TUI = PVP.TUI

local VISIBLE_ROWS = 4
local DAY_MS = 24 * 60 * 60 * 1000

local FORMATS = { "single_elim", "double_elim", "round_robin", "swiss" }

local browser = {
	-- Filters: nil = all.
	format = nil,
	ruleset = nil,
	official = false,
	open_spots = false,
	today = false,
	search = { text = "" },
	last_search = "",
	list = nil,
	filters = nil,
	active = false,
	unlisten = nil,
}

local function joined(id)
	for _, t in ipairs(PVP.Tournaments.state.mine or {}) do
		if t.id == id and (t.role == "entrant" or t.role == "waitlist") then
			return true
		end
	end
	return false
end

local function matches(t)
	if browser.format and t.format ~= browser.format then
		return false
	end
	if browser.ruleset and t.ruleset ~= browser.ruleset then
		return false
	end
	if browser.official and not t.official then
		return false
	end
	if browser.open_spots and (not t.registrationOpen or (t.players or 0) >= (t.maxPlayers or 0)) then
		return false
	end
	if browser.today and (t.startsAt or 0) - PVP.TournamentTime.now_ms() > DAY_MS then
		return false
	end
	local q = (browser.search.text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if q ~= "" then
		local hay = ((t.name or "") .. " " .. (t.organiserName or "")):lower()
		if not hay:find(q, 1, true) then
			return false
		end
	end
	return true
end

local function shown()
	local out = {}
	for _, t in ipairs(PVP.Tournaments.state.browse or {}) do
		if matches(t) then
			out[#out + 1] = t
		end
	end
	return out
end

-- The rulesets present in the list (plus any picked one), for the chips.
local function rulesets()
	local seen, out = {}, {}
	for _, t in ipairs(PVP.Tournaments.state.browse or {}) do
		if t.ruleset and not seen[t.ruleset] then
			seen[t.ruleset] = true
			out[#out + 1] = t.ruleset
		end
	end
	if browser.ruleset and not seen[browser.ruleset] then
		out[#out + 1] = browser.ruleset
	end
	table.sort(out)
	return out
end

local function build_row(t)
	local state = PVP.Tournaments.state
	local buttons = { TUI.button(PVP.T("k_tn_b_details"), "mp_pvp_tournament_details", { id = t.id }, G.C.UI.BACKGROUND_INACTIVE, 1.6) }
	if state.busy[t.id] then
		buttons[#buttons + 1] = TUI.text(state.busy[t.id] .. "...", TUI.SMALL, G.C.UI.TEXT_INACTIVE)
	elseif joined(t.id) then
		buttons[#buttons + 1] = TUI.button(PVP.T("k_tn_b_joined"), "mp_pvp_tournament_open", { id = t.id }, G.C.GREEN, 1.6)
	elseif t.registrationOpen then
		local full = (t.players or 0) >= (t.maxPlayers or 0)
		buttons[#buttons + 1] = TUI.button(PVP.T(full and "k_tn_b_waitlist" or "k_tn_b_join"), "mp_pvp_tournament_join", { id = t.id }, full and G.C.ORANGE or G.C.BLUE, 1.6)
	else
		buttons[#buttons + 1] = TUI.text(PVP.T("k_tn_closed"), TUI.SMALL, G.C.UI.TEXT_INACTIVE)
	end
	return TUI.row({
		TUI.name_line(t, 0.36),
		TUI.line({ TUI.text(PVP.T("k_tn_meta_by", TUI.meta_line(t), tostring(t.organiserName)), TUI.SMALL, G.C.UI.TEXT_INACTIVE) }),
		TUI.line({ TUI.text(PVP.T("k_tn_status_starts", PVP.TournamentTime.describe(t.startsAt)), TUI.SMALL) }),
	}, buttons, TUI.WIDTH - 0.6, t.official)
end

local function chip(label, on, button, ref)
	return {
		n = G.UIT.C,
		config = {
			align = "cm",
			padding = 0.06,
			r = 0.08,
			minh = 0.4,
			colour = on and G.C.BLUE or G.C.UI.BACKGROUND_INACTIVE,
			hover = true,
			shadow = on,
			button = button,
			ref_table = ref,
		},
		nodes = { TUI.text(label, 0.28, on and G.C.UI.TEXT_LIGHT or G.C.UI.TEXT_INACTIVE) },
	}
end

local function chip_row(chips)
	local nodes = {}
	for i, c in ipairs(chips) do
		if i > 1 then
			nodes[#nodes + 1] = TUI.spacer(0.06)
		end
		nodes[#nodes + 1] = c
	end
	return { n = G.UIT.R, config = { align = "cm", padding = 0.04 }, nodes = nodes }
end

local function build_filters()
	local formats = { chip(PVP.T("k_tn_all_formats"), browser.format == nil, "mp_pvp_tbrowse_format", { value = false }) }
	for _, f in ipairs(FORMATS) do
		formats[#formats + 1] = chip(TUI.format_name(f):upper(), browser.format == f, "mp_pvp_tbrowse_format", { value = f })
	end
	local types = { chip(PVP.T("k_tn_all_rulesets"), browser.ruleset == nil, "mp_pvp_tbrowse_ruleset", { value = false }) }
	for _, key in ipairs(rulesets()) do
		types[#types + 1] = chip(TUI.ruleset_name(key):upper(), browser.ruleset == key, "mp_pvp_tbrowse_ruleset", { value = key })
	end
	-- The on/off filters on a row of their own (beside the rulesets, the
	-- gap between the two groups read as uneven spacing).
	local toggles = {
		chip(PVP.T("k_tn_official_badge"), browser.official, "mp_pvp_tbrowse_toggle", { key = "official" }),
		chip(PVP.T("k_tn_open_spots"), browser.open_spots, "mp_pvp_tbrowse_toggle", { key = "open_spots" }),
		chip(PVP.T("k_tn_today"), browser.today, "mp_pvp_tbrowse_toggle", { key = "today" }),
	}
	-- REFRESH, set apart on the right of the on/off filters. Greyed out
	-- while a refresh is under way.
	local loading = PVP.Tournaments.state.loading
	toggles[#toggles + 1] = TUI.spacer(0.25)
	toggles[#toggles + 1] = {
		n = G.UIT.C,
		config = {
			align = "cm",
			padding = 0.06,
			r = 0.08,
			minh = 0.4,
			minw = 1.5,
			colour = loading and G.C.UI.BACKGROUND_INACTIVE or G.C.GREEN,
			hover = not loading,
			shadow = not loading,
			button = not loading and "mp_pvp_tbrowse_refresh" or nil,
		},
		nodes = { TUI.text(PVP.T(loading and "k_tn_refreshing" or "k_tn_b_refresh"), 0.28, loading and G.C.UI.TEXT_INACTIVE or G.C.UI.TEXT_LIGHT) },
	}
	local count = #shown()
	local total = #(PVP.Tournaments.state.browse or {})
	return {
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cm" },
				nodes = {
					chip_row(formats),
					chip_row(types),
					chip_row(toggles),
					TUI.message(PVP.T("k_tn_browse_count", count, total)),
				},
			},
		},
	}
end

local function redraw()
	if browser.filters then
		browser.filters:update()
	end
	if browser.list then
		browser.list:update()
	end
end

local function empty_text()
	local state = PVP.Tournaments.state
	if state.error and not state.browse then
		return state.error
	end
	if not state.browse then
		return PVP.T("k_tn_loading")
	end
	return PVP.T(#state.browse == 0 and "k_tn_browse_none" or "k_tn_browse_no_match")
end

local function build_page()
	browser.search.text = browser.search.text or ""
	browser.filters = MPAPI.ui_element(build_filters)
	if browser.list then
		browser.list:dispose()
	end
	browser.list = TUI.scroll_list({
		items = shown,
		build_row = build_row,
		visible = VISIBLE_ROWS,
		row_h = 1.0,
		width = TUI.WIDTH - 0.6,
		empty = empty_text,
	})
	local top = {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.06 },
		nodes = {
			{ n = G.UIT.C, config = { align = "cm", padding = 0.05 }, nodes = { TUI.button(PVP.T("k_tn_b_back"), "mp_pvp_tournaments_back", nil, G.C.ORANGE, 1.6) } },
			{ n = G.UIT.C, config = { align = "cm", padding = 0.05 }, nodes = { TUI.text(PVP.T("k_tn_browse_title"), 0.45, G.C.BLUE) } },
			{
				n = G.UIT.C,
				config = { align = "cm", padding = 0.05 },
				nodes = {
					create_text_input({
						id = "mp_pvp_tbrowse_search",
						ref_table = browser.search,
						ref_value = "text",
						prompt_text = PVP.T("k_tn_search_prompt"),
						max_length = 24,
						w = 4.6,
						h = 0.5,
						text_scale = 0.32,
					}),
				},
			},
			{ n = G.UIT.C, config = { align = "cm", padding = 0.05 }, nodes = { TUI.button(PVP.T("k_tn_join_with_code"), "mp_pvp_tournament_join_code", nil, G.C.PURPLE, 2.5) } },
		},
	}
	local body = TUI.panel({
		top,
		{ n = G.UIT.R, config = { align = "cm" }, nodes = { browser.filters.node } },
		{ n = G.UIT.R, config = { align = "cm", padding = 0.04 }, nodes = { browser.list.node } },
	}, { minw = TUI.WIDTH })
	return { n = G.UIT.ROOT, config = { align = "tm", colour = G.C.CLEAR }, nodes = { { n = G.UIT.R, config = { align = "tm", padding = 0.1 }, nodes = { body } } } }
end

-- Re-filters when the search text changes (the text input has no change hook).
local function watch_search()
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = 0.25,
		blockable = false,
		blocking = false,
		timer = "REAL",
		func = function()
			if not browser.active then
				return true
			end
			if browser.search.text ~= browser.last_search then
				browser.last_search = browser.search.text
				if browser.list then
					browser.list.offset = 0
				end
				redraw()
			end
			watch_search()
			return true
		end,
	}))
end

MPAPI.on_loaded(function()
	MPAPI.Page({
		key = "pvp_tournament_browse",
		category = "game_select",
		build = function(self)
			return build_page()
		end,
		on_enter = function(self)
			TUI.page_enter()
			browser.active = true
			browser.unlisten = PVP.Tournaments.on_change(redraw)
			PVP.Tournaments.refresh()
			watch_search()
		end,
		dispose = function(self)
			browser.active = false
			if browser.unlisten then
				browser.unlisten()
				browser.unlisten = nil
			end
			if browser.list then
				browser.list:dispose()
				browser.list = nil
			end
			browser.filters = nil
		end,
	})
end)

G.FUNCS.mp_pvp_tournaments_back = function()
	MPAPI.pages.show("pvp_find_game", { category = "tournaments" })
end

G.FUNCS.mp_pvp_tbrowse_format = function(e)
	local v = e.config.ref_table.value
	browser.format = v or nil
	if browser.list then
		browser.list.offset = 0
	end
	redraw()
end

G.FUNCS.mp_pvp_tbrowse_ruleset = function(e)
	local v = e.config.ref_table.value
	browser.ruleset = v or nil
	if browser.list then
		browser.list.offset = 0
	end
	redraw()
end

G.FUNCS.mp_pvp_tbrowse_toggle = function(e)
	local key = e.config.ref_table.key
	browser[key] = not browser[key]
	if browser.list then
		browser.list.offset = 0
	end
	redraw()
end

G.FUNCS.mp_pvp_tbrowse_refresh = function()
	PVP.Tournaments.refresh()
	redraw()
end

-- Join a private tournament by its invite code. The code table is captured
-- directly (see ui/pvp_main_menu.lua's join overlay for why).
local code_ref = { text = "" }
G.FUNCS.mp_pvp_tournament_join_code = function()
	code_ref.text = ""
	G.FUNCS.overlay_menu({
		definition = create_UIBox_generic_options({
			snap_back = true,
			contents = {
				{
					n = G.UIT.R,
					config = { align = "cm", padding = 0.2 },
					nodes = {
						TUI.title(PVP.T("k_tn_join_with_code"), G.C.PURPLE),
						{
							n = G.UIT.R,
							config = { align = "cm", padding = 0.1 },
							nodes = { create_text_input({ id = "mp_pvp_tournament_code_input", ref_table = code_ref, ref_value = "text", prompt_text = PVP.T("k_tn_invite_code_prompt"), max_length = 6, all_caps = true, w = 4, h = 0.6 }) },
						},
						{ n = G.UIT.R, config = { align = "cm", padding = 0.1 }, nodes = { TUI.button(PVP.T("k_tn_b_join"), "mp_pvp_tournament_join_code_confirm", nil, G.C.GREEN, 2.0, 0.42) } },
					},
				},
			},
		}),
	})
end

G.FUNCS.mp_pvp_tournament_join_code_confirm = function()
	local code = (code_ref.text or ""):gsub("%s", ""):upper()
	if #code == 0 then
		return
	end
	G.FUNCS.exit_overlay_menu()
	PVP.Tournaments.join_code(code, function(err, data)
		if not err and data and data.tournament and data.tournament.summary then
			PVP.open_tournament(data.tournament.summary.id)
		end
	end)
end
