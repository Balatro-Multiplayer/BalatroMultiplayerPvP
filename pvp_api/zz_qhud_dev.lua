-- Git checkouts get Alt+P; packaged builds require an explicit .env opt-in.
local enabled = PVP.ENV.qhud_sim
if enabled == nil then enabled = NFS.getInfo(PVP.path .. "/.git") ~= nil end
if enabled then PVP.load_mp_file("tests/scenarios/lib/qhud_sim.lua") end
