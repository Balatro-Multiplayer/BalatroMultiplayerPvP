-- Contains function overrides (monkey-patches) for round-related functionality
-- Overrides functions like ease_ante, ease_round, reset_blinds, EventManager:add_event

local ease_ante_ref = ease_ante
function ease_ante(mod)
	if PVP.is_mp_or_practice() and not PVP.LOBBY.config.disable_live_and_timer_hud then
		-- Prevents easing multiple times at once
		if PVP.GAME.antes_keyed[PVP.GAME.ante_key] then return end

		-- pizza: remove discards
		if PVP.GAME.pizza_discards > 0 then
			G.GAME.round_resets.discards = G.GAME.round_resets.discards - PVP.GAME.pizza_discards
			ease_discard(-PVP.GAME.pizza_discards)
			PVP.GAME.pizza_discards = 0
		end

		PVP.GAME.antes_keyed[PVP.GAME.ante_key] = true
		PVP.ACTIONS.set_ante(G.GAME.round_resets.ante + mod)
		G.E_MANAGER:add_event(Event({
			trigger = "immediate",
			func = function()
				G.GAME.round_resets.ante = G.GAME.round_resets.ante + mod
				check_and_set_high_score("furthest_ante", G.GAME.round_resets.ante)
				-- Practice ends after ante 8: real matches suppress vanilla's native
				-- win_ante=8 trigger (see game_state.lua's update_new_round) to continue
				-- past it via the lives system; practice has no lives system, so this is
				-- the intended stop. Checked here (ease_ante, which fires unconditionally
				-- on every ante advance) rather than update_new_round, since that hook
				-- turned out not to reliably run with G.STATE_COMPLETE already true on
				-- the shop-exit-to-next-ante transition -- confirmed live.
				if PVP.is_practice_mode() and G.GAME.round_resets.ante > 8 then
					win_game()
				end
				return true
			end,
		}))

		-- technically doesn't have to be in this block, but less logspam is nicer
		PVP.UTILS.log_mem_debug_messages()
	end
	return ease_ante_ref(mod)
end

local ease_round_ref = ease_round
function ease_round(mod)
	if PVP.is_mp_or_practice() and not PVP.LOBBY.config.disable_live_and_timer_hud and PVP.LOBBY.config.timer then
        G.GAME.round = G.GAME.round + mod
        return
    end
	ease_round_ref(mod)
end

local reset_blinds_ref = reset_blinds
function reset_blinds()
	reset_blinds_ref()
	G.GAME.round_resets.pvp_blind_choices = {}

	local gamemode_key = PVP.get_active_gamemode()
	if gamemode_key and PVP.Gamemodes[gamemode_key] then
		local mp_small_choice, mp_big_choice, mp_boss_choice =
			PVP.Gamemodes[gamemode_key]:get_blinds_by_ante(G.GAME.round_resets.ante)
		G.GAME.round_resets.blind_choices.Small = mp_small_choice or G.GAME.round_resets.blind_choices.Small
		G.GAME.round_resets.blind_choices.Big = mp_big_choice or G.GAME.round_resets.blind_choices.Big
		G.GAME.round_resets.blind_choices.Boss = mp_boss_choice or G.GAME.round_resets.blind_choices.Boss
	end
end

-- A Boss Tag (or any other reroll) must never swap the PvP blind for a normal boss: the
-- opponent would still wait in the PvP blind while this player plays a vanilla one.
local reroll_boss_ref = G.FUNCS.reroll_boss
function G.FUNCS.reroll_boss(e)
	if G.GAME.round_resets.blind_choices.Boss == "bl_mp_nemesis" then
		G.from_boss_tag = nil
		return true
	end
	return reroll_boss_ref(e)
end

-- necessary for showdown mode to ensure rounds progress properly, only affects nemesis blind to avoid possible incompatibilities (though i know many mods like to do this exact hook)
local blind_get_type = Blind.get_type
function Blind:get_type()
	if self.name == "bl_mp_nemesis" then
		return G.GAME.blind_on_deck
	else
		return blind_get_type(self)
	end
end

-- added event suppression for a lovely patch for ease_ante
local add_event_ref = EventManager.add_event
function EventManager:add_event(event, queue, front)
	if PVP.suppress_next_event then
		PVP.suppress_next_event = false
		return
	end
	return add_event_ref(self, event, queue, front)
end
