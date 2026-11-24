-- Run from the repo root: luajit tests/unit/trap_test.lua
-- Traps: the reader's bodies and view reads, the fire data, then the screen's sends and trap cards.
local T = dofile("tests/support/check.lua")
local eq, same, show = T.eq, T.same, T.show

-- pvp_api/read/trap.lua: each trap input body (the server's: nakama/src/lobby/pvp/parts/traps.ts), what
-- the view says of my traps, and what my cards and the Nemesis row must do to match it.
do
	T.fresh()
	PVP = { NET = {}, READ = {}, UI = {} }
	dofile("pvp_api/read/_view.lua")
	dofile("pvp_api/read/_trap_record.lua")
	dofile("pvp_api/read/trap.lua")
	local reader = PVP.READ.trap

	-- plant
	eq(reader.plant("c_mp_trap_alarm", 0), nil, "plant total 0")
	eq(reader.plant("c_mp_trap_alarm", 1.5), nil, "plant fraction")
	eq(reader.plant("c_fool", 1), nil, "plant of a card that is not a mod card")
	eq(reader.plant("", 1), nil, "plant with no key")
	eq(reader.plant(nil, 1), nil, "plant with a nil key")

	-- fire
	local body, problem = reader.fire(nil, "c_mp_trap_symbol", { owner = "a" })
	eq(body, nil, "fire with no trap number")
	eq(type(problem), "string", "fire with no trap number says why")
	eq(reader.fire(0, "c_mp_trap_symbol", { owner = "a" }), nil, "fire trap 0")
	eq(reader.fire(1, "c_mp_trap_phase_door", { owner = "a" }), nil, "fire with a field missing")

	-- lost
	eq(reader.lost(nil), nil, "lost with no number")
	eq(reader.lost(-1), nil, "lost negative")

	-- the view's traps
	local function entry(id, owner, holder, state, key) return { id = id, key = key or "c_mp_trap_alarm", owner = owner, holder = holder, state = state } end
	eq(reader.traps(nil), nil, "no view")
	eq(reader.traps({ onlyMine = {} }), nil, "no list in the view")
	same(reader.traps({ onlyMine = { traps = {} } }), {}, "an empty list is a list")
	same(
		reader.traps({ onlyMine = { traps = { entry(1, "a", "b", "live"), { id = 2, key = "c_mp_trap_alarm", owner = "a", holder = "b" }, entry(3, "a", "b", "gone") } } }),
		{ entry(1, "a", "b", "live") },
		"a trap that is not whole in the view is left out"
	)

	-- my cards against the traps I hold
	local function never() return false end
	local traps = { entry(1, "b", "a", "live"), entry(2, "b", "a", "fired"), entry(3, "a", "b", "live"), entry(4, "b", "a", "lost") }
	local work = reader.reconcile(traps, "a", {}, never)
	same(work.add, { traps[1] }, "a held live trap with no card is added; fired, lost and other holders are not")
	same(work.reveal, {}, "nothing to reveal with no card")
	work = reader.reconcile(traps, "a", { { id = 1, fired = false }, { id = 2, fired = false } }, never)
	same(work.add, {}, "a card there is not added again")
	same(work.reveal, { 2 }, "a card the server says has gone off is revealed")
	work = reader.reconcile(traps, "a", { { id = 2, fired = true } }, never)
	same(work.reveal, {}, "a card already revealed is not revealed again")
	work = reader.reconcile(traps, "a", {}, function(id) return id == 1 end)
	same(work.add, {}, "a trap that has gone off here is not dealt again after a load")

	-- the Nemesis row
	local mine = { entry(1, "a", "b", "live"), entry(2, "a", "c", "live"), entry(3, "a", "b", "fired"), entry(4, "z", "b", "live"), entry(5, "a", "b", "lost") }
	local row = reader.row(mine, "a", { "b" })
	same(row.shown, { mine[1] }, "the live traps I planted that the Nemesis holds")
	same(row.fired, { [3] = true }, "the ones that went off")
	same(reader.row(mine, "a", {}).shown, {}, "no Nemesis, nothing shown")
	same(reader.row(nil, "a", { "b" }).shown, {}, "no list, nothing shown")

	-- the signature changes with the holder and the state
	local before = reader.signature({ entry(1, "a", "b", "live") })
	eq(before ~= reader.signature({ entry(1, "a", "c", "live") }), true, "a new holder changes it")
	eq(before ~= reader.signature({ entry(1, "a", "b", "fired") }), true, "a new state changes it")
	eq(before ~= reader.signature({ entry(1, "a", "b", "live"), entry(2, "a", "b", "live") }), true, "a new trap changes it")
	eq(before, reader.signature({ entry(1, "a", "b", "live") }), "the same list gives the same signature")
end

-- pvp_api/read/_trap_record.lua: the fire data names are main's, the sender builds exactly what the handler reads,
-- and a record the server would refuse is never built.
do
	T.fresh()
	PVP = { NET = {}, READ = {}, UI = {} }
	dofile("pvp_api/read/_view.lua")
	dofile("pvp_api/read/_trap_record.lua")
	dofile("pvp_api/net/inbox.lua")
	local data, inbox = PVP.READ.trap_record, PVP.NET.inbox
	-- The game: every call is recorded by name.
	local made
	for name, value in pairs(inbox) do
		if type(value) == "function" and name ~= "install" then
			inbox[name] = function() made[#made + 1] = name end
		end
	end

	-- What each trap sends, with the names main used, and the game call its owner's handler makes from it.
	local rows = {
		{ "c_mp_trap_glyph_of_warding", {}, "add_tag" },
		{ "c_mp_trap_symbol", {}, nil },
		{ "c_mp_trap_alarm", { rerolls = 2 }, "add_free_rerolls" },
		{ "c_mp_trap_explosive_runes", {}, nil },
		{ "c_mp_trap_sepia_snake_sigil", { key = "j_blueprint" }, "add_joker" },
		{ "c_mp_trap_fire_trap", {}, nil },
		{ "c_mp_trap_guards_and_wards", {}, nil },
		{ "c_mp_trap_magic_mouth", { card = "H4sIAAAAAAAA" }, "add_stolen_card" },
		{ "c_mp_trap_snare", { tag_key = "tag_double", orbital_hand = "Pair" }, "add_tag" },
		{ "c_mp_trap_arcane_lock", {}, nil },
		{ "c_mp_trap_programmed_illusion", {}, nil },
		{ "c_mp_trap_web", { key = "c_pluto", set = "Planet" }, "add_consumable" },
		{ "c_mp_trap_forbiddance", {}, nil },
		{ "c_mp_trap_faithful_hound", { hand_type = "Flush" }, "level_up_hand" },
		{ "c_mp_trap_phase_door", { dollars = 12 }, "add_money" },
		{ "c_mp_trap_mental_prison", {}, "add_wheels" },
	}

	for _, row in ipairs(rows) do
		local key, values, call = row[1], row[2], row[3]
		local sent_values = { owner = "a" }
		for name, value in pairs(values) do sent_values[name] = value end
		local record, problem = data.build(key, sent_values)
		eq(problem, nil, key .. " builds")
		same(record, sent_values, key .. " sends exactly the fields it was given")
		-- The handler reads what the sender built.
		made = {}
		local ok, why = pcall(inbox.effects.trapReward, { effect = "trapReward", trap = { id = 1, key = key, data = record } })
		eq(why, nil, key .. " handler accepts the sender's record")
		eq(ok, true, key .. " handler runs")
		eq(made[#made], "show_trap_fired", key .. " shows the trap")
		eq(made[1] ~= "show_trap_fired" and made[1] or nil, call, key .. " handler call")
	end

	-- Every trap card the mod has has a table row.
	local count = 0
	for _ in pairs(data.FIELDS) do count = count + 1 end
	eq(count, #rows, "one row per trap")

	-- The names are main's, exactly.
	local function names(key)
		local out = {}
		for name in pairs(data.FIELDS[key]) do out[#out + 1] = name end
		table.sort(out)
		return table.concat(out, ",")
	end
	eq(names("c_mp_trap_snare"), "orbital_hand,owner,tag_key", "snare fields")
	eq(names("c_mp_trap_sepia_snake_sigil"), "key,owner", "sepia fields")
	eq(names("c_mp_trap_magic_mouth"), "card,owner", "magic mouth fields")
	eq(names("c_mp_trap_web"), "key,owner,set", "web fields")
	eq(names("c_mp_trap_faithful_hound"), "hand_type,owner", "hound fields")
	eq(names("c_mp_trap_phase_door"), "dollars,owner", "phase door fields")
	eq(names("c_mp_trap_alarm"), "owner,rerolls", "alarm fields")

	-- Not built: an unknown trap, a missing field, a wrong kind, a fraction, a field of another trap.
	local refused = {
		{ "unknown trap", "c_mp_trap_nothing", { owner = "a" } },
		{ "not a table", "c_mp_trap_symbol", "x" },
		{ "no owner", "c_mp_trap_symbol", {} },
		{ "alarm without rerolls", "c_mp_trap_alarm", { owner = "a" } },
		{ "alarm text rerolls", "c_mp_trap_alarm", { owner = "a", rerolls = "2" } },
		{ "alarm fraction", "c_mp_trap_alarm", { owner = "a", rerolls = 1.5 } },
		{ "phase door zero", "c_mp_trap_phase_door", { owner = "a", dollars = 0 } },
		{ "sepia empty key", "c_mp_trap_sepia_snake_sigil", { owner = "a", key = "" } },
		{ "web without set", "c_mp_trap_web", { owner = "a", key = "c_pluto" } },
		{ "snare bad orbital", "c_mp_trap_snare", { owner = "a", orbital_hand = 2 } },
	}
	for _, row in ipairs(refused) do
		local record, problem = data.build(row[2], row[3])
		eq(record, nil, row[1] .. " not built")
		eq(type(problem), "string", row[1] .. " says why")
	end

	-- The snare may name no tag (a skip with no tag): the record is just the owner.
	same(data.build("c_mp_trap_snare", { owner = "a" }), { owner = "a" }, "snare with no tag")

	-- A field of another trap is dropped, not sent.
	same(data.build("c_mp_trap_symbol", { owner = "a", dollars = 4 }), { owner = "a" }, "extra field dropped")

	-- The server's size cap (1024 bytes of JSON): a real Magic Mouth card is about 540 characters and fits;
	-- a card over the cap is refused, never cut.
	local small = string.rep("x", 540)
	eq(data.build("c_mp_trap_magic_mouth", { owner = "a", card = small }) ~= nil, true, "a real card fits")
	local record, problem = data.build("c_mp_trap_magic_mouth", { owner = "a", card = string.rep("x", 1100) })
	eq(record, nil, "a card over the cap is refused")
	eq(problem:find("1024", 1, true) ~= nil, true, "the refusal names the cap")
	-- Quotes count double, as the server counts the encoded text.
	eq(data.build("c_mp_trap_magic_mouth", { owner = "a", card = string.rep('"', 600) }), nil, "escapes count")

	-- The cap to the byte. The JSON text is written out here, so the size is counted by the test, not by
	-- the code under test: a string value and two keys, then four keys with a number among them.
	local function card_with_size(size)
		local overhead = #'{"card":"","owner":"a"}'
		return string.rep("x", size - overhead)
	end
	for _, case in ipairs({ { 1024, true }, { 1025, false }, { 1023, true } }) do
		local size, fits = case[1], case[2]
		local card = card_with_size(size)
		eq(#('{"card":"' .. card .. '","owner":"a"}'), size, "the test's JSON text is " .. size .. " bytes")
		eq(data.build("c_mp_trap_magic_mouth", { owner = "a", card = card }) ~= nil, fits, size .. " bytes, a string value and two keys")
	end
	local function web_with_size(size)
		local overhead = #'{"key":"","owner":"a","set":"s"}'
		return string.rep("k", size - overhead)
	end
	for _, case in ipairs({ { 1024, true }, { 1025, false } }) do
		local key = web_with_size(case[1])
		eq(#('{"key":"' .. key .. '","owner":"a","set":"s"}'), case[1], "the web's JSON text is " .. case[1] .. " bytes")
		eq(data.build("c_mp_trap_web", { owner = "a", key = key, set = "s" }) ~= nil, case[2], case[1] .. " bytes, three keys")
	end
	-- A number is its digits, with no quotes.
	local number_only = data.build("c_mp_trap_phase_door", { owner = "a", dollars = 12 })
	eq(number_only.dollars, 12, "a number is counted as digits")
	local snare_text = string.rep("t", 1024 - #'{"orbital_hand":"","owner":"a","tag_key":"x"}')
	eq(data.build("c_mp_trap_snare", { owner = "a", tag_key = "x", orbital_hand = snare_text }) ~= nil, true, "two keys and an optional one, 1024 bytes")
	eq(data.build("c_mp_trap_snare", { owner = "a", tag_key = "x", orbital_hand = snare_text .. "t" }), nil, "and 1025 bytes")

	-- A whole number of 16 digits counts as all its digits (tostring would write 9.007199254741e+15).
	local digits_owner = string.rep("o", 1024 - #'{"dollars":9007199254740991,"owner":""}')
	eq(data.build("c_mp_trap_phase_door", { owner = digits_owner, dollars = 2 ^ 53 - 1 }) ~= nil, true, "a 16-digit number at 1024 bytes")
	eq(data.build("c_mp_trap_phase_door", { owner = digits_owner .. "o", dollars = 2 ^ 53 - 1 }), nil, "and one byte more is refused")

	-- What the owner receives: the trap's own fields, and no owner needed. An empty record (the server's
	-- Arcane Lock bounce, which reaches Lua as an empty table either way) is fine for a trap with no fields.
	same(data.received("c_mp_trap_arcane_lock", {}), {}, "an empty record is received for the lock")
	same(data.received("c_mp_trap_alarm", { rerolls = 3 }), { rerolls = 3 }, "no owner needed")
	same(data.received("c_mp_trap_alarm", { rerolls = 3, owner = "a" }), { rerolls = 3 }, "an owner is not kept")
	eq(data.received("c_mp_trap_alarm", {}), nil, "a field of the trap itself is still needed")
	eq(data.received("c_mp_trap_alarm", "x"), nil, "a record that is not a table is refused")
	eq(data.received("c_mp_trap_nothing", {}), nil, "an unknown trap is refused")
	eq(data.checked("c_mp_trap_arcane_lock", {}), nil, "the sender still names the owner")

	-- Whole numbers are sent as they are; the server owns the upper limit.
	local most = 2 ^ 53 - 1
	eq(data.build("c_mp_trap_phase_door", { owner = "a", dollars = most }).dollars, most, "a big whole number is sent")
	eq(data.build("c_mp_trap_phase_door", { owner = "a", dollars = 1.5 }), nil, "a fraction is refused")
end

-- pvp_api/ui/trap.lua: each trap input is sent once (and never again after a load), nothing is sent
-- without a view, and my trap cards and the Nemesis row follow the view.
do
	T.fresh()
	local sent = {}
	local net
	net = {
		view = nil,
		refuse = false,
		send = function(kind, body)
			if not net.view or net.refuse then return nil end
			sent[#sent + 1] = { kind = kind, body = body }
			return #sent
		end,
	}
	function net.send_live(kind, body)
		if not body or MPAPI.playback.is_driving("pvp") then return nil end
		return net.send(kind, body)
	end

	local refreshes, revealed, disguised = 0, {}, {}
	local in_session = true
	PVP = {
		READ = {}, UI = { trap_row = { refresh = function() refreshes = refreshes + 1 end } },
		NET = net,
		LOBBY = { in_session = function() return in_session end },
		TRAP = {
			disguise = function(card)
				card.ability.mp_trap_hidden = true
				disguised[#disguised + 1] = card.ability.mp_trap_id
			end,
			reveal_and_consume = function(card) revealed[#revealed + 1] = card.ability.mp_trap_id end,
		},
	}
	local dissolved = 0
	Card = setmetatable({ start_dissolve = function() dissolved = dissolved + 1 end }, {
		__call = function(_, _, _, _, _, _, center)
			return { ability = {}, config = { center = center }, add_to_deck = function() end }
		end,
	})
	local update_ref_calls = 0
	Game = { update = function() update_ref_calls = update_ref_calls + 1 end }
	local consumeables = {
		T = { x = 0, y = 0, w = 1 },
		cards = {},
		emplace = function(self, card) self.cards[#self.cards + 1] = card end,
	}
	G = {
		CARD_W = 1,
		CARD_H = 1,
		P_CENTERS = { c_mp_trap_alarm = { key = "c_mp_trap_alarm" }, c_mp_trap_symbol = { key = "c_mp_trap_symbol" } },
		GAME = { pvp_net = { totals = {}, runId = "run1" } },
		consumeables = consumeables,
	}
	local warnings = {}
	function sendWarnMessage(text) warnings[#warnings + 1] = text end
	local driving = nil
	MPAPI = { playback = { is_driving = function(namespace) return driving == namespace end } }

	dofile("lib/run_totals.lua")
	dofile("pvp_api/read/_view.lua")
	dofile("pvp_api/read/_trap_record.lua")
	dofile("pvp_api/read/trap.lua")
	dofile("pvp_api/ui/trap.lua")
	local screen = PVP.UI.trap

	local function take()
		local out = sent
		sent = {}
		return out
	end

	local function trap_card(key, id, owner)
		return { ability = { mp_trap_id = id, mp_trap_owner_id = owner, mp_trap_hidden = true }, config = { center = { key = key } } }
	end

	-- Nothing is sent, and no total counted, without a view. A trap that went off with nowhere to report
	-- it is gone here all the same, and the warning says it was not told.
	screen.planted("c_mp_trap_alarm")
	screen.fired(trap_card("c_mp_trap_symbol", 1, "b"), { owner = "b" })
	screen.lost(trap_card("c_mp_trap_symbol", 2, "b"))
	eq(#take(), 0, "no view: nothing sent")
	same(G.GAME.pvp_net.traps_gone, { ["1"] = true }, "no view: only the trap that went off is counted, as gone")
	eq(warnings[#warnings]:find("gone here and the server was not told", 1, true) ~= nil, true, "and it is logged")
	G.GAME.pvp_net.totals = {}
	warnings = {}

	net.view ={ me = "a", match = { run = { id = "run1" } }, onlyMine = { traps = {} } }

	-- Plant: one input per trap card taken, counted per key.
	screen.planted("c_mp_trap_alarm")
	screen.planted("c_mp_trap_alarm")
	screen.planted("c_mp_trap_symbol")
	same(take(), {
		{ kind = "trapPlant", body = { key = "c_mp_trap_alarm", total = 1 } },
		{ kind = "trapPlant", body = { key = "c_mp_trap_alarm", total = 2 } },
		{ kind = "trapPlant", body = { key = "c_mp_trap_symbol", total = 1 } },
	}, "plant")

	-- A plant the net refuses is not counted: the next one carries the next total, with no gap.
	net.refuse = true
	screen.planted("c_mp_trap_alarm")
	net.refuse = false
	eq(#take(), 0, "a refused plant sends nothing")
	eq(G.GAME.pvp_net.totals["trap:c_mp_trap_alarm"], 2, "and uses no total")
	screen.planted("c_mp_trap_alarm")
	same(take(), { { kind = "trapPlant", body = { key = "c_mp_trap_alarm", total = 3 } } }, "the next plant follows with no gap")
	screen.planted("not_a_trap")
	eq(#take(), 0, "a plant that cannot be built is not sent")
	eq(G.GAME.pvp_net.totals["trap:not_a_trap"], nil, "and is not counted")

	-- Fire: the server's body, once.
	local alarm = trap_card("c_mp_trap_alarm", 5, "b")
	screen.fired(alarm, { owner = "b", rerolls = 2 })
	same(take(), { { kind = "trapFire", body = { trapId = 5, data = { owner = "b", rerolls = 2 } } } }, "fire")
	screen.fired(alarm, { owner = "b", rerolls = 2 })
	eq(#take(), 0, "fire is sent once")
	-- ... and not again after a load: the gone set is kept with the run.
	local saved_totals, saved_gone = G.GAME.pvp_net.totals, G.GAME.pvp_net.traps_gone
	G.GAME.pvp_net = { totals = saved_totals, traps_gone = saved_gone, runId = "run1" }
	screen.fired(trap_card("c_mp_trap_alarm", 5, "b"), { owner = "b", rerolls = 2 })
	eq(#take(), 0, "fire is not sent again after a load")

	-- A fire that cannot be built is not sent. The trap went off all the same: it is gone, the server is
	-- told it was lost, and it is never fired or lost again.
	local bad = trap_card("c_mp_trap_alarm", 6, "b")
	screen.fired(bad, { owner = "b" })
	same(take(), { { kind = "trapLost", body = { trapId = 6 } } }, "a bad fire sends the trap as lost")
	eq(G.GAME.pvp_net.traps_gone["6"], true, "and counts it as gone")
	screen.fired(bad, { owner = "b", rerolls = 2 })
	screen.lost(bad)
	eq(#take(), 0, "it is not sent again")
	-- A fire the net refuses: gone here; the lost refused too is logged.
	net.refuse = true
	warnings = {}
	screen.fired(trap_card("c_mp_trap_alarm", 12, "b"), { owner = "b", rerolls = 2 })
	net.refuse = false
	eq(#take(), 0, "a refused fire and a refused lost send nothing")
	eq(G.GAME.pvp_net.traps_gone["12"], true, "the trap is gone here")
	eq(#warnings, 1, "one warning")
	eq(warnings[1]:find("gone here and the server was not told", 1, true) ~= nil, true, "that says so")
	G.consumeables.cards = {}
	net.view = { me = "a", match = { run = { id = "run1" } }, onlyMine = { traps = { { id = 12, key = "c_mp_trap_alarm", owner = "b", holder = "a", state = "live" } } } }
	screen.update()
	eq(#consumeables.cards, 0, "a trap that went off is not dealt again from the view's live copy")
	refreshes = 0
	net.view = { me = "a", match = { run = { id = "run1" } }, onlyMine = { traps = {} } }
	-- The server's trap number is needed to say anything: with none nothing is sent or counted.
	local before_totals = show(G.GAME.pvp_net.totals)
	screen.fired(trap_card("c_mp_trap_alarm", nil, "b"), { owner = "b", rerolls = 2 })
	eq(#take(), 0, "a card with no number from the server sends nothing")
	eq(show(G.GAME.pvp_net.totals), before_totals, "and counts nothing")

	-- A fire over the server's size is built into nothing: the trap is lost, never sent half.
	screen.fired(trap_card("c_mp_trap_magic_mouth", 13, "b"), { owner = "b", card = string.rep("x", 1100) })
	same(take(), { { kind = "trapLost", body = { trapId = 13 } } }, "a card over the cap loses the trap")
	-- What a trap asks before it takes something.
	eq(screen.fire_problem(trap_card("c_mp_trap_magic_mouth", 14, "b"), { owner = "b", card = "x" }), nil, "a card that fits has no problem")
	eq(screen.fire_problem(trap_card("c_mp_trap_magic_mouth", 14, "b"), { owner = "b", card = string.rep("x", 1100) }):find("1024", 1, true) ~= nil, true, "a card over the cap says so")
	eq(#take(), 0, "asking sends nothing")
	eq((G.GAME.pvp_net.traps_gone or {})["14"], nil, "and counts nothing")

	-- A replay, a fast-forward or a rejoin load sends nothing and counts nothing.
	driving = "pvp"
	screen.planted("c_mp_trap_alarm")
	screen.fired(trap_card("c_mp_trap_alarm", 15, "b"), { owner = "b", rerolls = 1 })
	screen.fired(trap_card("c_mp_trap_alarm", 16, "b"), { owner = "b" })
	screen.lost(trap_card("c_mp_trap_symbol", 17, "b"))
	eq(#take(), 0, "playback: nothing is sent")
	eq(G.GAME.pvp_net.totals["trap:c_mp_trap_alarm"], 3, "and no plant total is used")
	for _, number in ipairs({ 15, 16, 17 }) do eq((G.GAME.pvp_net.traps_gone or {})[tostring(number)], nil, "playback: trap " .. number .. " is not gone") end
	driving = "other"
	screen.planted("c_mp_trap_alarm")
	driving = nil
	same(take(), { { kind = "trapPlant", body = { key = "c_mp_trap_alarm", total = 4 } } }, "another mod's playback does not silence the plant")

	-- Lost: once, and not for a trap that went off.
	local lost = trap_card("c_mp_trap_symbol", 7, "b")
	screen.lost(lost)
	same(take(), { { kind = "trapLost", body = { trapId = 7 } } }, "lost")
	screen.lost(lost)
	eq(#take(), 0, "lost is sent once")
	screen.fired(lost, { owner = "b" })
	eq(#take(), 0, "a lost trap does not fire")
	screen.fired(trap_card("c_mp_trap_symbol", 8, "b"), { owner = "b" })
	take()
	screen.lost(trap_card("c_mp_trap_symbol", 8, "b"))
	eq(#take(), 0, "a trap that went off is not lost")

	-- Dissolving a hidden trap that has not gone off sends lost; a revealed one, a plain card and a game
	-- outside a match send nothing.
	local hooked = Card.start_dissolve
	local hidden = trap_card("c_mp_trap_symbol", 9, "b")
	hooked(hidden)
	same(take(), { { kind = "trapLost", body = { trapId = 9 } } }, "dissolving a hidden trap loses it")
	eq(dissolved, 1, "the dissolve still happens")
	local went_off = trap_card("c_mp_trap_symbol", 10, "b")
	went_off.ability.mp_trap_fired = true
	hooked(went_off)
	hooked({ ability = {} })
	in_session = false
	hooked(trap_card("c_mp_trap_symbol", 11, "b"))
	in_session = true
	eq(#take(), 0, "no lost for a trap that went off, a plain card, or outside a match")

	-- The view: a trap I hold gets its card once; a trap the server says has gone off is revealed once.
	local function view_with(list) return { me = "a", match = { run = { id = "run1" } }, onlyMine = { traps = list } } end
	local function entry(id, owner, holder, state) return { id = id, key = "c_mp_trap_alarm", owner = owner, holder = holder, state = state } end
	G.GAME.pvp_net = { totals = {}, runId = "run1" }
	net.view = view_with({ entry(20, "b", "a", "live"), entry(21, "a", "b", "live") })
	screen.update()
	eq(#consumeables.cards, 1, "a held trap gets a card")
	eq(consumeables.cards[1].ability.mp_trap_id, 20, "the card has the server's number")
	eq(consumeables.cards[1].ability.mp_trap_owner_id, "b", "the card knows its Trapper")
	same(disguised, { 20 }, "the card is disguised")
	screen.update()
	screen.update()
	eq(#consumeables.cards, 1, "not dealt again")
	eq(refreshes, 1, "the row is refreshed once per change")
	net.view = view_with({ entry(20, "b", "a", "fired"), entry(21, "a", "b", "live") })
	screen.update()
	same(revealed, { 20 }, "a trap the server fired is revealed")
	eq(consumeables.cards[1].ability.mp_trap_fired, true, "marked as gone off")
	screen.update()
	same(revealed, { 20 }, "revealed once")
	eq(refreshes, 2, "the row is refreshed for the new state")
	eq(#take(), 0, "following the view sends nothing")
	-- The revealed card leaves after its delay; the trap is gone here, so it is not dealt again.
	eq(G.GAME.pvp_net.traps_gone["20"], true, "a trap revealed through the view is counted as gone")
	consumeables.cards = {}
	screen.update()
	eq(#consumeables.cards, 0, "the revealed trap's card is not added back on the next update")
	net.view = view_with({ entry(20, "b", "a", "live"), entry(21, "a", "b", "live") })
	screen.update()
	eq(#consumeables.cards, 0, "nor from a live copy of it")
	net.view = view_with({ entry(20, "b", "a", "fired"), entry(21, "a", "b", "live") })

	-- Not my run's view: nothing is dealt.
	G.GAME.pvp_net = { totals = {}, runId = "run2" }
	consumeables.cards = {}
	net.view = view_with({ entry(30, "b", "a", "live") })
	screen.update()
	eq(#consumeables.cards, 0, "a view of another run deals nothing")

	-- The update hook runs the game's update first and survives an error.
	Game.update(Game, 0)
	eq(update_ref_calls, 1, "the game's update still runs")
end

T.done("trap_test")
