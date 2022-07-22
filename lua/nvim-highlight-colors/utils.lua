local M = {}

M.rgb_regex = "rgba?[(]+" .. string.rep("%s*%d+%s*", 3, ",") ..",?%s*%d*%.?%d*%s*[)]+"

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

function M.get_color_value(color)
	if (M.is_short_hex_color(color)) then
		return M.convert_short_hex_to_hex(color)
	end

	if (M.is_rgb_color(color)) then
		local rgb_table = {}
		local count = 1
		for color_number in string.gmatch(color, "%d+") do
			rgb_table[count] = color_number
			count = count + 1
		end
		if (count >= 4) then
			return M.convert_rgb_to_hex(rgb_table[1], rgb_table[2], rgb_table[3])
		end
	end

	return color
end

function M.convert_rgb_to_hex(r, g, b)
 	return string.format("#%02X%02X%02X", r, g, b)
end

function M.is_short_hex_color(color)
	return string.len(color) == 4
end

function M.is_rgb_color(color)
	return string.match(color, M.rgb_regex)
end

function M.convert_short_hex_to_hex(color)
	if (M.is_short_hex_color(color)) then
		local new_color = "#"
		for char in color:gmatch"." do
			if (char ~= '#') then
				new_color = new_color .. char:rep(2)
			end
		end
		return new_color
	end

	return color
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

function M.get_positions_by_regex(patterns, min_row, max_row, row_offset)
	local positions = {}
	local content = M.get_buffer_contents(min_row, max_row)

	for key_pattern, pattern in pairs(patterns) do
		for key, value in pairs(content) do
			for match in string.gmatch(value, pattern) do
				local start_column = vim.fn.match(value, match)
				local end_column = vim.fn.matchend(value, match)
				local row = key + min_row - row_offset
				if (row >= 0) then
					local same_row_colors = M.table_filter(positions, function(position) return position.row == row end)
					M.print_table({same_row_colors = same_row_colors, #same_row_colors, row = row})
					table.insert(positions, {
						value = match,
						row = row,
						display_column = #same_row_colors,
						start_column = start_column,
						end_column = end_column
					})
				end
			end
		end
	end

	return positions
end

function M.create_window(row, col, bg_color)
	local highlight_color_name = string.gsub(bg_color, "#", ""):gsub("[(),%s%.]+", "")
	local buf = vim.api.nvim_create_buf(false, true)
	local window = vim.api.nvim_open_win(buf, false, {
		relative = "win",
		bufpos={row, col},
		width = 1,
		height = 1,
		focusable = false,
		noautocmd = true,
		zindex = 1,
		style= "minimal"
	})
	vim.api.nvim_command("highlight " .. highlight_color_name .. " guibg=" .. M.get_color_value(bg_color))
	vim.api.nvim_win_set_option(window, 'winhighlight', 'Normal:' .. highlight_color_name .. ',FloatBorder:' .. highlight_color_name)

	local row_content = M.get_buffer_contents(row + 1, row + 2)
	local col_position_on_buffer = col == 0 and 1 or col + 1
	vim.api.nvim_buf_set_lines(buf, 0, 0, true, {string.sub(row_content[1], col_position_on_buffer, col_position_on_buffer)})

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
