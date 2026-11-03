local A = PVP._pvp_action_helpers.A
local relay = PVP._pvp_action_helpers.relay

-- Stake indices the hovered stake applies, easiest first. White (and anything
-- else marked hide_from_run_info) is included only when it is the stake itself.
local function stake_effect_indices(stake_index)
	local center = G.P_CENTER_POOLS.Stake[stake_index]
	local indices = {}
	if center and SMODS.build_stake_chain then
		for order in pairs(SMODS.build_stake_chain(center)) do
			indices[#indices + 1] = order
		end
	else
		for i = 1, stake_index do
			indices[#indices + 1] = i
		end
	end
	table.sort(indices)
	local shown = {}
	for _, index in ipairs(indices) do
		local stake = G.P_CENTER_POOLS.Stake[index]
		if stake and (index == stake_index or not stake.hide_from_run_info) then
			shown[#shown + 1] = index
		end
	end
	return shown
end

-- One stake's effect lines. The trailing "applies previous stakes" line is
-- dropped, because the popup lists those stakes itself.
local function stake_desc_rows(stake_index)
	local center = G.P_CENTER_POOLS.Stake[stake_index]
	if not center then
		return {}
	end
	local vars, key, set = {}, center.key, center.set or "Stake"
	if type(center.loc_vars) == "function" then
		local ok, res = pcall(center.loc_vars, center, {})
		if ok and type(res) == "table" then
			vars = res.vars or {}
			key = res.key or key
			set = res.set or set
		end
	end
	local nodes = {}
	localize({ type = "descriptions", key = key, set = set, nodes = nodes, vars = vars })
	if center.applied_stakes and #center.applied_stakes > 0 then
		nodes[#nodes] = nil
	end
	local rows = {}
	for _, line in ipairs(nodes) do
		rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm" }, nodes = line }
	end
	return rows
end

-- Hover popup for a Draft stake chip: the stake's name, then every effect it
-- applies, from the easiest stake up to this one.
local function draft_stake_popup(stake_index)
	local center = G.P_CENTER_POOLS.Stake[stake_index]
	local name = center and localize({ type = "name_text", set = "Stake", key = center.key }) or ""
	local blocks = {
		{
			n = G.UIT.R,
			config = { align = "cm", padding = 0.04 },
			nodes = {
				{ n = G.UIT.T, config = { text = name, scale = 0.42, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
			},
		},
	}
	for _, index in ipairs(stake_effect_indices(stake_index)) do
		local desc = stake_desc_rows(index)
		if #desc > 0 then
			blocks[#blocks + 1] = {
				n = G.UIT.R,
				config = { align = "cm", padding = 0.03 },
				nodes = {
					{
						n = G.UIT.C,
						config = {
							align = "cm",
							minw = 0.32,
							minh = 0.32,
							r = 0.08,
							colour = get_stake_col(index),
							emboss = 0.05,
						},
						nodes = {},
					},
					{ n = G.UIT.C, config = { minw = 0.08 } },
					{
						n = G.UIT.C,
						config = {
							align = "cm",
							padding = 0.05,
							colour = G.C.WHITE,
							r = 0.08,
							minw = 4.2,
							maxw = 5.2,
						},
						nodes = desc,
					},
				},
			}
		end
	end
	return {
		n = G.UIT.ROOT,
		config = { align = "cm", colour = G.C.CLEAR, padding = 0.05 },
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cm", colour = G.C.L_BLACK, r = 0.1, padding = 0.08, emboss = 0.05 },
				nodes = blocks,
			},
		},
	}
end

-- Wire PvP's Draft policy and presentation into MPAPI.BanPick.
function PVP._ban_pick_config_for(gm_def, ruleset)
	local bp = gm_def.ban_pick
	local max_stake = (PVP.DECK and PVP.DECK.MAX_STAKE and PVP.DECK.MAX_STAKE > 0) and PVP.DECK.MAX_STAKE or 8
	return {
		id = PVP.SETUP.Step.DRAFT,
		pool_size = bp.pool_size,
		keep = bp.keep,
		schedule = bp.schedule,
		build_pool = function()
			return PVP.DRAFT.build({
				ruleset = ruleset,
				size = bp.pool_size,
				max_stake = PVP.DECK and PVP.DECK.MAX_STAKE,
			})
		end,
		-- The server shuffles the pool; show it lowest stake first, then by deck.
		tile_order = PVP.DRAFT.tile_order,
		max_stake = max_stake,
		-- Pin an enlarged stake chip to each deck back's corner (the stock back sticker is too small
		-- to read at this tile size). The chip is its own object: hovering it shows what the stake
		-- does, and clicking it selects the deck. The deck's own tooltip still names the stake.
		decorate_tile = function(card, item)
			local stake_index = type(item) == "table" and tonumber(item.stake)
			local stake = stake_index and G.P_CENTER_POOLS.Stake[stake_index]
			if not stake then
				return
			end
			local size = card.T.w * 0.5
			local chip = get_stake_sprite(stake_index, size)
			-- The card hashes itself after drawing this chip, and the cursor picks the latest
			-- hit. Hash the chip again afterwards so the corner wins over the deck under it.
			-- Shiny stakes replace Sprite:draw and never hash themselves, so this covers those too.
			local card_draw = card.draw
			function card:draw(layer)
				card_draw(self, layer)
				add_to_drawhash(chip)
			end
			chip.states.collide.can = true
			chip.states.drag.can = false
			chip.config = chip.config or {}
			chip:set_role({
				major = card,
				role_type = "Minor",
				offset = { x = card.T.w - size * 1.05, y = card.T.h - size * 1.05 },
				xy_bond = "Strong",
				wh_bond = "Weak",
				r_bond = "Strong",
				scale_bond = "Strong",
			})
			card.children.mp_stake_chip = chip
			card.mp_tile_note = localize({ type = "name_text", set = "Stake", key = stake.key })

			function chip:click()
				card:click()
			end

			function chip:hover()
				self:juice_up(0.05, 0.03)
				play_sound("paper1", math.random() * 0.2 + 0.9, 0.3)
				local popup_direction = self.T.y < G.CARD_H * 0.8 and "bm" or "tm"
				self.config.h_popup = draft_stake_popup(stake_index)
				self.config.h_popup_config = {
					major = self,
					parent = self,
					xy_bond = "Strong",
					r_bond = "Weak",
					wh_bond = "Weak",
					offset = { x = 0, y = popup_direction == "tm" and -0.13 or 0.1 },
					type = popup_direction,
				}
				Node.hover(self)
			end
		end,
		on_refresh = function()
			if PVP.lobby and PVP.lobby.refresh_mm_status then
				PVP.lobby.refresh_mm_status()
			end
		end,
	}
end

-- The host writes the drafted deck and stake over the queued ones in the lobby
-- metadata. The metadata mirror (pvp_api/lobby_bridge.lua) copies it back into
-- PVP.LOBBY on every metadata change, so a stale queued stake there would undo the
-- Draft (and a Reseed would then start on it). The server keeps the drafted stake
-- in the started game itself for a server-run restart.
function PVP.publish_drafted_loadout(lobby, back, stake)
	local patch = {}
	if back then
		patch.deck = back
	end
	if stake then
		patch.stake = tostring(stake)
	end
	if next(patch) then
		lobby:set_metadata(patch)
	end
end

-- Every client's start of a game (params = { seed, stake }): run off the
-- pvp_start_game broadcast (host-refereed lobbies) or off GAME_STARTED
-- (server-refereed lobbies, see pvp_api/lobby_bridge.lua) -- the same body.
-- A rejoin into a game still in Setup calls it again (pvp_api/reconnect.lua).
function PVP.on_game_start(params)
	-- The match reveal hides every menu, and the votes and the Draft open in the lobby's.
	if PVP.QUEUE_REVEAL then
		PVP.QUEUE_REVEAL.dismiss()
	end
	if PVP.stop_ready_resync then
		PVP.stop_ready_resync()
	end
	if PVP.reset_ready_state then
		PVP.reset_ready_state()
	end

	local lobby = MPAPI.get_current_lobby()
	local meta = (lobby and lobby:get_metadata()) or {}
	if meta.cocktail_recipe and not PVP.receive_cocktail_recipe(meta.cocktail_recipe) then return end
	local gm_def = meta.queue_mode and MPAPI.GameModes[meta.queue_mode]

	-- picked is a { key, stake } item (deck+stake Draft), a plain deck key/name, or nil.
	local function proceed(picked)
		local deck_ref, stake
		if type(picked) == "table" then
			deck_ref, stake = picked.key, picked.stake
		else
			deck_ref = picked
		end
		if deck_ref then
			-- Draft survivors are center KEYS (e.g. 'b_red'); PVP's run start wants a deck
			-- NAME. Resolve either form to a name, and pin it as the lobby deck so PVP's
			-- copy_host_deck (config.back -> deck.back) doesn't clobber the drafted deck.
			local center = G.P_CENTERS[deck_ref]
			local name = (center and center.name) or deck_ref
			PVP.LOBBY.config.back = name
			PVP.LOBBY.deck.back = name
		end
		if stake then
			PVP.LOBBY.config.stake = stake
			PVP.LOBBY.deck.stake = stake
		end
		if lobby and lobby.is_host then
			PVP.publish_drafted_loadout(lobby, deck_ref and PVP.LOBBY.config.back, stake)
		end
		PVP.referee_reset(PVP.LOBBY.config.starting_lives)
		PVP.dispatch_action("startGame", { seed = params.seed, stake = stake or params.stake })
	end

	-- Setup (pvp_api/setup.lua) runs on the server, so only a server-refereed
	-- lobby has one: the Casual votes, then the matchmaking Draft. Two Draft
	-- shapes exist (gamemodes.lua): BAN_PICK's explicit schedule addresses
	-- exactly two actor slots, so it only drafts at exactly 2 players.
	-- ROTATING_BAN_PICK (Royale/Manhunt/Teams) rotates through however many
	-- players are in the game, so it runs at any N >= 2.
	local plan = { votes = false, draft = false }
	if lobby and MPAPI.has_server_referee(lobby) then
		local started = lobby._game and lobby._game.started
		plan = PVP.SETUP.plan(
			meta.queue_mode,
			PVP._pvp_kind == PVP.LobbyAccess.CASUAL,
			PVP.is_matchmaking and PVP.is_matchmaking(),
			#((started and started.players) or lobby:get_players()),
			gm_def and gm_def.ban_pick
		)
	end
	if not (plan.votes or plan.draft) then
		proceed(meta.deck)
		return
	end
	PVP.SETUP.begin(lobby, plan, function(on_picked)
		-- The Draft's pool follows the ruleset the votes rolled (applied by the
		-- metadata mirror), else the queued one.
		MPAPI.BanPick.start(lobby, PVP._ban_pick_config_for(gm_def, PVP.LOBBY.config.ruleset), function(survivors)
			on_picked(survivors[1])
		end)
	end, function(picked)
		proceed(picked or (lobby:get_metadata() or {}).deck)
	end)
end

A("pvp_start_game", function(_at, from, params)
	PVP.on_game_start(params)
end)

relay("pvp_stop_game", "stopGame")
