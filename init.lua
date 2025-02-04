local awful = require("awful")
local gears = require("gears")
local naughty = require("naughty")
local wibox = require("wibox")
local cairo_lgi = require("lgi").cairo
local beautiful = require("beautiful")

local cursor_mode_active = false
local keygrabber

local teleport_keys = {
	{ "q", "w", "e", "r", "t" },
	{ "a", "s", "d", "f", "g" },
	{ "z", "x", "c", "v", "b" },
	{ "y", "u", "i", "o", "p" },
	{ "h", "j", "k", "l", "~" },
	{ "n", "m", ",", ".", "/" },
}

local NUM_ROWS = #teleport_keys
local NUM_COLS = 0
for _, row in ipairs(teleport_keys) do
	if #row > NUM_COLS then
		NUM_COLS = #row
	end
end

-- Main Grid
local grid_wibox = wibox({
	visible = false,
	ontop = true,
	type = "splash",
	x = 0,
	y = 0,
	width = awful.screen.focused().geometry.width,
	height = awful.screen.focused().geometry.height,
	bg = "#0000b0" .. "44",
})

local grid_widget = wibox.widget({
	widget = wibox.widget.base.make_widget,
	fit = function(_, _, width, height)
		return width, height
	end,
	draw = function(_, _, cr, width, height)
		-- Main Grid lines
		cr:set_source_rgba(1, 0, 0, 0.5)
		local cell_width = width / NUM_COLS
		local cell_height = height / NUM_ROWS

		for col = 0, NUM_COLS do
			local x = col * cell_width
			cr:move_to(x, 0)
			cr:line_to(x, height)
		end
		for row = 0, NUM_ROWS do
			local y = row * cell_height
			cr:move_to(0, y)
			cr:line_to(width, y)
		end
		cr:set_line_width(2)
		cr:stroke()

		-- Main Grid Labels
		cr:select_font_face("Sans", cairo_lgi.FontSlant.NORMAL, cairo_lgi.FontWeight.BOLD)
		cr:set_font_size(180)
		-- Fill color: R, G, B, Alpha (0-1)
		local fill_r, fill_g, fill_b, fill_a = 1, 1, 0, 0.5
		-- Outline color: R, G, B, Alpha (0-1)
		local outline_r, outline_g, outline_b, outline_a = 0, 0, 0, 1
		local outline_width = 2

		for row = 1, NUM_ROWS do
			for col = 1, NUM_COLS do
				local cx = (col - 1) * cell_width + (cell_width / 2)
				local cy = (row - 1) * cell_height + (cell_height / 2)
				local text = ""
				if teleport_keys[row] and teleport_keys[row][col] then
					text = teleport_keys[row][col]:gsub("^%l", string.upper)
				end

				local extents = cr:text_extents(text)
				local text_x = cx - (extents.width / 2 + extents.x_bearing)
				local text_y = cy - (extents.height / 2 + extents.y_bearing)
				cr:move_to(text_x, text_y)
				cr:text_path(text)
				cr:set_source_rgba(outline_r, outline_g, outline_b, outline_a)
				cr:set_line_width(outline_width)
				cr:stroke_preserve()
				cr:set_source_rgba(fill_r, fill_g, fill_b, fill_a)
				cr:fill()
			end
		end
	end,
})

grid_wibox:setup({
	grid_widget,
	layout = wibox.layout.stack,
})

local function toggle_grid()
	grid_wibox.visible = not grid_wibox.visible
end

local function move_cursor_to_section(section)
	local screen = mouse.screen
	local g = screen.geometry

	local rowIndex, colIndex
	for row = 1, #teleport_keys do
		local col = gears.table.hasitem(teleport_keys[row], section)
		if col then
			rowIndex = row
			colIndex = col
			break
		end
	end
	if not rowIndex or not colIndex then
		return
	end

	local row_height = g.height / NUM_ROWS
	local col_width = g.width / NUM_COLS

	local x_offset = (colIndex - 1) * col_width
	local y_offset = (rowIndex - 1) * row_height

	mouse.coords({
		x = g.x + x_offset + (col_width / 2),
		y = g.y + y_offset + (row_height / 2),
	})
end

local function move_cursor_to_section_precise(section, geom)
	local rowIndex, colIndex
	for row = 1, #teleport_keys do
		local col = gears.table.hasitem(teleport_keys[row], section)
		if col then
			rowIndex = row
			colIndex = col
			break
		end
	end
	if not rowIndex or not colIndex then
		return
	end

	local cell_width = geom.width / NUM_COLS
	local cell_height = geom.height / NUM_ROWS

	local x_offset = (colIndex - 1) * cell_width
	local y_offset = (rowIndex - 1) * cell_height

	mouse.coords({
		x = geom.x + x_offset + (cell_width / 2),
		y = geom.y + y_offset + (cell_height / 2),
	})
end

local function toggle_cursor_mode()
	cursor_mode_active = not cursor_mode_active
	toggle_grid()
	if cursor_mode_active then
		naughty.notify({ title = "Cursor Mode", text = "Ativado." })
		keygrabber = awful.keygrabber.run(function(_, key, event)
			if event == "release" then
				return
			end
			if key == "dead_tilde" or key == "asciitilde" then
				key = "~"
			end
			if key == "Escape" then
				toggle_cursor_mode()
			else
				move_cursor_to_section(key)
				toggle_cursor_mode()
			end
		end)
	else
		naughty.notify({ title = "Cursor Mode", text = "Desativado." })
		if keygrabber then
			awful.keygrabber.stop(keygrabber)
		end
	end
end

-- Precise Grid Widget
local function start_precise_click_mode()
	local cur = mouse.coords()
	local screen = awful.screen.focused()
	local sgeom = screen.geometry
	local precise_w = sgeom.width / NUM_COLS
	local precise_h = sgeom.height / NUM_ROWS
	local precise_x = cur.x - (precise_w / 2)
	local precise_y = cur.y - (precise_h / 2)

	local precise_grid_wibox = wibox({
		visible = true,
		ontop = true,
		type = "splash",
		x = precise_x,
		y = precise_y,
		width = precise_w,
		height = precise_h,
		bg = "#0000b0" .. "44",
	})

	local precise_grid_widget = wibox.widget({
		widget = wibox.widget.base.make_widget,
		fit = function(_, _, width, height)
			return width, height
		end,
		draw = function(_, _, cr, width, height)
			cr:set_source_rgba(1, 0, 0, 0.5)
			local cell_width = width / NUM_COLS
			local cell_height = height / NUM_ROWS

			for col = 0, NUM_COLS do
				local x = col * cell_width
				cr:move_to(x, 0)
				cr:line_to(x, height)
			end
			for row = 0, NUM_ROWS do
				local y = row * cell_height
				cr:move_to(0, y)
				cr:line_to(width, y)
			end
			cr:set_line_width(2)
			cr:stroke()

			-- Precise Grid Labels
			cr:select_font_face("Sans", cairo_lgi.FontSlant.NORMAL, cairo_lgi.FontWeight.BOLD)
			cr:set_font_size(60)
			-- Fill color: R, G, B, Alpha (0-1)
			local fill_r, fill_g, fill_b, fill_a = 1, 1, 0, 0.5
			-- Outline color: R, G, B, Alpha (0-1)
			local outline_r, outline_g, outline_b, outline_a = 0, 0, 0, 1
			local outline_width = 2

			for row = 1, NUM_ROWS do
				for col = 1, NUM_COLS do
					local cx = (col - 1) * cell_width + (cell_width / 2)
					local cy = (row - 1) * cell_height + (cell_height / 2)
					local text = ""
					if teleport_keys[row] and teleport_keys[row][col] then
						text = teleport_keys[row][col]:gsub("^%l", string.upper)
					end
					local extents = cr:text_extents(text)
					local text_x = cx - (extents.width / 2 + extents.x_bearing)
					local text_y = cy - (extents.height / 2 + extents.y_bearing)
					cr:move_to(text_x, text_y)
					cr:text_path(text)
					cr:set_source_rgba(outline_r, outline_g, outline_b, outline_a)
					cr:set_line_width(outline_width)
					cr:stroke_preserve()
					cr:set_source_rgba(fill_r, fill_g, fill_b, fill_a)
					cr:fill()
				end
			end
		end,
	})
	precise_grid_wibox:setup({
		precise_grid_widget,
		layout = wibox.layout.stack,
	})

	local precise_keygrabber = awful.keygrabber.run(function(_, key, event)
		if event == "release" then
			return
		end
		if key == "dead_tilde" or key == "asciitilde" then
			key = "~"
		end
		if key == "Escape" then
			awful.keygrabber.stop(precise_keygrabber)
			precise_grid_wibox.visible = false
		else
			move_cursor_to_section_precise(key, { x = precise_x, y = precise_y, width = precise_w, height = precise_h })
			awful.util.spawn_with_shell("xdotool click 1")
			awful.keygrabber.stop(precise_keygrabber)
			precise_grid_wibox.visible = false
		end
	end)
end

local function toggle_cursor_mode_with_click()
	cursor_mode_active = not cursor_mode_active
	toggle_grid()
	if cursor_mode_active then
		naughty.notify({ title = "Cursor Mode", text = "Ativado (com clique preciso)." })
		keygrabber = awful.keygrabber.run(function(_, key, event)
			if event == "release" then
				return
			end
			if key == "dead_tilde" or key == "asciitilde" then
				key = "~"
			end
			if key == "Escape" then
				toggle_cursor_mode_with_click()
			else
				move_cursor_to_section(key)
				toggle_grid()
				awful.keygrabber.stop(keygrabber)
				cursor_mode_active = false
				start_precise_click_mode()
			end
		end)
	else
		naughty.notify({ title = "Cursor Mode", text = "Desativado." })
		if keygrabber then
			awful.keygrabber.stop(keygrabber)
		end
	end
end

-- Global Bindings
local globalkeys = gears.table.join(
	root.keys(),
	awful.key(
		{ "Mod4", "Shift" },
		"u",
		toggle_cursor_mode,
		{ description = "Ativar modo de controle do cursor", group = "custom" }
	),
	awful.key(
		{ "Mod4", "Shift" },
		"i",
		toggle_cursor_mode_with_click,
		{ description = "Ativar modo de controle do cursor com clique preciso", group = "custom" }
	)
)

root.keys(globalkeys)
return {}
