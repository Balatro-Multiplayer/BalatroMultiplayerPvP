local checks = 0
local function check(value, message)
	assert(value, message)
	checks = checks + 1
end
PVP = {}
G = {
	FUNCS = {},
	SETTINGS = {},
	UIT = { R = "row", T = "text" },
	C = { UI = { TEXT_LIGHT = {} } },
}
dofile("lib/chaos_clock.lua")
dofile("lib/chaos_effects.lua")
dofile("ui/chaos_status.lua")
local C = PVP.CHAOS
check(#C.status_entries(nil) == 0, "No run is safe")
check(#C.status_entries({}) == 0, "Inspection does not need initialized state")
local game = {
	pvp_chaos = {
		active = {
			{ key = "higher_calling", remaining = 1 },
			{ key = "everybody_counts", remaining = 1 },
		},
	},
}
local entries = C.status_entries(game)
check(#entries == 2, "All active effects are inspectable")
check(entries[1].label == "Higher Calling", "Uses catalogue name")
check(entries[1].duration == "Until the ante changes", "Ante expiry is readable")
check(entries[2].duration == "Until the blind ends", "Blind expiry is distinct")
check(entries[2].description == C.effects.everybody_counts.description, "Catalogue owns descriptions")
entries[1].label = "Changed"
check(C.effects.higher_calling.label == "Higher Calling", "Snapshot cannot edit catalogue")
check(game.pvp_chaos.active[1].remaining == 1, "Inspection does not expire effects")
check(C.effects.clearance_sale.label == "Short Shelf Life", "Event does not borrow voucher name")
check(C.effects.clearance_sale.pending, "Renaming does not activate unfinished event")
local shown, cycle
function create_option_cycle(args)
	cycle = args
	return args
end
function UIBox_button(args)
	return args
end
function create_UIBox_generic_options(args)
	return args
end
G.FUNCS.overlay_menu = function(args)
	shown = args.definition
end
G.GAME = game
G.FUNCS.pvp_chaos_status()
check(cycle.options[2] == "Everybody Counts", "Selector includes every active effect")
check(shown.back_func == "options" and G.SETTINGS.paused, "Inspection returns to options and pauses")
G.FUNCS.pvp_chaos_status_choose({ to_key = 2 })
check(cycle.current_option == 2, "Can inspect a second effect")
game.pvp_chaos.active = {}
G.FUNCS.pvp_chaos_status()
check(shown.contents[2].nodes[1].config.text == "No temporary effects active", "Expired list has empty state")
check(game.pvp_chaos.active[1] == nil, "Rendering never creates effects")
game.chaos_draft = { acquired = {} }
G.FUNCS.pvp_chaos_status()
check(shown.contents[4].nodes[1].button == "pvp_chaos_inspect", "Links to existing deck inspection")
print("Chaos status: " .. checks .. " checks passed")
