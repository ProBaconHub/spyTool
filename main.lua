local WORKSPACE_FOLDER = "spyTool"
local MODULES = {
    "modules/01_core.lua",
    "modules/02_stealth.lua",
    "modules/03_parser.lua",
    "modules/04_theme.lua",
    "modules/05_ui_kit.lua",
    "modules/06_function_analyzer.lua",
    "modules/07_remote_scanner.lua",
    "modules/08_http_interceptor.lua",
    "modules/09_module_explorer.lua",
    "modules/10_ui_components.lua",
    "modules/11_ui.lua",
}

local function resolvePath(rel)
    local primary = WORKSPACE_FOLDER .. "/" .. rel
    if type(isfile) == "function" then
        if isfile(primary) then
            return primary
        end
        if isfile(rel) then
            return rel
        end
    end
    return primary
end

local function readSource(rel)
    local path = resolvePath(rel)
    if type(readfile) ~= "function" then
        error("[SpyTool] readfile is unavailable on this executor")
    end
    if type(isfile) == "function" and not isfile(path) then
        error("[SpyTool] missing module: " .. path)
    end
    local ok, source = pcall(readfile, path)
    if not ok then
        error("[SpyTool] failed to readfile(" .. path .. "): " .. tostring(source))
    end
    if type(source) ~= "string" or source == "" then
        error("[SpyTool] module is empty: " .. path)
    end
    return source, path
end

local parts = {}
local loadedPaths = {}
for i, rel in ipairs(MODULES) do
    local source, path = readSource(rel)
    parts[i] = source
    loadedPaths[i] = path
end

local combined = table.concat(parts, "\n")
local chunk, err = loadstring(combined, "@" .. WORKSPACE_FOLDER .. "/modules")
if not chunk then
    error("[SpyTool] failed to compile modules: " .. tostring(err))
end

return chunk()
