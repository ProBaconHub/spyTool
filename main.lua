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

local REPO_OWNER = "ProBaconHub"
local REPO_NAME = "spyTool"
local REPO_BRANCH = "main"
local BRANCH_RAW_BASE = string.format(
    "https://raw.githubusercontent.com/%s/%s/refs/heads/%s",
    REPO_OWNER,
    REPO_NAME,
    REPO_BRANCH
)
local API_REPO_BASE = string.format(
    "https://api.github.com/repos/%s/%s",
    REPO_OWNER,
    REPO_NAME
)

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

local function ensureBootstrapUpdateApi()
    if type(getgenv) ~= "function" then
        return
    end
    local okEnv, env = pcall(getgenv)
    if not okEnv or type(env) ~= "table" then
        return
    end
    env.__SpyToolLocalDevActive = nil

    local boot = env.__SpyToolBootstrap
    if type(boot) ~= "table" then
        return
    end
    if type(boot.CheckForUpdates) == "function" then
        return
    end

    local function httpGet(url, headers)
        url = tostring(url or "")
        if type(request) == "function" then
            local ok, res = pcall(request, {
                Url = url,
                Method = "GET",
                Headers = headers or {
                    ["Cache-Control"] = "no-cache, no-store, must-revalidate",
                },
            })
            if ok and type(res) == "table" then
                local body = res.Body or res.body
                if type(body) == "string" and #body > 0 then
                    return body
                end
            end
        end
        if type(game) == "userdata" or type(game) == "table" then
            local ok, body = pcall(function()
                return game:HttpGet(url, true)
            end)
            if ok and type(body) == "string" and #body > 0 then
                return body
            end
        end
        error("[SpyTool] HttpGet failed for " .. url)
    end

    local function fingerprint(content)
        if type(content) ~= "string" then
            return "0:0000000000000000"
        end
        local h1, h2 = 0, 0
        for i = 1, #content do
            local b = string.byte(content, i)
            h1 = (h1 + b) % 4294967296
            h2 = (h2 + h1) % 4294967296
        end
        return string.format("%d:%08x%08x", #content, h1, h2)
    end

    local function decodeJson(text)
        return game:GetService("HttpService"):JSONDecode(text)
    end

    local function resolveTipSha()
        local headers = {
            ["Accept"] = "application/vnd.github+json",
            ["User-Agent"] = "ProBaconHub-SpyTool",
        }
        local endpoints = {
            API_REPO_BASE .. "/commits/" .. REPO_BRANCH,
            API_REPO_BASE .. "/branches/" .. REPO_BRANCH,
            API_REPO_BASE .. "/git/ref/heads/" .. REPO_BRANCH,
        }
        for _, endpoint in ipairs(endpoints) do
            local ok, body = pcall(httpGet, endpoint, headers)
            if ok and type(body) == "string" and #body > 0 then
                local decodeOk, data = pcall(decodeJson, body)
                if decodeOk and type(data) == "table" then
                    if type(data.sha) == "string" and #data.sha >= 7 then
                        return data.sha
                    end
                    if type(data.commit) == "table" and type(data.commit.sha) == "string" then
                        return data.commit.sha
                    end
                    if type(data.object) == "table" and type(data.object.sha) == "string" then
                        return data.object.sha
                    end
                end
            end
        end
        return nil
    end

    local function rawUrl(rel, sha)
        rel = tostring(rel or ""):gsub("^/+", "")
        local base = BRANCH_RAW_BASE
        if type(sha) == "string" and #sha >= 7 then
            base = string.format(
                "https://raw.githubusercontent.com/%s/%s/%s",
                REPO_OWNER,
                REPO_NAME,
                sha
            )
        end
        return base .. "/" .. rel .. "?t=" .. tostring(tick()):gsub("%.", "")
    end

    boot.CheckForUpdates = function()
        local tipSha = nil
        local okSha, shaOrErr = pcall(resolveTipSha)
        if okSha and type(shaOrErr) == "string" then
            tipSha = shaOrErr
        end
        local manifestBody = httpGet(rawUrl("manifest.json", tipSha))
        local remoteManifest = decodeJson(manifestBody)
        local pending = {}
        if type(remoteManifest) == "table" and type(remoteManifest.files) == "table" then
            for _, entry in ipairs(remoteManifest.files) do
                if type(entry) == "table" and type(entry.path) == "string" and type(entry.hash) == "string" then
                    local dest = WORKSPACE_FOLDER .. "/" .. entry.path
                    local existing = nil
                    if type(isfile) == "function" and isfile(dest) and type(readfile) == "function" then
                        local okRead, body = pcall(readfile, dest)
                        if okRead and type(body) == "string" then
                            existing = body
                        end
                    end
                    if not (existing and fingerprint(existing) == entry.hash) then
                        pending[#pending + 1] = entry
                    end
                end
            end
        end
        local remoteVersion = nil
        local okCore, coreBody = pcall(httpGet, rawUrl("modules/01_core.lua", tipSha))
        if okCore and type(coreBody) == "string" then
            remoteVersion = coreBody:match('SPYTOOL_VERSION%s*=%s*"([^"]+)"')
                or coreBody:match("SPYTOOL_VERSION%s*=%s*'([^']+)'")
        end
        local pendingPaths = {}
        for i = 1, math.min(8, #pending) do
            pendingPaths[#pendingPaths + 1] = pending[i].path
        end
        return {
            available = #pending > 0,
            pending = #pending,
            sha = tipSha,
            remoteVersion = remoteVersion,
            pendingPaths = pendingPaths,
        }
    end
    print("[SpyTool] patched CheckForUpdates onto bootstrap (public bootstrap lacked it)")
end

ensureBootstrapUpdateApi()

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
