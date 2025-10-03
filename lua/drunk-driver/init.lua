Curl = require("plenary.curl")

local M = {}

local moonshot_config = {
    api_key_name = "MOONSHOT_API_KEY",
    url = "https://api.moonshot.ai",
    chat_url = "/v1/chat/completions",
    models_endpoint = "/v1/models",
    default_model = "kimi-k2-0905-preview",
    roles = {
        llm = "assistant",
        user = "user",
    },
}

local openai_config = {
    api_key_name = "OPENAI_API_KEY",
    url = "https://api.openai.com",
    chat_url = "/v1/responses",
    models_endpoint = "/v1/models",
    default_model = "gpt-5",
    roles = {
        llm = "assistant",
        user = "user",
    },
}

local system_prompt = "You are an AI assistant in neovim called Drunk Driver."

local globals = {
    current_config = moonshot_config,
    buffer = 0,
    state = "user_input",

    conversation = {
        {
            role = "system",
            content = system_prompt,
        },
    },
}

local print_stream = function(content)
    vim.schedule(function()
        local new_lines = vim.split(content, "\n")
        local lines = vim.api.nvim_buf_get_lines(globals.buffer, 0, -1, false)
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
        vim.api.nvim_set_option_value("modifiable", true, { buf = globals.buffer })
        vim.api.nvim_buf_set_lines(globals.buffer, 0, -1, false, lines)
        vim.api.nvim_set_option_value("modifiable", false, { buf = globals.buffer })
    end)
end

local openai_make_request = function()
    local config = openai_config
    local headers = {
        ["Content-Type"] = "application/json",
        Authorization = "Bearer " .. os.getenv(config.api_key_name),
    }

    local body = {
        model = config.default_model,
        input = globals.conversation,
        stream = true,
    }

    local answer = ""
    vim.api.nvim_set_option_value("modifiable", true, { buf = globals.buf })
    require("plenary.curl").post(config.url .. config.chat_url, {
        headers = headers,
        body = vim.fn.json_encode(body),
        stream = function(_, chunk)
            if chunk then
                for line in chunk:gmatch("[^\n]+") do
                    if line:match("event: response.completed") then
                        table.insert(globals.conversation, {
                            role = globals.current_config.roles.llm,
                            content = answer,
                        })
                        globals.state = "user_input"
                        vim.schedule(function()
                            vim.api.nvim_set_option_value("modifiable", true, { buf = globals.buffer })
                            vim.api.nvim_buf_set_lines(globals.buffer, -1, -1, false, { "", "# Me", "", "" })
                        end)
                        return
                    end
                    if line:gmatch("^data:") then
                        local data = line:gsub("^data: ", "")
                        local ok, decoded = pcall(vim.json.decode, data)
                        if ok and decoded.delta then
                            local text = decoded.delta
                            if text then
                                answer = answer .. text
                                print_stream(text)
                            end
                        end
                    end
                end
            end
        end,
    })
end

local moonshot_make_request = function()
    local config = moonshot_config
    local headers = {
        ["Content-Type"] = "application/json",
        Authorization = "Bearer " .. os.getenv(config.api_key_name),
    }

    local body = {
        model = config.default_model,
        messages = globals.conversation,
        temperature = 0.7,
        stream = true,
    }

    local answer = ""
    vim.api.nvim_set_option_value("modifiable", true, { buf = globals.buf })
    require("plenary.curl").post(config.url .. config.chat_url, {
        headers = headers,
        body = vim.fn.json_encode(body),
        stream = function(_, chunk)
            if chunk then
                for line in chunk:gmatch("[^\n\r]+") do
                    local data = line:gsub("^data: ", "")
                    if data == "[DONE]" then
                        table.insert(globals.conversation, {
                            role = globals.current_config.roles.llm,
                            content = answer,
                        })
                        globals.state = "user_input"
                        vim.schedule(function()
                            vim.api.nvim_set_option_value("modifiable", true, { buf = globals.buffer })
                            vim.api.nvim_buf_set_lines(globals.buffer, -1, -1, false, { "", "# Me", "", "" })
                        end)
                        return
                    end
                    local ok, decoded = pcall(vim.json.decode, data)
                    if ok then
                        local text = decoded.choices[1].delta.content
                        if text then
                            answer = answer .. text
                            print_stream(text)
                        end
                    else
                        print("Failed to decode JSON:", data)
                    end
                end
            end
        end,
    })
end

local print_models = function()
    local config = openai_config
    local headers = {
        Authorization = "Bearer " .. os.getenv(config.api_key_name),
    }
    local response = Curl.get(config.url .. config.models_endpoint, {
        headers = headers,
    })
    if response.status == 200 then
        local body = vim.json.decode(response.body)
        print("Available Models:")
        for _, model in ipairs(body.data) do
            print(model.id .. "\n")
        end
    else
        print("Failed to fetch models. Status: " .. response.status)
    end
end

moonshot_config.request_handler = moonshot_make_request
openai_config.request_handler = openai_make_request
globals.model_handler = print_models

-- Remove empty lines which includes whitespace only lines
local reduce_whitespace = function(lines)
    local result = {}
    for _, line in ipairs(lines) do
        if line:match("%S") then
            table.insert(result, line)
        end
    end
    return result
end

local parse_prompt = function()
    local lines = vim.api.nvim_buf_get_lines(globals.buffer, 0, -1, false)
    for i = #lines, 1, -1 do
        if lines[i]:match("^# Me") then
            return table.concat(reduce_whitespace(vim.list_slice(lines, i + 1)), "\n")
        end
    end
end

M.send_request = function()
    local prompt = parse_prompt()
    if #prompt == 0 then
        print("Buffer is empty. Please enter a prompt.")
        return
    end
    table.insert(globals.conversation, { role = globals.current_config.roles.user, content = prompt })
    globals.state = "awaiting_response"
    vim.api.nvim_buf_set_lines(globals.buffer, -1, -1, false, { "", "# Drunk Driver", "", "" })
    globals.current_config.request_handler()
end

local drunk_driver = function()
    local buf = vim.api.nvim_create_buf(false, true)
    globals.buffer = buf
    vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
    vim.api.nvim_set_option_value("filetype", "drunkdriver", { buf = buf })
    vim.treesitter.language.register("markdown", "drunkdriver")
    vim.api.nvim_buf_set_name(buf, "drunkdriver")
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "# Me", "" })
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_win_set_cursor(0, { 3, 0 })

    vim.api.nvim_buf_set_keymap(
        buf,
        "n",
        "<C-CR>",
        "<cmd>lua require('drunk-driver').send_request()<CR>",
        { noremap = true, silent = true }
    )
    vim.api.nvim_buf_set_keymap(
        buf,
        "i",
        "<C-CR>",
        "<cmd>lua require('drunk-driver').send_request()<CR>",
        { noremap = true, silent = true }
    )
end

M.setup = function(opts)
    opts = opts or {}
    vim.tbl_deep_extend("force", {
        -- Default options set here
    }, opts)
    vim.api.nvim_create_user_command("Dd", drunk_driver, {})
end

return M
