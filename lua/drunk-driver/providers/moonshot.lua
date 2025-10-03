local Curl = require("plenary.curl")
local config = require("drunk-driver.config")
local state = require("drunk-driver.state")
local buffer = require("drunk-driver.buffer")

local M = {}

M.make_request = function()
    local provider_config = config.providers.moonshot
    local headers = {
        ["Content-Type"] = "application/json",
        Authorization = "Bearer " .. os.getenv(provider_config.api_key_name),
    }

    local body = {
        model = provider_config.default_model,
        messages = state.conversation,
        temperature = 0.7,
        stream = true,
    }

    local answer = ""
    vim.api.nvim_set_option_value("modifiable", true, { buf = state.buffer })

    Curl.post(provider_config.url .. provider_config.chat_url, {
        headers = headers,
        body = vim.fn.json_encode(body),
        stream = function(_, chunk)
            if chunk then
                for line in chunk:gmatch("[^\n\r]+") do
                    local data = line:gsub("^data: ", "")
                    if data == "[DONE]" then
                        state.add_assistant_message(answer)
                        state.set_state("user_input")
                        buffer.add_user_header()
                        return
                    end
                    local ok, decoded = pcall(vim.json.decode, data)
                    if ok and decoded.choices and decoded.choices[1].delta.content then
                        local text = decoded.choices[1].delta.content
                        if text then
                            answer = answer .. text
                            buffer.print_stream(text)
                        end
                    end
                end
            end
        end,
    })
end

return M
