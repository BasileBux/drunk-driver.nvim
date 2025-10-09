local config = require("drunk-driver.config")

M = {}

M.get_headers = function(provider_config)
    local version = vim.version()
    return {
        Authorization = "Bearer " .. os.getenv(provider_config.api_key_name),
        ["Content-Type"] = "application/json",
        ["Copilot-Integration-Id"] = "vscode-chat",
        ["Editor-Version"] = "Neovim/" .. version.major .. "." .. version.minor .. "." .. version.patch,
    }
end

-- Reference: https://github.com/olimorris/codecompanion.nvim/blob/1ac1adb7f72798621cc9931ddf0a341ab486d7d8/lua/codecompanion/adapters/http/copilot/token.lua

-- Copied from: https://github.com/olimorris/codecompanion.nvim/blob/1ac1adb7f72798621cc9931ddf0a341ab486d7d8/lua/codecompanion/adapters/http/copilot/token.lua#L51-L65
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

    return decoded.token
end

M.test = function()
    local token = get_copilot_token()
    if token then
        print("Copilot token retrieved successfully: " .. token)
    else
        print("Failed to retrieve Copilot token")
    end
end

return M
