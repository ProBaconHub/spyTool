-- spyTool/modules/01_core.lua
-- Concat-loaded by main.lua (order matters; locals are shared across the chunk).

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

local SPYTOOL_GENV_KEY = "__ProBaconHubSpyTool__"
local SPYTOOL_HOOKS_KEY = "__ProBaconHubSpyToolHooks__"

local SPYTOOL_BRIDGE_KEY = "__ProBaconHubSpyToolBridge__"

local SPYTOOL_WORKSPACE_FOLDER = "spyTool"
local SPYTOOL_ASSET_DIR = SPYTOOL_WORKSPACE_FOLDER .. "/asset"
local _assetImageCache = {}

local function getAssetImage(fileName)
    if type(fileName) ~= "string" or fileName == "" then
        return nil
    end
    if _assetImageCache[fileName] ~= nil then
        return _assetImageCache[fileName] or nil
    end
    if type(safeGetcustomasset) ~= "function" then
        _assetImageCache[fileName] = false
        return nil
    end
    local candidates = {
        SPYTOOL_ASSET_DIR .. "/" .. fileName,
        "asset/" .. fileName,
    }
    for _, path in ipairs(candidates) do
        local ok, url = pcall(safeGetcustomasset, path)
        if ok and type(url) == "string" and url ~= "" then
            _assetImageCache[fileName] = url
            return url
        end
    end
    _assetImageCache[fileName] = false
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

local function appendInterceptHookHeader(lines, usesHookfunction)
    if usesHookfunction then
        table.insert(lines, "-- Intercept uses hookfunction")
    else
        table.insert(lines, "-- hookfunction unavailable on this executor; using direct replacement / wrapper fallback")
    end
    table.insert(lines, "")
end
