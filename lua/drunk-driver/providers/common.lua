local Curl = require("plenary.curl")
local state = require("drunk-driver.state")
local buffer = require("drunk-driver.buffer")
local config = require("drunk-driver.config")

local M = {}

M.make_request = function(
    provider_config,
    body,
    tool_build_function,
    reasoning_handler,
    content_handler,
    tool_call_handler,
    end_marker,
    valid_block_condition
)
    local headers = provider_config.headers_function(provider_config)
    headers["Content-Type"] = "application/json"

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
                    -- End condition
                    if line == end_marker then
                        if not tool_calls[1] then
                            state.add_assistant_message(answer)
                            state.set_state(state.state_enum.USER_INPUT)
                            buffer.print_stream_scheduled("\n", state.buffer)
                            buffer.add_user_header_scheduled(state.buffer)
                            return
                        end
                        -- Store tool calls and make a new request
                        -- NOTE: needs rework for better compatibility like better formatting
                        state.add_assistant_message_with_tools(answer, tool_calls)
                        for _, tool_call in ipairs(tool_calls) do
                            state.add_tool_call(tool_call)
                        end
                        vim.schedule(function()
                            M.make_request(provider_config, tool_build_function)
                        end)
                        return
                    end
                    local data = line:gsub("^data: ", "")
                    local ok, decoded = pcall(vim.json.decode, data)

                    if ok and valid_block_condition(decoded) then
                        if reasoning_handler(decoded, answer, { value = thinking_index }) then
                            return
                        end
                        if content_handler(decoded, answer) then
                            return
                        end
                        if tool_call_handler(decoded, tool_calls) then
                            return
                        end
                    end
                end
            end
        end,
    })
end

return M
