-- Group gates reuse Sandbox's mapping table; they never mutate a shop card's
-- center or the global pool after it has been indexed.
for group, key in pairs(PVP.SANDBOX.GROUP_LAYERS) do
	MPAPI.Layer(key, { banned_silent = PVP.SANDBOX.vanilla_bans_for(group) })
end

for _, variant in ipairs({ "zealot", "collector", "both", "none" }) do
	MPAPI.Layer("idol_" .. variant, { banned_silent = { "j_idol" } })
end

MPAPI.Layer("multiplayer_jokers", { multiplayer_content = true })
MPAPI.Layer("no_multiplayer_jokers", { multiplayer_content = false })
