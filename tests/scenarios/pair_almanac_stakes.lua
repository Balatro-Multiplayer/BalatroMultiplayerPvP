-- Almanac's pre-run stake Draft, turn by turn: the board the server deals, three
-- alternating bans and the second player's pick, each made by clicking the real
-- tile and the Confirm button, then the run starting on the picked stake.
-- Screenshots of the board, a stake chip's popup, the waiting side and every
-- turn land in the run dir. Run with scripts/run_pair.sh pair_almanac_stakes.
local P = assert(SMODS.load_file("tests/scenarios/lib/pair.lua", "MultiplayerPvP"))()

local variant = os.getenv("BMP_STAKE_VARIANT") or "planet"
assert(variant == "planet" or variant == "spectral" or variant == "neither", "unknown stake variant")
local replacement_roll = ({ planet = 0, spectral = 0.25, neither = 0.5 })[variant]

local function stake_key(index)
	local center = G.P_CENTER_POOLS.Stake[tonumber(index)]
	return center and center.key or tostring(index)
end

local function open_draft()
	local lobby = MPAPI.get_current_lobby()
	local open = lobby and MPAPI.Setup.open_step(lobby)
	if open and open.kind == "draft" then return open, lobby end
end

-- The rendered tile for a pool key. A Setup change rebuilds the overlay, so look
-- it up each time rather than keeping the card.
local function tile(key)
	for _, card in ipairs(G.I.CARD) do
		if card.mp_deck_key == key and not card.REMOVED then return card end
	end
end

-- Surviving pool items in display order.
local function survivors(open)
	local banned, out = {}, {}
	for _, key in ipairs(open.banned or {}) do
		banned[key] = true
	end
	for _, item in ipairs(open.pool) do
		if not banned[item.key] then out[#out + 1] = item end
	end
	table.sort(out, PVP.DRAFT.almanac_tile_order)
	return out
end

local function sorted_stakes(pool)
	local keys = {}
	for _, item in ipairs(pool) do
		keys[#keys + 1] = stake_key(item.stake)
	end
	table.sort(keys)
	return table.concat(keys, ",")
end

local function now()
	return love.timer.getTime()
end

-- The board is pinned to White- and the requested variant. Bans take the
-- last surviving tile that isn't White-, and the pick takes White-, so every run
-- starts on White- and checks its vouchers.
local function is_white_minus(item)
	return stake_key(item.stake) == "stake_mp_white_minus"
end
local seen_at, board_shot, waiting_shot
local done, phase, phase_at, turn, chosen, action = {}, nil, 0, nil, nil, nil
local draft = {
	until_ = function()
		local open, lobby = open_draft()
		if open and MPAPI.BanPick.is_active() then
			seen_at = seen_at or now()
			local step = MPAPI.Setup.draft_turn(lobby)
			local mine = MPAPI.Setup.is_my_turn(lobby)
			local t = #(open.banned or {}) + 1
			if not board_shot and now() - seen_at > 1 then
				board_shot = true
				P.screenshot("board")
			elseif not waiting_shot and not mine and now() - seen_at > 1.5 then
				waiting_shot = true
				P.screenshot("waiting_turn" .. t)
			elseif phase == nil and mine and step and not done[t] and now() - seen_at > 2 then
				local item
				for _, candidate in ipairs(survivors(open)) do
					if is_white_minus(candidate) == (step.action == "pick") then item = candidate end
				end
				local card = item and tile(item.key)
				if card then
					card:click()
					turn, chosen, action, phase, phase_at = t, item, step.action, "selected", now()
				end
			elseif phase == "selected" and now() - phase_at > 0.6 then
				P.screenshot("turn" .. turn .. "_" .. action)
				phase, phase_at = "shot", now()
			elseif phase == "shot" and now() - phase_at > 0.4 then
				G.FUNCS.mpapi_ban_pick_confirm()
				P.put("turn_" .. turn, P.role .. ":" .. action .. ":" .. stake_key(chosen.stake))
				P.note("turn " .. turn .. " " .. action .. " " .. stake_key(chosen.stake))
				done[turn], phase = true, nil
			end
		end
		return G.STATE == G.STATES.BLIND_SELECT and G.blind_select_opts ~= nil
	end,
	timeout = 120,
}

-- First sight of the board: five Almanac tiles, the agreed stake set, and a
-- stake chip's popup on the host.
local board = {
	until_ = function()
		local open = open_draft()
		return open and MPAPI.BanPick.is_active() and tile(open.pool[1].key) ~= nil
	end,
	timeout = 60,
	run = function(S)
		local open = open_draft()
		S.check(#open.pool == 5, P.role .. " board has five tiles")
		local stakes = {}
		for _, item in ipairs(open.pool) do
			S.check(item.art == "b_mp_almanac", P.role .. " tile " .. item.key .. " is the Almanac deck")
			stakes[stake_key(item.stake)] = true
		end
		for _, key in ipairs({ "stake_green", "stake_black" }) do
			S.check(stakes[key], P.role .. " board has " .. key)
		end
		S.check(
			stakes.stake_white ~= stakes.stake_mp_white_minus,
			P.role .. " board has exactly one of White and White-"
		)
		S.check(stakes.stake_gold ~= stakes.stake_mp_spectralplus, P.role .. " board has exactly one of Gold and Spectral+")
		S.check(stakes.stake_purple ~= stakes.stake_mp_planet, P.role .. " exactly one of Purple and Planet")
		S.check(not (stakes.stake_mp_planet and stakes.stake_mp_spectralplus), P.role .. " replacements are exclusive")
		S.check(not not stakes.stake_mp_planet == (variant == "planet"), P.role .. " requested Planet variant")
		S.check(not not stakes.stake_mp_spectralplus == (variant == "spectral"), P.role .. " requested Spectral+ variant")
		S.check(#open.schedule == 4 and open.schedule[4].action == "pick", P.role .. " schedule is three bans then a pick")
		P.stake_board = sorted_stakes(open.pool)
		P.note("board " .. P.stake_board)
		local last = survivors(open)
		last = last[variant == "planet" and 4 or 5]
		if P.role == "host" then
			local chip = tile(last.key).children.mp_stake_chip
			S.check(chip ~= nil, "host tile carries a stake chip")
			if chip then
				chip:hover()
				P.screenshot("stake_popup")
			end
		end
	end,
}

-- Fixture: pin White- and the requested exclusive replacement outcome. A
-- caller with its own rng (the start gate's catalogue check) keeps it.
local pin_board = P.only("host", {
	run = function()
		local almanac_board = PVP.DRAFT.almanac_board
		PVP.DRAFT.almanac_board = function(stake_keys, opts)
			opts = opts or {}
			if not opts.rng then
				local calls = 0
				opts.rng = function()
					calls = calls + 1
					return calls == 1 and 0 or replacement_roll
				end
			end
			return almanac_board(stake_keys, opts)
		end
	end,
})

local unhover = P.only("host", {
	wait = 0.5,
	run = function()
		for _, card in ipairs(G.I.CARD) do
			local chip = card.mp_deck_key and card.children.mp_stake_chip
			if chip and chip.children.h_popup then chip:stop_hover() end
		end
	end,
})

return P.steps(
	{
		run = function()
			-- Keep capture frames readable without changing saved DebugPlus settings.
			local ok, config = pcall(require, "debugplus.config")
			if ok then
				config.configDefinition.showNewLogs.onUpdate(false)
				local get = config.getValue
				config.getValue = function(key)
					if key == "showHUD" or key == "showNewLogs" then return false end
					return get(key)
				end
			end
		end,
	},
	P.connect(),
	P.lobby(PVP.GamemodeKey.PVP_NEMESIS, function(config)
		config.ruleset = PVP.RulesetKey.ALMANAC
	end),
	{
		run = function(S)
			local lobby = MPAPI.get_current_lobby()
			S.check(lobby.server_features and lobby.server_features.almanac_draft == 1, "server offers almanac_draft = 1")
			S.check(PVP.SHARED_RULES.supported(lobby), "server offers shared_pvp_rules = 2")
		end,
	},
	pin_board,
	P.sync("in_lobby"),
	P.start(),
	-- A refused start leaves an overlay instead of a Draft; fail on it with a picture.
	{
		until_ = function()
			return open_draft() ~= nil or G.STATE ~= G.STATES.MENU or (G.OVERLAY_MENU and not MPAPI.BanPick.is_active())
		end,
		timeout = 30,
		run = function(S)
			P.screenshot("after_start")
			S.check(open_draft() ~= nil, P.role .. " start opened the stake Draft (state " .. tostring(G.STATE) .. ")")
		end,
	},
	board,
	unhover,
	P.sync("board_seen"),
	draft,
	P.sync("drafted"),
	{
		run = function(S)
			local turns = {}
			for t = 1, 4 do
				local who, action, stake = (P.get("turn_" .. t) or "::"):match("^(.-):(.-):(.*)$")
				turns[t] = { who = who, action = action, stake = stake }
				S.check(who ~= "", P.role .. " turn " .. t .. " was played")
			end
			S.check(turns[1].who ~= turns[2].who, P.role .. " bans alternate")
			S.check(turns[1].who == turns[3].who, P.role .. " first player bans twice")
			S.check(turns[2].who == turns[4].who, P.role .. " second player picks")
			S.check(turns[4].action == "pick", P.role .. " last turn is the pick")
			local picked = turns[4].stake
			S.check(stake_key(G.GAME.stake) == picked, P.role .. " run is on the picked stake " .. picked)
			S.check(G.GAME.selected_back.effect.center.key == "b_mp_almanac", P.role .. " plays the Almanac deck")
			S.check(picked == "stake_mp_white_minus", P.role .. " picked White-")
			local v = G.GAME.used_vouchers
			S.check(v.v_grabber and v.v_wasteful, P.role .. " White- grants Grabber and Wasteful")
			P.screenshot("blind_select")
		end,
	},
	P.snapshot("after_stake_draft")
)
