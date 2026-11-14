-- Three notices share this screen, each decided by lib/contest.lua (Contest.end_screen); this
-- file is the thin shell. All have one button that leaves the way the end screen does
-- (ui/game/leave.lua):
--   PVP.show_dodge_notice        the opponent left during the Draft of a ranked game (GAME_ENDED,
--                                status dodged): the game is unrated.
--   PVP.show_dodge_away_notice   the same dodge, learned after the player was away; the text does
--                                not say who left.
--   PVP.show_ended_away_notice   any other end learned while away: it was settled without them.

-- The string keys of each notice, passed to G.UIDEF.dodge_notice.
local DODGE_TEXT = { "k_pvp_dodge_title", "k_pvp_dodge_text_1", "k_pvp_dodge_text_2" }
local DODGE_AWAY_TEXT = { "k_pvp_dodge_away_title", "k_pvp_dodge_away_text_1", "k_pvp_dodge_away_text_2" }
local ENDED_AWAY_TEXT = { "k_pvp_away_title", "k_pvp_away_text_1", "k_pvp_away_text_2" }

function G.UIDEF.dodge_notice(keys)
	local function text_row(key, scale)
		return PVP.UI.UTILS.create_row({ align = "cm", padding = 0.04 }, {
			PVP.UI.UTILS.create_text_node(localize(key), { scale = scale, colour = G.C.UI.TEXT_LIGHT }),
		})
	end
	return create_UIBox_generic_options({
		no_back = true,
		contents = {
			{
				n = G.UIT.C,
				config = { align = "cm", padding = 0.1 },
				nodes = {
					text_row(keys[1], 0.7),
					text_row(keys[2], 0.45),
					text_row(keys[3], 0.45),
					PVP.UI.UTILS.create_row({ align = "cm", padding = 0.06 }, {
						UIBox_button({
							button = "mp_pvp_leave_from_game",
							label = { localize("b_pvp_dodge_leave") },
							minw = 5,
							colour = G.C.RED,
						}),
					}),
				},
			},
		},
	})
end

-- Shows the notice, from any stage. Once per game is Contest.end_screen's decision; this
-- only records that it was shown. Deferred one event so the Draft's own teardown (MPAPI
-- closes its overlay on the same GAME_ENDED) cannot close it.
local function show_notice(keys)
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = 0,
		timer = "REAL",
		blockable = false,
		blocking = false,
		func = function()
			G.FUNCS.exit_overlay_menu()
			G.SETTINGS.paused = true
			-- Leave is the only way out: Escape would drop the player into a dead lobby.
			G.FUNCS.overlay_menu({ definition = G.UIDEF.dodge_notice(keys), config = { no_esc = true } })
			return true
		end,
	}))
end

function PVP.show_dodge_notice()
	PVP.GAME.dodge_notice_shown = true
	show_notice(DODGE_TEXT)
end

-- A dodge learned after being away: the same one-button notice. It cannot say who left, so the
-- text is true for both (Contest.EndScreen.DODGE_AWAY).
function PVP.show_dodge_away_notice()
	PVP.GAME.ended_away_notice_shown = true
	show_notice(DODGE_AWAY_TEXT)
end

-- Any other end learned after being away: the same notice with a neutral text
-- (Contest.EndScreen.ENDED_AWAY).
function PVP.show_ended_away_notice()
	PVP.GAME.ended_away_notice_shown = true
	show_notice(ENDED_AWAY_TEXT)
end
