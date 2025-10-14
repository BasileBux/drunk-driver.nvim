local config = require("drunk-driver.config")
local buffer = require("drunk-driver.buffer")
local tools = require("drunk-driver.tools")

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

M.create_buffer = function()
    local buf = vim.api.nvim_create_buf(false, true)
    M.set_buffer(buf)
    M.init()
    vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
    vim.api.nvim_set_option_value("filetype", "drunkdriver", { buf = buf })
    vim.api.nvim_buf_set_name(buf, "drunkdriver")
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "# Me", "" })
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    vim.api.nvim_set_option_value("wrap", true, { win = 0 })
    return buf
end

-- NOTE: keep this function but don't add directly to conversation
-- add to some new tool call list instead and reference the index of
-- the assistant message which did the tool calls
M.add_tool_call = function(tool_call)
    local args = vim.json.decode(tool_call["function"].arguments)
    table.insert(M.conversation, {
        role = "tool",
        tool_call_id = tool_call.id,
        name = tool_call["function"].name,
        content = vim.json.encode({
            args = args,
            result = tools[tool_call["function"].name].run(tool_call),
        }),
    })
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

-- NOTE: this has to go. 
M.add_assistant_message_with_tools = function(content, tool_calls)
    local provider_config = config.get_current_provider_config()
    table.insert(M.conversation, {
        role = provider_config.roles.llm,
        content = content,
        tool_calls = tool_calls,
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

M.load_conversation = function()
    if vim.bo.filetype ~= "drunkdriver" then
        vim.notify("This command can only be used in drunkdriver", vim.log.levels.ERROR)
        return
    end

    local save_dir = vim.fn.getcwd() .. "/" .. config.save_directory_name
    if vim.fn.isdirectory(save_dir) == 0 then
        vim.notify("No codecompanion directory found", vim.log.levels.ERROR)
        return
    end

    local files = vim.fn.globpath(save_dir, "*.json", false, true)
    if #files == 0 then
        vim.notify("No saved chats found", vim.log.levels.ERROR)
        return
    end

    local file_info = {}
    for _, file in ipairs(files) do
        local filename = vim.fn.fnamemodify(file, ":t")
        -- Extract date and title
        local date_str, title = filename:match("^(%d+%-%d+%-%d+)%-(.+)%.json$")
        if date_str and title then
            table.insert(file_info, {
                filename = filename,
                date_str = date_str,
                title = title:gsub("-", "("),
                full_path = file,
            })
        end
    end

    table.sort(file_info, function(a, b)
        return a.date_str > b.date_str
    end)

    local formatted_items = {}
    local file_lookup = {}
    for _, info in ipairs(file_info) do
        local display_text = string.format(
            "%s - %s",
            os.date("%d/%m/%y", tonumber(info.date_str:match("(%d%d)(%d%d)(%d%d)"))),
            info.title
        )
        table.insert(formatted_items, display_text)
        file_lookup[display_text] = info.full_path
    end

    vim.ui.select(formatted_items, {
        prompt = "Select chat to load:",
        format_item = function(item)
            return item
        end,
    }, function(choice)
        if choice then
            local filepath = file_lookup[choice]
            M.load_state(filepath)
        end
    end)
end

M.load_state = function(filepath)
    local file = io.open(filepath, "r")
    if not file then
        config.log_file:write("Dd: Failed to load conversation from " .. filepath, vim.log.levels.ERROR)
        return
    end
    local content = file:read("*a")
    file:close()
    local ok, data = pcall(vim.fn.json_decode, content)
    if not ok then
        config.log_file:write("Dd: Failed to parse conversation from " .. filepath, vim.log.levels.ERROR)
        return
    end
    if data.messages then
        M.conversation = {}
        table.insert(M.conversation, {
            role = "system",
            content = config.system_prompt,
        })
        for _, msg in ipairs(data.messages) do
            table.insert(M.conversation, msg)
        end
    end
    if data.thinking then
        M.thinking.data = {}
        M.thinking.data = data.thinking
    end

    if M.buffer and vim.api.nvim_buf_is_valid(M.buffer) then
        vim.api.nvim_buf_set_lines(M.buffer, 0, -1, false, { config.display_names.user, "", "" })
        for i, msg in ipairs(M.conversation) do
            if i ~= 2 and msg.role == "user" then
                buffer.print_stream("\n", M.buffer)
                buffer.add_user_header(M.buffer)
            elseif msg.role == "assistant" then
                buffer.add_assistant_header(M.buffer)
                vim.api.nvim_set_option_value("modifiable", true, { buf = M.buffer })
                buffer.print_stream("\n", M.buffer)
            elseif msg.role == "system" then
                goto continue -- We have continue at home
            end
            buffer.print_stream(msg.content, M.buffer)
            vim.api.nvim_set_option_value("modifiable", true, { buf = M.buffer })
            ::continue::
        end
        buffer.print_stream("\n", M.buffer)
        buffer.add_user_header(M.buffer)
    end
end

return M
