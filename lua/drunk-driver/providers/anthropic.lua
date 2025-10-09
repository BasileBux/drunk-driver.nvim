local Curl = require("plenary.curl")
local config = require("drunk-driver.config")
local state = require("drunk-driver.state")
local buffer = require("drunk-driver.buffer")
local thinking = require("drunk-driver.thinking")

local M = {}

M.get_headers = function(provider_config)
    return {
        ["x-api-key"] = os.getenv(provider_config.api_key_name),
        ["anthropic-version"] = "2023-06-01",
    }
end

M.make_request = function()
    local provider_config = config.providers.anthropic
    local headers = M.get_headers(provider_config)
    headers["Content-Type"] = "application/json"

    -- Anthropic doesn't accept system messages in input. It takes it in the system
    -- part of the body.
    local messages = vim.deepcopy(state.conversation)
    local system_message = nil
    if messages[1] and messages[1].role == "system" then
        system_message = {
            type = "text",
            text = table.remove(messages, 1).content,
        }
    end

    local body = {
        model = provider_config.model,
        max_tokens = provider_config.max_tokens,
        system = { system_message },
        messages = messages,
        stream = true,
    }
    if provider_config.thinking.enabled then
        body.thinking = {
            type = "enabled",
            budget_tokens = provider_config.thinking.budget,
        }
    end

    local answer = ""
    local thinking_index = 0

    Curl.post(provider_config.url .. provider_config.chat_url, {
        headers = headers,
        body = vim.fn.json_encode(body),
        stream = function(_, chunk)
            if chunk then
                for line in chunk:gmatch("[^\n\r]+") do
                    if line:match("event: message_stop") then
                        state.add_assistant_message(answer)
                        state.set_state(state.state_enum.USER_INPUT)
                        buffer.print_stream_scheduled("\n", state.buffer)
                        buffer.add_user_header_scheduled(state.buffer)
                        return
                    end

                    if line:gmatch("^data:") then
                        local data = line:gsub("^data: ", "")
                        local ok, decoded = pcall(vim.json.decode, data)
                        if ok and decoded.delta then
                            if decoded.delta.thinking then
                                if state.state ~= state.state_enum.THINKING then
                                    state.set_state(state.state_enum.THINKING)
                                    thinking_index = thinking.new()
                                    answer = answer .. config.thinking.marker .. " " .. thinking_index .. "\n\n"
                                end
                                local text = decoded.delta.thinking
                                state.thinking.data[thinking_index] = state.thinking.data[thinking_index] .. text
                                if state.thinking.current_thought == thinking_index then
                                    buffer.print_stream_scheduled(text, state.thinking.buffer)
                                end
                            end
                            if decoded.delta.text then
                                if state.state ~= state.state_enum.RESPONSE then
                                    state.set_state(state.state_enum.RESPONSE)
                                    buffer.print_stream_scheduled("\n", state.buffer)
                                end
                                local text = decoded.delta.text
                                answer = answer .. text
                                buffer.print_stream_scheduled(text, state.buffer)
                            end
                        end
                    end
                end
            end
        end,
    })
end

return M
