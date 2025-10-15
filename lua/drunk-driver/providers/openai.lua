local config = require("drunk-driver.config")
local state = require("drunk-driver.state")
local buffer = require("drunk-driver.buffer")
local common = require("drunk-driver.providers.common")
local tools = require("drunk-driver.tools")

local M = {}

M.build_tools = function()
    local unserialized_tools = {}
    for _, tool in pairs(tools) do
        table.insert(unserialized_tools, {
            type = "function",
            name = tool.name,
            description = tool.description,
            parameters = tool.parameters,
        })
    end
    return unserialized_tools
end

M.reasoning_function = function(_)
    return false
end

M.content_function = function(opts)
    if opts.decoded.delta and opts.decoded.type == "response.output_text.delta" then
        if state.state ~= state.state_enum.RESPONSE then
            state.set_state(state.state_enum.RESPONSE)
            buffer.print_stream_scheduled("\n", state.buffer)
        end
        opts.answer = opts.answer .. opts.decoded.delta
        buffer.print_stream_scheduled(opts.decoded.delta, state.buffer)
        return true
    end
    return false
end

M.tool_call_function = function(opts)
    if
        opts.decoded.item
        and opts.decoded.item.type == "function_call"
        and opts.decoded.item.status == "in_progress"
    then
        -- tool call start
        opts.tool_call_index = opts.tool_call_index + 1
        table.insert(opts.tool_calls, opts.tool_call_index, {
            id = opts.decoded.item.call_id,
            type = "function",
            ["function"] = {
                name = opts.decoded.item.name,
                arguments = opts.decoded.item.arguments,
            },
        })
        return true
    end
    if opts.decoded.delta and opts.decoded.type == "response.function_call_arguments.delta" then
        -- tool call arguments
        opts.tool_calls[opts.tool_call_index]["function"].arguments = opts.tool_calls[opts.tool_call_index]["function"].arguments
            .. opts.decoded.delta
        return true
    end
    return false
end

M.add_tool_calls = function(_, raw_tool_calls, solved_tool_calls)
    for _, call in ipairs(raw_tool_calls) do
        table.insert(state.conversation, {
            type = "function_call",
            name = call["function"].name,
            arguments = call["function"].arguments,
            call_id = call.id,
        })
    end

    for _, call in ipairs(solved_tool_calls) do
        table.insert(state.conversation, {
            type = "function_call_output",
            call_id = call.tool_call_id,
            output = call.result,
        })
    end
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
        M.make_request,
        M.reasoning_function,
        M.content_function,
        M.tool_call_function,
        "event: response.completed",
        M.add_tool_calls
    )
end

M.init = function()
    config.tools = M.build_tools()
end

return M
