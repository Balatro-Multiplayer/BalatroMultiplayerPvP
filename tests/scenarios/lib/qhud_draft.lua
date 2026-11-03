-- Draft simulator for qhud_sim.lua: a fake server-refereed lobby whose Setup referee runs
-- here, so the walkthrough continues past the match reveal into the real matchmaking lobby
-- view and the real ranked Draft (MPAPI.BanPick, configured by PVP._ban_pick_config_for),
-- against a bot. The referee follows the server's Draft rules (BalatroMultiplayerServer
-- nakama/src/actions/setup.ts) only as far as the 2-player schedule needs: a random first
-- actor, a turn clock that bans or picks at random when it runs out, then the survivors.
local DRAFT = rawget(_G, "QHUD_DRAFT") or {}
QHUD_DRAFT = DRAFT

DRAFT.RULESET, DRAFT.QUEUE_MODE = "ruleset_mp_expanded", "pvp_nemesis"
DRAFT.TURN_SECONDS, DRAFT.BOT_THINK, DRAFT.BOT_BETWEEN = 30, 1.4, 0.6
local ME, BOT = "me", "opp"

local function now()
	return love.timer.getTime()
end

-- Events die with the lobby they were scheduled for.
local function after(lobby, delay, fn)
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = delay,
		timer = "REAL",
		blockable = false,
		blocking = false,
		no_delete = true,
		func = function()
			if DRAFT.lobby == lobby then fn() end
			return true
		end,
	}))
end

local function copy(list)
	local out = {}
	for i, v in ipairs(list or {}) do
		out[i] = v
	end
	return out
end

-----------------------------
-- The referee
-----------------------------

local function publish(lobby, open)
	local setup = lobby._game.setup
	lobby._game.setup = { open = open, results = setup.results, received_at = now() }
	lobby:_fire(MPAPI.LobbyEvent.SETUP_CHANGED, lobby._game.setup)
end

local function unbanned(d)
	local banned, out = {}, {}
	for _, key in ipairs(d.banned) do
		banned[key] = true
	end
	for _, item in ipairs(d.pool) do
		if not banned[item.key] then out[#out + 1] = item end
	end
	return out
end

local function finish(lobby, survivors)
	local d = lobby._draft
	d.turn_token = nil
	lobby._game.setup.results[d.id] = { kind = "draft", survivors = survivors, banned = copy(d.banned) }
	publish(lobby, nil)
end

local open_turn

local function choose(lobby, actor, key)
	local d = lobby._draft
	local step = d and d.turn_token and d.schedule[d.turn + 1]
	if not step or d.slots[step.actor] ~= actor then return "not_your_turn" end
	local item
	for _, candidate in ipairs(unbanned(d)) do
		if candidate.key == key then item = candidate end
	end
	if not item then return "unknown_key" end
	if step.action == "pick" then
		finish(lobby, { item })
		return
	end
	d.banned[#d.banned + 1] = key
	d.remaining = d.remaining - 1
	if d.remaining > 0 then
		publish(lobby, d.open())
		return
	end
	d.turn = d.turn + 1
	open_turn(lobby)
end

local function random_choice(lobby, actor)
	local left = unbanned(lobby._draft)
	if #left > 0 then choose(lobby, actor, left[love.math.random(#left)].key) end
end

local function bot_moves(lobby, token, delay)
	after(lobby, delay, function()
		local d = lobby._draft
		if d.turn_token ~= token then return end
		random_choice(lobby, BOT)
		if d.turn_token == token then bot_moves(lobby, token, DRAFT.BOT_BETWEEN) end
	end)
end

open_turn = function(lobby)
	local d = lobby._draft
	local step = d.schedule[d.turn + 1]
	if not step then
		finish(lobby, unbanned(d))
		return
	end
	local actor = d.slots[step.actor]
	local token = {}
	d.turn_token, d.remaining, d.deadline = token, step.count, now() + DRAFT.TURN_SECONDS
	publish(lobby, d.open())
	after(lobby, DRAFT.TURN_SECONDS, function()
		for _ = 1, step.count do
			if d.turn_token ~= token then break end
			random_choice(lobby, actor)
		end
	end)
	if actor == BOT then bot_moves(lobby, token, DRAFT.BOT_THINK) end
end

local function start_draft(lobby, params)
	if lobby._draft then return "already_open" end
	local pool = copy(params.candidates)
	for i = #pool, 2, -1 do
		local j = love.math.random(i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	for i = #pool, (params.poolSize or #pool) + 1, -1 do
		pool[i] = nil
	end
	local slots = love.math.random(2) == 1 and { ME, BOT } or { BOT, ME }
	local d = { id = params.id, pool = pool, banned = {}, schedule = params.schedule, slots = slots, turn = 0 }
	function d.open()
		return {
			kind = "draft",
			id = d.id,
			pool = d.pool,
			banned = copy(d.banned),
			first = slots[1],
			schedule = d.schedule,
			turn = d.turn,
			remaining = d.remaining,
			actor = slots[d.schedule[d.turn + 1].actor],
			msLeft = math.max(0, d.deadline - now()) * 1000,
		}
	end
	lobby._draft = d
	open_turn(lobby)
end

local RECEIVERS = {
	mpapi_setup_draft = start_draft,
	mpapi_setup_choose = function(lobby, params)
		return choose(lobby, ME, params.key)
	end,
}

-----------------------------
-- The lobby
-----------------------------

local function new_lobby(players)
	local handlers = {}
	local lobby = {
		_nakama = true,
		code = "QHUDSIM",
		mod_id = PVP.id,
		player_id = ME,
		is_host = true,
		max_players = 2,
		_game = { setup = { results = {} } },
		-- The lobby view's player grid reads players by id.
		_players = setmetatable({}, {
			__index = function(_, id)
				for _, p in ipairs(players) do
					if p.id == id then return p end
				end
			end,
		}),
	}
	function lobby:get_players()
		return players
	end
	function lobby:get_metadata()
		return { queue_mode = DRAFT.QUEUE_MODE, ruleset = DRAFT.RULESET }
	end
	function lobby:on(event, fn)
		handlers[event] = handlers[event] or {}
		table.insert(handlers[event], fn)
	end
	function lobby:_fire(event, ...)
		for _, fn in ipairs(handlers[event] or {}) do
			fn(...)
		end
	end
	function lobby:action(action_type)
		local key = type(action_type) == "table" and action_type.key or action_type
		local builder = {}
		function builder:callback(cb)
			self.cb = cb
			return self
		end
		function builder:send(_, params)
			local receive = RECEIVERS[key]
			local reason = receive and receive(lobby, params or {}) or (not receive and "unknown_target")
			if self.cb then
				self.cb(nil, nil, reason and MPAPI.make_error(MPAPI.ErrorKind.ACTION_REJECTED, reason) or nil)
			end
		end
		builder.broadcast = builder.send
		return builder
	end
	return lobby
end

local function pvp_mod()
	return MPAPI._internal.mod_registry.registered_mods[PVP.id]
end

local function reset_lobby_view()
	local L = PVP.lobby
	L.ref, L.ui_ref, L.buttons_initialized = nil, nil, false
end

-- players: the reveal's { { id = "me" }, { id = "opp" } }. on_picked(item): the drafted
-- { key, stake } (stake is an index into G.P_CENTER_POOLS.Stake).
function DRAFT.start(players, on_picked)
	DRAFT.stop({ keep_page = true })
	local lobby = new_lobby(players)
	DRAFT.lobby = lobby
	DRAFT.real = {
		get_current_lobby = MPAPI.get_current_lobby,
		leave = G.FUNCS.mp_pvp_leave_lobby,
		kind = PVP._pvp_kind,
	}
	MPAPI.get_current_lobby = function()
		return lobby
	end
	G.FUNCS.mp_pvp_leave_lobby = function()
		DRAFT.on_leave()
	end
	PVP._pvp_kind = PVP.LobbyAccess.RANKED
	reset_lobby_view()
	local mod = pvp_mod()
	MPAPI.pages.show(mod.lobby_ui, { mod = mod, lobby = lobby })
	local gm_def = MPAPI.GameModes[DRAFT.QUEUE_MODE]
	MPAPI.BanPick.start(lobby, PVP._ban_pick_config_for(gm_def, DRAFT.RULESET), function(survivors)
		on_picked(survivors[1])
	end)
end

-- opts.keep_page leaves the menu page alone (a restart, or a run about to start).
function DRAFT.stop(opts)
	local lobby = DRAFT.lobby
	if not lobby then return end
	-- MPAPI.BanPick drops an unfinished Draft when its game ends.
	lobby:_fire(MPAPI.LobbyEvent.GAME_ENDED, {})
	DRAFT.lobby = nil
	MPAPI.get_current_lobby = DRAFT.real.get_current_lobby
	G.FUNCS.mp_pvp_leave_lobby = DRAFT.real.leave
	PVP._pvp_kind = DRAFT.real.kind
	DRAFT.real = nil
	reset_lobby_view()
	local mod = pvp_mod()
	if not (opts and opts.keep_page) and G.STAGE == G.STAGES.MAIN_MENU and mod then
		MPAPI.pages.show(mod.main_menu_ui, { mod = mod })
	end
end

-- The lobby view's Leave button; qhud_sim.lua points it at its own stop.
DRAFT.on_leave = DRAFT.stop
DRAFT._choose = choose

return DRAFT
