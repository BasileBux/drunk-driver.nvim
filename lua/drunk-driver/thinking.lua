local state = require("drunk-driver.state")
local config = require("drunk-driver.config")
local buffer = require("drunk-driver.buffer")

local M = {}

local hide = function()
    vim.api.nvim_win_close(state.thinking.window, true)
end

local show = function()
    state.thinking.window = vim.api.nvim_open_win(state.thinking.buffer, true, {
        relative = "cursor",
        width = 90,
        height = 24,
        col = 0,
        row = 0,
        anchor = "NW",
        style = "minimal",
        border = "rounded",
    })
    vim.api.nvim_set_option_value("wrap", true, { win = state.thinking.window })
end

vim.api.nvim_create_augroup("DrunkDriverThinking", { clear = true })
vim.api.nvim_create_autocmd("WinLeave", {
    group = "DrunkDriverThinking",
    buffer = state.thinking.buffer,
    callback = function()
        state.thinking.current_thought = -1
        if vim.api.nvim_win_is_valid(state.thinking.window) then
            hide()
        end
    end,
})

M.fill_buffer = function(index)
    local lines = {}
    local text = state.thinking.data[index] or "Error: No data"
    for l in text:gmatch("[^\n]+") do
        table.insert(lines, l)
    end
    vim.api.nvim_set_option_value("modifiable", true, { buf = state.thinking.buffer })
    vim.api.nvim_buf_set_lines(state.thinking.buffer, 0, -1, true, lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = state.thinking.buffer })
    show()
end

M.open = function()
    local line = vim.api.nvim_get_current_line()
    if line:find(config.thinking.marker_regex) then
        local subbed_line = line:gsub(config.thinking.marker_regex .. " ", "")
        local index = tonumber(subbed_line, 10)
        if not index then
            config.log_file:write("Error: No index found in subbed_line: " .. subbed_line .. "\n")
            return
        end
        M.fill_buffer(index)
        state.thinking.current_thought = index -- This MUST be set after fill_buffer (callback will set to -1)
    end
end

M.new = function()
    local index = #state.thinking.data + 1
    state.thinking.data[index] = ""
    buffer.add_thinking_marker(index)
    return index
end

M.setup = function()
    state.thinking.buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("modifiable", false, { buf = state.thinking.buffer })
end

return M
