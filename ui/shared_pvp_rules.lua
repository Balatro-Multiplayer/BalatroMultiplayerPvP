local R = PVP.SHARED_RULES
local function row(text, scale)
	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.06 },
		nodes = { { n = G.UIT.T, config = { text = text, scale = scale or 0.35, colour = G.C.UI.TEXT_LIGHT } } },
	}
end

function R.show_result(result)
	local rows = { row("THIS PVP: BOTH PLAYERS", 0.5) }
	for _, key in ipairs(result.rules) do
		local def = R.definitions[key]
		rows[#rows + 1] = row(def.label, 0.45)
		rows[#rows + 1] = row(def.text)
	end
	R.reveal_id = result.id
	G.FUNCS.overlay_menu({ definition = create_UIBox_generic_options({ no_back = true, contents = rows }) })
end

function R.show()
	local offer = R.offer
	if not offer then return end
	local remaining = math.max(0, math.ceil((offer.ms_left or 0) / 1000 - (love.timer.getTime() - offer.received_at)))
	local rows = {
		row("SHARED PVP RULES", 0.5),
		row(offer.locked and "Choice locked. Waiting for opponent." or ("Pick one: " .. remaining .. " seconds")),
		row("Both rules affect both players. Matching picks add a random second rule."),
	}
	for _, key in ipairs(offer.choices) do
		local def = R.definitions[key]
		rows[#rows + 1] = {
			n = G.UIT.R,
			config = { align = "cm", padding = 0.06 },
			nodes = {
				UIBox_button({
					id = "pvp_shared_" .. key,
					button = not offer.locked and remaining > 0 and "pvp_shared_pick" or "nil",
					ref_table = { key = key },
					label = { def.label, def.text },
					minw = 7,
					minh = 0.7,
					scale = 0.32,
					colour = offer.locked and G.C.UI.BACKGROUND_INACTIVE or G.C.PURPLE,
				}),
			},
		}
	end
	G.FUNCS.overlay_menu({
		definition = create_UIBox_generic_options({ no_back = true, contents = rows }),
	})
end

function G.FUNCS.pvp_shared_pick(e)
	local offer = R.offer
	if not offer or offer.locked then return end
	R.request("pvp_rules_pick", { id = offer.id, rule = e.config.ref_table.key })
end

local update = Game.update
function Game:update(dt)
	update(self, dt)
	if R.pending_start then
		local pending = R.pending_start
		if not R.enabled(MPAPI.get_current_lobby()) then
			R.pending_start = nil
		elseif R.can_start(pending.params.shared_rules) then
			R.pending_start = nil
			MPAPI.ActionTypes.pvp_start_blind.on_receive(nil, pending.from, pending.params)
		end
	end
	if not R.offer then return end
	if not R.enabled(MPAPI.get_current_lobby()) or G.STAGE ~= G.STAGES.RUN then
		R.offer = nil
		return
	end
	R.ui_elapsed = (R.ui_elapsed or 0) + dt
	if R.ui_elapsed >= 1 then
		R.ui_elapsed = 0
		R.show()
		if love.timer.getTime() - R.offer.received_at >= (R.offer.ms_left or 0) / 1000 + 1 then R.sync() end
	end
end
