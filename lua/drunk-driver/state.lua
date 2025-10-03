local config = require("drunk-driver.config")

local M = {}

M.buffer = 0
M.state = "user_input"
M.conversation = {}

M.init = function()
    M.conversation = {
        {
            role = "system",
            content = config.system_prompt,
        },
    }
end

M.add_user_message = function(content)
    local provider_config = config.get_current_provider_config()
    table.insert(M.conversation, {
        role = provider_config.roles.user,
        content = content,
    })
end

M.add_assistant_message = function(content)
    local provider_config = config.get_current_provider_config()
    table.insert(M.conversation, {
        role = provider_config.roles.llm,
        content = content,
    })
end

M.set_state = function(new_state)
    M.state = new_state
end

M.set_buffer = function(buffer)
    M.buffer = buffer
end

return M
