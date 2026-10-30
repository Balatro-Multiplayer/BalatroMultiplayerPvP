-- World Series of Balatro Ruleset

-- Not the Expanded pool (no PVP-original content, far fewer reworks), so it
-- composes its own dedicated "wsob" layer (layers/wsob.lua) instead of
-- "balanced"/"expanded" -- §9.2 purity migration moved its bans/reworks off the ruleset
-- itself and into that layer verbatim.
PVP.Ruleset({
	key = "wsob",
	layers = { "ranked", "wsob" }, -- let's gate on version though
	multiplayer_content = false,
}):inject()
