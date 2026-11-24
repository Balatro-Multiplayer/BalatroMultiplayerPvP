-- The one Game.update hook of the match net's screens. Each screen exports `update`; they run here in
-- this order each frame, after the rest of Game.update. Entry runs before blind: a blind entered this
-- frame is read by blind the same frame. One screen failing does not stop the others, and a repeated
-- error is logged once. A new run clears what the screens have shown before any of them runs.
local screens = {}
PVP.match_net.screens = screens

screens.order = {
	"away_screen",
	"entry_screen",
	"finish_screen",
	"pending_death_screen",
	"pvp_blind_screen",
	"reconnect_screen",
	"run_screen",
	"target_screen",
	"timer_screen",
	"trap_screen",
}

local logged = {}

-- Runs every screen's update in order. `modules` is the table the screens hang on (PVP); `log` takes a text.
function screens.tick(order, modules, log)
	for _, name in ipairs(order) do
		local ok, err = pcall(modules[name].update)
		local text = "[" .. name .. "] " .. tostring(err)
		if not ok and not logged[text] then
			logged[text] = true
			log(text)
		end
	end
end

local game_update_ref = Game.update
function Game:update(dt)
	game_update_ref(self, dt)
	PVP.view.follow_run(PVP.match_net.view)
	screens.tick(screens.order, PVP, function(text) sendWarnMessage(text, "MULTIPLAYER") end)
end

return screens
