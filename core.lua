PVP = SMODS.current_mod

PVP.BANNED_MODS = {
	["Incantation"] = true,
	["Brainstorm"] = true,
	["DVPreview"] = true,
	["Aura"] = true,
	["NotJustYet"] = true,
	["Showman"] = true,
	["TagPreview"] = true,
	["FantomsPreview"] = true,
}

PVP.LOBBY = {
	connected = false,
	temp_code = "",
	temp_seed = "",
	code = nil,
	type = "",
	config = {}, -- Now set in PVP.reset_lobby_config
	deck = {
		back = "Red Deck",
		sleeve = "sleeve_casl_none",
		stake = 1,
		challenge = "",
	},
	username = "Guest",
	blind_col = 1,
	host = {},
	guest = {},
	is_host = false,
	ready_to_start = false,
}
PVP.GAME = {}
PVP.UI = {}
PVP.ACTIONS = {}
PVP.MOD_ACTIONS = {}

-- SMODS flag: lets cards count as multiple enhancements at once (required by Alloy)
PVP.optional_features = { quantum_enhancements = false }

function PVP.register_mod_action(modAction, callback, modId)
	if not modId then
		local mod = SMODS.current_mod
		if not mod then
			sendWarnMessage("PVP.register_mod_action called outside of mod init without a modId", "MULTIPLAYER")
			return
		end
		modId = mod.id
	end
	PVP.MOD_ACTIONS[modId] = PVP.MOD_ACTIONS[modId] or {}
	PVP.MOD_ACTIONS[modId][modAction] = callback
end

PVP.INTEGRATIONS = {
	Preview = PVP.config.integrations.Preview,
}

PVP.PREVIEW = {
	text = PVP.config.preview.text,
	button = PVP.config.preview.button,
}

PVP.EXPERIMENTAL = {
	show_sandbox_collection = false,
	alt_stakes = false,
	suppress_dev_warning = false,
	mem_debug = true,
}

-- Override experimental flags and server config from .env file if present
PVP.ENV = {}
local env_path = PVP.path .. "/.env"
local env_info = NFS.getInfo(env_path)
if env_info then
	local content = NFS.read(env_path)
	if content then
		for line in content:gmatch("[^\r\n]+") do
			line = line:match("^%s*(.-)%s*$") -- trim
			if line ~= "" and not line:match("^#") then
				local key, val = line:match("^([%w_]+)%s*=%s*(.+)$")
				if key then
					if val == "true" then
						val = true
					elseif val == "false" then
						val = false
					end
					PVP.ENV[key] = val
					if PVP.EXPERIMENTAL[key] ~= nil then
						PVP.EXPERIMENTAL[key] = val
					end
				end
			end
		end
		sendDebugMessage("Loaded .env overrides", "MULTIPLAYER")
	end
end

G.C.MULTIPLAYER = HEX("AC3232")

PVP.MIN_SMODS_VERSION = "1.0.0~BETA-1814a"
PVP.MIN_LOVELY_VERSION = "0.10.0"

-- The Order (deterministic/anti-desync RNG) engine now lives entirely in the API
-- (BalatroMultiplayerAPI/api/the_order/). We delegate the gate + helpers to the
-- API's single implementation instead of shipping our own copy (was compatibility/TheOrder.lua).
function PVP.should_use_the_order()
	return MPAPI.should_use_the_order()
end

function PVP.is_major_league_ruleset()
	return PVP.LOBBY and PVP.LOBBY.config and PVP.LOBBY.config.ruleset == "ruleset_mp_majorleague" and PVP.LOBBY.code
end

-- §20: register our own predicates through the API's generic extension points
-- (MPAPI.register_order_gate/register_voucher_queue_gate/register_idol_gate) rather than the API
-- reading PVP.* globals directly. Practice mode always uses the order; otherwise a
-- lobby with the_order enabled does -- exactly the previous PVP-compat branch's logic.
MPAPI.register_order_gate(function()
	return (PVP.is_practice_mode and PVP.is_practice_mode())
		or (PVP.LOBBY and PVP.LOBBY.config and PVP.LOBBY.config.the_order and PVP.LOBBY.code ~= nil)
		or false
end)

-- MLBa plays without The Order, but its voucher queue and The Idol's card follow it.
local function in_major_league_lobby()
	return PVP.is_major_league_ruleset() and true or false
end

MPAPI.register_voucher_queue_gate(in_major_league_lobby)
MPAPI.register_idol_gate(in_major_league_lobby)

-- Legacy PVP.* aliases for The Order queue helpers, kept because live content still calls
-- them (objects/jokers/standard/bloodstone, objects/boosters/standard_giga, ui/game/blind_choice,
-- layers/smallworld). They forward to the API's implementations.
PVP.ante_based = MPAPI.ante_based
PVP.order_round_based = MPAPI.order_round_based
PVP.sorted_hand_list = MPAPI.sorted_hand_list

-- Forward-declaration stub: PVP.reset_game_states() below calls PVP.UTILS.timer_base(),
-- which reads PVP.current_ruleset() -- but that call happens synchronously at this
-- file's own load time, before rulesets/_rulesets.lua (loaded later via
-- PVP.load_mp_dir("rulesets", true)) defines the real PVP.current_ruleset(). Without
-- this stub the early call crashes on a nil field. The real definition overwrites
-- this one once rulesets load; this one is never reached again after that.
function PVP.current_ruleset()
	return {}
end

function PVP.load_mp_file(file)
	local chunk, err = SMODS.load_file(file, PVP.id)
	if chunk then
		local ok, func = pcall(chunk)
		if ok then
			return func
		else
			sendWarnMessage("Failed to process file: " .. func, "MULTIPLAYER")
		end
	else
		sendWarnMessage("Failed to find or compile file: " .. tostring(err), "MULTIPLAYER")
	end
	return nil
end

function PVP.load_mp_dir(directory, recursive)
	recursive = recursive or false
	local function has_prefix(name)
		return name:match("^_") ~= nil
	end

	local dir_path = PVP.path .. "/" .. directory
	local items = NFS.getDirectoryItemsInfo(dir_path)
	-- sort by prefix like { _file, _dir, file, dir }
	table.sort(items, function(a, b)
		local ac, bc = 0, 0
		if has_prefix(a.name) then ac = ac + 100 end
		if has_prefix(b.name) then bc = bc + 100 end
		if a.type == "directory" then ac = ac + 10 end
		if b.type == "directory" then bc = bc + 10 end
		if ac ~= bc then return ac > bc end
		return string.lower(a.name) < string.lower(b.name)
	end)

	-- load sorted files/dirs
	for _, item in ipairs(items) do
		local path = directory .. "/" .. item.name
		if item.type ~= "directory" then
			PVP.load_mp_file(path)
		elseif recursive then
			PVP.load_mp_dir(path, recursive)
		end
	end
end

PVP.load_mp_dir("lib")
PVP.load_mp_dir("overrides")

function PVP.reset_lobby_config(persist_ruleset_and_gamemode)
	sendDebugMessage("Resetting lobby options", "MULTIPLAYER")
	PVP.LOBBY.config = {
		gold_on_life_loss = true,
		no_gold_on_round_loss = false,
		death_on_round_loss = true,
		different_seeds = false,
		the_order = true,
		starting_lives = 4,
		pvp_start_round = 2,
		-- Manhunt only: each Hunter's individual life count (Runner is always
		-- fixed at 1, not configurable -- see PVP.referee_reset).
		manhunt_hunter_lives = 7,
		-- Private lobbies only: the host's Lobby Options switch for the "traps" modifier.
		trap_cards = false,
		timer_base_seconds = 150,
		timer_increment_seconds = 60,
		pvp_countdown_seconds = 3,
		ruleset = persist_ruleset_and_gamemode and PVP.LOBBY.config.ruleset or "ruleset_mp_expanded",
		gamemode = persist_ruleset_and_gamemode and PVP.LOBBY.config.gamemode or "gamemode_mp_attrition",
		weekly = nil,
		custom_seed = "random",
		different_decks = false,
		random_loadout = false,
		back = "Red Deck",
		sleeve = "sleeve_casl_none",
		stake = 1,
		challenge = "",
		cocktail = "",
		timer = true,
		timer_forgiveness = 0,
		forced_config = false,
		preview_disabled = false,
		legacy_smallworld = false,
		-- Baseline off; start_lobby sets it on for standard-layer rulesets.
		hide_score_until_played = false,
	}
end
PVP.reset_lobby_config()

function PVP.reset_game_states()
	sendDebugMessage("Resetting game states", "MULTIPLAYER")
	-- §17.10: fresh per-match roster collection -- must not carry over from
	-- whatever match (if any) this player was previously in.
	PVP._collected_results = {}
	-- Players who started the match (lib/match_players.lua); set by action_start_game.
	PVP._match_players = nil
	PVP.GAME = {
		ready_blind = false,
		ready_blind_text = localize("b_ready"),
		processed_round_done = false,
		lives = 0,
		loaded_ante = 0,
		loading_blinds = false,
		comeback_bonus_given = true,
		comeback_bonus = 0,
		end_pvp = false,
		enemy = {
			score = PVP.INSANE_INT.empty(),
			real_score = PVP.INSANE_INT.empty(),
			score_text = "0",
			hands = 4,
			hands_text = "4",
			-- Whether an enemyInfo message has arrived this blind. Used to mask
			-- the opponent's hands as "?" until we hear from them.
			info_received = false,
			location = localize("loc_selecting"),
			-- " (catching up)" while the target is replaying its run after a crash, else "".
			catching_up_text = "",
			skips = 0,
			lives = PVP.LOBBY.config.starting_lives,
			sells = 0,
			sells_per_ante = {},
			spent_in_shop = {},
			highest_score = PVP.INSANE_INT.empty(),
		},
		location = "loc_selecting",
		next_blind_context = nil,
		ante_key = tostring(math.random()),
		antes_keyed = {},
		prevent_eval = false,
		round_ended = false,
		duplicate_end = false,
		misprint_display = "",
		spent_total = 0,
		spent_before_shop = 0,
		highest_score = PVP.INSANE_INT.empty(),
		-- §17.10: PVP.GAME.highest_score above tracks the best SINGLE-BLIND
		-- score of any kind (updated unconditionally in every play_hand,
		-- including plain Small/Big/Boss blinds) -- not what the end-of-run
		-- roster needs ("highest PvP-blind score"). Tracked separately here,
		-- only updated while PVP.is_pvp_boss() is true.
		highest_pvp_score = PVP.INSANE_INT.empty(),
		timer = PVP.UTILS.timer_base(),
		timer_started = false,
		timer_threshold_pending = false,
		timer_consumed = false,
		pvp_reached = false,
		pvp_countdown = 0,
		real_money = 0,
		ce_cache = false,
		furthest_blind = 0,
		pincher_index = -3,
		pincher_unlock = false,
		asteroids = 0,
		pizza_discards = 0,
		disable_live_and_timer_hud = false,
		timers_forgiven = 0,
		stats = {
			reroll_count = 0,
			reroll_cost_total = 0,
			-- Add more stats here in the future
		},
	}
end
PVP.reset_game_states()

PVP.LOBBY.username = PVP.UTILS.get_username()
PVP.LOBBY.blind_col = PVP.UTILS.get_blind_col()

PVP.LOBBY.config.weekly = PVP.UTILS.get_weekly()

if not SMODS.current_mod.lovely then
	G.E_MANAGER:add_event(Event({
		no_delete = true,
		trigger = "immediate",
		blockable = false,
		blocking = false,
		func = function()
			if G.MAIN_MENU_UI then
				-- PVP.UI.UTILS is only populated by PVP.load_mp_dir("ui", true)
				-- below (line ~358) -- unreachable from here, since this whole
				-- branch only runs when SMODS.current_mod.lovely is falsy (the
				-- misconfigured-nesting case this message warns about) and
				-- returns before that load_mp_dir call ever runs. Calling
				-- PVP.UI.UTILS.overlay_message directly crashed with "attempt
				-- to index field 'UTILS' (a nil value)" every time this
				-- warning path was actually hit (confirmed live 2026-09-12).
				-- Fall back to a plain print so a genuinely misconfigured
				-- install still gets a visible message instead of a crash.
				if PVP.UI.UTILS then
					PVP.UI.UTILS.overlay_message(
						PVP.UTILS.wrapText(
							"Your Multiplayer Mod is not loaded correctly, make sure the Multiplayer folder does not have an extra Multiplayer folder around it.",
							50
						)
					)
				else
					print("[MultiplayerPvP] Your Multiplayer Mod is not loaded correctly, make sure the Multiplayer folder does not have an extra Multiplayer folder around it.")
				end
				return true
			end
		end,
	}))
	return
end

SMODS.Atlas({
	key = "modicon",
	path = "modicon.png",
	px = 34,
	py = 34,
})

PVP.load_mp_dir("compatibility")

PVP.load_mp_file("networking/action_handlers.lua")

PVP.load_mp_dir("gamemodes")
PVP.load_mp_dir("layers")
PVP.load_mp_dir("rulesets", true)
PVP.load_mp_dir("ui", true)
PVP.load_mp_dir("objects/editions")
PVP.load_mp_dir("objects/enhancements")
PVP.load_mp_dir("objects/seals")
PVP.load_mp_dir("objects/stickers")
PVP.load_mp_dir("objects/blinds")
PVP.load_mp_dir("objects/decks")
PVP.load_mp_dir("objects/jokers")
PVP.load_mp_dir("objects/jokers/sandbox")
PVP.load_mp_dir("objects/jokers/sandbox/extra-credit")
PVP.load_mp_dir("objects/jokers/standard")
PVP.load_mp_dir("objects/jokers/experimental")
PVP.load_mp_dir("objects/stakes")
PVP.load_mp_dir("objects/tags")
PVP.load_mp_dir("objects/consumables")
PVP.load_mp_dir("objects/consumables/sandbox")
PVP.load_mp_dir("objects/boosters")
PVP.load_mp_dir("objects/challenges")
PVP.load_mp_dir("objects/vouchers")

-- MultiplayerPvP runs on BalatroMultiplayerAPI. The API owns the connection,
-- lobbies, matchmaking, leaderboards, and the main-menu host, so we no longer start
-- our own TCP socket thread or call PVP.ACTIONS.connect(). Instead we register with
-- the API once it signals ready; it then lists "PvP" in its account panel and swaps
-- in our menu (PVP.build_pre_lobby_ui) when the player selects it.
--
-- NOTE (skeleton milestone): the in-game PvP protocol in networking/action_handlers.lua
-- is still loaded but inert (no socket thread) — Phase 4 converts each action to an
-- MPAPI.ActionType. The menus here are placeholders — Phase 6 builds the real
-- Find Game / Leaderboard / Practice / Join / Create layout.
MPAPI.on_loaded(function()
	MPAPI.Page({
		key = 'pvp_main_menu',
		category = 'mod_menu',
		build = function(self)
			return PVP.build_pre_lobby_ui()
		end,
		-- Fixes the logo back to its normal spot regardless of which page was previously
		-- showing -- entering from pvp_find_game (which nudges it up via
		-- MPAPI.set_logo_offset(-1, true)) would otherwise leave it shifted here too, since
		-- nothing else resets it on the way out. Same defensive reasoning as SPDRN's
		-- spdrn_game_select on_enter (BalatroMultiplayerSpeed/core.lua)'s own comment on this.
		on_enter = function(self)
			MPAPI.set_logo_offset(0, true)
		end,
	})

	MPAPI.Page({
		key = 'pvp_lobby',
		category = 'lobby_menu',
		build = function(self)
			return PVP.build_in_lobby_ui()
		end,
	})

	-- Practice / Create Lobby pillar pages (ui/main_menu/game_select.lua), same page setup as
	-- pvp_find_game below.
	MPAPI.Page({
		key = 'pvp_game_select',
		category = 'game_select',
		build = function(self)
			self._pillar_row = PVP.build_game_select_ui(self.params and self.params.intent)
			return self._pillar_row.definition
		end,
		on_enter = function(self)
			if G.MAIN_MENU_UI then
				G.MAIN_MENU_UI.alignment.offset.y = 1.5
				G.MAIN_MENU_UI:align_to_major()
			end
			MPAPI.set_logo_offset(-2.5, true)
		end,
		dispose = function(self)
			if self._pillar_row then
				self._pillar_row:dispose()
			end
		end,
	})

	-- Pillar-based Find Game screen (ui/main_menu/find_game.lua), mirroring SPDRN's
	-- spdrn_game_select page/pillar-row setup one-for-one -- see that file's own core.lua
	-- registration for the on_enter offset-nudge/logo-position reasoning this copies.
	MPAPI.Page({
		key = 'pvp_find_game',
		category = 'game_select',
		build = function(self)
			self._pillar_row = PVP.build_find_game_ui(self.params and self.params.category, self.params and self.params.group)
			return self._pillar_row.definition
		end,
		on_enter = function(self)
			if G.MAIN_MENU_UI then
				G.MAIN_MENU_UI.alignment.offset.y = 1.5
				G.MAIN_MENU_UI:align_to_major()
			end
			-- The title logo sits where it always does regardless of which page is showing
			-- (it's not part of G.MAIN_MENU_UI's own tree), so without this it renders behind
			-- this page's tab row (2026-09-08 user feedback -- "about half cut off"). -2.5, not
			-- SPDRN's -1: PvP's own title (ui/pvp_title.lua) is a single diagonal "PLAYER ..
			-- (VS) .. PLAYER" composition -- pvp_title.png bakes BOTH words into one image,
			-- second lower-right of the first -- not one word per sprite the way -1 (clearing
			-- just the first word) was tuned for elsewhere. -1 fully cleared the first PLAYER
			-- but left the second still sitting on the tab row; -2.5 (coincidentally the same
			-- value SPDRN's own main-menu cleanup uses for unrelated reasons) clears both.
			MPAPI.set_logo_offset(-2.5, true)
			PVP.start_find_game_polling()
		end,
		dispose = function(self)
			if self._pillar_row then
				self._pillar_row:dispose()
			end
			PVP.stop_find_game_polling()
		end,
	})

	MPAPI.register_mod({
		id = PVP.id,
		name = "PvP",
		colour = G.C.RED,
		main_menu_ui = 'pvp_main_menu',
		lobby_ui = 'pvp_lobby',
		-- Custom in-run pause menu (Settings + Seed Change + Forfeit), built by the API's
		-- options_builder hook instead of the vanilla options box (see ui/pvp_run_options.lua).
		prevent_pause = true,
		options_builder = PVP.create_run_options,
		-- Custom title logo shown while PvP's menu is focused (atlas in ui/pvp_title.lua).
		-- Prefixed with the mod prefix "mp" like every SMODS key.
		title = "mp_pvp_title",
	})

	-- Load API-side content (bridge GameModes now; ActionTypes in Phase 4) here so
	-- their SMODS GameObjects are tagged to this mod — per-lobby routing requires it.
	PVP.load_mp_dir("pvp_api", true)

	-- Boot diagnostic: confirm the pvp_* ActionTypes actually registered.
	local n = 0
	for k in pairs(MPAPI.ActionTypes or {}) do
		if tostring(k):match("^pvp_") then
			n = n + 1
		end
	end
	sendDebugMessage(
		"[pvp] boot: pvp ActionTypes registered=" .. n .. " pvp_player_ready="
			.. tostring(MPAPI.ActionTypes and MPAPI.ActionTypes["pvp_player_ready"] ~= nil),
		"MULTIPLAYER"
	)

	MPAPI.on_connection_state_change(function()
		if PVP.UI and PVP.UI.update_connection_status then
			pcall(PVP.UI.update_connection_status)
		end
		-- Refresh the reactive main-menu buttons so they enable once connected.
		if PVP.update_main_menu_buttons then
			pcall(PVP.update_main_menu_buttons)
		end
	end)
end)
