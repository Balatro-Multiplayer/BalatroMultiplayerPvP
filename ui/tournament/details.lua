-- Overlays for one tournament: DETAILS (everything about how it is run, and
-- who is in it) and BRACKET (a plain scrollable list of every match with its
-- score, or the standings for round robin and Swiss -- until the zoomable
-- bracket viewer replaces it). Both load the tournament's full view first.

PVP.TUI = PVP.TUI or {}
local TUI = PVP.TUI

local PRESETS = { live_event = "Live event", live_fixed_rounds = "Live, fixed round times", league = "League (play by a deadline)" }
local SEEDING = { rating = "By ranked rating", random = "Random", manual = "Set by the organiser" }
local STAGES = { W = "Winners", L = "Losers", GF = "Grand final", RR = "Round", SW = "Round" }

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
		text = text .. (o.grandFinalReset == false and ", no grand-final reset" or ", grand-final reset")
	elseif s.format == "swiss" and o.swissRounds then
		text = text .. ", " .. o.swissRounds .. " rounds"
	elseif s.format == "round_robin" and o.groupSize then
		text = text .. ", groups of " .. o.groupSize
	end
	return text
end

local function deck_text(deck)
	if not deck then
		return "Players' choice"
	end
	if deck.kind == "locked" then
		return string.format("%s, stake %d", tostring(deck.deck), deck.stake or 1)
	end
	local orders = { lower_seed_first = "lower seed bans first", lower_seed_last = "lower seed bans last", random = "random ban order", previous_loser_first = "previous game's loser bans first" }
	return string.format("Ban/pick from %d decks, %d stakes (%s)", #(deck.decks or {}), #(deck.stakes or {}), orders[deck.banOrder] or tostring(deck.banOrder))
end

local function details_contents(view)
	local s = view.summary
	local TT = PVP.TournamentTime
	local d = view.rounds and view.rounds.defaults or {}
	local overrides = 0
	for _ in pairs(view.rounds and view.rounds.overrides or {}) do
		overrides = overrides + 1
	end
	local info = {
		kv("Organiser", tostring(s.organiserName)),
		kv("Format", format_text(view)),
		kv("Players", string.format("%d / %d%s", s.players or 0, s.maxPlayers or 0, (s.waitlist or 0) > 0 and ("  (+" .. s.waitlist .. " waiting)") or "")),
		kv("Starts", TT.format_local(s.startsAt) .. "  (" .. TT.describe(s.startsAt) .. ")"),
		kv("Check-in", s.checkInAt and (TT.format_local(s.checkInAt) .. " until the start") or "None"),
		kv("Timetable", view.timetable and (view.timetable.kind == "preset" and (PRESETS[view.timetable.preset] or view.timetable.preset) or "Custom") or "?"),
		kv("Seeding", (SEEDING[view.seeding and view.seeding.kind] or "?") .. (view.seeding and view.seeding.kind == "rating" and ("  (" .. TUI.ruleset_name((view.seeding.board or ""):gsub("^ranked:", "")) .. ")") or "")),
		kv("Game type", TUI.game_type(d.gameMode) .. "  -  " .. TUI.ruleset_name(d.ruleset)),
		kv("Series", "Best of " .. tostring(d.bestOf or 1) .. (overrides > 0 and ("  (" .. overrides .. " round(s) differ)") or "")),
		kv("Deck", deck_text(d.deck)),
	}
	if s.official then
		table.insert(info, 1, { n = G.UIT.R, config = { align = "cl", padding = 0.04 }, nodes = { TUI.official_badge() } })
	end
	if view.description and view.description ~= "" then
		info[#info + 1] = { n = G.UIT.R, config = { align = "cl", padding = 0.06 }, nodes = { TUI.text(view.description, TUI.SMALL, G.C.UI.TEXT_LIGHT) } }
	end
	local entrants = TUI.scroll_list({
		items = function()
			return view.entrants or {}
		end,
		build_row = function(e)
			local tags = {}
			if e.seed then
				tags[#tags + 1] = "seed " .. e.seed
			end
			if e.checkedIn then
				tags[#tags + 1] = "checked in"
			end
			if e.dropped then
				tags[#tags + 1] = "dropped"
			end
			return {
				n = G.UIT.R,
				config = { align = "cl", minw = 4.2 },
				nodes = { TUI.text(e.name .. (#tags > 0 and ("  (" .. table.concat(tags, ", ") .. ")") or ""), TUI.SMALL) },
			}
		end,
		visible = 9,
		row_h = 0.38,
		width = 4.2,
		empty = "Nobody yet.",
	})
	overlay_lists[#overlay_lists + 1] = entrants
	return {
		TUI.name_line(s, 0.5),
		{
			n = G.UIT.R,
			config = { align = "tm", padding = 0.1 },
			nodes = {
				{ n = G.UIT.C, config = { align = "tl", padding = 0.06, minw = 7.4 }, nodes = info },
				{ n = G.UIT.C, config = { align = "tl", padding = 0.06 }, nodes = { TUI.text("PLAYERS", TUI.TEXT, G.C.GOLD), entrants.node } },
			},
		},
	}
end

local function player_name(p)
	if p == "tbd" then
		return "TBD"
	end
	if p == nil or p == false or type(p) ~= "table" then
		return "bye"
	end
	return p.name
end

-- One text line per match ("Winners 2 - 1   Alice  2-1  Bob   done"), or the
-- standings.
local function bracket_lines(view)
	local lines = {}
	if not view.bracket then
		lines[1] = { text = "The bracket is drawn when the tournament starts.", colour = G.C.UI.TEXT_INACTIVE }
		return lines
	end
	if view.standings then
		for g, table_rows in ipairs(view.standings) do
			if #view.standings > 1 then
				lines[#lines + 1] = { text = "Group " .. g, colour = G.C.GOLD }
			end
			for _, r in ipairs(table_rows) do
				local name = "?"
				for _, e in ipairs(view.entrants or {}) do
					if e.id == r.id then
						name = e.name
					end
				end
				lines[#lines + 1] = { text = string.format("%2d.  %-18s %g pts   %d-%d-%d", r.rank, name, r.points, r.matchWins, r.draws, r.losses) }
			end
		end
		lines[#lines + 1] = { text = "", colour = G.C.CLEAR }
	end
	local me = PVP.Tournaments.me_in(view)
	local last_round
	for _, m in ipairs(view.bracket) do
		local round = (STAGES[m.stage] or m.stage) .. " " .. m.round
		if round ~= last_round then
			lines[#lines + 1] = { text = round, colour = G.C.GOLD }
			last_round = round
		end
		local a, b = player_name(m.players[1]), player_name(m.players[2])
		local score = (m.status == "done" or m.status == "in_progress") and string.format("%d-%d", m.wins[1] or 0, m.wins[2] or 0) or "vs"
		local state = m.status == "done" and "" or m.status == "in_progress" and "playing" or m.status == "ready" and "open" or ""
		local mine = me and ((type(m.players[1]) == "table" and m.players[1].id == me.id) or (type(m.players[2]) == "table" and m.players[2].id == me.id))
		if not (a == "bye" and b == "bye") then
			lines[#lines + 1] = { text = string.format("   %s  %s  %s   %s", a, score, b, state), colour = mine and G.C.GREEN or nil }
		end
	end
	return lines
end

local function open_overlay(contents)
	G.FUNCS.overlay_menu({
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

G.FUNCS.mp_pvp_tournament_details = function(e)
	local id = e.config.ref_table and e.config.ref_table.id
	if id then
		with_view(id, function(view)
			close_lists()
			open_overlay(details_contents(view))
		end)
	end
end

G.FUNCS.mp_pvp_tournament_bracket = function(e)
	local id = e.config.ref_table and e.config.ref_table.id
	if not id then
		return
	end
	with_view(id, function(view)
		close_lists()
		local lines = bracket_lines(view)
		local list = TUI.scroll_list({
			items = function()
				return lines
			end,
			build_row = function(l)
				return { n = G.UIT.R, config = { align = "cl", minw = 9.5 }, nodes = { TUI.text(l.text, TUI.SMALL, l.colour) } }
			end,
			visible = 12,
			row_h = 0.38,
			width = 9.5,
		})
		overlay_lists[#overlay_lists + 1] = list
		open_overlay({ TUI.name_line(view.summary, 0.5), TUI.title("BRACKET", G.C.BLUE, 0.4), list.node })
	end)
end
