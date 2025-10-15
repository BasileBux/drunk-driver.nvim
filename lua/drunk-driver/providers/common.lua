local Curl = require("plenary.curl")
local state = require("drunk-driver.state")
local buffer = require("drunk-driver.buffer")
local config = require("drunk-driver.config")

local M = {}

M.make_request = function(
    provider_config,
    body,
    request_function,
    reasoning_handler,
    content_handler,
    tool_call_handler,
    end_marker,
    valid_block_condition,
    add_tool_call_function
)
    local headers = provider_config.headers_function(provider_config)
    headers["Content-Type"] = "application/json"

    local opts = {
        answer = "",
        thinking_index = 0,
        tool_calls = {},
        tool_call_index = 0,
    }
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
                        if not opts.tool_calls[1] then
                            state.add_assistant_message(opts.answer)
                            state.set_state(state.state_enum.USER_INPUT)
                            buffer.print_stream_scheduled("\n", state.buffer)
                            buffer.add_user_header_scheduled(state.buffer)
                            return
                        end
                        table.insert(state.messages, {
                            role = provider_config.roles.llm,
                            content = opts.answer,
                        })
                        local solved_tool_calls = {}
                        for _, tool_call in ipairs(opts.tool_calls) do
                            table.insert(solved_tool_calls, state.add_tool_call(tool_call, #state.messages + 1))
                        end
                        add_tool_call_function(opts.answer, opts.tool_calls, solved_tool_calls)

                        vim.schedule(function()
                            request_function()
                        end)
                        return
                    end
                    local data = line:gsub("^data: ", "")
                    local ok, decoded = pcall(vim.json.decode, data)
                    opts.decoded = decoded

                    if ok and valid_block_condition(decoded) then
                        if reasoning_handler(opts) then
                            return
                        end
                        if content_handler(opts) then
                            return
                        end
                        if tool_call_handler(opts) then
                            return
                        end
                    end
                end
            end
        end,
    })
end

return M
