-- §17.10: end-of-run roster -- every player's deck, highest PvP-blind score,
-- and a per-player joker drilldown, not just the local player's own or a
-- single toggleable nemesis. Reachable from the end screen via a "Roster"
-- button, additive to the existing single-nemesis toggle/deck-view (still
-- useful for a quick 1v1 glance; this is the real N-player answer for
-- Royale/Teams/Manhunt lobbies). Modeled directly on SPDRN's own roster
-- screen (ui/roster_screen.lua, §16.10).
PVP.UI = PVP.UI or {}

local _roster_el = nil

local function player_display_name(lobby, player_id)
	for _, p in ipairs(lobby:get_players()) do
		if p.id == player_id then
			return p.displayName or p.id
		end
	end
	return player_id
end

local function roster_row(lobby, player_id)
	local name = player_display_name(lobby, player_id)
	local result = PVP._collected_results and PVP._collected_results[player_id]
	local deck_label = (result and result.deck_back) or '--'
	local score_label = (result and result.highest_pvp_score and PVP.Score.display(result.highest_pvp_score)) or '--'
	local joker_count = result and result.jokers and #result.jokers or 0

	local nodes = {
		{ n = G.UIT.C, config = { align = 'cm', minw = 3, padding = 0.05 }, nodes = {
			{ n = G.UIT.T, config = { text = name, scale = 0.4, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
		} },
		{ n = G.UIT.C, config = { align = 'cm', minw = 2.2, padding = 0.05 }, nodes = {
			{ n = G.UIT.T, config = { text = deck_label, scale = 0.32, colour = G.C.UI.TEXT_INACTIVE } },
		} },
		{ n = G.UIT.C, config = { align = 'cm', minw = 2.5, padding = 0.05 }, nodes = {
			{ n = G.UIT.T, config = { text = 'Best PvP score: ' .. score_label, scale = 0.32, colour = G.C.UI.TEXT_INACTIVE } },
		} },
	}
	if joker_count > 0 then
		nodes[#nodes + 1] = { n = G.UIT.C, config = { align = 'cm', padding = 0.05 }, nodes = {
			UIBox_button({
				button = 'mp_pvp_view_roster_jokers',
				ref_table = { player_id = player_id },
				label = { 'Jokers (' .. joker_count .. ')' },
				colour = G.C.PURPLE,
				minw = 1.8,
				minh = 0.5,
				scale = 0.3,
			}),
		} }
	end

	return { n = G.UIT.R, config = { align = 'cm', padding = 0.06, colour = G.C.BLACK, emboss = 0.03, r = 0.08 }, nodes = nodes }
end

local function build_roster_contents()
	local lobby = MPAPI.get_current_lobby()
	local rows = {
		{ n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
			{ n = G.UIT.T, config = { text = 'Roster', scale = 0.5, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
		} },
	}
	if lobby then
		for _, p in ipairs(lobby:get_players()) do
			rows[#rows + 1] = roster_row(lobby, p.id)
		end
	end
	return rows
end

function PVP.UI.show_roster_overlay()
	_roster_el = _roster_el or MPAPI.ui_element(build_roster_contents)
	G.FUNCS.overlay_menu({
		definition = create_UIBox_generic_options({ contents = { _roster_el.node } }),
	})
end

-- Called by pvp_api/actions/player_result.lua whenever a new result arrives,
-- so an already-open roster reflects it without needing to be reopened.
function PVP.UI.refresh_roster()
	if _roster_el then
		_roster_el:update()
	end
end

G.FUNCS.mp_pvp_open_roster = function()
	PVP.UI.show_roster_overlay()
end

-- Read-only display of one player's captured joker snapshot. Builds ordinary
-- display Cards, the same technique MPAPI.BanPick's own deck tiles use --
-- these are never clickable/playable.
local function build_joker_area(jokers)
	local area = CardArea(0, 0, math.max(#jokers, 1) * 1.1, 1.6 * G.CARD_H / G.CARD_W, { card_limit = math.max(#jokers, 1), type = 'joker' })
	for _, j in ipairs(jokers or {}) do
		local center = G.P_CENTERS[j.key]
		if center then
			local card = Card(area.T.x, area.T.y, G.CARD_W, G.CARD_H, nil, center, { bypass_discovery_center = true })
			if j.edition then
				card:set_edition(j.edition, true, true)
			end
			card.ability.eternal = j.eternal or false
			card.ability.perishable = j.perishable or false
			area:emplace(card)
		end
	end
	return area
end

G.FUNCS.mp_pvp_view_roster_jokers = function(e)
	local player_id = e.config.ref_table.player_id
	local result = PVP._collected_results and PVP._collected_results[player_id]
	local jokers = (result and result.jokers) or {}

	local area = build_joker_area(jokers)
	G.FUNCS.overlay_menu({
		definition = create_UIBox_generic_options({ contents = {
			{ n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
				{ n = G.UIT.T, config = { text = 'Jokers', scale = 0.5, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
			} },
			{ n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
				{ n = G.UIT.O, config = { object = area } },
			} },
		} }),
	})
end
