-- Cosmetic layers only: no real card transforms, order, RNG, or saved state.
local D = PVP.ALMANAC_DRAFT
local MAX_VISIBLE = 8
local V = { fan = 0, arrival = 1, page = 1, sprites = {} }
D.visuals = V

local function passive(object)
	for _, key in ipairs({ "collide", "hover", "drag" }) do
		if object.states[key] then object.states[key].can = false end
	end
	return object
end

function V.clear()
	for _, sprite in ipairs(V.sprites) do
		sprite:remove()
	end
	if V.badge then V.badge:remove() end
	V.sprites, V.badge, V.state, V.deck, V.signature = {}, nil, nil, nil, nil
	V.fan, V.arrival, V.page = 0, 1, 1
end

function V.update(dt)
	local state = G.GAME and G.GAME.chaos_draft
	if G.STAGE ~= G.STAGES.RUN or not state or not G.deck then
		if V.state then V.clear() end
		return
	end
	if V.state ~= state or V.deck ~= G.deck then
		V.clear()
		V.state, V.deck = state, G.deck
	end
	local signature = table.concat(state.acquired, ",")
	if V.signature ~= signature then
		local previous_count, initialized = V.count, V.signature ~= nil
		for _, sprite in ipairs(V.sprites) do
			sprite:remove()
		end
		if V.badge then
			V.badge:remove()
			V.badge = nil
		end
		V.sprites, V.count, V.signature = {}, #state.acquired, signature
		for i = math.max(1, #state.acquired - MAX_VISIBLE + 1), #state.acquired do
			local center = G.P_CENTERS[state.acquired[i]]
			if center then
				V.sprites[#V.sprites + 1] =
					passive(Sprite(0, 0, G.CARD_W, G.CARD_H, G.ASSET_ATLAS[center.atlas or "centers"], center.pos))
			end
		end
		V.arrival = initialized and V.count > (previous_count or 0) and 0 or 1
		if V.count > MAX_VISIBLE then
			V.badge = passive(UIBox({
				definition = {
					n = G.UIT.ROOT,
					config = { align = "cm", padding = 0.06, r = 0.1, colour = G.C.BLACK },
					nodes = {
						{
							n = G.UIT.T,
							config = {
								text = "+"
									.. (V.count - MAX_VISIBLE)
									.. (V.count == MAX_VISIBLE + 1 and " deck" or " decks"),
								scale = 0.25,
								colour = G.C.WHITE,
							},
						},
					},
				},
				config = { align = "tm", offset = { x = 0, y = -0.15 }, major = G.deck, parent = G.deck },
			}))
		end
	end
	local top = G.deck.cards[1]
	local hovered = top
		and (top.states.hover.is or G.deck.states.hover.is or (G.CONTROLLER and G.CONTROLLER.focused.target == top))
	if G.OVERLAY_MENU then hovered = false end
	if G.SETTINGS.reduced_motion then
		V.fan, V.arrival = 0, 1
	else
		V.fan = V.fan + ((hovered and 1 or 0) - V.fan) * (1 - math.exp(-12 * dt))
		V.arrival = math.min(1, V.arrival + dt / 0.45)
	end
end

function V.offset(index, count, width, height)
	local depth = count - index
	local gaps = math.max(1, count - 1)
	-- Keep small stacks' spacing, but bound the full fan for larger collections.
	local x = -depth * width * math.min(0.08 + 0.16 * V.fan, (0.5 + 0.5 * V.fan) / gaps)
	local y = -depth * height * math.min(0.035 + 0.025 * V.fan, 0.25 / gaps)
	local rotation = -depth * math.min(0.045 + 0.065 * V.fan, 0.3 / gaps)
	if depth == 0 and V.arrival < 1 then
		local t = V.arrival
		y = y - height * 0.3 * (1 - t) ^ 2 + height * 0.035 * math.sin(t * math.pi * 2) * (1 - t)
		rotation = rotation + 0.1 * (1 - t)
	end
	return x, y, rotation
end

SMODS.DrawStep({
	key = "almanac_acquired_backs",
	order = 1, -- after the vanilla back, before stake stickers
	conditions = { vortex = false, facing = "back" },
	func = function(card)
		if G.VIEWING_DECK or G.STAGE ~= G.STAGES.RUN or not G.deck then return end
		-- CardArea draws deck cards from #cards down to 1; index 1 is topmost.
		if card.area ~= G.deck or card ~= G.deck.cards[1] then return end
		if V.state ~= G.GAME.chaos_draft or V.deck ~= G.deck then return end
		for i, sprite in ipairs(V.sprites) do
			sprite.role.draw_major = card
			local x, y, rotation = V.offset(i, #V.sprites, card.T.w, card.T.h)
			sprite:draw_shader("dissolve", 0.05, nil, true, card.children.back, nil, rotation, x, y)
			sprite:draw_shader("dissolve", nil, nil, true, card.children.back, nil, rotation, x, y)
		end
		if V.badge then V.badge:draw() end
	end,
})

local update = Game.update
function Game:update(dt)
	update(self, dt)
	V.update(dt)
end

local remove = CardArea.remove
function CardArea:remove(...)
	if self == V.deck then V.clear() end
	return remove(self, ...)
end

local function text_row(text, scale)
	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.04 },
		nodes = {
			{ n = G.UIT.T, config = { text = text, scale = scale or 0.28, colour = G.C.WHITE } },
		},
	}
end

function V.collection()
	local acquired = G.GAME.chaos_draft.acquired
	local pages = math.max(1, math.ceil(#acquired / 6))
	V.page = math.max(1, math.min(V.page, pages))
	local rows = { text_row("YOUR ALMANAC DECK - " .. #acquired .. " acquired", 0.4) }
	if #acquired == 0 then rows[#rows + 1] = text_row("Your first choice arrives in Ante 2.") end
	for start = (V.page - 1) * 6 + 1, math.min(V.page * 6, #acquired), 3 do
		local columns = {}
		for i = start, math.min(start + 2, #acquired) do
			local key = acquired[i]
			local center, definition = G.P_CENTERS[key], D.definitions[key]
			local nodes = { text_row(localize({ type = "name_text", set = "Back", key = key }), 0.32) }
			if center then
				nodes[#nodes + 1] = {
					n = G.UIT.R,
					config = { align = "cm" },
					nodes = {
						{
							n = G.UIT.O,
							config = {
								object = Sprite(
									0,
									0,
									G.CARD_W * 0.4,
									G.CARD_H * 0.4,
									G.ASSET_ATLAS[center.atlas or "centers"],
									center.pos
								),
							},
						},
					},
				}
			end
			for _, line in ipairs(definition and definition.lines or { "Deck definition unavailable." }) do
				nodes[#nodes + 1] = text_row(line, 0.23)
			end
			columns[#columns + 1] = {
				n = G.UIT.C,
				config = { align = "tm", padding = 0.12, minw = 3.6, minh = 2.7, colour = G.C.BLACK, r = 0.1 },
				nodes = nodes,
			}
		end
		rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm", padding = 0.08 }, nodes = columns }
	end
	if pages > 1 then
		rows[#rows + 1] = {
			n = G.UIT.R,
			config = { align = "cm", padding = 0.08 },
			nodes = {
				UIBox_button({ button = "pvp_almanac_previous_page", label = { "<" }, minw = 1 }),
				{
					n = G.UIT.C,
					config = { align = "cm", padding = 0.15 },
					nodes = { text_row(V.page .. " / " .. pages) },
				},
				UIBox_button({ button = "pvp_almanac_next_page", label = { ">" }, minw = 1 }),
			},
		}
	end
	return { n = G.UIT.ROOT, config = { align = "cm", padding = 0.1, colour = G.C.CLEAR }, nodes = rows }
end

-- Extend the native viewer without replacing its Full/Remaining tabs or click.
local tabs = create_tabs
function create_tabs(args)
	if G.GAME and G.GAME.chaos_draft and args and args.tabs then
		local deck_tabs, already_added = false, false
		for _, tab in ipairs(args.tabs) do
			if tab.tab_definition_function == G.UIDEF.view_deck then deck_tabs = true end
			if tab.tab_definition_function == V.collection then already_added = true end
		end
		if deck_tabs and not already_added then
			local copied = {}
			for k, value in pairs(args) do
				copied[k] = value
			end
			copied.tabs = {}
			for _, tab in ipairs(args.tabs) do
				local entry = {}
				for k, value in pairs(tab) do
					entry[k] = value
				end
				if V.choose_collection then entry.chosen = false end
				copied.tabs[#copied.tabs + 1] = entry
			end
			copied.tabs[#copied.tabs + 1] = {
				label = localize("k_almanac_decks"),
				chosen = V.choose_collection or false,
				tab_definition_function = V.collection,
			}
			return tabs(copied)
		end
	end
	return tabs(args)
end

local function turn_page(delta)
	V.page = V.page + delta
	V.choose_collection = true
	G.FUNCS.deck_info()
	V.choose_collection = nil
end
G.FUNCS.pvp_almanac_previous_page = function()
	turn_page(-1)
end
G.FUNCS.pvp_almanac_next_page = function()
	turn_page(1)
end
