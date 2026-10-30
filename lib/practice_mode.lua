-- Singleplayer ruleset state (parallels PVP.LOBBY.config.ruleset for multiplayer).
-- Live rulesets / game-state / networking read PVP.SP + PVP.is_practice_mode() to know
-- they are NOT in practice, so this state core must always exist.
PVP.SP = { ruleset = nil, practice = false, unlimited_slots = false, edition_cycling = false }

function PVP.is_practice_mode()
	return PVP.SP.practice == true
end

-- True for any active PvP session -- a real networked match or practice --
-- as opposed to being at the main menu with no run underway. Formerly also
-- included a ghost-replay branch (PVP.GHOST.is_active()); the ghost system
-- was removed, not replaced, so this is just the remaining two cases.
function PVP.is_mp_or_practice()
	return PVP.LOBBY.code or PVP.is_practice_mode()
end

-- Client-only practice lobby: no server lobby is ever allocated (MPAPI.create_local_lobby),
-- so there's nothing to be orphaned if the run is abandoned. `ruleset_key` is a plain
-- ruleset id (e.g. "ruleset_mp_balanced"/"ruleset_mp_expanded"/"ruleset_mp_vanilla"/
-- "ruleset_mp_smallworld"), not a PVP.PVP_GAMEMODES gamemode key -- practice was always
-- 1v1-only by design (see below), so it needs no format/shape choice, only a ruleset.
-- Royale and Nemesis-as-a-distinct-shape are intentionally not offered here: both
-- resolve to the same ruleset + gamemode_mp_attrition as plain Vanilla/whatever ruleset
-- is picked, and their whole distinguishing mechanic (N-player rank-and-cut / rotating
-- pairing) has no meaning with a single practice player. The match format itself is
-- hardcoded to Nemesis's 1v1 shape below.
--
-- Reuses the exact same primitives the real private-lobby flow uses (PVP.pvp_create_private_lobby
-- in pvp_api/flow.lua): PVP.setup_lobby_mirror to bridge the API lobby into PVP.LOBBY.*, and
-- PVP.pvp_lobby_metadata to resolve gamemode/ruleset/deck/stake/starting_lives/pvp_start_round
-- -- so practice can't drift from what a real lobby using the pvp_nemesis gamemode key
-- would set up.
--
-- `loadout` is the deck, stake and seed from the Practice run setup screen
-- (PVP.open_practice_setup): { back = deck name, stake = number, seed = string or nil }.
-- A nil seed is a random one, as in vanilla.
--
-- The PvP boss ("nemesis") blind still spawns and plays out normally from ante
-- PVP.LOBBY.config.pvp_start_round onward (see the practice branches in ui/game/game_state.lua
-- and ui/game/blind_hud.lua's opponent-score masking) -- it's neutered, not skipped: the
-- opponent's score/hands always read "???", every hand is always usable, and no life is ever
-- lost. Ante 8 ends the run naturally (see game_state.lua's update_new_round: the "prevent
-- player from winning" override that lets real matches continue past ante 8 via lives is
-- skipped in practice, so vanilla's own win_ante=8 default fires win_game() as normal).
function PVP._start_practice(ruleset_key, loadout)
	ruleset_key = ruleset_key or PVP.PVP_GAMEMODES.pvp_nemesis.ruleset
	local gamemode_key = PVP.GamemodeKey.PVP_NEMESIS

	-- Same queue gate as PVP._start_playback (lib/playback_launch.lua): without it
	-- the start_run guard blocks only after PVP.SP.practice and a local lobby are
	-- already set up, leaking practice state into the match the queue then forms.
	if MPAPI.matchmaking.guard_queued(function() return PVP._start_practice(ruleset_key, loadout) end) then
		return
	end

	-- Clean slate: don't inherit deck/stake/ruleset leftovers from whatever the player
	-- was doing before entering practice (e.g. a private lobby with different_decks set).
	PVP.reset_lobby_config()
	-- reset_lobby_config() above stamps its own hardcoded default (expanded), not
	-- this practice run's -- set the actual requested ruleset directly (bypassing
	-- PVP.reset_ruleset_to_gamemode_default, which resolves off a gamemode key, not
	-- a bare ruleset key).
	PVP.LOBBY.config.ruleset = ruleset_key
	PVP.LOBBY.config.gamemode = "gamemode_mp_attrition"
	if loadout then
		PVP.LOBBY.config.back = loadout.back
		PVP.LOBBY.config.stake = loadout.stake
	end

	PVP.SP.practice = true
	PVP.SP.ruleset = ruleset_key

	local lobby = MPAPI.create_local_lobby(PVP.id, { max_players = 1 })
	if not lobby then
		PVP.SP.practice = false
		return
	end
	lobby.suppress_lobby_view = true
	PVP._pvp_kind = PVP.LobbyAccess.PRACTICE
	PVP._pvp_gamemode = gamemode_key
	PVP.setup_lobby_mirror(lobby)

	-- No real opponent to populate these from network sync -- give them sane, non-nil
	-- defaults so nothing that reads them (PVP.UTILS.get_nemesis_key's own lives<=1 check)
	-- hits a nil comparison. Never decremented in practice (see update_new_round's
	-- practice branch), so this value just sits here for the whole run.
	PVP.GAME.lives = PVP.LOBBY.config.starting_lives

	lobby:on(MPAPI.LobbyEvent.CONNECTED, function()
		-- After setup_lobby_mirror's own CONNECTED handler (registered first, so it runs
		-- first) has already mirrored the (empty, no real opponent) player roster --
		-- otherwise its mirror_players() call overwrites this right back to {}.
		PVP.LOBBY.guest = { username = "???", id = "practice" }
		lobby:set_metadata(PVP.pvp_lobby_metadata(gamemode_key, PVP.LobbyAccess.PRACTICE))
		G.FUNCS.lobby_start_run(nil, { seed = loadout and loadout.seed })
	end)
end

-- Practice has no lobby code, so its end screens are vanilla's (create_UIBox_game_over/win
-- only switch to the PvP end screen when PVP.LOBBY.code is set), and their Main Menu and
-- New Run buttons never left the practice session: the next plain singleplayer run was
-- still a practice run of the old ruleset (Lobby Info button, ruleset pool rules, modifiers).
-- Leaving here, at the two vanilla exits, puts the player back in plain singleplayer.
local function leave_practice()
	if not PVP.is_practice_mode() or PVP.LOBBY.code then
		return
	end
	local lobby = MPAPI.get_current_lobby()
	if lobby then
		lobby:leave()
	end
	PVP.end_session()
end

local go_to_menu_ref = G.FUNCS.go_to_menu
G.FUNCS.go_to_menu = function(e)
	leave_practice()
	return go_to_menu_ref(e)
end

-- The ruleset a Practice pillar picked, while its run setup screen is open. Play on that
-- screen starts the Practice run; any other run setup screen clears it.
local setup_ruleset = nil

function PVP.practice_setup_ruleset()
	return setup_ruleset
end

-- Vanilla's run setup screen with only the New Run tab: Continue would load a plain saved
-- run, and a challenge has its own deck and rules.
local function practice_run_setup_definition()
	return create_UIBox_generic_options({
		contents = {
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0, draw_layer = 1 },
				nodes = {
					create_tabs({
						tabs = {
							{
								label = localize("b_new_run"),
								chosen = true,
								tab_definition_function = G.UIDEF.run_setup_option,
								tab_definition_function_args = "New Run",
							},
						},
						snap_to_nav = true,
					}),
				},
			},
		},
	})
end

-- Opens over the Practice pillars, so Back shows them again.
function PVP.open_practice_setup(ruleset_key)
	setup_ruleset = ruleset_key
	G.run_setup_seed = nil
	G.SETTINGS.paused = true
	G.FUNCS.overlay_menu({ definition = practice_run_setup_definition() })
end

-- The run setup screen's picks, as vanilla's start_setup_run reads them. An empty seed field
-- is a random seed.
local function picked_loadout()
	local seed = G.run_setup_seed and G.setup_seed or nil
	return {
		back = G.GAME.viewed_back and G.GAME.viewed_back.name or "Red Deck",
		stake = G.PROFILES[G.SETTINGS.profile].MEMORY.stake or 1,
		seed = seed ~= "" and seed or nil,
	}
end

local setup_run_ref = G.FUNCS.setup_run
G.FUNCS.setup_run = function(e)
	setup_ruleset = nil
	return setup_run_ref(e)
end

local start_setup_run_ref = G.FUNCS.start_setup_run
G.FUNCS.start_setup_run = function(e)
	local ruleset_key = setup_ruleset
	setup_ruleset = nil
	if ruleset_key then
		G.FUNCS.exit_overlay_menu()
		return PVP._start_practice(ruleset_key, picked_loadout())
	end
	leave_practice()
	return start_setup_run_ref(e)
end
