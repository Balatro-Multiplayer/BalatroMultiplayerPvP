-- English-only developer lab, not a shipped Chaos queue or player-facing HUD.
local C = PVP.CHAOS
local selected = 1
local function keys()
	local result = {}
	for key in pairs(C.effects) do
		result[#result + 1] = key
	end
	table.sort(result)
	return result
end

local function line(text)
	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.025 },
		nodes = { { n = G.UIT.T, config = { text = text, scale = 0.3, colour = G.C.UI.TEXT_LIGHT } } },
	}
end

local function append_text(rows, text)
	local current = ""
	for word in text:gmatch("%S+") do
		if #current + #word > 68 then
			rows[#rows + 1] = line(current)
			current = ""
		end
		current = current == "" and word or current .. " " .. word
	end
	if current ~= "" then rows[#rows + 1] = line(current) end
end

function C.debug_button()
	return UIBox_button({
		id = "pvp_chaos_lab_open",
		button = "pvp_chaos_debug",
		label = { "Chaos lab (debug)" },
		minw = 5,
		colour = G.C.PURPLE,
	})
end

function G.FUNCS.pvp_chaos_choose(args)
	selected = args.to_key
	G.FUNCS.pvp_chaos_debug()
end

local function action(method)
	if not C.safe_point() then return end
	local runtime = C.for_run(true)
	local result, reason = method(runtime)
	if reason then runtime.state.last = reason end
	save_run()
	G.FUNCS.pvp_chaos_debug()
	return result
end

function G.FUNCS.pvp_chaos_activate()
	action(function(runtime)
		return runtime:activate(keys()[selected])
	end)
end

function G.FUNCS.pvp_chaos_random()
	action(function(runtime)
		return runtime:random()
	end)
end

function G.FUNCS.pvp_chaos_clear()
	action(function(runtime)
		runtime:clear()
	end)
end

function G.FUNCS.pvp_chaos_expire()
	action(function(runtime)
		if runtime.state.active[1] then runtime:expire(runtime.state.active[1].id) end
	end)
end

function G.FUNCS.pvp_chaos_tick()
	-- Explicit simulated time, including while this overlay is paused.
	action(function(runtime)
		return runtime:advance(10, false)
	end)
end

function G.FUNCS.pvp_chaos_scheduler()
	action(function(runtime)
		runtime.state.scheduler.enabled = not runtime.state.scheduler.enabled
	end)
end

function G.FUNCS.pvp_chaos_debug()
	local rows = { line("CHAOS LAB — local Custom Solo only") }
	local runtime = C.for_run()
	if not C.safe_point() then
		append_text(
			rows,
			"Open in a Custom Solo run at blind selection or in a shop. No multiplayer or replay controls."
		)
		if runtime then
			for _, instance in ipairs(runtime.state.active) do
				append_text(
					rows,
					"Active: "
						.. C.effects[instance.key].label
						.. " / "
						.. instance.remaining
						.. " "
						.. C.effects[instance.key].duration.boundary
				)
			end
		end
	else
		local names, all = {}, keys()
		for _, key in ipairs(all) do
			names[#names + 1] = C.effects[key].label .. (C.effects[key].pending and " [pending]" or "")
		end
		local def = C.effects[all[selected]]
		rows[#rows + 1] = {
			n = G.UIT.R,
			config = { align = "cm" },
			nodes = {
				create_option_cycle({
					options = names,
					current_option = selected,
					opt_callback = "pvp_chaos_choose",
					w = 6,
				}),
			},
		}
		append_text(rows, def.description)
		local allowed, reason
		if runtime then
			allowed, reason = runtime:eligible(def.key)
		else
			allowed, reason = C.adapter.allowed(def)
		end
		if def.pending then
			allowed, reason = false, def.pending
		end
		append_text(rows, allowed and "Eligible now" or reason or "Unavailable here")
		append_text(
			rows,
			"Window: "
				.. (
					def.duration == "instant" and "instant; consequences persist"
					or tostring(def.duration.count) .. " " .. def.duration.boundary
				)
		)
		if runtime then
			local clock = runtime.state.scheduler
			append_text(
				rows,
				"Scheduler stub: "
					.. (clock.enabled and "armed" or "off")
					.. " / "
					.. clock.remaining
					.. "s remaining. Manual ticks only."
			)
			for _, instance in ipairs(runtime.state.active) do
				append_text(
					rows,
					"Active: "
						.. C.effects[instance.key].label
						.. " / "
						.. instance.remaining
						.. " "
						.. C.effects[instance.key].duration.boundary
				)
			end
			append_text(rows, runtime.state.last or "No events yet")
		end
		for _, entry in ipairs({
			{ "pvp_chaos_activate", "Activate selected" },
			{ "pvp_chaos_random", "Random eligible effect" },
			{ "pvp_chaos_expire", "Expire oldest" },
			{ "pvp_chaos_clear", "Clear active effects" },
			{ "pvp_chaos_scheduler", "Arm / disarm scheduler stub" },
			{ "pvp_chaos_tick", "Advance stub 10 seconds" },
		}) do
			rows[#rows + 1] = {
				n = G.UIT.R,
				config = { align = "cm", padding = 0.02 },
				nodes = {
					UIBox_button({ id = entry[1], button = entry[1], label = { entry[2] }, minw = 5, minh = 0.4 }),
				},
			}
		end
	end
	G.SETTINGS.paused = true
	G.FUNCS.overlay_menu({ definition = create_UIBox_generic_options({ contents = rows }) })
end

function G.FUNCS.pvp_chaos_normal_options()
	G.FUNCS.overlay_menu({ definition = create_UIBox_options() })
end

-- A local Custom Solo lobby need not remain MPAPI's active menu mod after
-- launch. Route its actual Options entry point by run identity, rather than
-- relying on the API's active-menu options_builder dispatch.
local options = G.FUNCS.options
function G.FUNCS.options(...)
	if C.available() then
		G.FUNCS.overlay_menu({ definition = PVP.create_run_options() })
		return
	end
	return options(...)
end
