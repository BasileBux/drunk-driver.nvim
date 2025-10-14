local config = require("drunk-driver.config")
local state = require("drunk-driver.state")
local buffer = require("drunk-driver.buffer")
local common = require("drunk-driver.providers.common")

local M = {}

M.reasoning_function = function(_)
    return false
end

M.content_function = function(opts)
    if opts.decoded.delta then
        if state.state ~= state.state_enum.RESPONSE then
            state.set_state(state.state_enum.RESPONSE)
            buffer.print_stream_scheduled("\n", state.buffer)
        end
        opts.answer = opts.answer .. opts.decoded.delta
        buffer.print_stream_scheduled(opts.decoded.delta, state.buffer)
    end
end

M.tool_call_function = function(_) -- NOTE: not implemented
    return false
end

M.valid_block_condition = function(decoded)
    return decoded.delta
end

M.make_request = function()
    local provider_config = config.providers.openai
    local body = {
        model = provider_config.model,
        input = state.conversation,
        stream = true,
        max_output_tokens = provider_config.max_tokens,
    }
    if provider_config.thinking.enabled then
        body.reasoning = { effort = "low" }
    end
    if provider_config.tools_enabled then
        body.tools = config.tools
    end
    common.make_request(
        provider_config,
        body,
        function() end,
        M.reasoning_function,
        M.content_function,
        M.tool_call_function,
        "event: response.completed",
        M.valid_block_condition
    )
end

M.init = function() end

return M
