-- Presentation fixture, not a probability test. Optional screenshots use the
-- same explicit destination convention as chaos_backs.
local areas, cards, old_reduced = {}, {}
local preview = os.getenv("BMP_VISUAL_PREVIEW") == "1"
local directory = os.getenv("BMP_SCREENSHOT_DIR")
assert(preview or directory, "Set BMP_SCREENSHOT_DIR to an existing directory")
local function capture(name)
	love.graphics.captureScreenshot(function(image)
		local file = assert(io.open(directory .. "/" .. name .. ".png", "wb"))
		file:write(image:encode("png"):getString())
		file:close()
	end)
end
local steps = {
	{
		run = function(S)
			S.check(
				PVP.SOLO.start({
					ruleset = "ruleset_mp_vanilla",
					deck = "b_red",
					stake = 1,
					seed = "RADIANT",
					modifiers = {},
				}),
				"Visual fixture starts"
			)
		end,
	},
	{
		until_ = function()
			return G.blind_select and PVP.CHAOS.safe_point()
		end,
		timeout = 20,
		run = function()
			assert(PVP.CHAOS.for_run(true):activate("higher_calling"))
			old_reduced = G.SETTINGS.reduced_motion
			local columns = {}
			for i, label in ipairs({ "Judgement", "Higher Calling", "Polychrome", "Calling + Negative" }) do
				local area = CardArea(0, 0, G.CARD_W * 1.35, G.CARD_H * 1.35, {
					type = "title_2",
					card_limit = 1,
					highlight_limit = 0,
				})
				local card = SMODS.create_card({ key = "c_judgement", area = area })
				card.T.w, card.T.h = G.CARD_W * 1.25, G.CARD_H * 1.25
				-- Comparison-only identities keep the same art, not the active shader.
				if i == 1 or i == 3 then
					card.config.center = copy_table(card.config.center)
					card.config.center.key = "fixture_plain_judgement"
				end
				if i == 3 then card:set_edition({ polychrome = true }, true, true) end
				if i == 4 then card:set_edition({ negative = true }, true, true) end
				area:emplace(card)
				areas[i], cards[i] = area, card
				columns[#columns + 1] = {
					n = G.UIT.C,
					config = { align = "cm", padding = 0.12 },
					nodes = {
						{
							n = G.UIT.R,
							config = { align = "cm" },
							nodes = {
								{ n = G.UIT.T, config = { text = label, scale = 0.32, colour = G.C.WHITE } },
							},
						},
						{
							n = G.UIT.R,
							config = { align = "cm" },
							nodes = {
								{ n = G.UIT.O, config = { object = area } },
							},
						},
					},
				}
			end
			G.FUNCS.overlay_menu({
				definition = create_UIBox_generic_options({
					contents = {
						{
							n = G.UIT.R,
							config = { align = "cm" },
							nodes = {
								{
									n = G.UIT.T,
									config = {
										text = "HIGHER CALLING — COSMETIC COMPARISON",
										scale = 0.4,
										colour = G.C.WHITE,
									},
								},
							},
						},
						{ n = G.UIT.R, config = { align = "cm" }, nodes = columns },
					},
				}),
			})
		end,
	},
	{
		wait = 2,
		run = function(S)
			S.check(G.SHADERS.mp_higher_calling ~= nil, "Shader compiles in the real renderer")
			S.check(cards[2].edition == nil, "Calling does not create an edition")
			S.check(cards[4].edition.negative, "Calling coexists with a real Negative edition")
			capture("calling-animated")
			G.SETTINGS.reduced_motion = true
		end,
	},
	{
		wait = 1,
		run = function()
			capture("calling-reduced-motion")
		end,
	},
	{
		run = function(S)
			PVP.CHAOS.for_run():clear()
			S.check(not PVP.CHAOS.has_rule("higher_calling"), "Effect expires without changing editions")
		end,
	},
	{
		wait = 1,
		run = function()
			capture("calling-expired")
		end,
	},
	{
		run = function()
			G.SETTINGS.reduced_motion = old_reduced
			G.FUNCS.exit_overlay_menu()
			for _, area in ipairs(areas) do
				area:remove()
			end
			assert(PVP.CHAOS.for_run():activate("higher_calling"))
			for _, key in ipairs({ "c_judgement", "c_fool" }) do
				local card = SMODS.create_card({ key = key, area = G.consumeables })
				card:add_to_deck()
				G.consumeables:emplace(card)
			end
		end,
	},
	{
		wait = 2,
		run = function(S)
			S.check(#G.consumeables.cards == 2, "Real tray holds Judgement and an unchanged Fool")
			capture("calling-inventory")
		end,
	},
	{
		run = function(S)
			local card = G.consumeables.cards[1]
			card.ability_UIBox_table = card:generate_UIBox_ability_table()
			local rows = card.ability_UIBox_table.main
			local footer = rows[#rows][1].nodes
			S.check(
				footer[1].nodes[1].config.text == localize("k_mp_higher_calling"),
				"Native tooltip includes Higher Calling"
			)
			S.check(
				footer[3].nodes[1].config.text == localize("k_mp_this_ante"),
				"Native tooltip includes ante duration"
			)
			G.FUNCS.overlay_menu({ definition = G.UIDEF.card_h_popup(card) })
		end,
	},
	{
		wait = 1,
		run = function()
			capture("calling-tooltip")
		end,
	},
	{
		run = function()
			G.FUNCS.exit_overlay_menu()
			G.FUNCS.go_to_menu()
		end,
	},
}

-- Finish the runner with the live comparison still open for manual inspection.
-- The automated scenario retains its expiry, inventory and cleanup checks.
if preview then
	return {
		steps[1],
		steps[2],
		{
			wait = 2,
			run = function(S)
				S.check(G.SHADERS.mp_higher_calling ~= nil, "Interactive comparison ready; press Back when finished")
			end,
		},
	}
end
return steps
