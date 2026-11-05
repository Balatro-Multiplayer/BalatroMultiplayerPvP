-- Read-only inspection, deliberately separate from the lab's mutation controls.
local C = PVP.CHAOS
local selected = 1

function C.status_entries(game)
	local entries = {}
	for _, instance in ipairs(game and game.pvp_chaos and game.pvp_chaos.active or {}) do
		local def = C.effects[instance.key]
		if def then
			local boundaries = {
				ante_end = "Until the ante changes",
				blind_end = "Until the blind ends",
				shop_end = "Until you leave the shop",
			}
			entries[#entries + 1] = {
				label = def.label,
				description = def.description,
				duration = boundaries[def.duration.boundary] or "Temporary effect",
			}
		end
	end
	return entries
end

local function line(text)
	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.04 },
		nodes = { { n = G.UIT.T, config = { text = text, scale = 0.35, colour = G.C.UI.TEXT_LIGHT } } },
	}
end

local function append_text(rows, text)
	local current = ""
	for word in text:gmatch("%S+") do
		if #current + #word > 60 then
			rows[#rows + 1] = line(current)
			current = ""
		end
		current = current == "" and word or current .. " " .. word
	end
	if current ~= "" then rows[#rows + 1] = line(current) end
end

function G.FUNCS.pvp_chaos_status_choose(args)
	selected = args.to_key
	G.FUNCS.pvp_chaos_status()
end

function G.FUNCS.pvp_chaos_status()
	-- Do not call for_run here: inspection must not create state or expire effects.
	local entries = C.status_entries(G.GAME)
	selected = math.max(1, math.min(selected, #entries))
	local rows = { line("Run effects") }
	if #entries == 0 then
		rows[#rows + 1] = line("No temporary effects active")
	else
		local names = {}
		for _, entry in ipairs(entries) do
			names[#names + 1] = entry.label
		end
		rows[#rows + 1] = {
			n = G.UIT.R,
			config = { align = "cm" },
			nodes = {
				create_option_cycle({
					options = names,
					current_option = selected,
					opt_callback = "pvp_chaos_status_choose",
					w = 6,
				}),
			},
		}
		append_text(rows, entries[selected].description)
		rows[#rows + 1] = line(entries[selected].duration)
	end
	if G.GAME and G.GAME.chaos_draft then
		rows[#rows + 1] = line("Deck picks: Antes 2, 3, 5 and 7")
		rows[#rows + 1] = {
			n = G.UIT.R,
			config = { align = "cm" },
			nodes = {
				UIBox_button({ button = "pvp_chaos_inspect", label = { "View acquired decks" }, minw = 5 }),
			},
		}
	end
	G.SETTINGS.paused = true
	G.FUNCS.overlay_menu({ definition = create_UIBox_generic_options({ back_func = "options", contents = rows }) })
end
