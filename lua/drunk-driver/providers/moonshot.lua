local config = require("drunk-driver.config")
local openai_compatible = require("drunk-driver.providers.openai_compatible")
local tools = require("drunk-driver.tools")

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
    return openai_compatible.make_request(provider_config, M.build_tools)
end

M.init = function()
    config.tools = M.build_tools()
end

return M
