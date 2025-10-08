local config = require("drunk-driver.config")

local M = {}

-- No type safety on this enum so only use this to set state
M.state_enum = {
    USER_INPUT = 0,
    AWAITING_RESPONSE = 1,
    THINKING = 2,
    RESPONSE = 3,
}

M.buffer = 0
M.state = M.state_enum.USER_INPUT
M.conversation = {}

M.thinking = {
    buffer = nil,
    window = -1,
    current_thought = -1,
    data = {},
}

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

M.save_conversation = function()
    vim.ui.input({ prompt = "Enter a name for the conversation: " }, function(input)
        if not input or input == "" then
            vim.notify("Dd: Conversation not saved. Name is required.", vim.log.levels.ERROR)
            return
        end
        M.save_state(input)
    end)
end

M.save_state = function(filename)
    local messages = vim.deepcopy(M.conversation)
    if messages[1] and messages[1].role == "system" then
        table.remove(messages, 1)
    end
    local saved = {
        messages = messages,
        thinking = M.thinking.data,
    }
    vim.json.encode(saved)
    local save_dir = vim.fn.getcwd() .. "/" .. config.save_directory_name
    if vim.fn.isdirectory(save_dir) == 0 then
        vim.fn.mkdir(save_dir)
        local gitignore = io.open(save_dir .. "/.gitignore", "w")
        if not gitignore then
            config.log_file:write(string.format("Failed to create .gitignore in %s\n", save_dir))
            return
        end
        gitignore:write("*\n")
        gitignore:close()
    end
    local date = os.date("%d-%m-%y")
    local filepath = string.format("%s/%s-%s.json", save_dir, date, filename)
    local file = io.open(filepath, "w")
    if file then
        file:write(vim.fn.json_encode(saved))
        file:close()
        config.log_file:write(string.format("Saved conversation to %s\n", filepath))
    else
        config.log_file:write(string.format("Failed to save conversation to %s\n", filepath))
    end
end

return M
