-- Run from the repo root: luajit tests/unit/run_test.lua
-- The run: the reader's bodies and the opponent's run, then every run input the screen sends and what it shows.
local T = dofile("tests/support/check.lua")
local eq, same, show = T.eq, T.same, T.show

-- The run-side bodies and the opponent's run read from the view. Plain values only.
do
	T.fresh()
	PVP = { NET = {}, READ = {}, UI = {} }
	dofile("pvp_api/read/_view.lua")
	dofile("pvp_api/read/run.lua")
	local reader = PVP.READ.run

	-- Bodies, with the server's field names.
	same(reader.blind_result(2, "Big", "beaten"), { blindKey = "2:Big", result = "beaten" }, "blind result: beaten")
	same(reader.blind_result(2, "Boss", "failed on the clock"), { blindKey = "2:Boss", result = "failed on the clock" }, "blind result: failed on the clock")
	eq(reader.blind_result(2, "Nemesis", "beaten"), nil, "blind result: not a blind")
	eq(reader.blind_result(2, "Big", nil), nil, "blind result: result unknown")
	eq(reader.skip(2, "Big", 0), nil, "skip: total starts at 1")
	same(reader.shop(2, 1, 7.9), { ante = 2, total = 1, spent = 7 }, "shop: whole dollars")
	same(reader.shop(2, 1, 1e9), { ante = 2, total = 1, spent = 1000000 }, "shop: capped")
	eq(reader.voucher(""), nil, "voucher: no key")

	-- Shape only: the server owns the limits.
	eq(reader.progress(-1, "Shop"), nil, "ante: not negative")
	eq(reader.progress(2.5, "Shop"), nil, "ante: whole")
	eq(reader.progress(0, "Shop").ante, 0, "ante 0 is valid")
	eq(reader.progress(3, ""), nil, "location: not empty")
	eq(reader.progress(3, 7), nil, "location: text")
	eq(reader.blind_result(2, "Big", "skipped"), nil, "blind result: a skip has its own input")
	eq(reader.blind_result(2, "Big", true), nil, "blind result: a flag is no result")
	eq(reader.blind_result(2, "Big", "won"), nil, "blind result: only the named results")
	eq(reader.skip(2, "Small", 1.5), nil, "skip total whole")
	eq(reader.skip(2, "Small", -1), nil, "skip total not negative")
	eq(reader.sell(2, 0), nil, "sell: total starts at 1")
	eq(reader.sell(2, 1.5), nil, "sell: total whole")
	eq(reader.sell(2, -1), nil, "sell: total not negative")
	eq(reader.sell(-1, 1), nil, "sell: ante not negative")
	eq(reader.shop(2, 0, 1), nil, "shop: total starts at 1")
	eq(reader.shop(2, 1.5, 1), nil, "shop: total whole")
	eq(reader.shop(2, 1, "7"), nil, "shop: spend is a number")
	eq(reader.shop(2, 1, 1000000).spent, 1000000, "shop: spend at the cap")
	eq(reader.voucher(5), nil, "voucher key is text")
	eq(reader.effect("pizza", 0), nil, "effect: total starts at 1")
	eq(reader.effect("pizza", 1.5), nil, "effect: total whole")

	-- The opponent's run from the view.
	local function view(player)
		return { match = { run = { targets = { opponents = { "b" } }, players = { a = { lives = 4 }, b = player } } } }
	end

	eq(reader.opponent_facts(nil), nil, "no view")
	eq(reader.opponent_facts({ match = { run = { targets = { opponents = {} }, players = {} } } }), nil, "no opponent")
	local facts = reader.opponent_facts(view({
		lives = 3, ante = 4, location = "Shop", skips = 2, sells = { ["2"] = 1, ["3"] = 2 }, shopSpends = { 5, 0 },
	}))
	eq(facts.lives, 3, "lives")
	eq(facts.ante, 4, "ante")
	eq(facts.location, "Shop", "location")
	eq(facts.skips, 2, "skips")
	eq(facts.sells[2], 1, "sells: ante turned into a number")
	eq(facts.sells[3], 2, "sells: ante 3")
	eq(facts.shop_spends[2], 0, "shop spends: second shop")

	local bare = reader.opponent_facts(view({ lives = 3 }))
	eq(bare.lives, 3, "bare: lives known")
	for _, name in ipairs({ "ante", "location", "skips", "sells", "shop_spends" }) do
		eq(bare[name], nil, "bare: " .. name .. " unknown, not defaulted")
	end

	eq(reader.opponent_facts(view({ ante = 1 })).lives, nil, "lives unknown, not defaulted")

	-- A shop without a total is a hole in the list.
	local holes = { [1] = 4, [3] = 6 }
	local gap = reader.opponent_facts(view({ shopSpends = holes }))
	eq(gap.shop_spends[1], 4, "hole: first shop")
	eq(gap.shop_spends[2], nil, "hole: unknown shop stays unknown")
	eq(gap.shop_spends[3], 6, "hole: third shop")

	-- What the view cannot say as a number or text is unknown.
	local odd = reader.opponent_facts(view({ sells = { x = 1, ["2"] = "many", ["3"] = 4 }, shopSpends = { x = 9, 7 }, location = 5 }))
	same(odd.sells, { [3] = 4 }, "sells: an ante that is not a number or a count that is not a number is left out")
	same(odd.shop_spends, { 7 }, "shop spends: a place that is not a number is left out")
	eq(odd.location, nil, "location: not text is unknown")

	-- Once only.
	eq(#reader.changed(nil, facts), #reader.FACTS, "first view: every fact is shown")
	same(reader.changed(facts, reader.opponent_facts(view({
		lives = 3, ante = 4, location = "Shop", skips = 2, sells = { ["2"] = 1, ["3"] = 2 }, shopSpends = { 5, 0 },
	}))), {}, "the same view again shows nothing")
	local later = reader.opponent_facts(view({
		lives = 2, ante = 4, location = "Shop", skips = 2, sells = { ["2"] = 1, ["3"] = 3 }, shopSpends = { 5, 0 },
	}))
	same(reader.changed(facts, later), { "lives", "sells" }, "only what changed is shown")
	same(reader.changed(facts, nil), reader.FACTS, "a view that lost the opponent clears every fact")

	-- A fact that only gains or loses a key is a change.
	local function one(fields) return reader.opponent_facts(view(fields)) end
	same(reader.changed(one({ sells = { ["2"] = 1 } }), one({ sells = { ["2"] = 1, ["4"] = 1 } })), { "sells" }, "sells gain an ante")
	same(reader.changed(one({ sells = { ["2"] = 1, ["4"] = 1 } }), one({ sells = { ["2"] = 1 } })), { "sells" }, "sells lose an ante")
	same(reader.changed(one({ shopSpends = { 5 } }), one({ shopSpends = { 5, 0 } })), { "shop_spends" }, "shop spends gain a shop")
	same(reader.changed(one({ shopSpends = { 5, 0 } }), one({ shopSpends = { 5 } })), { "shop_spends" }, "shop spends lose a shop")
	same(reader.changed(one({ sells = { ["2"] = 1 } }), one({ sells = { ["2"] = 1 } })), {}, "equal sells are no change")

	-- A skip is a known count going up: never from nothing known, never equal, down or not a number.
	for _, row in ipairs({
		{ 0, 1, true }, { 2, 5, true }, { 3, 3, false }, { 3, 2, false },
		{ nil, 1, false }, { 1, nil, false }, { nil, nil, false }, { "1", 2, false }, { 1, "2", false },
	}) do
		eq(reader.skips_gained(row[1], row[2]), row[3], "skips_gained " .. tostring(row[1]) .. " -> " .. tostring(row[2]))
	end

	-- opponent_shown: what to show of the opponent's run this frame
	local function table_view(opponents, players, statuses)
		return { me = "me", players = statuses or {}, match = { run = { targets = { opponents = opponents }, players = players } } }
	end
	local nothing = { facts = nil, id = nil, lives_guess = "none" }
	local shown_cases = {
		{
			name = "the first view shows every fact, even unknown ones",
			before = nothing, table_is = "new", view = table_view({ "a" }, { a = { lives = 3, ante = 2 } }),
			lives_from = "opponent", reset = "keep", names = { "lives", "ante", "location", "skips", "sells", "shop_spends" },
			next_id = "a", next_guess = "none",
		},
		{
			name = "the same facts again show nothing",
			before = { facts = { lives = 3, ante = 2 }, id = "a", lives_guess = "none" }, table_is = "same",
			view = table_view({ "a" }, { a = { lives = 3, ante = 2 } }),
			lives_from = "opponent", reset = "keep", names = {}, next_id = "a", next_guess = "none",
		},
		{
			name = "one fact changing shows only it",
			before = { facts = { lives = 3, ante = 2 }, id = "a", lives_guess = "none" }, table_is = "same",
			view = table_view({ "a" }, { a = { lives = 2, ante = 2 } }),
			lives_from = "opponent", reset = "keep", names = { "lives" }, next_id = "a", next_guess = "none",
		},
		{
			name = "another player under the same table starts over",
			before = { facts = { lives = 3 }, id = "a", lives_guess = "none" }, table_is = "same",
			view = table_view({ "b" }, { b = { lives = 1 } }),
			lives_from = "opponent", reset = "new opponent", names = { "lives", "ante", "location", "skips", "sells", "shop_spends" },
			next_id = "b", next_guess = "none",
		},
		{
			name = "an opponent arriving drops the guessed lives",
			before = { facts = { lives = 4 }, id = nil, lives_guess = "highest of others" }, table_is = "same",
			view = table_view({ "b" }, { b = { lives = 4 } }),
			lives_from = "opponent", reset = "guessed lives dropped", names = { "lives" },
			next_id = "b", next_guess = "none",
		},
		{
			name = "a gap shows the highest lives of the others",
			before = nothing, table_is = "new",
			view = table_view({}, { me = { lives = 5 }, x = { lives = 2 }, y = { lives = 4 } }),
			lives_from = "highest of others", reset = "keep", names = { "lives" }, next_id = nil, next_guess = "highest of others",
		},
		{
			name = "a gap with an out opponent keeps their lives",
			before = { facts = { lives = 1 }, id = "a", lives_guess = "none" }, table_is = "same",
			view = table_view({}, { a = { lives = 0 }, x = { lives = 4 } }, { a = { status = "out" } }),
			lives_from = "out opponent", reset = "keep", names = { "lives" }, next_id = "a", next_guess = "none",
		},
		{
			name = "a gap with nobody known shows nothing",
			before = nothing, table_is = "new", view = table_view({}, {}),
			lives_from = "none", reset = "keep", names = {}, next_id = nil, next_guess = "none",
		},
	}
	for _, case in ipairs(shown_cases) do
		local got = reader.opponent_shown(case.before, case.view, case.table_is)
		eq(got.lives_from, case.lives_from, case.name .. ": lives_from")
		eq(got.reset, case.reset, case.name .. ": reset")
		local names = {}
		for _, change in ipairs(got.show) do names[#names + 1] = change.name end
		eq(table.concat(names, ","), table.concat(case.names, ","), case.name .. ": shown")
		eq(got.next.id, case.next_id, case.name .. ": next id")
		eq(got.next.lives_guess, case.next_guess, case.name .. ": next guess")
	end
end

-- Every run-side input the screen sends, with a stub net that records send(kind, body): the kinds and
-- field names are the server's (nakama/src/lobby/pvp/parts/{run,effects}.ts). Then the opponent's run
-- shown from the view, once per change.
do
	T.fresh()
	local sent = {}
	local net
	net = {
		view = nil,
		refuse = false,
		send = function(kind, body)
			if not net.view or net.refuse then return nil, "refused" end
			sent[#sent + 1] = { kind = kind, body = body }
			return #sent
		end,
	}
	function net.send_live(kind, body)
		if not body or MPAPI.playback.is_driving("pvp") then return nil end
		return net.send(kind, body)
	end

	-- A replay, a fast-forward or a rejoin load is a playback driver of the PvP mod.
	local playing_back_for = nil
	MPAPI = { playback = { is_driving = function(ns) return playing_back_for == ns end } }

	local ruleset = {}
	local dispatched, lost_life_sounds = {}, 0
	PVP = {
		READ = {},
		NET = net,
		GAME = { location_full = "Shop", enemy = { lives = 5, skips = 0 } },
		LOBBY = {},
		OPPONENT_SIGNALS = {
			lives_dropped = function(old, new) return old ~= nil and new ~= nil and new < old end,
			play_life_lost = function() lost_life_sounds = lost_life_sounds + 1 end,
		},
		RULES = { current = function() return ruleset end },
		UI = { match = {
			show_enemy_location = function(location)
				dispatched[#dispatched + 1] = { name = "enemyLocation", params = { location = location } }
			end,
		} },
	}
	Game = { update = function() end }
	local sounds = {}
	function play_sound(name, pitch, volume) sounds[#sounds + 1] = { name, pitch, volume } end
	G = { GAME = { pvp_net = { totals = {} }, round_resets = { ante = 2 }, skips = 1 } }

	dofile("pvp_api/read/_view.lua")
	dofile("pvp_api/read/run.lua")
	dofile("pvp_api/ui/run.lua")
	dofile("lib/run_totals.lua")
	local screen = PVP.UI.run

	local function take()
		local out = sent
		sent = {}
		return out
	end

	-- Nothing is sent without a view.
	screen.progress("Shop")
	screen.sold()
	screen.effect("pizza")
	eq(#take(), 0, "no view: nothing sent, no total counted")
	eq(next(G.GAME.pvp_net.totals), nil, "no view: no total counted")

	net.view = { match = { run = {} } }

	screen.progress("Shop")
	same(take(), { { kind = "progress", body = { ante = 2, location = "Shop" } } }, "progress")
	screen.ante_changed(3)
	same(take(), { { kind = "progress", body = { ante = 3, location = "Shop" } } }, "ante changed")
	screen.blind_result("Boss", "lost")
	same(take(), { { kind = "blindResult", body = { blindKey = "2:Boss", result = "lost" } } }, "blind result")

	screen.skipped("Small")
	same(take(), {
		{ kind = "skip", body = { blindKey = "2:Small", total = 1 } },
		{ kind = "shop", body = { ante = 2, total = 1, spent = 0 } },
	}, "skip also closes its shop at 0")
	screen.skipped("Boss")
	same(take(), { { kind = "shop", body = { ante = 2, total = 2, spent = 0 } } }, "a Boss is not a skip")

	screen.sold()
	screen.sold()
	G.GAME.round_resets.ante = 3
	screen.sold()
	same(take(), {
		{ kind = "sell", body = { ante = 2, total = 1 } },
		{ kind = "sell", body = { ante = 2, total = 2 } },
		{ kind = "sell", body = { ante = 3, total = 1 } },
	}, "sells count per ante")

	screen.shop_closed(9)
	same(take(), { { kind = "shop", body = { ante = 3, total = 3, spent = 9 } } }, "shop")
	screen.voucher_redeemed("v_mp_hieroglyph_manhunt")
	same(take(), { { kind = "voucher", body = { voucherKey = "v_mp_hieroglyph_manhunt" } } }, "voucher")

	screen.effect("asteroid")
	screen.effect("asteroid")
	screen.effect("pizza")
	screen.effect("gambling")
	same(take(), {
		{ kind = "effect", body = { effect = "asteroid", total = 1 } },
		{ kind = "effect", body = { effect = "asteroid", total = 2 } },
		{ kind = "effect", body = { effect = "pizza", total = 1 } },
		{ kind = "effect", body = { effect = "gambling", total = 1 } },
	}, "effects count per card")
	screen.effect("trap")
	eq(#take(), 0, "an unknown effect is not sent")
	eq(PVP.GAME.enemy.pizza_discards, nil, "an effect changes nothing in my own run")

	-- An input that would be refused is not sent and does not use up a total.
	local totals = G.GAME.pvp_net.totals
	eq(totals["effect:trap"], nil, "an unknown effect counts nothing")
	screen.shop_closed(-1)
	screen.shop_closed(0 / 0)
	eq(#take(), 0, "a negative or NaN spend is not sent")
	eq(totals.shop, 3, "and does not use a shop total")
	screen.shop_closed(4)
	same(take(), { { kind = "shop", body = { ante = 3, total = 4, spent = 4 } } }, "the next shop total follows with no gap")

	-- Nothing is sent and no total counted while a replay, a fast-forward or a load runs.
	local before = show(totals)
	local skips_before = G.GAME.skips
	playing_back_for = "pvp"
	screen.sold()
	screen.skipped("Small")
	screen.shop_closed(5)
	screen.effect("pizza")
	screen.effect("gambling")
	screen.progress("Shop")
	screen.ante_changed(4)
	screen.blind_result("Boss", "beaten")
	screen.voucher_redeemed("v_mp_hieroglyph_manhunt")
	eq(#take(), 0, "playback: a sell, skip, shop, effect, progress, result or voucher sends nothing")
	eq(show(totals), before, "playback: no total is counted")
	eq(G.GAME.skips, skips_before, "playback: the skips count is the game's, untouched")
	playing_back_for = "spdrn"
	screen.sold()
	eq(#take(), 1, "another mod's playback does not stop this mod's inputs")
	playing_back_for = nil
	screen.sold()
	same(take(), { { kind = "sell", body = { ante = 3, total = 3 } } }, "after playback the totals go on from where they were")

	-- A refused send leaves the total as it was.
	net.refuse = true
	screen.sold()
	screen.shop_closed(2)
	screen.effect("asteroid")
	net.refuse = false
	eq(#take(), 0, "refused: nothing was sent")
	eq(totals["sell:3"], 3, "refused: a sell is not counted")
	eq(totals.shop, 4, "refused: a shop is not counted")
	eq(totals["effect:asteroid"], 2, "refused: an effect is not counted")
	screen.sold()
	screen.effect("asteroid")
	same(take(), {
		{ kind = "sell", body = { ante = 3, total = 4 } },
		{ kind = "effect", body = { effect = "asteroid", total = 3 } },
	}, "the next accepted input carries the next total, with no gap")

	-- An unknown location is not sent.
	screen.progress(nil)
	screen.ante_changed(nil)
	eq(#take(), 0, "an unknown location is not sent")
	PVP.GAME.location_full = "Shop"

	-- The opponent's run, from the view, once.
	local function opponent(player, id)
		id = id or "b"
		return { match = { run = { targets = { opponents = { id } }, players = { [id] = player } } } }
	end

	net.view = opponent({ lives = 3, ante = 4, location = "Shop", skips = 2, sells = { ["2"] = 1 }, shopSpends = { 5 } })
	screen.update()
	eq(PVP.GAME.enemy.lives, 3, "lives shown")
	eq(PVP.GAME.enemy.ante, 4, "ante shown")
	eq(PVP.GAME.enemy.skips, 2, "skips shown")
	eq(PVP.GAME.enemy.sells_per_ante[2], 1, "sells shown")
	eq(PVP.GAME.enemy.spent_in_shop[1], 5, "shop spends shown")
	eq(#dispatched, 1, "location shown")
	eq(dispatched[1].params.location, "Shop", "location value")
	eq(lost_life_sounds, 1, "a life dropped from the game's 5 to 3")
	screen.update()
	eq(#dispatched, 1, "the same view again shows nothing new")
	eq(lost_life_sounds, 1, "the same view again plays no sound")

	net.view = opponent({ lives = 2 })
	screen.update()
	eq(lost_life_sounds, 2, "a life lost is signalled once")
	eq(PVP.GAME.enemy.skips, nil, "a skips count the view lost is unknown, not kept or zero")
	eq(PVP.GAME.enemy.sells_per_ante, nil, "sells unknown")
	eq(#dispatched, 1, "an unknown location draws nothing")

	net.view = nil
	screen.update()
	net.view = opponent({ lives = 2 })
	screen.update()
	eq(lost_life_sounds, 2, "view back with the same lives: nothing new")

	-- The game's opponent table is replaced (a new match): the same view is shown into it again.
	dispatched = {}
	net.view = opponent({ lives = 4, ante = 2, location = "Blind", skips = 1 })
	screen.update()
	eq(#dispatched, 1, "the location is shown")
	PVP.GAME.enemy = { lives = 9, skips = 7 }
	screen.update()
	eq(PVP.GAME.enemy.lives, 4, "a new opponent table gets the view's lives")
	eq(PVP.GAME.enemy.skips, 1, "and its skips")
	eq(#dispatched, 2, "and its location is shown again")

	-- A gap with no opponent keeps what is shown; the same opponent coming back changes only what differs.
	net.view = { match = { run = {} } }
	screen.update()
	screen.update()
	PVP.GAME.enemy.lives = 99
	screen.update()
	eq(PVP.GAME.enemy.lives, 99, "no opponent in the view: what is shown is kept")
	net.view = opponent({ lives = 4, ante = 2, location = "Blind", skips = 1 })
	screen.update()
	eq(#dispatched, 2, "back from no opponent: an unchanged location is not dispatched again")
	eq(PVP.GAME.enemy.lives, 99, "and an unchanged life count is not shown again")
	net.view = nil
	screen.update()
	net.view = opponent({ lives = 4, ante = 2, location = "Blind", skips = 1 })
	screen.update()
	eq(#dispatched, 3, "back from no view: the location is dispatched again")

	-- A -> none -> A with a life lost in the gap: the sound plays once.
	PVP.GAME.enemy = {}
	net.view = opponent({ lives = 3 })
	screen.update()
	local sounds_before = lost_life_sounds
	net.view = { match = { run = {} } }
	screen.update()
	net.view = opponent({ lives = 2 })
	screen.update()
	eq(lost_life_sounds, sounds_before + 1, "a life lost while the opponent was gone sounds once")
	screen.update()
	eq(lost_life_sounds, sounds_before + 1, "and not again")
	-- A -> none -> B resets: B's lives are not a loss from A's.
	net.view = { match = { run = {} } }
	screen.update()
	net.view = opponent({ lives = 1 }, "c")
	screen.update()
	eq(lost_life_sounds, sounds_before + 1, "another opponent after a gap is not a life lost")
	eq(PVP.GAME.enemy.lives, 1, "and shows their own lives")
	dispatched = {}

	-- The opponent's last life: the server drops a player who is out from the targets but still lists
	-- them, so their 0 lives are shown with no opponent in the targets.
	PVP.GAME.enemy = {}
	net.view = opponent({ lives = 1 })
	screen.update()
	sounds_before = lost_life_sounds
	net.view = { match = { run = { targets = { opponents = {} }, players = { b = { lives = 0 } } } } }
	screen.update()
	eq(PVP.GAME.enemy.lives, 0, "an opponent out of the targets still shows their lives")
	eq(lost_life_sounds, sounds_before + 1, "the last life lost sounds once")
	screen.update()
	eq(lost_life_sounds, sounds_before + 1, "and not again")
	PVP.GAME.enemy.lives = 7
	screen.update()
	eq(PVP.GAME.enemy.lives, 7, "the same lives in the gap are shown once, not every frame")
	dispatched = {}

	-- Opponent lives as the live game shows them: the opponent's when there is one, else the highest of the
	-- other players', never my own.
	local function table_of(opponents, lives)
		local players = {}
		for id, count in pairs(lives) do players[id] = { lives = count } end
		return { me = "a", match = { run = { targets = { opponents = opponents }, players = players } } }
	end
	PVP.GAME.enemy = {}
	net.view = table_of({}, { a = 4, b = 3, c = 2 })
	screen.update()
	eq(PVP.GAME.enemy.lives, 3, "no opponent: the highest lives of the other players")
	net.view = table_of({}, { a = 9, b = 3, c = 1 })
	screen.update()
	eq(PVP.GAME.enemy.lives, 3, "my own lives are never the opponent's")
	net.view = table_of({}, { a = 4, b = 1, c = 2 })
	screen.update()
	eq(PVP.GAME.enemy.lives, 2, "the highest follows the view")
	PVP.GAME.enemy = {}
	net.view = table_of({ "c" }, { a = 4, b = 3, c = 2 })
	screen.update()
	eq(PVP.GAME.enemy.lives, 2, "an opponent: their lives, not the highest")
	PVP.GAME.enemy = {}
	net.view = table_of({}, {})
	screen.update()
	eq(PVP.GAME.enemy.lives, nil, "no other player in the view: unknown")

	-- 3+ players: my opponent goes out and leaves the targets. Their 0 is shown and sounds once; the highest of
	-- the others is only for when no opponent was shown yet.
	PVP.GAME.enemy = {}
	net.view = table_of({ "c" }, { a = 4, b = 3, c = 1 })
	screen.update()
	sounds_before = lost_life_sounds
	net.view = table_of({}, { a = 4, b = 3, c = 0 })
	screen.update()
	eq(PVP.GAME.enemy.lives, 0, "my opponent went out: their 0 stays, not the highest of the others")
	eq(lost_life_sounds, sounds_before + 1, "and the last life lost sounds once")
	net.view = table_of({}, { a = 4, b = 3, c = 0 })
	screen.update()
	eq(lost_life_sounds, sounds_before + 1, "and not again")
	net.view = table_of({ "b" }, { a = 4, b = 3, c = 0 })
	screen.update()
	eq(PVP.GAME.enemy.lives, 3, "the next opponent shows their own lives")
	eq(lost_life_sounds, sounds_before + 1, "which is no life lost")

	-- A gap before any opponent was shown shows the highest of the others; the first opponent then is no loss.
	PVP.GAME.enemy = {}
	net.view = table_of({}, { a = 4, b = 3, c = 2 })
	screen.update()
	eq(PVP.GAME.enemy.lives, 3, "a bye: the highest of the others")
	sounds_before = lost_life_sounds
	net.view = table_of({ "c" }, { a = 4, b = 3, c = 2 })
	screen.update()
	eq(PVP.GAME.enemy.lives, 2, "the first opponent shows their lives")
	eq(lost_life_sounds, sounds_before, "coming from the highest of the others is no life lost")
	-- a bye with my last opponent still in: the highest of the others, no cue; they come back with the same lives
	net.view = table_of({}, { a = 1, b = 4, c = 2 })
	screen.update()
	eq(PVP.GAME.enemy.lives, 4, "a bye: the highest of the others, though the last opponent is still in")
	eq(lost_life_sounds, sounds_before, "and no cue")
	net.view = table_of({ "c" }, { a = 1, b = 4, c = 2 })
	screen.update()
	eq(PVP.GAME.enemy.lives, 2, "the opponent back shows their own lives")
	eq(lost_life_sounds, sounds_before, "with no cue from the others' highest")
	net.view = table_of({ "c" }, { a = 1, b = 4, c = 1 })
	screen.update()
	eq(lost_life_sounds, sounds_before + 1, "a real drop by the same opponent still sounds")

	-- A ruleset that hides the opponent's location draws none.
	ruleset = { enemy_location_disabled = true }
	net.view = opponent({ lives = 4, location = "Shop" })
	screen.update()
	eq(#dispatched, 0, "enemy_location_disabled: no location is dispatched")
	eq(PVP.GAME.enemy.lives, 4, "but the other facts are shown")
	ruleset = {}

	-- The opponent skipping a blind sounds the old gong, once, only when the view shows the count going up.
	-- Nothing on the first view, after a rejoin or a new opponent table, or when the count is unchanged or down.
	eq(#sounds, 0, "no skip sound so far: the first view, a lost count and a return never sound")
	net.view = nil
	screen.update()
	net.view = opponent({ lives = 4, skips = 1 })
	screen.update()
	eq(#sounds, 0, "first view after a rejoin: the count 1 is not a skip")
	net.view = opponent({ lives = 4, skips = 2 })
	screen.update()
	same(sounds, { { "negative", 0.865, 0.4 }, { "gong", 0.765, 0.4 } }, "a skip count going up sounds the old pair")
	screen.update()
	eq(#sounds, 2, "the same view again is silent")
	net.view = opponent({ lives = 4, skips = 5 })
	screen.update()
	eq(#sounds, 4, "each rise sounds once")
	net.view = opponent({ lives = 4, skips = 3 })
	screen.update()
	eq(#sounds, 4, "a count going down is silent")
	net.view = opponent({ lives = 4 })
	screen.update()
	net.view = opponent({ lives = 4, skips = 9 })
	screen.update()
	eq(#sounds, 4, "a count that was unknown and is known again is not a rise")
	ruleset = { enemy_location_disabled = true }
	net.view = opponent({ lives = 4, skips = 10 })
	screen.update()
	eq(#sounds, 4, "a ruleset that hides the opponent's run is silent")
	ruleset = {}
	PVP.GAME.enemy = { lives = 4, skips = 0 }
	net.view = opponent({ lives = 4, skips = 11 })
	screen.update()
	eq(#sounds, 4, "a new opponent table starts from nothing known")

	-- A different opponent under the same table (Nemesis rotation, a new Royale target): their skips and
	-- lives are not a change in the last one's, so no sound and no juice.
	local lost_before = lost_life_sounds
	net.view = opponent({ lives = 4, skips = 1 }, "a")
	screen.update()
	net.view = opponent({ lives = 2, skips = 3 }, "c")
	screen.update()
	eq(#sounds, 4, "another opponent with more skips: no skip sound")
	eq(lost_life_sounds, lost_before, "another opponent with fewer lives: no life-lost sound")
	eq(PVP.GAME.enemy.skips, 3, "but their facts are shown")
	eq(PVP.GAME.enemy.lives, 2, "lives included")
	net.view = opponent({ lives = 2, skips = 4 }, "c")
	screen.update()
	eq(#sounds, 6, "the new opponent skipping later still sounds")
	net.view = opponent({ lives = 1, skips = 4 }, "c")
	screen.update()
	eq(lost_life_sounds, lost_before + 1, "and losing a life later still sounds")

	-- The opponent's last life ends the game: the lobby's view carries the game that ended, and the
	-- opponent's 0 is read from there.
	net.view = { match = { stage = "lobby", lobby = {}, ended = opponent({ lives = 0, skips = 4 }, "c") } }
	screen.update()
	eq(PVP.GAME.enemy.lives, 0, "the opponent's last life lost shows from the game that ended")
	eq(lost_life_sounds, lost_before + 2, "with its sound")
end

T.done("run_test")
