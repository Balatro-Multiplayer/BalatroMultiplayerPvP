-- Speed control shown while a Replay plays: 1x, 2x, 4x and fast-forward.
PVP.replay_hud = PVP.replay_hud or {}
local hud = PVP.replay_hud

local Speed = MPAPI.playback.Speed

local SPEED_OPTIONS = {
	{ speed = Speed.X1, label = '1x' },
	{ speed = Speed.X2, label = '2x' },
	{ speed = Speed.X4, label = '4x' },
	{ speed = Speed.FAST_FORWARD, label = '>>' },
}

local function speed_button(option, selected)
	return {
		n = G.UIT.C,
		config = {
			align = 'cm',
			padding = 0.08,
			minw = 0.9,
			minh = 0.5,
			r = 0.1,
			hover = true,
			shadow = true,
			colour = selected and G.C.BLUE or G.C.GREY,
			button = 'mp_replay_set_speed',
			ref_table = { speed = option.speed },
		},
		nodes = {
			{ n = G.UIT.T, config = { text = option.label, scale = 0.4, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
		},
	}
end

local function definition(current_speed)
	local buttons = {}
	for _, option in ipairs(SPEED_OPTIONS) do
		buttons[#buttons + 1] = speed_button(option, option.speed == current_speed)
	end
	return {
		n = G.UIT.ROOT,
		config = { align = 'cm', padding = 0.05, colour = G.C.CLEAR },
		nodes = { { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = buttons } },
	}
end

function hud.hide()
	if hud.box then
		hud.box:remove()
		hud.box = nil
	end
	hud.driver = nil
end

function hud.show(driver)
	hud.hide()
	hud.driver = driver
	hud.box = UIBox({
		definition = definition(driver:get_speed()),
		config = { align = 'bli', offset = { x = 0.3, y = -0.3 }, major = G.ROOM_ATTACH, bond = 'Weak' },
	})
end

function hud.set_speed(speed)
	local driver = hud.driver
	if not driver then
		return
	end
	driver:set_speed(speed)
	hud.show(driver)
end

G.FUNCS.mp_replay_set_speed = function(e)
	hud.set_speed(e.config.ref_table.speed)
end

-- A stopped or finished driver (left to the menu, or the Replay ended) takes the HUD with it.
local game_update_ref = Game.update
function Game:update(dt)
	game_update_ref(self, dt)
	local driver = hud.driver
	if driver and (driver._stopped or driver._completed) then
		hud.hide()
	end
end
