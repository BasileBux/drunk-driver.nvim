local state = require("drunk-driver.state")

local M = {}

local function reduce_whitespace(lines)
    local result = {}
    for _, line in ipairs(lines) do
        if line:match("%S") then
            table.insert(result, line)
        end
    end
    return result
end

M.parse_prompt = function()
    local lines = vim.api.nvim_buf_get_lines(state.buffer, 0, -1, false)
    for i = #lines, 1, -1 do
        if lines[i]:match("^# Me") then
            return table.concat(reduce_whitespace(vim.list_slice(lines, i + 1)), "\n")
        end
    end
    return ""
end

M.print_stream = function(content)
    vim.schedule(function()
        local new_lines = vim.split(content, "\n")
        local lines = vim.api.nvim_buf_get_lines(state.buffer, 0, -1, false)
        if #lines == 0 and #new_lines > 0 then
            lines = new_lines
        else
            if #new_lines > 0 then
                if #lines > 0 then
                    lines[#lines] = lines[#lines] .. new_lines[1]
                    table.remove(new_lines, 1)
                end
                for _, nl in ipairs(new_lines) do
                    table.insert(lines, nl)
                end
            end
        end
        vim.api.nvim_set_option_value("modifiable", true, { buf = state.buffer })
        vim.api.nvim_buf_set_lines(state.buffer, 0, -1, false, lines)
        vim.api.nvim_set_option_value("modifiable", false, { buf = state.buffer })
    end)
end

M.add_assistant_header = function()
    vim.api.nvim_buf_set_lines(state.buffer, -1, -1, false, { "", "# Drunk Driver", "", "" })
end

M.add_user_header = function()
    vim.schedule(function()
        vim.api.nvim_set_option_value("modifiable", true, { buf = state.buffer })
        vim.api.nvim_buf_set_lines(state.buffer, -1, -1, false, { "", "# Me", "", "" })
    end)
end

M.create_buffer = function()
    local buf = vim.api.nvim_create_buf(false, true)
    state.set_buffer(buf)
    state.init()

    vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
    vim.api.nvim_set_option_value("filetype", "drunkdriver", { buf = buf })
    vim.treesitter.language.register("markdown", "drunkdriver")
    vim.api.nvim_buf_set_name(buf, "drunkdriver")
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "# Me", "" })
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_win_set_cursor(0, { 3, 0 })

    return buf
end

M.setup_keymaps = function(buf, send_request_fn)
    vim.api.nvim_buf_set_keymap(buf, "n", "<C-CR>", "", {
        noremap = true,
        silent = true,
        callback = send_request_fn,
    })
    vim.api.nvim_buf_set_keymap(buf, "i", "<C-CR>", "", {
        noremap = true,
        silent = true,
        callback = send_request_fn,
    })
end

return M
