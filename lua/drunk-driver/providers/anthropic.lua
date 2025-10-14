local config = require("drunk-driver.config")
local state = require("drunk-driver.state")
local buffer = require("drunk-driver.buffer")
local thinking = require("drunk-driver.thinking")
local common = require("drunk-driver.providers.common")

local M = {}

M.reasoning_function = function(opts)
    if opts.decoded.delta.thinking then
        if state.state ~= state.state_enum.THINKING then
            state.set_state(state.state_enum.THINKING)
            opts.thinking_index = thinking.new()
            opts.answer = opts.answer .. config.thinking.marker .. " " .. opts.thinking_index .. "\n\n"
        end
        local text = opts.decoded.delta.thinking
        state.thinking.data[opts.thinking_index] = state.thinking.data[opts.thinking_index] .. text
        if state.thinking.current_thought == opts.thinking_index then
            buffer.print_stream_scheduled(text, state.thinking.buffer)
        end
        return true
    end
    return false
end
M.content_function = function(opts)
    if opts.decoded.delta.text then
        if state.state ~= state.state_enum.RESPONSE then
            state.set_state(state.state_enum.RESPONSE)
            buffer.print_stream_scheduled("\n", state.buffer)
        end
        local text = opts.decoded.delta.text or ""
        opts.answer = opts.answer .. text
        buffer.print_stream_scheduled(text, state.buffer)
        return true
    end
    return false
end
M.tool_call_function = function(_) -- NOTE: not implemented
    return false
end
M.valid_block_condition = function(decoded)
    return decoded.delta
end

M.make_request = function()
    local provider_config = config.providers.anthropic
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
    local end_marker = "event: message_stop"
    common.make_request(
        provider_config,
        body,
        function() end,
        M.reasoning_function,
        M.content_function,
        M.tool_call_function,
        end_marker,
        M.valid_block_condition
    )
end

M.init = function() end

return M
