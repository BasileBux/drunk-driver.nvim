local state = require("drunk-driver.state")
local buffer = require("drunk-driver.buffer")
local config = require("drunk-driver.config")
local thinking = require("drunk-driver.thinking")

local M = {}

M.end_marker = "data: [DONE]"

M.reasoning_function = function(opts)
    if opts.decoded.choices and opts.decoded.choices[1].delta.reasoning_content then
        if state.state ~= state.state_enum.THINKING then
            state.set_state(state.state_enum.THINKING)
            opts.thinking_index = thinking.new()
            opts.answer = config.thinking.marker .. " " .. opts.thinking_index .. "\n\n"
        end
        local text = opts.decoded.choices[1].delta.reasoning_content
        state.thinking.data[opts.thinking_index] = state.thinking.data[opts.thinking_index] .. text
        if state.thinking.current_thought == opts.thinking_index then
            buffer.print_stream_scheduled(text, state.thinking.buffer)
        end
        return true
    end
    return false
end

M.content_function = function(opts)
    if opts.decoded.choices and opts.decoded.choices[1].delta.content then
        if state.state ~= state.state_enum.RESPONSE then
            state.set_state(state.state_enum.RESPONSE)
            buffer.print_stream_scheduled("\n", state.buffer)
        end
        local user_value = opts.decoded.choices[1].delta.content
        if user_value and user_value ~= vim.NIL then
            local text = tostring(user_value)
            opts.answer = opts.answer .. text
            buffer.print_stream_scheduled(text, state.buffer)
        end
        return true
    end
    return false
end

M.tool_call_function = function(opts)
    if opts.decoded.choices and opts.decoded.choices[1].delta.tool_calls then
        local tool_call_delta = opts.decoded.choices[1].delta.tool_calls[1]
        local tool_index = tool_call_delta.index + 1 -- Transform to 1 indexed
        if not opts.tool_calls[tool_index] then
            table.insert(opts.tool_calls, tool_index, {
                id = tool_call_delta.id,
                type = "function",
                ["function"] = {
                    name = tool_call_delta["function"].name,
                    arguments = tool_call_delta["function"].arguments,
                },
            })
        else
            opts.tool_calls[tool_index]["function"].arguments = opts.tool_calls[tool_index]["function"].arguments
                .. (tool_call_delta["function"].arguments)
        end
        return true
    end
    return false
end

return M
