-- The legacy mutator wall's live cells, adapted to a private draft and MPAPI
-- layers. No connection, Steam registration, or multiplayer menu is required.
PVP.CUSTOM = {}
local C = PVP.CUSTOM
local BASES = { "vanilla", "expanded", "balanced", "sandbox", "experimental" }
local CATEGORIES = PVP.MUTATOR_CATEGORIES
local CONTENT = { false, "multiplayer_jokers", "no_multiplayer_jokers" }
local IDOLS = { false, "idol_zealot", "idol_collector", "idol_both", "idol_none" }

function C.new_draft()
	return { base = 1, deck = 1, stake = 1, content = 1, idol = 1, seed = "", selected = {} }
end

function C.inherited(key)
	local definition = PVP.MUTATORS[key]
	key = definition and definition.implied_by or key
	local base = BASES[C.draft.base]
	if base == key then return true end
	for _, name in ipairs(PVP.Rulesets["ruleset_mp_" .. base]._layer_order or {}) do
		if name == key then return true end
	end
	return false
end

function C.config()
	local draft = C.draft
	local modifiers = {}
	for _, category in ipairs(CATEGORIES) do
		for _, definition in ipairs(PVP.mutators_in(category)) do
			if draft.selected[definition.key] and not C.inherited(definition.key) then
				modifiers[#modifiers + 1] = definition.key
			end
		end
	end
	if CONTENT[draft.content] then modifiers[#modifiers + 1] = CONTENT[draft.content] end
	if IDOLS[draft.idol] then modifiers[#modifiers + 1] = IDOLS[draft.idol] end
	return {
		ruleset = "ruleset_mp_" .. BASES[draft.base],
		deck = C.decks[draft.deck],
		stake = draft.stake,
		seed = draft.seed:upper(),
		modifiers = modifiers,
	}
end

G.FUNCS.pvp_solo_toggle = function(e)
	local key = e.config.ref_table.key
	if not C.inherited(key) then C.draft.selected[key] = not C.draft.selected[key] end
	e:juice_up(0.2, 0.1)
end

G.FUNCS.pvp_solo_cell = function(e)
	local key = e.config.ref_table.key
	local inherited = C.inherited(key)
	e.config.colour = inherited and G.C.GREY or C.draft.selected[key] and G.C.PURPLE or G.C.BLACK
end

G.FUNCS.pvp_solo_cycle = function(args)
	C.draft[args.cycle_config.ref_table.field] = args.to_key
end

G.FUNCS.pvp_solo_sync_cycle = function(e)
	local args = e.config.ref_table
	args.current_option = C.draft[args.ref_table.field]
	args.current_option_val = args.options[args.current_option]
end

G.FUNCS.pvp_solo_reset = function()
	C.draft.selected = {}
	C.draft.content, C.draft.idol = 1, 1
end

G.FUNCS.pvp_solo_play = function()
	local ok, err = PVP.SOLO.start(C.config())
	if not ok then PVP.UI.UTILS.overlay_message(localize("k_solo_invalid_" .. err)) end
end

local function cycle(field, label, options)
	local args = {
		label = label,
		options = options,
		current_option = C.draft[field],
		opt_callback = "pvp_solo_cycle",
		ref_table = { field = field },
		scale = 0.65,
		w = 3.8,
	}
	return {
		n = G.UIT.C,
		config = { align = "cm", func = "pvp_solo_sync_cycle", ref_table = args },
		nodes = { create_option_cycle(args) },
	}
end

local function text_row(text, scale)
	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.06 },
		nodes = { { n = G.UIT.T, config = { text = text, scale = scale or 0.3, colour = G.C.UI.TEXT_LIGHT } } },
	}
end

function C.build()
	local base_labels, deck_labels, stake_labels = {}, {}, {}
	for _, base in ipairs(BASES) do
		base_labels[#base_labels + 1] = localize("k_solo_base_" .. base)
	end
	C.decks = {}
	for _, center in ipairs(G.P_CENTER_POOLS.Back) do
		if center.key:match("^b_") and not center.mod then
			C.decks[#C.decks + 1] = center.key
			deck_labels[#deck_labels + 1] = localize({ type = "name_text", set = "Back", key = center.key })
		end
	end
	for _, stake in ipairs(G.P_CENTER_POOLS.Stake) do
		stake_labels[#stake_labels + 1] = localize({ type = "name_text", set = "Stake", key = stake.key })
	end
	local columns = {}
	for _, category in ipairs(CATEGORIES) do
		local cells = { text_row(localize("k_solo_category_" .. category), 0.32) }
		for _, definition in ipairs(PVP.mutators_in(category)) do
			local label = localize("k_mutator_" .. definition.key)
			cells[#cells + 1] = {
				n = G.UIT.R,
				config = { align = "cm", padding = 0.03 },
				nodes = {
					{
						n = G.UIT.C,
						config = {
							id = "pvp_solo_" .. definition.key,
							align = "cm",
							minw = 2.3,
							minh = 0.48,
							padding = 0.06,
							r = 0.1,
							colour = G.C.BLACK,
							hover = true,
							shadow = true,
							button = "pvp_solo_toggle",
							func = "pvp_solo_cell",
							ref_table = definition,
							tooltip = { title = label, text = localize("ml_mutator_" .. definition.key) },
						},
						nodes = { { n = G.UIT.T, config = { text = label, scale = 0.28, colour = G.C.WHITE } } },
					},
				},
			}
		end
		columns[#columns + 1] = { n = G.UIT.C, config = { align = "tm", padding = 0.04 }, nodes = cells }
	end
	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.1 },
		nodes = {
			text_row(localize("k_solo_title"), 0.5),
			text_row(localize("k_solo_description")),
			{
				n = G.UIT.R,
				config = { align = "cm" },
				nodes = {
					cycle("base", localize("k_solo_base"), base_labels),
					cycle("deck", localize("k_solo_deck"), deck_labels),
					cycle("stake", localize("k_solo_stake"), stake_labels),
				},
			},
			{
				n = G.UIT.R,
				config = { align = "cm" },
				nodes = {
					cycle("content", localize("k_mutator_multiplayer_jokers"), localize("ml_solo_content")),
					cycle("idol", localize("k_solo_idol"), localize("ml_solo_idol")),
					create_text_input({
						id = "pvp_solo_seed",
						ref_table = C.draft,
						ref_value = "seed",
						prompt_text = localize("k_solo_seed"),
						max_length = 8,
						all_caps = true,
						w = 3,
					}),
				},
			},
			{ n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = columns },
			text_row(localize("k_solo_manual_warning"), 0.27),
			text_row(localize("k_solo_colours"), 0.27),
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.1 },
				nodes = {
					UIBox_button({
						button = "pvp_solo_reset",
						label = { localize("k_solo_reset") },
						colour = G.C.GREY,
						minw = 3,
					}),
					UIBox_button({
						id = "pvp_solo_play",
						button = "pvp_solo_play",
						label = { localize("k_solo_play") },
						colour = G.C.GREEN,
						minw = 4,
					}),
				},
			},
		},
	}
end

G.FUNCS.pvp_custom_solo = function()
	if MPAPI.get_current_lobby() or G.STAGE == G.STAGES.RUN then
		PVP.UI.UTILS.overlay_message(localize("k_solo_invalid_lobby"))
		return
	end
	C.draft = C.new_draft()
	G.FUNCS.overlay_menu({
		definition = create_UIBox_generic_options({
			back_func = "exit_overlay_menu",
			contents = { C.build() },
		}),
	})
end

local main_menu_buttons_ref = create_UIBox_main_menu_buttons
function create_UIBox_main_menu_buttons()
	local definition = main_menu_buttons_ref()
	local column = definition.nodes and definition.nodes[1]
	if column and column.nodes then
		column.nodes[#column.nodes + 1] = {
			n = G.UIT.R,
			config = { align = "cm", padding = 0.08 },
			nodes = {
				UIBox_button({
					id = "pvp_custom_solo",
					button = "pvp_custom_solo",
					label = { localize("k_solo_title") },
					minw = 4,
					minh = 0.6,
					colour = G.C.PURPLE,
					scale = 0.4,
				}),
			},
		}
	end
	return definition
end
