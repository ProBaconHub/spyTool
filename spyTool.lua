--[[
    Spy Tool loader
    Place the spyTool folder in your executor workspace, then run this file.
    It readfile()'s spyTool/main.lua and executes it.
]]

local MAIN_PATH = "spyTool/main.lua"
local FALLBACK_PATH = "main.lua"

local function resolveMainPath()
    if type(isfile) == "function" then
        if isfile(MAIN_PATH) then
            return MAIN_PATH
        end
        if isfile(FALLBACK_PATH) then
            return FALLBACK_PATH
        end
    end
    return MAIN_PATH
end

local function loadMainSource(path)
    if type(readfile) ~= "function" then
        error("[SpyTool] readfile is unavailable on this executor")
    end
    if type(isfile) == "function" and not isfile(path) then
        error("[SpyTool] missing main script at workspace path: " .. path)
    end
    local ok, source = pcall(readfile, path)
    if not ok then
        error("[SpyTool] failed to readfile(" .. path .. "): " .. tostring(source))
    end
    if type(source) ~= "string" or source == "" then
        error("[SpyTool] main script is empty: " .. path)
    end
    return source
end

local path = resolveMainPath()
local source = loadMainSource(path)

local chunk, compileErr = loadstring(source, "@" .. path)
if not chunk then
    error("[SpyTool] failed to compile " .. path .. ": " .. tostring(compileErr))
end

return chunk()
