local D = PVP.ALMANAC_DRAFT

local function name(key)
	return localize({ type = "name_text", set = "Back", key = key })
end

local function row(text, scale, colour)
	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.045 },
		nodes = { { n = G.UIT.T, config = { text = text, scale = scale or 0.3, colour = colour or G.C.WHITE } } },
	}
end

function D.preview(key)
	local config = G.P_CENTERS[key].config
	local parts = {}
	for _, item in ipairs({
		{ "Hands", config.hands, G.GAME.round_resets.hands },
		{ "Discards", config.discards, G.GAME.round_resets.discards },
		{ "Joker slots", config.joker_slot, G.jokers.config.card_limit },
		{ "Hand size", config.hand_size, G.hand.config.card_limit },
		{ "Tray slots", config.consumable_slot, G.consumeables.config.card_limit },
	}) do
		if item[2] then parts[#parts + 1] = item[1] .. ": " .. item[3] .. " -> " .. (item[3] + item[2]) end
	end
	if key == "b_abandoned" then
		local count = 0
		for _, card in ipairs(G.playing_cards) do
			if card.base.id >= 11 and card.base.id <= 13 then count = count + 1 end
		end
		parts[#parts + 1] = "Destroy " .. count .. " face cards, including enhanced copies."
	elseif key == "b_erratic" then
		parts[#parts + 1] = "Reroll ranks and suits of " .. #G.playing_cards .. " cards. Cannot undo."
	elseif key == "b_yellow" then
		parts[#parts + 1] = "$" .. G.GAME.dollars .. " + $" .. config.dollars .. " (money rules still apply)"
	end
	return #parts > 0 and table.concat(parts, "   |   ") or nil
end

function D.show()
	local state = G.GAME.chaos_draft
	if not state or not state.pending or state.busy then return end
	local pending = state.pending
	local title = row("YOUR ALMANAC DECK", 0.48)
	title.config.button, title.config.hover = "pvp_almanac_inspect", true
	title.config.tooltip = { title = "Your deck", text = { "Click to inspect your playing cards." } }
	local contents = { title }
	if #state.acquired == 0 then
		contents[#contents + 1] = row("No decks yet.")
	else
		-- Unlimited acquisitions; wrap the identity list instead of clipping it.
		for i = 1, #state.acquired, 4 do
			local names = {}
			for j = i, math.min(i + 3, #state.acquired) do
				names[#names + 1] = name(state.acquired[j])
			end
			contents[#contents + 1] = row(table.concat(names, " + "), 0.27)
		end
	end
	contents[#contents + 1] = row("ADD A DECK - ANTE " .. pending.ante, 0.4)
	local columns = {}
	for _, key in ipairs(pending.choices) do
		local center = G.P_CENTERS[key]
		local sprite =
			Sprite(0, 0, G.CARD_W * 0.65, G.CARD_H * 0.65, G.ASSET_ATLAS[center.atlas or "centers"], center.pos)
		local nodes = {
			{ n = G.UIT.R, config = { align = "cm" }, nodes = { { n = G.UIT.O, config = { object = sprite } } } },
			row(name(key), 0.34),
		}
		for _, line in ipairs(D.definitions[key].lines) do
			nodes[#nodes + 1] = row(line, 0.25)
		end
		columns[#columns + 1] = {
			n = G.UIT.C,
			config = {
				id = "almanac_offer_" .. key,
				align = "tm",
				padding = 0.15,
				minw = 3.7,
				minh = 3.4,
				r = 0.12,
				colour = pending.selected == key and G.C.PURPLE or G.C.BLACK,
				button = "pvp_almanac_select",
				ref_table = { key = key },
				hover = true,
				shadow = true,
			},
			nodes = nodes,
		}
	end
	contents[#contents + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.1 }, nodes = columns }
	if pending.selected then
		local preview = D.preview(pending.selected)
		if preview then contents[#contents + 1] = row(preview, 0.27) end
		local allowed, reason = D.can_acquire(pending.selected)
		if allowed then
			contents[#contents + 1] = row("Click again to add " .. name(pending.selected) .. ".", 0.27)
		else
			contents[#contents + 1] = row(reason, 0.28, G.C.RED)
		end
	else
		contents[#contents + 1] = row("Click to select. Click again to add.", 0.27)
	end
	local any_available = false
	for _, key in ipairs(pending.choices) do
		if D.can_acquire(key) then any_available = true end
	end
	if not any_available then
		contents[#contents + 1] = UIBox_button({
			button = "pvp_almanac_pass",
			label = { "No safe acquisition - continue" },
			minw = 5,
		})
	end
	G.FUNCS.overlay_menu({
		definition = create_UIBox_generic_options({
			no_back = true,
			no_esc = true,
			contents = { { n = G.UIT.C, config = { align = "cm", padding = 0.1 }, nodes = contents } },
		}),
	})
end

G.FUNCS.pvp_almanac_select = function(e)
	local state = G.GAME.chaos_draft
	if not state or not state.pending or state.busy then return end
	local key = e.config.ref_table.key
	local offered = false
	for _, choice in ipairs(state.pending.choices) do
		if choice == key then offered = true end
	end
	if not offered then return end
	if state.pending.selected == key then
		G.FUNCS.pvp_almanac_confirm()
		return
	end
	state.pending.selected = key
	play_sound("cardSlide1", 1, 0.6)
	D.show()
end

G.FUNCS.pvp_almanac_inspect = function()
	G.FUNCS.deck_info()
end

G.FUNCS.pvp_almanac_confirm = function()
	local state = G.GAME.chaos_draft
	local pending = state and state.pending
	if not pending or not pending.selected then return end
	local key = pending.selected
	if not D.can_acquire(key) then return end
	if PVP.rlog_active() then
		PVP.RLOG.record("chaos_pick", { state.seed, pending.ante, key, table.concat(pending.choices, ",") })
	end
	-- Close before callbacks: Orange opens a pack after the acquisition settles.
	G.FUNCS.exit_overlay_menu()
	if D.commit(state, key, D.apply) then play_sound("tarot1", 1.1, 0.6) end
end

G.FUNCS.pvp_almanac_pass = function()
	local state = G.GAME.chaos_draft
	if not state or not state.pending then return end
	for _, key in ipairs(state.pending.choices) do
		if D.can_acquire(key) then return end
	end
	if PVP.rlog_active() then
		PVP.RLOG.record("chaos_pick", {
			state.seed,
			state.pending.ante,
			"pass",
			table.concat(state.pending.choices, ","),
		})
	end
	state.last_ante = state.pending.ante
	state.pending = nil
	G.FUNCS.exit_overlay_menu()
	save_run()
end
