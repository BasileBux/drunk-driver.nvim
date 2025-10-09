Curl = require("plenary.curl")
local config = require("drunk-driver.config")

local M = {}

local providers = {
    moonshot = require("drunk-driver.providers.moonshot"),
    openai = require("drunk-driver.providers.openai"),
    anthropic = require("drunk-driver.providers.anthropic"),
    copilot = require("drunk-driver.providers.copilot"),
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

M.list_providers = function()
    local provider_names = {}
    for name, _ in pairs(providers) do
        table.insert(provider_names, name)
    end
    return provider_names
end

M.select_provider = function(callback)
    local provider_names = M.list_providers()
    vim.ui.select(provider_names, {
        prompt = "Select a provider",
    }, function(choice)
        if choice then
            callback(choice)
        end
    end)
end

M.list_models = function(provider_name)
    local provider = M.get_provider(provider_name)
    local provider_config = config.providers[provider_name]
    local headers = provider.get_headers(provider_config)

    local models = Curl.get(provider_config.url .. provider_config.models_endpoint, {
        headers = headers,
    })
    local ok, decoded = pcall(vim.json.decode, models.body)
    if ok and decoded.data then
        local model_names = {}
        for _, model in ipairs(decoded.data) do
            table.insert(model_names, model.id)
        end
        return model_names
    end
    return {}
end

M.select_model = function(provider, callback)
    local models = M.list_models(provider)
    vim.ui.select(models, {
        prompt = "Select a model",
    }, function(choice)
        if choice then
            callback(choice)
        end
    end)
end

M.change_model = function()
    M.select_provider(function(provider_name)
        M.select_model(provider_name, function(model_name)
            config.current_provider = provider_name
            providers[provider_name].init()
            config.providers[provider_name].model = model_name
            vim.notify("Provider set to " .. provider_name .. " with model " .. model_name)
        end)
    end)
end

return M
