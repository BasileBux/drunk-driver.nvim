local config = require("drunk-driver.config")
local openai_compatible = require("drunk-driver.providers.openai-compatible")

local M = {}

M.make_request = function()
    local provider_config = config.providers.moonshot
    openai_compatible.make_request(provider_config)
end

M.init = function() end

return M
