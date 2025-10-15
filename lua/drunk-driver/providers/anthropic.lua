local config = require("drunk-driver.config")
local state = require("drunk-driver.state")
local buffer = require("drunk-driver.buffer")
local thinking = require("drunk-driver.thinking")
local common = require("drunk-driver.providers.common")
local tools = require("drunk-driver.tools")

local M = {}

M.build_tools = function()
    local unserialized_tools = {}
    for _, tool in pairs(tools) do
        table.insert(unserialized_tools, {
            name = tool.name,
            description = tool.description,
            input_schema = tool.parameters,
        })
    end
    return unserialized_tools
end

M.reasoning_function = function(opts)
    if opts.decoded.delta and opts.decoded.delta.thinking then
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
    if opts.decoded.delta and opts.decoded.delta.text then
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

M.tool_call_function = function(opts)
    if opts.decoded.content_block and opts.decoded.content_block.type == "tool_use" then
        opts.tool_call_index = opts.tool_call_index + 1
        table.insert(opts.tool_calls, opts.tool_call_index, {
            id = opts.decoded.content_block.id,
            type = "function",
            ["function"] = {
                name = opts.decoded.content_block.name,
                arguments = "",
            },
        })
        return true
    end
    if
        opts.decoded.delta
        and opts.decoded.delta.type == "input_json_delta"
        and opts.tool_calls[opts.tool_call_index]
    then
        opts.tool_calls[opts.tool_call_index]["function"].arguments = opts.tool_calls[opts.tool_call_index]["function"].arguments
            .. (opts.decoded.delta.partial_json or "")
        return true
    end
    return false
end

M.add_tool_calls = function(content, raw_tool_calls, solved_tool_calls)
    local provider_config = config.providers.anthropic
    local formatted_content = {}
    local formatted_result_content = {}

    table.insert(formatted_content, {
        type = "text",
        text = content,
    })

    for _, call in ipairs(solved_tool_calls) do
        table.insert(formatted_content, {
            type = "tool_use",
            id = call.tool_call_id,
            name = call.name,
            input = call.args,
        })

        table.insert(formatted_result_content, {
            type = "tool_result",
            tool_use_id = call.tool_call_id,
            content = call.result,
            is_error = false,
        })
    end
    table.insert(formatted_result_content, {
        type = "text",
        text = "Go off king",
    })
    table.insert(state.conversation, {
        role = provider_config.roles.llm,
        content = formatted_content,
    })
    table.insert(state.conversation, {
        role = provider_config.roles.user,
        content = formatted_result_content,
    })
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
    if provider_config.tools_enabled then
        body.tools = config.tools
    end
    local end_marker = "event: message_stop"
    common.make_request(
        provider_config,
        body,
        M.make_request,
        M.reasoning_function,
        M.content_function,
        M.tool_call_function,
        end_marker,
        M.add_tool_calls
    )
end

M.init = function()
    config.tools = M.build_tools()
end

return M
