-- PvP's Setup (ADR 0003): what a started game runs before its run. Casual
-- Nemesis, Royale, Manhunt and Teams vote on the ruleset first, then on Trap
-- cards when the ruleset is in TRAP_RULESETS. Matchmade games then run the
-- Draft. The server holds every step (MPAPI.Setup); the current host opens
-- the next step, and every client follows the results.

PVP.SETUP = PVP.SETUP or {}
local S = PVP.SETUP

S.Step = { RULESET = "ruleset", TRAPS = "traps", DRAFT = "draft" }

-- Ruleset vote options, in panel order: option key -> ruleset key.
S.RULESET_OPTIONS = { "vanilla", "majorleague", "balanced", "expanded" }
S.TRAP_OPTIONS = { "on", "off" }
local TRAP_RULESETS = { balanced = true, expanded = true }
local VOTE_FORMATS = { pvp_nemesis = true, pvp_royale = true, pvp_manhunt = true, pvp_teams = true }

-- How long a vote result stays in the panel before the next step.
local REVEAL_SECONDS = 3
-- The first part of the reveal cycles through the options (the roll).
S.ROLL_SECONDS = 1.2

function S.ruleset_key(option)
	return "ruleset_mp_" .. option
end

-- Which steps a game runs. Pure: queue_mode, is_casual and players (the
-- started game's player count) in; { votes, draft } out.
function S.plan(queue_mode, is_casual, is_matchmaking, players, ban_pick)
	local draft_fits = ban_pick and (ban_pick.schedule and players == 2 or (not ban_pick.schedule and players >= 2))
	return {
		votes = is_casual and VOTE_FORMATS[queue_mode] == true,
		draft = (is_matchmaking and draft_fits) and true or false,
	}
end

-- The next step a game with `plan` runs after `results` (Setup results by
-- step id), or nil when Setup is over. Pure.
function S.next_step(plan, results)
	if plan.votes then
		local ruleset = results[S.Step.RULESET]
		if not ruleset then
			return { kind = "vote", id = S.Step.RULESET, options = S.RULESET_OPTIONS }
		end
		if TRAP_RULESETS[ruleset.option] and not results[S.Step.TRAPS] then
			return { kind = "vote", id = S.Step.TRAPS, options = S.TRAP_OPTIONS }
		end
	end
	if plan.draft then
		return { kind = "draft", id = S.Step.DRAFT }
	end
	return nil
end

-- What the votes rolled: the ruleset key (nil without a Ruleset vote) and
-- whether Trap cards are on. Pure.
function S.rolled(results)
	local ruleset = results and results[S.Step.RULESET]
	if not ruleset then
		return nil, false
	end
	local traps = results[S.Step.TRAPS]
	return S.ruleset_key(ruleset.option), traps ~= nil and traps.option == "on"
end

local function setup_results(lobby)
	local setup = lobby and lobby._game and lobby._game.setup
	return setup and setup.results or {}
end

-- Lays the votes' results over the mirrored lobby config (lobby_bridge.lua's
-- mirror_metadata, which first resets the modifiers to the ruleset's own).
function S.apply_results(lobby)
	local ruleset, traps = S.rolled(setup_results(lobby))
	if not ruleset then
		return
	end
	PVP.LOBBY.config.ruleset = ruleset
	MPAPI.apply_default_modifiers(ruleset)
	if traps then
		MPAPI.add_modifier("traps")
	end
	PVP.LOBBY.config.modifier_layers = MPAPI.modifiers_serialize()
	local def = MPAPI.Rulesets[ruleset]
	if def and def.force_lobby_options then
		def:force_lobby_options()
	end
end

-- MPAPI's bans and layers read the ruleset from the lobby metadata, so the
-- host writes the rolled one there.
local function publish_ruleset(lobby)
	local ruleset = S.rolled(setup_results(lobby))
	if ruleset and lobby.is_host and (lobby:get_metadata() or {}).ruleset ~= ruleset then
		lobby:set_metadata({ ruleset = ruleset })
	end
end

local function metadata_ready(lobby)
	local ruleset = S.rolled(setup_results(lobby))
	return not ruleset or (lobby:get_metadata() or {}).ruleset == ruleset
end

-----------------------------
-- The game's Setup
-----------------------------

-- The game Setup is running for: { run_id, plan, on_done, revealed = { id = true },
-- reveal = nil | { id, option, counts, at }, draft_started, finished, waiting }.
S.game = nil

local function refresh()
	if PVP.lobby and PVP.lobby.refresh_mm_status then
		PVP.lobby.refresh_mm_status()
	end
end

local function finish(lobby, picked)
	local g = S.game
	if not g or g.finished then
		return
	end
	-- The run starts on the rolled ruleset only once the metadata has it.
	if not metadata_ready(lobby) then
		publish_ruleset(lobby)
		g.waiting = picked or false
		return
	end
	g.finished = true
	g.waiting = nil
	g.on_done(picked)
end

function S.continue(lobby)
	local g = S.game
	if not lobby or not g or g.finished or g.reveal then
		return
	end
	if g.waiting ~= nil then
		finish(lobby, g.waiting or nil)
		return
	end
	publish_ruleset(lobby)
	local setup = MPAPI.Setup.state(lobby)
	local step = S.next_step(g.plan, setup.results)
	if not step then
		finish(lobby, nil)
	elseif step.kind == "vote" then
		if lobby.is_host and not setup.open then
			MPAPI.Setup.start_vote(lobby, { id = step.id, options = step.options }, function(err)
				if err and err.kind == MPAPI.ErrorKind.SERVER_TOO_OLD then
					sendWarnMessage(err.message, "MULTIPLAYER")
				end
			end)
		end
		refresh()
	elseif not g.draft_started then
		g.draft_started = true
		g.start_draft(function(picked)
			finish(lobby, picked)
		end)
	end
end

local function reveal(lobby, id, result)
	local g = S.game
	g.revealed[id] = true
	g.reveal = { id = id, option = result.option, counts = result.counts or {}, at = love.timer.getTime() }
	refresh()
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = REVEAL_SECONDS,
		timer = "REAL",
		blockable = false,
		blocking = false,
		func = function()
			if S.game == g then
				g.reveal = nil
				refresh()
				S.continue(lobby)
			end
			return true
		end,
	}))
end

-- Every Setup change: show a new vote result, else re-render.
function S.on_changed(lobby)
	local g = S.game
	if not g or g.finished then
		return
	end
	for id, result in pairs(setup_results(lobby)) do
		if result.kind == "vote" and not g.revealed[id] then
			PVP.mirror_lobby_metadata(lobby)
			reveal(lobby, id, result)
			return
		end
	end
	refresh()
end

-- Starts Setup for the game just started. start_draft(on_picked) runs the
-- Draft; on_done(picked) starts the run (picked is the drafted item, or nil
-- without a Draft). A rejoin calls this again: results already in are not
-- shown again.
function S.begin(lobby, plan, start_draft, on_done)
	local started = lobby._game and lobby._game.started
	local revealed = {}
	for id in pairs(setup_results(lobby)) do
		revealed[id] = true
	end
	S.game = {
		run_id = started and started.run_id,
		plan = plan,
		start_draft = start_draft,
		on_done = on_done,
		revealed = revealed,
	}
	S.continue(lobby)
end

function S.is_voting()
	local g = S.game
	if not g or g.finished then
		return false
	end
	if g.reveal then
		return true
	end
	local lobby = MPAPI.get_current_lobby()
	local open = lobby and MPAPI.Setup.open_step(lobby)
	return open ~= nil and open.kind == "vote"
end

function S.cast(option)
	local lobby = MPAPI.get_current_lobby()
	local open = lobby and MPAPI.Setup.open_step(lobby)
	if open and open.kind == "vote" and not MPAPI.Setup.has_voted(lobby) then
		if S.game then
			S.game.my_votes = S.game.my_votes or {}
			S.game.my_votes[open.id] = option
		end
		MPAPI.Setup.cast(lobby, option)
	end
end

-----------------------------
-- Vote panel
-----------------------------

-- Laid out like the Draft (api/ban_pick.lua in MPAPI): one tile per option,
-- select one, then Confirm. Nobody sees who has voted until the close.

-- The Trap vote's art: a Trap card for on, the locked card back for off.
local TRAP_ON_CENTER = "c_mp_trap_web"
local LOCKED_POS = { x = 8, y = 9 }

local TILE_SCALE = 1 / 1.75

local function option_label(id, option)
	if id == S.Step.RULESET then
		return PVP.ruleset_display_name(S.ruleset_key(option))
	end
	return localize("k_pvp_setup_" .. id .. "_" .. option)
end

local function step_options(id)
	return id == S.Step.RULESET and S.RULESET_OPTIONS or S.TRAP_OPTIONS
end

local function text_row(text, scale, colour, extra)
	local config = { align = "cm", padding = 0.04 }
	for k, v in pairs(extra or {}) do
		config[k] = v
	end
	return {
		n = G.UIT.R,
		config = config,
		nodes = { { n = G.UIT.T, config = { text = text, scale = scale, colour = colour, shadow = true } } },
	}
end

local function option_sprite(id, option)
	local sprite
	if id == S.Step.RULESET then
		sprite = PVP.ruleset_chip_sprite(S.ruleset_key(option), 1.3)
	else
		local w, h = G.CARD_W * TILE_SCALE, G.CARD_H * TILE_SCALE
		local center = G.P_CENTERS[TRAP_ON_CENTER]
		if option == "on" and center then
			sprite = Sprite(0, 0, w, h, G.ASSET_ATLAS[center.atlas], center.pos)
		else
			sprite = Sprite(0, 0, w, h, G.ASSET_ATLAS["Joker"], (G.j_locked and G.j_locked.pos) or LOCKED_POS)
		end
	end
	-- Clicks go to the tile around the sprite.
	sprite.states.collide.can = false
	sprite.states.drag.can = false
	return sprite
end

-- Live state the per-frame funcs below read and write.
local _live = { time_text = "", step_id = nil, selected = nil, roll_option = nil }

local function tag(text, colour)
	return {
		n = G.UIT.R,
		config = { align = "cm", r = 0.08, padding = 0.06, colour = colour, shadow = true },
		nodes = { { n = G.UIT.T, config = { text = text, scale = 0.32, colour = G.C.UI.TEXT_LIGHT, shadow = true } } },
	}
end

-- One option's tile: the name above the art, then a tag (Selected, Your vote,
-- or the reveal's count) below. `button` is nil once the tile cannot be pressed.
local function vote_tile(id, option, below, button)
	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.08 },
		nodes = {
			{
				n = G.UIT.C,
				config = {
					align = "cm",
					padding = 0.1,
					r = 0.1,
					minw = 2,
					hover = button ~= nil,
					shadow = true,
					colour = G.C.CLEAR,
					button = button,
					ref_table = { option = option },
					func = "pvp_setup_tile",
				},
				nodes = {
					text_row(option_label(id, option), 0.34, G.C.UI.TEXT_LIGHT),
					{
						n = G.UIT.R,
						config = { align = "cm" },
						nodes = { { n = G.UIT.O, config = { object = option_sprite(id, option) } } },
					},
					{ n = G.UIT.R, config = { align = "cm", minh = 0.45 }, nodes = below and { below } or {} },
				},
			},
		},
	}
end

local function tile_row(tiles)
	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.2, r = 0.25, colour = { 0, 0, 0, 0.1 } },
		nodes = tiles,
	}
end

local function action_button(label, button, check, minw)
	return {
		n = G.UIT.C,
		config = {
			align = "cm",
			minw = minw,
			minh = 0.7,
			r = 0.1,
			padding = 0.08,
			shadow = true,
			hover = true,
			colour = G.C.UI.BACKGROUND_INACTIVE,
			button = button,
			func = check,
		},
		nodes = { { n = G.UIT.T, config = { text = label, scale = 0.42, colour = G.C.UI.TEXT_LIGHT, shadow = true } } },
	}
end

local function open_vote_rows(lobby, open)
	if _live.step_id ~= open.id then
		_live.step_id = open.id
		_live.selected = nil
	end
	local voted = MPAPI.Setup.has_voted(lobby)
	local mine = voted and S.game and S.game.my_votes and S.game.my_votes[open.id]
	local rows = { text_row(localize("k_pvp_setup_title_" .. open.id), 0.6, G.C.UI.TEXT_LIGHT) }
	rows[#rows + 1] = text_row(
		localize(voted and "k_pvp_setup_vote_sent" or "k_pvp_setup_your_vote"),
		0.42,
		voted and G.C.UI.TEXT_INACTIVE or G.C.GREEN
	)
	rows[#rows + 1] = {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.03, func = "pvp_setup_clock" },
		nodes = {
			{ n = G.UIT.T, config = { text = localize("k_banpick_time_left") .. " ", scale = 0.32, colour = G.C.UI.TEXT_LIGHT } },
			{ n = G.UIT.T, config = { ref_table = _live, ref_value = "time_text", scale = 0.32, colour = G.C.UI.TEXT_LIGHT } },
		},
	}
	rows[#rows + 1] = { n = G.UIT.R, config = { minh = 0.2 } }
	local tiles = {}
	for _, option in ipairs(open.options) do
		local below
		if voted then
			below = option == mine and tag(localize("k_pvp_setup_your_vote_tag"), G.C.GREEN) or nil
		elseif option == _live.selected then
			below = tag(localize("k_banpick_selected_tag"), G.C.GREEN)
		end
		tiles[#tiles + 1] = vote_tile(open.id, option, below, not voted and "pvp_setup_select" or nil)
	end
	rows[#rows + 1] = tile_row(tiles)
	if not voted then
		rows[#rows + 1] = { n = G.UIT.R, config = { minh = 0.3 } }
		rows[#rows + 1] = {
			n = G.UIT.R,
			config = { align = "cm", padding = 0.06 },
			nodes = {
				action_button(
					localize("k_pvp_setup_confirm_vote"),
					"pvp_setup_confirm",
					"pvp_setup_confirm_check",
					3.2
				),
				{ n = G.UIT.C, config = { minw = 0.25 } },
				action_button(localize("k_banpick_random"), "pvp_setup_random", "pvp_setup_random_check", 1.6),
			},
		}
	end
	return rows
end

local function reveal_rows(reveal)
	_live.step_id = reveal.id
	local rows = { text_row(localize("k_pvp_setup_title_" .. reveal.id), 0.6, G.C.UI.TEXT_LIGHT) }
	rows[#rows + 1] = { n = G.UIT.R, config = { minh = 0.2 } }
	local options = step_options(reveal.id)
	local total = 0
	for _, option in ipairs(options) do
		total = total + (reveal.counts[option] or 0)
	end
	-- Each vote is one chance; with no votes every option has the same chance.
	local tiles = {}
	for _, option in ipairs(options) do
		local count = reveal.counts[option] or 0
		local chance = total > 0 and math.floor(count / total * 100 + 0.5) or math.floor(100 / #options + 0.5)
		local below = tag(count .. "  (" .. chance .. "%)", G.C.UI.BACKGROUND_INACTIVE)
		tiles[#tiles + 1] = vote_tile(reveal.id, option, below, nil)
	end
	rows[#rows + 1] = tile_row(tiles)
	rows[#rows + 1] = {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.12, func = "pvp_setup_roll" },
		nodes = {
			{ n = G.UIT.T, config = { ref_table = _live, ref_value = "roll_text", scale = 0.55, colour = G.C.GOLD, shadow = true } },
		},
	}
	return rows
end

-- The status panel's contents while a vote is open or its result shows.
function S.build_contents()
	local lobby = MPAPI.get_current_lobby()
	local g = S.game
	if g and g.reveal then
		return reveal_rows(g.reveal)
	end
	local open = lobby and MPAPI.Setup.open_step(lobby)
	if open and open.kind == "vote" then
		return open_vote_rows(lobby, open)
	end
	return { text_row(localize("k_pvp_setup_waiting"), 0.4, G.C.UI.TEXT_LIGHT) }
end

local function can_vote()
	local lobby = MPAPI.get_current_lobby()
	local open = lobby and MPAPI.Setup.open_step(lobby)
	return open ~= nil and open.kind == "vote" and open.id == _live.step_id and not MPAPI.Setup.has_voted(lobby)
end

-- Selecting only marks a tile; Confirm casts the vote.
G.FUNCS.pvp_setup_select = function(e)
	if can_vote() then
		_live.selected = e.config.ref_table.option
		refresh()
	end
end

G.FUNCS.pvp_setup_random = function(_e)
	if can_vote() then
		local options = step_options(_live.step_id)
		_live.selected = options[math.random(#options)]
		refresh()
	end
end

G.FUNCS.pvp_setup_confirm = function(_e)
	if can_vote() and _live.selected then
		S.cast(_live.selected)
		_live.selected = nil
		refresh()
	end
end

-- The button check pattern of the Draft's buttons: no `button` while not ready.
G.FUNCS.pvp_setup_confirm_check = function(e)
	local ready = can_vote() and _live.selected ~= nil
	e.config.colour = ready and G.C.GREEN or G.C.UI.BACKGROUND_INACTIVE
	e.config.button = ready and "pvp_setup_confirm" or nil
end

G.FUNCS.pvp_setup_random_check = function(e)
	local ready = can_vote()
	e.config.colour = ready and G.C.BLUE or G.C.UI.BACKGROUND_INACTIVE
	e.config.button = ready and "pvp_setup_random" or nil
end

-- A tile lights up while selected, and gold while the roll is on it.
G.FUNCS.pvp_setup_tile = function(e)
	local option = e.config.ref_table.option
	if S.game and S.game.reveal then
		e.config.colour = option == _live.roll_option and G.C.GOLD or G.C.CLEAR
	else
		e.config.colour = option == _live.selected and { 1, 1, 1, 0.15 } or G.C.CLEAR
	end
end

G.FUNCS.pvp_setup_clock = function(_e)
	local lobby = MPAPI.get_current_lobby()
	_live.time_text = lobby and tostring(math.ceil(MPAPI.Setup.seconds_left(lobby))) or ""
end

-- The roll: cycle through the options, then land on the result.
G.FUNCS.pvp_setup_roll = function(_e)
	local reveal = S.game and S.game.reveal
	if not reveal then
		return
	end
	local elapsed = love.timer.getTime() - reveal.at
	local option = reveal.option
	if elapsed < S.ROLL_SECONDS then
		local options = step_options(reveal.id)
		option = options[math.floor(elapsed * 12) % #options + 1]
	end
	_live.roll_option = option
	_live.roll_text = option_label(reveal.id, option)
end
