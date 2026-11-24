-- Opens the waiting screen while the view's run.waitingDeaths lists me, closes it when it no longer does,
-- and tells me when another player's pending death waits on me (pending_death_reader.lua decides). Never opens during a playback.
local screen = {}
PVP.pending_death_screen = screen

function screen.update()
	local view = PVP.match_net and PVP.match_net.view
	local run = PVP.view.run(view)
	if not run then return end
	if not (G.STAGE == G.STAGES.RUN and PVP.in_session()) or PVP.is_practice_mode() then return end
	local reader = PVP.pending_death_reader
	local mine = reader.waiting(view)
	local open = PVP.GAME.pending_death_screen
	if mine and not open then
		if PVP.GAME.end_shown ~= "not yet" or MPAPI.playback.is_driving("pvp") then return end
		PVP.GAME.pending_death = mine
		PVP.UI.show_pending_death_screen()
	elseif mine then
		PVP.GAME.pending_death = mine
	elseif open then
		PVP.end_pending_death()
	end
	-- Told once per run (a new run clears the marks): a death that leaves the list and comes back is not told twice.
	for _, mark in ipairs(reader.waiting_on_me(view)) do
		if PVP.view.once("death told " .. mark) then PVP.UI.show_pending_death_notice(reader.survivor_key(view)) end
	end
end


return screen
