local config = require("drunk-driver.config")
local openai_compatible = require("drunk-driver.providers.openai_compatible")

M = {}

M.make_request = function()
    local provider_config = config.providers.copilot
    openai_compatible.make_request(provider_config)
end

-- Tool calls: old openai compatible way and can only perform one tool call at a time
-- "functions": [
--     {
--         "name": "get_weather",
--         "description": "Get weather for a city",
--         "parameters": {
--             "type": "object",
--             "properties": {
--                 "city": {"type": "string"}
--             },
--             "required": ["city"]
--           }
--     }
-- ],
-- Response: So basically creates the tool call and streams the arguments in a valid json string
-- data: {"choices":[{"index":0,"delta":{"content":null,"role":"assistant","function_call":{"arguments":"","name":"get_weather"}}}],"created":1760426016,"id":"chatcmpl-CQTVwI8fVyPBdujAF4qrwF4wNlkge","model":"gpt-4o-mini-2024-07-18","system_fingerprint":"fp_efad92c60b"}
-- data: {"choices":[{"index":0,"delta":{"content":null,"function_call":{"arguments":"{\""}}}],"created":1760426016,"id":"chatcmpl-CQTVwI8fVyPBdujAF4qrwF4wNlkge","model":"gpt-4o-mini-2024-07-18","system_fingerprint":"fp_efad92c60b"}
-- data: {"choices":[{"index":0,"delta":{"content":null,"function_call":{"arguments":"city"}}}],"created":1760426016,"id":"chatcmpl-CQTVwI8fVyPBdujAF4qrwF4wNlkge","model":"gpt-4o-mini-2024-07-18","system_fingerprint":"fp_efad92c60b"}
-- data: {"choices":[{"index":0,"delta":{"content":null,"function_call":{"arguments":"\":\""}}}],"created":1760426016,"id":"chatcmpl-CQTVwI8fVyPBdujAF4qrwF4wNlkge","model":"gpt-4o-mini-2024-07-18","system_fingerprint":"fp_efad92c60b"}
-- data: {"choices":[{"index":0,"delta":{"content":null,"function_call":{"arguments":"Paris"}}}],"created":1760426016,"id":"chatcmpl-CQTVwI8fVyPBdujAF4qrwF4wNlkge","model":"gpt-4o-mini-2024-07-18","system_fingerprint":"fp_efad92c60b"}
-- data: {"choices":[{"index":0,"delta":{"content":null,"function_call":{"arguments":"\"}"}}}],"created":1760426016,"id":"chatcmpl-CQTVwI8fVyPBdujAF4qrwF4wNlkge","model":"gpt-4o-mini-2024-07-18","system_fingerprint":"fp_efad92c60b"}
-- Add this to the conversation messages: It seems the assistant doesn't answer anything else than the tool call
-- "messages": [
--   {"role": "system", "content": "You are a helpful assistant."},
--   {"role": "user", "content": "What's the weather in Paris?"},
--   {"role": "assistant", "function_call": {"name": "get_weather", "arguments": "{\"city\":\"Paris\"}"}},
--   {"role": "function", "name": "get_weather", "content": "{\"temperature\": 15, \"condition\": \"cloudy\"}"}
-- ],

-- Cpilot api isn't documented anywhere and the best ways to learn is to look at
-- other implementations. I got all my knowledge and code from the following file:
-- https://github.com/olimorris/codecompanion.nvim/blob/1ac1adb7f72798621cc9931ddf0a341ab486d7d8/lua/codecompanion/adapters/http/copilot/token.lua
local get_config_path = function()
    local path = vim.fs.normalize("$XDG_CONFIG_HOME")

    if path and vim.fn.isdirectory(path) > 0 then
        return path
    elseif vim.fn.has("win32") > 0 then
        path = vim.fs.normalize("~/AppData/Local")
        if vim.fn.isdirectory(path) > 0 then
            return path
        end
    else
        path = vim.fs.normalize("~/.config")
        if vim.fn.isdirectory(path) > 0 then
            return path
        end
    end
end

local get_oauth_token = function()
    local config_path = get_config_path()
    if not config_path == nil then
        config.log_file:write("Could not find config path\n")
        return nil
    end

    local file_paths = {
        config_path .. "/github-copilot/hosts.json",
        config_path .. "/github-copilot/apps.json",
    }

    for _, file_path in ipairs(file_paths) do
        if vim.uv.fs_stat(file_path) then
            local file = io.open(file_path, "r")
            if not file then
                return nil
            end
            local userdata = file:read("*a")
            file:close()

            if vim.islist(userdata) then
                userdata = table.concat(userdata, " ")
            end

            userdata = vim.json.decode(userdata)
            for key, value in pairs(userdata) do
                if string.find(key, "github.com") then
                    return value.oauth_token
                end
            end
        end
    end
    return nil
end

local get_copilot_token = function()
    local oauth_token = get_oauth_token()
    if not oauth_token then
        config.log_file:write("Could not find oauth token\n")
        return nil
    end

    local ok, request = pcall(function()
        return Curl.get("https://api.github.com/copilot_internal/v2/token", {
            headers = {
                Authorization = "Bearer " .. (oauth_token or ""),
                Accept = "application/json",
                ["User-Agent"] = "DrunkDriver.nvim",
            },
            on_error = function(err)
                config.log_file:write("Copilot Adapter: Token request error %s\n", err)
            end,
        })
    end)

    if not ok or request == nil or request.body == nil then
        config.log_file:write("Copilot Adapter: Token request failed\n")
        return nil
    end

    local ok, decoded = pcall(vim.json.decode, request.body)
    if not ok or decoded == nil or decoded.token == nil then
        config.log_file:write("Copilot Adapter: Token decode failed\n")
        return nil
    end

    return decoded
end

local token_save_path = vim.fn.stdpath("data") .. "/dd_copilot_token.json"

M.validate_token = function()
    -- verify if token exists and is valid and if not regenerate one
    local token_file = io.open(token_save_path, "r")
    if token_file then
        local token_data = token_file:read("*a")
        token_file:close()
        if token_data and #token_data > 0 then
            local decoded = vim.json.decode(token_data)
            local buffer = 600 -- 10 minutes buffer
            if os.time() < (decoded.expires_at - buffer) then
                config.providers.copilot.token = decoded.token
                return
            end
        end
    end

    local token_data = get_copilot_token()
    if token_data then
        local token_file = io.open(token_save_path, "w")
        if token_file then
            token_file:write(vim.json.encode(token_data))
            token_file:close()
        end
        config.providers.copilot.token = token_data.token
    else
        print("Failed to retrieve Copilot token")
    end
end

M.init = function()
    M.validate_token()
end

return M
