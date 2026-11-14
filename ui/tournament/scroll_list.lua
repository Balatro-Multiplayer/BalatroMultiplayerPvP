-- A scrollable list for the tournament screens. Balatro's UI has no
-- scrolling, so this shows a window of `visible` rows from a longer list and
-- moves it a row at a time: the mouse wheel, the arrow buttons, or a click on
-- the scroll bar's track (which jumps there). The track's lit part is the
-- thumb: where the window is in the list and how much of it is showing.
--
--   local list = PVP.TUI.scroll_list({
--       items = function() return {...} end,   -- read on every redraw
--       build_row = function(item) return node end,
--       visible = 4, row_h = 1.0, width = 13,
--       empty = "Nothing here",               -- or a function returning it
--   })
--   list.node        -- embed in a layout
--   list:update()    -- redraw (after data changes)
--   list:dispose()   -- when its page goes away

PVP.TUI = PVP.TUI or {}
local TUI = PVP.TUI

local lists = {}
local next_id = 0
-- The list the mouse wheel scrolls: the last one built that is still alive.
local wheel_target = nil

local TRACK_CELLS = 8

function TUI.scroll_list(opts)
	next_id = next_id + 1
	local list = { id = next_id, offset = 0, alive = true }
	lists[list.id] = list
	local visible = opts.visible or 4
	local row_h = opts.row_h or 1.0

	local function count()
		local ok, items = pcall(opts.items)
		return ok and items or {}
	end

	function list:scroll(delta)
		local before = self.offset
		self.offset = math.max(0, math.min(self.offset + delta, math.max(0, #count() - visible)))
		if self.offset ~= before then
			self:update()
		end
	end

	function list:jump(fraction)
		local max_offset = math.max(0, #count() - visible)
		self.offset = math.floor(fraction * max_offset + 0.5)
		self:update()
	end

	local function scrollbar(total)
		local max_offset = math.max(1, total - visible)
		local thumb_cells = math.max(1, math.floor(TRACK_CELLS * visible / total + 0.5))
		local thumb_start = math.floor((TRACK_CELLS - thumb_cells) * list.offset / max_offset + 0.5)
		-- The bar is as tall as the rows: two arrows (0.42 each), the column's
		-- padding (4 x 0.04) and the track's (9 x 0.02) leave this for the cells.
		local cell_h = math.max(0.05, (visible * row_h - 1.2) / TRACK_CELLS)
		local cells = {}
		for i = 0, TRACK_CELLS - 1 do
			local lit = i >= thumb_start and i < thumb_start + thumb_cells
			cells[#cells + 1] = {
				n = G.UIT.R,
				config = {
					align = "cm",
					minw = 0.22,
					minh = cell_h,
					colour = lit and G.C.UI.TEXT_INACTIVE or mix_colours(G.C.BLACK, G.C.L_BLACK, 0.6),
					button = "mp_pvp_tscroll_jump",
					ref_table = { list = list.id, fraction = i / (TRACK_CELLS - 1) },
					hover = true,
				},
				nodes = {},
			}
		end
		local function arrow(label, delta)
			return {
				n = G.UIT.R,
				config = { align = "cm", minw = 0.36, minh = 0.42, r = 0.08, colour = G.C.UI.BACKGROUND_INACTIVE, hover = true, shadow = true, button = "mp_pvp_tscroll_step", ref_table = { list = list.id, delta = delta } },
				nodes = { TUI.text(label, 0.32) },
			}
		end
		return {
			n = G.UIT.C,
			config = { align = "tm", padding = 0.04 },
			nodes = {
				arrow("^", -1),
				{ n = G.UIT.R, config = { align = "cm", padding = 0.02, r = 0.08, colour = G.C.BLACK }, nodes = cells },
				arrow("v", 1),
			},
		}
	end

	local function build()
		local items = count()
		list.offset = math.max(0, math.min(list.offset, math.max(0, #items - visible)))
		local rows = {}
		local empty = type(opts.empty) == "function" and opts.empty() or opts.empty
		if #items == 0 and empty then
			rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm", minh = row_h, minw = opts.width }, nodes = { TUI.text(empty, TUI.TEXT, G.C.UI.TEXT_INACTIVE) } }
		end
		for i = list.offset + 1, math.min(#items, list.offset + visible) do
			local ok, node = pcall(opts.build_row, items[i])
			rows[#rows + 1] = { n = G.UIT.R, config = { align = "cm", minh = row_h, padding = 0.03 }, nodes = { ok and node or TUI.text("Row failed: " .. tostring(node), TUI.SMALL, G.C.RED) } }
		end
		-- Keep the list's height fixed so the page doesn't jump.
		for _ = #rows + 1, visible do
			rows[#rows + 1] = { n = G.UIT.R, config = { minh = row_h, minw = opts.width }, nodes = {} }
		end
		local cols = { { n = G.UIT.C, config = { align = "tm" }, nodes = rows } }
		if #items > visible then
			cols[#cols + 1] = TUI.spacer(0.08)
			cols[#cols + 1] = scrollbar(#items)
		end
		return { nodes = { { n = G.UIT.R, config = { align = "tm" }, nodes = cols } } }
	end

	list.el = MPAPI.ui_element(build)
	list.node = list.el.node
	wheel_target = list

	function list:update()
		if self.alive then
			self.el:update()
		end
	end

	function list:dispose()
		self.alive = false
		lists[self.id] = nil
		if wheel_target == self then
			-- Back to the newest list still showing (e.g. the page under a closed overlay).
			wheel_target = nil
			for id, other in pairs(lists) do
				if not wheel_target or id > wheel_target.id then
					wheel_target = other
				end
			end
		end
	end

	return list
end

G.FUNCS.mp_pvp_tscroll_step = function(e)
	local ref = e.config.ref_table
	local list = ref and lists[ref.list]
	if list then
		list:scroll(ref.delta)
	end
end

G.FUNCS.mp_pvp_tscroll_jump = function(e)
	local ref = e.config.ref_table
	local list = ref and lists[ref.list]
	if list then
		list:jump(ref.fraction)
	end
end

-- The mouse wheel scrolls the active list (and still reaches the game).
local original_wheelmoved = love.wheelmoved
love.wheelmoved = function(x, y)
	-- A bracket canvas under the cursor takes the wheel (it zooms).
	local canvas = TUI.canvas_wants_wheel and TUI.canvas_wants_wheel()
	if wheel_target and wheel_target.alive and y ~= 0 and not canvas then
		wheel_target:scroll(y > 0 and -1 or 1)
	end
	if original_wheelmoved then
		return original_wheelmoved(x, y)
	end
end
