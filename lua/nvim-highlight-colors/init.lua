local utils = require("nvim-highlight-colors.utils")
local colors = require("nvim-highlight-colors.colors")

local load_on_start_up = false
is_tab_mode = false
local windows = {}

function get_column_offset()
	local sign_column_value = vim.api.nvim_get_option_value('signcolumn', {})
	if sign_column_value == 'yes' then
		return 6
	end

	return 4
end

function is_window_already_created(row, value, display_column, min_row)
	for index, window_data in ipairs(windows) do
		local window_position = vim.api.nvim_win_get_position(window_data.win_id)
		local window_row = window_position[1]
		if window_row == row  and value == window_data.color and window_data.display_column == display_column then
			return true
		end
	end

	return false
end

function close_windows()
	local ids = {}
	for index, window_data in ipairs(windows) do
		table.insert(ids, window_data.win_id)
	end
	utils.close_windows(ids)
	windows = {}
end

function scroll_visible_windows(min_row)
	for index, window_data in ipairs(windows) do
		local window_position = vim.api.nvim_win_get_position(window_data.win_id)
		local window_row = window_position[1]
		local window_column = window_position[2]
		vim.api.nvim_win_set_config(
			window_data.win_id,
			{
				relative = "editor",
				row = window_data.row - (min_row - window_data.min_row),
				col = window_column
			}
		)
	end
end

function close_not_visible_windows(min_row, max_row)
	local windows_to_remove = {}
	local new_windows_table = {}
	for index, window_data in ipairs(windows) do
		local tab_offset = is_tab_mode and 1 or 0
		local is_visible = window_data.row + window_data.min_row <= max_row and window_data.row + window_data.min_row - tab_offset >= min_row
		if is_visible == false then
			table.insert(windows_to_remove, window_data.win_id)
		else
			table.insert(new_windows_table, window_data)
		end
	end
	utils.close_windows(windows_to_remove)
	windows = new_windows_table
end

function show_visible_windows(min_row, max_row)
	local column_offset = get_column_offset()
	local positions = utils.get_positions_by_regex(
		{
			colors.hex_regex,
			colors.rgb_regex
		},
		min_row,
		max_row,
		column_offset,
		is_tab_mode
	)
	for index, data in pairs(positions) do
		if is_window_already_created(data.row, data.value, data.display_column, min_row) == false then
			table.insert(
				windows,
				{
					win_id = utils.create_window(data.row, data.display_column, column_offset, min_row, data.value, is_tab_mode),
					row = data.row,
					min_row = min_row,
					display_column = data.display_column,
					color = data.value
				}
			)
		end
	end
end

function update_windows_visibility()
	local visible_rows = utils.get_win_visible_rows(0)
	local min_row = visible_rows[1]
	local max_row = visible_rows[2]

	scroll_visible_windows(min_row)
	show_visible_windows(min_row, max_row)
	close_not_visible_windows(min_row, max_row)
end

function turn_on()
	close_windows()
	local visible_rows = utils.get_win_visible_rows(0)
	local min_row = visible_rows[1]
	local max_row = visible_rows[2]
	show_visible_windows(min_row, max_row)
end

function turn_off()
	close_windows()
end

function setup()
	load_on_start_up = true
end

vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI", "TextChangedP", "VimResized"}, {
	callback = turn_on,
})

vim.api.nvim_create_autocmd({"WinScrolled"}, {
	callback = update_windows_visibility,
})

vim.api.nvim_create_autocmd({"BufEnter"}, {
	callback = function ()
		if load_on_start_up == true then
			turn_on()
		end
	end,
})

vim.api.nvim_create_autocmd({"TabEnter"}, {
	callback = function ()
		is_tab_mode = true
		update_windows_visibility()
	end,
})

vim.api.nvim_create_autocmd({"TabClosed"}, {
	callback = function ()
		is_tab_mode = false
		turn_off()
	end,
})

local M = {}

M.turnOff = turn_off
M.turnOn = turn_on
M.setup = setup

return M
