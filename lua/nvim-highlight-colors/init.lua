local utils = require("nvim-highlight-colors.utils")
local colors= require("nvim-highlight-colors.colors")

local load_on_start_up = false
local row_offset = 2

function clear_highlights()
	vim.api.nvim_buf_clear_namespace(0, -1, 0, utils.get_last_row_index())
end

function create_color_highlights(min_row, max_row)
	local positions = utils.get_positions_by_regex(
		{
			colors.hex_regex,
			colors.rgb_regex
		},
		min_row,
		max_row,
		row_offset
	)
	for _, data in pairs(positions) do
		utils.create_highlight_range(data.row, data.display_column, data.value)
	end
end

function turn_on()
	clear_highlights()
	create_color_highlights(0, utils.get_last_row_index())
end

function turn_off()
	clear_highlights()
end

function setup()
	load_on_start_up = true
end

vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI", "TextChangedP", "VimResized"}, {
       callback = turn_on,
})

vim.api.nvim_create_autocmd({"BufEnter"}, {
	callback = function ()
		if load_on_start_up == true then
			turn_on()
		end
	end,
})

local M = {}

M.turnOff = turn_off
M.turnOn = turn_on
M.setup = setup

return M
