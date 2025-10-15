local system_prompt = require("drunk-driver.system_prompt")

local M = {}

local openai_compatible_get_headers = function(provider_config)
    return {
        Authorization = "Bearer " .. os.getenv(provider_config.api_key_name),
    }
end

local anthropic_get_headers = function(provider_config)
    return {
        ["x-api-key"] = os.getenv(provider_config.api_key_name),
        ["anthropic-version"] = "2023-06-01",
    }
end

local copilot_get_headers = function(provider_config)
    local version = vim.version()
    return {
        Authorization = "Bearer " .. provider_config.token,
        ["Content-Type"] = "application/json",
        ["Copilot-Integration-Id"] = "vscode-chat",
        ["Editor-Version"] = "Neovim/" .. version.major .. "." .. version.minor .. "." .. version.patch,
    }
end

M.providers = {
    moonshot = {
        name = "moonshot",
        api_key_name = "MOONSHOT_API_KEY",
        url = "https://api.moonshot.ai",
        chat_url = "/v1/chat/completions",
        models_endpoint = "/v1/models",
        model = "kimi-k2-0905-preview",
        roles = {
            llm = "assistant",
            user = "user",
        },
        max_tokens = 10000,
        thinking = {
            enabled = true,
            budget = 2000, -- NOTE: this doesn't work
        },
        headers_function = openai_compatible_get_headers,
        tools_enabled = true,
    },
    openai = {
        name = "openai",
        api_key_name = "OPENAI_API_KEY",
        url = "https://api.openai.com",
        chat_url = "/v1/responses",
        models_endpoint = "/v1/models",
        -- model = "gpt-5",
        model = "gpt-5-mini-2025-08-07",
        roles = {
            llm = "assistant",
            user = "user",
        },
        max_tokens = 10000,
        thinking = {
            enabled = true,
            budget = 2000, -- NOTE: this doesn't work
        },
        headers_function = openai_compatible_get_headers,
        tools_enabled = true,
    },
    anthropic = {
        name = "anthropic",
        api_key_name = "ANTHROPIC_API_KEY",
        url = "https://api.anthropic.com",
        chat_url = "/v1/messages",
        models_endpoint = "/v1/models",
        model = "claude-sonnet-4-20250514",
        roles = {
            llm = "assistant",
            user = "user",
        },
        max_tokens = 10000,
        thinking = {
            enabled = true,
            budget = 2000,
        },
        headers_function = anthropic_get_headers,
        tools_enabled = true,
    },
    copilot = {
        name = "copilot",
        api_key_name = "", -- This is not used
        url = "https://api.githubcopilot.com",
        chat_url = "/chat/completions",
        models_endpoint = "/models",
        model = "claude-sonnet-4",
        roles = {
            llm = "assistant",
            user = "user",
        },
        max_tokens = 10000,
        thinking = { -- WARNING: not sure this works
            enabled = true,
            budget = 2000, -- NOTE: this doesn't work
        },
        headers_function = copilot_get_headers,
        tools_enabled = false,
    },
}

M.display_names = {
    user = "# Me",
    llm = "# Drunk Driver",
}

M.thinking = {
    marker = "> [Thinking]",
    marker_regex = "> %[Thinking%]",
}

M.tools = {}

M.log_file = io.open(vim.fn.stdpath("log") .. "/drunk-driver.log", "a")

M.linux_distribution = ""
M.system_prompt = ""

M.current_provider = "anthropic"

M.save_directory_name = ".drunk-driver"

M.setup = function(opts)
    if opts.provider then
        M.current_provider = opts.provider
    end
    if opts.system_prompt then
        M.system_prompt = opts.system_prompt
    else
        M.system_prompt = system_prompt.default(M.linux_distribution)
    end
    if opts.linux_distribution then
        M.linux_distribution = opts.linux_distribution
    end
    if opts.providers then
        M.providers = vim.tbl_deep_extend("force", M.providers, opts.providers)
    end
end

M.get_current_provider_config = function()
    return M.providers[M.current_provider]
end

return M
