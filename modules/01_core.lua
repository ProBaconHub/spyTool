-- spyTool/modules/01_core.lua

local SPYTOOL_VERSION = "1.1.2"

local function getSpyToolVersion()
    return SPYTOOL_VERSION
end

local function getSpyToolVersionShort()
    local major, minor = string.match(SPYTOOL_VERSION, "^(%d+)%.(%d+)")
    if major and minor then
        return major .. "." .. minor
    end
    return SPYTOOL_VERSION
end

local HttpInterceptor

local function resolveUNCSource()
    local env = (getgenv and getgenv()) or _G
    if env then
        local sunc = rawget(env, "sUNC") or rawget(env, "SUNC")
        if sunc then
            return sunc
        end
        local unc = rawget(env, "UNC") or rawget(env, "Unc")
        if unc then
            return unc
        end
    end
    return nil
end

local UNCSource = resolveUNCSource()

local function resolveUNCFunction(name, fallback)
    if type(UNCSource) == "table" then
        local fn = UNCSource[name]
        if type(fn) == "function" then
            return fn
        end
    elseif type(UNCSource) == "function" then
        local ok, fn = pcall(UNCSource, name)
        if ok and type(fn) == "function" then
            return fn
        end
    end
    return fallback
end

local safeCloneref = resolveUNCFunction("cloneref", cloneref) or function(obj)
    return obj
end

local safeGame = safeCloneref(game) or game

local function safeService(serviceName)
    local ok, service = pcall(function()
        return safeGame:GetService(serviceName)
    end)
    if not ok or service == nil then
        return nil
    end
    local cloned = safeCloneref(service)
    return cloned or service
end

local Players = safeService("Players")
local TweenService = safeService("TweenService")
local UserInputService = safeService("UserInputService")
local RunService = safeService("RunService")
local HttpService = safeService("HttpService")
local TextService = safeService("TextService")
local GuiService = safeService("GuiService")
local LocalPlayer = Players and safeCloneref(Players.LocalPlayer) or nil

local safeHookmetamethod = resolveUNCFunction("hookmetamethod", hookmetamethod)
local safeHookfunction = resolveUNCFunction("hookfunction", hookfunction)
local safeNewcclosure = resolveUNCFunction("newcclosure", newcclosure)
local safeClonefunction = resolveUNCFunction("clonefunction", clonefunction) or function(fn) return fn end
local safeRestorefunction = resolveUNCFunction("restorefunction", restorefunction)
local safeIsfunctionhooked = resolveUNCFunction("isfunctionhooked", isfunctionhooked)
local safeIscclosure = resolveUNCFunction("iscclosure", iscclosure)
local safeIslclosure = resolveUNCFunction("islclosure", islclosure)
local safeIsexecutorclosure = resolveUNCFunction("isexecutorclosure", isexecutorclosure)
local safeGetrawmetatable = resolveUNCFunction("getrawmetatable", getrawmetatable)
local safeDebugInfo = debug and debug.info
local safeGetconnections = resolveUNCFunction("getconnections", getconnections)
local safeRequest = resolveUNCFunction("request", request)
local safeSetclipboard = resolveUNCFunction("setclipboard", setclipboard)
local safeGetcustomasset = resolveUNCFunction("getcustomasset", getcustomasset)
    or resolveUNCFunction("getsynasset", getsynasset)
local safeWritefile = resolveUNCFunction("writefile", writefile)
local safeReadfile = resolveUNCFunction("readfile", readfile)
local safeIsfile = resolveUNCFunction("isfile", isfile)
local safeIsfolder = resolveUNCFunction("isfolder", isfolder)
local safeMakefolder = resolveUNCFunction("makefolder", makefolder)
local safeDelfile = resolveUNCFunction("delfile", delfile)

local SPYTOOL_GENV_KEY = "__ProBaconHubSpyTool__"
local SPYTOOL_HOOKS_KEY = "__ProBaconHubSpyToolHooks__"

local SPYTOOL_BRIDGE_KEY = "__ProBaconHubSpyToolBridge__"

local SPYTOOL_WORKSPACE_FOLDER = "spyTool"
local SPYTOOL_ASSET_DIR = SPYTOOL_WORKSPACE_FOLDER .. "/asset"
local SPYTOOL_ASSET_CACHE_DIR = SPYTOOL_WORKSPACE_FOLDER .. "/.assetcache"
local _assetImageCache = {}
local _assetFontCache = {}
local _assetPathCache = {}
local _assetBustCache = {}

local function ensureAssetFolder(path)
    if type(safeMakefolder) ~= "function" then
        return
    end
    path = tostring(path or ""):gsub("\\", "/")
    local acc = ""
    for part in string.gmatch(path, "[^/]+") do
        acc = (acc == "") and part or (acc .. "/" .. part)
        if not (type(safeIsfolder) == "function" and safeIsfolder(acc)) then
            pcall(safeMakefolder, acc)
        end
    end
end

local function fingerprintAssetBytes(content)
    if type(content) ~= "string" then
        return "0"
    end
    local h1, h2 = 0, 0
    for i = 1, #content do
        local b = string.byte(content, i)
        h1 = (h1 + b) % 4294967296
        h2 = (h2 + h1) % 4294967296
    end
    return string.format("%d_%08x%08x", #content, h1, h2)
end

local function resolveAssetWorkspacePath(fileName)
    if type(fileName) ~= "string" or fileName == "" then
        return nil
    end
    if _assetPathCache[fileName] ~= nil then
        return _assetPathCache[fileName] or nil
    end
    local candidates = {
        SPYTOOL_ASSET_DIR .. "/" .. fileName,
        "asset/" .. fileName,
    }
    if type(safeIsfile) == "function" then
        for _, path in ipairs(candidates) do
            local ok, exists = pcall(safeIsfile, path)
            if ok and exists then
                _assetPathCache[fileName] = path
                return path
            end
        end
    end
    -- Prefer workspace-rooted path even when isfile is unavailable.
    _assetPathCache[fileName] = candidates[1]
    return candidates[1]
end

-- getcustomasset caches by path inside the executor. Replacing logo.png on disk
-- keeps serving the old bytes unless we request a content-unique path.
local function getAssetImage(fileName)
    if type(fileName) ~= "string" or fileName == "" then
        return nil
    end
    if type(safeGetcustomasset) ~= "function" then
        _assetImageCache[fileName] = false
        return nil
    end

    local sourcePath = resolveAssetWorkspacePath(fileName)
    local loadPath = sourcePath
    local cacheKey = fileName

    if type(safeReadfile) == "function" and type(sourcePath) == "string" then
        local okRead, bytes = pcall(safeReadfile, sourcePath)
        if okRead and type(bytes) == "string" and #bytes > 0 then
            local fp = fingerprintAssetBytes(bytes)
            cacheKey = fileName .. "@" .. fp
            if _assetImageCache[cacheKey] ~= nil then
                return _assetImageCache[cacheKey] or nil
            end
            local prev = _assetBustCache[fileName]
            if prev and prev.fp == fp and prev.url then
                _assetImageCache[cacheKey] = prev.url
                return prev.url
            end
            local ext = fileName:match("%.([^%.]+)$") or "bin"
            local base = fileName:gsub("[^%w%.%-%_/]", "_"):gsub("/", "_")
            ensureAssetFolder(SPYTOOL_ASSET_CACHE_DIR)
            local bustPath = string.format("%s/%s_%s.%s", SPYTOOL_ASSET_CACHE_DIR, base, fp, ext)
            if not (type(safeIsfile) == "function" and safeIsfile(bustPath)) then
                pcall(safeWritefile, bustPath, bytes)
            end
            loadPath = bustPath
            if prev and prev.path and prev.path ~= bustPath and type(safeDelfile) == "function" then
                pcall(safeDelfile, prev.path)
            end
            _assetBustCache[fileName] = { fp = fp, path = bustPath }
        end
    end

    if _assetImageCache[cacheKey] ~= nil then
        return _assetImageCache[cacheKey] or nil
    end

    local tryPaths = {
        loadPath,
        sourcePath,
        SPYTOOL_ASSET_DIR .. "/" .. fileName,
        "asset/" .. fileName,
    }
    for _, candidate in ipairs(tryPaths) do
        if type(candidate) == "string" and candidate ~= "" then
            local ok, url = pcall(safeGetcustomasset, candidate)
            if ok and type(url) == "string" and url ~= "" then
                _assetImageCache[cacheKey] = url
                if _assetBustCache[fileName] then
                    _assetBustCache[fileName].url = url
                end
                return url
            end
        end
    end
    _assetImageCache[cacheKey] = false
    return nil
end

-- Roblox/UNC custom fonts require a font-family JSON that references the TTF
-- via getcustomasset. Font.new(ttfUrl) alone does not load glyphs.
local function getAssetFont(fileName, weight, style)
    if type(fileName) ~= "string" or fileName == "" then
        return nil
    end
    weight = weight or Enum.FontWeight.Regular
    style = style or Enum.FontStyle.Normal
    local cacheKey = fileName .. "|" .. tostring(weight) .. "|" .. tostring(style)
    if _assetFontCache[cacheKey] ~= nil then
        return _assetFontCache[cacheKey] or nil
    end
    if type(safeGetcustomasset) ~= "function" or type(safeWritefile) ~= "function" then
        _assetFontCache[cacheKey] = false
        return nil
    end

    local ttfPath = resolveAssetWorkspacePath(fileName)
    if not ttfPath then
        _assetFontCache[cacheKey] = false
        return nil
    end
    if type(safeIsfile) == "function" then
        local okExists, exists = pcall(safeIsfile, ttfPath)
        if not (okExists and exists) then
            _assetFontCache[cacheKey] = false
            return nil
        end
    end

    local okTtf, ttfAsset = pcall(safeGetcustomasset, ttfPath)
    if not okTtf or type(ttfAsset) ~= "string" or ttfAsset == "" then
        _assetFontCache[cacheKey] = false
        return nil
    end

    local familyName = (fileName:match("([^/\\]+)%.[^%.]+$") or "SpyToolFont"):gsub("%W+", "")
    if familyName == "" then
        familyName = "SpyToolFont"
    end
    local numericWeight = 400
    if weight == Enum.FontWeight.Thin then
        numericWeight = 100
    elseif weight == Enum.FontWeight.ExtraLight then
        numericWeight = 200
    elseif weight == Enum.FontWeight.Light then
        numericWeight = 300
    elseif weight == Enum.FontWeight.Medium then
        numericWeight = 500
    elseif weight == Enum.FontWeight.SemiBold then
        numericWeight = 600
    elseif weight == Enum.FontWeight.Bold then
        numericWeight = 700
    elseif weight == Enum.FontWeight.ExtraBold then
        numericWeight = 800
    elseif weight == Enum.FontWeight.Heavy then
        numericWeight = 900
    end
    local styleName = (style == Enum.FontStyle.Italic) and "italic" or "normal"

    local familyDir = SPYTOOL_ASSET_DIR .. "/fonts"
    ensureAssetFolder(familyDir)
    local familyRel = "fonts/" .. familyName .. ".json"
    local familyPath = familyDir .. "/" .. familyName .. ".json"
    local familyJson = nil
    if HttpService and type(HttpService.JSONEncode) == "function" then
        local okEncode, encoded = pcall(function()
            return HttpService:JSONEncode({
                name = familyName,
                faces = {
                    {
                        name = "Regular",
                        weight = numericWeight,
                        style = styleName,
                        assetId = ttfAsset,
                    },
                },
            })
        end)
        if okEncode then
            familyJson = encoded
        end
    end
    if type(familyJson) ~= "string" or familyJson == "" then
        familyJson = string.format(
            '{"name":"%s","faces":[{"name":"Regular","weight":%d,"style":"%s","assetId":"%s"}]}',
            familyName,
            numericWeight,
            styleName,
            ttfAsset:gsub("\\", "\\\\"):gsub('"', '\\"')
        )
    end

    local okWrite = pcall(safeWritefile, familyPath, familyJson)
    if not okWrite then
        -- Some installs keep assets at bare asset/fonts
        familyPath = "asset/fonts/" .. familyName .. ".json"
        familyRel = "fonts/" .. familyName .. ".json"
        okWrite = pcall(safeWritefile, familyPath, familyJson)
    end
    if not okWrite then
        _assetFontCache[cacheKey] = false
        return nil
    end

    local okFamily, familyAsset = pcall(safeGetcustomasset, familyPath)
    if not okFamily or type(familyAsset) ~= "string" or familyAsset == "" then
        _assetFontCache[cacheKey] = false
        return nil
    end

    local okFont, font = pcall(function()
        return Font.new(familyAsset, weight, style)
    end)
    if not (okFont and font) then
        okFont, font = pcall(function()
            return Font.new(familyAsset)
        end)
    end
    if okFont and font then
        _assetFontCache[cacheKey] = font
        -- Keep family json discoverable like other assets.
        _assetImageCache[familyRel] = familyAsset
        return font
    end
    _assetFontCache[cacheKey] = false
    return nil
end

local function applyAssetIcon(imageLabel, fileName, fallbackTextLabel)
    local url = getAssetImage(fileName)
    if url and imageLabel then
        imageLabel.Image = url
        imageLabel.Visible = true
        if fallbackTextLabel then
            fallbackTextLabel.Visible = false
        end
        return true
    end
    if imageLabel then
        imageLabel.Visible = false
    end
    if fallbackTextLabel then
        fallbackTextLabel.Visible = true
    end
    return false
end

local function getSpyGenv()
    return (getgenv and getgenv()) or _G
end

local function getHookStore()
    local genv = getSpyGenv()
    local store = genv[SPYTOOL_HOOKS_KEY]
    if type(store) ~= "table" then
        store = {}
        genv[SPYTOOL_HOOKS_KEY] = store
    end
    return store
end

local function hookStoreKey(object, method)
    return tostring(method) .. "@" .. tostring(object)
end

local function saveHookOriginal(object, method, oldFn)
    if type(oldFn) ~= "function" then
        return
    end
    local store = getHookStore()
    local key = hookStoreKey(object, method)
    if store[key] == nil then
        store[key] = oldFn
    end
end

local function getHookGenvStore()
    local store = getSpyGenv()[SPYTOOL_HOOKS_KEY]
    if type(store) == "table" then
        return store
    end
    return {}
end

local function getHookOriginal(object, method, fallback)
    local store = getHookGenvStore()
    return store[hookStoreKey(object, method)] or fallback
end

local function clearHookStore()
    getSpyGenv()[SPYTOOL_HOOKS_KEY] = nil
end

local function getMetaBridge()
    local genv = getSpyGenv()
    local bridge = genv[SPYTOOL_BRIDGE_KEY]
    if type(bridge) ~= "table" then
        bridge = {
            handlers = {},
            originals = {},
            dispatchers = {},
            installed = {},
        }
        genv[SPYTOOL_BRIDGE_KEY] = bridge
    end
    if type(bridge.handlers) ~= "table" then
        bridge.handlers = {}
    end
    if type(bridge.originals) ~= "table" then
        bridge.originals = {}
    end
    if type(bridge.dispatchers) ~= "table" then
        bridge.dispatchers = {}
    end
    if type(bridge.installed) ~= "table" then
        bridge.installed = {}
    end
    return bridge
end

local function disarmMetaBridgeHandlers()
    local bridge = getMetaBridge()
    bridge.handlers = {}
end

local function restorePersistedRequestAliases()
    local store = getHookGenvStore()
    local aliases = store.requestAliases
    if type(aliases) ~= "table" then
        return
    end
    pcall(function()
        local env = getSpyGenv()
        if type(env) == "table" then
            for key, original in pairs(aliases) do
                if type(original) == "function" then
                    env[key] = original
                end
            end
        end
    end)
end

local function forceRestoreAllPersistedHooks()
    restorePersistedRequestAliases()
end

local function spyCleanupFrame()
    if RunService then
        RunService.Heartbeat:Wait()
    end
end

do
    disarmMetaBridgeHandlers()
    restorePersistedRequestAliases()

    local spyGenv = getSpyGenv()
    local previous = spyGenv[SPYTOOL_GENV_KEY]
    if previous then
        pcall(function()
            if type(previous.Destroy) == "function" then
                previous:Destroy({ defer = false, force = true })
            end
        end)
        spyGenv[SPYTOOL_GENV_KEY] = nil
    end

    
    pcall(function()
        local parents = {}
        pcall(function()
            if gethui then
                parents[#parents + 1] = gethui()
            end
        end)
        pcall(function()
            parents[#parents + 1] = game:GetService("CoreGui")
        end)
        pcall(function()
            local lp = game:GetService("Players").LocalPlayer
            if lp then
                parents[#parents + 1] = lp:FindFirstChildOfClass("PlayerGui")
            end
        end)
        for _, parent in ipairs(parents) do
            if parent then
                local existing = parent:FindFirstChild("RemoteSpyUI")
                if existing then
                    existing:Destroy()
                end
            end
        end
    end)

    restorePersistedRequestAliases()
    
    
    clearHookStore()
end

local function copyToClipboard(text)
    if type(safeSetclipboard) == "function" then
        pcall(safeSetclipboard, text)
    end
end

local hookfunctionSupportCache = nil

local function isHookfunctionSupported()
    if hookfunctionSupportCache ~= nil then
        return hookfunctionSupportCache
    end
    
    local hf = safeHookfunction
    if type(hf) ~= "function" then
        hookfunctionSupportCache = false
        return false
    end
    
    local function probeFunc()
        return "original"
    end
    
    local ok, supported = pcall(function()
        local hookedCall = false
        local original = hf(probeFunc, function()
            hookedCall = true
            return "hooked"
        end)
        
        if type(original) ~= "function" then
            return false
        end
        
        local result = probeFunc()
        
        if type(safeRestorefunction) == "function" then
            pcall(safeRestorefunction, probeFunc)
        else
            pcall(hf, probeFunc, original)
        end
        
        return hookedCall and result == "hooked"
    end)
    
    hookfunctionSupportCache = ok and supported == true
    return hookfunctionSupportCache
end

local function isHookmetamethodSupported()
    return type(safeHookmetamethod) == "function"
        or type(hookmetamethod) == "function"
end

local function appendInterceptHookHeader(lines, mode)
    -- Empty
end
