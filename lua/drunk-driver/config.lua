local M = {}

M.providers = {
    moonshot = {
        api_key_name = "MOONSHOT_API_KEY",
        url = "https://api.moonshot.ai",
        chat_url = "/v1/chat/completions",
        models_endpoint = "/v1/models",
        default_model = "kimi-k2-0905-preview",
        roles = {
            llm = "assistant",
            user = "user",
        },
    },
    openai = {
        api_key_name = "OPENAI_API_KEY",
        url = "https://api.openai.com",
        chat_url = "/v1/responses",
        models_endpoint = "/v1/models",
        default_model = "gpt-5",
        roles = {
            llm = "assistant",
            user = "user",
        },
    },
}

M.system_prompt = "You are an AI assistant in neovim called Drunk Driver."
M.current_provider = "moonshot"

M.setup = function(opts)
    if opts.provider then
        M.current_provider = opts.provider
    end
    if opts.system_prompt then
        M.system_prompt = opts.system_prompt
    end
    if opts.providers then
        M.providers = vim.tbl_deep_extend("force", M.providers, opts.providers)
    end
end

M.get_current_provider_config = function()
    return M.providers[M.current_provider]
end

return M
