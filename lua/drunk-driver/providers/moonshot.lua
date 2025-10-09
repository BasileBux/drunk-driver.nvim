local Curl = require("plenary.curl")
local config = require("drunk-driver.config")
local state = require("drunk-driver.state")
local buffer = require("drunk-driver.buffer")

local M = {}

M.get_headers = function(provider_config)
    return {
        Authorization = "Bearer " .. os.getenv(provider_config.api_key_name),
    }
end

M.make_request = function()
    local provider_config = config.providers.moonshot
    local headers = M.get_headers(provider_config)
    headers["Content-Type"] = "application/json"

    local body = {
        model = provider_config.model,
        messages = state.conversation,
        -- temperature = 0.7,
        stream = true,
        max_tokens = provider_config.max_tokens,
    }

    local answer = ""

    Curl.post(provider_config.url .. provider_config.chat_url, {
        headers = headers,
        body = vim.fn.json_encode(body),
        stream = function(_, chunk)
            if chunk then
                for line in chunk:gmatch("[^\n\r]+") do
                    local data = line:gsub("^data: ", "")
                    if data == "[DONE]" then
                        state.add_assistant_message(answer)
                        state.set_state(state.state_enum.USER_INPUT)
                        buffer.print_stream_scheduled("\n", state.buffer)
                        buffer.add_user_header_scheduled(state.buffer)
                        return
                    end
                    local ok, decoded = pcall(vim.json.decode, data)
                    if ok and decoded.choices and decoded.choices[1].delta.content then
                        if state.state ~= state.state_enum.RESPONSE then
                            state.set_state(state.state_enum.RESPONSE)
                            buffer.print_stream_scheduled("\n", state.buffer)
                        end
                        local text = decoded.choices[1].delta.content
                        if text then
                            answer = answer .. text
                            buffer.print_stream_scheduled(text, state.buffer)
                        end
                    end
                end
            end
        end,
    })
end

return M
