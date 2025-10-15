local config = require("drunk-driver.config")
local openai_compatible = require("drunk-driver.providers.openai_compatible")
local tools = require("drunk-driver.tools")
local state = require("drunk-driver.state")
local common = require("drunk-driver.providers.common")

local M = {}

M.build_tools = function()
    local unserialized_tools = {}
    for _, tool in pairs(tools) do
        table.insert(unserialized_tools, {
            type = "function",
            ["function"] = {
                name = tool.name,
                description = tool.description,
                parameters = tool.parameters,
            },
        })
    end
    return unserialized_tools
end

M.add_tool_calls = function(content, raw_tool_calls, solved_tool_calls)
    local provider_config = config.providers.moonshot
    table.insert(state.conversation, {
        role = provider_config.roles.llm,
        content = content,
        tool_calls = raw_tool_calls,
    })
    for _, call in ipairs(solved_tool_calls) do
        table.insert(state.conversation, {
            role = "tool",
            tool_call_id = call.tool_call_id,
            name = call.name,
            content = vim.json.encode({
                args = call.args,
                result = call.result,
            }),
        })
    end
end

M.make_request = function()
    local provider_config = config.providers.moonshot
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
    common.make_request(
        provider_config,
        body,
        M.make_request,
        openai_compatible.reasoning_function,
        openai_compatible.content_function,
        openai_compatible.tool_call_function,
        openai_compatible.end_marker,
        M.add_tool_calls
    )
end

M.init = function()
    config.tools = M.build_tools()
end

return M
