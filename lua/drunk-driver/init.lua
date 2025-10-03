local config = require("drunk-driver.config")
local state = require("drunk-driver.state")
local buffer = require("drunk-driver.buffer")
local providers = require("drunk-driver.providers")

local M = {}

M.send_request = function()
    local prompt = buffer.parse_prompt()
    if #prompt == 0 then
        print("Buffer is empty. Please enter a prompt.")
        return
    end

    state.add_user_message(prompt)
    state.set_state("awaiting_response")

    buffer.add_assistant_header()

    local provider = providers.get_current_provider()
    provider.make_request()
end

local function create_chat_buffer()
    local buf = buffer.create_buffer()
    buffer.setup_keymaps(buf, M.send_request)
    return buf
end

M.setup = function(opts)
    opts = opts or {}
    config.setup(opts)
    vim.api.nvim_create_user_command("Dd", create_chat_buffer, {})
end

return M
