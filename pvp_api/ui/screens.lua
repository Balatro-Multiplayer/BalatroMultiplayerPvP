-- The one Game.update hook of the match screens. Each screen exports `update`; they run here in
-- this order each frame, after the rest of Game.update. Blind start runs before the PvP blind: a blind entered this
-- frame is read by blind the same frame. One screen failing does not stop the others, and a repeated
-- error is logged once. A new run clears what the screens have shown before any of them runs.
local screens = {}
PVP.UI.screens = screens

screens.order = {
	"away",
	"blind_start",
	"finish",
	"pending_death",
	"pvp_blind",
	"reconnect",
	"run",
	"target",
	"timer",
	"trap",
}

local logged = {}

-- Runs every screen's update in order. `modules` is the table the screens hang on (PVP.UI); `log` takes a text.
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
	PVP.READ.view.follow_run(PVP.NET.view)
	screens.tick(screens.order, PVP.UI, function(text) sendWarnMessage(text, "MULTIPLAYER") end)
end

return screens
