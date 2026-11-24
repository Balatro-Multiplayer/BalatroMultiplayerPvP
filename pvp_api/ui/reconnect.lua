-- The small line that stays on screen once the big "waiting for reconnection" notice is dismissed:
-- "X reconnecting... 1:42" counting down to when the server forfeits X, and for a few seconds
-- "X reconnected" once they are back. lobby_bridge.lua owns when the big notice is up and reads
-- who is away from the lobby roster; it feeds this module through `sync` and `add_back`.
-- `on_frame` is the bridge's once-a-frame check. Times are love.timer.getTime() seconds.
-- In a PvP run pvp_api/ui/away.lua owns the line for other players; only my own drop and the
-- "reconnected" message show here.
local screen = {}
PVP.UI.reconnect = screen

local BACK_SECONDS = 4

-- id -> { who = "me" } or { who = "other", name = string, forfeits_at = number|nil }
local entries = {}
local visible = false
local backs = {} -- { name = string, ends_at = number }
local shown
local words = { text = "" }

-- "m:ss" for the whole seconds left, never below 0:00.
function screen.clock(forfeits_at, now)
	local left = math.max(0, math.ceil(forfeits_at - now))
	return string.format("%d:%02d", math.floor(left / 60), left % 60)
end

-- The line to show now, or nil for none. My own drop wins; then the away players, counting down to
-- the soonest forfeit; then those back.
function screen.text(away, show, back_list, now, in_run)
	if show then
		local names, soonest = {}, nil
		for _, entry in pairs(away) do
			if entry.who == "me" then return localize("k_mp_reconnecting_line") end
			if not in_run then
				names[#names + 1] = entry.name
				if entry.forfeits_at and (not soonest or entry.forfeits_at < soonest) then soonest = entry.forfeits_at end
			end
		end
		if #names > 0 then
			table.sort(names)
			local joined = table.concat(names, ", ")
			if soonest then
				return localize({ type = "variable", key = "k_pvp_player_reconnecting_timed", vars = { joined, screen.clock(soonest, now) } })
			end
			return localize({ type = "variable", key = "k_pvp_player_reconnecting", vars = { joined } })
		end
	end
	local back = {}
	for _, item in ipairs(back_list) do
		if item.ends_at > now then back[#back + 1] = item.name end
	end
	if #back > 0 then
		return localize({ type = "variable", key = "k_pvp_player_reconnected", vars = { table.concat(back, ", ") } })
	end
	return nil
end

-- The away players to name, and whether the line shows them (the big notice is down).
function screen.sync(away, show)
	entries = away
	visible = show
end

function screen.add_back(name, now)
	backs[#backs + 1] = { name = name, ends_at = now + BACK_SECONDS }
end

-- A new lobby's bridge takes the screen: nothing of an older lobby stays on it.
function screen.adopt(on_frame)
	entries, visible, backs = {}, false, {}
	screen.on_frame = on_frame
end

function screen.clear()
	entries, visible, backs = {}, false, {}
	screen.on_frame = nil
	screen.hide()
end

function screen.hide()
	if not shown then return end
	if not shown.box.REMOVED then shown.box:remove() end
	shown = nil
end

-- One line of a banner: a fixed text, or a `{ text = ... }` table whose text is shown live.
function screen.banner_row(words_or_text, scale)
	local config = { scale = scale, colour = G.C.UI.TEXT_LIGHT, shadow = true }
	if type(words_or_text) == "table" then
		config.ref_table, config.ref_value = words_or_text, "text"
	else
		config.text = words_or_text
	end
	return { n = G.UIT.R, config = { align = "cm" }, nodes = { { n = G.UIT.T, config = config } } }
end

-- The red banner at the top of the game around `rows`; pvp_api/ui/away.lua builds its notice with it too.
function screen.banner(rows, padding)
	return UIBox({
		definition = {
			n = G.UIT.ROOT,
			config = { align = "cm", colour = G.C.CLEAR },
			nodes = {
				{ n = G.UIT.R, config = { align = "cm", padding = padding, r = 0.1, colour = G.C.RED, emboss = 0.05 }, nodes = rows },
			},
		},
		config = { align = "tmi", offset = { x = 0, y = 0.3 }, major = G.ROOM_ATTACH, bond = "Weak" },
	})
end

-- The line as it reads at `now`; nil when none shows.
function screen.shown_text(now)
	local kept = {}
	for _, item in ipairs(backs) do
		if item.ends_at > now then kept[#kept + 1] = item end
	end
	backs = kept
	return screen.text(entries, visible, backs, now, PVP.UI.away.in_run())
end

function screen.update()
	if screen.on_frame then screen.on_frame() end
	local text = screen.shown_text(love.timer.getTime())
	if not text then return screen.hide() end
	words.text = text
	if not (shown and shown.room == G.ROOM and not shown.box.REMOVED) then
		screen.hide()
		shown = { room = G.ROOM, box = screen.banner({ screen.banner_row(words, 0.35) }, 0.08) }
	end
end

return screen
