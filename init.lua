local awful = require("awful")
local gears = require("gears")
local naughty = require("naughty")
local wibox = require("wibox")
local cairo_lgi = require("lgi").cairo
local beautiful = require("beautiful")

local cursor_mode_active = false
local keygrabber

-- Tabela com as teclas para colunas e linhas
local teleport_col_keys = {
	"q",
	"w",
	"e",
	"r",
	"t",
	"y",
	"u",
	"i",
	"o",
	"p",
}

local teleport_row_keys = {
	"a",
	"s",
	"d",
	"f",
	"g",
	"h",
	"j",
	"k",
	"l",
	"~",
}

-- Define NUM_ROWS e NUM_COLS com base nos tamanhos das tabelas
local NUM_ROWS = #teleport_row_keys
local NUM_COLS = #teleport_col_keys

-- Teclas para o grid preciso (apenas uma tecla por área)
local teleport_precise_keys = {
	"q",
	"w",
	"e",
	"r",
	"t",
	"a",
	"s",
	"d",
	"f",
	"g",
	"y",
	"u",
	"i",
	"o",
	"p",
	"h",
	"j",
	"k",
	"l",
	"~",
}

local NUM_ROWS_PRECISE = 4
local NUM_COLS_PRECISE = 5

-- Gera todos os pares possíveis (uma tecla de linha e uma tecla de coluna)
local all_pairs = {}
for _, row_key in ipairs(teleport_row_keys) do
	for _, col_key in ipairs(teleport_col_keys) do
		table.insert(all_pairs, col_key .. row_key)
	end
end

-- Definimos area_pairs diretamente como all_pairs, já que são todos os pares possíveis
local area_pairs = all_pairs

-- Cria um mapeamento de cada par para sua posição na grade (linha e coluna)
local pair_to_cell = {}
for i, pair in ipairs(area_pairs) do
	local row = math.floor((i - 1) / NUM_COLS) + 1
	local col = ((i - 1) % NUM_COLS) + 1
	pair_to_cell[pair] = { row = row, col = col }
end

-- Cria um mapeamento para as teclas precisas
local precise_key_to_cell = {}
for i, key in ipairs(teleport_precise_keys) do
	if i <= NUM_ROWS_PRECISE * NUM_COLS_PRECISE then
		local row = math.floor((i - 1) / NUM_COLS_PRECISE) + 1
		local col = ((i - 1) % NUM_COLS_PRECISE) + 1
		precise_key_to_cell[key] = { row = row, col = col }
	end
end

-- Funções auxiliares para verificar se um caractere é uma tecla de linha ou coluna
local function is_row_key(key)
	for _, k in ipairs(teleport_row_keys) do
		if k == key then
			return true
		end
	end
	return false
end

local function is_col_key(key)
	for _, k in ipairs(teleport_col_keys) do
		if k == key then
			return true
		end
	end
	return false
end

-- Função para verificar se é uma tecla precisa
local function is_precise_key(key)
	for _, k in ipairs(teleport_precise_keys) do
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

-- Função para mover o cursor para a área identificada por uma única tecla (modo preciso)
local function move_cursor_to_precise_key(key, geom)
	local cell = precise_key_to_cell[key]
	if not cell then
		return false
	end
	local cell_width = geom.width / NUM_COLS_PRECISE
	local cell_height = geom.height / NUM_ROWS_PRECISE
	local x_offset = (cell.col - 1) * cell_width
	local y_offset = (cell.row - 1) * cell_height
	mouse.coords({
		x = geom.x + x_offset + (cell_width / 2),
		y = geom.y + y_offset + (cell_height / 2),
	})
	return true
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
				-- local alpha = ((row + col) % 2 == 0) and 0.1 or 0
				-- Alterna colunas
				local alpha = (col % 2 == 0) and 0.2 or 0
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
				local text = area_pairs[index] and string.upper(area_pairs[index]) or ""
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
-- A ação é executada somente após o segundo caractere válido ser pressionado.
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
				if is_row_key(key) or is_col_key(key) then
					first_key = key
				end
			else
				local pair = ""
				if is_col_key(first_key) and is_row_key(key) then
					pair = first_key .. key
				elseif is_row_key(first_key) and is_col_key(key) then
					pair = key .. first_key
				else
					naughty.notify({ title = "Erro", text = "Um caractere deve ser de linha e outro de coluna." })
					first_key = nil
					return
				end

				if pair_to_cell[pair] then
					move_cursor_to_pair(pair)
				else
					naughty.notify({ title = "Erro", text = "Par inválido: " .. pair })
				end
				first_key = nil
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

-- Modo de clique preciso: a grade precisa é exibida e a ação (clique) ocorre após UMA ÚNICA tecla
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
			local cell_width = width / NUM_COLS_PRECISE
			local cell_height = height / NUM_ROWS_PRECISE

			-- Preenche o fundo de cada célula com alpha alternado
			for row = 1, NUM_ROWS_PRECISE do
				for col = 1, NUM_COLS_PRECISE do
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
			for col = 0, NUM_COLS_PRECISE do
				local x = col * cell_width
				cr:move_to(x, 0)
				cr:line_to(x, height)
			end
			for row = 0, NUM_ROWS_PRECISE do
				local y = row * cell_height
				cr:move_to(0, y)
				cr:line_to(width, y)
			end
			cr:set_line_width(2)
			cr:stroke()

			cr:select_font_face("Sans", cairo_lgi.FontSlant.NORMAL, cairo_lgi.FontWeight.BOLD)
			cr:set_font_size(20)
			local fill_r, fill_g, fill_b, fill_a = 1, 1, 0, 0.8
			local outline_r, outline_g, outline_b, outline_a = 0, 0, 0, 1
			local outline_width = 3

			for row = 1, NUM_ROWS_PRECISE do
				for col = 1, NUM_COLS_PRECISE do
					local cx = (col - 1) * cell_width + (cell_width / 2)
					local cy = (row - 1) * cell_height + (cell_height / 2)
					local index = (row - 1) * NUM_COLS_PRECISE + col
					-- Usamos um único caractere da tabela teleport_precise_keys
					local text = index <= #teleport_precise_keys and string.upper(teleport_precise_keys[index]) or ""
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
			return
		end

		-- Agora usamos apenas uma tecla
		if is_precise_key(key) then
			local success =
				move_cursor_to_precise_key(key, { x = precise_x, y = precise_y, width = precise_w, height = precise_h })

			if success then
				awful.util.spawn_with_shell("xdotool click 1")
			else
				naughty.notify({ title = "Erro", text = "Tecla inválida: " .. key })
			end
		else
			naughty.notify({ title = "Erro", text = "Tecla não reconhecida: " .. key })
		end

		awful.keygrabber.stop(precise_keygrabber)
		precise_grid_wibox.visible = false
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
				if is_row_key(key) or is_col_key(key) then
					first_key = key
				end
			else
				local pair = ""
				if is_col_key(first_key) and is_row_key(key) then
					pair = first_key .. key
				elseif is_row_key(first_key) and is_col_key(key) then
					pair = key .. first_key
				else
					naughty.notify({ title = "Erro", text = "Coluna Linha!" })
					first_key = nil
					return
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
