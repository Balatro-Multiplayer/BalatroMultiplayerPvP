-- The queue HUD simulator (Alt+P) loads only with qhud_sim=true in .env. Loads after hud.lua and
-- cards.lua, which it reads at load time; releases leave tests/ out, so it never ships.
if PVP.ENV.qhud_sim == true then PVP.load_mp_file("tests/scenarios/lib/qhud_sim.lua") end
