-- Forecast is schedule and current status only. It never rolls future offers.
local D = PVP.ALMANAC_DRAFT

function D.forecast(state, ante)
	local lines = { localize("k_almanac_clear_skies") }
	for _, milestone in ipairs({ 2, 3, 5, 7 }) do
		local status = state.last_ante >= milestone and "k_almanac_complete"
			or (state.pending and state.pending.ante == milestone and "k_almanac_pending")
			or "k_almanac_upcoming"
		lines[#lines + 1] = localize("k_ante")
			.. " "
			.. milestone
			.. ": "
			.. localize("k_almanac_deck_draft")
			.. " — "
			.. localize(status)
	end
	lines[#lines + 1] = localize("k_almanac_rule_schedule")
	local rules = G.GAME and G.GAME.pvp_shared_rules
	if rules and rules.ante == ante and not rules.finished then
		for _, key in ipairs(rules.rules) do
			lines[#lines + 1] = PVP.SHARED_RULES.definitions[key].label
		end
	elseif PVP.SHARED_RULES.offer then
		lines[#lines + 1] =
			localize(PVP.SHARED_RULES.offer.locked and "k_almanac_rule_locked" or "k_almanac_rule_pending")
	end
	return lines
end

local function row(text)
	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.06 },
		nodes = { { n = G.UIT.T, config = { text = text, scale = 0.34, colour = G.C.UI.TEXT_LIGHT } } },
	}
end

G.FUNCS.pvp_almanac_forecast = function()
	local state = G.GAME and G.GAME.almanac_draft
	if not state then return end
	local rows = { row(localize("k_almanac_forecast")) }
	for _, line in ipairs(D.forecast(state, G.GAME.round_resets.ante)) do
		rows[#rows + 1] = row(line)
	end
	G.FUNCS.overlay_menu({ definition = create_UIBox_generic_options({ contents = rows }) })
end

function D.show_waiting(supported)
	D.waiting_state = G.GAME.almanac_draft
	G.FUNCS.overlay_menu({
		definition = create_UIBox_generic_options({
			contents = {
				row(localize("k_almanac")),
				row(localize(supported and "k_almanac_waiting" or "k_almanac_server_required")),
			},
		}),
	})
end
