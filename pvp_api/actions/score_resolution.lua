local A = PVP._pvp_action_helpers.A
local self_id = PVP._pvp_action_helpers.self_id

-- Score / state resolution. The opponent-facing DISPLAY of
-- score/hands/skips/lives is synced separately via the nemesis blind's
-- calculate/receive (see objects/blinds/nemesis.lua); the referee is the server.

-- §17.11: NOT a plain relay, unlike every sibling in this file -- relay() only
-- guards against the sender's own loopback, so in any N>2 mode EVERY lobby
-- member's location changes would apply here, and enemyLocation's single
-- PVP.GAME.enemy.location* fields would be stomped by whichever broadcast
-- physically lands last (a last-write-wins race, decoupled from who the
-- receiving client's actual current target is). Filtering to
-- PVP.current_target_id() -- the same shared "who is the enemy right now"
-- resolution the score display/HUD/joker targeting already use -- means a
-- stray non-target player's location update is simply ignored.
A("pvp_location", function(_at, from, params)
	if from == self_id() then return end
	if from ~= PVP.current_target_id() then return end
	PVP.dispatch_action("enemyLocation", params or {})
end)
