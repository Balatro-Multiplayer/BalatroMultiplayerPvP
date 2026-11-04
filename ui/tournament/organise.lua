-- The ORGANISE page (pvp_tournament_organise): the sections the Tournament
-- Organiser mod registers with PVP.register_tournament_section (create,
-- manage). The tab only shows its button when there is a section, so players
-- without the mod never see this page.

PVP.TUI = PVP.TUI or {}
local TUI = PVP.TUI

MPAPI.on_loaded(function()
	MPAPI.Page({
		key = "pvp_tournament_organise",
		category = "game_select",
		build = function(self)
			local nodes = {
				TUI.hbox({ TUI.button("BACK", "mp_pvp_tournaments_back", nil, G.C.ORANGE, 1.6), TUI.text("ORGANISE", 0.45, G.C.PURPLE) }, "cm", 0.1),
			}
			for _, section in ipairs(PVP._tournament_sections or {}) do
				local ok, node = pcall(section.build)
				nodes[#nodes + 1] = ok and node or TUI.message("Organiser section failed: " .. tostring(node), G.C.RED)
			end
			if #(PVP._tournament_sections or {}) == 0 then
				nodes[#nodes + 1] = TUI.message("Hosting tournaments needs the Tournament Organiser mod.")
			end
			return {
				n = G.UIT.ROOT,
				config = { align = "tm", colour = G.C.CLEAR },
				nodes = { { n = G.UIT.R, config = { align = "tm", padding = 0.1 }, nodes = { TUI.panel(nodes, { minw = TUI.WIDTH }) } } },
			}
		end,
		on_enter = function(self)
			TUI.page_enter()
		end,
	})
end)
