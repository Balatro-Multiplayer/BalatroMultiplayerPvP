-- The PvP blind's on-HUD name. Read through __index so the DynaText re-reads it every
-- frame: the opponent slot is re-mirrored (a new table) whenever the roster or target
-- changes. Before a target latches (the Manhunt Runner, Royale before pairing) that slot
-- has no username, so fall back to the same gamemode name the blind-choice screen shows
-- rather than rendering a literal "nil".
local hud_opponent_name = setmetatable({}, {
    __index = function()
        if PVP.is_announced_bye() then
            return PVP.pvp_blind_opponent_name()
        end
        local opponent = PVP.LOBBY.is_host and PVP.LOBBY.guest or PVP.LOBBY.host
        return (opponent and opponent.username) or PVP.pvp_blind_opponent_name()
    end,
})

-- The enemy-score label's text, read each frame through PVP.GAME.enemy.score_label.
-- Royale tells the player what their shown target's score means: "Beat:" while they
-- are in the losing half, "Leading:" while safe. Every other mode (and Royale before
-- the host's first target broadcast) keeps the plain "Current Enemy score" label.
function PVP.UI.refresh_enemy_score_label()
	local safe = PVP.GAME.royale_target_safe
	local key = "k_enemy_score"
	if safe ~= nil and PVP.current_target_id() then
		key = safe and "k_royale_leading" or "k_royale_beat"
	end
	PVP.GAME.enemy.score_label = localize(key)
end

function PVP.UI.update_blind_HUD(blind, reset, silent)
    if PVP.is_mp_or_practice() then
        -- Setup blind name display
        local name_element = G.HUD_blind:get_UIE_by_ID("HUD_blind_name")
        name_element.config.object.config.string =  {
            {
                ref_table = hud_opponent_name,
                ref_value = "username",
            },
        }
        name_element.config.object.config.old_maxw = name_element.config.object.config.maxw
        name_element.config.object.config.mp_maxw = true
        name_element.config.object.config.maxw = 4.5
        name_element.config.object.scale = name_element.config.object.config.scale
        name_element.config.object:update_text(true)
        if name_element.config.object.config.maxw then
            name_element.config.object.scale = name_element.config.object.scale * math.min(1, name_element.config.object.config.maxw/name_element.config.object.config.W)
        end
        name_element.config.object:update_text(true)
        name_element.states.visible = false
        -- A bye has no opponent: keep the normal boss text ("Score at least",
        -- "Reward") with a 0 score requirement. The PvP round still ends only
        -- after every hand is played (Game:update_hand_played), not at 0 chips.
        local bye = PVP.is_announced_bye()
        if bye then
            G.GAME.blind.chips = 0
            G.GAME.blind.chip_text = "0"
        end
        if not bye then
            -- Setup enemy score text
            G.HUD_blind:get_UIE_by_ID("HUD_blind_count").config.ref_table = PVP.GAME.enemy
            G.HUD_blind:get_UIE_by_ID("HUD_blind_count").config.ref_value = "score_text"
            G.HUD_blind:get_UIE_by_ID("HUD_blind_count").config.func = "multiplayer_blind_chip_UI_scale"
            -- Setup labels
            -- Casual balala UI experience right here
            local labels = G.HUD_blind:get_UIE_by_ID("HUD_blind").children[2].children[2].children[2]
            PVP.UI.refresh_enemy_score_label()
            labels.children[1].children[1].config.text = PVP.GAME.enemy.score_label
            labels.children[1].children[1].config.ref_table = PVP.GAME.enemy
            labels.children[1].children[1].config.ref_value = "score_label"
            labels.children[3].children[1].config.text = localize("k_enemy_hands")
            -- Setup enemy hands
            G.HUD_blind:get_UIE_by_ID("dollars_to_be_earned").parent.parent.states.visible = false
            G.HUD_blind:get_UIE_by_ID("dollars_to_be_earned").config.object.config.string =
                { { ref_table = PVP.GAME.enemy, ref_value = "hands_text" } }
            G.HUD_blind:get_UIE_by_ID("dollars_to_be_earned").config.object:update_text()
        end

        G.HUD_blind.alignment.offset.y = 0
        G.E_MANAGER:add_event(Event({
            trigger = 'after',
            delay = 0.15,
            blockable = false,
            func = (function()
                local self = G.GAME.blind

                if self.config.blind.key == "bl_mp_nemesis" then
                    -- Setup blind atlas and pos
                    self.children.animatedSprite.atlas = G.ANIMATION_ATLAS["mp_player_blind_col"]
                    local nemesis_blind_col = PVP.UTILS.get_nemesis_key()
                    self.children.animatedSprite:set_sprite_pos(G.P_BLINDS[nemesis_blind_col].pos)
                end

                G.HUD_blind:get_UIE_by_ID("HUD_blind_name").states.visible = true
                G.HUD_blind:get_UIE_by_ID("dollars_to_be_earned").parent.parent.states.visible = true
                G.HUD_blind:get_UIE_by_ID("dollars_to_be_earned").config.object:pop_in(0)
                G.HUD_blind:get_UIE_by_ID("HUD_blind_name").config.object:pop_in(0)
                G.HUD_blind:get_UIE_by_ID("HUD_blind_count"):juice_up()
                self.dissolve = 0
                self.blind_set = true
                G.ROOM.jiggle = G.ROOM.jiggle + 3
                if not reset and not silent then
                    self:juice_up()
                    if blind then play_sound('chips1', math.random()*0.1 + 0.55, 0.42);play_sound('gold_seal', math.random()*0.1 + 1.85, 0.26)--play_sound('cancel')
                    end
                end
                return true
            end)
        }))
    end
end

function PVP.UI.reset_blind_HUD()
	if PVP.is_mp_or_practice() then
        local name_element = G.HUD_blind:get_UIE_by_ID("HUD_blind_name")
		name_element.config.object.config.string =
			{ { ref_table = G.GAME.blind, ref_value = "loc_name" } }
        if  name_element.config.object.config.mp_maxw then            
            name_element.config.object.config.maxw = name_element.config.object.config.old_maxw
            name_element.config.object.config.old_maxw = nil
            name_element.config.object.scale = name_element.config.object.config.scale
            name_element.config.object:update_text(true)
            if name_element.config.object.config.maxw then
                name_element.config.object.scale = name_element.config.object.scale * math.min(1, name_element.config.object.config.maxw/name_element.config.object.config.W)
            end
            name_element.config.object:update_text(true)
        end
		G.HUD_blind:get_UIE_by_ID("HUD_blind_count").config.ref_table = G.GAME.blind
		G.HUD_blind:get_UIE_by_ID("HUD_blind_count").config.ref_value = "chip_text"
		local score_label =
			G.HUD_blind:get_UIE_by_ID("HUD_blind").children[2].children[2].children[2].children[1].children[1]
		score_label.config.ref_table = nil
		score_label.config.ref_value = nil
		score_label.config.text = localize("ph_blind_score_at_least")
		G.HUD_blind:get_UIE_by_ID("HUD_blind").children[2].children[2].children[2].children[3].children[1].config.text =
			localize("ph_blind_reward")
		G.HUD_blind:get_UIE_by_ID("dollars_to_be_earned").config.object.config.string =
			{ { ref_table = G.GAME.current_round, ref_value = "dollars_to_be_earned" } }
		G.HUD_blind:get_UIE_by_ID("dollars_to_be_earned").config.object:update_text()
	end
end

-- Contains function overrides (monkey-patches) for blind-related functionality
-- Overrides functions like get_blind_main_colour, Blind:change_colour, Blind:set_blind, etc.

local get_blind_main_colourref = get_blind_main_colour
function get_blind_main_colour(type) -- handles ui colour stuff
	local nemesis = G.GAME.round_resets.blind_choices[type] == "bl_mp_nemesis" or type == "bl_mp_nemesis"
	if nemesis then type = PVP.UTILS.get_nemesis_key() end
	return get_blind_main_colourref(type)
end

local blind_change_colourref = Blind.change_colour
function Blind:change_colour(blind_col) -- ensures that small/big blinds have proper colouration
	local small = false
	if self.config.blind.key == "bl_mp_nemesis" then
		local blind_key = PVP.UTILS.get_nemesis_key()
		if blind_key == "bl_small" or blind_key == "bl_big" then small = true end
	end
	local boss = self.boss
	if small then self.boss = false end
	blind_change_colourref(self, blind_col)
	self.boss = boss
end

local blind_set_blindref = Blind.set_blind
function Blind:set_blind(blind, reset, silent) -- hacking in proper spirals, far from good but whatever
	blind_set_blindref(self, blind, reset, silent)
	if (blind and blind.key == "bl_mp_nemesis") or (self and self.name and self.name == "bl_mp_nemesis") then -- this shouldn't break and this fix shouldn't work
		local boss = false
		local showdown = false
		local blind_key = PVP.UTILS.get_nemesis_key()
		if G.P_BLINDS[blind_key].boss then
			boss = true
			if G.P_BLINDS[blind_key].boss.showdown then
				showdown = true
			end
		end
		G.ARGS.spin.real = (G.SETTINGS.reduced_motion and 0 or 1) * (boss and (showdown and 0.5 or 0.25) or 0)
	end
end

local ease_background_colour_blindref = ease_background_colour_blind
function ease_background_colour_blind(state, blind_override) -- handles background
	local blindname = (
		(blind_override or (G.GAME.blind and G.GAME.blind.name ~= "" and G.GAME.blind.name)) or "Small Blind"
	)
	local blindname = (blindname == "" and "Small Blind" or blindname)
	if blindname == "bl_mp_nemesis" then
		blind_override = PVP.UTILS.get_nemesis_key()
		for k, v in pairs(G.P_BLINDS) do
			if blind_override == k then blind_override = v.name end
		end
	end
	return ease_background_colour_blindref(state, blind_override)
end

local add_round_eval_rowref = add_round_eval_row
function add_round_eval_row(config) -- if i could post a skull emoji i would, wtf is this (cashout screen)
	if config.name == "blind1" and G.GAME.blind.config.blind.key == "bl_mp_nemesis" then
		G.GAME.blind.chip_text = PVP.INSANE_INT.to_string(PVP.GAME.enemy.score)

		G.P_BLINDS["bl_mp_nemesis"].atlas = "mp_player_blind_col"
		G.GAME.blind.pos = G.P_BLINDS[PVP.UTILS.get_nemesis_key()].pos -- this one is getting reset so no need to bother
		add_round_eval_rowref(config)
		G.E_MANAGER:add_event(Event({
			trigger = "before",
			delay = 0.0,
			func = function()
				G.P_BLINDS["bl_mp_nemesis"].atlas = "mp_player_blind_chip" -- lmao
				return true
			end,
		}))
	else
		add_round_eval_rowref(config)
	end
end

local blind_defeat_ref = Blind.defeat
function Blind:defeat(silent)
	blind_defeat_ref(self, silent)
	if PVP.is_mp_or_practice() and PVP.UI.reset_blind_HUD then PVP.UI.reset_blind_HUD() end
end

local blind_disable_ref = Blind.disable
function Blind:disable()
	if PVP.is_pvp_boss() and not (G.GAME.blind and G.GAME.blind.name == "Verdant Leaf") then -- hackfix to make verdant work properly
		return
	end
	blind_disable_ref(self)
end

G.FUNCS.multiplayer_blind_chip_UI_scale = function(e)
	-- No real opponent in practice -- always mask both, never reveal (there is
	-- nothing to reveal). Checked first since practice is never a real PvP boss in
	-- the sense the checks below assume (hide_score_until_played/info_received are
	-- both meaningless without a live opponent).
	if PVP.is_practice_mode() then
		PVP.GAME.enemy.hands_text = "???"
		PVP.GAME.enemy.score_text = "???"
		return
	end

	-- Hands start at the opponent's starting count (set when the blind starts), so
	-- there is nothing to hide.
	PVP.GAME.enemy.hands_text = tostring(PVP.GAME.enemy.hands)

	-- Hide the opponent's score until we have played a hand this PvP blind, so
	-- a player can't watch the enemy score before committing their own hand.
	-- (The server also withholds the score, this is the matching display.)
	-- Gated by the hide_score_until_played lobby option (on by default only on
	-- standard-layer rulesets; host-toggleable in non-forcing lobbies).
	if
		PVP.LOBBY.config.hide_score_until_played
		and PVP.is_pvp_boss()
		and G.GAME.current_round
		and G.GAME.current_round.hands_played == 0
	then
		PVP.GAME.enemy.score_text = "???"
		return
	end
	local new_score_text = PVP.INSANE_INT.to_string(PVP.GAME.enemy.score)
	if G.GAME.blind and PVP.GAME.enemy.score and PVP.GAME.enemy.score_text ~= new_score_text then
		if not PVP.INSANE_INT.greater_than(PVP.GAME.enemy.score, PVP.INSANE_INT.create(0, G.E_SWITCH_POINT, 0)) then
			e.config.scale = scale_number(PVP.GAME.enemy.score.coeffiocient, 0.7, 100000)
		end
		PVP.GAME.enemy.score_text = new_score_text
	end
end

-- Eases PVP.GAME.enemy.score's InsaneInt components toward `new_score` over 3s.
-- Shared by objects/blinds/nemesis.lua's raw per-sender relay and
-- pvp_api/actions/team_manhunt.lua's pvp_team_score_board handler (Teams' HUD
-- shows a host-computed team SUM, not a single sender's raw score, so it can't
-- reuse the relay itself -- just this animation).
function PVP.UI.ease_enemy_score(new_score)
	G.E_MANAGER:add_event(Event({
		blockable = false,
		blocking = false,
		trigger = "ease",
		delay = 3,
		ref_table = PVP.GAME.enemy.score,
		ref_value = "e_count",
		ease_to = new_score.e_count,
		func = function(t)
			return math.floor(t)
		end,
	}))
	G.E_MANAGER:add_event(Event({
		blockable = false,
		blocking = false,
		trigger = "ease",
		delay = 3,
		ref_table = PVP.GAME.enemy.score,
		ref_value = "coeffiocient", -- misspelled in InsaneInt
		ease_to = new_score.coeffiocient,
		func = function(t)
			local mult = 1
			if new_score.exponent > 0 then mult = 100 end
			return math.floor(t * mult) / mult
		end,
	}))
	G.E_MANAGER:add_event(Event({
		blockable = false,
		blocking = false,
		trigger = "ease",
		delay = 3,
		ref_table = PVP.GAME.enemy.score,
		ref_value = "exponent",
		ease_to = new_score.exponent,
		func = function(t)
			return math.floor(t)
		end,
	}))
end

function PVP.UI.juice_up_pvp_hud()
	if PVP.is_pvp_boss() then
		G.HUD_blind:get_UIE_by_ID("HUD_blind_count"):juice_up()
		G.HUD_blind:get_UIE_by_ID("dollars_to_be_earned"):juice_up()
	end
end
