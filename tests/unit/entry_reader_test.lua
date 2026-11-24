-- Run from the repo root: luajit tests/unit/entry_reader_test.lua
-- pvp_api/entry_reader.lua: Ready looks, the Ready press, teams and the blind entry, from literal views.
local checks = 0
local function eq(actual, expected, message)
	checks = checks + 1
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
	end
end

local function show(value)
	if type(value) ~= "table" then return tostring(value) end
	local keys = {}
	for key in pairs(value) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local parts = {}
	for _, key in ipairs(keys) do parts[#parts + 1] = tostring(key) .. "=" .. show(value[key]) end
	return "{" .. table.concat(parts, ",") .. "}"
end

local function same(actual, expected, message) eq(show(actual), show(expected), message) end

PVP = {}
dofile("pvp_api/_view.lua")
dofile("pvp_api/entry_reader.lua")
local reader = PVP.entry_reader

local function button(view, pending, entered) return reader.ready_button(view, pending, entered, 2) end
local function press(view, pending) return reader.press(view, pending, 2) end
-- My latest Ready press the server has not confirmed, as net.latest_waiting("ready") gives it.
local function pressed(ready, blind_key) return { kind = "ready", ready = ready, blindKey = blind_key or "2:Boss" } end

-- A player's part of a playing blind, in each stage the view has.
local function shown(score) return { kind = "shown", score = score } end
local NOT_ENTERED = { stage = "not entered" }
local ENTERED = { stage = "entered", handsLeft = 4, score = shown("0") }
local PLAYED = { stage = "played a hand", handsLeft = 3, score = shown("100") }
local DONE = { stage = "done", endedBy = "hands", handsLeft = 0, score = shown("250") }

-- A view with my blind: stage is "waiting" (me is "ready" / "not ready") or "playing" (me is a part above).
-- With no stage there is no open blind. The Boss answer (targets.myBoss) defaults to "plays".
local function view(stage, me, my_boss)
	local pvp_blind
	if stage then
		local other = stage == "waiting" and "ready" or NOT_ENTERED
		pvp_blind = { stage = stage, blindKey = "2:Boss", players = { a = me, b = other } }
	end
	return {
		me = "a",
		players = { a = { team = "HUNTER" }, b = {} },
		onlyMine = { inboxNewest = 4 },
		match = { run = { id = "run1", players = { a = { ante = 2 } }, targets = { myBoss = my_boss or "plays" }, currentPvpBlind = pvp_blind } },
	}
end

-- Ready looks.
eq(button(nil, false), "waiting", "no view yet: waiting, a press sends nothing")
eq(button(nil, pressed(true)), "waiting", "no view yet, even with a press on its way")
eq(button(view("waiting", "not ready"), false), "not_ready", "blind waiting, not pressed")
eq(button(view("waiting", "ready"), false), "ready", "confirmed ready")
eq(button(view("waiting", "ready"), pressed(false)), "not_ready", "an unconfirmed un-ready shows not ready")
eq(button(view("waiting", "not ready"), pressed(true)), "ready", "an unconfirmed ready shows ready")
eq(button(view("waiting", "ready"), pressed(false, "1:Boss")), "ready", "a press for another blind is not read")
eq(button(view("playing", NOT_ENTERED), false), "ready", "playing, stage not entered: Ready still stands")
eq(button(view("playing", ENTERED), false), "ready", "playing, stage entered, blind not entered here: Ready still stands")
eq(button(view("playing", PLAYED), false), "ready", "playing, stage played a hand, blind not entered here: Ready still stands")
eq(button(view("playing", NOT_ENTERED), false, "run1/2:Boss"), "not_ready", "playing and entered: no longer waiting")
eq(button(view("playing", DONE), false), "not_ready", "stage done in the blind")
eq(button(view(nil), false), "not_ready", "no blind")

-- The press.
same(press(view("waiting", "not ready"), false), { ready = true, blindKey = "2:Boss" }, "press asks ready")
same(press(view("waiting", "ready"), false), { ready = false, blindKey = "2:Boss" }, "press asks unready")
same(press(view("waiting", "not ready"), pressed(true)), { ready = false, blindKey = "2:Boss" }, "a second press before the server answers cancels")
same(press(view("waiting", "not ready"), pressed(false)), { ready = true, blindKey = "2:Boss" }, "a third press asks ready again")
eq(press(nil, false), nil, "no view, no press")
eq(press(view("playing", NOT_ENTERED), false), nil, "no press once the blind plays")
eq(PVP.view.pvp_blind_key(3), "3:Boss", "blind key")

-- The first Ready: with no blind of mine open it goes out.
local function no_pvp_blind_view(status, patch)
	local v = view(nil)
	v.players.a.status = status
	v.match.run.finishedPvpBlinds = {}
	if patch then patch(v) end
	return v
end
same(press(no_pvp_blind_view("playing"), false), { ready = true, blindKey = "2:Boss" }, "no blind open yet: a ready input goes out")
eq(button(no_pvp_blind_view("playing"), pressed(true)), "ready", "the first press shows ready before the view confirms")
eq(button(no_pvp_blind_view("playing"), false), "not_ready", "no blind yet: not shown as ready")
same(press(no_pvp_blind_view("playing"), pressed(true)), { ready = false, blindKey = "2:Boss" }, "first press unconfirmed: a second press cancels it")
eq(press(no_pvp_blind_view("playing", function(v) v.match.run.finishedPvpBlinds = { { blindKey = "2:Boss" } } end), false), nil, "this blind's blind is over: refused")
same(press(no_pvp_blind_view("playing", function(v) v.match.run.finishedPvpBlinds = { { blindKey = "1:Boss" } } end), false), { ready = true, blindKey = "2:Boss" }, "an earlier blind's blind does not block")
-- Away is how the view shows me until the server sees me back after a rejoin; the server takes the press.
same(press(no_pvp_blind_view("away"), false), { ready = true, blindKey = "2:Boss" }, "me away: the press goes out")
eq(press(no_pvp_blind_view("out"), false), nil, "me out: refused")
eq(press(no_pvp_blind_view("left"), false), nil, "me left: refused")
eq(press(no_pvp_blind_view(nil), false), nil, "my status unknown: refused")
eq(press({ me = "a", players = { a = { status = "playing" } }, match = {} }, false), nil, "no run: refused")

-- Every answer about my Boss: "plays" and "bye" release the first Ready; the rest hold and send nothing.
local function with_boss(answer)
	return no_pvp_blind_view("playing", function(v) v.match.run.targets.myBoss = answer end)
end
eq(button(with_boss("plays"), false), "not_ready", "myBoss plays: the normal look")
same(press(with_boss("plays"), false), { ready = true, blindKey = "2:Boss" }, "myBoss plays: the press goes out")
eq(button(with_boss("bye"), false), "not_ready", "myBoss bye: the normal look")
same(press(with_boss("bye"), false), { ready = true, blindKey = "2:Boss" }, "a bye presses Ready too")
eq(button(with_boss("no pvp this ante"), false), "held", "myBoss no pvp this ante: no Ready look")
eq(press(with_boss("no pvp this ante"), false), nil, "no pvp this ante: nothing sent")
eq(button(with_boss("something new"), false), "held", "an answer this mod does not know holds")
eq(button(no_pvp_blind_view("playing", function(v) v.match.run.targets = nil end), false), "held", "no targets yet: held")
eq(button(with_boss("no pvp this ante"), pressed(true)), "held", "held wins over an unconfirmed press")
eq(button({ me = "a", match = {} }, false), "waiting", "no run in the view: waiting")
eq(button(view("waiting", "ready", "no pvp this ante"), false), "ready", "a blind of mine is never held")

-- A blind open for another blind, or another pair, is not mine to read (362): it shows no Ready.
local function other_pvp_blind(blind_key, stage, part)
	local v = no_pvp_blind_view("playing")
	v.match.run.currentPvpBlind = { stage = stage, blindKey = blind_key, players = { a = part, b = part, c = part } }
	return v
end
eq(button(other_pvp_blind("1:Boss", "waiting", "ready"), false), "not_ready", "a leftover waiting blind of an earlier Boss: the normal look")
eq(button(other_pvp_blind("1:Boss", "playing", PLAYED), false), "not_ready", "a leftover playing blind of an earlier Boss: the normal look")
eq(press(other_pvp_blind("1:Boss", "playing", PLAYED), false) ~= nil, true, "a leftover playing blind does not hold the press")
eq(press(other_pvp_blind("1:Boss", "waiting", "ready"), false) ~= nil, true, "a leftover waiting blind does not hold the press")
eq(button(other_pvp_blind("3:Boss", "waiting", "ready"), false), "not_ready", "a blind of a later Boss: the normal look")
eq(reader.entry_key(other_pvp_blind("1:Boss", "playing", PLAYED), 2), nil, "a leftover blind has no entry key here")
eq(reader.entry_key(view("playing", NOT_ENTERED), 2), "run1/2:Boss", "the entry key of this Boss's blind")
local not_in_pvp_blind = view("waiting", "ready")
not_in_pvp_blind.match.run.currentPvpBlind.players = { b = "ready", c = "ready" }
eq(press(not_in_pvp_blind, false), nil, "a blind of this Boss I am not in: nothing sent")

-- The answer is about the ante the game is on: one about another ante, or none, holds and sends nothing.
eq(reader.ready_button(with_boss("plays"), false, nil, 3), "held", "an answer about an earlier ante holds")
eq(reader.ready_button(with_boss("plays"), false, nil, 1), "held", "an answer about a later ante holds")
eq(reader.ready_button(with_boss("plays"), false, nil, nil), "held", "unknown game ante holds")
eq(reader.press(with_boss("plays"), false, 3), nil, "no press on another ante's answer")
eq(reader.ready_held(no_pvp_blind_view("playing", function(v) v.match.run.players = nil end), 2), true, "no ante in the view holds")

-- The team picker.
same(reader.team_look(view("waiting", "not ready"), true), { state = "waiting" }, "unconfirmed pick: neutral, no team claimed")
same(reader.team_look(view("waiting", "not ready"), false), { state = "picked", team = "HUNTER" }, "otherwise the view's team")
same(reader.team_look(nil, false), { state = "not picked" }, "no view, no team")

-- Which button enters the blind.
eq(reader.entry_button({ saved_button = true, on_boss = true, boss_button = true }), "saved", "the press's button first")
eq(reader.entry_button({ saved_button = false, on_boss = true, boss_button = true }), "boss", "no saved button: the boss option")
eq(reader.entry_button({ saved_button = false, on_boss = false, boss_button = true }), nil, "boss option only on the boss blind")
eq(reader.entry_button({ saved_button = false, on_boss = true, boss_button = false }), nil, "no button at all")

-- Teams.
same(reader.teams(view("waiting", "not ready")), { a = "HUNTER" }, "team shown, none picked has no entry")
same(reader.teams(nil), {}, "no view, no teams")

-- Blind entry.
local game = { at_blind_select = true, inbox_done = 4, button = "boss", blind_key = "2:Boss" }
local key, entry = reader.next_entry(nil, view("playing", NOT_ENTERED), game)
eq(key, "run1/2:Boss", "entry key")
same(entry, { kind = "fresh", blind_key = "2:Boss" }, "stage not entered: send blindStart")
key, entry = reader.next_entry(nil, view("playing", ENTERED), game)
same(entry, { kind = "already playing", blind_key = "2:Boss" }, "stage entered: no blindStart")
key, entry = reader.next_entry(nil, view("playing", PLAYED), game)
same(entry, { kind = "already playing", blind_key = "2:Boss" }, "stage played a hand: no blindStart")
eq(select(2, reader.next_entry(nil, view("waiting", "ready"), game)), nil, "blind waiting does not enter")
eq(select(2, reader.next_entry(nil, view("playing", DONE), game)), nil, "stage done does not enter")
eq(select(2, reader.next_entry(nil, view("playing", NOT_ENTERED), { at_blind_select = false, inbox_done = 4, button = "boss", blind_key = "2:Boss" })), nil, "not at blind select")
eq(select(2, reader.next_entry(nil, view("playing", NOT_ENTERED), { at_blind_select = true, inbox_done = 3, button = "boss", blind_key = "2:Boss" })), nil, "items not done")
eq(select(2, reader.next_entry(nil, view("playing", NOT_ENTERED), { at_blind_select = true, inbox_done = 4, button = "boss", blind_key = "3:Boss" })), nil, "a blind of another Boss than the game's is not entered")
eq(select(2, reader.next_entry(nil, view("playing", NOT_ENTERED), { at_blind_select = true, inbox_done = 4, button = "boss" })), nil, "no game blind: nothing entered")
eq(select(2, reader.next_entry(nil, nil, game)), nil, "no view")
-- A rejoin's replay plays the recorded select_blind itself: entering from the view too would take the blind
-- select from it, and the recorded hand would find no cards.
local replaying = { at_blind_select = true, inbox_done = 4, button = "boss", blind_key = "2:Boss", run = "replaying" }
local replay_key, replay_entry = reader.next_entry(nil, view("playing", NOT_ENTERED), replaying)
eq(replay_entry, nil, "a replay does not enter the blind from the view")
eq(replay_key, nil, "a replay does not mark the blind entered")
local live = { at_blind_select = true, inbox_done = 4, button = "boss", blind_key = "2:Boss", run = "live" }
eq(select(2, reader.next_entry(nil, view("playing", NOT_ENTERED), live)) ~= nil, true, "a live run enters")
local no_button = { at_blind_select = true, inbox_done = 4, blind_key = "2:Boss" }
local held, held_command = reader.next_entry(nil, view("playing", NOT_ENTERED), no_button)
eq(held_command, nil, "no button: not entered")
eq(held, nil, "no button: not marked entered, so it is tried again")
key, entry = reader.next_entry(held, view("playing", NOT_ENTERED), game)
eq(entry ~= nil, true, "the button appears: entered then")

-- Exactly once across repeated identical views.
local entered, fired = nil, 0
for _ = 1, 5 do
	local command_now
	entered, command_now = reader.next_entry(entered, view("playing", NOT_ENTERED), game)
	if command_now then fired = fired + 1 end
end
eq(fired, 1, "entry fires once for repeated identical views")
local next_pvp_blind = view("playing", NOT_ENTERED)
next_pvp_blind.match.run.currentPvpBlind.blindKey = "3:Boss"
entered, entry = reader.next_entry(entered, next_pvp_blind, { at_blind_select = true, inbox_done = 4, button = "boss", blind_key = "3:Boss" })
eq(entry ~= nil, true, "the next blind enters again")

print("entry_reader_test: ok (" .. checks .. " checks)")
