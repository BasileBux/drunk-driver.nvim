local config = require("drunk-driver.config")

local M = {}

local providers = {
    moonshot = require("drunk-driver.providers.moonshot"),
    openai = require("drunk-driver.providers.openai"),
}

M.get_current_provider = function()
    return providers[config.current_provider]
end

M.get_provider = function(name)
    return providers[name]
end

M.register_provider = function(name, provider)
    providers[name] = provider
end

return M
