-- The zoomable bracket: a game object (embedded in a page as G.UIT.O) that
-- draws a PVP.BracketLayout itself, clipped to its frame. Balatro's UI can't
-- zoom or clip, so this draws with love.graphics from its top-left corner (like prep_draw, which puts
-- the origin there in game units, but never tilted).
--
--   mouse wheel   zoom around the cursor
--   drag          pan
--   click a match select it (on_select(box))
--   :zoom_by(f), :fit(), :focus(id)   for the page's buttons
--
-- The layout is in "bracket units"; the view is zoom + pan, where pan is the
-- bracket point at the frame's top-left corner.

PVP.TUI = PVP.TUI or {}
local TUI = PVP.TUI
local LAYOUT = function()
	return PVP.BracketLayout
end

local Canvas = Moveable:extend()
PVP.BracketCanvas = Canvas

-- The canvas under the mouse, if any (it takes the mouse wheel).
local hovered_canvas = nil

function TUI.canvas_wants_wheel()
	return hovered_canvas ~= nil and not hovered_canvas.REMOVED and hovered_canvas.mouse.inside
end

local CLICK_SLOP = 0.08 -- how far (frame units) a press may move and still be a click

function Canvas:init(args)
	Moveable.init(self, 0, 0, args.w, args.h)
	self.layout = nil
	self.zoom = 1
	self.pan = { x = 0, y = 0 }
	self.mouse = { x = 0, y = 0, inside = false }
	self.selected = nil
	self.me = args.me
	self.on_select = args.on_select
	self.fitted = false
	-- What to say while there is no bracket (set_empty_text).
	self.empty_text = "Loading..."
	self.states.collide.can = false
end

-- New layout (data changed). Keeps the view, except the first time (fit).
function Canvas:set_layout(layout, me)
	self.layout = layout
	self.me = me
	if layout and not self.fitted then
		self:fit()
		self.fitted = true
	end
end

function Canvas:set_empty_text(text)
	self.empty_text = text
end

function Canvas:fit()
	if not self.layout then
		return
	end
	local zoom, px, py = LAYOUT().fit(self.layout, self.T.w, self.T.h)
	self.zoom, self.pan.x, self.pan.y = zoom, px, py
end

-- Zoom by a factor around a frame point (default: the centre).
function Canvas:zoom_by(factor, fx, fy)
	fx = fx or self.T.w / 2
	fy = fy or self.T.h / 2
	local L = LAYOUT()
	local bx, by = self.pan.x + fx / self.zoom, self.pan.y + fy / self.zoom
	self.zoom = math.max(L.MIN_ZOOM, math.min(L.MAX_ZOOM, self.zoom * factor))
	self.pan.x, self.pan.y = bx - fx / self.zoom, by - fy / self.zoom
end

-- Centre a match and zoom in to a readable size.
function Canvas:focus(id)
	local box = LAYOUT().box(self.layout, id)
	if not box then
		return false
	end
	self.zoom = math.max(self.zoom, 1)
	self.pan.x = box.x + box.w / 2 - self.T.w / 2 / self.zoom
	self.pan.y = box.y + box.h / 2 - self.T.h / 2 / self.zoom
	self.selected = id
	return true
end

function Canvas:update(dt)
	if self.REMOVED then
		return
	end
	if self.mouse.inside then
		hovered_canvas = self
	elseif hovered_canvas == self then
		hovered_canvas = nil
	end
	local down = love.mouse.isDown(1)
	if down and not self.was_down and self.mouse.inside then
		self.press = { mx = self.mouse.x, my = self.mouse.y, px = self.pan.x, py = self.pan.y, moved = 0 }
	end
	if down and self.press then
		local dx, dy = self.mouse.x - self.press.mx, self.mouse.y - self.press.my
		self.press.moved = math.max(self.press.moved, math.abs(dx) + math.abs(dy))
		self.pan.x = self.press.px - dx / self.zoom
		self.pan.y = self.press.py - dy / self.zoom
	end
	if not down and self.press then
		if self.press.moved < CLICK_SLOP and self.layout then
			local box = LAYOUT().hit(self.layout, self.pan.x + self.mouse.x / self.zoom, self.pan.y + self.mouse.y / self.zoom)
			self.selected = box and box.id or nil
			if self.on_select then
				self.on_select(box)
			end
		end
		self.press = nil
	end
	self.was_down = down
end

-- Zoomed out, text is too small to read: it fades into a bar the size of the
-- text (so boxes don't look empty and words don't pop in when zooming).
local FADE_FROM, FADE_TO = 0.24, 0.4

local function text_fade(zoom)
	return math.max(0, math.min(1, (zoom - FADE_FROM) / (FADE_TO - FADE_FROM)))
end

-- Text at a scale like a UI text node's, left-aligned at x (or right-aligned
-- to right_x, or centred on centre_x), vertically centred in [y, y + h].
-- fade: 1 = text, 0 = bar. max_w: shrunk to fit that width.
local function text(str, x, y, h, scale, colour, right_x, fade, max_w, centre_x)
	fade = fade or 1
	local font = G.LANG.font
	local s = scale * font.FONTSCALE / G.TILESIZE
	local w = font.FONT:getWidth(str) * s * font.squish
	if max_w and w > max_w then
		s = s * max_w / w
		w = max_w
	end
	local th = font.FONT:getHeight() * s * font.TEXT_HEIGHT_SCALE
	local left = centre_x and (centre_x - w / 2) or (right_x and (right_x - w) or x)
	local a = colour[4] or 1
	if fade < 1 then
		local bh = th * 0.5
		love.graphics.setColor(colour[1], colour[2], colour[3], a * 0.6 * (1 - fade))
		love.graphics.rectangle("fill", left, y + (h - bh) / 2, w, bh, bh / 2, bh / 2)
	end
	if fade > 0 then
		love.graphics.setColor(colour[1], colour[2], colour[3], a * fade)
		love.graphics.print(str, left + font.TEXT_OFFSET.x * s, y + (h - th) / 2 + font.TEXT_OFFSET.y * s, 0, s * font.squish, s)
	end
	return w
end

local function short(name, max)
	name = tostring(name)
	if #name > max then
		return name:sub(1, max - 1) .. "."
	end
	return name
end

local function player_line(m, side)
	local p = m.players and m.players[side]
	if p == "tbd" then
		return "TBD", nil, true
	end
	if type(p) ~= "table" then
		return "bye", nil, true
	end
	-- A provisional bracket's empty slots (the server's open-spot-N).
	if tostring(p.id):find("^open%-spot%-") then
		return p.name, nil, true
	end
	return p.name, p.id, false
end

function Canvas:draw_box(box, fade)
	local m = box.match
	local mine = self.me and m.players and ((type(m.players[1]) == "table" and m.players[1].id == self.me) or (type(m.players[2]) == "table" and m.players[2].id == self.me))
	local live = m.status == "in_progress" or (m.clock and m.clock.phase == "in_game")
	love.graphics.setColor(live and mix_colours(G.C.GREEN, G.C.BLACK, 0.25) or mix_colours(G.C.L_BLACK, G.C.BLACK, 0.4))
	love.graphics.rectangle("fill", box.x, box.y, box.w, box.h, 0.08, 0.08)
	if box.id == self.selected or mine then
		love.graphics.setLineWidth(math.max(box.id == self.selected and 0.06 or 0.045, 2 * self.pixel))
		love.graphics.setColor(box.id == self.selected and G.C.GOLD or G.C.BLUE)
		love.graphics.rectangle("line", box.x, box.y, box.w, box.h, 0.08, 0.08)
	end
	-- The two players apart: the lower half a shade darker (a thin divider
	-- line shimmered).
	love.graphics.setColor(0, 0, 0, 0.18)
	local r, mid, bottom = 0.08, box.y + box.h / 2, box.y + box.h
	love.graphics.rectangle("fill", box.x, mid, box.w, box.h / 2 - r)
	love.graphics.rectangle("fill", box.x + r, bottom - r, box.w - 2 * r, r)
	love.graphics.arc("fill", box.x + r, bottom - r, r, math.pi / 2, math.pi)
	love.graphics.arc("fill", box.x + box.w - r, bottom - r, r, 0, math.pi / 2)
	local done = m.status == "done"
	local winner = m.outcome and m.outcome.winner
	local score_known = done or m.status == "in_progress"
	for side = 1, 2 do
		local name, id, faint = player_line(m, side)
		local y = box.y + (side - 1) * box.h / 2
		local h = box.h / 2
		local colour = G.C.UI.TEXT_LIGHT
		if faint then
			colour = G.C.UI.TEXT_INACTIVE
		elseif done and winner then
			colour = (id == winner) and G.C.GOLD or G.C.UI.TEXT_INACTIVE
		end
		text(short(name, 16), box.x + 0.14, y, h, 0.3, colour, nil, fade)
		if score_known and not faint then
			text(tostring(m.wins and m.wins[side] or 0), 0, y, h, 0.32, colour, box.x + box.w - 0.14, fade)
		end
	end
	if live then
		love.graphics.setColor(G.C.GREEN)
		love.graphics.circle("fill", box.x + box.w - 0.12, box.y + 0.12, 0.05)
	end
end

function Canvas:draw()
	if not self.states.visible or self.REMOVED then
		return
	end
	-- Like prep_draw(self, 1) but never rotated or scaled: the menu box tilts
	-- and bounces as it moves, which looks wobbly on a detailed drawing.
	love.graphics.push()
	-- Snapped to whole pixels: the box drifts by fractions of a pixel, and
	-- lines thinner than a pixel shimmer when they do.
	local unit = G.TILESCALE * G.TILESIZE
	love.graphics.translate(math.floor(self.VT.x * unit + 0.5), math.floor(self.VT.y * unit + 0.5))
	love.graphics.scale(unit)
	local w, h = self.T.w, self.T.h

	-- Where the mouse is, in frame units (the game draws at CANV_SCALE).
	local mx, my = love.mouse.getPosition()
	local scale = G.CANV_SCALE or 1
	local lx, ly = love.graphics.inverseTransformPoint(mx * scale, my * scale)
	self.mouse.x, self.mouse.y = lx, ly
	self.mouse.inside = lx >= 0 and ly >= 0 and lx <= w and ly <= h

	love.graphics.setColor(mix_colours(G.C.BLACK, G.C.L_BLACK, 0.7))
	love.graphics.rectangle("fill", 0, 0, w, h, 0.12, 0.12)

	-- Clip to the frame.
	local x0, y0 = love.graphics.transformPoint(0, 0)
	local x1, y1 = love.graphics.transformPoint(w, h)
	local sx, sy, sw, sh = love.graphics.getScissor()
	love.graphics.intersectScissor(math.floor(x0), math.floor(y0), math.ceil(x1 - x0), math.ceil(y1 - y0))

	local old_font = love.graphics.getFont()
	love.graphics.setFont(G.LANG.font.FONT)
	if self.layout then
		love.graphics.push()
		love.graphics.scale(self.zoom)
		-- One screen pixel in bracket units (the game draws at CANV_SCALE).
		-- Lines are at least two: Balatro's CRT filter bends the picture a
		-- little with the mouse and over time, and one-pixel lines shimmer.
		self.pixel = (G.CANV_SCALE or 1) / (unit * self.zoom)
		love.graphics.translate(-self.pan.x, -self.pan.y)
		-- Connectors.
		local old_style = love.graphics.getLineStyle()
		love.graphics.setLineStyle("smooth")
		love.graphics.setLineWidth(math.max(0.035, 2 * self.pixel))
		love.graphics.setColor(G.C.UI.TEXT_INACTIVE[1], G.C.UI.TEXT_INACTIVE[2], G.C.UI.TEXT_INACTIVE[3], 0.6)
		for _, line in ipairs(self.layout.lines) do
			love.graphics.line(line.points)
		end
		-- Round headings.
		local fade = text_fade(self.zoom)
		-- The mouse in bracket units, for the headings' tooltips.
		local bx, by = self.pan.x + self.mouse.x / self.zoom, self.pan.y + self.mouse.y / self.zoom
		self.tip = nil
		for _, label in ipairs(self.layout.labels) do
			local tw = text(label.text, label.x, label.y, LAYOUT().LABEL_H, 0.34, G.C.UI.TEXT_INACTIVE, nil, fade)
			if label.tip then
				-- A "?" after the heading; hovering the heading shows the tip.
				local cx, cy, r = label.x + tw + 0.22, label.y + LAYOUT().LABEL_H / 2, 0.14
				love.graphics.setColor(G.C.UI.BACKGROUND_INACTIVE[1], G.C.UI.BACKGROUND_INACTIVE[2], G.C.UI.BACKGROUND_INACTIVE[3], fade)
				love.graphics.circle("fill", cx, cy, r)
				text("?", 0, cy - r, 2 * r, 0.24, G.C.UI.TEXT_LIGHT, nil, fade, nil, cx)
				if self.mouse.inside and bx >= label.x and bx <= cx + r and by >= label.y and by <= label.y + LAYOUT().LABEL_H then
					self.tip = label.tip
				end
			end
			-- The round's timing under its heading: when it starts, how it's played.
			local line_y = label.y + LAYOUT().LABEL_H - 0.08
			for _, line in ipairs({ label.sub or false, label.sub2 or false }) do
				if line then
					text(line, label.x, line_y, LAYOUT().SUB_H, 0.27, G.C.GOLD, nil, fade, LAYOUT().BOX_W)
				end
				line_y = line_y + LAYOUT().SUB_H
			end
		end
		-- Breaks: in the gap before a round, a faint line down its section.
		for _, gap in ipairs(self.layout.gaps or {}) do
			local top = gap.y + LAYOUT().LABEL_H
			love.graphics.setLineWidth(math.max(0.025, 2 * self.pixel))
			love.graphics.setColor(G.C.GOLD[1], G.C.GOLD[2], G.C.GOLD[3], 0.35)
			love.graphics.line(gap.x, top + 2 * LAYOUT().SUB_H, gap.x, gap.bottom or top)
			text(gap.text, 0, gap.y + LAYOUT().LABEL_H - 0.08, LAYOUT().SUB_H, 0.25, G.C.GOLD, nil, fade, LAYOUT().COL_GAP - 0.1, gap.x)
			text("break", 0, gap.y + LAYOUT().LABEL_H - 0.08 + LAYOUT().SUB_H, LAYOUT().SUB_H, 0.25, G.C.GOLD, nil, fade, LAYOUT().COL_GAP - 0.1, gap.x)
		end
		for _, box in ipairs(self.layout.boxes) do
			self:draw_box(box, fade)
		end
		love.graphics.setLineStyle(old_style)
		love.graphics.pop()
	else
		text(self.empty_text, 0.4, 0, h, 0.4, G.C.UI.TEXT_INACTIVE)
	end

	if sx then
		love.graphics.setScissor(sx, sy, sw, sh)
	else
		love.graphics.setScissor()
	end
	-- A heading's tooltip, at the mouse (in frame units, not zoomed or clipped),
	-- in Balatro's tooltip colours.
	if self.tip then
		local lw, line_h = 0, 0.32
		for _, line in ipairs(self.tip) do
			local font = G.LANG.font
			local s = 0.28 * font.FONTSCALE / G.TILESIZE
			lw = math.max(lw, font.FONT:getWidth(line) * s * font.squish)
		end
		local bw, bh = lw + 0.3, #self.tip * line_h + 0.24
		local x, y = self.mouse.x + 0.25, self.mouse.y + 0.25
		if x + bw > w then
			x = math.max(0, self.mouse.x - bw - 0.15)
		end
		love.graphics.setColor(G.C.RED)
		love.graphics.rectangle("fill", x - 0.05, y - 0.05, bw + 0.1, bh + 0.1, 0.12, 0.12)
		love.graphics.setColor(G.C.WHITE)
		love.graphics.rectangle("fill", x, y, bw, bh, 0.1, 0.1)
		for i, line in ipairs(self.tip) do
			text(line, x + 0.15, y + 0.12 + (i - 1) * line_h, line_h, 0.28, G.C.UI.TEXT_DARK)
		end
	end
	love.graphics.setFont(old_font)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.pop()
end

-- The mouse wheel zooms the canvas under the cursor (before any list scrolls).
local original_wheelmoved = love.wheelmoved
love.wheelmoved = function(x, y)
	if TUI.canvas_wants_wheel() and y ~= 0 then
		local c = hovered_canvas
		c:zoom_by(y > 0 and 1.15 or 1 / 1.15, c.mouse.x, c.mouse.y)
		return
	end
	if original_wheelmoved then
		return original_wheelmoved(x, y)
	end
end
