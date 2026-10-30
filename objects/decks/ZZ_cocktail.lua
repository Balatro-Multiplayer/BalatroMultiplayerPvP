SMODS.Back({
	key = "cocktail",
	config = {},
	atlas = "mp_decks",
	pos = { x = 4, y = 0 },
	mod_whitelist = {
		[PVP.id] = true,
		Cryptid = true,
		aikoyorisshenanigans = true,
		allinjest = true,
	},
	deck_blacklist = {
		b_challenge = true,
		b_mp_cocktail = true,
		b_cry_antimatter = true,
		b_akyrs_hardcore_challenges = true,
	},
	apply = function(self)
		-- we need to fucking generate the seed early this is infuriating
		local seed = G._MP_SET_SEED
		local seeded = false
		if seed then seeded = true end
		G.GAME.pseudorandom.seed = seed or generate_starting_seed()
		G.GAME.modifiers.mp_cocktail = {}
		G.GAME.modifiers.mp_cocktail_sticker = {}
		local decks, forced = PVP.get_cocktail_decks(true)
		pseudoshuffle(decks, pseudoseed("mp_cocktail"))
		local back = G.GAME.selected_back

		local function add_deck(num, deck, sticker)
			G.GAME.modifiers.mp_cocktail[num] = deck
			if sticker then G.GAME.modifiers.mp_cocktail_sticker[num] = deck end
			if deck == "b_checkered" then -- hardcoded because cringe
				G.E_MANAGER:add_event(Event({
					func = function()
						for k, v in pairs(G.playing_cards) do
							if v.base.suit == "Clubs" then v:change_suit("Spades") end
							if v.base.suit == "Diamonds" then v:change_suit("Hearts") end
						end
						return true
					end,
				}))
			end
		end

		for i = 1, #forced do
			add_deck(i, forced[i], true)
		end
		for i = 1, math.min(3 - #forced, #decks) do
			add_deck(#forced + i, decks[i], PVP.cocktail_cfg_readpos("show", true) ~= "H" and true or false)
		end
		local function merge(t1, t2, safe)
			local t3 = {}
			for k, v in pairs(t1) do
				if type(v) == "table" then
					t3[k] = merge(v, {})
				else
					t3[k] = v
				end
			end
			for k, v in pairs(t2) do
				local existing = t3[k]

				if type(existing) == "number" and type(v) == "number" then
					t3[k] = existing + v
				elseif type(existing) == "table" and type(v) == "table" then
					t3[k] = merge(existing, v, true) -- risky but it works...
				else
					if type(v) == "table" then
						t3[k] = merge(v, {})
					else
						local index = safe and #t3 + 1 or k
						t3[index] = v
					end
				end
			end
			return t3
		end
		for i = 1, #G.GAME.modifiers.mp_cocktail do
			back.effect.config = merge(back.effect.config, G.P_CENTERS[G.GAME.modifiers.mp_cocktail[i]].config)
			if back.effect.config.voucher then
				back.effect.config.vouchers = back.effect.config.vouchers or {}
				back.effect.config.vouchers[#back.effect.config.vouchers + 1] = back.effect.config.voucher
				back.effect.config.voucher = nil
			end
			local obj = G.P_CENTERS[G.GAME.modifiers.mp_cocktail[i]]
			if obj.apply and type(obj.apply) == "function" then obj:apply(back) end

			-- aikoshen exception because this code runs before apply_to_run orig (why?)
			if back.effect.config.akyrs_starting_letters then
				G.GAME.starting_params.akyrs_starting_letters = back.effect.config.akyrs_starting_letters
			end
			if back.effect.config.akyrs_letters_no_uppercase then
				G.GAME.starting_params.akyrs_letters_no_uppercase = back.effect.config.akyrs_letters_no_uppercase
			end

			-- all in jest exception for patchwork deck
			if G.GAME.modifiers.mp_cocktail[i] == "b_aij_patchwork" then
				G.GAME.modifiers.b_aij_patchwork = true
			end
		end
		if PVP.is_layer_active("smallworld") then PVP.apply_fake_back_vouchers(back) end
		back.effect.mp_cocktailed = true
		if PVP.cocktail_check_edited() then G.GAME.seeded = true end
	end,
	calculate = function(self, back, context)
		for i = 1, #G.GAME.modifiers.mp_cocktail do
			back:change_to(G.P_CENTERS[G.GAME.modifiers.mp_cocktail[i]])
			local ret1, ret2 = back:trigger_effect(context)
			back:change_to(G.P_CENTERS["b_mp_cocktail"])
			if ret1 or ret2 then return ret1, ret2 end
		end
	end,
	mp_credits = { art = { "aura!", "shai1n" }, code = { "Toneblock" } },
})

-- honestly this could have been a list
-- whatever
local sticker_x_pos = {
	b_red = 0,
	b_blue = 1,
	b_yellow = 2,
	b_green = 3,
	b_black = 4,
	b_magic = 5,
	b_nebula = 6,
	b_ghost = 7,
	b_abandoned = 8,
	b_checkered = 9,
	b_zodiac = 10,
	b_painted = 11,
	b_anaglyph = 12,
	b_plasma = 13,
	b_erratic = 14,
	b_mp_orange = 15,
	b_mp_indigo = 16,
	b_mp_violet = 17,
	b_mp_white = 18,
	b_mp_oracle = 19,
	b_mp_gradient = 20,
	b_mp_heidelberg = 21,
	b_mp_echodeck = 22,
}

function PVP.get_cocktail_decks(cull)
	local ret = {}
	local forced = {}
	for k, v in pairs(G.P_CENTERS) do
		if v.set == "Back" and not G.P_CENTERS["b_mp_cocktail"].deck_blacklist[k] then
			if not (v.mod and not G.P_CENTERS["b_mp_cocktail"].mod_whitelist[v.mod.id]) then ret[#ret + 1] = k end
		end
	end
	table.sort(ret, function(a, b)
		return G.P_CENTERS[a].order < G.P_CENTERS[b].order
	end)
	if cull then
		local _ret = {}
		for i, v in ipairs(ret) do
			if PVP.cocktail_cfg_readpos(i, true) == "1" then
				_ret[#_ret + 1] = ret[i]
			elseif PVP.cocktail_cfg_readpos(i, true) == "2" then
				forced[#forced + 1] = ret[i]
			end
		end
		ret = _ret
	end
	return ret, forced
end

local change_to_ref = Back.change_to
function Back:change_to(new_back)
	if self.effect.mp_cocktailed then
		local t = copy_table(self.effect.config)
		local ret = change_to_ref(self, new_back)
		self.effect.config = copy_table(t)
		self.effect.mp_cocktailed = true
		return ret
	end
	return change_to_ref(self, new_back)
end

local function is_cocktail_select(card)
	if Galdur then
		return Galdur.run_setup
			and card.area == Galdur.run_setup.selected_deck_area
			and card.config.center.key == "b_mp_cocktail"
	else
		return G.GAME.viewed_back
			and G.GAME.viewed_back.effect
			and G.GAME.viewed_back.effect.center.key == "b_mp_cocktail"
			and card.facing == "back"
	end
end

local click_ref = Card.click
function Card:click() -- i'd rather deal with the cardarea but this is fine i suppose
	click_ref(self)
	if G.STAGE == G.STAGES.MAIN_MENU then
		if is_cocktail_select(self) then
			-- boilerplate robbed from cryptid's decaying corpse
			if G.cocktail_select then
				for i = 1, #G.cocktail_select do
					G.cocktail_select[i]:remove()
					G.cocktail_select[i] = nil
				end
			end
			G.cocktail_select = {}
			for i = 1, 2 do
				G.cocktail_select[i] = CardArea(
					G.ROOM.T.x + 0.2 * G.ROOM.T.w / 1.5,
					G.ROOM.T.h,
					5.3 * G.CARD_W,
					1.03 * G.CARD_H,
					{ card_limit = 5, type = "title", highlight_limit = 999, collection = true }
				)
			end
			local decks = PVP.get_cocktail_decks()
			local cfg = PVP.config
			for i, v in ipairs(decks) do
				local row = math.floor((((i - 1) / #decks) * 2) + 1)
				G.GAME.viewed_back = MPAPI.back_for_key(v)
				local card = Card(
					G.ROOM.T.x + 0.2 * G.ROOM.T.w / 2,
					G.ROOM.T.h,
					G.CARD_W,
					G.CARD_H,
					pseudorandom_element(G.P_CARDS),
					G.P_CENTERS.c_base,
					{ playing_card = i, bypass_back = G.P_CENTERS[v].pos }
				)
				G.cocktail_select[row]:emplace(card)
				card.sprite_facing = "back"
				card.facing = "back"
				card.mp_cocktail_select = v
				local num = PVP.cocktail_cfg_readpos(i)
				card.highlighted = tonumber(num) >= 1 and true or false
				card.mp_cocktail_forced = num == "2" and true or false
			end
			G.GAME.viewed_back = MPAPI.back_for_key("b_mp_cocktail")
			PVP.show_cocktail_decks = PVP.cocktail_cfg_readpos("show") ~= "H" and true or false
			deck_tables = {}
			for i = 1, #G.cocktail_select do
				deck_tables[i] = {
					n = G.UIT.R,
					config = { align = "cm", padding = 0, no_fill = true },
					nodes = {
						{ n = G.UIT.O, config = { object = G.cocktail_select[i] } },
					},
				}
			end
			local t = create_UIBox_generic_options({
				back_func = "setup_run",
				snap_back = true,
				contents = {
					{
						n = G.UIT.R,
						config = {
							padding = 0.0,
							align = "cl",
						},
						nodes = {
							create_toggle({
								id = "show_cocktail_decks",
								label = "Show active decks during run",
								ref_table = PVP,
								ref_value = "show_cocktail_decks",
								callback = function(bool)
									PVP.cocktail_cfg_edit(bool, "show")
								end,
							}),
						},
					},
					{ n = G.UIT.R, config = { align = "cl", padding = 0.4, minh = 0.4 } }, -- empty space row because i'm bad at ui
					{
						n = G.UIT.R,
						config = { align = "cm", minw = 2.5, padding = 0.1, r = 0.1, colour = G.C.BLACK, emboss = 0.05 },
						nodes = deck_tables,
					},
					{
						n = G.UIT.R,
						config = { align = "cl", padding = 0 },
						nodes = {
							{
								n = G.UIT.T,
								config = { text = localize("k_cocktail_select"), scale = 0.48, colour = G.C.WHITE },
							},
						},
					},
					{
						n = G.UIT.R,
						config = { align = "cl", padding = 0 },
						nodes = {
							{
								n = G.UIT.T,
								config = { text = localize("k_cocktail_shiftclick"), scale = 0.32, colour = G.C.WHITE },
							},
						},
					},
					{
						n = G.UIT.R,
						config = { align = "cl", padding = 0 },
						nodes = {
							{
								n = G.UIT.T,
								config = { text = localize("k_cocktail_rightclick"), scale = 0.32, colour = G.C.WHITE },
							},
						},
					},
				},
			})
			G.FUNCS.overlay_menu({
				definition = t,
			})
		end
	end
end

local draw_ref = Card.draw
function Card:draw(layer)
	draw_ref(self, layer)
	if G.STAGE == G.STAGES.MAIN_MENU then
		if not self.children.view_deck then
			self.children.view_deck = UIBox({
				definition = {
					n = G.UIT.ROOT,
					config = { align = "cm", padding = 0.1, r = 0.1, colour = G.C.CLEAR },
					nodes = {
						{
							n = G.UIT.R,
							config = {
								align = "cm",
								padding = 0.05,
								r = 0.1,
								colour = adjust_alpha(G.C.BLACK, 0.5),
								func = "set_button_pip",
								focus_args = { button = "triggerright", orientation = "bm", scale = 0.6 },
								button = "deck_info",
							},
							nodes = {
								{
									n = G.UIT.R,
									config = { align = "cm", maxw = 2 },
									nodes = {
										{
											n = G.UIT.T,
											config = {
												text = localize("k_edit"),
												scale = 0.48,
												colour = G.C.WHITE,
												shadow = true,
											},
										},
									},
								},
								{
									n = G.UIT.R,
									config = { align = "cm", maxw = 2 },
									nodes = {
										{
											n = G.UIT.T,
											config = {
												text = localize("k_deck"),
												scale = 0.38,
												colour = G.C.WHITE,
												shadow = true,
											},
										},
									},
								},
							},
						},
					},
				},
				config = { align = "cm", offset = { x = 0, y = 0 }, major = self, parent = self },
			})
			self.children.view_deck.states.collide.can = false
		end
		local bool = self.states.hover.is and is_cocktail_select(self)
		self.children.view_deck.states.visible = bool
	end
end

SMODS.DrawStep({
	key = "mp_cocktail_forced",
	order = 5,
	func = function(self)
		if self.mp_cocktail_forced then self.children.back:draw_shader("foil", nil, self.ARGS.send_to_shader) end
	end,
	conditions = { vortex = false, facing = "back" },
})

local hover_ref = Card.hover
function Card:hover()
	hover_ref(self)
	if self.mp_cocktail_select then
		self.ability_UIBox_table = self:generate_UIBox_ability_table()
		self.config.h_popup = G.UIDEF.card_h_popup(self)
		self.config.h_popup_config = self:align_h_popup()
		Node.hover(self)
	end
end

local generate_card_ui_ref = generate_card_ui
function generate_card_ui(_c, full_UI_table, specific_vars, card_type, badges, hide_desc, main_start, main_end, card)
	if card and card.mp_cocktail_select then
		_c = G.P_CENTERS[card.mp_cocktail_select]
		local ret = generate_card_ui_ref(
			_c,
			full_UI_table,
			specific_vars,
			"Back",
			badges,
			hide_desc,
			main_start,
			main_end,
			card
		)
		if not _c.generate_ui or type(_c.generate_ui) ~= "function" then
			-- i literally can't get the vars from anywhere else so we're thunk coding

			local name_to_check = G.P_CENTERS[card.mp_cocktail_select].name

			if name_to_check == "Blue Deck" then
				specific_vars = { _c.config.hands }
			elseif name_to_check == "Red Deck" then
				specific_vars = { _c.config.discards }
			elseif name_to_check == "Yellow Deck" then
				specific_vars = { _c.config.dollars }
			elseif name_to_check == "Green Deck" then
				specific_vars = { _c.config.extra_hand_bonus, _c.config.extra_discard_bonus }
			elseif name_to_check == "Black Deck" then
				specific_vars = { _c.config.joker_slot, -_c.config.hands }
			elseif name_to_check == "Magic Deck" then
				specific_vars = {
					localize({ type = "name_text", key = "v_crystal_ball", set = "Voucher" }),
					localize({ type = "name_text", key = "c_fool", set = "Tarot" }),
				}
			elseif name_to_check == "Nebula Deck" then
				specific_vars = { localize({ type = "name_text", key = "v_telescope", set = "Voucher" }), -1 }
			elseif name_to_check == "Zodiac Deck" then
				specific_vars = {
					localize({ type = "name_text", key = "v_tarot_merchant", set = "Voucher" }),
					localize({ type = "name_text", key = "v_planet_merchant", set = "Voucher" }),
					localize({ type = "name_text", key = "v_overstock_norm", set = "Voucher" }),
				}
			elseif name_to_check == "Painted Deck" then
				specific_vars = { _c.config.hand_size, _c.config.joker_slot }
			elseif name_to_check == "Anaglyph Deck" then
				specific_vars = { localize({ type = "name_text", key = "tag_double", set = "Tag" }) }
			elseif name_to_check == "Plasma Deck" then
				specific_vars = { _c.config.ante_scaling }
			end

			localize({ type = "descriptions", key = _c.key, set = _c.set, nodes = ret.main, vars = specific_vars })
		end
		return ret
	end
	return generate_card_ui_ref(
		_c,
		full_UI_table,
		specific_vars,
		card_type,
		badges,
		hide_desc,
		main_start,
		main_end,
		card
	)
end

local can_highlight_ref = CardArea.can_highlight
function CardArea:can_highlight(card)
	if card.mp_cocktail_select then return true end
	return can_highlight_ref(self, card)
end

local highlight_ref = Card.highlight
function Card:highlight(is_highlighted)
	if self.mp_cocktail_select then
		local shift = G.CONTROLLER.held_keys["lshift"] or G.CONTROLLER.held_keys["rshift"]
		if shift and self.mp_cocktail_forced then
			is_highlighted = false
			self.mp_cocktail_forced = false
		elseif self.mp_cocktail_forced then
			is_highlighted = true
			self.mp_cocktail_forced = false
		elseif shift then
			is_highlighted = true
			if PVP.cocktail_get_forced_num() < 3 then
				self.mp_cocktail_forced = true
				play_sound("foil1", 1.5, 0.3)
			else
				play_sound("timpani", 0.9, 0.7)
				play_sound("timpani", 1.2, 0.7)
			end
		end
		PVP.cocktail_cfg_edit(self.mp_cocktail_forced and 2 or is_highlighted, self.mp_cocktail_select)
	end
	return highlight_ref(self, is_highlighted)
end

local r_cursor_press_ref = Controller.queue_R_cursor_press
function Controller:queue_R_cursor_press(x, y)
	local ret = r_cursor_press_ref(self, x, y)
	if G.cocktail_select and G.cocktail_select[1].cards then -- bruh
		local highlight = true
		for i = 1, #G.cocktail_select do
			for j = 1, #G.cocktail_select[i].cards do
				if G.cocktail_select[i].cards[j].highlighted then
					highlight = false
					break
				end
			end
			if not highlight then break end
		end
		for i = 1, #G.cocktail_select do
			for j = 1, #G.cocktail_select[i].cards do
				G.cocktail_select[i].cards[j].highlighted = highlight
				G.cocktail_select[i].cards[j].mp_cocktail_forced = false
			end
		end
		if highlight then
			play_sound("cardSlide1")
		else
			play_sound("cardSlide2", nil, 0.3)
		end
		PVP.cocktail_cfg_edit(highlight)
	end
	return ret
end

-- kill me
G.E_MANAGER:add_event(Event({
	func = function()
		local decks = PVP.get_cocktail_decks()
		local cfg = PVP.config
		if (not cfg.cocktail) or #decks + 1 ~= #cfg.cocktail then
			local string = ""
			for i = 1, #decks do
				string = string .. "1"
			end
			string = string .. "H"
			cfg.cocktail = string
		end
		SMODS.save_mod_config(PVP)
		return true
	end,
}))

function PVP.cocktail_cfg_edit(bool, deck) -- strings are easier to send, and it's just ones and zeroes
	local decks = PVP.get_cocktail_decks()
	local cfg = PVP.config
	local num = (bool == 2) and "2" or (bool and "1" or "0")
	if not deck then
		local string = ""
		for i = 1, #decks do
			string = string .. num
		end
		local show = PVP.cocktail_cfg_readpos("show")
		string = string .. show
		cfg.cocktail = string
	else
		local function replace(str, pos, d)
			return str:sub(1, pos - 1) .. d .. str:sub(pos + 1)
		end
		for i, v in ipairs(decks) do
			if v == deck then
				cfg.cocktail = replace(cfg.cocktail, i, num)
				break
			end
		end
		if deck == "show" then cfg.cocktail = replace(cfg.cocktail, #cfg.cocktail, bool and "S" or "H") end
	end
	PVP.LOBBY.config.cocktail = cfg.cocktail
	SMODS.save_mod_config(PVP)
end

function PVP.cocktail_cfg_readpos(pos, construct)
	local cfg = construct and PVP.cocktail_cfg_get() or PVP.config.cocktail
	if pos == "show" then pos = #cfg end
	return cfg:sub(pos, pos)
end

function PVP.cocktail_cfg_get()
	if PVP.LOBBY.code and PVP.LOBBY.deck and PVP.LOBBY.deck.cocktail then
		local cfg = PVP.LOBBY.deck.cocktail
		-- Matchmaking has no custom selection. Use the same default pool on
		-- every client, not each player's saved single-player preferences.
		if cfg == "" then return string.rep("1", #PVP.get_cocktail_decks()) .. "H" end
		return cfg
	else
		return PVP.config.cocktail
	end
end

function PVP.cocktail_check_edited()
	local str = PVP.cocktail_cfg_get()
	for i = 1, #str - 1 do
		if string.sub(str, i, i) ~= "1" then return true end
	end
	if string.sub(str, #str, #str) ~= "H" then return true end
	return false
end

function PVP.cocktail_get_forced_num()
	local str = PVP.config.cocktail
	local c = 0
	for i = 1, #str - 1 do
		if string.sub(str, i, i) == "2" then c = c + 1 end
	end
	return c
end

local localize_ref = localize
function localize(args, misc_cat)
	if args and type(args) == "table" and args.key then
		local ret = localize_ref(args, misc_cat)
		local key = args.key or args.node and args.node.config.center.key or "NULL"
		if args.type == "name_text" and key == "b_mp_cocktail" then
			if PVP.cocktail_check_edited() then return ret .. "*" end
		end
		return ret
	else
		return localize_ref(args, misc_cat)
	end
end

SMODS.Atlas({
	key = "cocktail_deck_stickers",
	path = "deck_stickers.png",
	px = 71,
	py = 95,
})

SMODS.DrawStep({
	key = "back_cocktail",
	order = 11,
	func = function(self)
		if G.STAGE == G.STAGES.RUN and G.GAME and G.GAME.modifiers and G.GAME.modifiers.mp_cocktail_sticker then
			if self.area and self.area.config.type == "deck" then
				for i, v in ipairs(G.GAME.modifiers.mp_cocktail_sticker) do
					local num = math.min(i, 3)
					local key = "mp_cocktail_" .. v .. num
					if not G.shared_stickers[key] then
						G.shared_stickers[key] = Sprite(
							0,
							0,
							G.CARD_W,
							G.CARD_H,
							G.ASSET_ATLAS["mp_cocktail_deck_stickers"],
							{ x = sticker_x_pos[v] or 0, y = num - 1 }
						)
					end
					G.shared_stickers[key].role.draw_major = self
					local sticker_offset = self.sticker_offset or {}
					G.shared_stickers[key]:draw_shader(
						"dissolve",
						nil,
						nil,
						true,
						self.children.center,
						nil,
						self.sticker_rotation,
						sticker_offset.x,
						sticker_offset.y
					)
				end
			end
		end
	end,
	conditions = { vortex = false, facing = "back" },
})
