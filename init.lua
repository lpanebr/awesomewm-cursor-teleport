local awful = require("awful")
local gears = require("gears")
local naughty = require("naughty")
local wibox = require("wibox")
local cairo_lgi = require("lgi").cairo
local beautiful = require("beautiful")

local cursor_mode_active = false
local keygrabber

-- Tabela com os caracteres para cada mão (usada para formar os pares)
local teleport_keys_by_hand = {
	left_hand = {
		{ "q", "w", "e", "r", "t" },
		{ "a", "s", "d", "f", "g" },
	},
	right_hand = {
		{ "z", "x", "c", "v", "b" },
		{ "y", "u", "i", "o", "p" },
	},
}

-- Define NUM_ROWS e NUM_COLS fixos
local NUM_ROWS = 7
local NUM_COLS = 10

-- Obtém todos os caracteres de cada mão (mantendo a ordem desejada)
local left_keys = {}
for _, row in ipairs(teleport_keys_by_hand.left_hand) do
	for _, key in ipairs(row) do
		table.insert(left_keys, key)
	end
end

local right_keys = {}
for _, row in ipairs(teleport_keys_by_hand.right_hand) do
	for _, key in ipairs(row) do
		table.insert(right_keys, key)
	end
end

-- Gera todos os pares únicos (um da mão esquerda e um da mão direita)
local all_pairs = {}
for _, lkey in ipairs(left_keys) do
	for _, rkey in ipairs(right_keys) do
		table.insert(all_pairs, lkey .. rkey)
	end
end

-- Seleciona apenas os 60 primeiros pares para preencher a grade (NUM_ROWS * NUM_COLS)
local area_pairs = {}
for i = 1, NUM_ROWS * NUM_COLS do
	area_pairs[i] = all_pairs[i]
end

-- Cria um mapeamento de cada par para sua posição na grade (linha e coluna)
local pair_to_cell = {}
for i, pair in ipairs(area_pairs) do
	local row = math.floor((i - 1) / NUM_COLS) + 1
	local col = ((i - 1) % NUM_COLS) + 1
	pair_to_cell[pair] = { row = row, col = col }
end

-- Funções auxiliares para verificar se um caractere pertence a cada mão
local function is_left_key(key)
	for _, k in ipairs(left_keys) do
		if k == key then
			return true
		end
	end
	return false
end

local function is_right_key(key)
	for _, k in ipairs(right_keys) do
		if k == key then
			return true
		end
	end
	return false
end

-- Função para mover o cursor para a área identificada pelo par (modo geral)
local function move_cursor_to_pair(pair)
	local cell = pair_to_cell[pair]
	if not cell then
		return
	end
	local screen = awful.screen.focused()
	local g = screen.geometry
	local row_height = g.height / NUM_ROWS
	local col_width = g.width / NUM_COLS
	local x_offset = (cell.col - 1) * col_width
	local y_offset = (cell.row - 1) * row_height
	mouse.coords({
		x = g.x + x_offset + (col_width / 2),
		y = g.y + y_offset + (row_height / 2),
	})
end

-- Função para mover o cursor para a área identificada pelo par (modo preciso)
local function move_cursor_to_pair_precise(pair, geom)
	local cell = pair_to_cell[pair]
	if not cell then
		return
	end
	local cell_width = geom.width / NUM_COLS
	local cell_height = geom.height / NUM_ROWS
	local x_offset = (cell.col - 1) * cell_width
	local y_offset = (cell.row - 1) * cell_height
	mouse.coords({
		x = geom.x + x_offset + (cell_width / 2),
		y = geom.y + y_offset + (cell_height / 2),
	})
end

-- Cria a grade principal (wibox) e desenha as linhas e os rótulos com os pares
local grid_wibox = wibox({
	visible = false,
	ontop = true,
	type = "splash",
	x = 0,
	y = 0,
	width = awful.screen.focused().geometry.width,
	height = awful.screen.focused().geometry.height,
	bg = "#0000b044",
})

local grid_widget = wibox.widget({
	widget = wibox.widget.base.make_widget,
	fit = function(_, _, width, height)
		return width, height
	end,
	draw = function(_, _, cr, width, height)
		local cell_width = width / NUM_COLS
		local cell_height = height / NUM_ROWS

		-- Preenche o fundo de cada célula com alpha alternado (padrão tabuleiro de xadrez)
		for row = 1, NUM_ROWS do
			for col = 1, NUM_COLS do
				local x = (col - 1) * cell_width
				local y = (row - 1) * cell_height
				-- Alterna o alpha conforme a soma dos índices: par ou ímpar
				local alpha = ((row + col) % 2 == 0) and 0.1 or 0
				-- Cor base similar a "#0000b0" (azul)
				cr:set_source_rgba(0, 0, 0.69, alpha)
				cr:rectangle(x, y, cell_width, cell_height)
				cr:fill()
			end
		end

		-- Desenha as linhas da grade
		local gridline_r, gridline_g, gridline_b = 1, 1, 0
		local gridline_alpha = 0.1
		cr:set_source_rgba(gridline_r, gridline_g, gridline_b, gridline_alpha)
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

		-- Desenha os rótulos da grade (os pares)
		cr:select_font_face("Sans", cairo_lgi.FontSlant.NORMAL, cairo_lgi.FontWeight.BOLD)
		cr:set_font_size(180)
		local fill_r, fill_g, fill_b = 0.8, 0.8, 0
		local fill_alpha = 0.5
		local outline_r, outline_g, outline_b = 0, 0, 0
		local outline_alpha = 1
		local outline_width = 2

		for row = 1, NUM_ROWS do
			for col = 1, NUM_COLS do
				local cx = (col - 1) * cell_width + (cell_width / 2)
				local cy = (row - 1) * cell_height + (cell_height / 2)
				local index = (row - 1) * NUM_COLS + col
				local text = area_pairs[index] and area_pairs[index]:gsub("^%l", string.upper) or ""
				local extents = cr:text_extents(text)
				local text_x = cx - (extents.width / 2 + extents.x_bearing)
				local text_y = cy - (extents.height / 2 + extents.y_bearing)
				cr:move_to(text_x, text_y)
				cr:text_path(text)
				cr:set_source_rgba(outline_r, outline_g, outline_b, outline_alpha)
				cr:set_line_width(outline_width)
				cr:stroke_preserve()
				cr:set_source_rgba(fill_r, fill_g, fill_b, fill_alpha)
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

-- Modo de controle do cursor (sem clique preciso) com sequência de 2 teclas:
-- A ação é executada somente após o segundo caractere válido (de mãos diferentes) ser pressionado.
local function toggle_cursor_mode()
	cursor_mode_active = not cursor_mode_active
	toggle_grid()
	if cursor_mode_active then
		naughty.notify({ title = "Cursor Mode", text = "Ativado." })
		local first_key = nil
		keygrabber = awful.keygrabber.run(function(_, key, event)
			if event == "release" then
				return
			end
			if key == "dead_tilde" or key == "asciitilde" then
				key = "~"
			end
			if key == "Escape" then
				first_key = nil
				toggle_cursor_mode()
				return
			end
			if not first_key then
				if is_left_key(key) or is_right_key(key) then
					first_key = key
				end
			else
				if (is_left_key(first_key) and is_right_key(key)) or (is_right_key(first_key) and is_left_key(key)) then
					local pair = ""
					if is_left_key(first_key) then
						pair = first_key .. key
					else
						pair = key .. first_key
					end
					if pair_to_cell[pair] then
						move_cursor_to_pair(pair)
					else
						naughty.notify({ title = "Erro", text = "Par inválido: " .. pair })
					end
					first_key = nil
					toggle_cursor_mode()
				else
					naughty.notify({ title = "Erro", text = "Os caracteres devem ser de mãos diferentes." })
					first_key = nil
				end
			end
		end)
	else
		naughty.notify({ title = "Cursor Mode", text = "Desativado." })
		if keygrabber then
			awful.keygrabber.stop(keygrabber)
		end
	end
end

-- Modo de clique preciso: a grade precisa é exibida e a ação (clique) ocorre após a sequência válida de 2 teclas.
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
		bg = "#0000b000",
	})

	local precise_grid_widget = wibox.widget({
		widget = wibox.widget.base.make_widget,
		fit = function(_, _, width, height)
			return width, height
		end,
		draw = function(_, _, cr, width, height)
			local cell_width = width / NUM_COLS
			local cell_height = height / NUM_ROWS

			-- Preenche o fundo de cada célula com alpha alternado
			for row = 1, NUM_ROWS do
				for col = 1, NUM_COLS do
					local x = (col - 1) * cell_width
					local y = (row - 1) * cell_height
					local alpha = ((row + col) % 2 == 0) and 0.1 or 0.2
					cr:set_source_rgba(0, 0, 0.69, alpha)
					cr:rectangle(x, y, cell_width, cell_height)
					cr:fill()
				end
			end

			-- Desenha as linhas da grade
			local gridline_r, gridline_g, gridline_b = 1, 1, 0
			local gridline_alpha = 0.1
			cr:set_source_rgba(gridline_r, gridline_g, gridline_b, gridline_alpha)
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

			cr:select_font_face("Sans", cairo_lgi.FontSlant.NORMAL, cairo_lgi.FontWeight.BOLD)
			cr:set_font_size(25)
			local fill_r, fill_g, fill_b, fill_a = 1, 1, 0, 0.8
			local outline_r, outline_g, outline_b, outline_a = 0, 0, 0, 1
			local outline_width = 1

			for row = 1, NUM_ROWS do
				for col = 1, NUM_COLS do
					local cx = (col - 1) * cell_width + (cell_width / 2)
					local cy = (row - 1) * cell_height + (cell_height / 2)
					local index = (row - 1) * NUM_COLS + col
					local text = area_pairs[index] and area_pairs[index]:gsub("^%l", string.upper) or ""
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

	local precise_first_key = nil
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
			return
		end
		if not precise_first_key then
			if is_left_key(key) or is_right_key(key) then
				precise_first_key = key
			end
		else
			if
				(is_left_key(precise_first_key) and is_right_key(key))
				or (is_right_key(precise_first_key) and is_left_key(key))
			then
				local pair = ""
				if is_left_key(precise_first_key) then
					pair = precise_first_key .. key
				else
					pair = key .. precise_first_key
				end
				if pair_to_cell[pair] then
					move_cursor_to_pair_precise(
						pair,
						{ x = precise_x, y = precise_y, width = precise_w, height = precise_h }
					)
					awful.util.spawn_with_shell("xdotool click 1")
				else
					naughty.notify({ title = "Erro", text = "Par inválido: " .. pair })
				end
				precise_first_key = nil
				awful.keygrabber.stop(precise_keygrabber)
				precise_grid_wibox.visible = false
			else
				naughty.notify({ title = "Erro", text = "Os caracteres devem ser de mãos diferentes." })
				precise_first_key = nil
			end
		end
	end)
end

local function toggle_cursor_mode_with_click()
	cursor_mode_active = not cursor_mode_active
	toggle_grid()
	if cursor_mode_active then
		naughty.notify({ title = "Cursor Mode", text = "Ativado (com clique preciso)." })
		local first_key = nil
		keygrabber = awful.keygrabber.run(function(_, key, event)
			if event == "release" then
				return
			end
			if key == "dead_tilde" or key == "asciitilde" then
				key = "~"
			end
			if key == "Escape" then
				first_key = nil
				toggle_cursor_mode_with_click()
				return
			end
			if not first_key then
				if is_left_key(key) or is_right_key(key) then
					first_key = key
				end
			else
				if (is_left_key(first_key) and is_right_key(key)) or (is_right_key(first_key) and is_left_key(key)) then
					local pair = ""
					if is_left_key(first_key) then
						pair = first_key .. key
					else
						pair = key .. first_key
					end
					if pair_to_cell[pair] then
						move_cursor_to_pair(pair)
					else
						naughty.notify({ title = "Erro", text = "Par inválido: " .. pair })
					end
					first_key = nil
					toggle_grid()
					awful.keygrabber.stop(keygrabber)
					cursor_mode_active = false
					start_precise_click_mode()
				else
					naughty.notify({ title = "Erro", text = "Os caracteres devem ser de mãos diferentes." })
					first_key = nil
				end
			end
		end)
	else
		naughty.notify({ title = "Cursor Mode", text = "Desativado." })
		if keygrabber then
			awful.keygrabber.stop(keygrabber)
		end
	end
end

-- Bindings globais
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
