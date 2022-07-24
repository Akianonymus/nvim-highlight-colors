local colors = require("nvim-highlight-colors.colors")
local table_utils = require("nvim-highlight-colors.table_utils")

local M = {}

function M.get_last_row_index()
	return vim.fn.line('$')
end

function M.get_buffer_contents(min_row, max_row)
	return vim.api.nvim_buf_get_lines(0, min_row, max_row, false)
end

function M.get_win_visible_rows(winid)
	return vim.api.nvim_win_call(
		winid,
		function()
			return {
				vim.fn.line('w0'),
				vim.fn.line('w$')
			}
		end
	)
end

function M.get_positions_by_regex(patterns, min_row, max_row, row_offset)
	local positions = {}
	local content = M.get_buffer_contents(min_row, max_row)

	for _, pattern in pairs(patterns) do
		for key, value in pairs(content) do
			for match in string.gmatch(value, pattern) do
				local start_column = vim.fn.match(value, match)
				local end_column = vim.fn.matchend(value, match)
				local row = key + min_row - row_offset
				if (row >= 0) then
					table.insert(positions, {
						value = match,
						row = row,
						start_column = start_column,
						end_column = end_column
					})
				end
			end
		end
	end

	table.sort(positions, function (position1, position2) return position1.row == position2.row and position1.start_column < position2.start_column end)

	for _, position in ipairs(positions) do
		local same_row_colors = table_utils.filter(positions, function(pos) return pos.row == position.row end)
		local match_index = table_utils.find_index(same_row_colors, function (pos) return pos.row == position.row and pos.start_column == position.start_column end)
		position.display_column = match_index - 1
	end

	table_utils.print({positions})
	return positions
end

function M.create_highlight_range(row, col, bg_color)
	local highlight_color_name = string.gsub(bg_color, "#", ""):gsub("[(),%s%.]+", "")
	vim.api.nvim_command("highlight " .. highlight_color_name .. " guibg=" .. colors.get_color_value(bg_color))
	vim.api.nvim_buf_add_highlight(0, -1, highlight_color_name, row + 1, col, col + 1)
end


function M.close_windows (windows)
	for index, data in pairs(windows) do
		if vim.api.nvim_win_is_valid(data) then
			vim.api.nvim_win_close(data, false)
		end
	end
end

return M
