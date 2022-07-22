local colors = require("nvim-highlight-colors.colors")

local M = {}

function M.print_table(node)
    local cache, stack, output = {},{},{}
    local depth = 1
    local output_str = "{\n"

    while true do
        local size = 0
        for k,v in pairs(node) do
            size = size + 1
        end

        local cur_index = 1
        for k,v in pairs(node) do
            if (cache[node] == nil) or (cur_index >= cache[node]) then

                if (string.find(output_str,"}",output_str:len())) then
                    output_str = output_str .. ",\n"
                elseif not (string.find(output_str,"\n",output_str:len())) then
                    output_str = output_str .. "\n"
                end

                -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
                table.insert(output,output_str)
                output_str = ""

                local key
                if (type(k) == "number" or type(k) == "boolean") then
                    key = "["..tostring(k).."]"
                else
                    key = "['"..tostring(k).."']"
                end

                if (type(v) == "number" or type(v) == "boolean") then
                    output_str = output_str .. string.rep('\t',depth) .. key .. " = "..tostring(v)
                elseif (type(v) == "table") then
                    output_str = output_str .. string.rep('\t',depth) .. key .. " = {\n"
                    table.insert(stack,node)
                    table.insert(stack,v)
                    cache[node] = cur_index+1
                    break
                else
                    output_str = output_str .. string.rep('\t',depth) .. key .. " = '"..tostring(v).."'"
                end

                if (cur_index == size) then
                    output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
                else
                    output_str = output_str .. ","
                end
            else
                -- close the table
                if (cur_index == size) then
                    output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
                end
            end

            cur_index = cur_index + 1
        end

        if (size == 0) then
            output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
        end

        if (#stack > 0) then
            node = stack[#stack]
            stack[#stack] = nil
            depth = cache[node] == nil and depth + 1 or depth - 1
        else
            break
        end
    end

    -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
    table.insert(output,output_str)
    output_str = table.concat(output)

    print(output_str)
end


function M.table_find(table_param, fun)
	for index, value in pairs(table_param) do
		local assertion = fun(value)
		if assertion then
			return value
		end
	end

	return nil
end

function M.table_filter(table_param, fun)
	local results = {}
	for index, value in pairs(table_param) do
		local assertion = fun(value)
		if assertion then
			table.insert(results, value)
		end
	end

	return results
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

function M.get_positions_by_regex(patterns, min_row, max_row, col_offset)
	local positions = {}
	local content = M.get_buffer_contents(min_row, max_row)

	for key_pattern, pattern in ipairs(patterns) do
		for row, value in ipairs(content) do
			for match in string.gmatch(value, pattern) do
				local start_column = vim.fn.match(value, match)
				local end_column = vim.fn.matchend(value, match)
					local same_row_colors = M.table_filter(positions, function(position) return position.row == row end)
					table.insert(positions, {
						value = match,
						row = row,
						display_column = #same_row_colors + col_offset,
						start_column = start_column,
						end_column = end_column
					})
			end
		end
	end

	return positions
end

function M.create_window(row, col, col_offset, bg_color)
	local highlight_color_name = string.gsub(bg_color, "#", ""):gsub("[(),%s%.]+", "")
	local row_content = M.get_buffer_contents(row, row + 1)
	local buf = vim.api.nvim_create_buf(false, true)
	local col_position_on_buffer = col == 0 and 1 or col + 1 - col_offset
	vim.api.nvim_buf_set_lines(buf, 0, 0, true, {string.sub(row_content[1], col_position_on_buffer, col_position_on_buffer)})
	local window = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		row = row,
		col = col,
		width = 1,
		height = 1,
		focusable = false,
		zindex = 1,
		style= "minimal"
	})
	vim.api.nvim_command("highlight " .. highlight_color_name .. " guibg=" .. colors.get_color_value(bg_color))
	vim.api.nvim_win_set_option(window, 'winhighlight', 'Normal:' .. highlight_color_name .. ',FloatBorder:' .. highlight_color_name)
	return window
end


function M.close_windows (windows)
	for index, data in pairs(windows) do
		if vim.api.nvim_win_is_valid(data) then
			vim.api.nvim_win_close(data, false)
		end
	end
end

return M
