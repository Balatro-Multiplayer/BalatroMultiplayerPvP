-- Multi-client scenario helpers. scripts/run_pair.sh launches one client per role (host and
-- guest unless the scenario names its own) on the same scenario file; these build ordinary
-- runner steps, so the MPAPI runner is unchanged.
local role = os.getenv("BMP_ROLE")
local dir = os.getenv("BMP_PAIR_DIR")
-- Every role in this run (the scenario's `-- roles:` line, else host and guest).
local roles = {}
for name in (os.getenv("BMP_ROLES") or "host guest"):gmatch("%S+") do
	roles[#roles + 1] = name
end
local listed = false
for _, name in ipairs(roles) do
	listed = listed or name == role
end
assert(listed and dir, "pair scenarios run under scripts/run_pair.sh")

local P = { role = role, roles = roles }

local function path(name)
	return dir .. "/" .. name
end

local function write(name, value)
	local file = assert(io.open(path(name), "w"))
	file:write(value or "")
	file:close()
end

local function read(name)
	local file = io.open(path(name), "r")
	if not file then return nil end
	local value = file:read("*a")
	file:close()
	return value
end

-- Values one side hands the other, e.g. a lobby code.
function P.put(key, value)
	write("value." .. key, tostring(value))
end

function P.get(key)
	return read("value." .. key)
end

-- A step only one role (or a list of roles) performs; the rest pass straight through.
local function only(who, step)
	if who == role then return step end
	if type(who) == "table" then
		for _, name in ipairs(who) do
			if name == role then return step end
		end
	end
	return { wait = 0 }
end
P.only = only

-- Flattens step lists (P.lobby etc. return several steps) into one scenario.
function P.steps(...)
	local out = {}
	for _, item in ipairs({ ... }) do
		if item[1] then
			for _, step in ipairs(item) do
				out[#out + 1] = step
			end
		elseif next(item) then
			out[#out + 1] = item
		end
	end
	return out
end

-- Every role waits here until all the others arrive.
function P.sync(label, timeout)
	local arrived = false
	return {
		wait = 0,
		timeout = timeout or 60,
		until_ = function()
			if not arrived then
				write("sync." .. label .. "." .. role)
				arrived = true
			end
			for _, name in ipairs(roles) do
				if read("sync." .. label .. "." .. name) == nil then return false end
			end
			return true
		end,
	}
end

-- Logged in through the Dev mod's Device login. A fresh test account answers the
-- server's age question the way the Notice overlay would.
function P.connect()
	return {
		until_ = function()
			local state = MPAPI.connection_state.state
			local conn = MPAPI._internal.conn and MPAPI._internal.conn.connection
			if state == MPAPI.ConnectionState.TOS_REQUIRED and conn then conn:accept_tos(true) end
			return state == MPAPI.ConnectionState.CONNECTED
		end,
		timeout = 30,
		run = function(S)
			S.check(true, role .. " connected")
		end,
	}
end

local function lobby()
	return MPAPI.get_current_lobby()
end

-- Host creates a private lobby and hands its code over; configure(config) may
-- change PVP.LOBBY.config before the metadata goes out. Guest joins it. Both
-- wait until two players are in.
function P.lobby(gamemode, configure)
	return {
		only("host", {
			run = function()
				PVP.pvp_create_private_lobby(gamemode)
			end,
		}),
		only("host", {
			until_ = function()
				return lobby() and lobby().code and lobby().is_host
			end,
			timeout = 20,
			run = function()
				if configure then configure(PVP.LOBBY.config) end
				lobby():set_metadata(PVP.pvp_lobby_metadata(gamemode, PVP.LobbyAccess.PRIVATE))
				P.put("lobby", lobby().code)
			end,
		}),
		only("guest", {
			until_ = function()
				return P.get("lobby") ~= nil
			end,
			timeout = 30,
			run = function()
				PVP.pvp_join_lobby(P.get("lobby"))
			end,
		}),
		{
			until_ = function()
				return lobby() and #lobby():get_players() == 2
			end,
			timeout = 30,
			run = function(S)
				S.check(true, role .. " sees both players in " .. tostring(lobby().code))
			end,
		},
	}
end

-- Guest readies, host starts once the guest's ready reaches it.
function P.start()
	return {
		only("guest", {
			run = function()
				G.FUNCS.mp_pvp_toggle_ready()
				P.put("guest_ready", 1)
			end,
		}),
		only("host", {
			until_ = function()
				return P.get("guest_ready") ~= nil
			end,
			timeout = 30,
			wait = 2,
			run = function()
				PVP.pvp_start_match()
			end,
		}),
	}
end

-- Plays out the pre-run stake Draft (if any) with random picks, until the
-- first blind select.
function P.reach_blind_select()
	return {
		until_ = function()
			if MPAPI.BanPick.is_active() then
				G.FUNCS.mpapi_ban_pick_random()
				G.FUNCS.mpapi_ban_pick_confirm()
			end
			return G.STATE == G.STATES.BLIND_SELECT and G.blind_select_opts ~= nil
		end,
		timeout = 90,
		run = function(S)
			S.check(G.GAME.round_resets.ante == 1, role .. " in ante 1 blind select")
		end,
	}
end

-- Fixture: from a blind select, jump to this ante with Small and Big already
-- skipped, so the next blind is the PvP boss. The referee hears the ante as it
-- would from ease_ante. The blind select rebuilds on the next update.
function P.jump_to_pvp(ante)
	return {
		run = function()
			local resets = G.GAME.round_resets
			if resets.ante ~= ante then PVP.ACTIONS.set_ante(ante) end
			resets.ante, resets.blind_ante = ante, ante
			resets.blind_states.Boss = "Defeated"
			reset_blinds()
			resets.blind_states = { Small = "Skipped", Big = "Skipped", Boss = "Select" }
			G.GAME.blind_on_deck = "Boss"
			if G.blind_select then
				G.blind_select:remove()
				G.blind_select = nil
			end
			if G.blind_prompt_box then
				G.blind_prompt_box:remove()
				G.blind_prompt_box = nil
			end
			G.STATE_COMPLETE = false
		end,
	}
end

-- Saves this side's next frame as <role>.<name>.png in the run dir. The capture
-- lands at the end of the frame, so give the next step a short wait.
function P.screenshot(name)
	love.graphics.captureScreenshot(function(image)
		local file = assert(io.open(path(role .. "." .. name .. ".png"), "wb"))
		file:write(image:encode("png"):getString())
		file:close()
	end)
end

-- Progress lines for debugging; run_pair.sh keeps them, the verdict ignores them.
function P.note(message)
	sendInfoMessage("BMP_SCENARIO NOTE " .. role .. " " .. message, "MPAPI")
end

local last_state
function P.note_state()
	if G.STATE ~= last_state then
		last_state = G.STATE
		for name, value in pairs(G.STATES) do
			if value == G.STATE then P.note("state " .. name) end
		end
	end
end

local function boss_button()
	local opts = G.blind_select_opts and G.blind_select_opts.boss
	return opts and opts:get_UIE_by_ID("select_blind_button")
end

-- The cash out button is its own UIBox (attached to G.round_eval, not inside it),
-- so look through every live UIBox.
local function find_button(id)
	for _, box in ipairs(G.I.UIBOX) do
		local button = box.get_UIE_by_ID and box:get_UIE_by_ID(id)
		if button and button.config.button then return button end
	end
end

-- From round eval: cash out and leave the shop, until the next blind select or
-- until stop() (e.g. an overlay that gates the shop).
function P.next_round(stop)
	return {
		until_ = function()
			P.note_state()
			if stop and stop() then return true end
			if not G.CONTROLLER.locked then
				local button = G.STATE == G.STATES.ROUND_EVAL and find_button("cash_out_button")
					or G.STATE == G.STATES.SHOP and find_button("next_round_button")
				if button then button:click() end
			end
			return G.STATE == G.STATES.BLIND_SELECT and G.blind_select_opts ~= nil
		end,
		timeout = 60,
	}
end

-- Readies for the PvP boss, runs any between steps, then
-- plays leftmost-card hands until the round resolves on this side. Real cards,
-- real scoring, real referee. Host plays five cards, guest one, so the shared
-- seed doesn't make every blind a tie.
function P.play_pvp_blind(between)
	local cards = role == "host" and 5 or 1
	local played_at
	local ready = {
		until_ = function()
			local button = boss_button()
			return G.STATE == G.STATES.BLIND_SELECT and button and button.config.button == "mp_toggle_ready"
		end,
		timeout = 60,
		run = function(S)
			S.check(G.GAME.round_resets.blind_choices.Boss == "bl_mp_nemesis", role .. " boss is the PvP blind")
			boss_button():click()
		end,
	}
	return P.steps(ready, between or {}, {
		until_ = function()
			P.note_state()
			return G.STATE == G.STATES.SELECTING_HAND
		end,
		timeout = 60,
	}, {
		wait = 0.2,
		until_ = function()
			P.note_state()
			-- The state and hands_left change a few frames after a play, so
			-- played_at keeps it to one play per hand.
			local left = G.GAME.current_round.hands_left
			if
				G.STATE == G.STATES.SELECTING_HAND
				and left > 0
				and left ~= played_at
				and #G.hand.cards > 0
				and not G.CONTROLLER.locked
			then
				played_at = left
				G.hand:unhighlight_all()
				for i = 1, math.min(cards, #G.hand.cards) do
					G.hand:add_to_highlighted(G.hand.cards[i], true)
				end
				P.note("play hand, hands_left=" .. G.GAME.current_round.hands_left)
				G.FUNCS.play_cards_from_highlighted()
			end
			return G.STATE == G.STATES.ROUND_EVAL or G.STATE == G.STATES.SHOP or G.STATE == G.STATES.GAME_OVER
		end,
		timeout = 180,
		run = function(S)
			S.check(true, role .. " PvP blind resolved, state " .. tostring(G.STATE))
		end,
	})
end

-- The fields both clients must agree on. Per-player fields are keyed by role
-- (lives_host, lives_guest), never mine/theirs, so the two lines compare byte for byte.
local function project()
	local mine, theirs = PVP.GAME and PVP.GAME.lives, PVP.GAME and PVP.GAME.enemy and PVP.GAME.enemy.lives
	return {
		ante = G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante,
		lives_host = role == "host" and mine or theirs,
		lives_guest = role == "guest" and mine or theirs,
		stake = G.GAME and G.GAME.stake or "-",
	}
end

local function encode(fields)
	local keys = {}
	for key in pairs(fields) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	for i, key in ipairs(keys) do
		keys[i] = key .. "=" .. tostring(fields[key])
	end
	return table.concat(keys, " ")
end

-- Logs this side's view; run_pair.sh diffs host against guest per label.
function P.snapshot(label)
	return {
		wait = 2, -- Let the last lives/outcome messages land.
		run = function()
			sendInfoMessage("BMP_SCENARIO STATE " .. label .. " " .. encode(project()), "MPAPI")
		end,
	}
end

return P
