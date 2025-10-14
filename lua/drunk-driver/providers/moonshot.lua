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
                parameters = {
                    type = "object",
                    required = tool.parameters.required,
                    properties = tool.parameters.properties,
                },
            },
        })
    end
    return unserialized_tools
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
        M.build_tools,
        openai_compatible.reasoning_function,
        openai_compatible.content_function,
        openai_compatible.tool_call_function,
        openai_compatible.end_marker,
        openai_compatible.valid_block_condition
    )
end

M.init = function()
    config.tools = M.build_tools()
end

return M
