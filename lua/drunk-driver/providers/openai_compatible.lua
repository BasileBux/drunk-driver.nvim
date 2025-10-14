local Curl = require("plenary.curl")
local state = require("drunk-driver.state")
local buffer = require("drunk-driver.buffer")
local config = require("drunk-driver.config")
local thinking = require("drunk-driver.thinking")

local M = {}

M.make_request = function(provider_config, tool_build_function)
    local headers = provider_config.headers_function(provider_config)
    headers["Content-Type"] = "application/json"

    local body = {
        model = provider_config.model,
        messages = state.conversation,
        stream = true,
        max_tokens = provider_config.max_tokens,
        thinking = provider_config.thinking.enabled,
    }
    if provider_config.tools_enabled then
        body.tools = config.tools
    end

    local answer = ""
    local thinking_index = 0
    local tool_calls = {}
    config.log_file:write("Request body:\n" .. vim.json.encode(body) .. "\n\n")

    Curl.post(provider_config.url .. provider_config.chat_url, {
        headers = headers,
        body = vim.json.encode(body),
        stream = function(_, chunk)
            if chunk then
                config.log_file:write(chunk .. "\n\n")
                for line in chunk:gmatch("[^\n\r]+") do
                    local data = line:gsub("^data: ", "")
                    if data == "[DONE]" then
                        if not tool_calls[1] then
                            state.add_assistant_message(answer)
                            state.set_state(state.state_enum.USER_INPUT)
                            buffer.print_stream_scheduled("\n", state.buffer)
                            buffer.add_user_header_scheduled(state.buffer)
                            return
                        end
                        -- NOTE: tool calls here but really static
                        state.add_assistant_message_with_tools(answer, tool_calls)
                        for _, tool_call in ipairs(tool_calls) do
                            state.add_tool_call(tool_call)
                        end
                        vim.schedule(function()
                            M.make_request(provider_config, tool_build_function)
                        end)
                        return
                    end
                    local ok, decoded = pcall(vim.json.decode, data)

                    if ok and decoded.choices then
                        if decoded.choices[1].delta.reasoning_content then
                            if state.state ~= state.state_enum.THINKING then
                                state.set_state(state.state_enum.THINKING)
                                thinking_index = thinking.new()
                                answer = answer .. config.thinking.marker .. " " .. thinking_index .. "\n\n"
                            end
                            local text = decoded.choices[1].delta.reasoning_content
                            state.thinking.data[thinking_index] = state.thinking.data[thinking_index] .. text
                            if state.thinking.current_thought == thinking_index then
                                buffer.print_stream_scheduled(text, state.thinking.buffer)
                            end
                        elseif decoded.choices[1].delta.content then
                            if state.state ~= state.state_enum.RESPONSE then
                                state.set_state(state.state_enum.RESPONSE)
                                buffer.print_stream_scheduled("\n", state.buffer)
                            end
                            local user_value = decoded.choices[1].delta.content
                            if user_value and user_value ~= vim.NIL then
                                local text = tostring(user_value)
                                answer = answer .. text
                                buffer.print_stream_scheduled(text, state.buffer)
                            end
                            -- NOTE: tool calls here
                        elseif decoded.choices[1].delta.tool_calls then
                            local tool_call_delta = decoded.choices[1].delta.tool_calls[1]
                            local tool_index = tool_call_delta.index + 1 -- Transform to 1 indexed
                            if not tool_calls[tool_index] then
                                table.insert(tool_calls, tool_index, {
                                    id = tool_call_delta.id,
                                    type = "function",
                                    ["function"] = {
                                        name = tool_call_delta["function"].name,
                                        arguments = tool_call_delta["function"].arguments or "",
                                    },
                                })
                            else
                                tool_calls[tool_index]["function"].arguments = tool_calls[tool_index]["function"].arguments
                                    .. (tool_call_delta["function"].arguments or "")
                            end
                        end
                    end
                end
            end
        end,
    })
end

return M
