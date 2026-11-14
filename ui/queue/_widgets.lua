-- Stateless UI construction and real-time event helpers.
local Widgets = {}
PVP.QUEUE_WIDGETS = Widgets

function Widgets.now()
	return love.timer.getTime()
end

function Widgets.reduced_motion()
	return G.SETTINGS and G.SETTINGS.reduced_motion
end

-- Persistent events must validate their owner before touching removed objects.
function Widgets.after(delay, is_current, fn)
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = delay,
		timer = "REAL",
		blockable = false,
		blocking = false,
		no_delete = true,
		func = function()
			if not is_current or is_current() then fn() end
			return true
		end,
	}))
end

function Widgets.ease_to(ref_table, ref_value, value, duration)
	G.E_MANAGER:add_event(Event({
		trigger = "ease",
		ref_table = ref_table,
		ref_value = ref_value,
		ease_to = value,
		delay = duration,
		timer = "REAL",
		blockable = false,
		blocking = false,
		no_delete = true,
		func = function(t)
			return t
		end,
	}))
end

function Widgets.slide(uibox, x, y)
	if not uibox or not uibox.alignment then return end
	if x then uibox.alignment.offset.x = x end
	if y then uibox.alignment.offset.y = y end
	uibox:align_to_major()
end

function Widgets.juice(uibox, amount, rot)
	if uibox and uibox.UIRoot then uibox.UIRoot:juice_up(amount or 0.1, rot or 0.05) end
end

function Widgets.remove_box(uibox)
	if uibox then pcall(function()
		uibox:remove()
	end) end
end

function Widgets.text_object(id, string, scale, colour, opts)
	opts = opts or {}
	return {
		n = G.UIT.O,
		config = {
			id = id,
			object = DynaText({
				string = string,
				colours = { colour },
				scale = scale,
				shadow = true,
				float = opts.float,
				bump = opts.bump,
				pop_in = opts.pop_in,
				pop_in_rate = opts.pop_in_rate,
				silent = true,
				maxw = opts.maxw,
			}),
		},
	}
end

function Widgets.room_box(definition, offset, popup)
	return UIBox({
		definition = definition,
		config = {
			align = "cm",
			offset = offset,
			major = G.ROOM_ATTACH,
			bond = "Weak",
			instance_type = popup and "POPUP" or nil,
		},
	})
end

function Widgets.clear_root(nodes, padding)
	return { n = G.UIT.ROOT, config = { align = "cm", padding = padding or 0, colour = G.C.CLEAR }, nodes = nodes }
end
