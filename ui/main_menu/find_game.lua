-- The Find Game pillar page (MPAPI page pvp_find_game), built on MPAPI's generic pillar-row
-- layout (BalatroMultiplayerAPI/api/ui_pillar_row.lua) -- same shape SPDRN's gamemode-select
-- page uses (BalatroMultiplayerSpeed/ui/main_menu/game_select.lua). Replaces the old two-step
-- Find Game -> Ranked/Casual -> ruleset grid overlay (pvp_api/queue.lua's now-removed
-- mp_pvp_find_game_ranked/_casual).
--
-- Ranked (5 pillars) and Casual (4 pillars) are two separate screens now, not one 9-pillar row
-- -- too many to read comfortably on one page (2026-09-08 user feedback on the first pass).
-- self.params.category (set by the tab buttons below, read in core.lua's page registration)
-- picks which list PVP.build_find_game_ui builds; the tab row at the top of the page switches
-- between them via a normal MPAPI.pages.show() re-navigation (same page, new params), same
-- mechanism SPDRN's practice/create_lobby/find_game intents already use -- not a separate
-- widget/mechanism of its own.
--
-- WIP: chip art is a single placeholder frame reused across every pillar (no per-mode art
-- exists yet). Every pillar routes straight to the existing mp_pvp_queue_ranked_*/
-- mp_pvp_queue_casual_* handlers (pvp_api/queue.lua), unchanged.

-- No new atlas registered here -- reuses objects/blinds/nemesis.lua's already-registered
-- "player_blind_chip" (G.ANIMATION_ATLAS['mp_player_blind_chip'], SMODS auto-prefixes the key)
-- as a generic placeholder chip for every pillar, rather than adding a second atlas just to
-- have *something* in the icon slot. core.lua's load_mp_dir("ui", true) call actually runs
-- BEFORE load_mp_dir("objects/blinds"), but that only orders top-level (file-load-time) code --
-- build_chip_sprite below is a function body, only called once the page is actually built
-- (well after every load_mp_dir call has finished, since that requires a live game/player
-- input), so the atlas is always registered by the time this runs.
local PLACEHOLDER_CHIP_ROW = 0

-- uses_order reflects PVP.LOBBY.config.the_order as core.lua's reset_lobby_config default
-- (true) and each ruleset's own force_lobby_options override actually resolve it, not a
-- hand-picked guess: rulesets/majorleague.lua explicitly forces false; rulesets/vanilla.lua
-- forces false; balanced/expanded/smallworld have no override, so they inherit the
-- true default.
--
-- Ranked: always exactly 2 players -- see pvp_api/queue.lua's own comment on this.
-- desc lines are hand-wrapped to roughly Nemesis's own second line ("Nemesis every ante", 19
-- chars) rather than left as whatever length the source description happened to be -- a couple
-- (Battle Royale, Teams) were 25+ chars per line before this and visibly overran their card
-- (2026-09-08 user feedback). No code-level truncation/wrapping added; this is just each string
-- rewritten by hand to fit.
-- ruleset_key is the exact string PVP._join_ranked_ruleset stamps onto PVP.LOBBY.config.ruleset
-- and PVP._active_queue_id.key (pvp_api/queue.lua) -- build_select below compares against it to
-- decide whether this exact pillar's queue is the one currently active.
local RANKED_MODES = {
	{ key = "pvp_ranked_vanilla",
		desc = { "Normal Balatro", "with PvP blinds" }, uses_order = false,
		queue_button = "mp_pvp_queue_ranked_vanilla", ruleset_key = PVP.RulesetKey.VANILLA, colour = G.C.GREEN },
	{ key = "pvp_ranked_balanced",
		desc = { "Near-vanilla with", "a few reworks" }, uses_order = true,
		queue_button = "mp_pvp_queue_ranked_balanced", ruleset_key = PVP.RulesetKey.BALANCED, colour = G.C.BLUE },
	{ key = "pvp_ranked_expanded",
		desc = { "Balanced plus more", "reworks and MP cards" }, uses_order = true,
		queue_button = "mp_pvp_queue_ranked_expanded", ruleset_key = PVP.RulesetKey.EXPANDED, colour = G.C.PURPLE },
	{ key = "pvp_ranked_majorleague", short_name = "MLBa",
		desc = { "Follows the MLBa", "ruleset" }, uses_order = false,
		queue_button = "mp_pvp_queue_ranked_majorleague", ruleset_key = PVP.RulesetKey.MAJORLEAGUE, colour = G.C.BLACK },
	{ key = "pvp_smallworld_ranked",
		desc = { "75% of cards are", "banned at random" }, uses_order = true,
		queue_button = "mp_pvp_queue_ranked_smallworld", ruleset_key = PVP.RulesetKey.SMALLWORLD, colour = G.C.RED },
}

-- Casual: Nemesis is 1v1, the others take 2-16 players. Each pillar plays its gamemode key's own default ruleset
-- (PVP.reset_ruleset_to_gamemode_default, pvp_api/queue.lua). Manhunt has an existing
-- casual queue handler (mp_pvp_queue_casual_manhunt) but wasn't in the requested pillar
-- set, so it's left reachable only via Create Lobby for now, not duplicated here. None
-- has a the_order override, so all four inherit the default and use The Order here.
-- gamemode_key is the exact PVP.GamemodeKey value PVP._join_queue's second argument (and
-- PVP._active_queue_id.key) uses -- see the ruleset_key comment on RANKED_MODES above for why
-- build_select needs it. Note these deliberately differ from a couple of the pillar `key` ids
-- above (e.g. "pvp_smallworld_casual" vs. gamemode_key "pvp_smallworld") -- `key` is just this
-- page's own UI item id, unrelated to the wire gamemode key.
local CASUAL_MODES = {
	{ key = "pvp_nemesis", name = "Nemesis",
		desc = { "One Nemesis,", "head to head" }, uses_order = true,
		queue_button = "mp_pvp_queue_casual_nemesis", gamemode_key = "pvp_nemesis", colour = G.C.BLUE },
	{ key = "pvp_royale", name = { "Battle", "Royale" },
		desc = { "Free for all;", "bottom half lose" }, uses_order = true,
		queue_button = "mp_pvp_queue_casual_royale", gamemode_key = "pvp_royale", colour = G.C.PURPLE },
	{ key = "pvp_teams", name = "Teams",
		desc = { "Team vs team;", "best score wins" }, uses_order = true,
		queue_button = "mp_pvp_queue_casual_teams", gamemode_key = "pvp_teams", colour = G.C.GREEN },
	{ key = "pvp_smallworld_casual", display_ruleset = PVP.RulesetKey.SMALLWORLD,
		desc = { "75% of cards are", "banned at random" }, uses_order = true,
		queue_button = "mp_pvp_queue_casual_smallworld", gamemode_key = "pvp_smallworld", colour = G.C.RED },
}

-- Plain Sprite, not AnimatedSprite -- see SPDRN's game_select.lua build_chip_sprite for why
-- (AnimatedSprite free-runs its column animation; this icon is meant to sit static).
local function build_chip_sprite()
	return Sprite(0, 0, 1.1, 1.1, G.ANIMATION_ATLAS["mp_player_blind_chip"], { x = PLACEHOLDER_CHIP_ROW, y = 0 })
end

-- A ruleset's art, shared by the Ranked pillars and the Ruleset vote's tiles
-- (pvp_api/setup.lua) so both change together when per-ruleset art exists.
function PVP.ruleset_chip_sprite(_ruleset_key, size)
	size = size or 1.1
	return Sprite(0, 0, size, size, G.ANIMATION_ATLAS["mp_player_blind_chip"], { x = PLACEHOLDER_CHIP_ROW, y = 0 })
end

-- Every currently-built pillar's SELECT button, keyed by mode.key -- reset at the start of each
-- build_items call (a fresh page build, e.g. a Ranked<->Casual tab switch) and refreshed live by
-- PVP._refresh_find_game_queue_ui (called from pvp_api/queue.lua's PVP._show_searching any time
-- PvP's single active queue starts, ends, or targets a different pillar).
local _select_els = {}

function PVP._refresh_find_game_queue_ui()
	for _, el in pairs(_select_els) do
		el:update()
	end
end

-- The pillars grey out by the account's standing, which the server can change at any time.
if MPAPI.on_standing_changed then
	MPAPI.on_standing_changed(function()
		PVP._refresh_find_game_queue_ui()
	end)
end

-- The single handler behind every pillar's SELECT/CANCEL button. Whether this joins or cancels
-- depends on ref_table.cancel's presence, not any state read here -- the button that was
-- actually clicked already encoded, at the moment it was rendered, which action it means (see
-- build_select) -- so this can't race against a queue state change that happens between click
-- and handling. Mirrors SPDRN's spdrn_game_select_toggle_queue.
G.FUNCS.mp_pvp_find_game_toggle_queue = function(e)
	local rt = e.config.ref_table
	if not rt then
		return
	end
	-- Preserves the exact behavior of the old per-mode mp_pvp_queue_ranked_*/_casual_*
	-- handlers this replaces (pvp_api/queue.lua), which all called this before queuing.
	G.FUNCS.exit_overlay_menu()
	if rt.cancel then
		PVP._cancel_queue()
	elseif rt.ruleset_key then
		PVP._join_ranked_ruleset(rt.ruleset_key)
	elseif rt.gamemode_key then
		PVP._join_queue(PVP.LobbyAccess.CASUAL, rt.gamemode_key)
	end
end

-- A blocked pillar's press: says why the account's standing refuses that queue (MPAPI's
-- ui/mods_not_allowed_overlay.lua) instead of queueing.
G.FUNCS.mp_pvp_find_game_standing_refused = function(e)
	local rt = e.config.ref_table
	if rt and rt.refusal then
		MPAPI.show_standing_refusal(rt.refusal)
	end
end

-- The queue kind a pillar is (MPAPI.QueueKind): Ranked pillars carry a ruleset_key.
local function queue_kind(mode)
	return mode.ruleset_key ~= nil and MPAPI.QueueKind.RANKED or MPAPI.QueueKind.CASUAL
end

-- Reactive SELECT button: QUEUE (orange) when idle or a different pillar is the active queue,
-- CANCEL (red) while this exact pillar's own queue is PvP's one active queue
-- (PVP._active_queue_matches, pvp_api/queue.lua). A pillar the account's standing refuses
-- (MPAPI.can_queue: Casual needs a valid or verified account, Ranked on the Official server a launcher-verified one,
-- matching SPDRN's own gating in BalatroMultiplayerSpeed/ui/main_menu/game_select.lua) is
-- greyed, and pressing it says why. Every OTHER pillar is also disabled while
-- one queue is active: PvP tracks only a single matchmaking handle at a time
-- (PVP._match_handle), unlike SPDRN's per-mode _queue_handles table, so queuing a second pillar
-- here would silently orphan the first handle instead of joining both.
local function build_select(mode)
	local el = MPAPI.ui_element(function()
		local this_queued = (mode.ruleset_key and PVP._active_queue_matches(PVP.LobbyAccess.RANKED, mode.ruleset_key))
			or (mode.gamemode_key and PVP._active_queue_matches(PVP.LobbyAccess.CASUAL, mode.gamemode_key))
			or false
		local other_active = PVP._is_queue_active() and not this_queued
		local may_queue, refusal = MPAPI.can_queue(queue_kind(mode))
		local standing_refused = not this_queued and not may_queue
		local unavailable = mode.queue_button == nil
			or other_active
			or standing_refused
		local config = {
			align = "cm", minh = 0.5, minw = 2.2, padding = 0.06, r = 0.1,
			colour = unavailable and G.C.UI.BACKGROUND_INACTIVE or (this_queued and G.C.RED or G.C.ORANGE),
		}
		if standing_refused and mode.queue_button ~= nil and not other_active then
			config.hover = true
			config.button = "mp_pvp_find_game_standing_refused"
			config.ref_table = { refusal = refusal }
		end
		if not unavailable then
			config.shadow = true
			config.hover = true
			config.one_press = true
			config.button = "mp_pvp_find_game_toggle_queue"
			config.ref_table = this_queued
				and { cancel = true }
				or { ruleset_key = mode.ruleset_key, gamemode_key = mode.gamemode_key }
		end
		return { nodes = { { n = G.UIT.R, config = config, nodes = {
			{ n = G.UIT.T, config = { text = this_queued and "CANCEL" or "QUEUE", scale = 0.4, colour = unavailable and G.C.UI.TEXT_INACTIVE or G.C.UI.TEXT_LIGHT, shadow = not unavailable } },
		} } } }
	end)
	_select_els[mode.key] = el
	return el.node
end

-- In group mode (opened from a Party lobby's Find Game, pvp_api/party_lobby.lua)
-- a pillar's QUEUE queues the whole lobby for its mode instead (pvp_api/group_queue.lua). A
-- mode the lobby doesn't fit is greyed; one a member's standing refuses is greyed but still
-- pressable, so the server's refusal says which mods.
local function build_group_select(mode)
	local el = MPAPI.ui_element(function()
		local available, standing_refused = PVP.group_mode_available(MPAPI.get_current_lobby(), mode.gamemode_key)
		local lit = available and not standing_refused
		local config = {
			align = "cm", minh = 0.5, minw = 2.2, padding = 0.06, r = 0.1,
			colour = lit and G.C.ORANGE or G.C.UI.BACKGROUND_INACTIVE,
		}
		if available then
			config.shadow = lit
			config.hover = true
			config.one_press = true
			config.button = "mp_pvp_group_queue_mode"
			config.ref_table = { gamemode_key = mode.gamemode_key }
		end
		return { nodes = { { n = G.UIT.R, config = config, nodes = {
			{ n = G.UIT.T, config = { text = "QUEUE", scale = 0.4, colour = lit and G.C.UI.TEXT_LIGHT or G.C.UI.TEXT_INACTIVE, shadow = lit } },
		} } } }
	end)
	_select_els[mode.key] = el
	return el.node
end

-- Live In Queue / In Game counts, polled from the server's queue_counts RPC while this page
-- is shown (PVP.start/stop_find_game_polling, called from the page's on_enter/dispose in
-- core.lua). Same shape as SPDRN's find_game counts (BalatroMultiplayerSpeed/ui/main_menu/
-- game_select.lua).
local FIND_GAME_POLL_INTERVAL_SECONDS = 5
local _poller = nil
local _latest_counts = nil
local _stat_els = {}

-- The key the server counts a pillar's players under: its queue ticket's game_mode, as
-- pvp_api/queue.lua builds it (and the matchmade lobby's label carries).
local function count_key(mode)
	if mode.ruleset_key then
		return PVP.ranked_ticket(mode.ruleset_key)
	end
	return mode.gamemode_key
end

local function stop_poller_only()
	if _poller then
		_poller.stop()
		_poller = nil
	end
end

-- From on_enter, which runs after build() filled _stat_els, so only the old poller goes.
function PVP.start_find_game_polling()
	stop_poller_only()
	_latest_counts = nil
	_poller = MPAPI.matchmaking.create_queue_counts_poller(PVP.id, FIND_GAME_POLL_INTERVAL_SECONDS, function(err, game_modes)
		_latest_counts = game_modes or {}
		for _, el in pairs(_stat_els) do
			el:update()
		end
	end)
	_poller.start()
end

function PVP.stop_find_game_polling()
	stop_poller_only()
	_stat_els = {}
end

-- One half (In Queue or In Game): a label above a darker inset value, like the HUD's Ante box.
local function build_count_half(label, value)
	return { n = G.UIT.C, config = { align = "cm", padding = 0.02, minw = 1.0, minh = 0.85, colour = mix_colours(G.C.BLACK, G.C.L_BLACK, 0.5), emboss = 0.05, r = 0.1 }, nodes = {
		{ n = G.UIT.R, config = { align = "cm" }, nodes = {
			{ n = G.UIT.T, config = { text = label, scale = 0.24, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
		} },
		{ n = G.UIT.R, config = { align = "cm" }, nodes = {
			{ n = G.UIT.T, config = { text = tostring(value), scale = 0.5, colour = G.C.IMPORTANT, shadow = true } },
		} },
	} }
end

local function build_stat_box(mode)
	local key = count_key(mode)
	local el = MPAPI.ui_element(function()
		local counts = key and _latest_counts and _latest_counts[key]
		return { nodes = { MPAPI.ui_embossed_box({ minw = 2.4, nodes = {
			build_count_half("In Queue", counts and counts.queued or 0),
			{ n = G.UIT.C, config = { minw = 0.06 }, nodes = {} },
			build_count_half("In Game", counts and counts.inMatch or 0),
		} }) } }
	end)
	_stat_els[mode.key] = el
	return el.node
end

-- Mirrors SPDRN's game_select.lua build_order_card exactly (same the_order_open button,
-- MPAPI's own G.FUNCS handler, ui/the_order.lua) -- reused as-is, not reimplemented.
local function build_order_card()
	return MPAPI.ui_embossed_box({ minw = 2.4, nodes = {
		{ n = G.UIT.R, config = { align = "cm" }, nodes = {
			{ n = G.UIT.C, config = {
				align = "cm", minw = 2.2, minh = 0.6, padding = 0.06, r = 0.1,
				colour = G.C.BLUE, shadow = true, hover = true, one_press = true, button = "the_order_open",
			}, nodes = {
				{ n = G.UIT.R, config = { align = "cm" }, nodes = {
					{ n = G.UIT.T, config = { text = "Uses", scale = 0.32, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
				} },
				{ n = G.UIT.R, config = { align = "cm" }, nodes = {
					{ n = G.UIT.T, config = { text = "The Order", scale = 0.32, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
				} },
			} },
		} },
	} })
end

-- Ranked pillars read "<ruleset> / Ranked"; a Casual pillar may take its name from its ruleset.
local function pillar_name(mode)
	if mode.ruleset_key then
		return { mode.short_name or PVP.ruleset_display_name(mode.ruleset_key), localize("k_pvp_ranked") }
	end
	if mode.display_ruleset then
		return PVP.ruleset_display_name(mode.display_ruleset)
	end
	return mode.name
end

local function build_items(modes, group)
	_select_els = {}
	_stat_els = {}
	local items = {}
	for _, mode in ipairs(modes) do
		items[#items + 1] = {
			id = mode.key,
			icon = mode.ruleset_key and PVP.ruleset_chip_sprite(mode.ruleset_key) or build_chip_sprite(),
			select = group and build_group_select(mode) or build_select(mode),
			name_plate = MPAPI.ui_pillar_name_plate({
				lines = pillar_name(mode),
				bg_colour = mix_colours(mode.colour, G.C.BLACK, 0.3),
				outline_colour = mode.colour,
			}),
			-- minh reserves room for 3 lines regardless of how many an individual mode's desc
			-- actually has (every current one is 2) -- ui_embossed_box centers its content
			-- ('cm' align) within whatever minh it's given, same as the name plate above, so
			-- this is what makes a 2-line description sit centered with breathing room instead
			-- of the box just shrinking to hug the text (2026-09-08 user feedback).
			description = MPAPI.ui_pillar_description_box({ lines = mode.desc, minh = 1.3 }),
			stat_box = build_stat_box(mode),
			extra = mode.uses_order and build_order_card() or nil,
		}
	end
	return items
end

local TABS = {
	{ key = "ranked", label = "RANKED", colour = G.C.RED },
	{ key = "casual", label = "CASUAL", colour = G.C.BLUE },
}

local function build_tab_row(category)
	local nodes = {}
	for _, tab in ipairs(TABS) do
		local is_active = tab.key == category
		nodes[#nodes + 1] = { n = G.UIT.C, config = { align = "cm", padding = 0.08 }, nodes = {
			UIBox_button({
				button = "mp_pvp_find_game_tab",
				ref_table = { category = tab.key },
				label = { tab.label },
				colour = is_active and tab.colour or G.C.UI.BACKGROUND_INACTIVE,
				minw = 3.0,
				minh = 0.6,
				scale = 0.4,
			}),
		} }
	end
	return { n = G.UIT.R, config = { align = "cm", padding = 0.1 }, nodes = nodes }
end

-- Group mode's header: the way back to the lobby instead of the Ranked/Casual tabs.
local function build_group_header()
	return { n = G.UIT.R, config = { align = "cm", padding = 0.1 }, nodes = {
		{ n = G.UIT.C, config = { align = "cm", padding = 0.08 }, nodes = {
			UIBox_button({ button = "mp_pvp_group_queue_back", label = { localize("b_back") }, colour = G.C.ORANGE, minw = 2.4, minh = 0.6, scale = 0.4 }),
		} },
		{ n = G.UIT.C, config = { align = "cm", padding = 0.08 }, nodes = {
			UIBox_button({ button = "nil", label = { localize("k_party_lobby") }, colour = G.C.BLUE, minw = 3.0, minh = 0.6, scale = 0.4 }),
		} },
	} }
end

-- Re-navigates to this same page key with different params (category), same mechanism
-- SPDRN's practice/create_lobby/find_game intents already use to switch content on
-- spdrn_game_select -- verified live, repeatedly, in both directions with no stale content
-- left behind. (An earlier version of this handler appeared to leave stale pillar nodes behind
-- when hot-patched via cctl eval mid-session for testing -- did not reproduce at all across
-- several full Ranked<->Casual cycles on a freshly launched instance, so that was very likely
-- an artifact of repeatedly redefining this function on one long-running process while
-- iterating, not a real bug in this code path.)
G.FUNCS.mp_pvp_find_game_tab = function(e)
	local rt = e.config.ref_table
	if not rt or not rt.category then
		return
	end
	MPAPI.pages.show("pvp_find_game", { category = rt.category })
end

-- Builds this page's full definition (tab row + pillar row) for the given category ("ranked" or
-- "casual", default "ranked"). `group` builds the casual pillars for queueing the current
-- Party lobby as a group, with a back-to-lobby header in place of the tabs. The caller (pvp_find_game's MPAPI.Page registration, core.lua)
-- owns the returned pillar_row controller for this page's lifetime: call :dispose() from the
-- page's own dispose() hook so the tracked chip icons get :remove()'d -- see
-- api/ui_pillar_row.lua's header comment for why that's required.
function PVP.build_find_game_ui(category, group)
	category = group and "casual" or category or "ranked"
	local modes = category == "casual" and CASUAL_MODES or RANKED_MODES

	local pillar_row = MPAPI.ui_pillar_row({ items = build_items(modes, group) })
	local definition = {
		n = G.UIT.ROOT,
		config = { align = "tm", colour = G.C.CLEAR },
		nodes = { group and build_group_header() or build_tab_row(category), pillar_row.row_node },
	}
	return { definition = definition, dispose = function(self)
		pillar_row:dispose()
		_select_els = {}
	end }
end
