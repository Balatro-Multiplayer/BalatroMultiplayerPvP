-- §22.2: "My Replays" browser -- lists MPAPI.replay.list_mine, launches a
-- full, uninteractable card-level replay of the picked run via
-- PVP._start_playback (lib/playback_launch.lua) + MPAPI.playback (the same
-- engine lib/playback_handlers.lua's opcode handlers drive).
--
-- Most-recent-first, paged with the server's cursor (Older / Newer).

-- The server's run statuses (nakama lobby/protocol.ts RunStatus) as players
-- read them: agreed/partial both mean the game finished with a result.
local STATUS_LABELS = {
	agreed = 'Finished',
	partial = 'Finished',
	disputed = 'Disputed',
	abandoned = 'Abandoned',
	restarted = 'Restarted',
}

local function format_run_label(run)
	local date = tostring(run.startedAt or ''):match('^(%d%d%d%d%-%d%d%-%d%d)') or '?'
	local status = STATUS_LABELS[run.status] or tostring(run.status or '?')
	local place = tonumber(run.place) and ('  #' .. run.place) or ''
	return date .. '  ' .. tostring(run.lobbyCode or '??????') .. '  ' .. status .. place
end

-- Finds this player's own bootstrap data in an already-built timeline
-- (MPAPI.playback.build_timeline) -- merges the first match_manifest (for
-- schema_version) + first lobby_info (gamemode/ruleset/sleeve/challenge,
-- the latter two now riding in lobby_info's options dict, see
-- networking/action_handlers.lua's action_start_game) + LAST run_info
-- (seed/deck/stake) event, so a reseeded match replays its latest seed. This
-- replaces the old single 'manifest' event's args
-- now that match framing is split across three events fired at three
-- different scopes (see BalatroMultiplayerAPI/api/replay/framing_codes.lua).
-- Returns the same {seed, deck, sleeve, challenge, stake, ruleset, gamemode}
-- shape PVP._start_playback already expects, plus schema_version for the
-- compatibility gate below.
local function find_bootstrap(timeline, player_id)
	return PVP.replay_bootstrap(timeline, player_id)
end

function PVP._launch_replay(run_id)
	MPAPI.replay.get(run_id, function(err, data)
		if err or not data or not data.logs then
			MPAPI.sendWarnMessage('[replay] failed to load run ' .. tostring(run_id) .. ': ' .. tostring(err and err.message))
			return
		end

		local timeline = MPAPI.playback.build_timeline(data.logs)
		local my_id = MPAPI.get_replay_player_id()
		local bootstrap = find_bootstrap(timeline, my_id)
		if not bootstrap then
			MPAPI.sendWarnMessage('[replay] no bootstrap data found for our own player in run ' .. tostring(run_id))
			return
		end
		if not MPAPI.replay.is_schema_compatible(bootstrap.schema_version) then
			MPAPI.sendWarnMessage(
				'[replay] recording schema_version ' .. tostring(bootstrap.schema_version)
				.. ' is newer than this client understands (' .. tostring(MPAPI.replay.SCHEMA_VERSION) .. '); refusing to play'
			)
			return
		end

		PVP._start_playback(bootstrap, function()
			local driver = MPAPI.playback.new_driver(timeline, {
				mod_id = 'pvp',
				pov_player_id = my_id,
				schema_version = bootstrap.schema_version,
				paced = true,
				on_complete = function()
					-- No `cover` field: confirmed live (via SPDRN's identical
					-- on_complete call, ported from this one) to crash --
					-- functions/UI_definitions.lua's attention_text expects a
					-- real UI target with its own `.T` transform there, not a
					-- bare {align=...} table. `cover` is optional, so omitting
					-- it entirely sidesteps that branch.
					attention_text({
						text = 'Replay finished',
						scale = 1,
						hold = 3,
						pos = { x = 0, y = 0 },
					})
				end,
			})
			driver:finish()
			driver:play()
			PVP.replay_hud.show(driver)
		end)
	end)
end

-- MPAPI account overlay's Match History tab dispatches here via
-- MPAPI.playback.launch(run.modId, run.id) (api/playback/registry.lua) --
-- registered under PVP.id (the SMODS mod id, what run.modId actually is,
-- since MPAPI.create_lobby/create_local_lobby are always called with PVP.id
-- as their own mod_id argument), NOT the literal 'pvp' string used above for
-- mod_id = 'pvp' / register_handler('pvp', ...) -- that's a separate,
-- unrelated opcode-dispatch namespace this PvP mod happens to also use.
MPAPI.playback.register_launcher(PVP.id, PVP._launch_replay)

-- Server pages hold every mod's runs; PvP's own are filtered out of them, so
-- a page with none of ours is skipped (up to MAX_SKIP pages) rather than
-- shown empty while older ones exist.
local MAX_SKIP = 5

-- cursors[i] is the server cursor page i starts from (nil for the newest).
local browser = { cursors = { false }, index = 1 }

local function fetch_pvp_page(cursor, skipped, callback)
	MPAPI.replay.list_mine({ cursor = cursor or nil }, function(err, data)
		if err then return callback(err) end
		local runs = {}
		for _, run in ipairs((data and data.runs) or {}) do
			-- list_mine returns every mod's runs (the server has no modId filter);
			-- another mod's replay would launch with the wrong playback engine.
			if run.modId == PVP.id then runs[#runs + 1] = run end
		end
		local next_cursor = data and data.cursor
		if #runs == 0 and next_cursor and skipped < MAX_SKIP then
			return fetch_pvp_page(next_cursor, skipped + 1, callback)
		end
		callback(nil, runs, next_cursor)
	end)
end

local function show_page(runs, has_older)
	local rows = {
		{ n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
			{ n = G.UIT.T, config = { text = 'My Replays', scale = 0.6, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
		} },
	}

	if #runs == 0 then
		rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cm', minh = 2 }, nodes = {
			{ n = G.UIT.T, config = { text = 'No replays yet.', scale = 0.4, colour = G.C.UI.TEXT_LIGHT } },
		} }
	else
		for _, run in ipairs(runs) do
			rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
				UIBox_button({
					button = 'mp_pvp_replay_pick_' .. run.id,
					label = { format_run_label(run) },
					colour = G.C.BLUE,
					minw = 5,
					minh = 0.6,
					scale = 0.35,
				}),
			} }
			G.FUNCS['mp_pvp_replay_pick_' .. run.id] = function()
				G.FUNCS.exit_overlay_menu()
				PVP._launch_replay(run.id)
			end
		end
	end

	local nav = {}
	if browser.index > 1 then
		nav[#nav + 1] = UIBox_button({ button = 'mp_pvp_replay_newer', label = { 'Newer' }, colour = G.C.ORANGE, minw = 2, minh = 0.6, scale = 0.35 })
	end
	if has_older then
		nav[#nav + 1] = UIBox_button({ button = 'mp_pvp_replay_older', label = { 'Older' }, colour = G.C.ORANGE, minw = 2, minh = 0.6, scale = 0.35 })
	end
	if #nav > 0 then
		rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = nav }
	end

	G.FUNCS.overlay_menu({ definition = create_UIBox_generic_options({ contents = rows }) })
end

local function open_page(index)
	fetch_pvp_page(browser.cursors[index], 0, function(err, runs, next_cursor)
		if err then
			MPAPI.sendWarnMessage('[replay] list_mine failed: ' .. tostring(err.message))
			return
		end
		browser.index = index
		browser.cursors[index + 1] = next_cursor or nil
		show_page(runs, next_cursor ~= nil)
	end)
end

G.FUNCS.mp_pvp_replay_older = function()
	if browser.cursors[browser.index + 1] then open_page(browser.index + 1) end
end

G.FUNCS.mp_pvp_replay_newer = function()
	if browser.index > 1 then open_page(browser.index - 1) end
end

G.FUNCS.mp_pvp_open_replay_browser = function()
	browser = { cursors = { false }, index = 1 }
	open_page(1)
end
