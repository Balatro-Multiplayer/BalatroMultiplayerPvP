-- Custom pause/options screen for an active PvP run (mirrors Speed's ui/run_options.lua).
-- Shows Settings + Seed Change (unanimous vote, gated) + Forfeit. Wired via
-- prevent_pause + options_builder in core.lua's register_mod; the API renders this for
-- the in-run pause overlay and leaves the non-run (main-menu) options box vanilla.

G.FUNCS.mp_pvp_seed_change = function()
	G.FUNCS.exit_overlay_menu()
	-- A unanimous vote restarts the match on a fresh seed (see pvp_seed_vote action).
	PVP.cast_seed_vote()
end

G.FUNCS.mp_pvp_draw_vote = function()
	G.FUNCS.exit_overlay_menu()
	-- A unanimous vote ends the match as a draw (see pvp_draw_vote action).
	PVP.cast_draw_vote()
end

G.FUNCS.mp_pvp_forfeit = function()
	G.FUNCS.exit_overlay_menu()
	-- Practice is solo: there is no opponent or host referee to resolve a forfeit
	-- broadcast, so pressing Forfeit did nothing. It ends the practice run instead
	-- (go_to_menu also leaves practice, see lib/practice_mode.lua).
	if PVP.is_practice_mode() and not PVP.LOBBY.code then
		G.FUNCS.go_to_menu()
		return
	end
	-- A matchmade match (2 players or more) asks first: forfeit or contest.
	if PVP.contest_offered() then
		PVP.UI.show_contest_modal()
		return
	end
	PVP.pvp_forfeit()
end

-- Seed change is only offered for the first few minutes of a run.
PVP.SEED_CHANGE_WINDOW = 300

PVP.create_run_options = function()
	-- §17.9: unlike Speedrunning's version of this same overlay (a timed race, where
	-- pausing must never stop the clock), PvP's pause menu is meant to actually pause --
	-- prevent_pause (core.lua) only means "render our own options box instead of
	-- vanilla's," not "never pause." view.lua's G.FUNCS.options wrapper calls this
	-- builder directly instead of vanilla's own G.FUNCS.options (which sets this same
	-- flag before building create_UIBox_options()), so nothing else sets it for us.
	-- G.FUNCS.exit_overlay_menu already unconditionally resets this to false on any
	-- close path (ESC or an explicit button here), so no unpause wiring is needed.
	G.SETTINGS.paused = true

	-- Each button is its own row inside one column so they stack vertically.
	local rows = {}
	local function add_row(node)
		rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.08 }, nodes = { node } }
	end

	add_row(UIBox_button({ button = "settings", label = { localize("b_settings") }, minw = 5, focus_args = { snap_to = true } }))

	-- Seed Change visibility/enabled state:
	--   * hidden entirely when the gamemode sets seed_change_allowed = false
	--   * shown but disabled once SEED_CHANGE_WINDOW seconds have elapsed
	local lobby = MPAPI.get_current_lobby()
	local meta = lobby and lobby:get_metadata()
	local gm = meta and meta.queue_mode and MPAPI.GameModes[meta.queue_mode]
	if not gm or gm.seed_change_allowed ~= false then
		local within_window = PVP._run_started_at ~= nil
			and (love.timer.getTime() - PVP._run_started_at) < PVP.SEED_CHANGE_WINDOW
		add_row(MPAPI.disableable_button({
			button = "mp_pvp_seed_change",
			label = { "Seed Change" },
			colour = G.C.BLUE,
			minw = 5,
			enabled = within_window,
		}).node)
	end

	-- Draw vote: hidden entirely when the gamemode sets draw_vote_allowed = false.
	-- No time window, unlike Seed Change above -- a draw ending the match outright
	-- is a different risk profile than reseeding mid-run.
	-- Also hidden in practice: with no opponent the 1/1 vote "won", and vanilla's game
	-- over screen came up outside any blind, reading "Defeated By ERROR".
	if (not gm or gm.draw_vote_allowed ~= false) and not PVP.is_practice_mode() then
		add_row(UIBox_button({
			button = "mp_pvp_draw_vote",
			label = { localize("k_draw_vote") },
			colour = G.C.BLUE,
			minw = 5,
		}))
	end

	add_row(UIBox_button({ button = "mp_pvp_forfeit", label = { "Forfeit" }, minw = 5, colour = G.C.RED }))

	-- §17.9: Collection/Mods, shared with SPDRN's identical overlay (both mods
	-- previously stopped at 3 buttons; the doc's claimed 5-button set needs
	-- these two on top of the mode-specific ones above).
	for _, row in ipairs(MPAPI.pause_menu_extra_rows()) do
		rows[#rows + 1] = row
	end

	return create_UIBox_generic_options({
		contents = {
			{ n = G.UIT.C, config = { align = "cm" }, nodes = rows },
		},
	})
end
