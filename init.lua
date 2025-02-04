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
		cr:set_source_rgba(1, 1, 1, 0.1) -- cor das linhas com transparência

		local cell_width = width / NUM_COLS
		local cell_height = height / NUM_ROWS

		-- Desenha linhas verticais
		for col = 0, NUM_COLS do
			local x = col * cell_width
			cr:move_to(x, 0)
			cr:line_to(x, height)
		end

		-- Desenha linhas horizontais
		for row = 0, NUM_ROWS do
			local y = row * cell_height
			cr:move_to(0, y)
			cr:line_to(width, y)
		end

		cr:set_line_width(2)
		cr:stroke()

		-- Desenha rótulos no centro de cada célula
		cr:select_font_face("Sans", cairo_lgi.FontSlant.NORMAL, cairo_lgi.FontWeight.BOLD)
		cr:set_font_size(180)
		cr:set_source_rgba(1, 1, 0, 0.3) -- cor do texto

		for row = 1, NUM_ROWS do
			for col = 1, NUM_COLS do
				local cx = (col - 1) * cell_width + (cell_width / 2)
				local cy = (row - 1) * cell_height + (cell_height / 2)

				-- Obtém a letra da célula correspondente, se existir
				local text = ""
				if teleport_keys[row] and teleport_keys[row][col] then
					text = teleport_keys[row][col]:gsub("^%l", string.upper)
				end

				local extents = cr:text_extents(text)
				local text_x = cx - (extents.width / 2 + extents.x_bearing)
				local text_y = cy - (extents.height / 2 + extents.y_bearing)

				cr:move_to(text_x, text_y)
				cr:show_text(text)
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

-------------------- Teleporte do Cursor --------------------

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

-- Nova função para mover o cursor e clicar
local function toggle_cursor_mode_with_click()
	cursor_mode_active = not cursor_mode_active

	toggle_grid()

	if cursor_mode_active then
		naughty.notify({ title = "Cursor Mode", text = "Ativado (com clique)." })
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
				-- Simulando um clique do mouse após mover o cursor
				awful.util.spawn_with_shell("xdotool click 1")
				toggle_cursor_mode_with_click()
			end
		end)
	else
		naughty.notify({ title = "Cursor Mode", text = "Desativado." })
		if keygrabber then
			awful.keygrabber.stop(keygrabber)
		end
	end
end

-- Bind globals para ativar os modos de cursor
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
		{ description = "Ativar modo de controle do cursor com clique", group = "custom" }
	)
)

root.keys(globalkeys)
return {}
