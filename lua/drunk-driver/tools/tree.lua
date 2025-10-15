local M = {}

M.name = "tree"

M.description = "Show the file tree of a given directory.\n\n"
    .. "When you need to know which files exist where, use this command. It works exactly like in linux."

M.parameters = {
    type = "object",
    required = {},
    properties = {
        args = {
            type = "string",
            description = "Additional arguments to pass to the 'tree' command (e.g., '-L 2' to limit depth to 2).",
        },
        path = {
            type = "string",
            description = "The path to list files from. If not provided, lists files in the current directory.",
        },
    },
}

M.run = function(args, path)
    -- local cmd = "tree"
    -- if path then
    --     cmd = cmd .. " " .. args .. " " .. path
    -- end
    -- TODO: run in shell and return output
    -- WARNING: TESTING ONLY
    return ".\n"
.. "├── lua\n"
.. "│   └── drunk-driver\n"
.. "│       ├── buffer.lua\n"
.. "│       ├── config.lua\n"
.. "│       ├── init.lua\n"
.. "│       ├── providers\n"
.. "│       │   ├── anthropic.lua\n"
.. "│       │   ├── copilot.lua\n"
.. "│       │   ├── init.lua\n"
.. "│       │   ├── moonshot.lua\n"
.. "│       │   ├── openai_compatible.lua\n"
.. "│       │   └── openai.lua\n"
.. "│       ├── state.lua\n"
.. "│       ├── system_prompt.lua\n"
.. "│       ├── thinking.lua\n"
.. "│       └── tools\n"
.. "│           ├── init.lua\n"
.. "│           ├── ls.lua\n"
.. "│           └── tree.lua\n"
.. "├── README.md\n"
.. "├── single-tool-call.log\n"
.. "└── TODO.md\n\n"
.. "5 directories, 18 files"
end

return M
