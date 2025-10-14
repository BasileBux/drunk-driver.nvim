local M = {}

M.name = "ls"

M.description = "List files and directories\n\n"
    .. "When you need to know which files exist where, use this command. It works exactly like in linux."

M.parameters = {
    required = {},
    properties = {
        path = {
            type = "string",
            description = "The path to list files from. If not provided, lists files in the current directory.",
        },
    },
}

M.run = function(path)
    -- local cmd = "ls -la"
    -- if path then
    --     cmd = cmd .. " " .. path
    -- end
    -- TODO: run in shell and return output
    -- WARNING: TESTING ONLY
    return "total 36K\n"
        .. "drwxr-xr-x  4 basileb users 4.0K Oct 13 16:55 .\n"
        .. "drwx------ 57 basileb users 4.0K Oct 13 16:28 ..\n"
        .. "-rw-r--r--  1 basileb users   45 Oct  1 12:58 .editorconfig\n"
        .. "drwxr-xr-x  7 basileb users 4.0K Oct  9 21:28 .git\n"
        .. "drwxr-xr-x  3 basileb users 4.0K Oct  2 18:38 lua\n"
        .. "-rw-r--r--  1 basileb users  224 Oct  7 19:27 README.md\n"
        .. "-rw-r--r--  1 basileb users 5.4K Oct 13 16:55 single-tool-call.log\n"
        .. "-rw-r--r--  1 basileb users  869 Oct 13 14:07 TODO.md"
end

return M
