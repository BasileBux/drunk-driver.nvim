local config = require("drunk-driver.config")
local state = require("drunk-driver.state")
local buffer = require("drunk-driver.buffer")
local providers = require("drunk-driver.providers")
local thinking = require("drunk-driver.thinking")

local M = {}

M.send_request = function()
    local prompt = buffer.parse_prompt(state.buffer)
    if #prompt == 0 then
        print("Buffer is empty. Please enter a prompt.")
        return
    end

    state.add_user_message(prompt)
    state.set_state(state.state_enum.AWAITING_RESPONSE)

    buffer.add_assistant_header(state.buffer)

    local provider = providers.get_current_provider()
    provider.make_request()
end

M.hover_thinking = thinking.open
M.save_conversation = state.save_conversation
M.load_conversation = state.load_conversation

M.new_chat = function()
    local buf = state.create_buffer()
    buffer.setup_keymaps(buf, M.send_request, M.hover_thinking)
    thinking.setup()
    return buf
end

local subcommands = { "new", "show_thinking", "save", "load" }

local handlers = {
    new = M.new_chat,
    show_thinking = M.hover_thinking,
    save = M.save_conversation,
    load = M.load_conversation,
}

M.dd = function(opts)
    local sub = opts.fargs[1]
    if not sub or not handlers[sub] then
        vim.notify("Dd: missing / unknown sub-command", vim.log.levels.ERROR)
        return
    end
    handlers[sub]()
end

M.setup = function(opts)
    opts = opts or {}
    config.setup(opts)
    vim.treesitter.language.register("markdown", "drunkdriver")
    vim.api.nvim_create_user_command("Dd", M.dd, {
        nargs = "+",
        desc = "Dd sub-commands: " .. table.concat(subcommands, ", "),
        complete = function(ArgLead, CmdLine, CursorPos)
            local parts = vim.split(vim.trim(CmdLine), "%s+")
            if #parts <= 2 then
                return vim.tbl_filter(function(s)
                    return s:match("^" .. ArgLead)
                end, subcommands)
            end
        end,
    })
end

return M
