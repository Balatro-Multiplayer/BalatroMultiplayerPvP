-- Main menu, copied from the Speedrunning mod's ui/main_menu (buttons.lua + view.lua)
-- and rewired to PvP. Same layout: a big Find Game, a Leaderboard/Practice stack, a
-- Join Lobby column (by-code / from-clipboard), and a big Create Lobby.

PVP.main_menu = PVP.main_menu or { buttons = {}, initialized = false }

-- Distinct teal for the Leaderboard button (matches Speed).
local _leaderboard_colour = { 0.20, 0.74, 0.72, 1 }

function PVP.main_menu.create_buttons()
	local M = PVP.main_menu
	if M.initialized then
		return
	end
	local b = M.buttons

	M.find_game_args = {
		id = "mp_pvp_find_game",
		button = "mp_pvp_find_game",
		colour = G.C.BLUE,
		minw = 3.65,
		minh = 1.55,
		label = { localize("b_find_game_cap") },
		scale = 0.7,
		col = true,
		enabled = function()
			return MPAPI.is_connected()
		end,
	}
	b.find_game = MPAPI.disableable_button(M.find_game_args)
	b.create_lobby = MPAPI.disableable_button({
		id = "mp_pvp_create_lobby",
		button = "mp_pvp_create_lobby",
		colour = G.C.GREEN,
		minw = 3.65,
		minh = 1.55,
		label = localize("b_create_lobby_cap"),
		scale = 0.7,
		col = true,
		enabled = function()
			return MPAPI.is_connected()
		end,
	})
	b.join_by_code = MPAPI.disableable_button({
		id = "mp_pvp_join_lobby_by_code",
		button = "mp_pvp_join_lobby_by_code",
		colour = G.C.RED,
		minw = 3.65,
		minh = 0.6,
		label = { localize("b_by_code_cap") },
		scale = 0.45,
		enabled = function()
			return MPAPI.is_connected()
		end,
	})
	b.join_from_clipboard = MPAPI.disableable_button({
		id = "mp_pvp_join_lobby_from_clipboard",
		button = "mp_pvp_join_lobby_from_clipboard",
		colour = G.C.PURPLE,
		minw = 3.65,
		minh = 0.6,
		label = { localize("b_from_clipboard_cap") },
		scale = 0.45,
		enabled = function()
			return MPAPI.is_connected()
		end,
	})
	b.practice = MPAPI.disableable_button({
		id = "mp_pvp_practice",
		button = "mp_pvp_practice",
		colour = G.C.ORANGE,
		minw = 2.65,
		minh = 1.35,
		label = { localize("b_practice_cap") },
		scale = 0.54,
		col = true,
		-- Practice is fully local (MPAPI.create_local_lobby) -- no server needed.
		enabled = true,
	})
	b.leaderboard = MPAPI.disableable_button({
		id = "mp_pvp_leaderboard",
		button = "mp_pvp_open_leaderboard",
		colour = _leaderboard_colour,
		minw = 2.65,
		minh = 1.35,
		label = { localize("b_leaderboard_cap") },
		scale = 0.54,
		col = true,
		enabled = function()
			return MPAPI.is_connected()
		end,
	})
	M.initialized = true
end

PVP.update_main_menu_buttons = function()
	local M = PVP.main_menu
	if not M.initialized then
		return
	end
	M.buttons.find_game:update()
	M.buttons.create_lobby:update()
	M.buttons.join_by_code:update()
	M.buttons.join_from_clipboard:update()
	M.buttons.leaderboard:update()
end

-- Swap the Find Game button between search / cancel (called by queue.lua).
PVP._show_searching_state = function(searching)
	local M = PVP.main_menu
	if not M.initialized or not M.find_game_args then
		return
	end
	if searching then
		M.find_game_args.label = { localize("b_cancel_search_cap") }
		M.find_game_args.button = "mp_pvp_cancel_queue"
		M.find_game_args.colour = G.C.RED
	else
		M.find_game_args.label = { localize("b_find_game_cap") }
		M.find_game_args.button = "mp_pvp_find_game"
		M.find_game_args.colour = G.C.BLUE
	end
	M.buttons.find_game:update()
end

PVP.build_pre_lobby_ui = function()
	PVP.main_menu.create_buttons()
	MPAPI.set_logo_offset(0, true)
	local b = PVP.main_menu.buttons
	-- Back from a group queue's public match without having made it home
	-- (still in a run, or the automatic return gave up): offer it here.
	local Group = MPAPI.matchmaking and MPAPI.matchmaking.group
	local pending = Group and Group.pending_return and Group.pending_return(PVP.id)
	local return_row = { n = G.UIT.R, config = { align = "cm" }, nodes = {} }
	if pending then
		return_row = { n = G.UIT.R, config = { align = "cm", padding = 0.1 }, nodes = {
			UIBox_button({
				id = "mp_pvp_group_return",
				button = "mp_pvp_group_return",
				label = { localize("b_group_return_to_lobby") .. " " .. tostring(pending.home_code) },
				colour = G.C.GREEN,
				minw = 5,
				minh = 0.8,
				scale = 0.5,
			}),
		} }
	end
	return {
		n = G.UIT.ROOT,
		config = { align = "cm", colour = G.C.CLEAR },
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "bm" },
				nodes = {
					return_row,
					{
						n = G.UIT.R,
						config = { align = "cm", padding = 0.1, r = 0.1, emboss = 0.1, colour = G.C.L_BLACK, mid = true },
						nodes = {
							b.find_game.node,
							{
								n = G.UIT.C,
								config = { align = "cm" },
								nodes = {
									{ n = G.UIT.R, config = { align = "cm" }, nodes = {
										{ n = G.UIT.C, config = { align = "cm", padding = 0.05 }, nodes = { b.leaderboard.node } },
										{ n = G.UIT.C, config = { align = "cm", padding = 0.05 }, nodes = { b.practice.node } },
									} },
								},
							},
							{
								n = G.UIT.C,
								config = { align = "cm", padding = 0.1, r = 0.2, colour = G.C.BLACK },
								nodes = {
									{
										n = G.UIT.C,
										config = { align = "cm", maxh = 1.4 },
										nodes = {
											{ n = G.UIT.T, config = { text = localize("k_join_lobby_cap"), scale = 0.45, colour = G.C.UI.TEXT_LIGHT, vert = true, maxh = 1.4 } },
										},
									},
									{
										n = G.UIT.C,
										config = { align = "cm", padding = 0.1 },
										nodes = {
											{ n = G.UIT.R, config = { align = "cm" }, nodes = { b.join_by_code.node } },
											{ n = G.UIT.R, config = { align = "cm" }, nodes = { b.join_from_clipboard.node } },
										},
									},
								},
							},
							b.create_lobby.node,
						},
					},
				},
			},
		},
	}
end

-- ── Create Lobby overlay ─────────────────────────────────────────────────────
-- Gamemode (shape) picker, same grid-of-buttons style as the Practice overlay
-- below. Nemesis IS the 1v1 shape (its rotating pairing degenerates identically
-- to plain pairwise at exactly 2 players, see referee.lua) so there's no separate
-- "1v1" option. Ruleset (default Balanced) is picked afterward, once inside the
-- lobby, via Lobby Options (ui/lobby/lobby_options.lua) -- not here.
-- Pillar page: ui/main_menu/game_select.lua; each pillar presses the per-mode handler below.
G.FUNCS.mp_pvp_create_lobby = function()
	MPAPI.pages.show("pvp_game_select", { intent = "create_lobby" })
end

G.FUNCS.mp_pvp_create_lobby_nemesis = function()
	G.FUNCS.exit_overlay_menu()
	PVP.pvp_create_private_lobby(PVP.GamemodeKey.PVP_NEMESIS)
end

G.FUNCS.mp_pvp_create_lobby_royale = function()
	G.FUNCS.exit_overlay_menu()
	PVP.pvp_create_private_lobby("pvp_royale")
end

G.FUNCS.mp_pvp_create_lobby_manhunt = function()
	G.FUNCS.exit_overlay_menu()
	PVP.pvp_create_private_lobby("pvp_manhunt")
end

G.FUNCS.mp_pvp_create_lobby_teams = function()
	G.FUNCS.exit_overlay_menu()
	PVP.pvp_create_private_lobby("pvp_teams")
end

G.FUNCS.mp_pvp_create_lobby_party = function()
	G.FUNCS.exit_overlay_menu()
	PVP.pvp_create_party_lobby()
end

-- ── Join overlays (copied from Speed's join.lua) ─────────────────────────────
-- CONFIRMED LIVE BUG, fixed by capturing this table directly: create_UIBox_generic_options
-- wraps create_text_input's node in a way that leaves config.ref_table nil on the node
-- create_UIBox_generic_options's own get_UIE_by_ID(id) resolves back later -- the confirm
-- button used to re-fetch the node by id and read code.config.ref_table.text off of it,
-- which is always nil under this wrapper (reproduced live: the typed code still renders
-- correctly on screen -- create_text_input itself writes into THIS SAME table -- but
-- get_UIE_by_ID's returned node's own .config.ref_table field is nil regardless of input
-- method, real click+type or simulated), so "Join Lobby" silently no-opped on every valid
-- code with no error shown. Capturing the table by closure instead of re-deriving it from
-- the node tree sidesteps whatever create_UIBox_generic_options does to that field, since
-- it's the same physical table object create_text_input mutates either way.
local mp_pvp_lobby_code_ref = { text = "" }
G.FUNCS.mp_pvp_join_lobby_by_code = function()
	mp_pvp_lobby_code_ref.text = ""
	G.FUNCS.overlay_menu({
		definition = create_UIBox_generic_options({
			snap_back = true,
			contents = {
				{
					n = G.UIT.R,
					config = { align = "cm", padding = 0.2, r = 0.1 },
					nodes = {
						{ n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = {
							{ n = G.UIT.T, config = { text = localize("k_lobby_code_cap"), scale = 0.5, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
						} },
						{ n = G.UIT.R, config = { align = "cm", padding = 0.1 }, nodes = {
							create_text_input({ id = "mp_pvp_lobby_code_input", ref_table = mp_pvp_lobby_code_ref, ref_value = "text", prompt_text = localize("k_lobby_code_cap"), max_length = 6, all_caps = true, w = 4, h = 0.6 }),
						} },
						{ n = G.UIT.R, config = { align = "cm", padding = 0.1 }, nodes = {
							UIBox_button({ id = "mp_pvp_join_lobby_confirm", button = "mp_pvp_join_lobby_confirm", colour = G.C.GREEN, minw = 2, minh = 0.6, label = { localize("k_join_lobby_cap") }, scale = 0.45 }),
						} },
					},
				},
			},
		}),
	})
end

G.FUNCS.mp_pvp_join_lobby_confirm = function()
	local text = mp_pvp_lobby_code_ref.text or ""
	text = text:match("^%s*(.-)%s*$") or ""
	if #text > 0 then
		G.FUNCS.exit_overlay_menu()
		PVP.pvp_join_lobby(text)
	end
end

G.FUNCS.mp_pvp_join_lobby_from_clipboard = function()
	local code = (love.system.getClipboardText and love.system.getClipboardText()) or ""
	code = code:match("^%s*(.-)%s*$") or ""
	if #code > 0 then
		PVP.pvp_join_lobby(code)
	end
end

-- ── Practice overlay ─────────────────────────────────────────────────────────
-- Ruleset picker, not a gamemode picker: Royale/Nemesis both resolve to the same
-- ruleset_mp_vanilla + gamemode_mp_attrition as plain Vanilla and have no distinguishing
-- mechanic with a single practice player (see PVP._start_practice's header comment), so
-- they're intentionally not offered here.
-- Pillar page: ui/main_menu/game_select.lua; each pillar presses the per-mode handler below,
-- which opens the run setup screen (deck, stake, seed) for that ruleset.
G.FUNCS.mp_pvp_practice = function()
	MPAPI.pages.show("pvp_game_select", { intent = "practice" })
end

G.FUNCS.mp_pvp_practice_balanced = function()
	PVP.open_practice_setup(PVP.RulesetKey.BALANCED)
end

G.FUNCS.mp_pvp_practice_expanded = function()
	PVP.open_practice_setup(PVP.RulesetKey.EXPANDED)
end

G.FUNCS.mp_pvp_practice_vanilla = function()
	PVP.open_practice_setup(PVP.RulesetKey.VANILLA)
end

G.FUNCS.mp_pvp_practice_smallworld = function()
	PVP.open_practice_setup(PVP.RulesetKey.SMALLWORLD)
end

-- ── Replay/Spectate overlay ───────────────────────────────────────────────
-- §22.2/§22.3: a small picker routing to the two list screens
-- (ui/replay/replay_browser.lua, ui/replay/spectate_browser.lua), same
-- overlay style as the Practice/Create Lobby pickers above.
G.FUNCS.mp_pvp_open_replay_menu = function()
	G.FUNCS.overlay_menu({
		definition = create_UIBox_generic_options({
			contents = {
				{ n = G.UIT.R, config = { align = "cm", padding = 0.1 }, nodes = {
					{ n = G.UIT.T, config = { text = "Replay / Spectate", scale = 0.6, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
				} },
				{
					n = G.UIT.R,
					config = { align = "cm", padding = 0.1 },
					nodes = {
						{ n = G.UIT.C, config = { align = "cm", padding = 0.08 }, nodes = {
							UIBox_button({ button = "mp_pvp_open_replay_browser_from_menu", label = { "My", "Replays" }, colour = G.C.BLUE, minw = 2.5, minh = 2.0, scale = 0.5, col = true }),
						} },
						{ n = G.UIT.C, config = { align = "cm", padding = 0.08 }, nodes = {
							UIBox_button({ button = "mp_pvp_open_spectate_browser_from_menu", label = { "Spectate" }, colour = G.C.PURPLE, minw = 2.5, minh = 2.0, scale = 0.5, col = true }),
						} },
					},
				},
			},
		}),
	})
end

G.FUNCS.mp_pvp_open_replay_browser_from_menu = function()
	G.FUNCS.exit_overlay_menu()
	G.FUNCS.mp_pvp_open_replay_browser()
end

G.FUNCS.mp_pvp_open_spectate_browser_from_menu = function()
	G.FUNCS.exit_overlay_menu()
	G.FUNCS.mp_pvp_open_spectate_browser()
end
