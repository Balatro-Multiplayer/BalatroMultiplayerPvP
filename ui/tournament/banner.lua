-- The "your match is open" banner. When a tournament match opens (or a
-- ready-up deadline is close) and the player isn't on that tournament's
-- screen, a banner slides in at the top with a sound. It never takes the
-- player anywhere by itself (Lex's rule): GO opens the tournament screen,
-- and is only offered in the menus, so a running game is never interrupted.
-- It goes away on its own after SHOW_SECONDS.

PVP.TUI = PVP.TUI or {}
local TUI = PVP.TUI

local SHOW_SECONDS = 15
local banner = { box = nil, id = nil, serial = 0 }

local function remove()
	if banner.box then
		banner.box:remove()
		banner.box = nil
	end
	banner.id = nil
end

local function in_menus()
	return G.STAGE == G.STAGES.MAIN_MENU
end

-- content: the TOURNAMENT_MATCH notification ({tournamentId, name, kind,
-- minutesLeft, opponent}).
function PVP.show_tournament_banner(content)
	if not content or not content.tournamentId then
		return
	end
	if PVP.tournament_screen_id and PVP.tournament_screen_id() == content.tournamentId then
		return
	end
	remove()
	banner.id = content.tournamentId
	banner.serial = banner.serial + 1
	local serial = banner.serial
	local vs = content.opponent and content.opponent.name or "your opponent"
	local headline = content.kind == "reminder" and "Your match closes soon" or content.kind == "series" and "Next game: ready up" or "Your match is open"
	local detail = "Ready up vs " .. tostring(vs) .. (content.minutesLeft and ("  -  " .. content.minutesLeft .. " min left") or "")
	local buttons = {}
	if in_menus() then
		buttons[#buttons + 1] = TUI.button("GO", "mp_pvp_tournament_banner_go", { id = content.tournamentId }, G.C.GREEN, 1.2)
	end
	buttons[#buttons + 1] = TUI.button("X", "mp_pvp_tournament_banner_close", nil, G.C.UI.BACKGROUND_INACTIVE, 0.6)
	local body = TUI.panel({
		{
			n = G.UIT.R,
			config = { align = "cm" },
			nodes = {
				{
					n = G.UIT.C,
					config = { align = "cl", padding = 0.04 },
					nodes = {
						TUI.line({ TUI.text(tostring(content.name), 0.34, G.C.GOLD) }),
						TUI.line({ TUI.text(headline, 0.4) }),
						TUI.line({ TUI.text(detail, TUI.SMALL) }),
					},
				},
				TUI.spacer(0.2),
				TUI.hbox(buttons, "cm", 0.04),
			},
		},
	}, { align = "cm", padding = 0.1 })
	banner.box = UIBox({
		definition = { n = G.UIT.ROOT, config = { align = "cm", colour = G.C.CLEAR }, nodes = { body } },
		config = { align = "tm", offset = { x = 0, y = 0.3 }, major = G.ROOM_ATTACH, bond = "Weak", instance_type = "POPUP" },
	})
	play_sound("highlight2", 1.1, 0.6)
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = SHOW_SECONDS,
		blockable = false,
		blocking = false,
		timer = "REAL",
		func = function()
			if banner.serial == serial then
				remove()
			end
			return true
		end,
	}))
end

G.FUNCS.mp_pvp_tournament_banner_go = function(e)
	local id = e.config.ref_table and e.config.ref_table.id
	remove()
	if id and in_menus() then
		PVP.open_tournament(id)
	end
end

G.FUNCS.mp_pvp_tournament_banner_close = function()
	remove()
end
