-- §22.3: "Spectate" browser -- lists MPAPI.replay.list_spectatable, launches
-- a live, uninteractable follow of the picked match via PVP.SPECTATE.start
-- (pvp_api/spectate_feed.lua), which bootstraps its own seeded local run
-- (PVP.REPLAY.start) from the match's own buffered manifest before
-- attaching the live feed.
--
-- v1 scope: no pagination, matching replay_browser.lua's own scope decision.

local function format_lobby_label(lobby)
	return tostring(lobby.code or '??????') .. '  (' .. tostring(lobby.playerCount or '?') .. ' players)'
end

G.FUNCS.mp_pvp_open_spectate_browser = function()
	MPAPI.replay.list_spectatable(function(err, data)
		if err then
			MPAPI.sendWarnMessage('[spectate] list_spectatable failed: ' .. tostring(err.message))
			return
		end

		local lobbies = (data and data.lobbies) or {}
		local rows = {
			{ n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
				{ n = G.UIT.T, config = { text = 'Spectate', scale = 0.6, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
			} },
		}

		if #lobbies == 0 then
			rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cm', minh = 2 }, nodes = {
				{ n = G.UIT.T, config = { text = 'No spectatable matches right now.', scale = 0.4, colour = G.C.UI.TEXT_LIGHT } },
			} }
		else
			for _, lobby in ipairs(lobbies) do
				rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
					UIBox_button({
						button = 'mp_pvp_spectate_pick_' .. lobby.code,
						label = { format_lobby_label(lobby) },
						colour = G.C.PURPLE,
						minw = 5,
						minh = 0.6,
						scale = 0.35,
					}),
				} }
				G.FUNCS['mp_pvp_spectate_pick_' .. lobby.code] = function()
					G.FUNCS.exit_overlay_menu()
					PVP.SPECTATE.start(lobby.code, function(spectate_err)
						if spectate_err then
							MPAPI.sendWarnMessage('[spectate] failed to start: ' .. tostring(spectate_err))
						end
					end)
				end
			end
		end

		G.FUNCS.overlay_menu({ definition = create_UIBox_generic_options({ contents = rows }) })
	end)
end
