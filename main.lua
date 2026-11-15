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

local SpyStealth = {
    FunctionHooks = {},
    MetaRecords = {},
    ProtectedFunctions = {},
    ExpectedClosure = {},
    ExpectedExecutor = {},
    Baseline = {
        Executor = "Real",
        HttpSurfaceIsExecutor = true,
        MetaMethodIsExecutor = false,
        RemoteMethodIsExecutor = false,
        DecoyHookReportsHooked = true,
    },
    DetectionSpoofsInstalled = false,
    _uninstalling = false,
    RestoreBypass = nil,
    IsFunctionHookedBypass = nil,
    IscclosureBypass = nil,
    IslclosureBypass = nil,
    IsExecutorClosureBypass = nil,
    DebugInfoBypass = nil,
}

function SpyStealth:RestoreRaw(fn)
    if type(fn) ~= "function" or type(safeRestorefunction) ~= "function" then
        return false
    end
    local bypass = self.RestoreBypass
    if type(bypass) == "function" then
        return pcall(bypass, fn)
    end
    return pcall(safeRestorefunction, fn)
end

function SpyStealth:CloneRaw(fn)
    if type(fn) ~= "function" then
        return fn
    end
    if not self._uninstalling then
        self:RestoreRaw(fn)
    end
    return safeClonefunction(fn)
end

function SpyStealth:RegisterProtected(fn, closureKind, isExecutorClosure)
    if type(fn) ~= "function" then
        return
    end
    self.ProtectedFunctions[fn] = true
    if closureKind then
        self.ExpectedClosure[fn] = closureKind
    end
    if isExecutorClosure ~= nil then
        self.ExpectedExecutor[fn] = isExecutorClosure
    end
end

function SpyStealth:ShouldHideHookStatus(fn)
    if type(fn) ~= "function" then
        return false
    end
    if self.ProtectedFunctions[fn] then
        return true
    end
    for _, record in ipairs(self.FunctionHooks) do
        if fn == record.target or fn == record.replacement or fn == record.original then
            return true
        end
    end
    for _, record in ipairs(self.MetaRecords) do
        if fn == record.replacement or fn == record.slot or fn == record.old then
            return true
        end
    end
    return false
end

function SpyStealth:RegisterMetamethodSlot(object, method, closureKind, isExecutorClosure)
    if type(safeGetrawmetatable) ~= "function" then
        return nil
    end
    local slotFn
    pcall(function()
        local mt = safeGetrawmetatable(object)
        if mt and type(mt[method]) == "function" then
            slotFn = mt[method]
            self:RegisterProtected(slotFn, closureKind, isExecutorClosure)
        end
    end)
    return slotFn
end

function SpyStealth:SyncHookVisibility()
    local bindings = {
        safeIsfunctionhooked,
        safeIscclosure,
        safeIslclosure,
        safeRestorefunction,
        safeIsexecutorclosure,
        safeDebugInfo,
        isfunctionhooked,
        iscclosure,
        islclosure,
        restorefunction,
        isexecutorclosure,
        debug and debug.info,
    }
    for _, fn in ipairs(bindings) do
        if type(fn) == "function" then
            self:RegisterProtected(fn)
        end
    end

    for _, record in ipairs(self.FunctionHooks) do
        self:RegisterProtected(record.target)
        self:RegisterProtected(record.replacement)
        if type(record.original) == "function" then
            self:RegisterProtected(record.original)
        end
    end

    for _, record in ipairs(self.MetaRecords) do
        self:RegisterProtected(record.replacement)
        record.slot = self:RegisterMetamethodSlot(
            record.object,
            record.method,
            "c",
            self.Baseline.MetaMethodIsExecutor
        ) or record.slot
    end
end

function SpyStealth:WrapCClosure(fn)
    if type(fn) ~= "function" then
        return fn
    end
    if type(safeNewcclosure) == "function" then
        return safeNewcclosure(fn)
    end
    return fn
end

function SpyStealth:RegisterFunctionHook(record)
    table.insert(self.FunctionHooks, record)
    self:RegisterProtected(record.target, record.closureKind, record.executorIsExecutor)
    self:RegisterProtected(record.replacement, record.closureKind, record.executorIsExecutor)
end

function SpyStealth:ReinstallFunctionHook(record)
    if type(record.target) ~= "function" or type(record.replacement) ~= "function" then
        return
    end
    self:RestoreRaw(record.target)
    local original = safeHookfunction(record.target, record.replacement)
    record.original = original
    self:SyncHookVisibility()
end

function SpyStealth:HookFunction(target, handler, opts)
    opts = opts or {}
    if type(target) ~= "function" or type(safeHookfunction) ~= "function" then
        return nil, nil, nil
    end

    local rawClone = self:CloneRaw(target)
    local replacement = self:WrapCClosure(handler)
    local closureKind = opts.closureKind
    if not closureKind and type(safeIscclosure) == "function" then
        local ok, isC = pcall(safeIscclosure, rawClone)
        closureKind = ok and isC and "c" or "lua"
    end

    local original = safeHookfunction(target, replacement)
    local record = {
        name = opts.name or "function",
        target = target,
        original = original,
        replacement = replacement,
        raw = rawClone,
        closureKind = closureKind,
        executorIsExecutor = opts.executorIsExecutor,
    }
    self:RegisterFunctionHook(record)
    return original, replacement, rawClone
end

function SpyStealth:HookMetamethod(object, method, handler)
    if type(safeHookmetamethod) ~= "function" or type(handler) ~= "function" then
        return nil, nil
    end

    local bridge = getMetaBridge()
    local key = tostring(method)
    
    bridge.handlers[key] = handler

    if bridge.installed[key] and type(bridge.dispatchers[key]) == "function" then
        local old = bridge.originals[key]
        local dispatcher = bridge.dispatchers[key]
        self:RegisterProtected(dispatcher, "c", self.Baseline.MetaMethodIsExecutor)
        local record = {
            object = object,
            method = method,
            old = old,
            replacement = dispatcher,
            bridged = true,
        }
        table.insert(self.MetaRecords, record)
        record.slot = self:RegisterMetamethodSlot(object, method, "c", self.Baseline.MetaMethodIsExecutor)
        return old, dispatcher
    end

    
    local dispatcher
    dispatcher = self:WrapCClosure(function(...)
        local active = bridge.handlers[key]
        if type(active) == "function" then
            return active(...)
        end
        local original = bridge.originals[key]
        if type(original) == "function" then
            return original(...)
        end
        return nil
    end)
    self:RegisterProtected(dispatcher, "c", self.Baseline.MetaMethodIsExecutor)

    local old = safeHookmetamethod(object, method, dispatcher)
    bridge.originals[key] = old
    bridge.dispatchers[key] = dispatcher
    bridge.installed[key] = true
    saveHookOriginal(object, method, old)

    local record = {
        object = object,
        method = method,
        old = old,
        replacement = dispatcher,
        bridged = true,
    }
    table.insert(self.MetaRecords, record)
    record.slot = self:RegisterMetamethodSlot(object, method, "c", self.Baseline.MetaMethodIsExecutor)
    return old, dispatcher
end

function SpyStealth:ReinstallMeta(record)
    if not record or type(record.replacement) ~= "function" then
        return
    end
    local bridge = getMetaBridge()
    local key = tostring(record.method)
    self:RestoreRaw(record.replacement)
    local old = safeHookmetamethod(record.object, record.method, record.replacement)
    record.old = old
    if type(old) == "function" then
        bridge.originals[key] = bridge.originals[key] or old
    end
    bridge.dispatchers[key] = record.replacement
    bridge.installed[key] = true
    record.slot = self:RegisterMetamethodSlot(
        record.object,
        record.method,
        "c",
        self.Baseline.MetaMethodIsExecutor
    ) or record.slot
    self:SyncHookVisibility()
end

function SpyStealth:InstallDetectionSpoofs()
    local bridge = getMetaBridge()
    if self.DetectionSpoofsInstalled or bridge.detectionInstalled then
        self.DetectionSpoofsInstalled = true
        bridge.detectionInstalled = true
        return
    end

    if type(safeIsfunctionhooked) == "function" then
        local rawIsHooked = self:CloneRaw(safeIsfunctionhooked)
        local function spoofedIsFunctionHooked(fn)
            if self:ShouldHideHookStatus(fn) then
                return false
            end
            return rawIsHooked(fn)
        end
        local _, replacement = self:HookFunction(safeIsfunctionhooked, spoofedIsFunctionHooked, {
            name = "isfunctionhooked",
            closureKind = "c",
            executorIsExecutor = true,
        })
        self.IsFunctionHookedBypass = replacement
    end

    if type(safeIscclosure) == "function" then
        local rawIscclosure = self:CloneRaw(safeIscclosure)
        local function spoofedIscclosure(fn)
            local expected = self.ExpectedClosure[fn]
            if expected == "c" then
                return true
            end
            if expected == "lua" then
                return false
            end
            return rawIscclosure(fn)
        end
        local _, replacement = self:HookFunction(safeIscclosure, spoofedIscclosure, {
            name = "iscclosure",
            closureKind = "c",
            executorIsExecutor = true,
        })
        self.IscclosureBypass = replacement
    end

    if type(safeIslclosure) == "function" then
        local rawIslclosure = self:CloneRaw(safeIslclosure)
        local function spoofedIslclosure(fn)
            local expected = self.ExpectedClosure[fn]
            if expected == "c" then
                return false
            end
            if expected == "lua" then
                return true
            end
            return rawIslclosure(fn)
        end
        local _, replacement = self:HookFunction(safeIslclosure, spoofedIslclosure, {
            name = "islclosure",
            closureKind = "c",
            executorIsExecutor = true,
        })
        self.IslclosureBypass = replacement
    end

    if type(safeRestorefunction) == "function" then
        local rawRestore = self:CloneRaw(safeRestorefunction)
        local stealth = self
        local function spoofedRestore(fn)
            if stealth._uninstalling then
                return rawRestore(fn)
            end
            for _, record in ipairs(stealth.FunctionHooks) do
                if record.target == fn then
                    pcall(rawRestore, fn)
                    stealth:ReinstallFunctionHook(record)
                    return
                end
            end
            for _, record in ipairs(stealth.MetaRecords) do
                if record.replacement == fn or record.slot == fn then
                    pcall(rawRestore, fn)
                    stealth:ReinstallMeta(record)
                    record.slot = stealth:RegisterMetamethodSlot(
                        record.object,
                        record.method,
                        "c",
                        stealth.Baseline.MetaMethodIsExecutor
                    ) or record.slot
                    stealth:SyncHookVisibility()
                    return
                end
            end
            return rawRestore(fn)
        end
        local _, replacement = self:HookFunction(safeRestorefunction, spoofedRestore, {
            name = "restorefunction",
            closureKind = "c",
            executorIsExecutor = true,
        })
        self.RestoreBypass = rawRestore
    end

    if type(safeIsexecutorclosure) == "function" then
        local rawIsExecutor = self:CloneRaw(safeIsexecutorclosure)
        local function spoofedIsExecutorClosure(fn)
            local expected = self.ExpectedExecutor[fn]
            if expected ~= nil then
                return expected
            end
            return rawIsExecutor(fn)
        end
        local _, replacement = self:HookFunction(safeIsexecutorclosure, spoofedIsExecutorClosure, {
            name = "isexecutorclosure",
            closureKind = "c",
            executorIsExecutor = true,
        })
        self.IsExecutorClosureBypass = replacement
    end

    if type(safeDebugInfo) == "function" then
        local rawDebugInfo = self:CloneRaw(safeDebugInfo)
        local stealth = self
        local function spoofedDebugInfo(fn, what, ...)
            if stealth:ShouldHideHookStatus(fn) then
                local field = what
                if field == nil or field == "s" then
                    return "[C]"
                end
            end
            return rawDebugInfo(fn, what, ...)
        end
        local _, replacement = self:HookFunction(safeDebugInfo, spoofedDebugInfo, {
            name = "debug.info",
            closureKind = "c",
            executorIsExecutor = false,
        })
        self.DebugInfoBypass = replacement
    end

    self.DetectionSpoofsInstalled = true
    getMetaBridge().detectionInstalled = true
end

function SpyStealth:UninstallFunctionHooks()
    
    
    local pending = {}
    for _, record in pairs(self.FunctionHooks) do
        if type(record) == "table" then
            table.insert(pending, record)
        end
    end
    self.FunctionHooks = {}

    for _, record in ipairs(pending) do
        self.ProtectedFunctions[record.target] = nil
        self.ProtectedFunctions[record.replacement] = nil
        self.ExpectedClosure[record.target] = nil
        self.ExpectedClosure[record.replacement] = nil
        self.ExpectedExecutor[record.target] = nil
        self.ExpectedExecutor[record.replacement] = nil
    end
end

function SpyStealth:UninstallMetaHooks()
    
    
    
    
    
    local bridge = getMetaBridge()
    local pending = {}
    for _, record in pairs(self.MetaRecords) do
        if type(record) == "table" then
            table.insert(pending, record)
            if record.method ~= nil then
                bridge.handlers[tostring(record.method)] = nil
            end
        end
    end
    self.MetaRecords = {}

    for _, record in ipairs(pending) do
        self.ProtectedFunctions[record.replacement] = nil
        self.ProtectedFunctions[record.slot] = nil
        self.ExpectedClosure[record.replacement] = nil
        self.ExpectedClosure[record.slot] = nil
        self.ExpectedExecutor[record.replacement] = nil
        self.ExpectedExecutor[record.slot] = nil
    end
end

function SpyStealth:UninstallDetectionSpoofs()
    
    
    
    local bridge = getMetaBridge()
    if self.DetectionSpoofsInstalled then
        bridge.detectionInstalled = true
    end
end

function SpyStealth:UninstallAll()
    self:UninstallMetaHooks()
    self:UninstallFunctionHooks()
    self:UninstallDetectionSpoofs()
    self.ProtectedFunctions = {}
    self.ExpectedClosure = {}
    self.ExpectedExecutor = {}
end

function SpyStealth:UninstallAllGentle()
    self._uninstalling = true
    pcall(function()
        self:UninstallMetaHooks()
    end)
    spyCleanupFrame()
    pcall(function()
        self:UninstallFunctionHooks()
    end)
    spyCleanupFrame()
    pcall(function()
        self:UninstallDetectionSpoofs()
    end)
    
    
    local bridge = getMetaBridge()
    self.FunctionHooks = {}
    self.MetaRecords = {}
    self.ProtectedFunctions = {}
    self.ExpectedClosure = {}
    self.ExpectedExecutor = {}
    self.DetectionSpoofsInstalled = bridge.detectionInstalled == true
    self._uninstalling = false
end

local parse
local getInstancePathFromParser
local parseLoadSuccess = pcall(function()
    local isCyclic; isCyclic = function(tbl, visited)
        visited = visited or {}
        if visited[tbl] then return true end
        visited[tbl] = true
        for _, value in pairs(tbl) do
            if type(value) == "table" then if isCyclic(value, visited) then return true end end
        end
        return false
    end
    local clean_string = function(str)
        local cleanTable = {['"'] = '\\"', ['\\'] = '\\\\', ["\n"] = "\\n", ["\t"] = "\\t", ["\r"] = "\\r"}
        for i = 0, 31 do
            if not cleanTable[string.char(i)] then
                cleanTable[string.char(i)] = "\\" .. string.format("%03d", i)
            end
        end
        for i = 127, 255 do
            cleanTable[string.char(i)] = "\\" .. string.format("%03d", i)
        end
        return (string.gsub(tostring(str), "[\"\\\0-\31\127-\255]", cleanTable))
    end
    local function isSimpleIdentifierName(name)
        if type(name) ~= "string" or name == "" then
            return false
        end
        if name:find(".", 1, true) then
            return false
        end
        return string.match(name, "^[%a_][%w_]*$") ~= nil
    end
    local get_instance_path = function(obj)
    	local path = ""
    	while obj do
    		if obj == game then
    			path = "game"..path
    			break
    		end
    		local indexName
    		local objName = tostring(obj.Name or "Unknown")
    		local objClass = "Instance"
    		pcall(function()
    			local cn = obj.ClassName
    			if type(cn) == "string" then
    				objClass = cn
    			end
    		end)

    		if isSimpleIdentifierName(objName) then
    			indexName = "." .. objName
    		else
                local escapedName = clean_string(objName)
    			indexName = '["' .. escapedName .. '"]'
    		end
    		if obj.Parent then
    			local success, hasChild = pcall(function() return obj.Parent:FindFirstChild(objName) end)
    			if success and hasChild and obj.Parent:FindFirstChild(objName) ~= obj then
    				local parCh = obj.Parent:GetChildren()
    				local fcInd = table.find(parCh, obj) or "nil"
    				indexName = ":GetChildren()["..fcInd.."]"
    			elseif obj.Parent == game and objClass then
    				indexName = ':GetService("'..objClass..'")'
    			end
    		elseif obj.Parent == nil then
    			local getnil = "local getNil = function(name, class) for _, v in next, getnilinstances() do if v.ClassName == class and v.Name == name then return v end end end"
    			local gotnil = "\n\ngetNil(\"%s\", \"%s\")"
    			indexName = getnil .. gotnil:format(objName, objClass)
    		end
    		path = indexName..path
    		obj = obj.Parent
    	end
        local lp = game.Players.LocalPlayer
        if lp and lp.Name then
            if path:sub(1, 27 + #lp.Name) == "game:GetService(\"Players\")." .. lp.Name then path = path:gsub("game:GetService%(\"Players\"%)." .. lp.Name, "game:GetService(\"Players\").LocalPlayer", 1) end
            if path:sub(1, 29 + #lp.Name) == "game:GetService(\"Workspace\")." .. lp.Name then path = path:gsub("game:GetService%(\"Workspace\"%)." .. lp.Name, "game:GetService(\"Players\").LocalPlayer.Character", 1) end
        end
    	local checkValid = pcall(function() local a = loadstring("return " .. path)() end)
        if not checkValid then path = "nil --[[ Invalid Path ]] " end
        return path
    end
    getInstancePathFromParser = get_instance_path
    local format_value = function(v)
        local vType = typeof(v)
        if vType == "string" then
            return '"' .. clean_string(v) .. '"'
        elseif vType == "number" then
            if v == math.huge then
                return "math.huge"
            elseif v == -math.huge then
                return "-math.huge"
            else
                return tostring(v)
            end
        elseif vType == "Instance" then
            return get_instance_path(v)
        elseif vType == "Color3" then
            return string.format("Color3.new(%s, %s, %s)", v.R, v.G, v.B)
        elseif vType == "BrickColor" then
            return string.format('BrickColor.new("%s")', tostring(v))
        elseif vType == "Vector3" then
            return string.format("Vector3.new(%s, %s, %s)", v.X, v.Y, v.Z)
        elseif vType == "Vector2" then
            return string.format("Vector2.new(%s, %s)", v.X, v.Y)
        elseif vType == "CFrame" then
            return "CFrame.new(" .. tostring(v) .. ")"
        elseif vType == "UDim2" then
            return "UDim2.new(" .. tostring(v):gsub("[%[%]]", "") .. ")"
        elseif vType == "UDim" then
            return "UDim.new(" .. tostring(v):gsub("[%[%]]", "") .. ")"
        elseif vType == "EnumItem" then
            return tostring(v)
        elseif vType == "NumberRange" then
            return "NumberRange.new(" .. tostring(v):gsub(" ", ", ") .. ")"
        elseif vType == "Rect" then
            return "Rect.new(" .. tostring(v) .. ")"
        else
            local str = tostring(v)
            if type(str) == "string" and str:match("^RaycastResult%s*{") then
                return '"' .. clean_string(str) .. '"' .. ' --[[ RaycastResult ]]'
            end
            if type(str) == "string" and str:match("^Connection") then
                return '\"' .. clean_string(str) .. '\"' .. ' --[[ Connection ]]'
            end
            if vType == "thread" or vType == "userdata" or vType == "function" or str:match("0x%x+$") then
                return '"' .. clean_string(str) .. '"'
            end
            return str
        end
    end
    local format_key = function(k)
        local kType = typeof(k)
        if kType == "string" then
            if isSimpleIdentifierName(k) then
                return k
            else
                return '["' .. clean_string(k) .. '"]'
            end
        else
            return "[" .. format_value(k) .. "]"
        end
    end
    local loops = 0
    local parse_workers = {} 
    local create_worker_index = function(parser)
        local current_index = #parse_workers + 1
        parse_workers[current_index] = parser
        return current_index
    end
    local parser; parser = function(tbl, indent, visited, ...)
        local extra = {...}
        local do_not_check_cyclic = extra[2]
        if not do_not_check_cyclic then
            if visited[tbl] then
                return indent .. "--[[ cyclic table detected ]]"
            end
            visited[tbl] = true
        end
        loops += 1
        if extra[1] and loops >= 1000 then
            loops = 0
            RunService.Stepped:Wait()
        end
        local prasing_lines = {}
        for i,v in pairs(tbl) do
            local formatted_key = format_key(i)
            if typeof(v) == "table" then
                local this_line = string.format("%s%s = {\n", indent, formatted_key)
                local new_worker = create_worker_index(parser)
                this_line ..= parse_workers[new_worker](v, indent .. "    ", visited, ...)
                this_line ..= "\n" .. indent .. "},"
                table.insert(prasing_lines, this_line)
            elseif typeof(v) == "function" then
                local success, result = pcall(function() return getfenv(v).script end)
                local the_source = tostring(debug.info(v, "s") or "unknown")
                if success and get_instance_path(result) ~= "" and get_instance_path(result) ~= nil then 
                    the_source = get_instance_path(result) 
                end
                the_source = the_source:gsub("%-%-%[%[", ""):gsub("%]%]", "") 

                local numArgs, isVariadic = debug.info(v, "a")
                local argInfo = string.format("args: %d%s", numArgs or 0, isVariadic and "..." or "")

                table.insert(prasing_lines, string.format("%s%s = %s, --[[ %s | Called by %s ]]", indent, formatted_key, format_value(v), argInfo, the_source))
            else
                table.insert(prasing_lines, string.format("%s%s = %s,", indent, formatted_key, format_value(v)))
            end
        end
        return table.concat(prasing_lines, "\n")
    end
    parse = function(tbl, halt, do_not_check_cyclic)
        if not tbl or type(tbl) ~= "table" then
            return tbl
        end
        parse_workers = {}
        loops = 0
        local parsed_content = "{\n"
        local worker_index = create_worker_index(parser)
        parsed_content ..= parse_workers[worker_index](tbl, "    ", {}, halt, do_not_check_cyclic)
        parsed_content ..= "\n}"
        parse_workers = {}
        return parsed_content
    end
end)

if not parseLoadSuccess or not parse then
    parse = function(value)
        if typeof(value) ~= "table" then
            return tostring(value)
        end
        
        local function serialize(tbl, indent)
            indent = indent or 0
            local spaces = string.rep("    ", indent)
            local nextSpaces = string.rep("    ", indent + 1)
            
            local isArray = true
            local count = 0
            for k, _ in pairs(tbl) do
                count = count + 1
                if type(k) ~= "number" or k ~= count then
                    isArray = false
                end
            end
            
            if count == 0 then
                return "{}"
            end
            
            local parts = {}
            
            if isArray then
                for i, v in ipairs(tbl) do
                    local valStr
                    if type(v) == "table" then
                        valStr = serialize(v, indent + 1)
                    elseif type(v) == "string" then
                        valStr = '"' .. v:gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
                    else
                        valStr = tostring(v)
                    end
                    table.insert(parts, nextSpaces .. valStr)
                end
            else
                for k, v in pairs(tbl) do
                    local keyStr
                    if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                        keyStr = k
                    else
                        keyStr = "[" .. (type(k) == "string" and ('"' .. k .. '"') or tostring(k)) .. "]"
                    end
                    
                    local valStr
                    if type(v) == "table" then
                        valStr = serialize(v, indent + 1)
                    elseif type(v) == "string" then
                        valStr = '"' .. v:gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
                    else
                        valStr = tostring(v)
                    end
                    
                    table.insert(parts, nextSpaces .. keyStr .. " = " .. valStr)
                end
            end
            
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. spaces .. "}"
        end
        
        return serialize(value, 0)
    end
end

local Theme = {
    Background = Color3.fromRGB(9, 9, 11),
    BackgroundSecondary = Color3.fromRGB(24, 24, 27),
    BackgroundTertiary = Color3.fromRGB(39, 39, 42),
    BackgroundHover = Color3.fromRGB(49, 49, 52),
    
    Border = Color3.fromRGB(39, 39, 42),
    BorderHover = Color3.fromRGB(63, 63, 70),
    BorderActive = Color3.fromRGB(82, 82, 91),
    
    TextPrimary = Color3.fromRGB(250, 250, 250),
    TextSecondary = Color3.fromRGB(161, 161, 170),
    TextMuted = Color3.fromRGB(113, 113, 122),
    TextDisabled = Color3.fromRGB(63, 63, 70),
    
    Primary = Color3.fromRGB(59, 130, 246),
    PrimaryHover = Color3.fromRGB(37, 99, 235),
    PrimaryMuted = Color3.fromRGB(30, 64, 175),
    Success = Color3.fromRGB(34, 197, 94),
    SuccessMuted = Color3.fromRGB(22, 101, 52),
    Warning = Color3.fromRGB(234, 179, 8),
    WarningMuted = Color3.fromRGB(133, 77, 14),
    Danger = Color3.fromRGB(239, 68, 68),
    DangerMuted = Color3.fromRGB(127, 29, 29),
    Purple = Color3.fromRGB(168, 85, 247),
    PurpleMuted = Color3.fromRGB(88, 28, 135),
    Cyan = Color3.fromRGB(34, 211, 238),
    CyanMuted = Color3.fromRGB(21, 94, 117),
    Orange = Color3.fromRGB(249, 115, 22),
    OrangeMuted = Color3.fromRGB(124, 45, 18),
    
    Shadow = Color3.fromRGB(0, 0, 0),
    
    
    Radius = {
        Window = 28, 
        Large = 14,
        Medium = 10,
        Small = 8,
        Chip = 12,
    },
    TitleBarHeight = 36,
    
    
    CornerRadius = UDim.new(0, 10),
    CornerRadiusSmall = UDim.new(0, 8),
    CornerRadiusLarge = UDim.new(0, 16),
    CornerRadiusFull = UDim.new(0, 999), 
    
    FontFamily = Enum.Font.GothamMedium,
    FontFamilyBold = Enum.Font.GothamBold,
    FontFamilyMono = Enum.Font.RobotoMono,
}

local TypeColors = {
    
    RemoteEvent = Theme.Orange,
    RemoteFunction = Theme.Purple,
    UnreliableRemoteEvent = Theme.Orange,
    BindableEvent = Theme.Orange,
    BindableFunction = Theme.Purple,
    ["RemoteEvent (Incoming)"] = Color3.fromRGB(255, 160, 80),
    ["RemoteFunction (Incoming)"] = Color3.fromRGB(200, 130, 255),
    ["UnreliableRemoteEvent (Incoming)"] = Color3.fromRGB(255, 160, 80),
    ["BindableEvent (Incoming)"] = Color3.fromRGB(255, 160, 80),
    ["BindableFunction (Incoming)"] = Color3.fromRGB(200, 130, 255),
    HttpGet = Theme.Warning,
    HttpPost = Theme.Warning,
    Request = Theme.Danger,
}

local TypeLabels = {
    RemoteEvent = "RE▲",
    RemoteFunction = "RF▲",
    UnreliableRemoteEvent = "URE▲",
    BindableEvent = "BE▲",
    BindableFunction = "BF▲",
    ["RemoteEvent (Incoming)"] = "RE▼",
    ["RemoteFunction (Incoming)"] = "RF▼",
    ["UnreliableRemoteEvent (Incoming)"] = "URE▼",
    ["BindableEvent (Incoming)"] = "BE▼",
    ["BindableFunction (Incoming)"] = "BF▼",
    HttpGet = "HTTP",
    HttpPost = "HTTP",
    Request = "REQ",
}

local TypeAssets = {
    RemoteEvent = "RemoteEvent.png",
    RemoteFunction = "RemoteFunction.png",
    UnreliableRemoteEvent = "UnreliableRemoteEvent.png",
    BindableEvent = "BindableEvent.png",
    BindableFunction = "BindableFunction.png",
}

local function getUIParent()
    local ok, hui = pcall(function()
        if getgenv then
            local env = getgenv()
            if type(env) == "table" and type(env.gethui) == "function" then
                return env.gethui()
            end
        end
        
        if type(gethui) == "function" then
            return gethui()
        end
        return nil
    end)
    if ok and hui then
        return safeCloneref(hui)
    end
    local coreGui = safeService("CoreGui")
    if coreGui then
        return coreGui
    end
    local player = LocalPlayer or (Players and safeCloneref(Players.LocalPlayer))
    if player then
        local playerGui = player:FindFirstChild("PlayerGui")
        if playerGui then
            return safeCloneref(playerGui)
        end
    end
    return nil
end

local function createInstance(className, properties, children)
    local instance = Instance.new(className)
    
    pcall(function()
        if instance:IsA("GuiObject") then
            instance.BorderSizePixel = 0
        end
    end)
    
    for prop, value in pairs(properties or {}) do
        if prop ~= "Parent" then
            instance[prop] = value
        end
    end
    
    for _, child in ipairs(children or {}) do
        child.Parent = instance
    end
    
    if properties and properties.Parent then
        instance.Parent = properties.Parent
    end
    
    return instance
end

local createCorner

local function createStroke(parent, color, thickness)
    return createInstance("UIStroke", {
        Color = color or Theme.Border,
        Thickness = thickness or 1,
        Parent = parent
    })
end

local function setSquircleOutline(entry, color, visible)
    if not entry then
        return
    end
    local outline = entry:FindFirstChild("SelectOutline")
    if not visible or not color then
        if outline then
            outline.Visible = false
        end
        local stroke = entry:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke:Destroy()
        end
        return
    end
    local stroke = entry:FindFirstChildOfClass("UIStroke")
    if stroke then
        stroke:Destroy()
    end
    if not outline then
        local radius = entry:GetAttribute("SquircleRadius") or Theme.Radius.Small
        outline = createSquircle(radius, "SquircleOutline", {
            Name = "SelectOutline",
            Size = UDim2.new(1, 0, 1, 0),
            ImageColor3 = color,
            ZIndex = 0,
            Parent = entry,
        }, false)
    else
        outline.ImageColor3 = color
        outline.Visible = true
    end
end

local SquircleShapeDefs = {
    Circle = {
        File = "squircle/circle.png",
        Fallback = "rbxassetid://111665032676235",
        LocalRect = Rect.new(310, 310, 714, 714),
        FallbackRect = Rect.new(310, 310, 714, 714),
        LocalRadius = 310,
        FallbackRadius = 310,
    },
    Squircle = {
        File = "squircle/squircle.png",
        Fallback = "rbxassetid://89641024074289",
        LocalRect = Rect.new(310, 310, 714, 714),
        FallbackRect = Rect.new(310, 310, 714, 714),
        LocalRadius = 310,
        FallbackRadius = 310,
    },
    SquircleOutline = {
        File = "squircle/squircle-outline.png",
        Fallback = "rbxassetid://74029063732681",
        LocalRect = Rect.new(310, 310, 714, 714),
        FallbackRect = Rect.new(310, 310, 714, 714),
        LocalRadius = 310,
        FallbackRadius = 310,
    },
    ["Squircle-TL-TR"] = {
        File = "squircle/squircle-tl-tr.png",
        Fallback = "rbxassetid://75712142040725",
        LocalRect = Rect.new(310, 310, 714, 714),
        FallbackRect = Rect.new(310, 310, 714, 714),
        LocalRadius = 310,
        FallbackRadius = 310,
    },
    ["Squircle-BL-BR"] = {
        File = "squircle/squircle-bl-br.png",
        Fallback = "rbxassetid://83676684425544",
        LocalRect = Rect.new(310, 310, 714, 714),
        FallbackRect = Rect.new(310, 310, 714, 714),
        LocalRadius = 310,
        FallbackRadius = 310,
    },
    
    Window = {
        File = "squircle/window.png",
        Fallback = "rbxassetid://89641024074289",
        LocalRect = Rect.new(420, 420, 604, 604),
        FallbackRect = Rect.new(310, 310, 714, 714),
        LocalRadius = 420,
        FallbackRadius = 310,
    },
    WindowOutline = {
        File = "squircle/window-outline.png",
        Fallback = "rbxassetid://74029063732681",
        LocalRect = Rect.new(420, 420, 604, 604),
        FallbackRect = Rect.new(310, 310, 714, 714),
        LocalRadius = 420,
        FallbackRadius = 310,
    },
    ["Window-TL-TR"] = {
        File = "squircle/window-tl-tr.png",
        Fallback = "rbxassetid://75712142040725",
        LocalRect = Rect.new(420, 420, 604, 604),
        FallbackRect = Rect.new(310, 310, 714, 714),
        LocalRadius = 420,
        FallbackRadius = 310,
    },
    ["Window-BL-BR"] = {
        File = "squircle/window-bl-br.png",
        Fallback = "rbxassetid://83676684425544",
        LocalRect = Rect.new(420, 420, 604, 604),
        FallbackRect = Rect.new(310, 310, 714, 714),
        LocalRadius = 420,
        FallbackRadius = 310,
    },
}

local SquircleShapes = {} 

local function resolveRadiusPx(radius)
    if typeof(radius) == "UDim" then
        return radius.Offset
    end
    return tonumber(radius) or Theme.Radius.Medium
end

local function getSquircleShape(shapeType)
    local cached = SquircleShapes[shapeType]
    if cached then
        return cached
    end
    local def = SquircleShapeDefs[shapeType] or SquircleShapeDefs.Squircle
    
    
    local localImage = getAssetImage(def.File)
    local useLocal = type(localImage) == "string" and localImage ~= ""
    if not useLocal and (type(def.Fallback) ~= "string" or def.Fallback == "") then
        useLocal = false
    end
    cached = {
        Image = useLocal and localImage or def.Fallback,
        Rect = useLocal and def.LocalRect or def.FallbackRect,
        Radius = useLocal and def.LocalRadius or def.FallbackRadius,
        File = def.File,
        Source = useLocal and "local" or "cdn",
    }
    SquircleShapes[shapeType] = cached
    return cached
end

local function measureTextWidth(text, textSize, font)
    text = tostring(text or "")
    textSize = textSize or 11
    font = font or Theme.FontFamily
    if TextService then
        local ok, bounds = pcall(function()
            return TextService:GetTextSize(text, textSize, font, Vector2.new(10000, textSize + 8))
        end)
        if ok and bounds then
            return math.ceil(bounds.X)
        end
    end
    return math.max(8, math.ceil(#text * textSize * 0.55))
end

local function createSquircle(radius, shapeType, props, interactive)
    props = props or {}
    shapeType = shapeType or "Squircle"
    local shape = getSquircleShape(shapeType)
    local radiusPx = math.clamp(resolveRadiusPx(radius), 0.5, shape.Radius)
    local className = interactive and "ImageButton" or "ImageLabel"
    local sliceScale = math.clamp(radiusPx / shape.Radius, 0.0001, 1)

    local defaults = {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = shape.Image,
        ImageColor3 = props.ImageColor3 or Theme.BackgroundTertiary,
        ImageTransparency = props.ImageTransparency or 0,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = shape.Rect,
        SliceScale = sliceScale,
    }
    if interactive then
        defaults.AutoButtonColor = false
        defaults.Active = true
    end

    for key, value in pairs(props) do
        if key ~= "Parent"
            and key ~= "OutlineColor"
            and key ~= "OutlineTransparency"
            and key ~= "Interactive"
            and key ~= "AutomaticSize" 
        then
            defaults[key] = value
        end
    end

    
    local parent = props.Parent
    defaults.Parent = nil

    local ok, inst = pcall(function()
        return createInstance(className, defaults)
    end)
    if not ok or not inst then
        
        local fallbackProps = {
            BackgroundColor3 = props.ImageColor3 or Theme.BackgroundTertiary,
            BackgroundTransparency = props.ImageTransparency or 0,
            BorderSizePixel = 0,
            Size = props.Size or UDim2.new(0, 40, 0, 40),
            Position = props.Position,
            AnchorPoint = props.AnchorPoint,
            ZIndex = props.ZIndex,
            Name = props.Name,
        }
        if interactive then
            fallbackProps.Text = ""
            fallbackProps.AutoButtonColor = false
            inst = createInstance("TextButton", fallbackProps)
        else
            inst = createInstance("Frame", fallbackProps)
        end
        createCorner(inst, UDim.new(0, math.floor(radiusPx)))
    end

    pcall(function()
        inst:SetAttribute("SquircleRadius", radiusPx)
        inst:SetAttribute("SquircleType", shapeType)
    end)

    if parent then
        inst.Parent = parent
    end
    return inst
end

local function createPanel(radius, props, withOutline)
    props = props or {}
    local autoSize = props.AutomaticSize
    local parent = props.Parent
    local plateProps = {}
    for k, v in pairs(props) do
        plateProps[k] = v
    end
    plateProps.AutomaticSize = nil

    local contentParent
    if autoSize then
        local wrap = createInstance("Frame", {
            Name = props.Name and (props.Name .. "Wrap") or "PanelWrap",
            Size = props.Size or UDim2.new(1, 0, 0, 0),
            AutomaticSize = autoSize,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = props.LayoutOrder,
            ZIndex = props.ZIndex,
            Parent = parent,
        })
        plateProps.Parent = wrap
        plateProps.Size = UDim2.new(1, 0, 1, 0)
        plateProps.Position = nil
        plateProps.LayoutOrder = nil
        local plate = createSquircle(radius, "Squircle", plateProps, props.Interactive == true)
        local outline = nil
        if withOutline ~= false then
            outline = createSquircle(radius, "SquircleOutline", {
                Name = "Outline",
                Size = UDim2.new(1, 0, 1, 0),
                ImageColor3 = props.OutlineColor or Theme.Border,
                ImageTransparency = props.OutlineTransparency or 0,
                ZIndex = 0,
                Parent = plate,
            }, false)
        end
        contentParent = createInstance("Frame", {
            Name = "Content",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = autoSize,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 2,
            Parent = wrap,
        })
        
        contentParent:SetAttribute("SquircleType", "PanelContent")
        plate:SetAttribute("SquirclePanel", true)
        return contentParent, outline, plate
    end

    local plate = createSquircle(radius, "Squircle", plateProps, props.Interactive == true)
    local outline = nil
    if withOutline ~= false then
        outline = createSquircle(radius, "SquircleOutline", {
            Name = "Outline",
            Size = UDim2.new(1, 0, 1, 0),
            ImageColor3 = props.OutlineColor or Theme.Border,
            ImageTransparency = props.OutlineTransparency or 0,
            ZIndex = props.ZIndex or 1,
            Parent = plate,
        }, false)
    end
    return plate, outline
end

local function setSquircleRadius(inst, radius)
    if not inst then
        return
    end
    local shapeType = inst:GetAttribute("SquircleType") or "Squircle"
    local shape = getSquircleShape(shapeType)
    local radiusPx = math.max(resolveRadiusPx(radius), 0.0001)
    inst.SliceScale = radiusPx / shape.Radius
    inst:SetAttribute("SquircleRadius", radiusPx)
end

local function setSquircleColor(inst, color)
    if inst and (inst:IsA("ImageLabel") or inst:IsA("ImageButton")) then
        inst.ImageColor3 = color
    elseif inst then
        inst.BackgroundColor3 = color
    end
end

local function isSquircle(inst)
    return inst ~= nil and inst:GetAttribute("SquircleType") ~= nil
end

local function getSurfaceFill(inst)
    if not inst then
        return nil, false
    end
    if isSquircle(inst) then
        return inst, true
    end
    local fill = inst:FindFirstChild("G2Fill")
    if fill and (fill:IsA("ImageLabel") or fill:IsA("ImageButton")) then
        return fill, true
    end
    return inst, false
end

local function setSurfaceColor(inst, color)
    local fill, isImage = getSurfaceFill(inst)
    if not fill then
        return
    end
    if isImage then
        fill.ImageColor3 = color
    else
        fill.BackgroundColor3 = color
    end
end

local function setSurfaceTransparency(inst, transparency)
    local fill, isImage = getSurfaceFill(inst)
    if not fill then
        return
    end
    if isImage then
        fill.ImageTransparency = transparency
    else
        fill.BackgroundTransparency = transparency
    end
end

local function isLayoutChromeChild(child)
    if not child then
        return true
    end
    local name = child.Name
    if name == "G2Fill" or name == "G2Content" then
        return true
    end
    return child:IsA("UIStroke")
        or child:IsA("UIGradient")
        or child:IsA("UICorner")
        or child:IsA("UIAspectRatioConstraint")
        or child:IsA("UISizeConstraint")
        or child:IsA("UIScale")
end

local function getG2Content(parent)
    if not parent then
        return nil
    end
    local host = parent:FindFirstChild("G2Content")
    if host then
        return host
    end
    return parent
end

local function _resolveCornerSize(parent)
    local w = parent.Size and parent.Size.X.Offset or 0
    local h = parent.Size and parent.Size.Y.Offset or 0
    if w <= 0 or h <= 0 then
        local abs = parent.AbsoluteSize
        if abs then
            if w <= 0 and abs.X > 0 then
                w = abs.X
            end
            if h <= 0 and abs.Y > 0 then
                h = abs.Y
            end
        end
    end
    return w, h
end

createCorner = function(parent, radius)
    if not parent then
        return nil
    end
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("UICorner") or child.Name == "G2Fill" or child.Name == "G2Content" then
            child:Destroy()
        end
    end

    local radiusPx = resolveRadiusPx(radius or Theme.CornerRadius)
    local w, h = _resolveCornerSize(parent)
    local minSide = math.min(w > 0 and w or 1e9, h > 0 and h or 1e9)
    local isSquare = w > 0 and h > 0 and math.abs(w - h) <= 1
    
    local isPillOrCircle = radiusPx >= 64
        or (isSquare and radiusPx >= minSide * 0.45)
        or (w > 0 and h > 0 and radiusPx >= minSide * 0.5 - 0.5)

    local autoSize = Enum.AutomaticSize.None
    pcall(function()
        autoSize = parent.AutomaticSize
    end)

    if isPillOrCircle or autoSize ~= Enum.AutomaticSize.None then
        parent:SetAttribute("HasG2Fill", false)
        local uiR = isPillOrCircle and 999 or math.floor(math.clamp(radiusPx, 1, 64))
        return createInstance("UICorner", {
            CornerRadius = UDim.new(0, uiR),
            Parent = parent,
        })
    end

    local color = parent.BackgroundColor3
    local transparency = parent.BackgroundTransparency
    parent.BackgroundTransparency = 1

    local plate = createSquircle(radiusPx, "Squircle", {
        Name = "G2Fill",
        Size = UDim2.new(1, 0, 1, 0),
        ImageColor3 = color,
        ImageTransparency = transparency,
        ZIndex = 0,
        Parent = parent,
    }, false)

    local host = createInstance("Frame", {
        Name = "G2Content",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = math.max(1, parent.ZIndex or 1),
        Parent = parent,
    })

    for _, child in ipairs(parent:GetChildren()) do
        if child ~= plate and child ~= host and not isLayoutChromeChild(child) then
            child.Parent = host
        end
    end

    if not parent:GetAttribute("G2ReparentHooked") then
        parent:SetAttribute("G2ReparentHooked", true)
        parent.ChildAdded:Connect(function(child)
            if child.Parent ~= parent or isLayoutChromeChild(child) then
                return
            end
            local content = parent:FindFirstChild("G2Content")
            if not content then
                return
            end
            if child:IsA("UIListLayout")
                or child:IsA("UIGridLayout")
                or child:IsA("UIPageLayout")
                or child:IsA("UITableLayout")
                or child:IsA("UIPadding")
                or child:IsA("GuiObject")
            then
                task.defer(function()
                    if child.Parent == parent and content.Parent == parent then
                        child.Parent = content
                    end
                end)
            end
        end)
    end

    parent:SetAttribute("HasG2Fill", true)
    return plate, host
end

local function createAssetGlyph(parent, fileName, sizePx, props)
    props = props or {}
    sizePx = sizePx or 12
    local icon = createInstance("ImageLabel", {
        Name = props.Name or "AssetGlyph",
        Size = UDim2.new(0, sizePx, 0, sizePx),
        Position = props.Position,
        AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Image = "",
        ImageColor3 = props.ImageColor3 or Color3.new(1, 1, 1),
        ImageTransparency = props.ImageTransparency or 0,
        ScaleType = Enum.ScaleType.Fit,
        Rotation = props.Rotation or 0,
        Visible = props.Visible ~= false,
        ZIndex = props.ZIndex or 2,
        Parent = parent,
    })
    local url = getAssetImage(fileName)
    if url then
        icon.Image = url
    end
    return icon
end

-- DexPlusPlus NewDark class icons live in asset/instance/<ClassName>.png
local DEX_NEWDARK = {
    Image = "rbxassetid://135148380892747", -- source sheet id (tiles extracted locally)
    IconSize = 32,
    Columns = 18,
    Dir = "instance",
}

local DEX_NEWDARK_INDEX = {
    Accessory = 1,
    Actor = 2,
    AdGui = 3,
    AdPortal = 4,
    AirController = 5,
    AlignOrientation = 6,
    AlignPosition = 7,
    AngularVelocity = 8,
    Animation = 9,
    AnimationConstraint = 10,
    AnimationController = 11,
    AnimationFromVideoCreatorService = 12,
    Animator = 13,
    ArcHandles = 14,
    Atmosphere = 15,
    Attachment = 16,
    AudioAnalyzer = 17,
    AudioChannelMixer = 18,
    AudioChannelSplitter = 19,
    AudioChorus = 20,
    AudioCompressor = 21,
    AudioDeviceInput = 22,
    AudioDeviceOutput = 23,
    AudioDistortion = 24,
    AudioEcho = 25,
    AudioEmitter = 26,
    AudioEqualizer = 27,
    AudioFader = 28,
    AudioFilter = 29,
    AudioFlanger = 30,
    AudioGate = 31,
    AudioLimiter = 32,
    AudioListener = 33,
    AudioPitchShifter = 34,
    AudioPlayer = 35,
    AudioRecorder = 36,
    AudioReverb = 37,
    AudioTextToSpeech = 38,
    AuroraScript = 39,
    AvatarEditorService = 40,
    AvatarSettings = 41,
    Backpack = 42,
    BallSocketConstraint = 43,
    BasePlate = 44,
    Beam = 45,
    BillboardGui = 46,
    BindableEvent = 47,
    BindableFunction = 48,
    BlockMesh = 49,
    BloomEffect = 50,
    BlurEffect = 51,
    BodyAngularVelocity = 52,
    BodyColors = 53,
    BodyForce = 54,
    BodyGyro = 55,
    BodyPosition = 56,
    BodyThrust = 57,
    BodyVelocity = 58,
    Bone = 59,
    BoolValue = 60,
    BoxHandleAdornment = 61,
    Breakpoint = 62,
    BrickColorValue = 63,
    BubbleChatConfiguration = 64,
    Buggaroo = 65,
    CFrameValue = 68,
    Camera = 66,
    CanvasGroup = 67,
    ChannelTabsConfiguration = 69,
    CharacterControllerManager = 70,
    CharacterMesh = 71,
    Chat = 72,
    ChatInputBarConfiguration = 73,
    ChatWindowConfiguration = 74,
    ChorusSoundEffect = 75,
    Class = 76,
    Cleanup = 77,
    ClickDetector = 78,
    ClientReplicator = 79,
    ClimbController = 80,
    Clouds = 81,
    Color = 82,
    Color3Value = 284,
    ColorCorrectionEffect = 83,
    CompressorSoundEffect = 84,
    ConeHandleAdornment = 85,
    Configuration = 86,
    Constant = 87,
    Constructor = 88,
    Controller = 89,
    CoreGui = 90,
    CornerWedgePart = 91,
    CylinderHandleAdornment = 92,
    CylindricalConstraint = 93,
    Decal = 94,
    DepthOfFieldEffect = 95,
    Dialog = 96,
    DialogChoice = 97,
    DistortionSoundEffect = 98,
    DragDetector = 99,
    EchoSoundEffect = 100,
    EditableImage = 101,
    EditableMesh = 102,
    Enum = 103,
    EnumMember = 104,
    EqualizerSoundEffect = 105,
    Event = 106,
    Explosion = 107,
    FaceControls = 108,
    Field = 109,
    File = 110,
    Fire = 111,
    FlangeSoundEffect = 112,
    Folder = 113,
    ForceField = 114,
    Frame = 115,
    Function = 116,
    GameSettings = 117,
    GroundController = 118,
    Handles = 119,
    HapticEffect = 120,
    HapticService = 121,
    HeightmapImporterService = 122,
    Highlight = 123,
    HingeConstraint = 124,
    Humanoid = 125,
    HumanoidDescription = 126,
    IKControl = 127,
    ImageButton = 128,
    ImageHandleAdornment = 129,
    ImageLabel = 130,
    InputAction = 131,
    InputBinding = 132,
    InputContext = 133,
    IntValue = 284,
    Interface = 134,
    IntersectOperation = 135,
    Keyword = 136,
    Lighting = 137,
    LineForce = 139,
    LineHandleAdornment = 140,
    LinearVelocity = 138,
    LocalFile = 141,
    LocalScript = 144,
    LocalizationService = 142,
    LocalizationTable = 143,
    MaterialService = 145,
    MaterialVariant = 146,
    MemoryStoreService = 147,
    MeshPart = 148,
    Meshparts = 149,
    MessagingService = 150,
    Method = 151,
    Model = 152,
    Modelgroups = 153,
    Module = 154,
    ModuleScript = 155,
    Motor6D = 156,
    NegateOperation = 157,
    NetworkClient = 158,
    NoCollisionConstraint = 159,
    NumberValue = 284,
    ObjectValue = 284,
    Operator = 160,
    PackageLink = 161,
    Pants = 162,
    Part = 163,
    ParticleEmitter = 164,
    Path2D = 165,
    PathfindingLink = 166,
    PathfindingModifier = 167,
    PathfindingService = 168,
    PitchShiftSoundEffect = 169,
    Place = 170,
    Placeholder = 171,
    Plane = 172,
    PlaneConstraint = 173,
    Player = 174,
    Players = 175,
    PluginGuiService = 176,
    PointLight = 177,
    PrismaticConstraint = 178,
    Property = 179,
    ProximityPrompt = 180,
    PublishService = 181,
    RayValue = 284,
    Reference = 182,
    RemoteEvent = 183,
    RemoteFunction = 184,
    RenderingTest = 185,
    ReplicatedFirst = 186,
    ReplicatedScriptService = 187,
    ReplicatedStorage = 188,
    ReverbSoundEffect = 189,
    RigidConstraint = 190,
    RobloxPluginGuiService = 191,
    RocketPropulsion = 192,
    RodConstraint = 193,
    RopeConstraint = 194,
    Rotate = 195,
    ScreenGui = 196,
    Script = 197,
    ScrollingFrame = 198,
    Seat = 199,
    Selected_Workspace = 200,
    SelectionBox = 201,
    SelectionSphere = 202,
    ServerScriptService = 203,
    ServerStorage = 204,
    Service = 205,
    Shirt = 206,
    ShirtGraphic = 207,
    SkinnedMeshPart = 208,
    Sky = 209,
    Smoke = 210,
    Snap = 211,
    Snippet = 212,
    SocialService = 213,
    Sound = 214,
    SoundEffect = 215,
    SoundGroup = 216,
    SoundService = 217,
    Sparkles = 218,
    SpawnLocation = 219,
    SpecialMesh = 220,
    SphereHandleAdornment = 221,
    SpotLight = 222,
    SpringConstraint = 223,
    StandalonePluginScripts = 224,
    StarterCharacterScripts = 225,
    StarterGui = 226,
    StarterPack = 227,
    StarterPlayer = 228,
    StarterPlayerScripts = 229,
    StringValue = 284,
    Struct = 230,
    StyleDerive = 231,
    StyleLink = 232,
    StyleRule = 233,
    StyleSheet = 234,
    SunRaysEffect = 235,
    SurfaceAppearance = 236,
    SurfaceGui = 237,
    SurfaceLight = 238,
    SurfaceSelection = 239,
    SwimController = 240,
    TaskScheduler = 241,
    Team = 242,
    Teams = 243,
    Terrain = 244,
    TerrainDetail = 245,
    TestService = 246,
    TextBox = 247,
    TextBoxService = 248,
    TextButton = 249,
    TextChannel = 250,
    TextChatCommand = 251,
    TextChatService = 252,
    TextLabel = 253,
    TextString = 254,
    Texture = 255,
    Tool = 256,
    Torque = 257,
    TorsionSpringConstraint = 258,
    Trail = 259,
    TremoloSoundEffect = 260,
    TrussPart = 261,
    TypeParameter = 262,
    UGCValidationService = 263,
    UIAspectRatioConstraint = 264,
    UICorner = 265,
    UIDragDetector = 266,
    UIFlexItem = 267,
    UIGradient = 268,
    UIGridLayout = 269,
    UIListLayout = 270,
    UIPadding = 271,
    UIPageLayout = 272,
    UIScale = 273,
    UISizeConstraint = 274,
    UIStroke = 275,
    UITableLayout = 276,
    UITextSizeConstraint = 277,
    UnionOperation = 278,
    Unit = 279,
    UniversalConstraint = 280,
    UnreliableRemoteEvent = 281,
    UpdateAvailable = 282,
    UserService = 283,
    VRService = 296,
    Value = 284,
    Variable = 285,
    Vector3Value = 284,
    VectorForce = 286,
    VehicleSeat = 287,
    VideoDisplay = 288,
    VideoFrame = 289,
    VideoPlayer = 290,
    ViewportFrame = 291,
    VirtualUser = 292,
    VoiceChannel = 293,
    VoiceChatService = 295,
    Voicechat = 294,
    WedgePart = 297,
    Weld = 298,
    WeldConstraint = 299,
    Wire = 300,
    WireframeHandleAdornment = 301,
    Workspace = 302,
    WorldModel = 303,
    WrapDeformer = 304,
    WrapLayer = 305,
    WrapTarget = 306,
}

local function classIconFile(className)
    local name = className
    if type(name) ~= "string" or name == "" or not DEX_NEWDARK_INDEX[name] then
        name = "Placeholder"
    end
    return DEX_NEWDARK.Dir .. "/" .. name .. ".png"
end

local function createClassIcon(parent, className, sizePx, props)
    props = props or {}
    sizePx = sizePx or 14
    local fileName = classIconFile(className)
    local url = getAssetImage(fileName) or getAssetImage(classIconFile("Placeholder"))
    local icon = createInstance("ImageLabel", {
        Name = props.Name or "ClassIcon",
        Size = UDim2.new(0, sizePx, 0, sizePx),
        Position = props.Position,
        AnchorPoint = props.AnchorPoint or Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Image = url or "",
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = props.ZIndex or 2,
        Parent = parent,
    })
    return icon
end

local MODULE_TREE_ARROW_WIDTH = 12

local function moduleTreeArrowRotation(isExpanded)
    return isExpanded and 180 or 90
end

local function createModuleTreeArrow(parent, isExpanded, layout)
    
    local host = createInstance("Frame", {
        Name = "TreeArrow",
        Size = UDim2.new(0, 8, 0, 8),
        Position = UDim2.new(0, layout.arrow + MODULE_TREE_ARROW_WIDTH * 0.5, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Rotation = moduleTreeArrowRotation(isExpanded),
        ZIndex = 2,
        Parent = parent,
    })
    createAssetGlyph(host, "triangle.png", 8, {
        Name = "Glyph",
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ImageColor3 = Theme.TextMuted,
        Rotation = 0,
        ZIndex = 2,
    })
    return host
end

local function setModuleTreeArrowExpanded(arrow, isExpanded)
    if not arrow or not arrow:IsA("GuiObject") then
        return
    end
    arrow.Rotation = moduleTreeArrowRotation(isExpanded)
end

local function createTypeIcon(parent, typeName, sizePx, position)
    sizePx = sizePx or 18
    local assetFile = TypeAssets[typeName]
    local icon = createInstance("ImageLabel", {
        Name = "TypeIcon",
        Size = UDim2.new(0, sizePx, 0, sizePx),
        Position = position or UDim2.new(0, 6, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Image = "",
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 2,
        Parent = parent,
    })
    local fallback = createInstance("TextLabel", {
        Name = "TypeFallback",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = (TypeLabels[typeName] or tostring(typeName or "?")):gsub("[▲▼⇅]", ""),
        TextColor3 = TypeColors[typeName] or Theme.TextMuted,
        TextSize = math.max(8, sizePx - 8),
        Font = Theme.FontFamilyBold,
        Visible = false,
        ZIndex = 3,
        Parent = icon,
    })
    if assetFile then
        applyAssetIcon(icon, assetFile, fallback)
    else
        fallback.Visible = true
    end
    return icon
end

local function createPadding(parent, padding, left, right, top, bottom)
    parent = getG2Content(parent)
    return createInstance("UIPadding", {
        PaddingTop = UDim.new(0, top or padding or 12),
        PaddingBottom = UDim.new(0, bottom or padding or 12),
        PaddingLeft = UDim.new(0, left or padding or 12),
        PaddingRight = UDim.new(0, right or padding or 12),
        Parent = parent
    })
end

local function createListLayout(parent, padding, direction, hAlign, vAlign)
    parent = getG2Content(parent)
    return createInstance("UIListLayout", {
        Padding = UDim.new(0, padding or 8),
        FillDirection = direction or Enum.FillDirection.Vertical,
        HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
        VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = parent
    })
end

local function createGridLayout(parent, cellSize, padding)
    return createInstance("UIGridLayout", {
        CellSize = cellSize or UDim2.new(0, 100, 0, 30),
        CellPadding = UDim2.new(0, padding or 8, 0, padding or 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = parent
    })
end

local function tween(instance, properties, duration, style, direction)
    local tweenInfo = TweenInfo.new(
        duration or 0.2,
        style or Enum.EasingStyle.Quart,
        direction or Enum.EasingDirection.Out
    )
    if not instance or type(properties) ~= "table" then
        return nil
    end

    local fill, isImage = getSurfaceFill(instance)
    if isImage and fill then
        local mapped = {}
        for key, value in pairs(properties) do
            if key == "BackgroundTransparency" then
                mapped.ImageTransparency = value
            elseif key == "BackgroundColor3" then
                mapped.ImageColor3 = value
            else
                mapped[key] = value
            end
        end

        if fill ~= instance then
            local fillProps, hostProps = {}, {}
            for key, value in pairs(mapped) do
                if key == "ImageTransparency" or key == "ImageColor3" then
                    fillProps[key] = value
                else
                    hostProps[key] = value
                end
            end
            local lastTween = nil
            if next(fillProps) then
                lastTween = TweenService:Create(fill, tweenInfo, fillProps)
                lastTween:Play()
            end
            if next(hostProps) then
                lastTween = TweenService:Create(instance, tweenInfo, hostProps)
                lastTween:Play()
            end
            return lastTween
        end

        local t = TweenService:Create(instance, tweenInfo, mapped)
        t:Play()
        return t
    end

    local t = TweenService:Create(instance, tweenInfo, properties)
    t:Play()
    return t
end

local function createSplitResizer(parent, orientation, position, zIndex)
    local isVertical = orientation == "vertical"
    local hit = createInstance("TextButton", {
        Name = isVertical and "VerticalResizer" or "HorizontalResizer",
        Size = isVertical and UDim2.new(0, 10, 1, 0) or UDim2.new(1, 0, 0, 10),
        Position = position,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = zIndex or 5,
        Parent = parent,
    })
    local grip = createSquircle(Theme.Radius.Chip, "Squircle", {
        Name = "Grip",
        Size = isVertical and UDim2.new(0, 3, 0, 48) or UDim2.new(0, 48, 0, 3),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ImageColor3 = Theme.Border,
        ImageTransparency = 0.25,
        Parent = hit,
    }, false)
    hit.MouseEnter:Connect(function()
        tween(grip, {ImageColor3 = Theme.Primary, ImageTransparency = 0}, 0.15)
    end)
    hit.MouseLeave:Connect(function()
        tween(grip, {ImageColor3 = Theme.Border, ImageTransparency = 0.25}, 0.15)
    end)
    return hit, grip
end

local function deepCopy(original)
    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            copy[k] = deepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

if not parse then
    parse = function(value)
        local t = typeof(value)
        if t == "table" then
            local success, result = pcall(function()
                return HttpService:JSONEncode(value)
            end)
            if success then
                return result
            end
            return "{...}"
        else
            return tostring(value)
        end
    end
end

local resolveModuleByPath

local function isUsablePathExpr(path)
    return type(path) == "string"
        and path ~= ""
        and not path:find("nil %-%-%[%[", 1, false)
end

local function buildPathFromDottedName(fullName)
    if type(fullName) ~= "string" or fullName == "" then
        return nil
    end
    if fullName:sub(1, 4) == "game" then
        return fullName
    end
    local parts = {}
    for part in fullName:gmatch("[^%.]+") do
        parts[#parts + 1] = part
    end
    if #parts == 0 then
        return nil
    end
    local expr = 'game:GetService("' .. parts[1] .. '")'
    for i = 2, #parts do
        local part = parts[i]
        if part:match("^[%a_][%w_]*$") then
            expr = expr .. "." .. part
        else
            expr = expr .. '["' .. part:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"]'
        end
    end
    return expr
end

local function resolveInstanceFromDottedName(fullName)
    if type(fullName) ~= "string" or fullName == "" then
        return nil
    end
    local parts = {}
    for part in fullName:gmatch("[^%.]+") do
        parts[#parts + 1] = part
    end
    if #parts == 0 then
        return nil
    end
    local current
    local okSvc, svc = pcall(function()
        return game:GetService(parts[1])
    end)
    if okSvc and typeof(svc) == "Instance" then
        current = svc
    else
        current = game:FindFirstChild(parts[1])
    end
    if not current then
        return nil
    end
    for i = 2, #parts do
        local child = current:FindFirstChild(parts[i])
        if not child then
            return nil
        end
        current = child
    end
    return current
end

local function formatRobloxPath(pathOrInstance)
    if typeof(pathOrInstance) == "Instance" then
        if getInstancePathFromParser then
            local ok, path = pcall(getInstancePathFromParser, pathOrInstance)
            if ok and isUsablePathExpr(path) then
                return path
            end
        end
        local fullName
        pcall(function()
            fullName = pathOrInstance:GetFullName()
        end)
        return buildPathFromDottedName(fullName) or "nil"
    end

    if type(pathOrInstance) == "string" and pathOrInstance ~= "" then
        if pathOrInstance:sub(1, 4) == "game" then
            return pathOrInstance
        end
        if resolveModuleByPath then
            local mod = resolveModuleByPath(pathOrInstance)
            if mod and typeof(mod.Module) == "Instance" then
                return formatRobloxPath(mod.Module)
            end
        end
        local live = resolveInstanceFromDottedName(pathOrInstance)
        if live then
            return formatRobloxPath(live)
        end
        return buildPathFromDottedName(pathOrInstance) or "nil"
    end

    return "nil"
end

local function formatInstancePath(instance)
    if typeof(instance) == "Instance" then
        return formatRobloxPath(instance)
    end
    if type(instance) == "string" then
        return formatRobloxPath(instance)
    end
    return "nil"
end

local function serializeValue(value, depth)
    depth = depth or 0
    if depth > 5 then return "..." end
    
    local t = typeof(value)
    
    if t == "table" then
        local success, result = pcall(function()
            return parse(value)
        end)
        if success and result then
            return result
        end
        return "{...}"
    end
    
    if t == "string" then
        local escaped = value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
        return '"' .. escaped .. '"'
    elseif t == "number" then
        if value == math.huge then return "math.huge"
        elseif value == -math.huge then return "-math.huge"
        elseif value ~= value then return "0/0"
        else return tostring(value) end
    elseif t == "boolean" then
        return tostring(value)
    elseif t == "nil" then
        return "nil"
    elseif t == "Instance" then
        if getInstancePathFromParser then
            local ok, pathStr = pcall(getInstancePathFromParser, value)
            if ok and pathStr and pathStr ~= "" then
                return pathStr
            end
        end
        return formatRobloxPath(value)
    elseif t == "Vector3" then
        return string.format("Vector3.new(%s, %s, %s)", value.X, value.Y, value.Z)
    elseif t == "Vector2" then
        return string.format("Vector2.new(%s, %s)", value.X, value.Y)
    elseif t == "CFrame" then
        local components = {value:GetComponents()}
        return string.format("CFrame.new(%s)", table.concat(components, ", "))
    elseif t == "Color3" then
        return string.format("Color3.fromRGB(%d, %d, %d)", 
            math.floor(value.R * 255), 
            math.floor(value.G * 255), 
            math.floor(value.B * 255))
    elseif t == "BrickColor" then
        return string.format('BrickColor.new("%s")', value.Name)
    elseif t == "UDim" then
        return string.format("UDim.new(%s, %s)", value.Scale, value.Offset)
    elseif t == "UDim2" then
        return string.format("UDim2.new(%s, %s, %s, %s)", 
            value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset)
    elseif t == "Rect" then
        return string.format("Rect.new(%s, %s, %s, %s)", 
            value.Min.X, value.Min.Y, value.Max.X, value.Max.Y)
    elseif t == "Ray" then
        return string.format("Ray.new(Vector3.new(%s, %s, %s), Vector3.new(%s, %s, %s))",
            value.Origin.X, value.Origin.Y, value.Origin.Z,
            value.Direction.X, value.Direction.Y, value.Direction.Z)
    elseif t == "Region3" then
        return "Region3.new(...)"
    elseif t == "NumberSequence" then
        local keypoints = {}
        for _, kp in ipairs(value.Keypoints) do
            table.insert(keypoints, string.format("NumberSequenceKeypoint.new(%s, %s)", kp.Time, kp.Value))
        end
        return "NumberSequence.new({" .. table.concat(keypoints, ", ") .. "})"
    elseif t == "ColorSequence" then
        local keypoints = {}
        for _, kp in ipairs(value.Keypoints) do
            table.insert(keypoints, string.format("ColorSequenceKeypoint.new(%s, %s)", 
                kp.Time, serializeValue(kp.Value)))
        end
        return "ColorSequence.new({" .. table.concat(keypoints, ", ") .. "})"
    elseif t == "NumberRange" then
        return string.format("NumberRange.new(%s, %s)", value.Min, value.Max)
    elseif t == "Enum" then
        return tostring(value)
    elseif t == "EnumItem" then
        return tostring(value)
    elseif t == "function" then
        return "function() end"
    elseif t == "thread" then
        return "coroutine.create(function() end)"
    elseif t == "userdata" then
        return "newproxy(true)"
    elseif t == "buffer" then
        return "buffer.create(0)"
    else
        return "nil --[[ " .. t .. " ]]"
    end
end

local function formatValue(value)
    local t = typeof(value)
    
    if t == "string" then
        local display = value:sub(1, 60)
        if value:len() > 60 then display = display .. "..." end
        return '"' .. display:gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t") .. '"'
    elseif t == "Instance" then
        return value.Name .. " (" .. value.ClassName .. ")"
    elseif t == "table" then
        local count = 0
        for _ in pairs(value) do count = count + 1 end
        return "{" .. count .. " items}"
    elseif t == "function" then
        return "function()"
    elseif t == "Vector3" then
        return string.format("Vector3(%.1f, %.1f, %.1f)", value.X, value.Y, value.Z)
    elseif t == "CFrame" then
        return string.format("CFrame(%.1f, %.1f, %.1f)", value.X, value.Y, value.Z)
    elseif t == "Color3" then
        return string.format("RGB(%d, %d, %d)", 
            math.floor(value.R * 255), 
            math.floor(value.G * 255), 
            math.floor(value.B * 255))
    else
        local str = tostring(value)
        if #str > 50 then
            return str:sub(1, 47) .. "..."
        end
        return str
    end
end

local SNAPSHOT_MAX_DEPTH = 8
local FINGERPRINT_MAX_DEPTH = 4
local FINGERPRINT_MAX_KEYS = 24
local FINGERPRINT_MAX_STRING = 96

local InstancePathCache = setmetatable({}, {__mode = "k"})

local function getCachedInstancePath(inst)
    if typeof(inst) ~= "Instance" then
        return ""
    end
    local cached = InstancePathCache[inst]
    if cached ~= nil then
        return cached
    end
    local path = ""
    local ok, fullName = pcall(function()
        return inst:GetFullName()
    end)
    if ok and type(fullName) == "string" then
        path = fullName
    end
    InstancePathCache[inst] = path
    return path
end

local function captureArgumentSnapshot(value, depth, eager)
    depth = depth or 0
    local t = typeof(value)
    local snapshot = {
        Type = t,
        Display = nil,
        Preview = nil,
        Serialized = nil,
        _eager = eager and true or nil,
    }

    if t == "Instance" then
        local name, className
        local fullName = getCachedInstancePath(value)
        pcall(function()
            name = value.Name
            className = value.ClassName
        end)
        snapshot.Path = fullName
        snapshot.Name = name
        snapshot.ClassName = className
        snapshot.Preview = (name and className) and (name .. " (" .. className .. ")") or "Instance"
        if eager then
            snapshot.Display = serializeValue(value, 0)
            snapshot.Serialized = snapshot.Display
        end
    elseif t == "table" then
        if depth >= SNAPSHOT_MAX_DEPTH then
            snapshot.Preview = "{...}"
            if eager then
                snapshot.Display = "{...}"
                snapshot.Serialized = "{}"
            end
        else
            local count = 0
            for _ in pairs(value) do
                count = count + 1
                if count > 999 then
                    break
                end
            end
            snapshot.Preview = "{" .. count .. (count > 999 and "+" or "") .. " items}"
            if eager then
                local success, result = pcall(function()
                    return parse(value)
                end)
                snapshot.Display = (success and result) or "{...}"
                snapshot.Serialized = snapshot.Display
            end
        end
    else
        snapshot.Preview = formatValue(value)
        if eager then
            snapshot.Display = serializeValue(value, 0)
            snapshot.Serialized = snapshot.Display
        end
    end

    return snapshot
end

local function snapshotArguments(args, eager)
    local snapshots = {}
    for i, v in ipairs(args) do
        snapshots[i] = captureArgumentSnapshot(v, 0, eager)
    end
    return snapshots
end

local function ensureSnapshotMaterialized(snapshot, fallbackArg)
    if not snapshot then
        return
    end
    if snapshot.Display and snapshot.Serialized then
        return
    end
    local value = fallbackArg
    local t = snapshot.Type or typeof(value)
    if t == "Instance" then
        if typeof(value) == "Instance" then
            snapshot.Display = serializeValue(value, 0)
        elseif snapshot.Path and snapshot.Path ~= "" then
            snapshot.Display = snapshot.Path
        else
            snapshot.Display = snapshot.Preview or "Instance"
        end
        snapshot.Serialized = snapshot.Display
    elseif t == "table" then
        if type(value) == "table" then
            local success, result = pcall(function()
                return parse(value)
            end)
            snapshot.Display = (success and result) or (snapshot.Preview or "{...}")
        else
            snapshot.Display = snapshot.Preview or "{...}"
        end
        snapshot.Serialized = snapshot.Display
    else
        if value ~= nil then
            snapshot.Display = serializeValue(value, 0)
        else
            snapshot.Display = snapshot.Preview or "nil"
        end
        snapshot.Serialized = snapshot.Display
    end
end

local function getArgPreviewFromSnapshot(snapshot, fallbackArg)
    if snapshot and snapshot.Preview then
        return snapshot.Preview
    end
    if fallbackArg ~= nil then
        return formatValue(fallbackArg)
    end
    return "?"
end

local function getArgDisplayFromSnapshot(snapshot, fallbackArg)
    if snapshot then
        ensureSnapshotMaterialized(snapshot, fallbackArg)
        if snapshot.Display then
            return snapshot.Display
        end
    end
    if fallbackArg == nil then
        return "nil"
    end
    local typeStr = typeof(fallbackArg)
    if typeStr == "table" then
        local success, result = pcall(function()
            return parse(fallbackArg)
        end)
        return (success and result) or "{...}"
    end
    return serializeValue(fallbackArg, 0)
end

local function getArgTypeFromSnapshot(snapshot, fallbackArg)
    if snapshot and snapshot.Type then
        return snapshot.Type
    end
    if fallbackArg ~= nil then
        return typeof(fallbackArg)
    end
    return "unknown"
end

local function appendFingerprint(parts, value, depth, seen)
    local t = typeof(value)
    if t == "Instance" then
        parts[#parts + 1] = "I:"
        parts[#parts + 1] = getCachedInstancePath(value)
        return
    end
    if t == "table" then
        if depth >= FINGERPRINT_MAX_DEPTH then
            parts[#parts + 1] = "{...}"
            return
        end
        if seen[value] then
            parts[#parts + 1] = "{cyc}"
            return
        end
        seen[value] = true
        parts[#parts + 1] = "{"
        local n = 0
        local maxKey = 0
        local isArray = true
        for k in pairs(value) do
            n = n + 1
            if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
                isArray = false
            elseif k > maxKey then
                maxKey = k
            end
        end
        if n == 0 then
            parts[#parts + 1] = "}"
            return
        end
        if isArray and maxKey == n then
            local limit = math.min(n, FINGERPRINT_MAX_KEYS)
            for i = 1, limit do
                if i > 1 then
                    parts[#parts + 1] = ","
                end
                appendFingerprint(parts, value[i], depth + 1, seen)
            end
            if n > FINGERPRINT_MAX_KEYS then
                parts[#parts + 1] = ",+#"
                parts[#parts + 1] = tostring(n)
            end
        else
            local keys = {}
            local keyCount = 0
            for k in pairs(value) do
                keyCount = keyCount + 1
                keys[keyCount] = k
            end
            table.sort(keys, function(a, b)
                local ta, tb = type(a), type(b)
                if ta == tb then
                    return tostring(a) < tostring(b)
                end
                return ta < tb
            end)
            local limit = math.min(#keys, FINGERPRINT_MAX_KEYS)
            for i = 1, limit do
                if i > 1 then
                    parts[#parts + 1] = ","
                end
                parts[#parts + 1] = tostring(keys[i])
                parts[#parts + 1] = "="
                appendFingerprint(parts, value[keys[i]], depth + 1, seen)
            end
            if #keys > FINGERPRINT_MAX_KEYS then
                parts[#parts + 1] = ",+#"
                parts[#parts + 1] = tostring(#keys)
            end
        end
        parts[#parts + 1] = "}"
        return
    end
    if t == "string" then
        parts[#parts + 1] = "s:"
        if #value > FINGERPRINT_MAX_STRING then
            parts[#parts + 1] = value:sub(1, FINGERPRINT_MAX_STRING)
            parts[#parts + 1] = "#"
            parts[#parts + 1] = tostring(#value)
        else
            parts[#parts + 1] = value
        end
        return
    end
    if t == "number" or t == "boolean" or t == "nil" then
        parts[#parts + 1] = t:sub(1, 1)
        parts[#parts + 1] = ":"
        parts[#parts + 1] = tostring(value)
        return
    end
    if t == "Vector3" then
        parts[#parts + 1] = "V3:"
        parts[#parts + 1] = string.format("%.4f,%.4f,%.4f", value.X, value.Y, value.Z)
        return
    end
    if t == "Vector2" then
        parts[#parts + 1] = "V2:"
        parts[#parts + 1] = string.format("%.4f,%.4f", value.X, value.Y)
        return
    end
    if t == "CFrame" then
        parts[#parts + 1] = "CF:"
        parts[#parts + 1] = string.format("%.4f,%.4f,%.4f", value.X, value.Y, value.Z)
        return
    end
    if t == "EnumItem" then
        parts[#parts + 1] = "E:"
        parts[#parts + 1] = tostring(value)
        return
    end
    parts[#parts + 1] = t
    parts[#parts + 1] = ":"
    parts[#parts + 1] = tostring(value)
end

local function stableArgFingerprint(value)
    local parts = {}
    appendFingerprint(parts, value, 0, {})
    return table.concat(parts)
end

local function hashArgs(args)
    local parts = {}
    for i, v in ipairs(args) do
        if i > 1 then
            parts[#parts + 1] = "||"
        end
        appendFingerprint(parts, v, 0, {})
    end
    return table.concat(parts)
end

local function shallowCopyArgs(args)
    local copy = {}
    for i, v in ipairs(args) do
        copy[i] = v
    end
    return copy
end

local function nextLogId(counterHolder)
    local id = (counterHolder._nextLogId or 0) + 1
    counterHolder._nextLogId = id
    return id
end

local function getTimestamp()
    return os.date("%H:%M:%S")
end

local function getFullTimestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

local FunctionAnalyzer = {}

function FunctionAnalyzer:GetInfo(func)
    if typeof(func) ~= "function" then
        return nil
    end
    
    local info = {
        Address = tostring(func):gsub("function: ", ""),
        Name = "anonymous",
        Source = "Unknown",
        LineDefined = 0,
        LastLineDefined = 0,
        NumParams = 0,
        IsVararg = false,
        ClosureType = "Unknown",
        Constants = {},
        Upvalues = {},
        Protos = {},
        ScriptPath = "Unknown",
    }
    
    pcall(function()
        local source, line, name = debug.info(func, "sln")
        if source then info.Source = source end
        if line then info.LineDefined = line end
        if name and name ~= "" then info.Name = name end
    end)
    
    if debug.getinfo then
        pcall(function()
            local dbgInfo = debug.getinfo(func)
            if dbgInfo then
                if dbgInfo.source then info.Source = dbgInfo.source end
                if dbgInfo.short_src then info.Source = dbgInfo.short_src end
                if dbgInfo.name and dbgInfo.name ~= "" then info.Name = dbgInfo.name end
                if dbgInfo.linedefined then info.LineDefined = dbgInfo.linedefined end
                if dbgInfo.lastlinedefined then info.LastLineDefined = dbgInfo.lastlinedefined end
                if dbgInfo.numparams then info.NumParams = dbgInfo.numparams end
                if dbgInfo.is_vararg ~= nil then info.IsVararg = dbgInfo.is_vararg end
                if dbgInfo.what then info.ClosureType = dbgInfo.what end
                if dbgInfo.func then info.Address = tostring(dbgInfo.func):gsub("function: ", "") end
            end
        end)
    end
    
    pcall(function()
        local env = getfenv(func)
        if env and env.script and typeof(env.script) == "Instance" then
            info.ScriptPath = env.script:GetFullName()
        end
    end)
    
    if debug.getconstants then
        pcall(function()
            info.Constants = debug.getconstants(func) or {}
        end)
    end
    
    if debug.getupvalues then
        pcall(function()
            info.Upvalues = debug.getupvalues(func) or {}
        end)
    end
    
    if debug.getprotos then
        pcall(function()
            info.Protos = debug.getprotos(func) or {}
        end)
    end
    
    if islclosure and islclosure(func) then
        info.ClosureType = "Lua"
    elseif iscclosure and iscclosure(func) then
        info.ClosureType = "C"
    end
    
    return info
end

function FunctionAnalyzer:Decompile(func)
    if decompile then
        local success, result = pcall(decompile, func)
        if success then
            return result
        end
    end
    return "-- Decompilation not available or failed"
end

function FunctionAnalyzer:GetScript(func)
    local script = nil
    
    pcall(function()
        local env = getfenv(func)
        if env and env.script then
            script = env.script
        end
    end)
    
    return script
end

local RemoteScanner = {
    FoundRemotes = {},
    GroupedLogs = {},  
    SpyConnections = {},
    HookBackups = {},
    
    IsSpying = false,
    MaxLogs = 1000,
    MaxLogsPerRemote = 200,
    MaxLogsPerArgGroup = 50,
    
    SortMode = "latest", 
    
    EnabledFilters = {
        RemoteEvent = true,
        RemoteFunction = true,
        UnreliableRemoteEvent = true,
        BindableEvent = true,
        BindableFunction = true,
    },
    
    DirectionFilters = {
        Outgoing = true,
        Incoming = true,
    },
    
    IgnoredInstances = {},
    IgnoredArgs = {},
    BlockedInstances = {},
    BlockedArgs = {},
    
    ReturnBypassEnabled = false,
    CachedReturns = {},
    TotalLogCount = 0,
    IncomingLogSuppressDepth = 0,
    PendingLogs = {},
    PendingLogHead = 1,
    PendingLogTail = 0,
    LogProcessingBudget = 0.003,
    MaxLogsPerStep = 32,
    MaxLogsPerStepBurst = 128,
    BacklogBurstThreshold = 64,
    RemoteConnectionStates = setmetatable({}, {__mode = "k"}),
    _nextLogId = 0,
    
    OnLogAdded = nil,
    OnGroupUpdated = nil,
    OnFiltersChanged = nil,
}

function RemoteScanner:GetConnections(signal)
    if safeGetconnections then
        return safeGetconnections(signal)
    end
    return {}
end

function RemoteScanner:QueueLog(remote, remoteType, args, callerFunc, returnValue, isIncoming, blocked, pathHint, nameHint, argHashHint)
    if not self.IsSpying then
        return nil
    end
    if isIncoming and (self.IncomingLogSuppressDepth or 0) > 0 then
        return nil
    end

    local path = pathHint or getCachedInstancePath(remote)
    if self.IgnoredInstances[path] then
        return nil
    end

    local baseType = remoteType
    if type(baseType) == "string" then
        baseType = baseType:gsub(" %(Incoming%)", "")
    end
    if not self.EnabledFilters[baseType] then
        return nil
    end
    if isIncoming then
        if not self.DirectionFilters.Incoming then
            return nil
        end
    elseif not self.DirectionFilters.Outgoing then
        return nil
    end

    local argHash = argHashHint
    local ignoredArgs = self.IgnoredArgs[path]
    if ignoredArgs then
        argHash = argHash or hashArgs(args)
        if ignoredArgs[argHash] then
            return nil
        end
    end

    
    
    local tail = self.PendingLogTail + 1
    self.PendingLogTail = tail
    self.PendingLogs[tail] = {
        Remote = remote,
        RemoteType = remoteType,
        Arguments = args,
        CallerFunction = callerFunc,
        ReturnValue = returnValue,
        IsIncoming = isIncoming,
        Blocked = blocked,
        Path = path,
        Name = nameHint or remote.Name,
        ArgHash = argHash,
    }
end

function RemoteScanner:ProcessLogQueue()
    local started = os.clock()
    local processed = 0
    local pendingCount = self.PendingLogTail - self.PendingLogHead + 1
    local stepLimit = self.MaxLogsPerStep
    local budget = self.LogProcessingBudget
    if pendingCount >= (self.BacklogBurstThreshold or 64) then
        stepLimit = self.MaxLogsPerStepBurst or stepLimit
        budget = math.max(budget, 0.006)
    end

    while self.PendingLogHead <= self.PendingLogTail and processed < stepLimit do
        local head = self.PendingLogHead
        local queued = self.PendingLogs[head]
        self.PendingLogs[head] = nil
        self.PendingLogHead = head + 1
        processed = processed + 1

        if queued then
            local ok, err = pcall(function()
                local log = self:CreateLog(
                    queued.Remote,
                    queued.RemoteType,
                    queued.Arguments,
                    queued.CallerFunction,
                    queued.ReturnValue,
                    queued.IsIncoming,
                    queued
                )
                if log and queued.Blocked then
                    log.Blocked = true
                end
            end)
            if not ok then
                warn("[SpyTool] CreateLog failed:", err)
            end
        end

        if os.clock() - started >= budget then
            break
        end
    end

    if self.PendingLogHead > self.PendingLogTail then
        self.PendingLogs = {}
        self.PendingLogHead = 1
        self.PendingLogTail = 0
    end
end

local REMOTE_CLASS_TYPES = {
    RemoteEvent = "RemoteEvent",
    RemoteFunction = "RemoteFunction",
    UnreliableRemoteEvent = "UnreliableRemoteEvent",
    BindableEvent = "BindableEvent",
    BindableFunction = "BindableFunction",
}

function RemoteScanner:GetAllRemotes()
    local remotes = {}
    
    local containers = {
        safeService("ReplicatedStorage"),
        safeService("ReplicatedFirst"),
        safeCloneref(workspace),
        Players,
        safeService("Lighting"),
        safeService("StarterGui"),
        safeService("StarterPack"),
        safeService("StarterPlayer"),
    }
    
    if LocalPlayer then
        if LocalPlayer:FindFirstChild("PlayerGui") then
            containers[#containers + 1] = safeCloneref(LocalPlayer.PlayerGui)
        end
        if LocalPlayer:FindFirstChild("Backpack") then
            containers[#containers + 1] = safeCloneref(LocalPlayer.Backpack)
        end
        if LocalPlayer:FindFirstChild("PlayerScripts") then
            containers[#containers + 1] = LocalPlayer.PlayerScripts
        end
        if LocalPlayer:FindFirstChild("Character") then
            containers[#containers + 1] = LocalPlayer.Character
        end
    end
    
    for _, container in ipairs(containers) do
        pcall(function()
            for _, desc in ipairs(container:GetDescendants()) do
                local remoteType = REMOTE_CLASS_TYPES[desc.ClassName]
                if remoteType then
                    remotes[#remotes + 1] = {Instance = desc, Type = remoteType}
                end
            end
        end)
    end
    
    return remotes
end

function RemoteScanner:Scan()
    self.FoundRemotes = {}
    self.GroupedLogs = {}
    
    local remotes = self:GetAllRemotes()
    
    for _, data in ipairs(remotes) do
        local remote = data.Instance
        local remoteType = data.Type
        local path = getCachedInstancePath(remote)
        local connections = {}
        
        if remoteType == "RemoteEvent" then
            connections = self:GetConnections(remote.OnClientEvent)
        elseif remoteType == "UnreliableRemoteEvent" then
            connections = self:GetConnections(remote.OnClientEvent)
        elseif remoteType == "BindableEvent" then
            connections = self:GetConnections(remote.Event)
        end
        
        self.FoundRemotes[path] = {
            Instance = remote,
            Path = path,
            Name = remote.Name,
            Type = remoteType,
            ConnectionCount = #connections,
            Connections = connections,
        }
        
        self.GroupedLogs[path] = {
            Info = self.FoundRemotes[path],
            ArgGroups = {},  
            TotalCalls = 0,
            FirstCall = nil,
            LastCall = nil,
            Expanded = false,
        }
    end
    
    return self.FoundRemotes
end

function RemoteScanner:WithIncomingLogSuppressed(callback)
    self.IncomingLogSuppressDepth = (self.IncomingLogSuppressDepth or 0) + 1
    local ok, result = pcall(callback)
    self.IncomingLogSuppressDepth = math.max(0, (self.IncomingLogSuppressDepth or 1) - 1)
    if not ok then
        error(result, 0)
    end
    return result
end

local function dropOldestFromArgGroup(scanner, group, argHash, argGroup)
    local removed = table.remove(argGroup.Logs)
    if not removed then
        return false
    end
    argGroup.Count = math.max(0, (argGroup.Count or 1) - 1)
    group.TotalCalls = math.max(0, (group.TotalCalls or 1) - 1)
    scanner.TotalLogCount = math.max(0, (scanner.TotalLogCount or 1) - 1)
    if argGroup.Count <= 0 or #argGroup.Logs == 0 then
        group.ArgGroups[argHash] = nil
        group._argGroupsDirty = true
    elseif scanner.SortMode == "calls" then
        group._argGroupsDirty = true
    end
    return true
end

function RemoteScanner:_trimRemoteLogs(group)
    local maxPerRemote = self.MaxLogsPerRemote
    if maxPerRemote == nil then
        return
    end
    
    local safety = 0
    while group.TotalCalls > maxPerRemote and safety < 64 do
        safety = safety + 1
        local oldestArgHash = nil
        local oldestTick = math.huge
        
        for argHash, argGroup in pairs(group.ArgGroups) do
            local oldestLog = argGroup.Logs[#argGroup.Logs]
            if oldestLog and oldestLog.TickTime < oldestTick then
                oldestTick = oldestLog.TickTime
                oldestArgHash = argHash
            end
        end
        
        if not oldestArgHash then
            break
        end
        
        dropOldestFromArgGroup(self, group, oldestArgHash, group.ArgGroups[oldestArgHash])
        if group.TotalCalls <= 0 and group.Info and not self.FoundRemotes[group.Info.Path] then
            self.GroupedLogs[group.Info.Path] = nil
            break
        end
    end
end

function RemoteScanner:_trimGlobalLogs()
    local maxLogs = self.MaxLogs or 1000
    
    
    local safety = 0
    while (self.TotalLogCount or 0) > maxLogs and safety < 64 do
        safety = safety + 1
        local targetPath, targetArgHash, oldestTick = nil, nil, math.huge
        
        for path, group in pairs(self.GroupedLogs) do
            for argHash, argGroup in pairs(group.ArgGroups) do
                local oldestLog = argGroup.Logs[#argGroup.Logs]
                if oldestLog and oldestLog.TickTime < oldestTick then
                    oldestTick = oldestLog.TickTime
                    targetPath = path
                    targetArgHash = argHash
                end
            end
        end
        
        if not targetPath or not targetArgHash then
            break
        end
        
        local group = self.GroupedLogs[targetPath]
        local argGroup = group and group.ArgGroups[targetArgHash]
        if not group or not argGroup then
            break
        end
        dropOldestFromArgGroup(self, group, targetArgHash, argGroup)
        if group.TotalCalls <= 0 and not self.FoundRemotes[targetPath] then
            self.GroupedLogs[targetPath] = nil
        end
    end
end

function RemoteScanner:RestoreIncomingHooks()
    for path, backup in pairs(self.HookBackups) do
        local data = self.FoundRemotes[path]
        if data and data.Instance and backup then
            pcall(function()
                if backup.Type == "OnClientInvoke" then
                    data.Instance.OnClientInvoke = backup.Original
                elseif backup.Type == "OnInvoke" then
                    data.Instance.OnInvoke = backup.Original
                end
            end)
        end
    end
    self.HookBackups = {}
end

function RemoteScanner:CreateLog(remote, remoteType, args, callerFunc, returnValue, isIncoming, queuedInfo)
    if isIncoming and (self.IncomingLogSuppressDepth or 0) > 0 then
        return nil
    end
    
    local path = (queuedInfo and queuedInfo.Path) or getCachedInstancePath(remote)
    local remoteName = (queuedInfo and queuedInfo.Name) or remote.Name
    local argHash = (queuedInfo and queuedInfo.ArgHash) or hashArgs(args)
    
    local baseType = remoteType:gsub(" %(Incoming%)", "")
    
    
    if self.IgnoredInstances[path] then
        return nil
    end
    
    if self.IgnoredArgs[path] and self.IgnoredArgs[path][argHash] then
        return nil
    end
    
    if not self.EnabledFilters[baseType] then
        return nil
    end
    
    if isIncoming and not self.DirectionFilters.Incoming then
        return nil
    end
    if not isIncoming and not self.DirectionFilters.Outgoing then
        return nil
    end
    
    local now = tick()
    local timestamp = getTimestamp()
    
    local displayType = isIncoming and (baseType .. " (Incoming)") or baseType
    
    self.TotalLogCount = (self.TotalLogCount or 0) + 1

    
    local cachedArguments = snapshotArguments(args, false)
    local argsCopy = shallowCopyArgs(args)

    local log = {
        Id = nextLogId(self),
        Timestamp = timestamp,
        FullTimestamp = nil, 
        TickTime = now,
        Remote = remote,
        RemotePath = path,
        RemoteName = remoteName,
        RemoteType = displayType,
        Arguments = argsCopy,
        CachedArguments = cachedArguments,
        ArgumentCount = #args,
        ArgHash = argHash,
        CallerFunction = callerFunc,
        CallerInfo = nil, 
        ReturnValue = returnValue,
        Blocked = false,
        IsIncoming = isIncoming or false,
    }
    
    if not self.GroupedLogs[path] then
        self.GroupedLogs[path] = {
            Info = self.FoundRemotes[path] or {
                Instance = remote,
                Path = path,
                Name = remoteName,
                Type = baseType,
                ConnectionCount = 0,
                Connections = {},
            },
            ArgGroups = {},
            TotalCalls = 0,
            FirstCall = nil,
            LastCall = nil,
            Expanded = false,
        }
    end
    
    local group = self.GroupedLogs[path]
    
    group.TotalCalls = group.TotalCalls + 1
    group.LastCall = timestamp
    if not group.FirstCall then
        group.FirstCall = now
    end
    
    if not group.ArgGroups[argHash] then
        group.ArgGroups[argHash] = {
            Args = argsCopy,
            CachedArgs = cachedArguments,
            ArgHash = argHash,
            Logs = {},
            Count = 0,
            FirstCall = now,
            LastCall = nil,
            Expanded = false,
            HasIncoming = false,
            HasOutgoing = false,
        }
        group._argGroupsDirty = true
    end
    
    local argGroup = group.ArgGroups[argHash]
    argGroup.CachedArgs = cachedArguments
    
    if isIncoming then
        argGroup.HasIncoming = true
        group.HasIncomingLogs = true
    else
        argGroup.HasOutgoing = true
        group.HasOutgoingLogs = true
    end
    
    table.insert(argGroup.Logs, 1, log)
    argGroup.Count = argGroup.Count + 1
    argGroup.LastCall = timestamp
    
    if self.SortMode == "calls" then
        group._argGroupsDirty = true
    end
    
    if #argGroup.Logs > self.MaxLogsPerArgGroup then
        table.remove(argGroup.Logs)
        argGroup.Count = math.max(0, argGroup.Count - 1)
        group.TotalCalls = math.max(0, group.TotalCalls - 1)
        self.TotalLogCount = math.max(0, (self.TotalLogCount or 1) - 1)
    end
    
    self:_trimRemoteLogs(group)
    self:_trimGlobalLogs()
    
    if returnValue ~= nil then
        if not self.CachedReturns[path] then
            self.CachedReturns[path] = {}
        end
        self.CachedReturns[path][argHash] = returnValue
        
        local cacheCount = 0
        for _ in pairs(self.CachedReturns[path]) do
            cacheCount = cacheCount + 1
        end
        local cacheCap = self.MaxLogsPerRemote
        if cacheCap and cacheCount > cacheCap then
            for hash in pairs(self.CachedReturns[path]) do
                if hash ~= argHash then
                    self.CachedReturns[path][hash] = nil
                    break
                end
            end
        end
    end
    
    
    if self.OnLogAdded then
        self.OnLogAdded(log)
    elseif self.OnGroupUpdated then
        self.OnGroupUpdated(path, group)
    end
    
    return log
end

function RemoteScanner:EnsureCallerInfo(log)
    if not log then
        return nil
    end
    if log._callerInfoResolved then
        return log.CallerInfo
    end
    log._callerInfoResolved = true
    if not log.CallerFunction then
        log.CallerInfo = nil
        return nil
    end
    log.CallerInfo = FunctionAnalyzer:GetInfo(log.CallerFunction)
    return log.CallerInfo
end

function RemoteScanner:EnsureFullTimestamp(log)
    if not log then
        return ""
    end
    if not log.FullTimestamp then
        log.FullTimestamp = getFullTimestamp()
    end
    return log.FullTimestamp
end

function RemoteScanner:GetSortedGroups()
    local groups = {}
    
    for path, group in pairs(self.GroupedLogs) do
        if group.TotalCalls > 0 or self.FoundRemotes[path] then
            table.insert(groups, {
                Path = path,
                Group = group,
                FirstCall = group.FirstCall or 0,
                TotalCalls = group.TotalCalls,
            })
        end
    end
    
    if self.SortMode == "latest" then
        table.sort(groups, function(a, b)
            return (a.FirstCall or 0) > (b.FirstCall or 0)
        end)
    elseif self.SortMode == "calls" then
        table.sort(groups, function(a, b)
            return a.TotalCalls > b.TotalCalls
        end)
    end
    
    return groups
end

function RemoteScanner:GetSortedArgGroups(path)
    local group = self.GroupedLogs[path]
    if not group then return {} end
    
    if group._sortedArgGroupsCache and not group._argGroupsDirty then
        return group._sortedArgGroupsCache
    end
    
    local argGroups = {}
    for argHash, argGroup in pairs(group.ArgGroups) do
        local hasVisibleLog = false
        if self.DirectionFilters.Incoming and self.DirectionFilters.Outgoing then
            hasVisibleLog = argGroup.Count > 0
        elseif argGroup.HasIncoming and argGroup.HasOutgoing then
            hasVisibleLog = (self.DirectionFilters.Incoming or self.DirectionFilters.Outgoing)
        elseif argGroup.HasIncoming then
            hasVisibleLog = self.DirectionFilters.Incoming
        elseif argGroup.HasOutgoing then
            hasVisibleLog = self.DirectionFilters.Outgoing
        end
        
        if hasVisibleLog then
            table.insert(argGroups, {
                ArgHash = argHash,
                ArgGroup = argGroup,
                FirstCall = argGroup.FirstCall or 0,
                Count = argGroup.Count,
            })
        end
    end
    
    if self.SortMode == "latest" then
        table.sort(argGroups, function(a, b)
            return (a.FirstCall or 0) > (b.FirstCall or 0)
        end)
    elseif self.SortMode == "calls" then
        table.sort(argGroups, function(a, b)
            return a.Count > b.Count
        end)
    end
    
    group._sortedArgGroupsCache = argGroups
    group._argGroupsDirty = false
    return argGroups
end

function RemoteScanner:ShouldBlock(path, args, argHash)
    if self.BlockedInstances[path] then
        return true
    end
    
    local blockedArgs = self.BlockedArgs[path]
    if not blockedArgs then
        return false
    end
    local hash = argHash or hashArgs(args)
    return blockedArgs[hash] == true
end

function RemoteScanner:GetBypassReturn(path, args, argHash)
    if not self.ReturnBypassEnabled then
        return nil
    end
    
    local cached = self.CachedReturns[path]
    if not cached then
        return nil
    end
    local hash = argHash or hashArgs(args)
    return cached[hash]
end

function RemoteScanner:PrepareOutgoing(remote, args)
    local path = getCachedInstancePath(remote)
    if self.IgnoredInstances[path] then
        return path, false, nil, true 
    end
    local needsHash = (self.BlockedArgs[path] ~= nil)
        or (self.IgnoredArgs[path] ~= nil)
        or self.ReturnBypassEnabled
    local argHash = needsHash and hashArgs(args) or nil
    local blocked = self.BlockedInstances[path] == true
        or (argHash ~= nil and self.BlockedArgs[path] and self.BlockedArgs[path][argHash] == true)
    return path, blocked, argHash, false
end

function RemoteScanner:StartSpying()
    if self.IsSpying then 
        return
    end
    self.IsSpying = true
    self.PendingLogs = {}
    self.PendingLogHead = 1
    self.PendingLogTail = 0

    local processorConn = RunService.Heartbeat:Connect(function()
        if self.IsSpying and self.PendingLogHead <= self.PendingLogTail then
            self:ProcessLogQueue()
        end
    end)
    table.insert(self.SpyConnections, processorConn)
    self.RemoteConnectionStates = setmetatable({}, {__mode = "k"})
    
    if not HttpInterceptor.IsHooked then
        HttpInterceptor:InstallHooks()
    end

    local function ensureRemoteState(remote, path)
        local state = self.RemoteConnectionStates[remote]
        if state then
            return state
        end

        state = {Connections = {}}
        self.RemoteConnectionStates[remote] = state
        state.DestroyingConnection = remote.Destroying:Connect(function()
            for _, conn in ipairs(state.Connections) do
                pcall(function() conn:Disconnect() end)
            end
            state.Connections = {}
            self.RemoteConnectionStates[remote] = nil

            local found = self.FoundRemotes[path]
            if found and found.Instance == remote then
                self.FoundRemotes[path] = nil
                local group = self.GroupedLogs[path]
                if group and (group.TotalCalls or 0) <= 0 then
                    self.GroupedLogs[path] = nil
                end
            end
            self.HookBackups[path] = nil
        end)
        return state
    end
    
    
    local function hookIncoming(remote, data, path)
        if not remote or not remote.Parent then
            return
        end
        local state = ensureRemoteState(remote, path)
        
        local remoteName = remote.Name
        if data.Type == "RemoteEvent" or data.Type == "UnreliableRemoteEvent" then
            local success, conn = pcall(function()
                return remote.OnClientEvent:Connect(function(...)
                    if not self.IsSpying then return end
                    self:QueueLog(remote, data.Type, {...}, nil, nil, true, false, path, remoteName)
                end)
            end)
            if success and conn then
                state.Connections[#state.Connections + 1] = conn
            end
        elseif data.Type == "BindableEvent" then
            local success, conn = pcall(function()
                return remote.Event:Connect(function(...)
                    if not self.IsSpying then return end
                    self:QueueLog(remote, data.Type, {...}, nil, nil, true, false, path, remoteName)
                end)
            end)
            if success and conn then
                state.Connections[#state.Connections + 1] = conn
            end
        elseif data.Type == "RemoteFunction" and not self.HookBackups[path] then
            local original = remote.OnClientInvoke
            self.HookBackups[path] = {
                Type = "OnClientInvoke",
                Original = original,
            }
            local scanner = self
            remote.OnClientInvoke = function(...)
                if scanner.IsSpying and (scanner.IncomingLogSuppressDepth or 0) == 0 then
                    scanner:QueueLog(remote, data.Type, {...}, nil, nil, true, false, path, remoteName)
                end
                if type(original) == "function" then
                    return original(...)
                end
            end
        elseif data.Type == "BindableFunction" and not self.HookBackups[path] then
            local original = remote.OnInvoke
            self.HookBackups[path] = {
                Type = "OnInvoke",
                Original = original,
            }
            local scanner = self
            remote.OnInvoke = function(...)
                if scanner.IsSpying and (scanner.IncomingLogSuppressDepth or 0) == 0 then
                    scanner:QueueLog(remote, data.Type, {...}, nil, nil, true, false, path, remoteName)
                end
                if type(original) == "function" then
                    return original(...)
                end
            end
        end
    end
    
    
    for path, data in pairs(self.FoundRemotes) do
        hookIncoming(data.Instance, data, path)
    end
    
    
    
    local pendingRemotes = setmetatable({}, {__mode = "k"})
    local admissionScheduled = false

    local function flushPendingRemotes()
        admissionScheduled = false
        local candidates = pendingRemotes
        pendingRemotes = setmetatable({}, {__mode = "k"})
        local started = os.clock()
        local admitted = 0
        local processedCandidates = {}

        if not self.IsSpying then
            return
        end

        for descendant, remoteType in pairs(candidates) do
            processedCandidates[descendant] = true
            if descendant.Parent and descendant:IsDescendantOf(game) then
                local path = getCachedInstancePath(descendant)
                local existing = self.FoundRemotes[path]
                if not existing or existing.Instance ~= descendant then
                    local connections = {}
                    if remoteType == "RemoteEvent" or remoteType == "UnreliableRemoteEvent" then
                        connections = self:GetConnections(descendant.OnClientEvent)
                    elseif remoteType == "BindableEvent" then
                        connections = self:GetConnections(descendant.Event)
                    end
                    
                    local data = {
                        Instance = descendant,
                        Path = path,
                        Name = descendant.Name,
                        Type = remoteType,
                        ConnectionCount = #connections,
                        Connections = connections,
                    }
                    self.FoundRemotes[path] = data
                    
                    if not self.GroupedLogs[path] then
                        self.GroupedLogs[path] = {
                            Info = data,
                            ArgGroups = {},
                            TotalCalls = 0,
                            FirstCall = nil,
                            LastCall = nil,
                            Expanded = false,
                        }
                    else
                        self.GroupedLogs[path].Info = data
                    end
                    
                    hookIncoming(descendant, data, path)
                end
            end

            admitted = admitted + 1
            if admitted >= 10 or os.clock() - started >= 0.001 then
                break
            end
        end

        if admitted < 1 then
            return
        end

        local hasRemaining = false
        for descendant, remoteType in pairs(candidates) do
            if not processedCandidates[descendant] then
                pendingRemotes[descendant] = remoteType
                hasRemaining = true
            end
        end
        if hasRemaining then
            if not admissionScheduled then
                admissionScheduled = true
                task.spawn(function()
                    task.wait()
                    flushPendingRemotes()
                end)
            end
        end
    end

    local function onDescendantAdded(descendant)
        if not self.IsSpying then return end
        
        local remoteType = REMOTE_CLASS_TYPES[descendant.ClassName]
        if not remoteType then return end

        pendingRemotes[descendant] = remoteType
        if not admissionScheduled then
            admissionScheduled = true
            task.defer(flushPendingRemotes)
        end
    end
    
    local addedConn = game.DescendantAdded:Connect(onDescendantAdded)
    table.insert(self.SpyConnections, addedConn)
end

function RemoteScanner:StopSpying()
    self.IsSpying = false
    for _, conn in ipairs(self.SpyConnections) do
        pcall(function() conn:Disconnect() end)
    end
    self.SpyConnections = {}
    for _, state in pairs(self.RemoteConnectionStates) do
        for _, conn in ipairs(state.Connections) do
            pcall(function() conn:Disconnect() end)
        end
        if state.DestroyingConnection then
            pcall(function() state.DestroyingConnection:Disconnect() end)
        end
    end
    self.RemoteConnectionStates = setmetatable({}, {__mode = "k"})
    self.PendingLogs = {}
    self.PendingLogHead = 1
    self.PendingLogTail = 0
    self:RestoreIncomingHooks()
end

function RemoteScanner:ClearLogs()
    for path, group in pairs(self.GroupedLogs) do
        group.ArgGroups = {}
        group.TotalCalls = 0
        group.FirstCall = nil
        group.LastCall = nil
        group._argGroupsDirty = true
        group._sortedArgGroupsCache = nil
        group.HasIncomingLogs = nil
        group.HasOutgoingLogs = nil
    end
    self.TotalLogCount = 0
end

function RemoteScanner:PurgeAll()
    self.IsSpying = false
    self.GroupedLogs = {}
    self.FoundRemotes = {}
    self.CachedReturns = {}
    self.TotalLogCount = 0
    self.PendingLogs = {}
    self.PendingLogHead = 1
    self.PendingLogTail = 0
    self.HookBackups = {}
    self.IncomingLogSuppressDepth = 0
    self.OnLogAdded = nil
    self.OnGroupUpdated = nil
    self.OnFiltersChanged = nil
end

function RemoteScanner:ClearLogsForRemote(path)
    if self.GroupedLogs[path] then
        local removed = self.GroupedLogs[path].TotalCalls or 0
        self.GroupedLogs[path].ArgGroups = {}
        self.GroupedLogs[path].TotalCalls = 0
        self.GroupedLogs[path].FirstCall = nil
        self.GroupedLogs[path].LastCall = nil
        self.TotalLogCount = math.max(0, (self.TotalLogCount or 0) - removed)
    end
end

function RemoteScanner:ClearLogsForArgGroup(path, argHash)
    if self.GroupedLogs[path] and self.GroupedLogs[path].ArgGroups[argHash] then
        local group = self.GroupedLogs[path]
        local argGroup = group.ArgGroups[argHash]
        local count = argGroup.Count
        
        group.ArgGroups[argHash] = nil
        group.TotalCalls = group.TotalCalls - count
        self.TotalLogCount = math.max(0, (self.TotalLogCount or 0) - count)
        group._argGroupsDirty = true
        group._sortedArgGroupsCache = nil
        group.HasIncomingLogs = nil
        group.HasOutgoingLogs = nil
        for _, ag in pairs(group.ArgGroups) do
            if ag.HasIncoming then group.HasIncomingLogs = true end
            if ag.HasOutgoing then group.HasOutgoingLogs = true end
        end
    end
end

function RemoteScanner:SetIgnoreInstance(path, ignore)
    self.IgnoredInstances[path] = ignore or nil
    if self.OnFiltersChanged then
        task.defer(self.OnFiltersChanged)
    end
end

function RemoteScanner:SetIgnoreArgs(path, argsOrHash, ignore)
    local argHash = type(argsOrHash) == "string" and argsOrHash or hashArgs(argsOrHash)
    if not self.IgnoredArgs[path] then
        self.IgnoredArgs[path] = {}
    end
    self.IgnoredArgs[path][argHash] = ignore or nil
    if self.OnFiltersChanged then
        task.defer(self.OnFiltersChanged)
    end
end

function RemoteScanner:SetBlockInstance(path, block)
    self.BlockedInstances[path] = block or nil
    if self.OnFiltersChanged then
        task.defer(self.OnFiltersChanged)
    end
end

function RemoteScanner:SetBlockArgs(path, argsOrHash, block)
    local argHash = type(argsOrHash) == "string" and argsOrHash or hashArgs(argsOrHash)
    if not self.BlockedArgs[path] then
        self.BlockedArgs[path] = {}
    end
    self.BlockedArgs[path][argHash] = block or nil
    if self.OnFiltersChanged then
        task.defer(self.OnFiltersChanged)
    end
end

function RemoteScanner:FireRemote(log)
    if not log or not log.Remote then return false end
    
    local remote = log.Remote
    local args = log.Arguments
    local remoteType = log.RemoteType:gsub(" %(Incoming%)", "")
    local isIncoming = log.IsIncoming
    
    local success, result = pcall(function()
        if isIncoming then
            return self:WithIncomingLogSuppressed(function()
                if remoteType == "RemoteEvent" or remoteType == "UnreliableRemoteEvent" then
                    if firesignal then
                        return firesignal(remote.OnClientEvent, unpack(args))
                    end
                    return nil
                elseif remoteType == "BindableEvent" then
                    if firesignal then
                        return firesignal(remote.Event, unpack(args))
                    end
                    return nil
                elseif remoteType == "RemoteFunction" then
                    if type(remote.OnClientInvoke) == "function" then
                        return remote.OnClientInvoke(unpack(args))
                    end
                    return nil
                elseif remoteType == "BindableFunction" then
                    if type(remote.OnInvoke) == "function" then
                        return remote.OnInvoke(unpack(args))
                    end
                    return nil
                end
            end)
        else
            
            if remoteType == "RemoteEvent" or remoteType == "UnreliableRemoteEvent" then
                return remote:FireServer(unpack(args))
            elseif remoteType == "RemoteFunction" then
                return remote:InvokeServer(unpack(args))
            elseif remoteType == "BindableEvent" then
                return remote:Fire(unpack(args))
            elseif remoteType == "BindableFunction" then
                return remote:Invoke(unpack(args))
            end
        end
    end)
    
    return success, result
end

function RemoteScanner:GenerateFireScript(log)
    if not log then return "" end
    
    local lines = {
        "-- Generated by Spy Tool",
        "",
    }
    
    local remotePath = log.RemotePath
    local remoteType = log.RemoteType:gsub(" %(Incoming%)", "")
    local isIncoming = log.IsIncoming
    
    
    local pathParts = {}
    for part in remotePath:gmatch("[^%.]+") do
        table.insert(pathParts, part)
    end
    
    local serviceName = pathParts[1]
    local remoteLine = 'local remote = game:GetService("' .. serviceName .. '")'
    
    for i = 2, #pathParts do
        remoteLine = remoteLine .. ':WaitForChild("' .. pathParts[i] .. '")'
    end
    
    table.insert(lines, remoteLine)
    table.insert(lines, "")
    
    
    if log.ArgumentCount > 0 then
        table.insert(lines, "local args = {")
        for i = 1, log.ArgumentCount do
            local arg = log.Arguments[i]
            local snapshot = log.CachedArguments and log.CachedArguments[i]
            local serialized
            if snapshot then
                ensureSnapshotMaterialized(snapshot, arg)
                serialized = snapshot.Serialized
            end
            if not serialized then
                if typeof(arg) == "table" then
                    local success, result = pcall(function()
                        return parse(arg)
                    end)
                    if success and result then
                        serialized = result:gsub("\n", "\n    ")
                    else
                        serialized = "{}"
                    end
                else
                    serialized = serializeValue(arg, 1)
                end
            end
            
            local comma = i < log.ArgumentCount and "," or ""
            table.insert(lines, "    " .. serialized .. comma)
        end
        table.insert(lines, "}")
        table.insert(lines, "")
    end
    
    
    if isIncoming then
        
        if remoteType == "RemoteEvent" or remoteType == "UnreliableRemoteEvent" then
            if log.ArgumentCount > 0 then
                table.insert(lines, "firesignal(remote.OnClientEvent, unpack(args))")
            else
                table.insert(lines, "firesignal(remote.OnClientEvent)")
            end
        elseif remoteType == "RemoteFunction" then
            table.insert(lines, "-- Note: RemoteFunction OnClientInvoke cannot be fired directly")
            table.insert(lines, "-- You need to set up a callback instead:")
            table.insert(lines, "-- remote.OnClientInvoke = function(...) return yourHandler(...) end")
        elseif remoteType == "BindableEvent" then
            if log.ArgumentCount > 0 then
                table.insert(lines, "firesignal(remote.Event, unpack(args))")
            else
                table.insert(lines, "firesignal(remote.Event)")
            end
        elseif remoteType == "BindableFunction" then
            table.insert(lines, "-- Note: BindableFunction OnInvoke cannot be fired directly")
            table.insert(lines, "-- You need to set up a callback instead:")
            table.insert(lines, "-- remote.OnInvoke = function(...) return yourHandler(...) end")
        end
    else
        
        if remoteType == "RemoteEvent" or remoteType == "UnreliableRemoteEvent" then
            if log.ArgumentCount > 0 then
                table.insert(lines, "remote:FireServer(unpack(args))")
            else
                table.insert(lines, "remote:FireServer()")
            end
        elseif remoteType == "RemoteFunction" then
            if log.ArgumentCount > 0 then
                table.insert(lines, "local result = remote:InvokeServer(unpack(args))")
            else
                table.insert(lines, "local result = remote:InvokeServer()")
            end
            table.insert(lines, "print(\"Result:\", result)")
        elseif remoteType == "BindableEvent" then
            if log.ArgumentCount > 0 then
                table.insert(lines, "remote:Fire(unpack(args))")
            else
                table.insert(lines, "remote:Fire()")
            end
        elseif remoteType == "BindableFunction" then
            if log.ArgumentCount > 0 then
                table.insert(lines, "local result = remote:Invoke(unpack(args))")
            else
                table.insert(lines, "local result = remote:Invoke()")
            end
            table.insert(lines, "print(\"Result:\", result)")
        end
    end
    
    return table.concat(lines, "\n")
end

function RemoteScanner:GenerateInterceptScript(log)
    if not log then return "", false end
    
    local usesHookfunction = isHookfunctionSupported()
    local lines = {
        "-- Generated by Spy Tool",
        "",
    }
    appendInterceptHookHeader(lines, usesHookfunction)
    
    local remoteType = log.RemoteType:gsub(" %(Incoming%)", "")
    local isIncoming = log.IsIncoming
    
    
    local remotePath = log.RemotePath
    local pathParts = {}
    for part in remotePath:gmatch("[^%.]+") do
        table.insert(pathParts, part)
    end
    
    local serviceName = pathParts[1]
    local remoteLine = 'local remote = game:GetService("' .. serviceName .. '")'
    for i = 2, #pathParts do
        remoteLine = remoteLine .. ':WaitForChild("' .. pathParts[i] .. '")'
    end
    
    table.insert(lines, remoteLine)
    table.insert(lines, "")
    
    if isIncoming then
        if remoteType == "RemoteEvent" or remoteType == "UnreliableRemoteEvent" then
            table.insert(lines, [[
-- Intercept incoming OnClientEvent by replacing connections
local connections = getconnections(remote.OnClientEvent)

for _, connection in ipairs(connections) do
    local originalFunc = connection.Function
    connection:Disconnect()
    
    remote.OnClientEvent:Connect(function(...)
        local args = {...}
        
        -- Modify args here
        -- Example: args[1] = "modified"
        
        -- To block: return (don't call original)
        
        print("Intercepted incoming:", remote.Name)
        for i, arg in ipairs(args) do
            print("  Arg " .. i .. ":", arg)
        end
        
        -- Call original handler with (possibly modified) args
        originalFunc(unpack(args))
    end)
end
]])
        elseif remoteType == "RemoteFunction" then
            table.insert(lines, [[
-- Intercept incoming OnClientInvoke by replacing the callback
local originalCallback = remote.OnClientInvoke

remote.OnClientInvoke = function(...)
    local args = {...}
    
    print("Intercepted incoming invoke:", remote.Name)
    for i, arg in ipairs(args) do
        print("  Arg " .. i .. ":", arg)
    end
    
    local result = originalCallback(unpack(args))

    
    print("  Returning:", result)
    return result
end
]])
        end
    else
        
        table.insert(lines, 'local remotePath = "' .. log.RemotePath .. '"')
        table.insert(lines, "")
        
        if usesHookfunction then
            if remoteType == "RemoteEvent" then
                table.insert(lines, [[
local oldFireServer
oldFireServer = hookfunction(Instance.new("RemoteEvent").FireServer, function(remote, ...)
    if remote:GetFullName() == remotePath then
        local args = {...}
        
        print("Intercepted:", remote.Name)
        for i, arg in ipairs(args) do
            print("  Arg " .. i .. ":", arg)
        end
        
        return oldFireServer(remote, unpack(args))
    end
    return oldFireServer(remote, ...)
end)
]])
            elseif remoteType == "UnreliableRemoteEvent" then
                table.insert(lines, [[
local oldFireServer
oldFireServer = hookfunction(Instance.new("UnreliableRemoteEvent").FireServer, function(remote, ...)
    if remote:GetFullName() == remotePath then
        local args = {...}
        
        print("Intercepted:", remote.Name)
        for i, arg in ipairs(args) do
            print("  Arg " .. i .. ":", arg)
        end
        
        return oldFireServer(remote, unpack(args))
    end
    return oldFireServer(remote, ...)
end)
]])
            elseif remoteType == "RemoteFunction" then
                table.insert(lines, [[
local oldInvokeServer
oldInvokeServer = hookfunction(Instance.new("RemoteFunction").InvokeServer, function(remote, ...)
    if remote:GetFullName() == remotePath then
        local args = {...}
        
        print("Intercepted:", remote.Name)
        for i, arg in ipairs(args) do
            print("  Arg " .. i .. ":", arg)
        end
        
        local result = oldInvokeServer(remote, unpack(args))
        
        print("  Return:", result)
        return result
    end
    return oldInvokeServer(remote, ...)
end)
]])
            end
        else
            if remoteType == "RemoteEvent" or remoteType == "UnreliableRemoteEvent" then
                table.insert(lines, [[
-- Replace remote:FireServer(...) with FireServerIntercept(remote, ...)
local function FireServerIntercept(remote, ...)
    if remote:GetFullName() == remotePath then
        local args = {...}
        
        print("Intercepted:", remote.Name)
        for i, arg in ipairs(args) do
            print("  Arg " .. i .. ":", arg)
        end
        
        -- To block: return without calling FireServer
    end
    return remote.FireServer(remote, ...)
end
]])
            elseif remoteType == "RemoteFunction" then
                table.insert(lines, [[
-- Replace remote:InvokeServer(...) with InvokeServerIntercept(remote, ...)
local function InvokeServerIntercept(remote, ...)
    if remote:GetFullName() == remotePath then
        local args = {...}
        
        print("Intercepted:", remote.Name)
        for i, arg in ipairs(args) do
            print("  Arg " .. i .. ":", arg)
        end
        
        local result = remote.InvokeServer(remote, unpack(args))
        
        print("  Return:", result)
        return result
    end
    return remote.InvokeServer(remote, ...)
end
]])
            end
        end
    end
    
    return table.concat(lines, "\n"), usesHookfunction
end

HttpInterceptor = {
    IsSpying = false,
    InterceptEnabled = false,
    IsHooked = false,
    _shuttingDown = false,
    _pendingReleased = false,
    HasRequestApi = false,
    HasRequestAsyncApi = false,
    
    Logs = {},
    LogsById = {},
    MaxLogs = 200,
    BlockedUrls = {},
    
    OnLogAdded = nil,
    OnRequestPending = nil,
    OnResponseReady = nil,
    OnBlockStateChanged = nil,
}

local PendingRequests = {}
local CompletedResponses = {}
local FetchingUrls = {}
local FetchingRequests = {}

local ClonedHttpGet = nil
local ClonedHttpGetAsync = nil
local ClonedHttpPost = nil
local ClonedHttpPostAsync = nil
local ClonedRequest = nil
local ClonedRequestAsync = nil

local function isHttpTableResponseType(requestType)
    return requestType == "Request" or requestType == "RequestAsync"
end

local function isHttpStringResponseType(requestType)
    return requestType == "HttpGet"
        or requestType == "HttpGetAsync"
        or requestType == "HttpPost"
        or requestType == "HttpPostAsync"
end

local function makeBlockedTableResponse()
    return {
        Success = false,
        StatusCode = 0,
        StatusMessage = "Blocked",
        Headers = {},
        Body = "",
    }
end

local function makeTimeoutTableResponse()
    return {
        Success = false,
        StatusCode = 0,
        StatusMessage = "Intercept timeout",
        Headers = {},
        Body = "",
    }
end

function HttpInterceptor:IsUrlBlocked(url)
    url = tostring(url or "")
    return url ~= "" and self.BlockedUrls[url] == true
end

function HttpInterceptor:GetEffectiveUrl(log, pending)
    if log and log.TamperedUrl then
        return log.TamperedUrl
    end
    if pending and pending.Url then
        return pending.Url
    end
    return log and log.Url or ""
end

function HttpInterceptor:FinishInterceptTimeout(logId, log, response)
    CompletedResponses[logId] = response
    log.ReturnValue = response
    log.TimedOut = true
    log.Pending = false
    PendingRequests[logId] = nil
end

function HttpInterceptor:GetLogStatus(log)
    if log.Blocked then
        return "BLOCKED", Theme.Danger
    end
    if log.TimedOut then
        return "TIMEOUT", Theme.Warning
    end
    if log.Pending then
        if log.IsFetching then
            return "FETCH...", Theme.Cyan
        elseif log.FetchedResponse then
            return "READY", Theme.Success
        end
        return "PENDING", Theme.Warning
    end

    local returnValue = log.ReturnValue
    if isHttpTableResponseType(log.Type) and type(returnValue) == "table" then
        if returnValue.Success == false then
            return "FAIL", Theme.Danger
        end
        return "OK", Theme.Success
    end

    if isHttpStringResponseType(log.Type) then
        if returnValue == nil or returnValue == "" then
            return "EMPTY", Theme.Warning
        end
        return "OK", Theme.Success
    end

    if returnValue == nil then
        return "EMPTY", Theme.Warning
    end
    return "OK", Theme.Success
end

function HttpInterceptor:HasRequestSupport()
    return ClonedRequest ~= nil
end

function HttpInterceptor:IsTableResponseType(requestType)
    return isHttpTableResponseType(requestType)
end

function HttpInterceptor:CreateLog(requestType, url, method, body, headers, options)
    local log = {
        Id = HttpService:GenerateGUID(false),
        Timestamp = getTimestamp(),
        FullTimestamp = getFullTimestamp(),
        TickTime = tick(),
        Type = requestType,
        Url = url,
        Method = method or "GET",
        Body = body,
        Headers = headers,
        Options = options,
        ReturnValue = nil,
        FetchedResponse = nil,
        Blocked = false,
        Pending = false,
        IsFetching = false,
        TimedOut = false,
        Nocache = nil,
        ContentType = nil,
        
        TamperedUrl = nil,
        TamperedMethod = nil,
        TamperedBody = nil,
        TamperedHeaders = nil,
    }
    
    table.insert(self.Logs, 1, log)
    self.LogsById[log.Id] = log
    
    if self.MaxLogs ~= nil and #self.Logs > self.MaxLogs then
        local removed = table.remove(self.Logs)
        if removed and removed.Id then
            self.LogsById[removed.Id] = nil
        end
    end
    
    if self.OnLogAdded then
        task.spawn(self.OnLogAdded, log)
    end
    
    return log
end

function HttpInterceptor:FetchResponse(logId)
    local pending = PendingRequests[logId]
    if not pending then 
        return nil, "Not found"
    end
    
    local log = pending.Log
    
    
    if log.FetchedResponse ~= nil then
        return log.FetchedResponse
    end
    
    if log.IsFetching then
        return nil, "Already fetching"
    end
    
    local url = self:GetEffectiveUrl(log, pending)
    if self:IsUrlBlocked(url) then
        return nil, "URL is blocked"
    end
    
    log.IsFetching = true
    
    FetchingUrls[url] = true
    FetchingUrls[pending.Url] = true
    FetchingRequests[url] = true
    FetchingRequests[pending.Url] = true
    
    local result = nil
    local success, err = pcall(function()
        if pending.Type == "HttpGet" then
            result = ClonedHttpGet(game, url, pending.Nocache)
        elseif pending.Type == "HttpGetAsync" then
            result = ClonedHttpGetAsync(game, url, pending.Nocache)
        elseif pending.Type == "HttpPost" then
            result = ClonedHttpPost(game, url, pending.Body, pending.ContentType, pending.Nocache)
        elseif pending.Type == "HttpPostAsync" then
            result = ClonedHttpPostAsync(game, url, pending.Body, pending.ContentType, pending.Nocache)
        elseif pending.Type == "Request" then
            local options = {}
            for k, v in pairs(pending.Options or {}) do
                options[k] = v
            end
            
            options.Url = url
            options.Method = log.TamperedMethod or options.Method
            options.Body = log.TamperedBody or options.Body
            
            if log.TamperedHeaders then
                options.Headers = log.TamperedHeaders
            end
            
            result = ClonedRequest(options)
        elseif pending.Type == "RequestAsync" and ClonedRequestAsync then
            local options = {}
            for k, v in pairs(pending.Options or {}) do
                options[k] = v
            end
            
            options.Url = url
            options.Method = log.TamperedMethod or options.Method
            options.Body = log.TamperedBody or options.Body
            
            if log.TamperedHeaders then
                options.Headers = log.TamperedHeaders
            end
            
            result = ClonedRequestAsync(HttpService, options)
        end
    end)
    
    FetchingUrls[url] = nil
    FetchingUrls[pending.Url] = nil
    FetchingRequests[url] = nil
    FetchingRequests[pending.Url] = nil
    log.IsFetching = false
    
    if success and result ~= nil then
        log.FetchedResponse = result
        
        if self.OnResponseReady then
            task.spawn(self.OnResponseReady, log)
        end
        
        return result
    else
        return nil, tostring(err)
    end
end

function HttpInterceptor:ClearFetchedResponse(logId)
    local pending = PendingRequests[logId]
    if pending then
        pending.Log.FetchedResponse = nil
    end
end

function HttpInterceptor:AcceptResponse(logId, customResponse)
    local pending = PendingRequests[logId]
    if not pending then 
        return false
    end
    
    local log = pending.Log
    local response = customResponse or log.FetchedResponse
    
    if response == nil then
        return self:BlockRequest(logId)
    end
    
    if isHttpTableResponseType(pending.Type) and type(response) == "string" then
        response = {
            Success = true,
            StatusCode = 200,
            StatusMessage = "OK",
            Headers = {},
            Body = response,
        }
    end
    
    CompletedResponses[logId] = response
    log.ReturnValue = response
    log.Blocked = false
    
    PendingRequests[logId] = nil
    log.Pending = false
    
    return true
end

function HttpInterceptor:BlockRequest(logId)
    local pending = PendingRequests[logId]
    if not pending then 
        return false
    end
    
    local log = pending.Log
    
    local emptyResponse
    if isHttpTableResponseType(pending.Type) then
        emptyResponse = makeBlockedTableResponse()
    else
        emptyResponse = ""
    end
    
    CompletedResponses[logId] = emptyResponse
    log.ReturnValue = emptyResponse
    log.Blocked = true
    
    PendingRequests[logId] = nil
    log.Pending = false
    
    return true
end

function HttpInterceptor:ResendRequest(logId, callback)
    local log = nil
    
    
    for _, l in ipairs(self.Logs) do
        if l.Id == logId then
            log = l
            break
        end
    end
    
    
    if not log and PendingRequests[logId] then
        log = PendingRequests[logId].Log
    end
    
    if not log then
        if callback then callback(nil, "Log not found") end
        return nil, "Log not found"
    end
    
    if log.Type ~= "Request" and log.Type ~= "RequestAsync" then
        if callback then callback(nil, "Not a Request type") end
        return nil, "Not a Request type"
    end
    
    
    local options = {}
    
    
    if log.Options then
        for k, v in pairs(log.Options) do
            options[k] = v
        end
    end
    
    
    options.Url = log.TamperedUrl or log.Url
    options.Method = log.TamperedMethod or log.Method or "GET"
    
    
    if log.TamperedBody ~= nil then
        options.Body = log.TamperedBody
    elseif log.Body then
        options.Body = log.Body
    end
    
    
    if log.TamperedHeaders then
        options.Headers = log.TamperedHeaders
    elseif log.Headers then
        options.Headers = log.Headers
    end
    
    local url = options.Url
    if self:IsUrlBlocked(url) then
        if callback then callback(nil, "URL is blocked") end
        return nil, "URL is blocked"
    end
    
    FetchingRequests[url] = true
    if log.Url ~= url then
        FetchingRequests[log.Url] = true
    end
    
    local result = nil
    local success, err = pcall(function()
        if log.Type == "RequestAsync" and ClonedRequestAsync then
            result = ClonedRequestAsync(HttpService, options)
        else
            result = ClonedRequest(options)
        end
    end)
    
    FetchingRequests[url] = nil
    FetchingRequests[log.Url] = nil
    
    if success and result then
        if callback then callback(result, nil) end
        return result, nil
    else
        if callback then callback(nil, tostring(err)) end
        return nil, tostring(err)
    end
end

function HttpInterceptor:SetUrlBlocked(url, blocked)
    self.BlockedUrls[url] = blocked or nil
    if self.OnBlockStateChanged then
        task.defer(self.OnBlockStateChanged)
    end
end

function HttpInterceptor:ClearLogs()
    self:ReleaseAllPending()
    self.Logs = {}
    self.LogsById = {}
end

function HttpInterceptor:ReleaseAllPending()
    if self._pendingReleased then
        return
    end
    self._pendingReleased = true

    for logId, pending in pairs(PendingRequests) do
        pcall(function()
            local log = pending and pending.Log
            if not log then
                return
            end
            local emptyResponse = ""
            if isHttpTableResponseType(pending.Type) then
                emptyResponse = makeBlockedTableResponse()
            end
            CompletedResponses[logId] = emptyResponse
            log.ReturnValue = emptyResponse
            log.Blocked = true
            log.Pending = false
        end)
    end
    PendingRequests = {}
    CompletedResponses = {}
end

function HttpInterceptor:PurgeAll()
    self:ReleaseAllPending()
    FetchingUrls = {}
    FetchingRequests = {}
    self.Logs = {}
    self.LogsById = {}
    self.OnLogAdded = nil
    self.OnRequestPending = nil
    self.OnResponseReady = nil
    self.OnBlockStateChanged = nil
end

function HttpInterceptor:GetPendingCount()
    local count = 0
    for _ in pairs(PendingRequests) do
        count = count + 1
    end
    return count
end

function HttpInterceptor:Start()
    self.IsSpying = true
end

function HttpInterceptor:Stop()
    self.IsSpying = false
end

function HttpInterceptor:UninstallHooks()
    local hasStealthHooks = next(SpyStealth.MetaRecords) ~= nil or next(SpyStealth.FunctionHooks) ~= nil
    local hookStore = getHookGenvStore()
    local hasPersistedMeta = false
    for key, value in pairs(hookStore) do
        if type(value) == "function" and type(key) == "string" and key:find("@", 1, true) then
            hasPersistedMeta = true
            break
        end
    end
    if not self.IsHooked and not hasStealthHooks and not hasPersistedMeta and type(hookStore.requestAliases) ~= "table" then
        return
    end

    if not self._pendingReleased then
        self:ReleaseAllPending()
    end
    spyCleanupFrame()

    pcall(function()
        local env = getSpyGenv()
        if type(env) == "table" then
            local aliases = self.StoredRequestAliases or hookStore.requestAliases
            if type(aliases) == "table" then
                for key, original in pairs(aliases) do
                    if type(original) == "function" then
                        env[key] = original
                    end
                end
            elseif type(self.StoredRequest) == "function" then
                env.request = self.StoredRequest
            end
        end
    end)
    self.StoredRequest = nil
    self.StoredRequestProxy = nil
    self.StoredRequestAliases = nil
    spyCleanupFrame()

    SpyStealth:UninstallAllGentle()
    spyCleanupFrame()

    
    
    
    
    self.IsHooked = false
end

function HttpInterceptor:InstallHooks()
    if self.IsHooked then
        return
    end

    self._shuttingDown = false
    self._pendingReleased = false

    
    
    if next(SpyStealth.MetaRecords) ~= nil or next(SpyStealth.FunctionHooks) ~= nil then
        pcall(function()
            SpyStealth:UninstallAllGentle()
        end)
        spyCleanupFrame()
    else
        local hookStore = getHookGenvStore()
        if type(hookStore.requestAliases) == "table" then
            pcall(restorePersistedRequestAliases)
            spyCleanupFrame()
        end
        
        if hookStore.requestAliases ~= nil then
            hookStore.requestAliases = nil
        end
    end
    disarmMetaBridgeHandlers()

    SpyStealth:InstallDetectionSpoofs()
    
    PendingRequests = {}
    CompletedResponses = {}
    FetchingUrls = {}
    FetchingRequests = {}
    
    ClonedHttpGet = SpyStealth:CloneRaw(game.HttpGet)
    ClonedHttpGetAsync = SpyStealth:CloneRaw(game.HttpGetAsync)
    ClonedHttpPost = SpyStealth:CloneRaw(game.HttpPost)
    ClonedHttpPostAsync = SpyStealth:CloneRaw(game.HttpPostAsync)
    ClonedRequestAsync = SpyStealth:CloneRaw(HttpService.RequestAsync)
    
    pcall(function()
        if type(safeRequest) == "function" then
            ClonedRequest = SpyStealth:CloneRaw(safeRequest)
        end
    end)
    self.HasRequestApi = ClonedRequest ~= nil
    self.HasRequestAsyncApi = ClonedRequestAsync ~= nil
    
    local httpSpy = self
    
    local function waitForIntercept(log, logId, pendingType, timeoutResponse)
        log.Pending = true
        
        PendingRequests[logId] = {
            Log = log,
            Type = pendingType.Type,
            Url = pendingType.Url,
            Nocache = pendingType.Nocache,
            Body = pendingType.Body,
            ContentType = pendingType.ContentType,
            Options = pendingType.Options,
        }
        
        if httpSpy.OnRequestPending and not httpSpy._shuttingDown then
            task.spawn(httpSpy.OnRequestPending, log)
        end
        
        local startTime = tick()
        while log.Pending do
            if httpSpy._shuttingDown then
                log.Pending = false
                break
            end
            task.wait()
            if tick() - startTime > 300 then
                httpSpy:FinishInterceptTimeout(logId, log, timeoutResponse)
                break
            end
        end
        
        local result = CompletedResponses[logId]
        CompletedResponses[logId] = nil
        
        if result == nil then
            result = log.ReturnValue
        end
        if result == nil then
            result = timeoutResponse
        end
        
        return result
    end
    
    local function processHttpGet(url, nocache, isAsync)
        url = tostring(url or "")
        local methodName = isAsync and "HttpGetAsync" or "HttpGet"
        local clonedFunc = isAsync and ClonedHttpGetAsync or ClonedHttpGet
        
        if FetchingUrls[url] then
            return clonedFunc(game, url, nocache)
        end
        
        if not httpSpy.IsSpying then
            return clonedFunc(game, url, nocache)
        end
        
        local log = httpSpy:CreateLog(methodName, url, "GET", nil, nil, nil)
        log.Nocache = nocache
        local logId = log.Id
        
        if httpSpy:IsUrlBlocked(url) then
            log.Blocked = true
            log.ReturnValue = ""
            return ""
        end
        
        if httpSpy.InterceptEnabled then
            return waitForIntercept(log, logId, {
                Type = methodName,
                Url = url,
                Nocache = nocache,
            }, "")
        end
        
        FetchingUrls[url] = true
        local success, result = pcall(clonedFunc, game, url, nocache)
        FetchingUrls[url] = nil
        
        if success then
            log.ReturnValue = result
            return result
        end
        log.ReturnValue = ""
        return ""
    end
    
    local function processHttpPost(url, data, contentType, nocache, isAsync)
        url = tostring(url or "")
        data = data or ""
        local methodName = isAsync and "HttpPostAsync" or "HttpPost"
        local clonedFunc = isAsync and ClonedHttpPostAsync or ClonedHttpPost
        
        if FetchingUrls[url] then
            return clonedFunc(game, url, data, contentType, nocache)
        end
        
        if not httpSpy.IsSpying then
            return clonedFunc(game, url, data, contentType, nocache)
        end
        
        local log = httpSpy:CreateLog(methodName, url, "POST", data, nil, {
            ContentType = contentType,
            Nocache = nocache,
        })
        log.Nocache = nocache
        log.ContentType = contentType
        local logId = log.Id
        
        if httpSpy:IsUrlBlocked(url) then
            log.Blocked = true
            log.ReturnValue = ""
            return ""
        end
        
        if httpSpy.InterceptEnabled then
            return waitForIntercept(log, logId, {
                Type = methodName,
                Url = url,
                Body = data,
                ContentType = contentType,
                Nocache = nocache,
            }, "")
        end
        
        FetchingUrls[url] = true
        local success, result = pcall(clonedFunc, game, url, data, contentType, nocache)
        FetchingUrls[url] = nil
        
        if success then
            log.ReturnValue = result
            return result
        end
        log.ReturnValue = ""
        return ""
    end
    
    
    
    
    
    local function processRequest(options)
        if not ClonedRequest then
            if type(safeRequest) == "function" then
                return safeRequest(options)
            end
            return nil
        end
        
        local url = options and options.Url or ""
        local method = options and options.Method or "GET"
        local body = options and options.Body
        local headers = options and options.Headers
        
        if FetchingRequests[url] then
            return ClonedRequest(options)
        end
        
        if not httpSpy.IsSpying then
            return ClonedRequest(options)
        end
        
        local log = httpSpy:CreateLog("Request", url, method, body, headers, options)
        local logId = log.Id
        
        if httpSpy:IsUrlBlocked(url) then
            log.Blocked = true
            local empty = makeBlockedTableResponse()
            log.ReturnValue = empty
            return empty
        end
        
        if httpSpy.InterceptEnabled then
            local result = waitForIntercept(log, logId, {
                Type = "Request",
                Url = url,
                Options = options,
            }, makeTimeoutTableResponse())
            
            if result == nil then
                result = {
                    Success = false,
                    StatusCode = 0,
                    StatusMessage = "No response",
                    Headers = {},
                    Body = "",
                }
            end
            return result
        end
        
        
        if not ClonedRequest then
            return nil
        end
        FetchingRequests[url] = true
        local success, result = pcall(ClonedRequest, options)
        FetchingRequests[url] = nil
        
        if success then
            log.ReturnValue = result
            return result
        else
            local err = {Success = false, StatusCode = 0, StatusMessage = tostring(result), Headers = {}, Body = ""}
            log.ReturnValue = err
            return err
        end
    end
    
    local function processRequestAsync(requestOptions)
        if not ClonedRequestAsync then
            return HttpService:RequestAsync(requestOptions)
        end
        
        local options = requestOptions or {}
        local url = options.Url or ""
        local method = options.Method or "GET"
        local body = options.Body
        local headers = options.Headers
        
        if FetchingRequests[url] then
            return ClonedRequestAsync(HttpService, options)
        end
        
        if not httpSpy.IsSpying then
            return ClonedRequestAsync(HttpService, options)
        end
        
        local log = httpSpy:CreateLog("RequestAsync", url, method, body, headers, options)
        local logId = log.Id
        
        if httpSpy:IsUrlBlocked(url) then
            log.Blocked = true
            local empty = makeBlockedTableResponse()
            log.ReturnValue = empty
            return empty
        end
        
        if httpSpy.InterceptEnabled then
            local result = waitForIntercept(log, logId, {
                Type = "RequestAsync",
                Url = url,
                Options = options,
            }, makeTimeoutTableResponse())
            
            if result == nil then
                result = {
                    Success = false,
                    StatusCode = 0,
                    StatusMessage = "No response",
                    Headers = {},
                    Body = "",
                }
            end
            return result
        end
        
        FetchingRequests[url] = true
        local success, result = pcall(ClonedRequestAsync, HttpService, options)
        FetchingRequests[url] = nil
        
        if success then
            log.ReturnValue = result
            return result
        end
        local err = {Success = false, StatusCode = 0, StatusMessage = tostring(result), Headers = {}, Body = ""}
        log.ReturnValue = err
        return err
    end
    
    
    
    

    local httpGetProxy = SpyStealth:WrapCClosure(function(_, url, nocache)
        return processHttpGet(url, nocache, false)
    end)
    local httpGetAsyncProxy = SpyStealth:WrapCClosure(function(_, url, nocache)
        return processHttpGet(url, nocache, true)
    end)
    local httpPostProxy = SpyStealth:WrapCClosure(function(_, url, data, contentType, nocache)
        return processHttpPost(url, data, contentType, nocache, false)
    end)
    local httpPostAsyncProxy = SpyStealth:WrapCClosure(function(_, url, data, contentType, nocache)
        return processHttpPost(url, data, contentType, nocache, true)
    end)
    SpyStealth:RegisterProtected(httpGetProxy, "c", SpyStealth.Baseline.HttpSurfaceIsExecutor)
    SpyStealth:RegisterProtected(httpGetAsyncProxy, "c", SpyStealth.Baseline.HttpSurfaceIsExecutor)
    SpyStealth:RegisterProtected(httpPostProxy, "c", SpyStealth.Baseline.HttpSurfaceIsExecutor)
    SpyStealth:RegisterProtected(httpPostAsyncProxy, "c", SpyStealth.Baseline.HttpSurfaceIsExecutor)
    
    local REMOTE_METHODS = {
        FireServer = true,
        InvokeServer = true,
        Fire = true,
        Invoke = true,
    }
    local HTTP_METHODS = {
        HttpGet = true,
        HttpGetAsync = true,
        HttpPost = true,
        HttpPostAsync = true,
        RequestAsync = true,
    }

    local oldNamecall
    oldNamecall = SpyStealth:HookMetamethod(game, "__namecall", function(obj, ...)
        local method = getnamecallmethod()

        
        local isHttpMethod = HTTP_METHODS[method]
        local isRemoteMethod = REMOTE_METHODS[method]
        if not isHttpMethod and not (isRemoteMethod and RemoteScanner.IsSpying) then
            setnamecallmethod(method)
            return oldNamecall(obj, ...)
        end

        if isHttpMethod then
            if obj == game then
                if method == "HttpGet" then
                    local url, nocache = ...
                    return processHttpGet(url, nocache, false)
                elseif method == "HttpGetAsync" then
                    local url, nocache = ...
                    return processHttpGet(url, nocache, true)
                elseif method == "HttpPost" then
                    local url, data, contentType, nocache = ...
                    return processHttpPost(url, data, contentType, nocache, false)
                elseif method == "HttpPostAsync" then
                    local url, data, contentType, nocache = ...
                    return processHttpPost(url, data, contentType, nocache, true)
                end
            elseif obj == HttpService and method == "RequestAsync" then
                local options = ...
                return processRequestAsync(options)
            end
            setnamecallmethod(method)
            return oldNamecall(obj, ...)
        end

        
        if typeof(obj) ~= "Instance" then
            setnamecallmethod(method)
            return oldNamecall(obj, ...)
        end
        local className = obj.ClassName
        local args = {...}

        if method == "FireServer" then
            if className == "RemoteEvent" then
                local path, blocked, argHash, ignored = RemoteScanner:PrepareOutgoing(obj, args)
                if not ignored then
                    local callerFunc = nil
                    pcall(function() callerFunc = debug.info(2, "f") end)
                    if blocked then
                        RemoteScanner:QueueLog(obj, "RemoteEvent", args, callerFunc, nil, false, true, path, nil, argHash)
                        return RemoteScanner:GetBypassReturn(path, args, argHash)
                    end
                    RemoteScanner:QueueLog(obj, "RemoteEvent", args, callerFunc, nil, false, false, path, nil, argHash)
                end
                setnamecallmethod(method)
                return oldNamecall(obj, ...)
            elseif className == "UnreliableRemoteEvent" then
                local path, blocked, argHash, ignored = RemoteScanner:PrepareOutgoing(obj, args)
                if not ignored then
                    if blocked then
                        RemoteScanner:QueueLog(obj, "UnreliableRemoteEvent", args, nil, nil, false, true, path, nil, argHash)
                        return RemoteScanner:GetBypassReturn(path, args, argHash)
                    end
                    RemoteScanner:QueueLog(obj, "UnreliableRemoteEvent", args, nil, nil, false, false, path, nil, argHash)
                end
                setnamecallmethod(method)
                return oldNamecall(obj, ...)
            end
        elseif method == "InvokeServer" and className == "RemoteFunction" then
            local path, blocked, argHash, ignored = RemoteScanner:PrepareOutgoing(obj, args)
            if not ignored then
                local callerFunc = nil
                pcall(function() callerFunc = debug.info(2, "f") end)
                if blocked then
                    RemoteScanner:QueueLog(obj, "RemoteFunction", args, callerFunc, nil, false, true, path, nil, argHash)
                    return RemoteScanner:GetBypassReturn(path, args, argHash)
                end
                setnamecallmethod(method)
                local results = {oldNamecall(obj, ...)}
                RemoteScanner:QueueLog(obj, "RemoteFunction", args, callerFunc, results[1], false, false, path, nil, argHash)
                return unpack(results)
            end
            setnamecallmethod(method)
            return oldNamecall(obj, ...)
        elseif method == "Fire" and className == "BindableEvent" then
            local path, blocked, argHash, ignored = RemoteScanner:PrepareOutgoing(obj, args)
            if not ignored then
                if blocked then
                    RemoteScanner:QueueLog(obj, "BindableEvent", args, nil, nil, false, true, path, nil, argHash)
                    return RemoteScanner:GetBypassReturn(path, args, argHash)
                end
                RemoteScanner:QueueLog(obj, "BindableEvent", args, nil, nil, false, false, path, nil, argHash)
            end
            setnamecallmethod(method)
            return oldNamecall(obj, ...)
        elseif method == "Invoke" and className == "BindableFunction" then
            local path, blocked, argHash, ignored = RemoteScanner:PrepareOutgoing(obj, args)
            if not ignored then
                if blocked then
                    RemoteScanner:QueueLog(obj, "BindableFunction", args, nil, nil, false, true, path, nil, argHash)
                    return RemoteScanner:GetBypassReturn(path, args, argHash)
                end
                setnamecallmethod(method)
                local results = {oldNamecall(obj, ...)}
                RemoteScanner:QueueLog(obj, "BindableFunction", args, nil, results[1], false, false, path, nil, argHash)
                return unpack(results)
            end
            setnamecallmethod(method)
            return oldNamecall(obj, ...)
        end

        setnamecallmethod(method)
        return oldNamecall(obj, ...)
    end)
    
    local oldIndex
    oldIndex = SpyStealth:HookMetamethod(game, "__index", function(obj, key)
        
        
        
        
        if (not httpSpy.IsHooked) or httpSpy._shuttingDown then
            return oldIndex(obj, key)
        end
        if obj == game then
            if key == "HttpGet" then
                return httpGetProxy
            elseif key == "HttpGetAsync" then
                return httpGetAsyncProxy
            elseif key == "HttpPost" then
                return httpPostProxy
            elseif key == "HttpPostAsync" then
                return httpPostAsyncProxy
            end
        end
        return oldIndex(obj, key)
    end)
    
    local requestProxy = SpyStealth:WrapCClosure(function(options)
        return processRequest(options)
    end)
    SpyStealth:RegisterProtected(requestProxy, "c", true)
    self.StoredRequestProxy = requestProxy
    
    if ClonedRequest then
        pcall(function()
            if getgenv then
                local env = getgenv()
                if type(env) == "table" then
                    local hookStore = getHookStore()
                    hookStore.requestAliases = hookStore.requestAliases or {}
                    self.StoredRequestAliases = {}
                    local aliasKeys = {"request", "http_request", "httprequest"}
                    for _, key in ipairs(aliasKeys) do
                        if type(env[key]) == "function" then
                            if hookStore.requestAliases[key] == nil then
                                hookStore.requestAliases[key] = env[key]
                            end
                            self.StoredRequestAliases[key] = hookStore.requestAliases[key]
                            env[key] = requestProxy
                        end
                    end
                    self.StoredRequest = self.StoredRequestAliases.request
                end
            end
        end)
    end

    SpyStealth:SyncHookVisibility()
    
    self.IsHooked = true
end

local ModuleExplorer = {
    AllModules = {},           
    LoadedModules = {},        
    SearchFilter = "",
    SortMode = "name",         
    OnModulesRefreshed = nil,
    _scanId = 0,
    _scanRunning = false,
}

local MODULE_SCAN_BATCH_SIZE = 100
local MODULE_SCAN_TRAVERSE_YIELD_EVERY = 800
local MODULE_UI_YIELD_EVERY = 12

function ModuleExplorer:GetScanContainers()
    local containers = {
        safeService("ReplicatedStorage"),
        safeService("ReplicatedFirst"),
        safeService("StarterPlayer"),
        safeService("StarterGui"),
        safeService("StarterPack"),
    }
    
    pcall(function()
        table.insert(containers, safeService("Lighting"))
    end)
    pcall(function()
        local lp = LocalPlayer or safeCloneref(Players.LocalPlayer)
        table.insert(containers, safeCloneref(lp.PlayerScripts))
    end)
    pcall(function()
        local lp = LocalPlayer or safeCloneref(Players.LocalPlayer)
        table.insert(containers, safeCloneref(lp.PlayerGui))
    end)
    pcall(function()
        local lp = LocalPlayer or safeCloneref(Players.LocalPlayer)
        table.insert(containers, safeCloneref(lp.Backpack))
    end)
    pcall(function()
        local character = Players.LocalPlayer.Character
        if character then
            table.insert(containers, character)
        end
    end)
    
    return containers
end

function ModuleExplorer:CancelScan()
    self._scanId = (self._scanId or 0) + 1
    self._scanRunning = false
end

function ModuleExplorer:PurgeAll()
    self:CancelScan()
    self.AllModules = {}
    self.LoadedModules = {}
    self.OnModulesRefreshed = nil
end

function ModuleExplorer:ModuleMatchesFilter(moduleData)
    if self.SearchFilter == "" then
        return true
    end
    local filter = self.SearchFilter:lower()
    local nameLower = moduleData.Name:lower()
    local pathLower = moduleData.Path:lower()
    return nameLower:find(filter, 1, true) ~= nil or pathLower:find(filter, 1, true) ~= nil
end

local function flushModuleScanBatch(explorer, modules, pendingBatch, onBatchFound)
    if #pendingBatch == 0 then
        return
    end
    for _, moduleData in ipairs(pendingBatch) do
        table.insert(modules, moduleData)
        table.insert(explorer.AllModules, moduleData)
    end
    if onBatchFound then
        onBatchFound(pendingBatch, #modules)
    end
    for i = #pendingBatch, 1, -1 do
        pendingBatch[i] = nil
    end
end

function ModuleExplorer:ScanAllModulesAsync(onProgress, onComplete, onBatchFound)
    self:CancelScan()
    local scanId = self._scanId
    self._scanRunning = true
    self.AllModules = {}
    
    task.spawn(function()
        local modules = {}
        local pendingBatch = {}
        local queue = {}
        local visited = {}
        local processed = 0
        
        for _, container in ipairs(self:GetScanContainers()) do
            if container then
                table.insert(queue, container)
            end
        end
        
        while #queue > 0 do
            if self._scanId ~= scanId then
                return
            end
            
            local current = table.remove(queue, 1)
            if visited[current] then
                continue
            end
            visited[current] = true
            
            local children
            local ok = pcall(function()
                children = current:GetChildren()
            end)
            if not ok or not children then
                continue
            end
            
            for _, child in ipairs(children) do
                if self._scanId ~= scanId then
                    return
                end
                
                if child:IsA("ModuleScript") then
                    table.insert(pendingBatch, {
                        Module = child,
                        Name = child.Name,
                        Path = child:GetFullName(),
                        Parent = child.Parent and child.Parent.Name or "Unknown",
                    })
                    
                    if #pendingBatch >= MODULE_SCAN_BATCH_SIZE then
                        flushModuleScanBatch(self, modules, pendingBatch, onBatchFound)
                        if onProgress then
                            onProgress(#modules, processed)
                        end
                        RunService.Heartbeat:Wait()
                    end
                end
                
                table.insert(queue, child)
                processed = processed + 1
                
                if processed % MODULE_SCAN_TRAVERSE_YIELD_EVERY == 0 then
                    if onProgress then
                        onProgress(#modules + #pendingBatch, processed)
                    end
                    RunService.Heartbeat:Wait()
                end
            end
        end
        
        if self._scanId ~= scanId then
            return
        end
        
        flushModuleScanBatch(self, modules, pendingBatch, onBatchFound)
        
        table.sort(self.AllModules, function(a, b)
            return a.Name:lower() < b.Name:lower()
        end)
        modules = self.AllModules
        self._scanRunning = false
        
        if onComplete then
            onComplete(#modules)
        end
        if self.OnModulesRefreshed then
            task.spawn(self.OnModulesRefreshed)
        end
    end)
end

function ModuleExplorer:ScanAllModules()
    local done = false
    local total = 0
    self:ScanAllModulesAsync(nil, function(count)
        total = count
        done = true
    end)
    while not done and self._scanRunning do
        RunService.Heartbeat:Wait()
    end
    return self.AllModules
end

function ModuleExplorer:GetFilteredModules()
    if self.SearchFilter == "" then
        return self.AllModules
    end
    
    local filter = self.SearchFilter:lower()
    local nameMatches = {}
    local pathMatches = {}
    
    for _, mod in ipairs(self.AllModules) do
        local nameMatch = mod.Name:lower():find(filter, 1, true) ~= nil
        local pathMatch = mod.Path:lower():find(filter, 1, true) ~= nil
        
        if nameMatch then
            table.insert(nameMatches, mod)
        elseif pathMatch then
            table.insert(pathMatches, mod)
        end
    end
    
    
    local filtered = {}
    for _, mod in ipairs(nameMatches) do
        table.insert(filtered, mod)
    end
    for _, mod in ipairs(pathMatches) do
        table.insert(filtered, mod)
    end
    
    return filtered
end

local function resolveInstanceAtPath(path)
    if not path or path == "" then
        return nil
    end
    local ok, inst = pcall(function()
        local parts = {}
        for part in path:gmatch("[^%.]+") do
            table.insert(parts, part)
        end
        if #parts == 0 then
            return nil
        end
        local current = safeService(parts[1]) or safeGame:FindFirstChild(parts[1])
        if current then
            current = safeCloneref(current)
        end
        for i = 2, #parts do
            current = current and current:FindFirstChild(parts[i])
            if not current then
                return nil
            end
            current = safeCloneref(current)
        end
        return current
    end)
    return ok and inst or nil
end

local function nodeHasExpandableChildren(node)
    for _ in pairs(node.Children or {}) do
        return true
    end
    return #(node.Modules or {}) > 0
end

local function areTreeAncestorsExpanded(path, expandedNodes, parentByKey)
    if not path or path == "" then
        return true
    end
    local parent = parentByKey and parentByKey[path]
    while parent and parent ~= "" do
        if expandedNodes[parent] ~= true then
            return false
        end
        parent = parentByKey[parent]
    end
    return true
end

local function isTreePathDescendantOf(path, ancestorKey, parentByKey)
    if not path or not ancestorKey or ancestorKey == "" or path == ancestorKey then
        return false
    end
    if not parentByKey then
        return false
    end
    local parent = parentByKey[path]
    while parent and parent ~= "" do
        if parent == ancestorKey then
            return true
        end
        parent = parentByKey[parent]
    end
    return false
end

local function buildInstanceAncestorChain(inst)
    local chain = {}
    local current = inst
    while current and current ~= game do
        table.insert(chain, 1, current)
        current = current.Parent
    end
    return chain
end

local function getTreeNodeRowType(node)
    if node.SelfModule and not nodeHasExpandableChildren(node) then
        return "module"
    end
    if node.SelfModule or (node.ClassName == "ModuleScript" and nodeHasExpandableChildren(node)) then
        return "module_branch"
    end
    return "folder"
end

local function pruneTreeNodeDuplicateModules(node)
    local modules = node.Modules
    if modules then
        for i = #modules, 1, -1 do
            local mod = modules[i]
            local leafSegment = mod.Module and mod.Module.Name or (mod.Path and mod.Path:match("[^%.]+$"))
            if leafSegment and node.Children and node.Children[leafSegment] then
                table.remove(modules, i)
            end
        end
    end
    for _, child in pairs(node.Children or {}) do
        pruneTreeNodeDuplicateModules(child)
    end
end

local function getTreeClassSortPriority(className)
    if className == "Folder" then
        return 1
    end
    if className == "ModuleScript" then
        return 3
    end
    return 2
end

local function countModulesInTreeNode(node)
    local total = #(node.Modules or {})
    for _, child in ipairs(node.SortedChildren or {}) do
        if child.SelfModule then
            total = total + 1
        end
        total = total + countModulesInTreeNode(child)
    end
    return total
end

local function refreshTreeNodeClass(node)
    if not node then
        return
    end
    if node.SelfModule then
        node.ClassName = "ModuleScript"
    elseif node.Instance then
        node.ClassName = node.Instance.ClassName
    elseif node.Key and node.Key ~= "" then
        local inst = resolveInstanceAtPath(node.Key)
        if inst then
            node.ClassName = inst.ClassName
        end
    end
    for _, child in pairs(node.Children or {}) do
        refreshTreeNodeClass(child)
    end
end

local function sortModuleTreeNode(node)
    node.SortedChildren = {}
    for _, child in pairs(node.Children or {}) do
        sortModuleTreeNode(child)
        table.insert(node.SortedChildren, child)
    end
    table.sort(node.SortedChildren, function(a, b)
        local pa = getTreeClassSortPriority(a.ClassName or "Folder")
        local pb = getTreeClassSortPriority(b.ClassName or "Folder")
        if pa ~= pb then
            return pa < pb
        end
        return a.Name:lower() < b.Name:lower()
    end)
    
    table.sort(node.Modules or {}, function(a, b)
        return a.Name:lower() < b.Name:lower()
    end)
end

function ModuleExplorer:BuildModuleTree(modules)
    local root = {
        Key = "",
        Name = "game",
        ParentKey = nil,
        Children = {},
        Modules = {},
        Instance = nil,
    }
    local parentByKey = {}
    
    local function ensureChildNode(parentNode, childInst)
        local segment = childInst.Name
        local key = childInst:GetFullName()
        
        if not parentNode.Children[segment] then
            parentNode.Children[segment] = {
                Key = key,
                ParentKey = parentNode.Key,
                Name = segment,
                Children = {},
                Modules = {},
                SelfModule = nil,
                ClassName = childInst.ClassName,
                Instance = childInst,
            }
            parentByKey[key] = parentNode.Key
        else
            local childNode = parentNode.Children[segment]
            childNode.Key = key
            childNode.ParentKey = parentNode.Key
            childNode.Instance = childInst
            childNode.ClassName = childInst.ClassName
            parentByKey[key] = parentNode.Key
        end
        
        return parentNode.Children[segment]
    end
    
    for _, mod in ipairs(modules) do
        local inst = mod.Module
        if not inst or not inst.Parent then
            continue
        end
        
        local chain = buildInstanceAncestorChain(inst)
        if #chain == 0 then
            continue
        end
        
        local node = root
        for i = 1, #chain - 1 do
            node = ensureChildNode(node, chain[i])
        end
        
        local leafInst = chain[#chain]
        local leafSegment = leafInst.Name
        local leafKey = mod.Path or leafInst:GetFullName()
        
        if not node.Children[leafSegment] then
            node.Children[leafSegment] = {
                Key = leafKey,
                ParentKey = node.Key,
                Name = leafSegment,
                Children = {},
                Modules = {},
                SelfModule = nil,
                ClassName = "ModuleScript",
                Instance = leafInst,
            }
            parentByKey[leafKey] = node.Key
        else
            local leafNode = node.Children[leafSegment]
            leafNode.Key = leafKey
            leafNode.ParentKey = node.Key
            leafNode.Instance = leafInst
            leafNode.ClassName = "ModuleScript"
            parentByKey[leafKey] = node.Key
        end
        
        local leafNode = node.Children[leafSegment]
        leafNode.SelfModule = mod
        leafNode.ClassName = "ModuleScript"
        leafNode.Instance = leafInst
    end
    
    self._treeParentByKey = parentByKey
    pruneTreeNodeDuplicateModules(root)
    refreshTreeNodeClass(root)
    sortModuleTreeNode(root)
    return root
end

function ModuleExplorer:GetModuleByPath(path)
    if not path then
        return nil
    end
    for _, mod in ipairs(self.AllModules) do
        if mod.Path == path then
            return mod
        end
    end
    return nil
end

resolveModuleByPath = function(path)
    return ModuleExplorer:GetModuleByPath(path)
end

function ModuleExplorer:RequireModule(moduleData)
    local path = moduleData.Path
    
    if self.LoadedModules[path] then
        return self.LoadedModules[path]
    end
    
    local entry = {
        Module = moduleData.Module,
        Result = nil,
        LoadSuccess = false,
        LoadError = nil,
        Contents = {},   
        SortedContents = nil,  
    }
    
    local success, result = pcall(function()
        return require(moduleData.Module)
    end)
    
    entry.LoadSuccess = success
    if success then
        entry.Result = result
        entry.Contents = self:AnalyzeModuleContents(result)
    else
        entry.LoadError = tostring(result)
    end
    
    self.LoadedModules[path] = entry
    return entry
end

function ModuleExplorer:AnalyzeModuleContents(result)
    local contents = {}
    
    if type(result) ~= "table" then
        
        contents["[return]"] = {
            Key = "[return]",
            Type = type(result),
            Value = result,
            DisplayType = type(result),
            IsReturn = true,
        }
        return contents
    end
    
    
    local success, err = pcall(function()
        for key, value in pairs(result) do
            local keyStr = tostring(key)
            local valueType = type(value)
            local displayType = typeof(value)
            
            
            if type(key) == "string" and key:sub(1, 2) == "__" then
                continue
            end
            
            contents[keyStr] = {
                Key = key,
                KeyStr = keyStr,
                Type = valueType,
                DisplayType = displayType,
                Value = value,
                IsFunction = valueType == "function",
                IsTable = valueType == "table",
                IsInstance = displayType == "Instance",
                InstanceClass = (displayType == "Instance" and typeof(value) == "Instance") and value.ClassName or nil,
            }
            
            
            if valueType == "function" then
                local funcInfo = {}
                pcall(function()
                    local numArgs, isVariadic = debug.info(value, "a")
                    funcInfo.NumArgs = numArgs or 0
                    funcInfo.IsVariadic = isVariadic or false
                end)
                pcall(function()
                    funcInfo.Source = debug.info(value, "s")
                end)
                pcall(function()
                    funcInfo.Line = debug.info(value, "l")
                end)
                pcall(function()
                    funcInfo.Name = debug.info(value, "n")
                end)
                if islclosure then
                    pcall(function()
                        funcInfo.IsLuaClosure = islclosure(value)
                    end)
                end
                if iscclosure then
                    pcall(function()
                        funcInfo.IsCClosure = iscclosure(value)
                    end)
                end
                contents[keyStr].FuncInfo = funcInfo
            end
        end
    end)
    
    return contents
end

function ModuleExplorer:GetSortedContents(entry)
    
    if entry.SortedContents then
        return entry.SortedContents
    end
    
    local contents = entry.Contents
    local sorted = {}
    
    for keyStr, data in pairs(contents) do
        table.insert(sorted, data)
    end
    
    
    table.sort(sorted, function(a, b)
        
        local priorityA = a.IsFunction and 1 or (a.IsTable and 2 or 3)
        local priorityB = b.IsFunction and 1 or (b.IsTable and 2 or 3)
        
        if priorityA ~= priorityB then
            return priorityA < priorityB
        end
        
        return tostring(a.KeyStr):lower() < tostring(b.KeyStr):lower()
    end)
    
    
    entry.SortedContents = sorted
    return sorted
end

function ModuleExplorer:GenerateModulePath(moduleData)
    local path = moduleData.Path
    local parts = {}
    for part in path:gmatch("[^%.]+") do
        table.insert(parts, part)
    end
    
    if #parts == 0 then
        return "require(nil)"
    end
    
    local serviceName = parts[1]
    local line = 'require(game:GetService("' .. serviceName .. '")'
    
    for i = 2, #parts do
        line = line .. ':WaitForChild("' .. parts[i] .. '")'
    end
    
    line = line .. ")"
    return line
end

function ModuleExplorer:GenerateCallingCode(moduleData, contentData)
    local lines = {"-- Generated calling code"}
    table.insert(lines, "local module = " .. self:GenerateModulePath(moduleData))
    table.insert(lines, "")
    
    local keyAccess = type(contentData.Key) == "string" 
        and (contentData.Key:match("^[%a_][%w_]*$") and "." .. contentData.Key or '["' .. contentData.Key .. '"]')
        or "[" .. tostring(contentData.Key) .. "]"
    
    if contentData.IsFunction then
        local funcInfo = contentData.FuncInfo or {}
        local argCount = funcInfo.NumArgs or 0
        local isVariadic = funcInfo.IsVariadic or false
        
        
        local args = {}
        for i = 1, argCount do
            table.insert(args, "arg" .. i)
        end
        if isVariadic then
            table.insert(args, "...")
        end
        
        table.insert(lines, "local result = module" .. keyAccess .. "(" .. table.concat(args, ", ") .. ")")
        table.insert(lines, "print(result)")
    else
        table.insert(lines, "local value = module" .. keyAccess)
        table.insert(lines, "print(value)")
    end
    
    return table.concat(lines, "\n")
end

function ModuleExplorer:GenerateSetCode(moduleData, contentData, newValue)
    local lines = {"-- Generated set code"}
    table.insert(lines, "local module = " .. self:GenerateModulePath(moduleData))
    table.insert(lines, "")
    
    local keyAccess = type(contentData.Key) == "string" 
        and (contentData.Key:match("^[%a_][%w_]*$") and "." .. contentData.Key or '["' .. contentData.Key .. '"]')
        or "[" .. tostring(contentData.Key) .. "]"
    
    table.insert(lines, "module" .. keyAccess .. " = " .. (newValue or '"YOUR_VALUE_HERE"'))
    
    return table.concat(lines, "\n")
end

function ModuleExplorer:GenerateInterceptCode(moduleData, contentData)
    if not contentData.IsFunction then
        return "-- Intercept only works for functions", false
    end
    
    local usesHookfunction = isHookfunctionSupported()
    local lines = {
        "-- Generated by Spy Tool",
        "",
    }
    appendInterceptHookHeader(lines, usesHookfunction)
    
    table.insert(lines, "local module = " .. self:GenerateModulePath(moduleData))
    table.insert(lines, "")
    
    local keyAccess = type(contentData.Key) == "string" 
        and (contentData.Key:match("^[%a_][%w_]*$") and "." .. contentData.Key or '["' .. contentData.Key .. '"]')
        or "[" .. tostring(contentData.Key) .. "]"
    
    table.insert(lines, "local originalFunc = module" .. keyAccess)
    table.insert(lines, "")
    
    if usesHookfunction then
        table.insert(lines, "local oldFunc")
        table.insert(lines, "oldFunc = hookfunction(originalFunc, function(...)")
        table.insert(lines, '    local args = {...}')
        table.insert(lines, '    ')
        table.insert(lines, '    print("Intercepted ' .. contentData.KeyStr .. ':", unpack(args))')
        table.insert(lines, '    ')
        table.insert(lines, '    -- Modify args here if needed')
        table.insert(lines, '    -- args[1] = newValue')
        table.insert(lines, '    ')
        table.insert(lines, '    local result = oldFunc(unpack(args))')
        table.insert(lines, '    ')
        table.insert(lines, '    -- Modify result here if needed')
        table.insert(lines, '    -- result = modifiedResult')
        table.insert(lines, '    ')
        table.insert(lines, '    return result')
        table.insert(lines, 'end)')
    else
        table.insert(lines, "-- Replaces the export on the module table (does not use hookfunction)")
        table.insert(lines, "module" .. keyAccess .. " = function(...)")
        table.insert(lines, '    local args = {...}')
        table.insert(lines, '    ')
        table.insert(lines, '    print("Intercepted ' .. contentData.KeyStr .. ':", unpack(args))')
        table.insert(lines, '    ')
        table.insert(lines, '    -- Modify args here if needed')
        table.insert(lines, '    -- args[1] = newValue')
        table.insert(lines, '    ')
        table.insert(lines, '    local result = originalFunc(unpack(args))')
        table.insert(lines, '    ')
        table.insert(lines, '    -- Modify result here if needed')
        table.insert(lines, '    -- result = modifiedResult')
        table.insert(lines, '    ')
        table.insert(lines, '    return result')
        table.insert(lines, 'end')
    end
    
    return table.concat(lines, "\n"), usesHookfunction
end

function ModuleExplorer:DecompileFunction(func)
    if not func or type(func) ~= "function" then
        return "-- Not a function"
    end
    
    if decompile then
        local success, result = pcall(function()
            return decompile(func)
        end)
        if success and result then
            return result
        end
    end
    
    return "-- Decompilation not available"
end

local RequireScanner = {
    IsSpying = false,
    IsHooked = false,
    RequiredModules = {},
    GroupedLogs = {},
    IgnoredModules = {},
    BlockedModules = {},
    BlockedFunctions = {},
}

function RequireScanner:Start() self.IsSpying = true end
function RequireScanner:Stop() self.IsSpying = false end
function RequireScanner:ClearLogs() self.GroupedLogs = {} end
function RequireScanner:InstallHooks() self.IsHooked = true end
function RequireScanner:PurgeAll()
    self.IsSpying = false
    self.IsHooked = false
    self.RequiredModules = {}
    self.GroupedLogs = {}
    self.IgnoredModules = {}
    self.BlockedModules = {}
    self.BlockedFunctions = {}
end
function RequireScanner:GetSortedModules() return {} end
function RequireScanner:GetSortedFunctions() return {} end
function RequireScanner:GetSortedArgGroups() return {} end

local UIComponents = {}

local buttonBgState = setmetatable({}, { __mode = "k" })

local function setButtonBgState(button, baseBg, hoverBg)
    if button then
        buttonBgState[button] = { base = baseBg, hover = hoverBg }
    end
end

local function getButtonBaseBg(button, fallback)
    local state = buttonBgState[button]
    return state and state.base or fallback
end

local function getButtonHoverBg(button, fallback)
    local state = buttonBgState[button]
    return state and state.hover or fallback
end

function UIComponents.Badge(parent, text, color, size)
    size = size or 11
    local labelText = "  " .. tostring(text) .. "  "
    local width = measureTextWidth(labelText, size, Theme.FontFamilyBold) + 8
    local badge = createSquircle(Theme.Radius.Small, "Squircle", {
        Size = UDim2.new(0, width, 0, size + 8),
        ImageColor3 = color or Theme.Primary,
        ImageTransparency = 0.85,
        Parent = parent,
    }, false)
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = color or Theme.Primary,
        TextSize = size,
        Font = Theme.FontFamilyBold,
        Parent = badge
    })
    
    return badge
end

function UIComponents.Button(parent, text, variant, callback, icon)
    local bgColor, textColor, hoverColor
    
    if variant == "primary" then
        bgColor = Theme.Primary
        hoverColor = Theme.PrimaryHover
        textColor = Theme.TextPrimary
    elseif variant == "danger" then
        bgColor = Theme.Danger
        hoverColor = Theme.DangerMuted
        textColor = Theme.TextPrimary
    elseif variant == "success" then
        bgColor = Theme.Success
        hoverColor = Theme.SuccessMuted
        textColor = Theme.TextPrimary
    elseif variant == "warning" then
        bgColor = Theme.Warning
        hoverColor = Theme.WarningMuted
        textColor = Theme.Background
    elseif variant == "ghost" then
        bgColor = Theme.Background
        hoverColor = Theme.BackgroundTertiary
        textColor = Theme.TextSecondary
    else 
        bgColor = Theme.BackgroundTertiary
        hoverColor = Theme.BackgroundHover
        textColor = Theme.TextPrimary
    end
    
    local displayText = icon and (icon .. " " .. text) or text
    local labelText = "  " .. displayText .. "  "
    local width = math.max(56, measureTextWidth(labelText, 11, Theme.FontFamily) + 16)

    local button = createSquircle(Theme.Radius.Small, "Squircle", {
        Size = UDim2.new(0, width, 0, 30),
        ImageColor3 = bgColor,
        Parent = parent,
    }, true)
    
    if variant == "ghost" or variant == "secondary" or not variant then
        createSquircle(Theme.Radius.Small, "SquircleOutline", {
            Name = "Outline",
            Size = UDim2.new(1, 0, 1, 0),
            ImageColor3 = Theme.Border,
            ZIndex = 0,
            Parent = button,
        }, false)
    end
    
    createInstance("TextLabel", {
        Name = "Label",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = textColor,
        TextSize = 11,
        Font = Theme.FontFamily,
        ZIndex = 2,
        Parent = button
    })
    
    setButtonBgState(button, bgColor, hoverColor)

    button.MouseEnter:Connect(function()
        if isSquircle(button) then
            tween(button, {ImageColor3 = getButtonHoverBg(button, hoverColor)}, 0.15)
        else
            tween(button, {BackgroundColor3 = getButtonHoverBg(button, hoverColor)}, 0.15)
        end
    end)
    
    button.MouseLeave:Connect(function()
        if isSquircle(button) then
            tween(button, {ImageColor3 = getButtonBaseBg(button, bgColor)}, 0.15)
        else
            tween(button, {BackgroundColor3 = getButtonBaseBg(button, bgColor)}, 0.15)
        end
    end)
    
    button.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)
    
    return button
end

function UIComponents.IconButton(parent, icon, callback, size, tooltip)
    size = size or 28
    local isAssetIcon = type(icon) == "string" and icon:match("%.png$") ~= nil
    local assetUrl = isAssetIcon and getAssetImage(icon) or nil
    local textFallback = ""
    if isAssetIcon then
        if icon == "minimize.png" then
            textFallback = "_"
        elseif icon == "maximize.png" then
            textFallback = "□"
        elseif icon == "close.png" then
            textFallback = "X"
        elseif icon == "play.png" then
            textFallback = ">"
        elseif icon == "pause.png" then
            textFallback = "||"
        elseif icon == "clear.png" then
            textFallback = "C"
        elseif icon == "rescan.png" then
            textFallback = "R"
        else
            textFallback = "•"
        end
    else
        textFallback = tostring(icon or "")
    end
    
    local button = createSquircle(Theme.Radius.Small, "Squircle", {
        Size = UDim2.new(0, size, 0, size),
        ImageColor3 = Theme.BackgroundTertiary,
        ImageTransparency = 1,
        ZIndex = 12,
        Parent = parent,
    }, true)

    local textLabel = nil
    if not assetUrl then
        textLabel = createInstance("TextLabel", {
            Name = "Glyph",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = textFallback,
            TextColor3 = Theme.TextSecondary,
            TextSize = math.floor(size * 0.5),
            Font = Theme.FontFamily,
            ZIndex = 13,
            Parent = button,
        })
    end

    local iconImage = nil
    if assetUrl then
        iconImage = createInstance("ImageLabel", {
            Name = "IconImage",
            Size = UDim2.new(0, math.floor(size * 0.55), 0, math.floor(size * 0.55)),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Image = assetUrl,
            ImageColor3 = Theme.TextSecondary,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 13,
            Parent = button
        })
    end
    
    if tooltip then
        local tipText = "  " .. tooltip .. "  "
        local tipWidth = measureTextWidth(tipText, 11, Theme.FontFamily) + 12
        local tooltipLabel = createSquircle(Theme.Radius.Small, "Squircle", {
            Name = "Tooltip",
            Size = UDim2.new(0, tipWidth, 0, 24),
            Position = UDim2.new(0.5, 0, 1, 4),
            AnchorPoint = Vector2.new(0.5, 0),
            ImageColor3 = Theme.BackgroundSecondary,
            Visible = false,
            ZIndex = 9999,
            Parent = button,
        }, false)
        createSquircle(Theme.Radius.Small, "SquircleOutline", {
            Size = UDim2.new(1, 0, 1, 0),
            ImageColor3 = Theme.Border,
            ZIndex = 0,
            Parent = tooltipLabel,
        }, false)
        createInstance("TextLabel", {
            Name = "TooltipText",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = tipText,
            TextColor3 = Theme.TextPrimary,
            TextSize = 11,
            Font = Theme.FontFamily,
            ZIndex = 1,
            Parent = tooltipLabel,
        })
        
        button.MouseEnter:Connect(function()
            tooltipLabel.Visible = true
        end)
        
        button.MouseLeave:Connect(function()
            tooltipLabel.Visible = false
        end)
    end
    
    local function resolveIconBaseColor()
        local accent = button:GetAttribute("IconAccent")
        if accent == "danger" then
            return Theme.Danger
        elseif accent == "primary" then
            return Theme.Primary
        end
        return Theme.TextSecondary
    end

    button.MouseEnter:Connect(function()
        tween(button, {ImageTransparency = 0}, 0.15)
        if iconImage then
            tween(iconImage, {ImageColor3 = Theme.TextPrimary}, 0.15)
        end
        if textLabel then
            tween(textLabel, {TextColor3 = Theme.TextPrimary}, 0.15)
        end
    end)
    
    button.MouseLeave:Connect(function()
        tween(button, {ImageTransparency = 1}, 0.15)
        local base = resolveIconBaseColor()
        if iconImage then
            tween(iconImage, {ImageColor3 = base}, 0.15)
        end
        if textLabel then
            tween(textLabel, {TextColor3 = base}, 0.15)
        end
    end)
    
    button.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)
    
    return button
end

function UIComponents.Toggle(parent, initialState, callback, label)
    local state = initialState or false
    local trackW, trackH = 44, 24
    local knobSize = 18
    local knobPad = 3
    local dragging = false
    local didDrag = false
    
    local container = createInstance("Frame", {
        Size = UDim2.new(0, label and 200 or trackW, 0, trackH),
        BackgroundTransparency = 1,
        Parent = parent
    })
    
    if label then
        createInstance("TextLabel", {
            Size = UDim2.new(1, -(trackW + 8), 1, 0),
            BackgroundTransparency = 1,
            Text = label,
            TextColor3 = Theme.TextPrimary,
            TextSize = 13,
            Font = Theme.FontFamily,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = container
        })
    end
    
    local toggleBg = createInstance("Frame", {
        Size = UDim2.new(0, trackW, 0, trackH),
        Position = label and UDim2.new(1, -trackW, 0.5, -trackH / 2) or UDim2.new(0, 0, 0.5, -trackH / 2),
        BackgroundColor3 = state and Theme.Primary or Theme.BackgroundTertiary,
        BorderSizePixel = 0,
        
        ClipsDescendants = false,
        Parent = container
    })
    
    createCorner(toggleBg, Theme.CornerRadiusFull)
    
    
    local function knobPosForState(on)
        if on then
            return UDim2.new(1, -(knobPad + knobSize * 0.5), 0.5, 0)
        end
        return UDim2.new(0, knobPad + knobSize * 0.5, 0.5, 0)
    end

    local knob = createInstance("Frame", {
        Name = "Knob",
        Size = UDim2.new(0, knobSize, 0, knobSize),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = knobPosForState(state),
        BackgroundColor3 = Theme.TextPrimary,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = toggleBg
    })
    createCorner(knob, Theme.CornerRadiusFull)
    local knobScale = createInstance("UIScale", {
        Scale = 1,
        Parent = knob,
    })
    
    local hitbox = createInstance("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 3,
        Parent = toggleBg
    })
    
    local function updateState(newState, animate)
        state = newState == true
        local dur = animate == false and 0 or 0.2
        knobScale.Scale = 1
        knob.BackgroundTransparency = 0
        tween(toggleBg, {BackgroundColor3 = state and Theme.Primary or Theme.BackgroundTertiary}, dur)
        tween(knob, {Position = knobPosForState(state)}, dur)
    end
    
    local function setKnobDragging(active)
        if active then
            tween(knobScale, {Scale = 1.45}, 0.22)
            tween(knob, {BackgroundTransparency = 0.45}, 0.22)
        else
            tween(knobScale, {Scale = 1}, 0.2)
            tween(knob, {BackgroundTransparency = 0}, 0.2)
        end
    end
    
    local function finishDrag()
        if not dragging then
            return
        end
        dragging = false
        setKnobDragging(false)
        if didDrag then
            local centerX = knob.AbsolutePosition.X + knob.AbsoluteSize.X / 2
            local midX = toggleBg.AbsolutePosition.X + toggleBg.AbsoluteSize.X / 2
            local newState = centerX > midX
            updateState(newState, true)
            if callback then
                callback(state)
            end
        else
            updateState(not state, true)
            if callback then
                callback(state)
            end
        end
        didDrag = false
    end
    
    hitbox.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        dragging = true
        didDrag = false
        setKnobDragging(true)
    end)
    
    hitbox.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            finishDrag()
        end
    end)
    
    local dragConn = UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        if not toggleBg.Parent then
            dragging = false
            return
        end
        local minX = knobPad
        local maxX = trackW - knobSize - knobPad
        local rel = input.Position.X - toggleBg.AbsolutePosition.X - knobSize / 2
        rel = math.clamp(rel, minX, maxX)
        if math.abs(rel - (state and maxX or minX)) > 2 then
            didDrag = true
        end
        knob.Position = UDim2.new(0, rel, 0.5, -knobSize / 2)
        local pct = (rel - minX) / math.max(1, maxX - minX)
        toggleBg.BackgroundColor3 = Theme.BackgroundTertiary:Lerp(Theme.Primary, pct)
    end)
    
    container.Destroying:Connect(function()
        dragging = false
        if dragConn then
            pcall(function()
                dragConn:Disconnect()
            end)
            dragConn = nil
        end
    end)
    
    return container, updateState, function() return state end
end

function UIComponents.Checkbox(parent, initialState, callback, label)
    local state = initialState == true
    local interactive = type(callback) == "function"
    
    local container = createInstance("Frame", {
        Size = UDim2.new(0, label and 72 or 16, 0, 16),
        BackgroundTransparency = 1,
        Parent = parent
    })
    createListLayout(container, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
    
    local box = createSquircle(Theme.Radius.Small, "Squircle", {
        Name = "Checkbox",
        Size = UDim2.new(0, 16, 0, 16),
        ImageColor3 = state and Theme.Primary or Theme.BackgroundTertiary,
        LayoutOrder = 1,
        Active = interactive,
        Parent = container,
    }, interactive)
    if not interactive and box:IsA("ImageLabel") then
        
    elseif not interactive then
        box.Active = false
        pcall(function()
            box.AutoButtonColor = false
        end)
    end
    local outline = createSquircle(Theme.Radius.Small, "SquircleOutline", {
        Name = "Outline",
        Size = UDim2.new(1, 0, 1, 0),
        ImageColor3 = state and Theme.Primary or Theme.Border,
        ZIndex = 0,
        Parent = box,
    }, false)
    local checkIcon = createAssetGlyph(box, "check.png", 10, {
        Name = "CheckIcon",
        Position = UDim2.new(0.5, 0, 0.5, 0),
        ImageColor3 = Theme.TextPrimary,
        Visible = state,
        ZIndex = 2,
    })
    
    if label then
        createInstance("TextLabel", {
            Size = UDim2.new(0, 52, 1, 0),
            BackgroundTransparency = 1,
            Text = label,
            TextColor3 = Theme.TextSecondary,
            TextSize = 10,
            Font = Theme.FontFamily,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 2,
            Parent = container
        })
    end
    
    local function updateState(newState)
        state = newState == true
        setSquircleColor(box, state and Theme.Primary or Theme.BackgroundTertiary)
        outline.ImageColor3 = state and Theme.Primary or Theme.Border
        checkIcon.Visible = state
    end
    
    if interactive and box:IsA("GuiButton") then
        box.MouseButton1Click:Connect(function()
            updateState(not state)
            callback(state)
        end)
    end
    
    return container, updateState, function()
        return state
    end
end

function UIComponents.Slider(parent, min, max, initialValue, step, callback, formatValue, labelWidth, frictionOptions)
    min = min or 0
    max = max or 1
    step = step or 0.01
    labelWidth = labelWidth or 40
    local value = initialValue or min
    local dragging = false

    local frictionValue = frictionOptions and frictionOptions.frictionValue
    local confirmValue = frictionOptions and frictionOptions.confirmValue
    local frictionAlpha = frictionOptions and frictionOptions.frictionAlpha or 0.9
    local confirmAlpha = frictionOptions and frictionOptions.confirmAlpha or 1
    local hasFriction = frictionValue ~= nil and confirmValue ~= nil
    
    local container = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Parent = parent
    })
    
    local trackColor = Theme.BackgroundTertiary
    local bar = createInstance("Frame", {
        Size = UDim2.new(1, -(labelWidth + 4), 0, 6),
        Position = UDim2.new(0, 0, 0.5, -3),
        
        BackgroundColor3 = hasFriction and Color3.new(1, 1, 1) or trackColor,
        Parent = container
    })
    createCorner(bar, Theme.CornerRadiusFull)

    if hasFriction then
        local markPos = math.clamp(frictionAlpha, 0.02, 0.98)
        local lineSharp = 0.001
        local lineHalf = 0.004
        local linestart_2 = markPos - lineHalf
        local linestart_1 = linestart_2 - lineSharp
        local lineend_1 = markPos + lineHalf
        local lineend_2 = lineend_1 + lineSharp

        linestart_1 = math.clamp(linestart_1, 0, 1)
        linestart_2 = math.clamp(linestart_2, linestart_1 + 0.0001, 1)
        lineend_1 = math.clamp(lineend_1, linestart_2 + 0.0001, 1)
        lineend_2 = math.clamp(lineend_2, lineend_1 + 0.0001, 1)

        local lineColor = Theme.BorderHover
        createInstance("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, trackColor),
                ColorSequenceKeypoint.new(linestart_1, trackColor),
                ColorSequenceKeypoint.new(linestart_2, lineColor),
                ColorSequenceKeypoint.new(lineend_1, lineColor),
                ColorSequenceKeypoint.new(lineend_2, trackColor),
                ColorSequenceKeypoint.new(1, trackColor),
            }),
            Parent = bar
        })
    end
    
    local fill = createInstance("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.Primary,
        Parent = bar
    })
    createCorner(fill, Theme.CornerRadiusFull)

    local knobBase = 12
    local knob = createInstance("Frame", {
        Size = UDim2.new(0, knobBase, 0, knobBase),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = Theme.TextPrimary,
        BackgroundTransparency = 0,
        ZIndex = 3,
        Parent = bar
    })
    createCorner(knob, Theme.CornerRadiusFull)
    local knobScale = createInstance("UIScale", {
        Scale = 1,
        Parent = knob,
    })

    local function setSliderKnobDragging(active)
        if active then
            tween(knobScale, {Scale = 1.55}, 0.22)
            tween(knob, {BackgroundTransparency = 0.55}, 0.22)
        else
            tween(knobScale, {Scale = 1}, 0.2)
            tween(knob, {BackgroundTransparency = 0}, 0.2)
        end
    end
    
    local valueLabel = createInstance("TextLabel", {
        Size = UDim2.new(0, labelWidth, 1, 0),
        Position = UDim2.new(1, -labelWidth, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.TextMuted,
        TextSize = 10,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = container
    })
    
    local function format(v)
        if formatValue then
            return formatValue(v)
        end
        if max <= 1 then
            return string.format("%.2fs", v)
        end
        if step and step < 1 then
            return string.format("%.2f", v)
        end
        return tostring(math.floor(v + 0.5))
    end

    local function valueToAlpha(v)
        if not hasFriction then
            return (max == min) and 0 or (v - min) / (max - min)
        end
        if v >= confirmValue then
            return confirmAlpha
        end
        if v >= frictionValue then
            return frictionAlpha
        end
        if frictionValue == min then
            return 0
        end
        local t = (v - min) / (frictionValue - min)
        return t * frictionAlpha
    end

    local function relToValue(rel)
        rel = math.clamp(rel, 0, 1)
        if not hasFriction then
            return min + (max - min) * rel
        end
        if rel >= confirmAlpha then
            return confirmValue
        end
        if rel >= frictionAlpha then
            return frictionValue
        end
        local t = (frictionAlpha > 0) and (rel / frictionAlpha) or 0
        local raw = min + (frictionValue - min) * t
        if step and step > 0 then
            raw = math.floor((raw - min) / step + 0.5) * step + min
        end
        return math.clamp(raw, min, frictionValue)
    end
    
    local function applyValue(v, skipCallback)
        if max == min then
            v = min
        else
            v = math.clamp(v, min, max)
        end
        if not hasFriction then
            if step and step > 0 then
                v = math.floor((v - min) / step + 0.5) * step + min
            end
            value = math.clamp(v, min, max)
        elseif v >= confirmValue then
            value = confirmValue
        elseif v >= frictionValue then
            value = frictionValue
        else
            if step and step > 0 then
                v = math.floor((v - min) / step + 0.5) * step + min
            end
            value = math.clamp(v, min, frictionValue)
        end
        local alpha = valueToAlpha(value)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = format(value)
        if callback and not skipCallback then
            callback(value)
        end
    end
    
    local function updateFromX(x)
        if max == min then
            applyValue(min)
            return
        end
        local rel = (x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
        rel = math.clamp(rel, 0, 1)
        applyValue(relToValue(rel))
    end
    
    local function beginSliderDrag(input)
        dragging = true
        setSliderKnobDragging(true)
        updateFromX(input.Position.X)
    end

    local function endSliderDrag()
        if not dragging then
            return
        end
        dragging = false
        setSliderKnobDragging(false)
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            beginSliderDrag(input)
        end
    end)
    
    bar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            endSliderDrag()
        end
    end)
    
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            beginSliderDrag(input)
        end
    end)
    
    knob.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            endSliderDrag()
        end
    end)

    local endConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            endSliderDrag()
        end
    end)
    
    local dragConn = UserInputService.InputChanged:Connect(function(input)
        if not dragging or input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end
        if not bar.Parent then
            dragging = false
            return
        end
        updateFromX(input.Position.X)
    end)

    container.Destroying:Connect(function()
        dragging = false
        if dragConn then
            pcall(function()
                dragConn:Disconnect()
            end)
            dragConn = nil
        end
        if endConn then
            pcall(function()
                endConn:Disconnect()
            end)
            endConn = nil
        end
    end)
    
    applyValue(value, true)
    return container, function(v) applyValue(v) end, function() return value end
end

function UIComponents.NumberBox(parent, min, max, initialValue, step, callback, formatDisplay)
    min = min or 0
    max = max or 100
    step = step or 1
    local value = initialValue or min
    
    local inputHeight = 26
    local buttonWidth = 26
    local inputWidth = 50
    local totalWidth = buttonWidth + inputWidth + buttonWidth
    
    local container = createInstance("Frame", {
        Size = UDim2.new(0, totalWidth, 0, inputHeight),
        BackgroundColor3 = Theme.BackgroundTertiary,
        Parent = parent
    })
    
    createCorner(container, Theme.CornerRadiusFull)
    
    
    local minusBtn = createInstance("TextButton", {
        Size = UDim2.new(0, buttonWidth, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
        Parent = container
    })
    createCorner(minusBtn, Theme.CornerRadiusSmall)
    
    local minusBtnLabel = createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "-",
        TextColor3 = Theme.TextPrimary,
        TextSize = 14,
        Font = Theme.FontFamilyBold,
        ZIndex = 2,
        Parent = minusBtn
    })
    
    
    local minusBtnHighlight = createInstance("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.BackgroundHover,
        BackgroundTransparency = 1,
        ZIndex = 0,
        Parent = minusBtn
    })
    createCorner(minusBtnHighlight, Theme.CornerRadiusSmall)
    createInstance("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.75, 0),
            NumberSequenceKeypoint.new(0.76, 1),
            NumberSequenceKeypoint.new(1, 1)
        }),
        Parent = minusBtnHighlight
    })
    local minusHighlightExtend = createInstance("Frame", {
        Size = UDim2.new(0.3, 0, 1, 0),
        Position = UDim2.new(0.7, 0, 0, 0),
        BackgroundColor3 = Theme.BackgroundHover,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 0,
        Parent = minusBtn
    })
    
    
    createInstance("Frame", {
        Size = UDim2.new(0, 1, 1, -6),
        Position = UDim2.new(0, buttonWidth, 0, 3),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
        Parent = container
    })
    
    
    local input = createInstance("TextBox", {
        Size = UDim2.new(0, inputWidth, 1, 0),
        Position = UDim2.new(0, buttonWidth, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Theme.FontFamilyMono,
        Parent = container
    })
    
    
    createInstance("Frame", {
        Size = UDim2.new(0, 1, 1, -6),
        Position = UDim2.new(0, buttonWidth + inputWidth, 0, 3),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
        Parent = container
    })
    
    
    local plusBtn = createInstance("TextButton", {
        Size = UDim2.new(0, buttonWidth, 1, 0),
        Position = UDim2.new(0, buttonWidth + inputWidth, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
        Parent = container
    })
    createCorner(plusBtn, Theme.CornerRadiusSmall)
    
    local plusBtnLabel = createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "+",
        TextColor3 = Theme.TextPrimary,
        TextSize = 14,
        Font = Theme.FontFamilyBold,
        ZIndex = 2,
        Parent = plusBtn
    })
    
    
    local plusBtnHighlight = createInstance("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.BackgroundHover,
        BackgroundTransparency = 1,
        ZIndex = 0,
        Parent = plusBtn
    })
    createCorner(plusBtnHighlight, Theme.CornerRadiusSmall)
    createInstance("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.24, 1),
            NumberSequenceKeypoint.new(0.25, 0),
            NumberSequenceKeypoint.new(1, 0)
        }),
        Parent = plusBtnHighlight
    })
    local plusHighlightExtend = createInstance("Frame", {
        Size = UDim2.new(0.3, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Theme.BackgroundHover,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 0,
        Parent = plusBtn
    })
    
    
    minusBtn.MouseEnter:Connect(function()
        tween(minusBtnHighlight, {BackgroundTransparency = 0}, 0.15)
        tween(minusHighlightExtend, {BackgroundTransparency = 0}, 0.15)
    end)
    minusBtn.MouseLeave:Connect(function()
        tween(minusBtnHighlight, {BackgroundTransparency = 1}, 0.15)
        tween(minusHighlightExtend, {BackgroundTransparency = 1}, 0.15)
    end)
    plusBtn.MouseEnter:Connect(function()
        tween(plusBtnHighlight, {BackgroundTransparency = 0}, 0.15)
        tween(plusHighlightExtend, {BackgroundTransparency = 0}, 0.15)
    end)
    plusBtn.MouseLeave:Connect(function()
        tween(plusBtnHighlight, {BackgroundTransparency = 1}, 0.15)
        tween(plusHighlightExtend, {BackgroundTransparency = 1}, 0.15)
    end)
    
    local function format(v)
        if formatDisplay then
            return formatDisplay(v)
        end
        return tostring(v)
    end
    
    local function updateDisplay()
        input.Text = format(value)
    end
    
    local function applyValue(newValue, skipCallback)
        newValue = math.clamp(newValue, min, max)
        if step and step > 0 then
            newValue = math.floor((newValue - min) / step + 0.5) * step + min
        end
        value = math.clamp(newValue, min, max)
        updateDisplay()
        if callback and not skipCallback then
            callback(value)
        end
    end
    
    minusBtn.MouseButton1Click:Connect(function()
        applyValue(value - step)
    end)
    
    plusBtn.MouseButton1Click:Connect(function()
        applyValue(value + step)
    end)
    
    input.FocusLost:Connect(function()
        local text = input.Text:gsub("[^%d%.%-]", "")
        local num = tonumber(text)
        if num then
            applyValue(num)
        else
            updateDisplay()
        end
    end)
    
    applyValue(value, true)
    return container, function(v) applyValue(v) end, function() return value end
end

function UIComponents.SearchBar(parent, placeholder, callback)
    local container = createSquircle(Theme.Radius.Small, "Squircle", {
        Size = UDim2.new(1, 0, 1, 0),
        ImageColor3 = Theme.BackgroundSecondary,
        Parent = parent,
    }, false)
    local outline = createSquircle(Theme.Radius.Small, "SquircleOutline", {
        Name = "Outline",
        Size = UDim2.new(1, 0, 1, 0),
        ImageColor3 = Theme.Border,
        ZIndex = 0,
        Parent = container,
    }, false)
    
    local input = createInstance("TextBox", {
        Size = UDim2.new(1, -34, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = placeholder or "Search...",
        PlaceholderColor3 = Theme.TextMuted,
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        ZIndex = 1,
        Parent = container
    })

    local clearBtn = createInstance("ImageButton", {
        Name = "ClearSearch",
        Size = UDim2.new(0, 16, 0, 16),
        Position = UDim2.new(1, -22, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Image = "",
        ImageColor3 = Theme.TextMuted,
        ScaleType = Enum.ScaleType.Fit,
        Visible = false,
        ZIndex = 2,
        AutoButtonColor = false,
        Parent = container,
    })
    local clearUrl = getAssetImage("close.png")
    if clearUrl then
        clearBtn.Image = clearUrl
    else
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "×",
            TextColor3 = Theme.TextMuted,
            TextSize = 14,
            Font = Theme.FontFamilyBold,
            ZIndex = 1,
            Parent = clearBtn,
        })
    end

    local function syncClearVisible()
        clearBtn.Visible = input.Text ~= ""
    end

    clearBtn.MouseButton1Click:Connect(function()
        input.Text = ""
        input:CaptureFocus()
        if callback then
            callback("")
        end
        syncClearVisible()
    end)
    clearBtn.MouseEnter:Connect(function()
        clearBtn.ImageColor3 = Theme.TextPrimary
    end)
    clearBtn.MouseLeave:Connect(function()
        clearBtn.ImageColor3 = Theme.TextMuted
    end)
    
    input.Focused:Connect(function()
        tween(outline, {ImageColor3 = Theme.Primary}, 0.15)
    end)
    
    input.FocusLost:Connect(function()
        tween(outline, {ImageColor3 = Theme.Border}, 0.15)
    end)
    
    input:GetPropertyChangedSignal("Text"):Connect(function()
        syncClearVisible()
        if callback then callback(input.Text) end
    end)
    
    return container, input
end

local function findScreenGui(instance)
    local current = instance
    while current and not current:IsA("ScreenGui") do
        current = current.Parent
    end
    return current
end

function UIComponents.Dropdown(parent, options, defaultOption, callback)
    local isOpen = false
    local selectedOption = defaultOption or options[1]
    local menuHeight = #options * 26 + 8
    local dockedMenuPos = UDim2.new(0, 0, 1, 4)
    local dockedMenuSize = UDim2.new(1, 0, 0, menuHeight)
    
    local container = createInstance("Frame", {
        Size = UDim2.new(0, 120, 1, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = false,
        ZIndex = 50,
        Parent = parent
    })
    
    local button = createSquircle(Theme.Radius.Small, "Squircle", {
        Size = UDim2.new(1, 0, 1, 0),
        ImageColor3 = Theme.BackgroundSecondary,
        ZIndex = 50,
        Parent = container,
    }, true)
    createSquircle(Theme.Radius.Small, "SquircleOutline", {
        Size = UDim2.new(1, 0, 1, 0),
        ImageColor3 = Theme.Border,
        ZIndex = 0,
        Parent = button,
    }, false)
    
    local label = createInstance("TextLabel", {
        Size = UDim2.new(1, -28, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        Text = selectedOption,
        TextColor3 = Theme.TextPrimary,
        TextSize = 11,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 51,
        Parent = button
    })
    
    local arrow = createAssetGlyph(button, "chevron.png", 10, {
        Name = "Chevron",
        Position = UDim2.new(1, -14, 0.5, 0),
        ImageColor3 = Theme.TextMuted,
        ZIndex = 51,
    })
    
    local optionsFrame = createSquircle(Theme.Radius.Small, "Squircle", {
        Name = "DropdownMenu",
        Size = dockedMenuSize,
        Position = dockedMenuPos,
        ImageColor3 = Theme.BackgroundSecondary,
        Visible = false,
        ZIndex = 100,
        Parent = container,
    }, false)
    createSquircle(Theme.Radius.Small, "SquircleOutline", {
        Size = UDim2.new(1, 0, 1, 0),
        ImageColor3 = Theme.Border,
        ZIndex = 0,
        Parent = optionsFrame,
    }, false)
    local optionsContent = createInstance("Frame", {
        Name = "MenuContent",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ZIndex = 101,
        Parent = optionsFrame,
    })
    createPadding(optionsContent, 4)
    createListLayout(optionsContent, 2)

    local function bumpMenuZ(base)
        optionsFrame.ZIndex = base
        optionsContent.ZIndex = base + 1
        for _, child in ipairs(optionsContent:GetChildren()) do
            if child:IsA("GuiObject") then
                child.ZIndex = base + 2
            end
        end
    end

    local function dockOptionsMenu()
        optionsFrame.Parent = container
        optionsFrame.AnchorPoint = Vector2.new(0, 0)
        optionsFrame.Position = dockedMenuPos
        optionsFrame.Size = dockedMenuSize
        bumpMenuZ(100)
    end

    local function floatOptionsMenu()
        local screenGui = findScreenGui(container)
        if not screenGui then
            dockOptionsMenu()
            return
        end
        local absPos = container.AbsolutePosition
        local absSize = container.AbsoluteSize
        optionsFrame.AnchorPoint = Vector2.new(0, 0)
        optionsFrame.Position = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 4)
        optionsFrame.Size = UDim2.new(0, math.max(absSize.X, 120), 0, menuHeight)
        optionsFrame.Parent = screenGui
        bumpMenuZ(300)
    end

    local function setOpen(open)
        isOpen = open
        if isOpen then
            floatOptionsMenu()
        else
            dockOptionsMenu()
        end
        optionsFrame.Visible = isOpen
        tween(arrow, {Rotation = isOpen and 180 or 0}, 0.2)
    end

    local function syncOptionColors()
        for _, child in ipairs(optionsContent:GetChildren()) do
            if child:IsA("TextButton") then
                local optLabel = child:FindFirstChild("Label")
                if optLabel then
                    optLabel.TextColor3 = optLabel.Text == selectedOption and Theme.Primary or Theme.TextPrimary
                end
            end
        end
    end
    
    for i, option in ipairs(options) do
        local optBtn = createInstance("TextButton", {
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundColor3 = Theme.BackgroundTertiary,
            BackgroundTransparency = 1,
            Text = "",
            LayoutOrder = i,
            ZIndex = 102,
            Parent = optionsContent
        })
        createCorner(optBtn, Theme.CornerRadiusSmall)
        createInstance("TextLabel", {
            Name = "Label",
            Size = UDim2.new(1, -12, 1, 0),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = option,
            TextColor3 = option == selectedOption and Theme.Primary or Theme.TextPrimary,
            TextSize = 11,
            Font = Theme.FontFamily,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 103,
            Parent = getG2Content(optBtn),
        })
        
        optBtn.MouseEnter:Connect(function()
            tween(optBtn, {BackgroundTransparency = 0}, 0.1)
        end)
        
        optBtn.MouseLeave:Connect(function()
            tween(optBtn, {BackgroundTransparency = 1}, 0.1)
        end)
        
        optBtn.MouseButton1Click:Connect(function()
            selectedOption = option
            label.Text = option
            syncOptionColors()
            setOpen(false)
            if callback then callback(option) end
        end)
    end

    button.MouseButton1Click:Connect(function()
        setOpen(not isOpen)
    end)

    local function isPointInside(frame, pos)
        local absPos = frame.AbsolutePosition
        local absSize = frame.AbsoluteSize
        return pos.X >= absPos.X and pos.X <= absPos.X + absSize.X
            and pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y
    end

    local outsideClickConn = UserInputService.InputBegan:Connect(function(input)
        if not isOpen or not container.Parent then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local pos = input.Position
        if isPointInside(button, pos) or isPointInside(optionsFrame, pos) then
            return
        end
        setOpen(false)
    end)

    container.Destroying:Connect(function()
        if outsideClickConn then
            outsideClickConn:Disconnect()
            outsideClickConn = nil
        end
        if optionsFrame.Parent and optionsFrame.Parent ~= container then
            optionsFrame:Destroy()
        end
    end)

    return container, function() return selectedOption end
end

function UIComponents.Separator(parent)
    return createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Border,
        Parent = parent
    })
end

function UIComponents.ScrollFrame(parent, autoSize)
    local scroll = createInstance("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.BorderHover,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = autoSize or Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ClipsDescendants = true,
        Parent = parent
    })
    
    return scroll
end

function UIComponents.ClippedScrollText(parent, displayText, options)
    options = options or {}
    local textColor = options.TextColor or Theme.TextPrimary
    local maxHeight = options.MaxHeight or 200
    local layoutOrder = options.LayoutOrder or 0
    local lineHeight = options.LineHeight or 12

    local lineCount = 1
    for _ in displayText:gmatch("\n") do
        lineCount = lineCount + 1
    end

    local scrollContainer = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, math.min(lineCount * lineHeight + 16, maxHeight)),
        BackgroundColor3 = Theme.Background,
        ClipsDescendants = true,
        LayoutOrder = layoutOrder,
        Parent = parent
    })
    createCorner(scrollContainer, Theme.CornerRadiusSmall)

    local contentScroll = createInstance("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.BorderHover,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.XY,
        ScrollingDirection = Enum.ScrollingDirection.XY,
        ClipsDescendants = true,
        Parent = scrollContainer
    })
    createPadding(contentScroll, 6)

    createInstance("TextLabel", {
        Size = UDim2.new(0, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundTransparency = 1,
        Text = displayText,
        TextColor3 = textColor,
        TextSize = 10,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = false,
        Parent = contentScroll
    })

    return scrollContainer
end

function UIComponents.ContextMenu(items, position, parent)
    
    local existing = parent:FindFirstChild("ContextMenu")
    if existing then existing:Destroy() end
    local existingClose = parent:FindFirstChild("ContextMenuClose")
    if existingClose then existingClose:Destroy() end
    
    
    local closeBtn = createInstance("TextButton", {
        Name = "ContextMenuClose",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 500,
        Parent = parent
    })
    
    local menu = createInstance("TextButton", {
        Name = "ContextMenu",
        Size = UDim2.new(0, 180, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.new(0, position.X, 0, position.Y),
        BackgroundColor3 = Theme.BackgroundSecondary,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 501,
        Parent = parent
    })
    createCorner(menu, Theme.CornerRadius)
    createStroke(menu, Theme.Border)
    createPadding(menu, 4)
    createListLayout(menu, 2)
    
    for i, item in ipairs(items) do
        if item.Separator then
            createInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = Theme.Border,
                LayoutOrder = i,
                ZIndex = 502,
                Parent = menu
            })
        else
            local btn = createInstance("TextButton", {
                Size = UDim2.new(1, 0, 0, 26),
                BackgroundColor3 = Theme.BackgroundTertiary,
                BackgroundTransparency = 1,
                Text = "",
                LayoutOrder = i,
                ZIndex = 502,
                Parent = menu
            })
            createCorner(btn, Theme.CornerRadiusSmall)
            
            local icon = item.Icon or ""
            local text = item.Text or ""
            
            createInstance("TextLabel", {
                Size = UDim2.new(1, -16, 1, 0),
                Position = UDim2.new(0, 8, 0, 0),
                BackgroundTransparency = 1,
                Text = icon .. (icon ~= "" and "  " or "") .. text,
                TextColor3 = item.Danger and Theme.Danger or Theme.TextPrimary,
                TextSize = 11,
                Font = Theme.FontFamily,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 503,
                Parent = btn
            })
            
            btn.MouseEnter:Connect(function()
                tween(btn, {BackgroundTransparency = 0}, 0.1)
            end)
            
            btn.MouseLeave:Connect(function()
                tween(btn, {BackgroundTransparency = 1}, 0.1)
            end)
            
            btn.MouseButton1Click:Connect(function()
                menu:Destroy()
                closeBtn:Destroy()
                if item.Callback then item.Callback() end
            end)
        end
    end
    
    closeBtn.MouseButton1Click:Connect(function()
        menu:Destroy()
        closeBtn:Destroy()
    end)
    
    return menu
end

function UIComponents.Modal(parent, title, size, content)
    
    local backdrop = createInstance("Frame", {
        Name = "ModalBackdrop",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.Shadow,
        BackgroundTransparency = 0.7,
        ZIndex = 1000,
        Parent = parent
    })
    
    local modal = createSquircle(Theme.Radius.Large, "Squircle", {
        Name = "Modal",
        Size = size or UDim2.new(0, 500, 0, 400),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ImageColor3 = Theme.Background,
        ZIndex = 1001,
        Parent = backdrop,
    }, true)
    createSquircle(Theme.Radius.Large, "SquircleOutline", {
        Size = UDim2.new(1, 0, 1, 0),
        ImageColor3 = Theme.Border,
        ZIndex = 1001,
        Parent = modal,
    }, false)
    
    local header = createSquircle(Theme.Radius.Large, "Squircle-TL-TR", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 44),
        ImageColor3 = Theme.BackgroundSecondary,
        ZIndex = 1002,
        Parent = modal,
    }, true)
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.new(0, 16, 0, 0),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.TextPrimary,
        TextSize = 14,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 1003,
        Parent = header
    })
    
    local closeBtn = createSquircle(Theme.Radius.Small, "Squircle", {
        Size = UDim2.new(0, 26, 0, 26),
        Position = UDim2.new(1, -36, 0.5, -13),
        AnchorPoint = Vector2.new(0, 0.5),
        ImageColor3 = Theme.BackgroundTertiary,
        ImageTransparency = 1,
        ZIndex = 1003,
        Parent = header,
    }, true)
    local closeGlyph = createAssetGlyph(closeBtn, "close.png", 12, {
        Name = "Glyph",
        Position = UDim2.new(0.5, 0, 0.5, 0),
        ImageColor3 = Theme.TextSecondary,
        ZIndex = 1004,
    })
    
    closeBtn.MouseEnter:Connect(function()
        tween(closeBtn, {ImageTransparency = 0}, 0.15)
        if closeGlyph then
            tween(closeGlyph, {ImageColor3 = Theme.TextPrimary}, 0.15)
        end
    end)
    
    closeBtn.MouseLeave:Connect(function()
        tween(closeBtn, {ImageTransparency = 1}, 0.15)
        if closeGlyph then
            tween(closeGlyph, {ImageColor3 = Theme.TextSecondary}, 0.15)
        end
    end)
    
    closeBtn.MouseButton1Click:Connect(function()
        backdrop:Destroy()
    end)
    
    
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = modal.Position
        end
    end)
    
    header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    local dragConnection = UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        if not modal.Parent then
            dragging = false
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement or
            input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            modal.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    
    backdrop.Destroying:Connect(function()
        dragConnection:Disconnect()
    end)
    
    
    local contentFrame = createInstance("Frame", {
        Size = UDim2.new(1, 0, 1, -44),
        Position = UDim2.new(0, 0, 0, 44),
        BackgroundTransparency = 1,
        ZIndex = 1002,
        Parent = modal
    })
    createPadding(contentFrame, 14)
    
    if content then
        content(contentFrame)
    end
    
    return backdrop, modal, contentFrame
end

function UIComponents.ChunkedTextArea(parent, initialText, readOnly, onChunkChanged)
    local CHUNK_SIZE = 90000
    
    local container = createInstance("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.BackgroundSecondary,
        Parent = parent
    })
    createCorner(container, Theme.CornerRadiusSmall)
    
    local chunks = {}
    local currentChunkIndex = 1
    local fullText = initialText or ""
    
    local function splitIntoChunks(text)
        chunks = {}
        if #text == 0 then
            chunks[1] = ""
            return
        end
        
        local pos = 1
        while pos <= #text do
            local chunkEnd = math.min(pos + CHUNK_SIZE - 1, #text)
            table.insert(chunks, text:sub(pos, chunkEnd))
            pos = chunkEnd + 1
        end
    end
    
    local function getFullText()
        return table.concat(chunks)
    end
    
    splitIntoChunks(fullText)
    
    
    local header = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = Theme.BackgroundTertiary,
        Parent = container
    })
    createCorner(header, Theme.CornerRadiusSmall)
    
    local infoLabel = createInstance("TextLabel", {
        Size = UDim2.new(0.5, 0, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        Text = string.format("Chunk 1/%d | Total: %d chars", #chunks, #fullText),
        TextColor3 = Theme.TextMuted,
        TextSize = 10,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header
    })
    
    local navContainer = createInstance("Frame", {
        Size = UDim2.new(0, 120, 1, 0),
        Position = UDim2.new(1, -125, 0, 0),
        BackgroundTransparency = 1,
        Parent = header
    })
    createListLayout(navContainer, 4, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
    
    local prevBtn = UIComponents.Button(navContainer, "<", nil, function() end)
    prevBtn.Size = UDim2.new(0, 28, 0, 20)
    prevBtn.LayoutOrder = 1
    
    local chunkLabel = createInstance("TextLabel", {
        Size = UDim2.new(0, 40, 0, 20),
        BackgroundTransparency = 1,
        Text = "1/" .. #chunks,
        TextColor3 = Theme.TextPrimary,
        TextSize = 11,
        Font = Theme.FontFamily,
        LayoutOrder = 2,
        Parent = navContainer
    })
    
    local nextBtn = UIComponents.Button(navContainer, ">", nil, function() end)
    nextBtn.Size = UDim2.new(0, 28, 0, 20)
    nextBtn.LayoutOrder = 3
    
    local textContainer = createInstance("Frame", {
        Size = UDim2.new(1, 0, 1, -32),
        Position = UDim2.new(0, 0, 0, 32),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = container
    })
    
    local scroll = createInstance("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 6,
        ScrollBarImageColor3 = Theme.BorderHover,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.XY,
        ScrollingDirection = Enum.ScrollingDirection.XY,
        ClipsDescendants = true,
        Parent = textContainer
    })
    createPadding(scroll, 8)
    
    local textElement
    if readOnly then
        textElement = createInstance("TextLabel", {
            Size = UDim2.new(0, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.XY,
            BackgroundTransparency = 1,
            Text = chunks[1] or "",
            TextColor3 = Theme.TextPrimary,
            TextSize = 11,
            Font = Theme.FontFamilyMono,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = false,
            Parent = scroll
        })
    else
        textElement = createInstance("TextBox", {
            Size = UDim2.new(0, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.XY,
            BackgroundTransparency = 1,
            Text = chunks[1] or "",
            TextColor3 = Theme.TextPrimary,
            TextSize = 11,
            Font = Theme.FontFamilyMono,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = false,
            MultiLine = true,
            ClearTextOnFocus = false,
            Parent = scroll
        })
        
        textElement.FocusLost:Connect(function()
            chunks[currentChunkIndex] = textElement.Text
            if onChunkChanged then
                onChunkChanged(getFullText())
            end
        end)
    end
    
    local function updateDisplay()
        textElement.Text = chunks[currentChunkIndex] or ""
        chunkLabel.Text = currentChunkIndex .. "/" .. #chunks
        infoLabel.Text = string.format("Chunk %d/%d | Total: %d chars | This: %d chars", 
            currentChunkIndex, #chunks, #getFullText(), #(chunks[currentChunkIndex] or ""))
        scroll.CanvasPosition = Vector2.new(0, 0)
    end
    
    prevBtn.MouseButton1Click:Connect(function()
        if not readOnly then
            chunks[currentChunkIndex] = textElement.Text
        end
        if currentChunkIndex > 1 then
            currentChunkIndex = currentChunkIndex - 1
            updateDisplay()
        end
    end)
    
    nextBtn.MouseButton1Click:Connect(function()
        if not readOnly then
            chunks[currentChunkIndex] = textElement.Text
        end
        if currentChunkIndex < #chunks then
            currentChunkIndex = currentChunkIndex + 1
            updateDisplay()
        end
    end)
    
    return {
        Container = container,
        
        GetFullText = function()
            if not readOnly then
                chunks[currentChunkIndex] = textElement.Text
            end
            return getFullText()
        end,
        
        SetText = function(text)
            fullText = text or ""
            splitIntoChunks(fullText)
            currentChunkIndex = 1
            updateDisplay()
        end,
        
        GetChunkCount = function()
            return #chunks
        end,
    }
end

function UIComponents.TextArea(parent, initialText, placeholder)
    local container = createInstance("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.Background,
        ClipsDescendants = true,
        Parent = parent
    })
    createCorner(container, Theme.CornerRadiusSmall)
    
    local scroll = createInstance("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.BorderHover,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ClipsDescendants = true,
        Parent = container
    })
    createPadding(scroll, 8)
    
    local inputBox = createInstance("TextBox", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = initialText or "",
        PlaceholderText = placeholder or "",
        TextColor3 = Theme.TextPrimary,
        TextSize = 11,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        MultiLine = true,
        ClearTextOnFocus = false,
        Parent = scroll
    })
    
    return container, inputBox
end

function UIComponents.CodeBlock(parent, code, language)
    local container = createInstance("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.Background,
        ClipsDescendants = true,
        Parent = parent
    })
    createCorner(container, Theme.CornerRadiusSmall)
    
    
    local header = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = Theme.BackgroundSecondary,
        Parent = container
    })
    createCorner(header, Theme.CornerRadiusSmall)
    
    createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 8),
        Position = UDim2.new(0, 0, 1, -8),
        BackgroundColor3 = Theme.BackgroundSecondary,
        BorderSizePixel = 0,
        Parent = header
    })
    
    createInstance("TextLabel", {
        Size = UDim2.new(0.5, 0, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = language or "lua",
        TextColor3 = Theme.TextMuted,
        TextSize = 10,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header
    })
    
    local copyBtn = UIComponents.Button(header, "Copy", "ghost", function()
        copyToClipboard(code)
    end)
    copyBtn.Size = UDim2.new(0, 50, 0, 20)
    copyBtn.Position = UDim2.new(1, -55, 0.5, -10)
    
    
    local scroll = createInstance("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, -26),
        Position = UDim2.new(0, 0, 0, 26),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.BorderHover,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.XY,
        ClipsDescendants = true,
        Parent = container
    })
    createPadding(scroll, 10)
    
    local codeLabel = createInstance("TextLabel", {
        Size = UDim2.new(0, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundTransparency = 1,
        Text = code,
        TextColor3 = Theme.TextPrimary,
        TextSize = 11,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        RichText = true,
        Parent = scroll
    })
    
    return container, codeLabel
end

function UIComponents.PropertyRow(parent, label, value, order)
    local row = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        LayoutOrder = order or 0,
        Parent = parent
    })
    
    createInstance("TextLabel", {
        Size = UDim2.new(0, 110, 1, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row
    })
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, -115, 1, 0),
        Position = UDim2.new(0, 115, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(value),
        TextColor3 = Theme.TextPrimary,
        TextSize = 11,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row
    })
    
    return row
end

function UIComponents.Notification(parent, message, type, duration)
    type = type or "info"
    duration = duration or 3
    
    local colors = {
        info = Theme.Primary,
        success = Theme.Success,
        warning = Theme.Warning,
        error = Theme.Danger,
    }
    
    local color = colors[type] or Theme.Primary
    local msg = tostring(message or "")
    local textHeight = 16
    if TextService then
        local ok, bounds = pcall(function()
            return TextService:GetTextSize(msg, 12, Theme.FontFamily, Vector2.new(260, 1000))
        end)
        if ok and bounds then
            textHeight = math.max(16, math.ceil(bounds.Y))
        end
    else
        textHeight = math.max(16, math.ceil(#msg / 36) * 16)
    end
    local notifHeight = textHeight + 20

    local notif = createSquircle(Theme.Radius.Medium, "Squircle", {
        Size = UDim2.new(0, 280, 0, notifHeight),
        Position = UDim2.new(1, -300, 1, 0),
        ImageColor3 = Theme.BackgroundSecondary,
        ZIndex = 500,
        Parent = parent,
    }, false)
    createSquircle(Theme.Radius.Medium, "SquircleOutline", {
        Size = UDim2.new(1, 0, 1, 0),
        ImageColor3 = color,
        ZIndex = 0,
        Parent = notif,
    }, false)
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, -20, 1, -12),
        Position = UDim2.new(0, 10, 0, 6),
        BackgroundTransparency = 1,
        Text = msg,
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Theme.FontFamily,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 501,
        Parent = notif
    })
    
    
    tween(notif, {Position = UDim2.new(1, -300, 1, -(notifHeight + 16))}, 0.3)
    
    
    task.delay(duration, function()
        if not notif.Parent then
            return
        end
        tween(notif, {Position = UDim2.new(1, 0, 1, -(notifHeight + 16))}, 0.3)
        task.delay(0.3, function()
            if notif.Parent then
                notif:Destroy()
            end
        end)
    end)
    
    return notif
end

function UIComponents.ClickableUrl(parent, url, layoutOrder)
    local urlBtn = createInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = url,
        TextColor3 = Theme.Primary,
        TextSize = 10,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        LayoutOrder = layoutOrder or 0,
        Parent = parent
    })
    
    
    urlBtn.MouseEnter:Connect(function()
        urlBtn.TextColor3 = Theme.Cyan
    end)
    
    urlBtn.MouseLeave:Connect(function()
        urlBtn.TextColor3 = Theme.Primary
    end)
    
    
    urlBtn.MouseButton1Click:Connect(function()
        copyToClipboard(url)
        UIComponents.Notification(parent:FindFirstAncestorOfClass("ScreenGui"), "URL copied to clipboard", "success")
    end)
    
    return urlBtn
end

local SETTINGS_FILE_PATH = "ProBaconHub/RemoteSpySettings.json"

local LOG_CAP_MIN = 0
local LOG_CAP_MAX = 2000
local LOG_CAP_DEFAULT = 200
local LOG_CAP_INFINITE = LOG_CAP_MAX

local function decodeLogCapLimit(sliderValue)
    local v = math.floor(tonumber(sliderValue) or LOG_CAP_DEFAULT)
    if v >= LOG_CAP_INFINITE then
        return nil
    end
    return math.clamp(v, LOG_CAP_MIN, LOG_CAP_INFINITE - 1)
end

local function encodeLogCapLimit(limit)
    if limit == nil then
        return LOG_CAP_INFINITE
    end
    return limit
end

local function formatLogCapLimit(sliderValue)
    if sliderValue >= LOG_CAP_INFINITE then
        return "Infinite"
    end
    return tostring(math.floor(sliderValue))
end

local function applyLogCapLimit(limit)
    HttpInterceptor.MaxLogs = limit
    RemoteScanner.MaxLogsPerRemote = limit
end

local function getLogCapSliderValue()
    return encodeLogCapLimit(HttpInterceptor.MaxLogs)
end

local RemoteSpyUI = {
    ScreenGui = nil,
    MainFrame = nil,
    UIScaleInstance = nil,
    IsMinimized = false,
    IsMaximized = false,
    CurrentTab = "Remotes",
    SearchFilter = "",
    PendingUpdateDelay = 0,
    RemoteAutoStartSpy = true,
    HttpAutoStartSpy = false,
    TextScale = 1.0,  
    UIScale = 1.0,    
    BaseTextSize = 10,  
    _httpEntriesById = {},
    _argEntryMap = {},
    _lastArgsPanelSig = nil,
    _detailsLogId = nil,
    _trackedConnections = {},
    _destroying = false,
    _httpPendingPollGen = 0,
    TypeFilters = {
        RemoteEvent = true,
        RemoteFunction = true,
        UnreliableRemoteEvent = true,
        BindableEvent = true,
        BindableFunction = true,
    },
    DirectionFilters = {
        Outgoing = true,
        Incoming = true,
    },
    ExpandedGroups = {},
    ExpandedArgGroups = {},  
    SelectedLog = nil,
    SelectedRemotePath = nil,  
    SelectedRemoteGroup = nil, 
    SelectedArgKey = nil,      
    SelectedArgGroup = nil,    
    
    
    DefaultSize = UDim2.new(0, 960, 0, 580),
    SidebarWidth = 44,
    RemoteDirectionFilters = {}, 

    
    WindowSize = nil,      
    WindowPosition = nil,  
}

function RemoteSpyUI:_encodeBlockedArgsMap(map)
    local entries = {}
    for path, hashes in pairs(map or {}) do
        for argHash, enabled in pairs(hashes) do
            if enabled then
                table.insert(entries, {Path = path, Hash = argHash})
            end
        end
    end
    return entries
end

function RemoteSpyUI:_decodeBlockedArgsMap(entries)
    local map = {}
    if type(entries) ~= "table" then
        return map
    end
    for _, entry in ipairs(entries) do
        if type(entry) == "table" and entry.Path and entry.Hash then
            if not map[entry.Path] then
                map[entry.Path] = {}
            end
            map[entry.Path][entry.Hash] = true
        end
    end
    return map
end

function RemoteSpyUI:_encodeStringMap(map)
    local entries = {}
    for key, enabled in pairs(map or {}) do
        if enabled then
            table.insert(entries, key)
        end
    end
    table.sort(entries)
    return entries
end

function RemoteSpyUI:_decodeStringMap(entries)
    local map = {}
    if type(entries) ~= "table" then
        return map
    end
    for _, key in ipairs(entries) do
        if type(key) == "string" and key ~= "" then
            map[key] = true
        end
    end
    return map
end

function RemoteSpyUI:SaveSettings()
    if self._destroying then
        return
    end
    local settings = {
        UIScale = self.UIScale,
        TextScale = self.TextScale,
        PendingUpdateDelay = self.PendingUpdateDelay,
        MaxLogsPerArgGroup = RemoteScanner.MaxLogsPerArgGroup,
        ReturnBypassEnabled = RemoteScanner.ReturnBypassEnabled,
        RemoteAutoStartSpy = self.RemoteAutoStartSpy,
        HttpAutoStartSpy = self.HttpAutoStartSpy,
        HttpInterceptEnabled = HttpInterceptor.InterceptEnabled,
        TypeFilters = self.TypeFilters,
        DirectionFilters = self.DirectionFilters,
        RemoteDirectionFilters = self.RemoteDirectionFilters,
        BlockedInstances = self:_encodeStringMap(RemoteScanner.BlockedInstances),
        IgnoredInstances = self:_encodeStringMap(RemoteScanner.IgnoredInstances),
        BlockedArgs = self:_encodeBlockedArgsMap(RemoteScanner.BlockedArgs),
        IgnoredArgs = self:_encodeBlockedArgsMap(RemoteScanner.IgnoredArgs),
        BlockedUrls = self:_encodeStringMap(HttpInterceptor.BlockedUrls),
        WindowSize = self.WindowSize,
        WindowPosition = self.WindowPosition,
        MaxLogCap = getLogCapSliderValue(),
    }
    
    local success, encoded = pcall(function()
        return HttpService:JSONEncode(settings)
    end)
    
    if success and encoded and writefile then
        pcall(function()
            
            local dir = SETTINGS_FILE_PATH:match("(.+)/[^/]+$")
            if dir and makefolder and not isfolder(dir) then
                makefolder(dir)
            end
            writefile(SETTINGS_FILE_PATH, encoded)
        end)
    end
end

function RemoteSpyUI:LoadSettings()
    if not readfile or not isfile then return end
    
    local success, content = pcall(function()
        if isfile(SETTINGS_FILE_PATH) then
            return readfile(SETTINGS_FILE_PATH)
        end
        return nil
    end)
    
    if not success or not content then return end
    
    local decodeSuccess, settings = pcall(function()
        return HttpService:JSONDecode(content)
    end)
    
    if not decodeSuccess or type(settings) ~= "table" then return end
    
    
    if settings.UIScale then
        self.UIScale = math.clamp(tonumber(settings.UIScale) or 1.0, 0.5, 2.0)
    end
    if settings.TextScale then
        self.TextScale = math.clamp(tonumber(settings.TextScale) or 1.0, 0.5, 1.5)
    end
    if settings.PendingUpdateDelay then
        self.PendingUpdateDelay = math.clamp(tonumber(settings.PendingUpdateDelay) or 0, 0, 1)
    end
    if settings.MaxLogsPerArgGroup then
        RemoteScanner.MaxLogsPerArgGroup = math.clamp(math.floor(tonumber(settings.MaxLogsPerArgGroup) or 50), 1, 9999)
    end
    if settings.ReturnBypassEnabled ~= nil then
        RemoteScanner.ReturnBypassEnabled = settings.ReturnBypassEnabled == true
    end
    if settings.RemoteAutoStartSpy ~= nil then
        self.RemoteAutoStartSpy = settings.RemoteAutoStartSpy == true
    end
    if settings.HttpAutoStartSpy ~= nil then
        self.HttpAutoStartSpy = settings.HttpAutoStartSpy == true
    end
    if settings.HttpInterceptEnabled ~= nil then
        HttpInterceptor.InterceptEnabled = settings.HttpInterceptEnabled == true
    end
    if type(settings.TypeFilters) == "table" then
        for k, v in pairs(settings.TypeFilters) do
            if self.TypeFilters[k] ~= nil then
                self.TypeFilters[k] = v == true
            end
        end
    end
    if type(settings.DirectionFilters) == "table" then
        for k, v in pairs(settings.DirectionFilters) do
            if self.DirectionFilters[k] ~= nil then
                self.DirectionFilters[k] = v == true
            end
        end
    end
    if type(settings.RemoteDirectionFilters) == "table" then
        self.RemoteDirectionFilters = {}
        for path, filters in pairs(settings.RemoteDirectionFilters) do
            if type(path) == "string" and type(filters) == "table" then
                local mode = filters.Mode
                if type(mode) ~= "string" then
                    local out = filters.Outgoing ~= false
                    local incoming = filters.Incoming ~= false
                    if out and incoming then
                        mode = "All"
                    elseif out then
                        mode = "Outgoing"
                    elseif incoming then
                        mode = "Incoming"
                    else
                        mode = "All"
                    end
                end
                self.RemoteDirectionFilters[path] = {
                    Mode = mode,
                    Outgoing = mode == "All" or mode == "Outgoing",
                    Incoming = mode == "All" or mode == "Incoming",
                }
            end
        end
    end
    if settings.BlockedInstances ~= nil then
        RemoteScanner.BlockedInstances = self:_decodeStringMap(settings.BlockedInstances)
    end
    if settings.IgnoredInstances ~= nil then
        RemoteScanner.IgnoredInstances = self:_decodeStringMap(settings.IgnoredInstances)
    end
    if settings.BlockedArgs ~= nil then
        RemoteScanner.BlockedArgs = self:_decodeBlockedArgsMap(settings.BlockedArgs)
    end
    if settings.IgnoredArgs ~= nil then
        RemoteScanner.IgnoredArgs = self:_decodeBlockedArgsMap(settings.IgnoredArgs)
    end
    if settings.BlockedUrls ~= nil then
        HttpInterceptor.BlockedUrls = self:_decodeStringMap(settings.BlockedUrls)
    end
    if settings.MaxLogCap ~= nil then
        applyLogCapLimit(decodeLogCapLimit(settings.MaxLogCap))
    end
    if type(settings.WindowSize) == "table"
        and tonumber(settings.WindowSize.X) and tonumber(settings.WindowSize.Y) then
        local w, h = self:ClampWindowSize(settings.WindowSize.X, settings.WindowSize.Y)
        self.WindowSize = { X = w, Y = h }
    end
    
    self.WindowPosition = nil
    
    self:SyncScannerFilters()
end

local WINDOW_MIN_WIDTH = 600
local WINDOW_MIN_HEIGHT = 350

function RemoteSpyUI:GetDisplaySize()
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize
    if typeof(viewport) == "Vector2" and viewport.X > 0 and viewport.Y > 0 then
        return viewport
    end
    return Vector2.new(1280, 720)
end

function RemoteSpyUI:GetMaxWindowSize()
    local display = self:GetDisplaySize()
    local scale = self.UIScale or 1
    if scale < 0.01 then
        scale = 1
    end
    return math.max(1, math.floor(display.X / scale)), math.max(1, math.floor(display.Y / scale))
end

function RemoteSpyUI:ClampWindowSize(width, height)
    local maxW, maxH = self:GetMaxWindowSize()
    local minW = math.min(WINDOW_MIN_WIDTH, maxW)
    local minH = math.min(WINDOW_MIN_HEIGHT, maxH)
    width = math.clamp(math.floor(tonumber(width) or minW), minW, maxW)
    height = math.clamp(math.floor(tonumber(height) or minH), minH, maxH)
    return width, height
end

function RemoteSpyUI:SaveWindowGeometry()
    if not self.MainFrame then return end
    
    local size = self.IsMinimized and self.OriginalSize or self.MainFrame.Size
    if size then
        local w, h = self:ClampWindowSize(size.X.Offset, size.Y.Offset)
        self.WindowSize = { X = w, Y = h }
    end
    
    local pos = self.MainFrame.Position
    self.WindowPosition = {
        XScale = pos.X.Scale,
        XOffset = math.floor(pos.X.Offset),
        YScale = pos.Y.Scale,
        YOffset = math.floor(pos.Y.Offset),
    }

    self._geometrySaveToken = (self._geometrySaveToken or 0) + 1
    local token = self._geometrySaveToken
    task.delay(0.5, function()
        if self._geometrySaveToken == token then
            self:SaveSettings()
        end
    end)
end

function RemoteSpyUI:SyncScannerFilters()
    for name, enabled in pairs(self.TypeFilters) do
        if RemoteScanner.EnabledFilters[name] ~= nil then
            RemoteScanner.EnabledFilters[name] = enabled
        end
    end
    
    RemoteScanner.DirectionFilters.Outgoing = true
    RemoteScanner.DirectionFilters.Incoming = true
    for _, group in pairs(RemoteScanner.GroupedLogs) do
        group._argGroupsDirty = true
        group._sortedArgGroupsCache = nil
    end
end

function RemoteSpyUI:_getRemoteDirectionMode(path)
    self.RemoteDirectionFilters = self.RemoteDirectionFilters or {}
    local filters = self.RemoteDirectionFilters[path]
    if type(filters) ~= "table" then
        filters = { Mode = "All" }
        self.RemoteDirectionFilters[path] = filters
    end
    if type(filters.Mode) ~= "string" then
        
        local out = filters.Outgoing ~= false
        local incoming = filters.Incoming ~= false
        if out and incoming then
            filters.Mode = "All"
        elseif out then
            filters.Mode = "Outgoing"
        elseif incoming then
            filters.Mode = "Incoming"
        else
            filters.Mode = "All"
        end
    end
    if filters.Mode ~= "All" and filters.Mode ~= "Outgoing" and filters.Mode ~= "Incoming" then
        filters.Mode = "All"
    end
    return filters.Mode
end

function RemoteSpyUI:_setRemoteDirectionMode(path, mode)
    self.RemoteDirectionFilters = self.RemoteDirectionFilters or {}
    local filters = self.RemoteDirectionFilters[path]
    if type(filters) ~= "table" then
        filters = {}
        self.RemoteDirectionFilters[path] = filters
    end
    filters.Mode = mode
    filters.Outgoing = mode == "All" or mode == "Outgoing"
    filters.Incoming = mode == "All" or mode == "Incoming"
end

function RemoteSpyUI:_syncRemoteDirectionChipVisuals(path)
    local mode = self:_getRemoteDirectionMode(path)
    local tabs = self._directionTabs
    if not tabs then
        return
    end
    for name, btn in pairs(tabs) do
        local active = name == mode
        if isSquircle(btn) then
            btn.ImageColor3 = active and Theme.Primary or Theme.BackgroundTertiary
            btn.ImageTransparency = active and 0.15 or 0.55
        end
        local label = btn:FindFirstChild("Label")
        if label then
            label.TextColor3 = active and Theme.TextPrimary or Theme.TextMuted
        end
    end
end

function RemoteSpyUI:ApplyFilterChanges()
    self:SyncScannerFilters()
    self:RefreshRemoteList()
    if self.SelectedRemotePath then
        local group = RemoteScanner.GroupedLogs[self.SelectedRemotePath]
        self:PopulateArgsPanel(group)
    end
end

function RemoteSpyUI:_trackConnection(conn)
    if conn and self._trackedConnections then
        table.insert(self._trackedConnections, conn)
    end
    return conn
end

function RemoteSpyUI:_disconnectTrackedConnections()
    if not self._trackedConnections then
        return
    end
    for _, conn in ipairs(self._trackedConnections) do
        pcall(function()
            conn:Disconnect()
        end)
    end
    self._trackedConnections = {}
end

function RemoteSpyUI:_destroyFloatedDropdowns()
    local screenGui = self.ScreenGui
    if not screenGui then
        return
    end
    for _, child in ipairs(screenGui:GetChildren()) do
        if child.Name == "DropdownMenu" then
            pcall(function()
                child:Destroy()
            end)
        end
    end
end

function RemoteSpyUI:_clearModuleCallbacks()
    RemoteScanner.OnLogAdded = nil
    RemoteScanner.OnGroupUpdated = nil
    RemoteScanner.OnFiltersChanged = nil
    HttpInterceptor.OnLogAdded = nil
    HttpInterceptor.OnRequestPending = nil
    HttpInterceptor.OnResponseReady = nil
    HttpInterceptor.OnBlockStateChanged = nil
    ModuleExplorer.OnModulesRefreshed = nil
end

function RemoteSpyUI:Create()
    
    self:LoadSettings()
    
    local uiParent = getUIParent()
    if not uiParent then
        warn("[SpyTool] Could not find a UI parent (gethui/CoreGui/PlayerGui). Spy UI was not created.")
        return nil
    end
    
    
    local existing = uiParent:FindFirstChild("RemoteSpyUI")
    if existing then
        pcall(function()
            local tool = getSpyGenv()[SPYTOOL_GENV_KEY]
            if tool and type(tool.Destroy) == "function" then
                tool:Destroy({ defer = false, force = true })
            else
                RemoteScanner:StopSpying()
                HttpInterceptor:Stop()
                HttpInterceptor:UninstallHooks()
                existing:Destroy()
            end
        end)
        spyCleanupFrame()
    end

    self._destroying = false
    self._trackedConnections = {}
    self._httpPendingPollGen = (self._httpPendingPollGen or 0) + 1
    HttpInterceptor._shuttingDown = false
    HttpInterceptor._pendingReleased = false
    
    
    self.ScreenGui = createInstance("ScreenGui", {
        Name = "RemoteSpyUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 999999,  
        IgnoreGuiInset = false,
        Parent = uiParent
    })
    
    
    local startW = self.DefaultSize.X.Offset
    local startH = self.DefaultSize.Y.Offset
    if self.WindowSize then
        startW = self.WindowSize.X
        startH = self.WindowSize.Y
    end
    
    startW, startH = self:ClampWindowSize(startW, startH)
    self.WindowSize = { X = startW, Y = startH }
    local initialSize = UDim2.new(0, startW, 0, startH)
    
    local initialPosition = UDim2.new(
        0.5, -math.floor(startW * 0.5),
        0.5, -math.floor(startH * 0.5)
    )
    self.MainFrame = createSquircle(Theme.Radius.Window, "Window", {
        Name = "MainFrame",
        Size = initialSize,
        Position = initialPosition,
        ImageColor3 = Theme.Background,
        Parent = self.ScreenGui,
    }, true)
    
    
    self.UIScaleInstance = createInstance("UIScale", {
        Scale = self.UIScale,
        Parent = self.MainFrame
    })

    createSquircle(Theme.Radius.Window, "WindowOutline", {
        Name = "WindowOutline",
        Size = UDim2.new(1, 0, 1, 0),
        ImageColor3 = Theme.Border,
        ZIndex = 2,
        Parent = self.MainFrame,
    }, false)
    
    self:CreateTitleBar()
    self:CreateSidebar()
    self:CreateMainContent()
    self:MakeDraggable()
    self:MakeResizable()
    
    
    RemoteScanner.OnGroupUpdated = function(path, group)
        self:UpdateRemoteGroup(path, group)
    end

    RemoteScanner.OnLogAdded = function(log)
        self:QueueRemoteRefresh()
    end
    
    HttpInterceptor.OnLogAdded = function()
        self:QueueHttpRefresh()
    end
    
    HttpInterceptor.OnRequestPending = function()
        self:QueueHttpRefresh()
    end
    
    HttpInterceptor.OnResponseReady = function()
        self:QueueHttpRefresh()
    end
    
    RemoteScanner.OnFiltersChanged = function()
        self:SaveSettings()
    end
    
    HttpInterceptor.OnBlockStateChanged = function()
        self:SaveSettings()
    end
    
    
    HttpInterceptor:InstallHooks()

    self:EnsureRefreshConnections()
    self:_beginStartupScan()
    
    return self.ScreenGui
end

function RemoteSpyUI:_beginStartupScan()
    local overlay = createSquircle(Theme.Radius.Window, "Window", {
        Name = "StartupLoader",
        Size = UDim2.new(1, 0, 1, 0),
        ImageColor3 = Theme.Background,
        ImageTransparency = 0.08,
        ZIndex = 500,
        Parent = self.MainFrame,
    }, false)
    pcall(function()
        overlay.Active = true
    end)

    local card = createPanel(Theme.Radius.Medium, {
        Name = "LoaderCard",
        Size = UDim2.new(0, 260, 0, 96),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ImageColor3 = Theme.BackgroundSecondary,
        ZIndex = 501,
        Parent = overlay,
    }, true)

    local status = createInstance("TextLabel", {
        Name = "Status",
        Size = UDim2.new(1, -24, 0, 20),
        Position = UDim2.new(0, 12, 0, 18),
        BackgroundTransparency = 1,
        Text = "Scanning remotes...",
        TextColor3 = Theme.TextPrimary,
        TextSize = 13,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 502,
        Parent = card,
    })

    local detail = createInstance("TextLabel", {
        Name = "Detail",
        Size = UDim2.new(1, -24, 0, 16),
        Position = UDim2.new(0, 12, 0, 42),
        BackgroundTransparency = 1,
        Text = "Preparing Spy Tool",
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 502,
        Parent = card,
    })

    local barBg = createInstance("Frame", {
        Size = UDim2.new(1, -24, 0, 6),
        Position = UDim2.new(0, 12, 1, -20),
        BackgroundColor3 = Theme.BackgroundTertiary,
        ZIndex = 502,
        Parent = card,
    })
    createCorner(barBg, Theme.CornerRadiusFull)
    local barFill = createInstance("Frame", {
        Size = UDim2.new(0.08, 0, 1, 0),
        BackgroundColor3 = Theme.Primary,
        ZIndex = 503,
        Parent = barBg,
    })
    createCorner(barFill, Theme.CornerRadiusFull)

    local function setProgress(alpha, statusText, detailText)
        if statusText then
            status.Text = statusText
        end
        if detailText then
            detail.Text = detailText
        end
        tween(barFill, {Size = UDim2.new(math.clamp(alpha, 0, 1), 0, 1, 0)}, 0.2)
    end

    local finished = false
    local function finishLoader()
        if finished or self._destroying then
            return
        end
        finished = true
        if self.RemoteAutoStartSpy then
            pcall(function()
                RemoteScanner:StartSpying()
            end)
            self:_syncRemoteSpyButton()
        end
        if self.HttpAutoStartSpy then
            HttpInterceptor:Start()
            self:_syncHttpSpyButton()
        else
            self:_syncHttpSpyButton()
        end
        self:UpdateStatusLabel()

        tween(overlay, {ImageTransparency = 1}, 0.25)
        tween(card, {ImageTransparency = 1}, 0.25)
        task.delay(0.28, function()
            if overlay and overlay.Parent then
                overlay:Destroy()
            end
        end)
    end

    task.spawn(function()
        setProgress(0.15, "Scanning remotes...", "Finding RemoteEvent / RemoteFunction instances")
        local okScan, errScan = pcall(function()
            RemoteScanner:Scan()
        end)
        if not okScan then
            warn("[SpyTool] Remote scan failed:", errScan)
        end
        local remoteCount = 0
        if type(RemoteScanner.FoundRemotes) == "table" then
            for _ in pairs(RemoteScanner.FoundRemotes) do
                remoteCount += 1
            end
        end
        self:RefreshRemoteList(true)
        setProgress(0.45, "Scanning remotes...", string.format("Found %d remotes", remoteCount))

        if self._destroying then
            return
        end

        setProgress(0.55, "Scanning modules...", "Walking ModuleScripts")
        self.ModulesScanned = true
        self._moduleScanDisplayOrder = 0
        if self.ModuleListFrame then
            self:_clearModuleListFrame()
            self:_showModuleScanPlaceholder("Scanning...")
        end
        if self.RequireModuleCountLabel then
            self.RequireModuleCountLabel.Text = "Scanning..."
        end

        local scanDone = false
        ModuleExplorer:ScanAllModulesAsync(function(foundCount)
            if self._destroying then
                return
            end
            local pct = 0.55 + math.min(0.35, (foundCount / 200) * 0.35)
            setProgress(pct, "Scanning modules...", string.format("%d modules found", foundCount))
            if self.RequireModuleCountLabel then
                self.RequireModuleCountLabel.Text = string.format("Scanning... %d found", foundCount)
            end
            local placeholder = self.ModuleListFrame and self.ModuleListFrame:FindFirstChild("ModuleScanPlaceholder")
            if placeholder then
                placeholder.Text = string.format("Scanning... %d modules found", foundCount)
            end
        end, function(total)
            if self._destroying then
                return
            end
            scanDone = true
            if self._moduleScanUIGen ~= ModuleExplorer._scanId then
                
            end
            self:_removeModuleScanPlaceholder()
            if self.ModuleTreeView then
                self:RefreshModuleTreeList(true)
            else
                self:_resortModuleListAfterScan()
            end
            if total == 0 and self.ModuleListFrame then
                self:_showModuleScanPlaceholder("No modules found")
            end
            if self.RequireModuleCountLabel then
                self.RequireModuleCountLabel.Text = total .. " modules"
            end
            setProgress(1, "Ready", string.format("%d remotes · %d modules", remoteCount, total))
            task.wait(0.15)
            finishLoader()
        end, function(batch)
            if self._destroying then
                return
            end
            if self.ModuleTreeView then
                self:_applyModuleTreeRowsIncremental()
            else
                self:_appendModulesDuringScan(batch)
            end
        end)
        self._moduleScanUIGen = ModuleExplorer._scanId

        
        task.delay(45, function()
            if not scanDone and overlay and overlay.Parent and not self._destroying then
                setProgress(1, "Ready", "Scan timed out — you can rescan from each tab")
                finishLoader()
            end
        end)
    end)
end

function RemoteSpyUI:EnsureRefreshConnections()
    if not self._remoteRefreshConn then
        self._remoteRefreshConn = RunService.Heartbeat:Connect(function()
            if self._destroying or not (self.ScreenGui and self.ScreenGui.Parent) then
                self._remoteRefreshConn:Disconnect()
                self._remoteRefreshConn = nil
                return
            end
            local logCount = RemoteScanner.TotalLogCount or 0
            if self._lastRemoteLogCount ~= logCount then
                self._lastRemoteLogCount = logCount
                self._remoteDirty = true
            end
            if not self._remoteDirty then
                return
            end
            if self.CurrentTab ~= "Remotes" then
                return
            end
            local delayTime = self.PendingUpdateDelay or 0
            local waitTime = delayTime <= 0 and 0.05 or delayTime
            if self._detailsLogId then
                waitTime = math.max(waitTime, 0.12)
            end
            local now = tick()
            self._remoteNextRefresh = self._remoteNextRefresh or 0
            if now < self._remoteNextRefresh then
                return
            end
            self._remoteDirty = false
            self._remoteNextRefresh = now + waitTime
            local ok = pcall(function()
                self:RefreshRemoteList()
                local selectedGroup = nil
                if self.SelectedRemotePath then
                    selectedGroup = RemoteScanner.GroupedLogs[self.SelectedRemotePath]
                end
                self.SelectedRemoteGroup = selectedGroup
            end)
            if not ok then
                self._remoteDirty = true
            end
        end)
    end

    if not self._httpRefreshConn then
        self._httpRefreshConn = RunService.Heartbeat:Connect(function()
            if self._destroying or not (self.ScreenGui and self.ScreenGui.Parent) then
                self._httpRefreshConn:Disconnect()
                self._httpRefreshConn = nil
                return
            end
            if not self._httpDirty then
                return
            end
            if self.CurrentTab ~= "HTTP" then
                return
            end
            local delayTime = self.PendingUpdateDelay or 0
            local waitTime = delayTime <= 0 and 0.05 or delayTime
            local now = tick()
            self._httpNextRefresh = self._httpNextRefresh or 0
            if now < self._httpNextRefresh then
                return
            end
            self._httpDirty = false
            self._httpNextRefresh = now + waitTime
            local ok = pcall(function()
                self:RefreshHttpList()
            end)
            if not ok then
                self._httpDirty = true
            end
        end)
    end
end

function RemoteSpyUI:CreateTitleBar()
    local titleH = Theme.TitleBarHeight or 44
    
    local titleBar = createSquircle(Theme.Radius.Window, "Window-TL-TR", {
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, titleH),
        ImageColor3 = Theme.BackgroundSecondary,
        ZIndex = 10,
        Parent = self.MainFrame,
    }, true)
    
    local brand = createInstance("Frame", {
        Name = "Brand",
        Size = UDim2.new(0, 130, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = 11,
        Parent = titleBar
    })

    local logoImage = createInstance("ImageLabel", {
        Name = "Logo",
        Size = UDim2.new(0, 15, 0, 15),
        Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Image = "",
        ImageColor3 = Theme.Primary,
        ScaleType = Enum.ScaleType.Fit,
        Visible = false,
        ZIndex = 12,
        Parent = brand
    })
    local logoFallback = createInstance("TextLabel", {
        Name = "LogoFallback",
        Size = UDim2.new(0, 15, 0, 15),
        Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Text = "S",
        TextColor3 = Theme.Primary,
        TextSize = 12,
        Font = Theme.FontFamilyBold,
        ZIndex = 12,
        Parent = brand
    })
    applyAssetIcon(logoImage, "logo.png", logoFallback)

    createInstance("TextLabel", {
        Size = UDim2.new(1, -22, 1, 0),
        Position = UDim2.new(0, 20, 0, 0),
        BackgroundTransparency = 1,
        Text = "Spy Tool",
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 11,
        Parent = brand
    })
    
    self.StatusLabel = createInstance("TextLabel", {
        Size = UDim2.new(0, 120, 1, 0),
        Position = UDim2.new(0.5, -60, 0, 0),
        BackgroundTransparency = 1,
        Text = "Ready",
        TextColor3 = Theme.TextMuted,
        TextSize = 10,
        Font = Theme.FontFamily,
        ZIndex = 11,
        Parent = titleBar
    })
    
    local controls = createInstance("Frame", {
        Size = UDim2.new(0, 56, 1, 0),
        Position = UDim2.new(1, -66, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = 11,
        Parent = titleBar
    })
    createListLayout(controls, 4, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

    -- One control: minimize when open, maximize icon when collapsed (restore).
    self.MinimizeButton = UIComponents.IconButton(controls, "minimize.png", function()
        self:ToggleMinimize()
    end, 22, "Minimize")
    self.MinimizeButton.ZIndex = 12
    self.MinimizeButton.LayoutOrder = 1
    self.MaximizeButton = nil

    local closeBtn = UIComponents.IconButton(controls, "close.png", function()
        local tool = getSpyGenv()[SPYTOOL_GENV_KEY]
        if tool and type(tool.Destroy) == "function" then
            tool:Destroy()
        else
            self:Destroy()
        end
    end, 22, "Close")
    closeBtn.ZIndex = 12
    closeBtn.LayoutOrder = 2

    self.TitleBar = titleBar
    self:_syncMinimizeButtonIcon()
end

function RemoteSpyUI:_syncMinimizeButtonIcon()
    local btn = self.MinimizeButton
    if not btn then
        return
    end
    local collapsed = self.IsMinimized == true
    local fileName = collapsed and "maximize.png" or "minimize.png"
    local tip = collapsed and "Restore" or "Minimize"
    local icon = btn:FindFirstChild("IconImage")
    local glyph = btn:FindFirstChild("Glyph")
    local url = getAssetImage(fileName)
    if icon and url then
        icon.Image = url
        icon.Visible = true
        if glyph then
            glyph.Visible = false
        end
    elseif glyph then
        glyph.Text = collapsed and "□" or "_"
        glyph.Visible = true
        if icon then
            icon.Visible = false
        end
    end
    local tooltip = btn:FindFirstChild("Tooltip")
    local tipText = tooltip and tooltip:FindFirstChild("TooltipText")
    if tipText then
        tipText.Text = "  " .. tip .. "  "
        local tipWidth = measureTextWidth(tipText.Text, 11, Theme.FontFamily) + 12
        tooltip.Size = UDim2.new(0, tipWidth, 0, 24)
    end
end

function RemoteSpyUI:CreateSidebar()
    local sideW = self.SidebarWidth or 44
    local titleH = Theme.TitleBarHeight or 36
    local windowR = Theme.Radius.Window or 16
    
    
    local sidebar = createInstance("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, sideW, 1, -titleH),
        Position = UDim2.new(0, 0, 0, titleH),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 5,
        Parent = self.MainFrame
    })

    createSquircle(windowR, "Window-BL-BR", {
        Name = "SidebarFill",
        Size = UDim2.new(1, windowR + 2, 1, 0),
        ImageColor3 = Theme.BackgroundSecondary,
        ZIndex = 5,
        Parent = sidebar,
    }, false)
    
    local sidebarScroll = createInstance("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        ZIndex = 6,
        Parent = sidebar
    })
    createPadding(sidebarScroll, 6, 6, 6, 6, 6 + windowR)
    createListLayout(sidebarScroll, 4, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Center)
    
    local navItems = {
        {Name = "Remotes", Asset = "remotes.png", Fallback = "R", Tooltip = "Remotes"},
        {Name = "Modules", Asset = "modules.png", Fallback = "M", Tooltip = "Modules"},
        {Name = "HTTP", Asset = "http.png", Fallback = "H", Tooltip = "HTTP"},
        {Name = "Settings", Asset = "settings.png", Fallback = "S", Tooltip = "Settings"},
    }
    
    self.NavButtons = {}
    
    for i, item in ipairs(navItems) do
        local isActive = item.Name == self.CurrentTab
        local iconColor = isActive and Theme.Primary or Theme.TextMuted
        
        local btn = createSquircle(Theme.Radius.Small, "Squircle", {
            Size = UDim2.new(0, 32, 0, 32),
            ImageColor3 = Theme.BackgroundTertiary,
            ImageTransparency = isActive and 0 or 1,
            LayoutOrder = i,
            ZIndex = 6,
            Parent = sidebarScroll,
        }, true)

        local iconImage = createInstance("ImageLabel", {
            Name = "NavIcon",
            Size = UDim2.new(0, 16, 0, 16),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Image = "",
            ImageColor3 = iconColor,
            ScaleType = Enum.ScaleType.Fit,
            Visible = false,
            ZIndex = 7,
            Parent = btn
        })
        iconImage:SetAttribute("NavRole", "icon")

        local iconFallback = createInstance("TextLabel", {
            Name = "NavIconFallback",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = item.Fallback,
            TextColor3 = iconColor,
            TextSize = 12,
            Font = Theme.FontFamilyBold,
            ZIndex = 7,
            Parent = btn
        })
        iconFallback:SetAttribute("NavRole", "icon")
        applyAssetIcon(iconImage, item.Asset, iconFallback)

        local tipText = "  " .. item.Tooltip .. "  "
        local tipWidth = measureTextWidth(tipText, 11, Theme.FontFamily) + 12
        local tooltipLabel = createSquircle(Theme.Radius.Small, "Squircle", {
            Name = "NavTooltip_" .. item.Name,
            Size = UDim2.new(0, tipWidth, 0, 24),
            ImageColor3 = Theme.BackgroundSecondary,
            Visible = false,
            ZIndex = 9999,
            Parent = self.MainFrame,
        }, false)
        createSquircle(Theme.Radius.Small, "SquircleOutline", {
            Size = UDim2.new(1, 0, 1, 0),
            ImageColor3 = Theme.Border,
            ZIndex = 0,
            Parent = tooltipLabel,
        }, false)
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = tipText,
            TextColor3 = Theme.TextPrimary,
            TextSize = 11,
            Font = Theme.FontFamily,
            ZIndex = 1,
            Parent = tooltipLabel,
        })

        local function placeTooltip()
            local absPos = btn.AbsolutePosition
            local absSize = btn.AbsoluteSize
            local mainPos = self.MainFrame.AbsolutePosition
            tooltipLabel.Position = UDim2.new(
                0, (absPos.X - mainPos.X) + absSize.X + 8,
                0, (absPos.Y - mainPos.Y) + math.floor(absSize.Y * 0.5) - 12
            )
        end
        
        self.NavButtons[item.Name] = btn
        
        btn.MouseEnter:Connect(function()
            placeTooltip()
            tooltipLabel.Visible = true
            if self.CurrentTab ~= item.Name then
                tween(btn, {ImageTransparency = 0.45}, 0.15)
            end
        end)
        
        btn.MouseLeave:Connect(function()
            tooltipLabel.Visible = false
            if self.CurrentTab ~= item.Name then
                tween(btn, {ImageTransparency = 1}, 0.15)
            end
        end)
        
        btn.MouseButton1Click:Connect(function()
            self:SwitchTab(item.Name)
        end)
    end
    
    self.Sidebar = sidebar
end

function RemoteSpyUI:CreateMainContent()
    local sideW = self.SidebarWidth or 56
    local titleH = Theme.TitleBarHeight or 44
    local content = createInstance("Frame", {
        Name = "Content",
        Size = UDim2.new(1, -sideW, 1, -titleH),
        Position = UDim2.new(0, sideW, 0, titleH),
        BackgroundTransparency = 1,
        ZIndex = 5,
        Parent = self.MainFrame
    })
    
    self.ContentFrame = content
    
    self:CreateRemotesTab()
    self:CreateRequireTab()
    self:CreateHttpTab()
    self:CreateSettingsTab()
    
    self:SwitchTab("Remotes")
end

function RemoteSpyUI:_syncFilterChipVisual(chip, enabled, activeColor)
    if not chip then
        return
    end
    local label = chip:FindFirstChild("Label")
    local icon = chip:FindFirstChild("TypeIcon")
    if isSquircle(chip) then
        chip.ImageColor3 = enabled and activeColor or Theme.BackgroundTertiary
        chip.ImageTransparency = enabled and 0.2 or 0.55
    else
        setSurfaceColor(chip, enabled and activeColor or Theme.BackgroundTertiary)
        setSurfaceTransparency(chip, enabled and 0.15 or 0.35)
    end
    if label then
        label.TextColor3 = enabled and Theme.TextPrimary or Theme.TextMuted
    elseif chip:IsA("TextButton") then
        chip.TextColor3 = enabled and Theme.TextPrimary or Theme.TextMuted
    end
    if icon then
        icon.ImageTransparency = enabled and 0 or 0.45
    end
end

function RemoteSpyUI:_typeFilterSummaryLabel()
    local enabled = {}
    local order = {
        "RemoteEvent",
        "RemoteFunction",
        "UnreliableRemoteEvent",
        "BindableEvent",
        "BindableFunction",
    }
    local short = {
        RemoteEvent = "RE",
        RemoteFunction = "RF",
        UnreliableRemoteEvent = "URE",
        BindableEvent = "BE",
        BindableFunction = "BF",
    }
    for _, name in ipairs(order) do
        if self.TypeFilters[name] then
            enabled[#enabled + 1] = short[name]
        end
    end
    if #enabled == 0 then
        return "Types: none"
    end
    if #enabled == #order then
        return "Types: all"
    end
    return "Types: " .. table.concat(enabled, ", ")
end

function RemoteSpyUI:_createTypeFilterDropdown(parent)
    local typeDefs = {
        {Name = "RemoteEvent", Label = "RemoteEvent", Color = TypeColors.RemoteEvent, Asset = TypeAssets.RemoteEvent},
        {Name = "RemoteFunction", Label = "RemoteFunction", Color = TypeColors.RemoteFunction, Asset = TypeAssets.RemoteFunction},
        {Name = "UnreliableRemoteEvent", Label = "UnreliableRemoteEvent", Color = TypeColors.UnreliableRemoteEvent, Asset = TypeAssets.UnreliableRemoteEvent},
        {Name = "BindableEvent", Label = "BindableEvent", Color = TypeColors.BindableEvent, Asset = TypeAssets.BindableEvent},
        {Name = "BindableFunction", Label = "BindableFunction", Color = TypeColors.BindableFunction, Asset = TypeAssets.BindableFunction},
    }

    local isOpen = false
    local rowHeight = 28
    local menuHeight = #typeDefs * rowHeight + 8
    local container = createInstance("Frame", {
        Name = "TypeFilterDropdown",
        Size = UDim2.new(0, 110, 0, 24),
        Position = UDim2.new(0, 86, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        ZIndex = 40,
        Parent = parent,
    })

    local button = createSquircle(Theme.Radius.Small, "Squircle", {
        Size = UDim2.new(1, 0, 1, 0),
        ImageColor3 = Theme.BackgroundSecondary,
        ZIndex = 41,
        Parent = container,
    }, true)
    createSquircle(Theme.Radius.Small, "SquircleOutline", {
        Size = UDim2.new(1, 0, 1, 0),
        ImageColor3 = Theme.Border,
        ZIndex = 0,
        Parent = button,
    }, false)

    local summary = createInstance("TextLabel", {
        Name = "Summary",
        Size = UDim2.new(1, -28, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        Text = self:_typeFilterSummaryLabel(),
        TextColor3 = Theme.TextPrimary,
        TextSize = 10,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 42,
        Parent = button,
    })
    local chevron = createAssetGlyph(button, "chevron.png", 10, {
        Name = "Chevron",
        Position = UDim2.new(1, -14, 0.5, 0),
        ImageColor3 = Theme.TextMuted,
        ZIndex = 42,
    })

    local menuContentWidth = 160
    for _, filter in ipairs(typeDefs) do
        menuContentWidth = math.max(
            menuContentWidth,
            measureTextWidth(filter.Label, 11, Theme.FontFamily) + 72
        )
    end

    local optionsFrame = createSquircle(Theme.Radius.Small, "Squircle", {
        Name = "DropdownMenu",
        Size = UDim2.new(0, menuContentWidth, 0, menuHeight),
        Position = UDim2.new(0, 0, 1, 4),
        ImageColor3 = Theme.BackgroundSecondary,
        Visible = false,
        ZIndex = 200,
        Parent = container,
    }, false)
    createSquircle(Theme.Radius.Small, "SquircleOutline", {
        Size = UDim2.new(1, 0, 1, 0),
        ImageColor3 = Theme.Border,
        ZIndex = 0,
        Parent = optionsFrame,
    }, false)
    local optionsContent = createInstance("Frame", {
        Name = "MenuContent",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ZIndex = 201,
        Parent = optionsFrame,
    })
    createPadding(optionsContent, 4)
    createListLayout(optionsContent, 2)

    local function bumpMenuZ(base)
        optionsFrame.ZIndex = base
        optionsContent.ZIndex = base + 1
        for _, child in ipairs(optionsContent:GetChildren()) do
            if child:IsA("GuiObject") then
                child.ZIndex = base + 2
            end
        end
    end

    local function dockMenu()
        optionsFrame.Parent = container
        optionsFrame.Position = UDim2.new(0, 0, 1, 4)
        bumpMenuZ(200)
    end

    local function floatMenu()
        local screenGui = findScreenGui(container)
        if not screenGui then
            dockMenu()
            return
        end
        local absPos = container.AbsolutePosition
        local absSize = container.AbsoluteSize
        optionsFrame.Parent = screenGui
        optionsFrame.Position = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 4)
        bumpMenuZ(300)
    end

    local function setOpen(open)
        isOpen = open
        if isOpen then
            floatMenu()
        else
            dockMenu()
        end
        optionsFrame.Visible = isOpen
        tween(chevron, {Rotation = isOpen and 180 or 0}, 0.2)
    end

    local function layoutDropdownWidths()
        local summaryText = summary.Text
        local textW = measureTextWidth(summaryText, 10, Theme.FontFamily) + 36
        local maxBtn = 220
        if parent.AbsoluteSize.X > 0 then
            
            maxBtn = math.max(96, parent.AbsoluteSize.X - 86 - 64)
        end
        local btnW = math.clamp(textW, 96, maxBtn)
        container.Size = UDim2.new(0, btnW, 0, 24)
        local menuW = math.max(btnW, menuContentWidth)
        optionsFrame.Size = UDim2.new(0, menuW, 0, menuHeight)
    end

    local function refreshSummary()
        summary.Text = self:_typeFilterSummaryLabel()
        layoutDropdownWidths()
    end

    local rowChecks = {}

    for i, filter in ipairs(typeDefs) do
        local row = createInstance("TextButton", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundColor3 = Theme.BackgroundTertiary,
            BackgroundTransparency = 1,
            Text = "",
            LayoutOrder = i,
            ZIndex = 202,
            Parent = optionsContent,
        })
        createCorner(row, Theme.CornerRadiusSmall)
        local rowContent = getG2Content(row)

        local icon = createInstance("ImageLabel", {
            Size = UDim2.new(0, 16, 0, 16),
            Position = UDim2.new(0, 6, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundTransparency = 1,
            Image = "",
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 203,
            Parent = rowContent,
        })
        local iconFallback = createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = filter.Label:sub(1, 2),
            TextColor3 = filter.Color,
            TextSize = 8,
            Font = Theme.FontFamilyBold,
            Visible = false,
            ZIndex = 204,
            Parent = icon,
        })
        applyAssetIcon(icon, filter.Asset, iconFallback)

        local nameLabel = createInstance("TextLabel", {
            Size = UDim2.new(1, -56, 1, 0),
            Position = UDim2.new(0, 28, 0, 0),
            BackgroundTransparency = 1,
            Text = filter.Label,
            TextColor3 = Theme.TextPrimary,
            TextSize = 11,
            Font = Theme.FontFamily,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 203,
            Parent = rowContent,
        })

        local checkHost = createInstance("Frame", {
            Name = "CheckHost",
            Size = UDim2.new(0, 16, 0, 16),
            Position = UDim2.new(1, -22, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundTransparency = 1,
            ZIndex = 203,
            Parent = rowContent,
        })
        
        local _, setCheck = UIComponents.Checkbox(checkHost, self.TypeFilters[filter.Name] == true, nil)
        rowChecks[filter.Name] = setCheck

        local function syncRow()
            local enabled = self.TypeFilters[filter.Name] == true
            setCheck(enabled)
            nameLabel.TextColor3 = enabled and Theme.TextPrimary or Theme.TextMuted
            icon.ImageTransparency = enabled and 0 or 0.45
        end
        syncRow()
        self._filterChips.Type[filter.Name] = row

        row.MouseEnter:Connect(function()
            tween(row, {BackgroundTransparency = 0}, 0.1)
        end)
        row.MouseLeave:Connect(function()
            tween(row, {BackgroundTransparency = 1}, 0.1)
        end)
        row.MouseButton1Click:Connect(function()
            self.TypeFilters[filter.Name] = not self.TypeFilters[filter.Name]
            local anyEnabled = false
            for _, on in pairs(self.TypeFilters) do
                if on then
                    anyEnabled = true
                    break
                end
            end
            if not anyEnabled then
                self.TypeFilters[filter.Name] = true
            end
            syncRow()
            refreshSummary()
            self:ApplyFilterChanges()
            self:SaveSettings()
        end)
    end

    button.MouseButton1Click:Connect(function()
        layoutDropdownWidths()
        setOpen(not isOpen)
    end)

    parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        layoutDropdownWidths()
        if isOpen then
            floatMenu()
        end
    end)

    local outsideClickConn = UserInputService.InputBegan:Connect(function(input)
        if not isOpen or not container.Parent then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local pos = input.Position
        local function inside(frame)
            local absPos = frame.AbsolutePosition
            local absSize = frame.AbsoluteSize
            return pos.X >= absPos.X and pos.X <= absPos.X + absSize.X
                and pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y
        end
        if inside(button) or inside(optionsFrame) then
            return
        end
        setOpen(false)
    end)
    container.Destroying:Connect(function()
        if outsideClickConn then
            outsideClickConn:Disconnect()
        end
        if optionsFrame.Parent and optionsFrame.Parent ~= container then
            optionsFrame:Destroy()
        end
    end)

    self.TypeFilterDropdown = container
    refreshSummary()
    return container
end

function RemoteSpyUI:_createFilterChip(parent, labelText, activeColor, isEnabled, onToggle, layoutOrder, assetFile)
    local useIcon = type(assetFile) == "string" and assetFile ~= ""
    local text = "  " .. tostring(labelText) .. "  "
    local width = useIcon and 28 or math.max(28, measureTextWidth(text, 10, Theme.FontFamilyBold) + 10)
    local chip = createSquircle(Theme.Radius.Chip, "Circle", {
        Size = UDim2.new(0, width, 0, 24),
        ImageColor3 = Theme.BackgroundTertiary,
        LayoutOrder = layoutOrder or 0,
        Parent = parent,
    }, true)
    if useIcon then
        local icon = createInstance("ImageLabel", {
            Name = "TypeIcon",
            Size = UDim2.new(0, 16, 0, 16),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Image = "",
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 2,
            Parent = chip,
        })
        local fallback = createInstance("TextLabel", {
            Name = "Label",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = tostring(labelText),
            TextColor3 = Theme.TextMuted,
            TextSize = 9,
            Font = Theme.FontFamilyBold,
            Visible = false,
            ZIndex = 2,
            Parent = chip,
        })
        applyAssetIcon(icon, assetFile, fallback)
    else
        createInstance("TextLabel", {
            Name = "Label",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = Theme.TextMuted,
            TextSize = 10,
            Font = Theme.FontFamilyBold,
            ZIndex = 2,
            Parent = chip,
        })
    end
    self:_syncFilterChipVisual(chip, isEnabled, activeColor)
    chip.MouseButton1Click:Connect(function()
        onToggle(chip)
    end)
    return chip
end

function RemoteSpyUI:UpdateInspectorChrome()
    local crumb = self.InspectorBreadcrumb
    local hint = self.InspectorHint
    local remotePath = self.SelectedRemotePath
    local group = self.SelectedRemoteGroup
    local argGroup = self.SelectedArgGroup

    if crumb then
        if not remotePath or not group then
            crumb.Text = "Remotes"
        elseif not argGroup then
            crumb.Text = "Remotes  /  " .. (group.Info and group.Info.Name or remotePath)
        else
            local preview = ""
            local cached = argGroup.CachedArgs
            local args = argGroup.Args
            local count = cached and #cached or (args and #args or 0)
            if count == 0 then
                preview = "()"
            else
                local parts = {}
                for i = 1, math.min(count, 3) do
                    parts[#parts + 1] = getArgPreviewFromSnapshot(cached and cached[i], args and args[i])
                end
                if count > 3 then
                    parts[#parts + 1] = "..."
                end
                preview = "(" .. table.concat(parts, ", ") .. ")"
            end
            crumb.Text = "Remotes  /  " .. (group.Info and group.Info.Name or remotePath) .. "  /  " .. preview
        end
    end

    if hint then
        if not remotePath then
            hint.Text = "Select a remote on the left to inspect its traffic."
        elseif not argGroup then
            hint.Text = "Select a call pattern below to inspect the latest matching call."
        else
            hint.Text = "Showing the latest call for this pattern. Right-click rows for more actions."
        end
    end

    if self.ArgsTitle then
        if group and group.Info then
            local sorted = RemoteScanner:GetSortedArgGroups(remotePath)
            self.ArgsTitle.Text = "Call patterns (" .. tostring(#sorted) .. ")"
        else
            self.ArgsTitle.Text = "Call patterns"
        end
    end

    if self.DetailsTitle and not self._detailsLogId then
        if not remotePath then
            self.DetailsTitle.Text = "Inspector"
        elseif not argGroup then
            self.DetailsTitle.Text = "Remote overview"
        end
    end
end

function RemoteSpyUI:ShowInspectorEmptyState(resetSelection)
    if resetSelection then
        self.SelectedRemotePath = nil
        self.SelectedRemoteGroup = nil
        self.SelectedArgKey = nil
        self.SelectedArgGroup = nil
        self._lastArgsPanelSig = nil
        if self.ArgsListFrame then
            for _, child in ipairs(self.ArgsListFrame:GetChildren()) do
                if child:IsA("Frame") or child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("ImageButton") then
                    child:Destroy()
                end
            end
        end
    end
    if self.DetailsFrame then
        for _, child in ipairs(self.DetailsFrame:GetChildren()) do
            if child:IsA("Frame") or child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("ImageButton") then
                child:Destroy()
            end
        end
    end
    self._detailsLogId = nil
    if self.InspectorEmptyState then
        self.InspectorEmptyState.Visible = true
    end
    if self.InspectorSplit then
        self.InspectorSplit.Visible = false
    end
    self:UpdateInspectorChrome()
end

function RemoteSpyUI:ShowInspectorActiveState()
    if self.InspectorEmptyState then
        self.InspectorEmptyState.Visible = false
    end
    if self.InspectorSplit then
        self.InspectorSplit.Visible = true
    end
end

function RemoteSpyUI:CreateRemotesTab()
    local tab = createInstance("Frame", {
        Name = "RemotesTab",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = true,
        Parent = self.ContentFrame,
    })
    createPadding(tab, 12)
    createListLayout(tab, 10)

    
    
    
    local chrome = createPanel(Theme.Radius.Medium, {
        Size = UDim2.new(1, 0, 0, 36),
        ImageColor3 = Theme.BackgroundSecondary,
        LayoutOrder = 1,
        Parent = tab,
    }, true)
    pcall(function()
        chrome.ClipsDescendants = true
    end)

    local chromePad = createInstance("Frame", {
        Size = UDim2.new(1, -16, 1, -8),
        Position = UDim2.new(0, 8, 0, 4),
        BackgroundTransparency = 1,
        ZIndex = 2,
        Parent = chrome,
    })

    local searchWrap = createInstance("Frame", {
        Size = UDim2.new(1, -214, 1, 0),
        BackgroundTransparency = 1,
        Parent = chromePad,
    })
    UIComponents.SearchBar(searchWrap, "Search remotes...", function(text)
        self.SearchFilter = text:lower()
        self:RefreshRemoteList()
    end)

    local sortWrap = createInstance("Frame", {
        Size = UDim2.new(0, 100, 1, 0),
        Position = UDim2.new(1, -206, 0, 0),
        BackgroundTransparency = 1,
        Parent = chromePad,
    })
    local sortDropdown = UIComponents.Dropdown(sortWrap, {"Latest", "Calls"}, "Latest", function(option)
        RemoteScanner.SortMode = option:lower()
        self:RefreshRemoteList()
    end)
    sortDropdown.Size = UDim2.new(1, 0, 1, 0)

    local actions = createInstance("Frame", {
        Size = UDim2.new(0, 96, 1, 0),
        Position = UDim2.new(1, -96, 0, 0),
        BackgroundTransparency = 1,
        Parent = chromePad,
    })
    createListLayout(actions, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

    local rescanBtn = UIComponents.IconButton(actions, "rescan.png", function()
        RemoteScanner:Scan()
        self:RefreshRemoteList(true)
        UIComponents.Notification(self.ScreenGui, "Rescanned all remotes", "success")
    end, 26, "Rescan")
    rescanBtn.LayoutOrder = 1

    local clearBtn = UIComponents.IconButton(actions, "clear.png", function()
        RemoteScanner:ClearLogs()
        self:RefreshRemoteList(true)
        self:ShowInspectorEmptyState(true)
        UIComponents.Notification(self.ScreenGui, "Remote logs cleared", "info")
    end, 26, "Clear")
    clearBtn.LayoutOrder = 2

    self.RemoteSpyButton = UIComponents.IconButton(actions, "play.png", function()
        if RemoteScanner.IsSpying then
            RemoteScanner:StopSpying()
        else
            pcall(function()
                RemoteScanner:StartSpying()
            end)
        end
        self:_syncRemoteSpyButton()
    end, 26, "Start Spy")
    self.RemoteSpyButton.LayoutOrder = 3
    self:_syncRemoteSpyButton()

    
    
    
    local body = createInstance("Frame", {
        Size = UDim2.new(1, 0, 1, -46),
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Parent = tab,
    })

    self._leftPanelWidth = 0.36
    self._argsPanelHeight = 0.40

    local leftPanel = createPanel(Theme.Radius.Medium, {
        Size = UDim2.new(self._leftPanelWidth, -5, 1, 0),
        ImageColor3 = Theme.BackgroundSecondary,
        Parent = body,
    }, true)
    pcall(function()
        leftPanel.ClipsDescendants = true
    end)

    
    local listHeader = createSquircle(Theme.Radius.Medium, "Squircle-TL-TR", {
        Size = UDim2.new(1, 0, 0, 36),
        ImageColor3 = Theme.BackgroundTertiary,
        ZIndex = 2,
        ClipsDescendants = true,
        Parent = leftPanel,
    }, false)

    createInstance("TextLabel", {
        Size = UDim2.new(0, 70, 0, 18),
        Position = UDim2.new(0, 12, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Text = "Remotes",
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
        Parent = listHeader,
    })
    createInstance("TextLabel", {
        Size = UDim2.new(0, 48, 0, 18),
        Position = UDim2.new(1, -56, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Text = "Calls",
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 3,
        Parent = listHeader,
    })

    self._filterChips = {Type = {}, Direction = {}}
    self:_createTypeFilterDropdown(listHeader)

    local remoteScroll = UIComponents.ScrollFrame(leftPanel)
    remoteScroll.Size = UDim2.new(1, 0, 1, -36)
    remoteScroll.Position = UDim2.new(0, 0, 0, 36)
    createPadding(remoteScroll, 6)
    createListLayout(remoteScroll, 3)
    self.RemoteListFrame = remoteScroll
    self.LeftPanel = leftPanel

    local rightPanel
    local verticalResizer = createSplitResizer(
        body,
        "vertical",
        UDim2.new(self._leftPanelWidth, -5, 0, 0),
        4
    )

    local draggingVertical = false
    verticalResizer.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingVertical = true
        end
    end)
    verticalResizer.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingVertical = false
        end
    end)

    self:_trackConnection(UserInputService.InputChanged:Connect(function(input)
        if self._destroying or not body.Parent then
            return
        end
        if draggingVertical and input.UserInputType == Enum.UserInputType.MouseMovement then
            local relX = (input.Position.X - body.AbsolutePosition.X) / body.AbsoluteSize.X
            relX = math.clamp(relX, 0.24, 0.52)
            self._leftPanelWidth = relX
            leftPanel.Size = UDim2.new(relX, -5, 1, 0)
            verticalResizer.Position = UDim2.new(relX, -5, 0, 0)
            rightPanel.Size = UDim2.new(1 - relX, -5, 1, 0)
            rightPanel.Position = UDim2.new(relX, 5, 0, 0)
        end
    end))

    
    
    
    rightPanel = createPanel(Theme.Radius.Medium, {
        Size = UDim2.new(1 - self._leftPanelWidth, -5, 1, 0),
        Position = UDim2.new(self._leftPanelWidth, 5, 0, 0),
        ImageColor3 = Theme.BackgroundSecondary,
        Parent = body,
    }, true)
    self.RightPanel = rightPanel

    pcall(function()
        rightPanel.ClipsDescendants = true
    end)

    local inspectorChrome = createSquircle(Theme.Radius.Medium, "Squircle-TL-TR", {
        Size = UDim2.new(1, 0, 0, 32),
        ImageColor3 = Theme.BackgroundTertiary,
        ZIndex = 2,
        Parent = rightPanel,
    }, false)
    pcall(function()
        inspectorChrome.ClipsDescendants = true
    end)

    self.InspectorBreadcrumb = createInstance("TextLabel", {
        Size = UDim2.new(1, -24, 1, 0),
        Position = UDim2.new(0, 14, 0, 0),
        BackgroundTransparency = 1,
        Text = "Inspector",
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
        Parent = inspectorChrome,
    })
    self.InspectorHint = createInstance("TextLabel", {
        Size = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        Visible = false,
        ZIndex = 3,
        Parent = inspectorChrome,
    })

    local inspectorBody = createInstance("Frame", {
        Size = UDim2.new(1, 0, 1, -32),
        Position = UDim2.new(0, 0, 0, 32),
        BackgroundTransparency = 1,
        ZIndex = 2,
        ClipsDescendants = true,
        Parent = rightPanel,
    })

    
    local emptyState = createInstance("Frame", {
        Name = "EmptyState",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = true,
        ZIndex = 3,
        Parent = inspectorBody,
    })
    local emptyInner = createInstance("Frame", {
        Size = UDim2.new(0, 280, 0, 120),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Parent = emptyState,
    })
    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Text = "Nothing selected",
        TextColor3 = Theme.TextPrimary,
        TextSize = 14,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = emptyInner,
    })
    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 60),
        Position = UDim2.new(0, 0, 0, 28),
        BackgroundTransparency = 1,
        Text = "Pick a remote on the left.\nThen choose a call pattern to inspect,\nfire, block, or copy scripts.",
        TextColor3 = Theme.TextMuted,
        TextSize = 12,
        Font = Theme.FontFamily,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = emptyInner,
    })
    self.InspectorEmptyState = emptyState

    
    local inspectorSplit = createInstance("Frame", {
        Name = "InspectorSplit",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 3,
        Parent = inspectorBody,
    })
    self.InspectorSplit = inspectorSplit

    local argsPanel = createInstance("Frame", {
        Size = UDim2.new(1, 0, self._argsPanelHeight, -4),
        BackgroundTransparency = 1,
        Parent = inspectorSplit,
    })
    self.ArgsTitle = createInstance("TextLabel", {
        Size = UDim2.new(0.45, 0, 0, 20),
        Position = UDim2.new(0, 12, 0, 6),
        BackgroundTransparency = 1,
        Text = "Call patterns",
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = argsPanel,
    })

    local dirTabs = createInstance("Frame", {
        Name = "DirectionTabs",
        Size = UDim2.new(0, 168, 0, 22),
        Position = UDim2.new(1, -220, 0, 5),
        BackgroundTransparency = 1,
        Parent = argsPanel,
    })
    createListLayout(dirTabs, 3, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
    self._directionTabs = {}
    local directionModes = {
        {Name = "All", Label = "All"},
        {Name = "Outgoing", Label = "Outgoing"},
        {Name = "Incoming", Label = "Incoming"},
    }
    for i, mode in ipairs(directionModes) do
        local width = measureTextWidth(mode.Label, 10, Theme.FontFamilyBold) + 14
        local tabBtn = createSquircle(Theme.Radius.Small, "Squircle", {
            Size = UDim2.new(0, width, 0, 22),
            ImageColor3 = Theme.BackgroundTertiary,
            ImageTransparency = 0.55,
            LayoutOrder = i,
            Parent = dirTabs,
        }, true)
        createInstance("TextLabel", {
            Name = "Label",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = mode.Label,
            TextColor3 = Theme.TextMuted,
            TextSize = 10,
            Font = Theme.FontFamilyBold,
            ZIndex = 2,
            Parent = tabBtn,
        })
        tabBtn.MouseButton1Click:Connect(function()
            local path = self.SelectedRemotePath
            if not path then
                return
            end
            self:_setRemoteDirectionMode(path, mode.Name)
            self:_syncRemoteDirectionChipVisuals(path)
            local group = RemoteScanner.GroupedLogs[path]
            if group then
                self._lastArgsPanelSig = nil
                self:IncrementalRefreshArgsPanel(group, true)
            end
            self:SaveSettings()
        end)
        self._directionTabs[mode.Name] = tabBtn
    end

    createInstance("TextLabel", {
        Size = UDim2.new(0, 40, 0, 20),
        Position = UDim2.new(1, -48, 0, 6),
        BackgroundTransparency = 1,
        Text = "Count",
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = argsPanel,
    })

    local argsScroll = UIComponents.ScrollFrame(argsPanel)
    argsScroll.Size = UDim2.new(1, 0, 1, -28)
    argsScroll.Position = UDim2.new(0, 0, 0, 28)
    createPadding(argsScroll, 6)
    createListLayout(argsScroll, 3)
    self.ArgsListFrame = argsScroll
    self.ArgsPanel = argsPanel

    local detailsPanel = createInstance("Frame", {
        Size = UDim2.new(1, 0, 1 - self._argsPanelHeight, -4),
        Position = UDim2.new(0, 0, self._argsPanelHeight, 4),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = inspectorSplit,
    })
    self.RemoteDetailsPanel = detailsPanel

    self.DetailsTitle = createInstance("TextLabel", {
        Size = UDim2.new(1, -24, 0, 20),
        Position = UDim2.new(0, 12, 0, 6),
        BackgroundTransparency = 1,
        Text = "Details",
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = detailsPanel,
    })

    local detailsScroll = UIComponents.ScrollFrame(detailsPanel)
    detailsScroll.Size = UDim2.new(1, 0, 1, -28)
    detailsScroll.Position = UDim2.new(0, 0, 0, 28)
    createPadding(detailsScroll, 10)
    createListLayout(detailsScroll, 8)
    self.DetailsFrame = detailsScroll

    local horizontalResizer = createSplitResizer(
        inspectorSplit,
        "horizontal",
        UDim2.new(0, 0, self._argsPanelHeight, -5),
        5
    )

    local draggingHorizontal = false
    horizontalResizer.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingHorizontal = true
        end
    end)
    horizontalResizer.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingHorizontal = false
        end
    end)

    self:_trackConnection(UserInputService.InputChanged:Connect(function(input)
        if self._destroying or not inspectorSplit.Parent then
            return
        end
        if draggingHorizontal and input.UserInputType == Enum.UserInputType.MouseMovement then
            local relY = (input.Position.Y - inspectorSplit.AbsolutePosition.Y) / inspectorSplit.AbsoluteSize.Y
            relY = math.clamp(relY, 0.22, 0.68)
            self._argsPanelHeight = relY
            argsPanel.Size = UDim2.new(1, 0, relY, -4)
            horizontalResizer.Position = UDim2.new(0, 0, relY, -5)
            detailsPanel.Size = UDim2.new(1, 0, 1 - relY, -4)
            detailsPanel.Position = UDim2.new(0, 0, relY, 4)
        end
    end))

    self.RemotesTab = tab
    self:ShowInspectorEmptyState()
end

function RemoteSpyUI:CreateRequireTab()
    local tab = createInstance("Frame", {
        Name = "RequireTab",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = self.ContentFrame
    })
    createPadding(tab, 12)
    createListLayout(tab, 10)

    
    
    
    local chrome = createPanel(Theme.Radius.Medium, {
        Size = UDim2.new(1, 0, 0, 36),
        ImageColor3 = Theme.BackgroundSecondary,
        LayoutOrder = 1,
        Parent = tab,
    }, true)
    pcall(function()
        chrome.ClipsDescendants = true
    end)

    local chromePad = createInstance("Frame", {
        Size = UDim2.new(1, -16, 1, -8),
        Position = UDim2.new(0, 8, 0, 4),
        BackgroundTransparency = 1,
        ZIndex = 2,
        Parent = chrome,
    })

    local searchWrap = createInstance("Frame", {
        Size = UDim2.new(1, -190, 1, 0),
        BackgroundTransparency = 1,
        Parent = chromePad,
    })
    local searchContainer, searchInput = UIComponents.SearchBar(searchWrap, "Search modules...")
    searchContainer.Size = UDim2.new(1, 0, 1, 0)

    self._moduleSearchDebounceId = 0
    searchInput:GetPropertyChangedSignal("Text"):Connect(function()
        self._moduleSearchDebounceId = (self._moduleSearchDebounceId or 0) + 1
        local debounceId = self._moduleSearchDebounceId
        task.delay(0.25, function()
            if self._moduleSearchDebounceId ~= debounceId then
                return
            end
            ModuleExplorer.SearchFilter = searchInput.Text
            self:RefreshModuleList(true)
        end)
    end)

    local treeWrap = createInstance("Frame", {
        Size = UDim2.new(0, 72, 1, 0),
        Position = UDim2.new(1, -182, 0, 0),
        BackgroundTransparency = 1,
        Parent = chromePad,
    })
    UIComponents.Checkbox(treeWrap, self.ModuleTreeView, function(state)
        self.ModuleTreeView = state
        self:_switchModuleListView()
    end, "Tree")

    local actions = createInstance("Frame", {
        Size = UDim2.new(0, 100, 1, 0),
        Position = UDim2.new(1, -100, 0, 0),
        BackgroundTransparency = 1,
        Parent = chromePad,
    })
    createListLayout(actions, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

    self.RequireModuleCountLabel = createInstance("TextLabel", {
        Size = UDim2.new(0, 64, 1, 0),
        BackgroundTransparency = 1,
        Text = "0 modules",
        TextColor3 = Theme.TextMuted,
        TextSize = 10,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Right,
        LayoutOrder = 1,
        Parent = actions,
    })

    local function runModuleScan()
        if ModuleExplorer._scanRunning then
            ModuleExplorer:CancelScan()
            self.RequireModuleCountLabel.Text = "Scan cancelled"
            return
        end

        self.ModulesScanned = true
        self._moduleScanDisplayOrder = 0
        self:_clearModuleListFrame()
        self:_showModuleScanPlaceholder("Scanning...")
        self.RequireModuleCountLabel.Text = "Scanning..."

        ModuleExplorer:ScanAllModulesAsync(function(foundCount, processed)
            self.RequireModuleCountLabel.Text = string.format("Scanning... %d found", foundCount)
            local placeholder = self.ModuleListFrame:FindFirstChild("ModuleScanPlaceholder")
            if placeholder then
                placeholder.Text = string.format("Scanning... %d modules found", foundCount)
            end
        end, function(total)
            if self._moduleScanUIGen ~= ModuleExplorer._scanId then
                return
            end
            self:_removeModuleScanPlaceholder()
            if self.ModuleTreeView then
                self:RefreshModuleTreeList(true)
            else
                self:_resortModuleListAfterScan()
            end
            if total == 0 then
                self:_showModuleScanPlaceholder("No modules found")
            end
            self.RequireModuleCountLabel.Text = total .. " modules"
            UIComponents.Notification(self.ScreenGui, "Found " .. total .. " modules", "success")
        end, function(batch)
            if self.ModuleTreeView then
                self:_applyModuleTreeRowsIncremental()
            else
                self:_appendModulesDuringScan(batch)
            end
        end)
        self._moduleScanUIGen = ModuleExplorer._scanId
    end

    UIComponents.IconButton(actions, "rescan.png", runModuleScan, 26, "Rescan").LayoutOrder = 2

    
    
    
    local mainContent = createInstance("Frame", {
        Size = UDim2.new(1, 0, 1, -46),
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Parent = tab
    })

    local headerH = 32

    
    local modulePanel = createPanel(Theme.Radius.Medium, {
        Size = UDim2.new(0.30, -5, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        ImageColor3 = Theme.BackgroundSecondary,
        Parent = mainContent,
    }, true)
    pcall(function()
        modulePanel.ClipsDescendants = true
    end)

    local moduleTitle = createInstance("TextLabel", {
        Size = UDim2.new(1, -8, 0, headerH),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        Text = "Modules",
        TextColor3 = Theme.TextPrimary,
        TextSize = 11,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
        Parent = modulePanel
    })

    local moduleScroll = createInstance("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, -headerH),
        Position = UDim2.new(0, 0, 0, headerH),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Border,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = modulePanel
    })
    createPadding(moduleScroll, 4)
    createListLayout(moduleScroll, 2)

    self.ModuleListFrame = moduleScroll
    self.ModuleTitle = moduleTitle

    
    local contentsPanel = createPanel(Theme.Radius.Medium, {
        Size = UDim2.new(0.30, -5, 1, 0),
        Position = UDim2.new(0.30, 5, 0, 0),
        ImageColor3 = Theme.BackgroundSecondary,
        Parent = mainContent,
    }, true)
    pcall(function()
        contentsPanel.ClipsDescendants = true
    end)

    local contentsTitle = createInstance("TextLabel", {
        Size = UDim2.new(1, -8, 0, headerH),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        Text = "Contents",
        TextColor3 = Theme.TextPrimary,
        TextSize = 11,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
        Parent = contentsPanel
    })

    local contentsScroll = createInstance("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, -headerH),
        Position = UDim2.new(0, 0, 0, headerH),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Border,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = contentsPanel
    })
    createPadding(contentsScroll, 4)
    createListLayout(contentsScroll, 2)

    self.ContentsListFrame = contentsScroll
    self.ContentsTitle = contentsTitle

    
    local detailsPanel = createPanel(Theme.Radius.Medium, {
        Size = UDim2.new(0.40, -5, 1, 0),
        Position = UDim2.new(0.60, 5, 0, 0),
        ImageColor3 = Theme.BackgroundSecondary,
        Parent = mainContent,
    }, true)
    pcall(function()
        detailsPanel.ClipsDescendants = true
    end)

    local detailsTitle = createInstance("TextLabel", {
        Size = UDim2.new(1, -8, 0, headerH),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        Text = "Details",
        TextColor3 = Theme.TextPrimary,
        TextSize = 11,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
        Parent = detailsPanel
    })

    local detailsScroll = createInstance("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, -headerH),
        Position = UDim2.new(0, 0, 0, headerH),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Border,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        Parent = detailsPanel
    })
    createPadding(detailsScroll, 4)
    createListLayout(detailsScroll, 4)

    self.ModuleDetailsFrame = detailsScroll
    self.ModuleDetailsTitle = detailsTitle
    
    
    self.ModulePanel = modulePanel
    self.ContentsPanel = contentsPanel
    self.RequireDetailsPanel = detailsPanel
    self._modulePanelWidth = 0.30
    self._contentsPanelWidth = 0.30
    
    
    local resizer1 = createSplitResizer(
        mainContent,
        "vertical",
        UDim2.new(self._modulePanelWidth, -5, 0, 0),
        5
    )
    local draggingResizer1 = false
    resizer1.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingResizer1 = true
        end
    end)
    resizer1.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingResizer1 = false
        end
    end)

    local resizer2 = createSplitResizer(
        mainContent,
        "vertical",
        UDim2.new(self._modulePanelWidth + self._contentsPanelWidth, -5, 0, 0),
        5
    )
    local draggingResizer2 = false
    resizer2.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingResizer2 = true
        end
    end)
    resizer2.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingResizer2 = false
        end
    end)
    
    
    self:_trackConnection(UserInputService.InputChanged:Connect(function(input)
        if self._destroying or not mainContent.Parent then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        
        local relX = (input.Position.X - mainContent.AbsolutePosition.X) / mainContent.AbsoluteSize.X
        
        if draggingResizer1 then
            
            local maxX = self._modulePanelWidth + self._contentsPanelWidth - 0.1
            relX = math.clamp(relX, 0.15, maxX)
            
            local delta = relX - self._modulePanelWidth
            self._modulePanelWidth = relX
            self._contentsPanelWidth = self._contentsPanelWidth - delta
            
            modulePanel.Size = UDim2.new(self._modulePanelWidth, -5, 1, 0)
            resizer1.Position = UDim2.new(self._modulePanelWidth, -5, 0, 0)
            contentsPanel.Size = UDim2.new(self._contentsPanelWidth, -5, 1, 0)
            contentsPanel.Position = UDim2.new(self._modulePanelWidth, 5, 0, 0)
            resizer2.Position = UDim2.new(self._modulePanelWidth + self._contentsPanelWidth, -5, 0, 0)
            local detailsWidth = 1 - self._modulePanelWidth - self._contentsPanelWidth
            detailsPanel.Size = UDim2.new(detailsWidth, -5, 1, 0)
            detailsPanel.Position = UDim2.new(self._modulePanelWidth + self._contentsPanelWidth, 5, 0, 0)
        elseif draggingResizer2 then
            
            local minX = self._modulePanelWidth + 0.1
            relX = math.clamp(relX, minX, 0.85)
            
            self._contentsPanelWidth = relX - self._modulePanelWidth
            
            contentsPanel.Size = UDim2.new(self._contentsPanelWidth, -5, 1, 0)
            resizer2.Position = UDim2.new(relX, -5, 0, 0)
            local detailsWidth = 1 - relX
            detailsPanel.Size = UDim2.new(detailsWidth, -5, 1, 0)
            detailsPanel.Position = UDim2.new(relX, 5, 0, 0)
        end
    end))
    
    
    self.SelectedModuleData = nil
    self.SelectedModuleEntry = nil
    self.SelectedContentKey = nil
    self.SelectedContentData = nil
    self.ModulesScanned = false
    self.ModuleTreeView = false
    self.ExpandedModuleTreeNodes = {}
    self._moduleEntryByPath = {}
    self._moduleFolderByKey = {}
    self._moduleTreeRowById = {}
    self._moduleTreeCacheRoot = nil
    self._moduleTreeCacheKey = nil
    self._moduleListRefreshGen = 0
    self._contentsRefreshGen = 0
    
    
    
    self.RequireTab = tab
end

function RemoteSpyUI:_clearModuleListFrame()
    for _, child in ipairs(self.ModuleListFrame:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    self._moduleEntryByPath = {}
    self._moduleFolderByKey = {}
    self._moduleTreeRowById = {}
    self:_invalidateModuleTreeCache()
end

function RemoteSpyUI:_invalidateModuleTreeCache()
    self._moduleTreeCacheRoot = nil
    self._moduleTreeCacheKey = nil
    self._moduleTreeParentByKey = nil
end

function RemoteSpyUI:_getCachedModuleTree()
    local modules = ModuleExplorer:GetFilteredModules()
    local cacheKey = tostring(ModuleExplorer._scanId or 0) .. "|" .. tostring(ModuleExplorer.SearchFilter or "") .. "|" .. #modules
    if self._moduleTreeCacheKey ~= cacheKey or not self._moduleTreeCacheRoot then
        self._moduleTreeCacheRoot = ModuleExplorer:BuildModuleTree(modules)
        self._moduleTreeParentByKey = ModuleExplorer._treeParentByKey or {}
        self._moduleTreeCacheKey = cacheKey
    end
    return self._moduleTreeCacheRoot
end

function RemoteSpyUI:_getModuleTreeRowPath(row)
    if row.Type == "module" then
        return row.Module.Path
    end
    return row.Node.Key
end

function RemoteSpyUI:_isModuleTreeRowVisible(row, expandedNodes)
    return areTreeAncestorsExpanded(self:_getModuleTreeRowPath(row), expandedNodes, self._moduleTreeParentByKey)
end

function RemoteSpyUI:_setTreeHeaderExpanded(entry, isExpanded)
    if not entry then
        return
    end
    setModuleTreeArrowExpanded(entry:FindFirstChild("TreeArrow"), isExpanded)
end

function RemoteSpyUI:_createModuleTreeRowEntry(row, order)
    if row.Type == "folder" then
        local entry = self:CreateModuleFolderEntry(row.Node, row.Depth, order)
        self._moduleFolderByKey[row.Node.Key] = entry
        return entry
    elseif row.Type == "module_branch" then
        local entry = self:CreateModuleBranchEntry(row.Node, row.Depth, order)
        self._moduleFolderByKey[row.Node.Key] = entry
        return entry
    else
        return self:CreateModuleEntry(row.Module, order, row.Depth, true)
    end
end

function RemoteSpyUI:_setFlatModuleListVisible(visible)
    for _, entry in pairs(self._moduleEntryByPath or {}) do
        if entry and entry.Parent then
            entry.Visible = visible
        end
    end
end

function RemoteSpyUI:_setModuleTreeRowsVisible(visible)
    if visible then
        self:_applyModuleTreeRowsIncremental(false)
    else
        for _, entry in pairs(self._moduleTreeRowById or {}) do
            if entry and entry.Parent then
                entry.Visible = false
            end
        end
    end
end

function RemoteSpyUI:_flatModuleListIsComplete(modules)
    modules = modules or ModuleExplorer:GetFilteredModules()
    for _, moduleData in ipairs(modules) do
        local entry = self._moduleEntryByPath[moduleData.Path]
        if not entry or not entry.Parent or entry:GetAttribute("TreeNodeKey") then
            return false
        end
    end
    return true
end

function RemoteSpyUI:_syncFlatModuleList(modules)
    modules = modules or ModuleExplorer:GetFilteredModules()
    local visiblePaths = {}
    
    for i, moduleData in ipairs(modules) do
        local path = moduleData.Path
        visiblePaths[path] = true
        local entry = self._moduleEntryByPath[path]
        
        if entry and entry.Parent and not entry:GetAttribute("TreeNodeKey") then
            entry.Visible = true
            if entry.LayoutOrder ~= i then
                entry.LayoutOrder = i
            end
            self:_applyModuleEntryVisual(entry, path)
        else
            if entry and entry.Parent then
                entry:Destroy()
            end
            entry = self:CreateModuleEntry(moduleData, i)
            self._moduleEntryByPath[path] = entry
        end
    end
    
    for path, entry in pairs(self._moduleEntryByPath) do
        if not visiblePaths[path] and entry.Parent then
            entry:Destroy()
            self._moduleEntryByPath[path] = nil
        end
    end
    
    if self.RequireModuleCountLabel then
        self.RequireModuleCountLabel.Text = #modules .. " modules"
    end
end

function RemoteSpyUI:_clearModuleTreeRowsOnly()
    for _, entry in pairs(self._moduleTreeRowById or {}) do
        if entry and entry.Parent then
            entry:Destroy()
        end
    end
    self._moduleTreeRowById = {}
    self._moduleFolderByKey = {}
    self:_invalidateModuleTreeCache()
end

function RemoteSpyUI:_switchModuleListView()
    if not self.ModuleListFrame then
        return
    end
    
    if not self.ModulesScanned then
        return
    end
    
    self:_removeModuleScanPlaceholder()
    local modules = ModuleExplorer:GetFilteredModules()
    
    if self.ModuleTreeView then
        if not next(self._moduleTreeRowById or {}) then
            self:_applyModuleTreeRowsIncremental()
        else
            self:_setModuleTreeRowsVisible(true)
        end
        self:_setFlatModuleListVisible(false)
    else
        if not self:_flatModuleListIsComplete(modules) then
            self:_syncFlatModuleList(modules)
        else
            self:_setFlatModuleListVisible(true)
            for i, moduleData in ipairs(modules) do
                local entry = self._moduleEntryByPath[moduleData.Path]
                if entry and entry.Parent then
                    if entry.LayoutOrder ~= i then
                        entry.LayoutOrder = i
                    end
                    self:_applyModuleEntryVisual(entry, moduleData.Path)
                end
            end
            if self.RequireModuleCountLabel then
                self.RequireModuleCountLabel.Text = #modules .. " modules"
            end
        end
        self:_setModuleTreeRowsVisible(false)
    end
end

function RemoteSpyUI:_findTreeNodeByKey(node, key)
    if not node or not key then
        return nil
    end
    if node.Key == key then
        return node
    end
    for _, child in pairs(node.Children or {}) do
        local found = self:_findTreeNodeByKey(child, key)
        if found then
            return found
        end
    end
    return nil
end

function RemoteSpyUI:_getTreeNodeDepth(treeRoot, key)
    local foundDepth = 0
    local function walk(node, depth)
        if node.Key == key then
            foundDepth = depth
            return true
        end
        for _, child in ipairs(node.SortedChildren or {}) do
            if walk(child, depth + 1) then
                return true
            end
        end
        return false
    end
    walk(treeRoot, 0)
    return foundDepth
end

function RemoteSpyUI:_collectRowsUnderTreeNode(node, depth, rows)
    for _, childNode in ipairs(node.SortedChildren or {}) do
        local rowType = getTreeNodeRowType(childNode)
        if rowType == "module" then
            if childNode.SelfModule then
                table.insert(rows, {
                    Type = "module",
                    Module = childNode.SelfModule,
                    Depth = depth,
                })
            end
        else
            table.insert(rows, {
                Type = rowType,
                Node = childNode,
                Depth = depth,
            })
        end
        self:_collectRowsUnderTreeNode(childNode, depth + 1, rows)
    end
    
    for _, moduleData in ipairs(node.Modules or {}) do
        table.insert(rows, {
            Type = "module",
            Module = moduleData,
            Depth = depth,
        })
    end
end

function RemoteSpyUI:_refreshVisibleModuleTreeLayoutOrders()
    if not self.ModuleListFrame or not self.ModulesScanned then
        return
    end
    
    local treeRoot = self:_getCachedModuleTree()
    local rows = {}
    self:_collectModuleTreeRows(treeRoot, 0, rows, true)
    local expandedNodes = self.ExpandedModuleTreeNodes
    
    local visibleOrder = 0
    local hiddenOrder = 1000000
    
    for _, row in ipairs(rows) do
        local rowId = self:_getModuleTreeRowId(row)
        local entry = self._moduleTreeRowById[rowId]
        if entry and entry.Parent then
            if self:_isModuleTreeRowVisible(row, expandedNodes) then
                visibleOrder = visibleOrder + 1
                entry.Visible = true
                entry.LayoutOrder = visibleOrder
            else
                entry.Visible = false
                entry.LayoutOrder = hiddenOrder
                hiddenOrder = hiddenOrder + 1
            end
        end
    end
end

function RemoteSpyUI:_collectModuleTreeRows(node, depth, rows, includeNodeModules)
    depth = depth or 0
    if includeNodeModules == nil then
        includeNodeModules = true
    end
    
    for _, childNode in ipairs(node.SortedChildren or {}) do
        local rowType = getTreeNodeRowType(childNode)
        if rowType == "module" then
            if childNode.SelfModule then
                table.insert(rows, {
                    Type = "module",
                    Module = childNode.SelfModule,
                    Depth = depth,
                })
            end
        else
            table.insert(rows, {
                Type = rowType,
                Node = childNode,
                Depth = depth,
            })
        end
        
        if rowType ~= "module" and self.ExpandedModuleTreeNodes[childNode.Key] == true then
            for _, moduleData in ipairs(childNode.Modules or {}) do
                table.insert(rows, {
                    Type = "module",
                    Module = moduleData,
                    Depth = depth + 1,
                })
            end
            
            self:_collectModuleTreeRows(childNode, depth + 1, rows, false)
        end
    end
    
    if includeNodeModules then
        for _, moduleData in ipairs(node.Modules or {}) do
            table.insert(rows, {
                Type = "module",
                Module = moduleData,
                Depth = depth,
            })
        end
    end
end

function RemoteSpyUI:_applyModuleEntryVisual(entry, path)
    local isSelected = self.SelectedModuleData and self.SelectedModuleData.Path == path
    local stateKey = isSelected and "S" or "N"
    
    self:_setEntryVisualState(entry, stateKey, function()
        setSurfaceColor(entry, isSelected and Theme.Primary or Theme.BackgroundTertiary)
        setSurfaceTransparency(entry, isSelected and 0.7 or 0.9)
        local stroke = entry:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke:Destroy()
        end
    end)
end

function RemoteSpyUI:_refreshModuleListSelection()
    for _, child in ipairs(self.ModuleListFrame:GetChildren()) do
        if child:IsA("TextButton") then
            local modulePath = child:GetAttribute("ModulePath")
            if modulePath then
                self:_applyModuleEntryVisual(child, modulePath)
            end
        end
    end
end

function RemoteSpyUI:_getModuleTreeHeaderEntry(key)
    local entry = self._moduleFolderByKey[key]
    if entry and entry.Parent then
        return entry
    end
    for rowId, rowEntry in pairs(self._moduleTreeRowById or {}) do
        if rowId == "node:" .. key and rowEntry.Parent then
            return rowEntry
        end
    end
    return nil
end

function RemoteSpyUI:_toggleModuleTreeNode(key)
    if not key or key == "" then
        return
    end
    
    self.ExpandedModuleTreeNodes[key] = not (self.ExpandedModuleTreeNodes[key] == true)
    local isExpanded = self.ExpandedModuleTreeNodes[key] == true
    
    local entry = self:_getModuleTreeHeaderEntry(key)
    if entry then
        self:_setTreeHeaderExpanded(entry, isExpanded)
    end
    
    self:_syncModuleTreeRowsForKey(key)
end

function RemoteSpyUI:_syncModuleTreeRowsForKey(changedKey)
    if not self.ModuleListFrame or not self.ModulesScanned or not changedKey or changedKey == "" then
        return
    end
    
    local treeRoot = self:_getCachedModuleTree()
    local targetNode = self:_findTreeNodeByKey(treeRoot, changedKey)
    if not targetNode then
        return
    end
    
    local subtreeRows = {}
    local childDepth = self:_getTreeNodeDepth(treeRoot, changedKey) + 1
    self:_collectRowsUnderTreeNode(targetNode, childDepth, subtreeRows)
    
    local expandedNodes = self.ExpandedModuleTreeNodes
    
    for _, row in ipairs(subtreeRows) do
        local rowId = self:_getModuleTreeRowId(row)
        local shouldShow = self:_isModuleTreeRowVisible(row, expandedNodes)
        local entry = self._moduleTreeRowById[rowId]
        
        if shouldShow then
            if entry and entry.Parent then
                if row.Type == "folder" or row.Type == "module_branch" then
                    self:_setTreeHeaderExpanded(entry, expandedNodes[row.Node.Key] == true)
                end
            else
                entry = self:_createModuleTreeRowEntry(row, 0)
                self._moduleTreeRowById[rowId] = entry
                if row.Type == "folder" or row.Type == "module_branch" then
                    self._moduleFolderByKey[row.Node.Key] = entry
                end
            end
        elseif entry and entry.Parent then
            entry.Visible = false
        end
    end
    
    self:_refreshVisibleModuleTreeLayoutOrders()
end

function RemoteSpyUI:_selectModuleInTree(moduleData)
    if not moduleData then
        return
    end
    self.SelectedModuleData = moduleData
    self.SelectedContentKey = nil
    self.SelectedContentData = nil
    self:_refreshModuleListSelection()
    self:PopulateContentsPanel(moduleData)
    self:PopulateModuleDetailsPanel(nil)
end

function RemoteSpyUI:_getModuleTreeLayout(depth)
    local indent = 6 + (depth or 0) * 14
    return {
        indent = indent,
        arrow = indent,
        badge = indent + MODULE_TREE_ARROW_WIDTH,
        name = indent + 30,
        namePad = indent + 56,
    }
end

function RemoteSpyUI:_syncTreeArrowHitZone(header, indent)
    local arrowHit = header and header:FindFirstChild("TreeArrowHit")
    if arrowHit then
        arrowHit.Position = UDim2.new(0, indent, 0, 0)
    end
end

function RemoteSpyUI:_applyModuleTreeRowLayout(entry, depth, opts)
    if not entry then
        return
    end
    opts = opts or {}
    local layout = self:_getModuleTreeLayout(depth)
    
    local arrow = entry:FindFirstChild("TreeArrow")
    if arrow and arrow:IsA("GuiObject") then
        arrow.Position = UDim2.new(0, layout.arrow + MODULE_TREE_ARROW_WIDTH * 0.5, 0.5, 0)
        if opts.arrowExpanded ~= nil then
            setModuleTreeArrowExpanded(arrow, opts.arrowExpanded)
        elseif opts.arrowText ~= nil and arrow:IsA("TextLabel") then
            arrow.Text = opts.arrowText
        end
    end
    self:_syncTreeArrowHitZone(entry, layout.indent)
    
    local badge = entry:FindFirstChild("ModuleTreeBadge") or entry:FindFirstChild("ModuleTreeIcon")
    if badge then
        local yOff = badge.AnchorPoint.Y >= 0.5 and 0 or (badge.Position.Y.Offset)
        if badge.AnchorPoint.Y >= 0.5 then
            badge.Position = UDim2.new(0, layout.badge, 0.5, 0)
        else
            badge.Position = UDim2.new(0, layout.badge, 0, yOff)
        end
    end

    local folderIcon = entry:FindFirstChild("TreeFolderIcon")
    if folderIcon then
        folderIcon.Position = UDim2.new(0, layout.badge, 0.5, 0)
    end
    
    local nameLabel = entry:FindFirstChild("TreeNodeName")
    if nameLabel then
        nameLabel.Position = UDim2.new(0, layout.name, 0, 0)
        nameLabel.Size = UDim2.new(1, -layout.namePad, 1, 0)
    end
end

function RemoteSpyUI:_bindModuleTreeRowClicks(header, opts)
    opts = opts or {}
    local lastClickAt = 0
    local doubleClickWindow = 0.35
    
    if opts.onToggle then
        local arrow = header:FindFirstChild("TreeArrow")
        local existingHit = header:FindFirstChild("TreeArrowHit")
        if existingHit then
            existingHit:Destroy()
        end
        if arrow then
            local arrowHit = createInstance("TextButton", {
                Name = "TreeArrowHit",
                Size = UDim2.new(0, 14, 1, 0),
                Position = arrow.Position,
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                Parent = header,
            })
            arrowHit.MouseButton1Click:Connect(function()
                opts.onToggle()
            end)
        end
    end
    
    header.MouseButton1Click:Connect(function()
        local now = tick()
        
        if opts.toggleOnDoubleClick and opts.onToggle and lastClickAt > 0 and (now - lastClickAt) <= doubleClickWindow then
            lastClickAt = 0
            opts.onToggle()
            return
        end
        
        lastClickAt = now
        
        if opts.instantSelect and opts.onSelect then
            opts.onSelect()
        elseif opts.instantToggle and opts.onToggle then
            opts.onToggle()
        end
    end)
end

function RemoteSpyUI:_getModuleTreeRowId(row)
    if row.Type == "module" then
        return "mod:" .. row.Module.Path
    end
    return "node:" .. row.Node.Key
end

function RemoteSpyUI:_captureModuleListScrollAnchor()
    local frame = self.ModuleListFrame
    if not frame then
        return nil
    end
    
    local viewportTop = frame.AbsolutePosition.Y
    local anchorChild = nil
    local anchorTop = math.huge
    
    for _, child in ipairs(frame:GetChildren()) do
        if child:IsA("TextButton") and child.Visible then
            local top = child.AbsolutePosition.Y
            if top >= viewportTop - 1 and top < anchorTop then
                anchorTop = top
                anchorChild = child
            end
        end
    end
    
    if not anchorChild then
        return {CanvasY = frame.CanvasPosition.Y}
    end
    
    return {
        Key = anchorChild:GetAttribute("TreeNodeKey") or anchorChild:GetAttribute("ModulePath"),
        ScreenY = anchorChild.AbsolutePosition.Y,
        CanvasY = frame.CanvasPosition.Y,
    }
end

function RemoteSpyUI:_restoreModuleListScrollAnchor(anchor)
    if not anchor or not self.ModuleListFrame then
        return
    end
    
    local frame = self.ModuleListFrame
    
    if anchor.Key and anchor.ScreenY then
        for _, child in ipairs(frame:GetChildren()) do
            if child:IsA("TextButton") then
                local childKey = child:GetAttribute("TreeNodeKey") or child:GetAttribute("ModulePath")
                if childKey == anchor.Key then
                    local delta = child.AbsolutePosition.Y - anchor.ScreenY
                    frame.CanvasPosition = Vector2.new(0, math.max(0, anchor.CanvasY + delta))
                    return
                end
            end
        end
    end
    
    if anchor.CanvasY then
        frame.CanvasPosition = Vector2.new(0, math.max(0, anchor.CanvasY))
    end
end

function RemoteSpyUI:_applyModuleTreeRowsIncremental(purgeStale)
    if not self.ModuleListFrame then
        return
    end
    
    if not self.ModulesScanned then
        return
    end
    
    local modules = ModuleExplorer:GetFilteredModules()
    if #modules == 0 then
        return
    end
    
    local scrollAnchor = purgeStale and self:_captureModuleListScrollAnchor() or nil
    
    self:_removeModuleScanPlaceholder()
    
    local treeRoot = self:_getCachedModuleTree()
    
    local rows = {}
    self:_collectModuleTreeRows(treeRoot, 0, rows, true)
    
    self._moduleTreeRowById = self._moduleTreeRowById or {}
    local wantedIds = {}
    local expandedNodes = self.ExpandedModuleTreeNodes
    
    for _, row in ipairs(rows) do
        local rowId = self:_getModuleTreeRowId(row)
        wantedIds[rowId] = true
        local shouldShow = self:_isModuleTreeRowVisible(row, expandedNodes)
        local entry = self._moduleTreeRowById[rowId]
        
        if shouldShow then
            if entry and entry.Parent then
                if row.Type == "folder" then
                    self:_setTreeHeaderExpanded(entry, expandedNodes[row.Node.Key] == true)
                elseif row.Type == "module_branch" then
                    self:_setTreeHeaderExpanded(entry, expandedNodes[row.Node.Key] == true)
                    local path = row.Node.SelfModule and row.Node.SelfModule.Path
                    if path then
                        self:_applyModuleEntryVisual(entry, path)
                    end
                else
                    self:_applyModuleEntryVisual(entry, row.Module.Path)
                end
            else
                entry = self:_createModuleTreeRowEntry(row, 0)
                self._moduleTreeRowById[rowId] = entry
            end
        elseif entry and entry.Parent then
            entry.Visible = false
        end
    end
    
    self:_refreshVisibleModuleTreeLayoutOrders()
    
    if purgeStale then
        for rowId, entry in pairs(self._moduleTreeRowById) do
            if not wantedIds[rowId] and entry.Parent then
                entry:Destroy()
                self._moduleTreeRowById[rowId] = nil
            end
        end
        
        for key, entry in pairs(self._moduleFolderByKey or {}) do
            if entry and not entry.Parent then
                self._moduleFolderByKey[key] = nil
            end
        end
    end
    
    self.RequireModuleCountLabel.Text = #modules .. " modules"
    
    if scrollAnchor then
        self:_restoreModuleListScrollAnchor(scrollAnchor)
        task.defer(function()
            if self.ModuleListFrame and self.ModuleListFrame.Parent then
                self:_restoreModuleListScrollAnchor(scrollAnchor)
            end
        end)
    end
end

function RemoteSpyUI:_removeModuleScanPlaceholder()
    local placeholder = self.ModuleListFrame and self.ModuleListFrame:FindFirstChild("ModuleScanPlaceholder")
    if placeholder then
        placeholder:Destroy()
    end
end

function RemoteSpyUI:_showModuleScanPlaceholder(text)
    self:_removeModuleScanPlaceholder()
    createInstance("TextLabel", {
        Name = "ModuleScanPlaceholder",
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        Text = text or "Scanning...",
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        LayoutOrder = 0,
        Parent = self.ModuleListFrame
    })
end

function RemoteSpyUI:_appendModulesDuringScan(batch)
    if not batch or #batch == 0 or not self.ModuleListFrame then
        return
    end
    
    if self.ModuleTreeView then
        if self._moduleScanUIGen == ModuleExplorer._scanId then
            self:_applyModuleTreeRowsIncremental()
        end
        return
    end
    
    if self._moduleScanUIGen ~= ModuleExplorer._scanId then
        return
    end
    
    self:_removeModuleScanPlaceholder()
    self._moduleScanDisplayOrder = self._moduleScanDisplayOrder or 0
    
    local added = 0
    for _, moduleData in ipairs(batch) do
        if ModuleExplorer:ModuleMatchesFilter(moduleData) then
            local path = moduleData.Path
            if not self._moduleEntryByPath[path] then
                self._moduleScanDisplayOrder = self._moduleScanDisplayOrder + 1
                local entry = self:CreateModuleEntry(moduleData, self._moduleScanDisplayOrder)
                self._moduleEntryByPath[path] = entry
                added = added + 1
            end
        end
    end
    
    if added > 0 and self.RequireModuleCountLabel then
        self.RequireModuleCountLabel.Text = #ModuleExplorer.AllModules .. " modules"
    end
end

function RemoteSpyUI:_resortModuleListAfterScan()
    local modules = ModuleExplorer:GetFilteredModules()
    for i, moduleData in ipairs(modules) do
        local entry = self._moduleEntryByPath[moduleData.Path]
        if entry and entry.Parent then
            entry.LayoutOrder = i
        end
    end
    if self.RequireModuleCountLabel then
        self.RequireModuleCountLabel.Text = #modules .. " modules"
    end
end

function RemoteSpyUI:RefreshModuleList(forceFull)
    if self.ModuleTreeView then
        self:RefreshModuleTreeList(forceFull)
        return
    end
    
    if not self.ModulesScanned then
        self:_clearModuleListFrame()
        self.RequireModuleCountLabel.Text = "0 modules"
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, 50),
            BackgroundTransparency = 1,
            Text = "Click 'Refresh' to scan\nfor modules",
            TextColor3 = Theme.TextMuted,
            TextSize = 11,
            Font = Theme.FontFamily,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            LayoutOrder = 1,
            Parent = self.ModuleListFrame
        })
        return
    end
    
    local modules = ModuleExplorer:GetFilteredModules()
    
    if forceFull then
        self._setModuleTreeRowsVisible(false)
        for path, entry in pairs(self._moduleEntryByPath or {}) do
            if entry and entry.Parent then
                entry:Destroy()
            end
        end
        self._moduleEntryByPath = {}
    end
    
    if #modules == 0 then
        if forceFull then
            for path, entry in pairs(self._moduleEntryByPath or {}) do
                if entry and entry.Parent then
                    entry:Destroy()
                end
            end
            self._moduleEntryByPath = {}
        end
        self.RequireModuleCountLabel.Text = "0 modules"
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, 50),
            BackgroundTransparency = 1,
            Text = "No modules found",
            TextColor3 = Theme.TextMuted,
            TextSize = 11,
            Font = Theme.FontFamily,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            LayoutOrder = 1,
            Parent = self.ModuleListFrame
        })
        return
    end
    
    self:_removeModuleScanPlaceholder()
    self:_syncFlatModuleList(modules)
end

function RemoteSpyUI:RefreshModuleTreeList(forceFull)
    if not self.ModuleListFrame then
        return
    end
    
    if not self.ModulesScanned then
        self:_clearModuleListFrame()
        self.RequireModuleCountLabel.Text = "0 modules"
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, 50),
            BackgroundTransparency = 1,
            Text = "Click 'Refresh' to scan\nfor modules",
            TextColor3 = Theme.TextMuted,
            TextSize = 11,
            Font = Theme.FontFamily,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            LayoutOrder = 1,
            Parent = self.ModuleListFrame
        })
        return
    end
    
    local modules = ModuleExplorer:GetFilteredModules()
    
    if forceFull then
        self:_clearModuleTreeRowsOnly()
    end
    
    if #modules == 0 then
        if forceFull then
            self:_clearModuleTreeRowsOnly()
        end
        self.RequireModuleCountLabel.Text = "0 modules"
        if not ModuleExplorer._scanRunning then
            createInstance("TextLabel", {
                Size = UDim2.new(1, 0, 0, 50),
                BackgroundTransparency = 1,
                Text = "No modules found",
                TextColor3 = Theme.TextMuted,
                TextSize = 11,
                Font = Theme.FontFamily,
                TextXAlignment = Enum.TextXAlignment.Center,
                TextYAlignment = Enum.TextYAlignment.Center,
                LayoutOrder = 1,
                Parent = self.ModuleListFrame
            })
        end
        return
    end
    
    self:_setFlatModuleListVisible(false)
    self:_applyModuleTreeRowsIncremental(true)
end

function RemoteSpyUI:CreateModuleFolderEntry(folderNode, depth, order)
    local key = folderNode.Key
    local isExpanded = self.ExpandedModuleTreeNodes[key] == true
    local layout = self:_getModuleTreeLayout(depth)
    local moduleCount = countModulesInTreeNode(folderNode)
    
    local header = createInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundColor3 = Theme.BackgroundSecondary,
        BackgroundTransparency = 0.6,
        Text = "",
        LayoutOrder = order,
        Parent = self.ModuleListFrame
    })
    createCorner(header, Theme.CornerRadiusSmall)
    
    createModuleTreeArrow(header, isExpanded, layout)
    createAssetGlyph(header, "folder.png", 14, {
        Name = "TreeFolderIcon",
        Position = UDim2.new(0, layout.badge, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        ImageColor3 = Color3.new(1, 1, 1),
    })
    
    createInstance("TextLabel", {
        Name = "TreeNodeName",
        Size = UDim2.new(1, -layout.namePad, 1, 0),
        Position = UDim2.new(0, layout.name, 0, 0),
        BackgroundTransparency = 1,
        Text = folderNode.Name,
        TextColor3 = Theme.TextPrimary,
        TextSize = 11,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = header
    })
    
    createInstance("TextLabel", {
        Name = "FolderModuleCount",
        Size = UDim2.new(0, 36, 1, 0),
        Position = UDim2.new(1, -40, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(moduleCount),
        TextColor3 = Theme.TextMuted,
        TextSize = 9,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = header
    })
    
    header:SetAttribute("TreeNodeKey", key)
    header:SetAttribute("TreeDepth", depth)
    
    header.MouseEnter:Connect(function()
        tween(header, {BackgroundTransparency = 0.3}, 0.1)
    end)
    
    header.MouseLeave:Connect(function()
        tween(header, {BackgroundTransparency = 0.6}, 0.1)
    end)
    
    self:_bindModuleTreeRowClicks(header, {
        onToggle = function()
            self:_toggleModuleTreeNode(key)
        end,
        instantToggle = true,
    })
    
    return header
end

function RemoteSpyUI:CreateModuleBranchEntry(treeNode, depth, order)
    local key = treeNode.Key
    local moduleData = treeNode.SelfModule or ModuleExplorer:GetModuleByPath(treeNode.Key)
    local isExpanded = self.ExpandedModuleTreeNodes[key] == true
    local layout = self:_getModuleTreeLayout(depth)
    local moduleCount = countModulesInTreeNode(treeNode)
    local isSelected = moduleData and self.SelectedModuleData and self.SelectedModuleData.Path == moduleData.Path
    
    local header = createInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = isSelected and Theme.Primary or Theme.BackgroundTertiary,
        BackgroundTransparency = isSelected and 0.7 or 0.85,
        Text = "",
        LayoutOrder = order,
        Parent = self.ModuleListFrame
    })
    createCorner(header, Theme.CornerRadiusSmall)
    
    createModuleTreeArrow(header, isExpanded, layout)
    createClassIcon(header, "ModuleScript", 14, {
        Name = "ModuleTreeIcon",
        Position = UDim2.new(0, layout.badge, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
    })
    
    createInstance("TextLabel", {
        Name = "TreeNodeName",
        Size = UDim2.new(1, -layout.namePad, 1, 0),
        Position = UDim2.new(0, layout.name, 0, 0),
        BackgroundTransparency = 1,
        Text = moduleData and moduleData.Name or treeNode.Name,
        TextColor3 = Theme.TextPrimary,
        TextSize = 11,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = header
    })
    
    createInstance("TextLabel", {
        Name = "FolderModuleCount",
        Size = UDim2.new(0, 36, 1, 0),
        Position = UDim2.new(1, -40, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(moduleCount),
        TextColor3 = Theme.TextMuted,
        TextSize = 9,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = header
    })
    
    header:SetAttribute("TreeNodeKey", key)
    header:SetAttribute("TreeDepth", depth)
    if moduleData then
        header:SetAttribute("ModulePath", moduleData.Path)
    end
    
    local function selectBranchModule()
        local data = moduleData
        if data then
            self:_selectModuleInTree(data)
        end
    end
    
    self:_bindModuleTreeRowClicks(header, {
        onToggle = function()
            self:_toggleModuleTreeNode(key)
        end,
        onSelect = selectBranchModule,
        instantSelect = true,
        toggleOnDoubleClick = true,
    })
    
    header.MouseButton2Click:Connect(function()
        if not moduleData then
            return
        end
        local options = {
            {Text = "Copy Path", Action = function()
                copyToClipboard(formatRobloxPath(moduleData.Path))
                UIComponents.Notification(self.ScreenGui, "Path copied", "success")
            end},
            {Text = "Copy Require Code", Action = function()
                copyToClipboard(ModuleExplorer:GenerateModulePath(moduleData))
                UIComponents.Notification(self.ScreenGui, "Require code copied", "success")
            end},
        }
        UIComponents.ContextMenu(options, Vector2.new(header.AbsolutePosition.X + header.AbsoluteSize.X, header.AbsolutePosition.Y), self.ScreenGui)
    end)
    
    return header
end

function RemoteSpyUI:_updateModuleBranchEntry(entry, treeNode, depth)
    local key = treeNode.Key
    local isExpanded = self.ExpandedModuleTreeNodes[key] == true
    local moduleData = treeNode.SelfModule or ModuleExplorer:GetModuleByPath(treeNode.Key)
    local isSelected = moduleData and self.SelectedModuleData and self.SelectedModuleData.Path == moduleData.Path
    
    setSurfaceColor(entry, isSelected and Theme.Primary or Theme.BackgroundTertiary)
    setSurfaceTransparency(entry, isSelected and 0.7 or 0.85)
    
    self:_applyModuleTreeRowLayout(entry, depth, {
        arrowExpanded = isExpanded,
    })
    
    local nameLabel = entry:FindFirstChild("TreeNodeName")
    if nameLabel then
        nameLabel.Text = moduleData and moduleData.Name or treeNode.Name
    end
    
    local countLabel = entry:FindFirstChild("FolderModuleCount")
    if countLabel then
        countLabel.Text = tostring(countModulesInTreeNode(treeNode))
    end
    
    local stroke = entry:FindFirstChildOfClass("UIStroke")
    if stroke then
        stroke:Destroy()
    end
end

function RemoteSpyUI:_updateModuleFolderEntry(entry, folderNode, depth)
    local key = folderNode.Key
    local isExpanded = self.ExpandedModuleTreeNodes[key] == true
    local layout = self:_getModuleTreeLayout(depth)
    
    self:_applyModuleTreeRowLayout(entry, depth, {
        arrowExpanded = isExpanded,
    })
    
    local folderIcon = entry:FindFirstChild("TreeFolderIcon")
    if folderIcon then
        folderIcon.Position = UDim2.new(0, layout.badge, 0.5, 0)
    end
    
    local countLabel = entry:FindFirstChild("FolderModuleCount")
    if countLabel then
        countLabel.Text = tostring(countModulesInTreeNode(folderNode))
    end
    
    local nameLabel = entry:FindFirstChild("TreeNodeName")
    if nameLabel then
        nameLabel.Text = folderNode.Name
    end
end

function RemoteSpyUI:CreateModuleEntry(moduleData, order, depth, treeMode)
    local path = moduleData.Path
    local isSelected = self.SelectedModuleData and self.SelectedModuleData.Path == path
    depth = depth or 0
    treeMode = treeMode == true
    local layout = treeMode and self:_getModuleTreeLayout(depth) or nil
    local indent = treeMode and layout.indent or 6
    local rowHeight = treeMode and 26 or 32
    
    local header = createInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, rowHeight),
        BackgroundColor3 = isSelected and Theme.Primary or Theme.BackgroundTertiary,
        BackgroundTransparency = isSelected and 0.7 or 0.9,
        Text = "",
        LayoutOrder = order,
        Parent = self.ModuleListFrame
    })
    createCorner(header, Theme.CornerRadiusSmall)
    
    if treeMode then
        createModuleTreeArrow(header, false, layout)
        local arrow = header:FindFirstChild("TreeArrow")
        if arrow then
            arrow.Visible = false
        end
    end
    
    local iconX = treeMode and layout.badge or indent
    createClassIcon(header, "ModuleScript", treeMode and 14 or 16, {
        Name = "ModuleTreeIcon",
        Position = UDim2.new(0, iconX, 0.5, treeMode and 0 or -4),
        AnchorPoint = Vector2.new(0, 0.5),
    })
    
    local nameLabelProps = {
        Size = UDim2.new(1, treeMode and -layout.namePad or -(indent + 34), treeMode and 1 or 0, treeMode and 0 or 14),
        Position = UDim2.new(0, treeMode and layout.name or indent + 22, 0, treeMode and 0 or 2),
        BackgroundTransparency = 1,
        Text = moduleData.Name,
        TextColor3 = Theme.TextPrimary,
        TextSize = 11,
        Font = treeMode and Theme.FontFamilyMono or Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = header,
    }
    if treeMode then
        nameLabelProps.Name = "TreeNodeName"
    end
    createInstance("TextLabel", nameLabelProps)
    
    if not treeMode then
        createInstance("TextLabel", {
            Size = UDim2.new(1, -30, 0, 12),
            Position = UDim2.new(0, 30, 0, 17),
            BackgroundTransparency = 1,
            Text = moduleData.Path,
            TextColor3 = Theme.TextMuted,
            TextSize = 9,
            Font = Theme.FontFamily,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = header
        })
    end
    
    header.MouseEnter:Connect(function()
        if not isSelected then
            tween(header, {BackgroundTransparency = 0.7}, 0.1)
        end
    end)
    
    header.MouseLeave:Connect(function()
        if not isSelected then
            tween(header, {BackgroundTransparency = 0.9}, 0.1)
        end
    end)
    
    header:SetAttribute("ModulePath", path)
    
    if treeMode then
        self:_bindModuleTreeRowClicks(header, {
            onSelect = function()
                self:_selectModuleInTree(moduleData)
            end,
            instantSelect = true,
        })
    else
        header.MouseButton1Click:Connect(function()
            self:_selectModuleInTree(moduleData)
        end)
    end
    
    header.MouseButton2Click:Connect(function()
        local options = {
            {Text = "Copy Path", Action = function()
                copyToClipboard(formatRobloxPath(path))
                UIComponents.Notification(self.ScreenGui, "Path copied", "success")
            end},
            {Text = "Copy Require Code", Action = function()
                copyToClipboard(ModuleExplorer:GenerateModulePath(moduleData))
                UIComponents.Notification(self.ScreenGui, "Require code copied", "success")
            end},
        }
        UIComponents.ContextMenu(options, Vector2.new(header.AbsolutePosition.X + header.AbsoluteSize.X, header.AbsolutePosition.Y), self.ScreenGui)
    end)
    
    return header
end

function RemoteSpyUI:PopulateContentsPanel(moduleData)
    self._contentsRefreshGen = (self._contentsRefreshGen or 0) + 1
    local refreshGen = self._contentsRefreshGen
    
    for _, child in ipairs(self.ContentsListFrame:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    
    if not moduleData then
        self.ContentsTitle.Text = "  Contents"
        return
    end
    
    self.ContentsTitle.Text = "  Loading..."
    
    task.spawn(function()
        local entry = ModuleExplorer:RequireModule(moduleData)
        
        if refreshGen ~= self._contentsRefreshGen then
            return
        end
        if not self.SelectedModuleData or self.SelectedModuleData.Path ~= moduleData.Path then
            return
        end
        
        self.SelectedModuleEntry = entry
        
        for _, child in ipairs(self.ContentsListFrame:GetChildren()) do
            if child:IsA("Frame") or child:IsA("TextButton") or child:IsA("TextLabel") then
                child:Destroy()
            end
        end
        
        if not entry.LoadSuccess then
            self.ContentsTitle.Text = "  Contents (Error)"
            createInstance("TextLabel", {
                Size = UDim2.new(1, 0, 0, 50),
                BackgroundTransparency = 1,
                Text = "Failed to load:\n" .. (entry.LoadError or "Unknown error"),
                TextColor3 = Theme.Danger,
                TextSize = 10,
                Font = Theme.FontFamily,
                TextWrapped = true,
                LayoutOrder = 1,
                Parent = self.ContentsListFrame
            })
            return
        end
        
        local sortedContents = ModuleExplorer:GetSortedContents(entry)
        self.ContentsTitle.Text = "  Contents (" .. #sortedContents .. ")"
        
        if #sortedContents == 0 then
            createInstance("TextLabel", {
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundTransparency = 1,
                Text = type(entry.Result) ~= "table" and ("Returns: " .. type(entry.Result)) or "Empty module",
                TextColor3 = Theme.TextMuted,
                TextSize = 11,
                Font = Theme.FontFamily,
                LayoutOrder = 1,
                Parent = self.ContentsListFrame
            })
            return
        end
        
        local built = 0
        for i, contentData in ipairs(sortedContents) do
            if refreshGen ~= self._contentsRefreshGen then
                return
            end
            self:CreateContentEntry(moduleData, contentData, i)
            built = built + 1
            if built % MODULE_UI_YIELD_EVERY == 0 then
                self.ContentsTitle.Text = "  Contents (" .. built .. "/" .. #sortedContents .. ")"
                RunService.Heartbeat:Wait()
            end
        end
        
        if refreshGen == self._contentsRefreshGen then
            self.ContentsTitle.Text = "  Contents (" .. #sortedContents .. ")"
        end
    end)
end

function RemoteSpyUI:CreateContentEntry(moduleData, contentData, order)
    local isSelected = self.SelectedContentKey == contentData.KeyStr
    
    local header = createInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = isSelected and Theme.Primary or Theme.BackgroundTertiary,
        BackgroundTransparency = isSelected and 0.7 or 0.85,
        Text = "",
        LayoutOrder = order,
        Parent = self.ContentsListFrame
    })
    createCorner(header, Theme.CornerRadiusSmall)
    
    
    if contentData.IsFunction then
        createAssetGlyph(header, "function.png", 12, {
            Name = "ContentTypeIcon",
            Position = UDim2.new(0, 13, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ImageColor3 = Theme.Cyan,
        })
    elseif contentData.IsTable then
        createAssetGlyph(header, "brackets.png", 12, {
            Name = "ContentTypeIcon",
            Position = UDim2.new(0, 13, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ImageColor3 = Theme.Warning,
        })
    elseif contentData.IsInstance or contentData.DisplayType == "Instance" then
        local className = contentData.InstanceClass
        if (not className or className == "") and typeof(contentData.Value) == "Instance" then
            className = contentData.Value.ClassName
        end
        createClassIcon(header, className or "Instance", 12, {
            Name = "ContentTypeIcon",
            Position = UDim2.new(0, 13, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
        })
    else
        createAssetGlyph(header, "equal.png", 12, {
            Name = "ContentTypeIcon",
            Position = UDim2.new(0, 13, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ImageColor3 = Theme.TextMuted,
        })
    end
    
    
    createInstance("TextLabel", {
        Size = UDim2.new(0.5, -25, 1, 0),
        Position = UDim2.new(0, 24, 0, 0),
        BackgroundTransparency = 1,
        Text = contentData.KeyStr,
        TextColor3 = Theme.TextPrimary,
        TextSize = 10,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = header
    })
    
    
    local preview = ""
    if contentData.IsFunction then
        local funcInfo = contentData.FuncInfo or {}
        local argCount = funcInfo.NumArgs or 0
        local isVariadic = funcInfo.IsVariadic or false
        preview = "(" .. argCount .. " args" .. (isVariadic and "..." or "") .. ")"
    elseif contentData.IsTable then
        local count = 0
        pcall(function()
            for _ in pairs(contentData.Value) do count = count + 1 end
        end)
        preview = "{" .. count .. " items}"
    else
        local val = tostring(contentData.Value)
        if #val > 20 then val = val:sub(1, 20) .. "..." end
        preview = val
    end
    
    createInstance("TextLabel", {
        Size = UDim2.new(0.5, -10, 1, 0),
        Position = UDim2.new(0.5, 5, 0, 0),
        BackgroundTransparency = 1,
        Text = preview,
        TextColor3 = Theme.TextSecondary,
        TextSize = 9,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = header
    })
    
    header.MouseEnter:Connect(function()
        if self.SelectedContentKey ~= contentData.KeyStr then
            tween(header, {BackgroundTransparency = 0.6}, 0.1)
        end
    end)
    
    header.MouseLeave:Connect(function()
        if self.SelectedContentKey ~= contentData.KeyStr then
            tween(header, {BackgroundTransparency = 0.85}, 0.1)
        end
    end)
    
    header:SetAttribute("ContentKeyStr", contentData.KeyStr)
    
    header.MouseButton1Click:Connect(function()
        self.SelectedContentKey = contentData.KeyStr
        self.SelectedContentData = contentData
        self:_refreshContentsListSelection()
        self:PopulateModuleDetailsPanel(contentData)
    end)
end

function RemoteSpyUI:_applyContentEntryVisual(entry, keyStr)
    local isSelected = self.SelectedContentKey == keyStr
    local stateKey = isSelected and "S" or "N"
    
    self:_setEntryVisualState(entry, stateKey, function()
        setSurfaceColor(entry, isSelected and Theme.Primary or Theme.BackgroundTertiary)
        setSurfaceTransparency(entry, isSelected and 0.7 or 0.85)
        local stroke = entry:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke:Destroy()
        end
    end)
end

function RemoteSpyUI:_refreshContentsListSelection()
    for _, child in ipairs(self.ContentsListFrame:GetChildren()) do
        if child:IsA("TextButton") then
            local keyStr = child:GetAttribute("ContentKeyStr")
            if keyStr then
                self:_applyContentEntryVisual(child, keyStr)
            end
        end
    end
end

function RemoteSpyUI:PopulateModuleDetailsPanel(contentData)
    for _, child in ipairs(self.ModuleDetailsFrame:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("ScrollingFrame") then
            child:Destroy()
        end
    end
    
    local moduleData = self.SelectedModuleData
    local moduleEntry = self.SelectedModuleEntry
    
    if not moduleData then
        self.ModuleDetailsTitle.Text = "  Details"
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            Text = "Select a module",
            TextColor3 = Theme.TextMuted,
            TextSize = 11,
            Font = Theme.FontFamily,
            LayoutOrder = 1,
            Parent = self.ModuleDetailsFrame
        })
        return
    end
    
    
    local moduleBtnRow = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        Parent = self.ModuleDetailsFrame
    })
    createListLayout(moduleBtnRow, 4, Enum.FillDirection.Horizontal)
    
    UIComponents.Button(moduleBtnRow, "Copy Path", nil, function()
        copyToClipboard(formatRobloxPath(moduleData.Path))
        UIComponents.Notification(self.ScreenGui, "Path copied", "success")
    end).LayoutOrder = 1
    
    UIComponents.Button(moduleBtnRow, "Copy Require", nil, function()
        copyToClipboard(ModuleExplorer:GenerateModulePath(moduleData))
        UIComponents.Notification(self.ScreenGui, "Require code copied", "success")
    end).LayoutOrder = 2
    
    if moduleEntry and moduleEntry.LoadSuccess then
        UIComponents.Button(moduleBtnRow, "Decompile", "primary", function()
            local script = "-- Decompiling module: " .. moduleData.Name .. "\n\n"
            if decompile then
                local success, result = pcall(function()
                    return decompile(moduleData.Module)
                end)
                if success and result then
                    script = script .. result
                else
                    script = script .. "-- Decompilation failed: " .. tostring(result)
                end
            else
                script = script .. "-- Decompile function not available"
            end
            copyToClipboard(script)
            UIComponents.Notification(self.ScreenGui, "Decompiled code copied", "success")
        end).LayoutOrder = 3
    end
    
    
    UIComponents.Separator(self.ModuleDetailsFrame).LayoutOrder = 2
    
    if not contentData then
        self.ModuleDetailsTitle.Text = "  " .. moduleData.Name
        
        
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = "Path: " .. moduleData.Path,
            TextColor3 = Theme.TextSecondary,
            TextSize = 10,
            Font = Theme.FontFamily,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            LayoutOrder = 3,
            Parent = self.ModuleDetailsFrame
        })
        
        if moduleEntry then
            createInstance("TextLabel", {
                Size = UDim2.new(1, 0, 0, 16),
                BackgroundTransparency = 1,
                Text = "Status: " .. (moduleEntry.LoadSuccess and "Loaded" or "Failed"),
                TextColor3 = moduleEntry.LoadSuccess and Theme.Success or Theme.Danger,
                TextSize = 10,
                Font = Theme.FontFamily,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 4,
                Parent = self.ModuleDetailsFrame
            })
            
            if moduleEntry.LoadSuccess then
                createInstance("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 16),
                    BackgroundTransparency = 1,
                    Text = "Return Type: " .. type(moduleEntry.Result),
                    TextColor3 = Theme.TextSecondary,
                    TextSize = 10,
                    Font = Theme.FontFamily,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    LayoutOrder = 5,
                    Parent = self.ModuleDetailsFrame
                })
            end
        end
        
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            Text = "\nSelect content to view details",
            TextColor3 = Theme.TextMuted,
            TextSize = 11,
            Font = Theme.FontFamily,
            LayoutOrder = 10,
            Parent = self.ModuleDetailsFrame
        })
        return
    end
    
    
    self.ModuleDetailsTitle.Text = "  " .. contentData.KeyStr
    
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "Type: " .. contentData.DisplayType,
        TextColor3 = Theme.TextPrimary,
        TextSize = 11,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 3,
        Parent = self.ModuleDetailsFrame
    })
    
    if contentData.IsFunction then
        
        local funcInfo = contentData.FuncInfo or {}
        
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, 14),
            BackgroundTransparency = 1,
            Text = "Arguments: " .. (funcInfo.NumArgs or 0) .. (funcInfo.IsVariadic and " (variadic)" or ""),
            TextColor3 = Theme.TextSecondary,
            TextSize = 10,
            Font = Theme.FontFamily,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 4,
            Parent = self.ModuleDetailsFrame
        })
        
        if funcInfo.Source then
            createInstance("TextLabel", {
                Size = UDim2.new(1, 0, 0, 14),
                BackgroundTransparency = 1,
                Text = "Source: " .. tostring(funcInfo.Source):sub(1, 50),
                TextColor3 = Theme.TextSecondary,
                TextSize = 10,
                Font = Theme.FontFamily,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                LayoutOrder = 5,
                Parent = self.ModuleDetailsFrame
            })
        end
        
        if funcInfo.Line then
            createInstance("TextLabel", {
                Size = UDim2.new(1, 0, 0, 14),
                BackgroundTransparency = 1,
                Text = "Line: " .. tostring(funcInfo.Line),
                TextColor3 = Theme.TextSecondary,
                TextSize = 10,
                Font = Theme.FontFamily,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 6,
                Parent = self.ModuleDetailsFrame
            })
        end
        
        local closureType = "Unknown"
        if funcInfo.IsLuaClosure then
            closureType = "Lua Closure"
        elseif funcInfo.IsCClosure then
            closureType = "C Closure"
        end
        
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, 14),
            BackgroundTransparency = 1,
            Text = "Closure: " .. closureType,
            TextColor3 = Theme.TextSecondary,
            TextSize = 10,
            Font = Theme.FontFamily,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 7,
            Parent = self.ModuleDetailsFrame
        })
        
        
        UIComponents.Separator(self.ModuleDetailsFrame).LayoutOrder = 10
        
        local funcBtnRow1 = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            LayoutOrder = 11,
            Parent = self.ModuleDetailsFrame
        })
        createListLayout(funcBtnRow1, 4, Enum.FillDirection.Horizontal)
        
        UIComponents.Button(funcBtnRow1, "Copy Call", "primary", function()
            local code = ModuleExplorer:GenerateCallingCode(moduleData, contentData)
            copyToClipboard(code)
            UIComponents.Notification(self.ScreenGui, "Calling code copied", "success")
        end).LayoutOrder = 1
        
        UIComponents.Button(funcBtnRow1, "Copy Intercept", nil, function()
            local code = ModuleExplorer:GenerateInterceptCode(moduleData, contentData)
            copyToClipboard(code)
            UIComponents.Notification(self.ScreenGui, "Intercept code copied", "success")
        end).LayoutOrder = 2
        
        local funcBtnRow2 = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            LayoutOrder = 12,
            Parent = self.ModuleDetailsFrame
        })
        createListLayout(funcBtnRow2, 4, Enum.FillDirection.Horizontal)
        
        UIComponents.Button(funcBtnRow2, "Decompile Func", nil, function()
            local code = ModuleExplorer:DecompileFunction(contentData.Value)
            copyToClipboard(code)
            UIComponents.Notification(self.ScreenGui, "Function decompiled", "success")
        end).LayoutOrder = 1
        
        UIComponents.Button(funcBtnRow2, "Copy Set", nil, function()
            local code = ModuleExplorer:GenerateSetCode(moduleData, contentData, "function(...) end")
            copyToClipboard(code)
            UIComponents.Notification(self.ScreenGui, "Set code copied", "success")
        end).LayoutOrder = 2
        
    elseif contentData.IsTable then
        
        local count = 0
        pcall(function()
            for _ in pairs(contentData.Value) do count = count + 1 end
        end)
        
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, 14),
            BackgroundTransparency = 1,
            Text = "Items: " .. count,
            TextColor3 = Theme.TextSecondary,
            TextSize = 10,
            Font = Theme.FontFamily,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 4,
            Parent = self.ModuleDetailsFrame
        })
        
        
        UIComponents.Separator(self.ModuleDetailsFrame).LayoutOrder = 5
        
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = "Table Contents:",
            TextColor3 = Theme.TextPrimary,
            TextSize = 10,
            Font = Theme.FontFamilyBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 6,
            Parent = self.ModuleDetailsFrame
        })
        
        local parsedTable = ""
        local parseSuccess = pcall(function()
            parsedTable = parse(contentData.Value)
        end)
        
        if not parseSuccess or parsedTable == "" then
            parsedTable = "-- Failed to parse table"
        end
        
        
        local tableContainer = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 180),
            BackgroundTransparency = 1,
            LayoutOrder = 7,
            Parent = self.ModuleDetailsFrame
        })
        
        
        UIComponents.ChunkedTextArea(tableContainer, parsedTable, true, nil)
        
        
        local tableBtnRow = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            LayoutOrder = 10,
            Parent = self.ModuleDetailsFrame
        })
        createListLayout(tableBtnRow, 4, Enum.FillDirection.Horizontal)
        
        UIComponents.Button(tableBtnRow, "Copy Raw", "primary", function()
            copyToClipboard(parsedTable)
            UIComponents.Notification(self.ScreenGui, "Table content copied", "success")
        end).LayoutOrder = 1
        
        UIComponents.Button(tableBtnRow, "Copy Call", nil, function()
            local code = ModuleExplorer:GenerateCallingCode(moduleData, contentData)
            copyToClipboard(code)
            UIComponents.Notification(self.ScreenGui, "Calling code copied", "success")
        end).LayoutOrder = 2
        
        UIComponents.Button(tableBtnRow, "Copy Set", nil, function()
            local code = ModuleExplorer:GenerateSetCode(moduleData, contentData, "{}")
            copyToClipboard(code)
            UIComponents.Notification(self.ScreenGui, "Set code copied", "success")
        end).LayoutOrder = 3
        
    else
        
        local valueStr = tostring(contentData.Value)
        
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, 14),
            BackgroundTransparency = 1,
            Text = "Value:",
            TextColor3 = Theme.TextSecondary,
            TextSize = 10,
            Font = Theme.FontFamilyBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 4,
            Parent = self.ModuleDetailsFrame
        })
        
        local valuePreview = createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, math.min(60, 12 * math.max(1, select(2, valueStr:gsub("\n", "")) + 1))),
            BackgroundColor3 = Theme.Background,
            BackgroundTransparency = 0.5,
            Text = valueStr,
            TextColor3 = Theme.Success,
            TextSize = 10,
            Font = Theme.FontFamilyMono,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            LayoutOrder = 5,
            Parent = self.ModuleDetailsFrame
        })
        createCorner(valuePreview, Theme.CornerRadiusSmall)
        createPadding(valuePreview, 6)
        
        
        local valueBtnRow = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            LayoutOrder = 10,
            Parent = self.ModuleDetailsFrame
        })
        createListLayout(valueBtnRow, 4, Enum.FillDirection.Horizontal)
        
        UIComponents.Button(valueBtnRow, "Copy Value", "primary", function()
            copyToClipboard(valueStr)
            UIComponents.Notification(self.ScreenGui, "Value copied", "success")
        end).LayoutOrder = 1
        
        UIComponents.Button(valueBtnRow, "Copy Call", nil, function()
            local code = ModuleExplorer:GenerateCallingCode(moduleData, contentData)
            copyToClipboard(code)
            UIComponents.Notification(self.ScreenGui, "Calling code copied", "success")
        end).LayoutOrder = 2
        
        UIComponents.Button(valueBtnRow, "Copy Set", nil, function()
            local serialized = serializeValue(contentData.Value)
            local code = ModuleExplorer:GenerateSetCode(moduleData, contentData, serialized)
            copyToClipboard(code)
            UIComponents.Notification(self.ScreenGui, "Set code copied", "success")
        end).LayoutOrder = 3
    end
end

function RemoteSpyUI:RefreshRequireList()
    self:RefreshModuleList()
end

function RemoteSpyUI:PopulateRequireFuncsPanel(moduleId)
    
end

function RemoteSpyUI:PopulateRequireArgsPanel(moduleId, funcName)
    
end

function RemoteSpyUI:PopulateRequireDetailsPanel(log)
    
end

local function syncSpyIconButton(button, isSpying, startTip, stopTip)
    if not button then
        return
    end
    local iconFile = isSpying and "pause.png" or "play.png"
    local iconColor = isSpying and Theme.Danger or Theme.Primary
    local tip = isSpying and (stopTip or "Stop Spy") or (startTip or "Start Spy")
    pcall(function()
        button:SetAttribute("IconAccent", isSpying and "danger" or "primary")
    end)
    local iconImage = button:FindFirstChild("IconImage")
    local url = getAssetImage(iconFile)
    if iconImage and url then
        iconImage.Image = url
        iconImage.ImageColor3 = iconColor
        iconImage.Visible = true
    elseif iconImage then
        iconImage.ImageColor3 = iconColor
    end
    local glyph = button:FindFirstChild("Glyph")
    if glyph and glyph:IsA("TextLabel") then
        glyph.Text = isSpying and "||" or ">"
        glyph.TextColor3 = iconColor
        if not (iconImage and iconImage.Visible) then
            glyph.Visible = true
        end
    end
    local tooltipRoot = button:FindFirstChild("Tooltip")
    local tipText = tooltipRoot and tooltipRoot:FindFirstChild("TooltipText")
    if tipText and tipText:IsA("TextLabel") then
        tipText.Text = "  " .. tip .. "  "
        local tipWidth = measureTextWidth(tipText.Text, 11, Theme.FontFamily) + 12
        tooltipRoot.Size = UDim2.new(0, tipWidth, 0, 24)
    end
end

function RemoteSpyUI:_syncRemoteSpyButton()
    syncSpyIconButton(self.RemoteSpyButton, RemoteScanner.IsSpying, "Start Spy", "Stop Spy")
    self:UpdateStatusLabel()
end

function RemoteSpyUI:_syncHttpSpyButton()
    syncSpyIconButton(self.HttpSpyButton, HttpInterceptor.IsSpying, "Start Spy", "Stop Spy")
    self:UpdateStatusLabel()
    self:_updateHttpSpyBanner()
end

function RemoteSpyUI:_ensureHttpSpyActive(showNotice)
    if HttpInterceptor.IsSpying then
        return true
    end
    HttpInterceptor:Start()
    self:_syncHttpSpyButton()
    if showNotice then
        UIComponents.Notification(self.ScreenGui, "HTTP Spy enabled for intercept", "info")
    end
    return true
end

function RemoteSpyUI:_updateHttpSpyBanner()
    if not self.HttpSpyBanner then
        return
    end
    if HttpInterceptor.IsSpying then
        self.HttpSpyBanner.Visible = false
        return
    end
    self.HttpSpyBanner.Visible = true
    local label = self.HttpSpyBanner:FindFirstChild("BannerText")
    if label then
        label.Text = "HTTP Spy is inactive — click Start Spy to log requests."
    end
end

function RemoteSpyUI:_updateHttpCapabilityBanner()
    if not self.HttpCapabilityBanner then
        return
    end
    local hasRequest = HttpInterceptor:HasRequestSupport()
    local hasRequestAsync = HttpInterceptor.HasRequestAsyncApi == true
    if hasRequest and hasRequestAsync then
        self.HttpCapabilityBanner.Visible = false
        return
    end
    self.HttpCapabilityBanner.Visible = true
    local label = self.HttpCapabilityBanner:FindFirstChild("BannerText")
    if label then
        local parts = {"Hooks: HttpGet/HttpPost"}
        if hasRequestAsync then
            table.insert(parts, "RequestAsync")
        end
        if hasRequest then
            table.insert(parts, "request()")
        else
            table.insert(parts, "request() unavailable")
        end
        label.Text = table.concat(parts, " · ")
    end
end

function RemoteSpyUI:_getHttpBadgeStyle(log)
    local badgeText = log.Type
    if log.Type == "Request" or log.Type == "RequestAsync" then
        badgeText = log.Method or "GET"
    end
    
    local badgeColor = Theme.Warning
    if log.Type == "Request" or log.Type == "RequestAsync" then
        badgeColor = Theme.Orange
    elseif log.Type == "HttpPost" or log.Type == "HttpPostAsync" then
        badgeColor = Theme.HttpPost or Theme.Warning
    end
    
    return badgeText, badgeColor
end

function RemoteSpyUI:_buildHttpContextMenu(log)
    local items = {
        {Text = "Copy URL", Callback = function()
            copyToClipboard(log.TamperedUrl or log.Url)
            UIComponents.Notification(self.ScreenGui, "URL copied", "success")
        end},
        {Text = "View Details", Callback = function()
            self:ShowHttpDetailsModal(log)
        end},
    }
    
    if log.Type == "Request" or log.Type == "RequestAsync" then
        local method = log.TamperedMethod or log.Method or "GET"
        table.insert(items, {Text = "Resend " .. method .. "...", Icon = "↻", Callback = function()
            self:ShowResendModal(log)
        end})
    end
    
    if log.FetchedResponse or log.ReturnValue then
        local responseData = log.FetchedResponse or log.ReturnValue
        local responseStr
        if type(responseData) == "table" then
            responseStr = responseData.Body or HttpService:JSONEncode(responseData)
        else
            responseStr = tostring(responseData)
        end
        table.insert(items, {Text = "Copy Response (" .. #responseStr .. ")", Callback = function()
            copyToClipboard(responseStr)
            UIComponents.Notification(self.ScreenGui, "Copied", "success")
        end})
    end
    
    if (log.Type == "Request" or log.Type == "RequestAsync") and log.Body then
        local bodyStr = type(log.Body) == "table" and HttpService:JSONEncode(log.Body) or tostring(log.Body)
        table.insert(items, {Text = "Copy Request Body", Callback = function()
            copyToClipboard(bodyStr)
            UIComponents.Notification(self.ScreenGui, "Body copied", "success")
        end})
    end
    
    if log.Pending then
        table.insert(items, {Separator = true})
        
        local fetchMethod = log.TamperedMethod or log.Method or "GET"
        table.insert(items, {Text = "Send " .. fetchMethod, Callback = function()
            task.spawn(function()
                HttpInterceptor:FetchResponse(log.Id)
                self:QueueHttpRefresh()
            end)
        end})
        
        table.insert(items, {Text = "Accept", Icon = "✓", Callback = function()
            if log.FetchedResponse then
                HttpInterceptor:AcceptResponse(log.Id)
                self:QueueHttpRefresh()
                UIComponents.Notification(self.ScreenGui, "Accepted", "success")
            else
                UIComponents.Notification(self.ScreenGui, "Fetch first", "warning")
            end
        end})
        
        table.insert(items, {Text = "Custom Return...", Callback = function()
            self:ShowCustomReturnModal(log)
        end})
        
        if log.FetchedResponse then
            table.insert(items, {Text = "Edit Response...", Callback = function()
                self:ShowHttpEditModal(log)
            end})
        end
        
        table.insert(items, {Text = "Block", Danger = true, Callback = function()
            HttpInterceptor:BlockRequest(log.Id)
            self:QueueHttpRefresh()
            UIComponents.Notification(self.ScreenGui, "Blocked", "info")
        end})
    end
    
    table.insert(items, {Separator = true})
    local effectiveUrl = log.TamperedUrl or log.Url
    table.insert(items, {
        Text = HttpInterceptor.BlockedUrls[effectiveUrl] and "Unblock URL" or "Block URL",
        Danger = not HttpInterceptor.BlockedUrls[effectiveUrl],
        Callback = function()
            HttpInterceptor:SetUrlBlocked(effectiveUrl, not HttpInterceptor.BlockedUrls[effectiveUrl])
            UIComponents.Notification(self.ScreenGui,
                HttpInterceptor.BlockedUrls[effectiveUrl] and "URL blocked" or "URL unblocked", "info")
        end
    })
    
    return items
end

function RemoteSpyUI:_openHttpContextMenu(log)
    local mousePos = UserInputService:GetMouseLocation()
    UIComponents.ContextMenu(self:_buildHttpContextMenu(log), mousePos, self.ScreenGui)
end

function RemoteSpyUI:CreateHttpTab()
    local tab = createInstance("Frame", {
        Name = "HttpTab",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = self.ContentFrame
    })
    createPadding(tab, 12)
    
    local layout = createListLayout(tab, 10)
    
    
    local toolbar = createPanel(Theme.Radius.Medium, {
        Size = UDim2.new(1, 0, 0, 48),
        ImageColor3 = Theme.BackgroundSecondary,
        LayoutOrder = 1,
        Parent = tab,
    }, true)
    
    local leftToolbar = createInstance("Frame", {
        Size = UDim2.new(0, 220, 0, 36),
        Position = UDim2.new(0, 12, 0.5, -18),
        BackgroundTransparency = 1,
        ZIndex = 2,
        Parent = toolbar
    })
    createListLayout(leftToolbar, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
    
    local interceptToggle, setInterceptState, getInterceptState = UIComponents.Toggle(
        leftToolbar,
        HttpInterceptor.InterceptEnabled,
        function(state)
            if state then
                self:_ensureHttpSpyActive(true)
            end
            HttpInterceptor.InterceptEnabled = state
            self:SaveSettings()
            UIComponents.Notification(self.ScreenGui,
                state and "HTTP Intercept enabled - requests will pause" or "HTTP Intercept disabled",
                state and "warning" or "info")
        end,
        "Intercept"
    )
    interceptToggle.Size = UDim2.new(0, 120, 1, 0)
    interceptToggle.LayoutOrder = 1
    self._setHttpInterceptState = setInterceptState
    
    
    self.HttpPendingLabel = createInstance("TextLabel", {
        Size = UDim2.new(0, 80, 1, 0),
        BackgroundTransparency = 1,
        Text = "0 pending",
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        Font = Theme.FontFamily,
        LayoutOrder = 2,
        Parent = leftToolbar
    })
    
    local rightToolbar = createInstance("Frame", {
        Size = UDim2.new(0, 64, 0, 36),
        Position = UDim2.new(1, -72, 0.5, -18),
        BackgroundTransparency = 1,
        ZIndex = 2,
        Parent = toolbar
    })
    createListLayout(rightToolbar, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
    
    UIComponents.IconButton(rightToolbar, "clear.png", function()
        HttpInterceptor:ClearLogs()
        self:RefreshHttpList()
        UIComponents.Notification(self.ScreenGui, "HTTP logs cleared", "info")
    end, 26, "Clear").LayoutOrder = 1
    
    self.HttpSpyButton = UIComponents.IconButton(rightToolbar, "play.png", function()
        if HttpInterceptor.IsSpying then
            HttpInterceptor:Stop()
        else
            HttpInterceptor:Start()
        end
        self:_syncHttpSpyButton()
        self:SaveSettings()
    end, 26, "Start Spy")
    self.HttpSpyButton.LayoutOrder = 2
    
    self.HttpSpyBanner = createPanel(Theme.Radius.Small, {
        Size = UDim2.new(1, 0, 0, 28),
        ImageColor3 = Theme.WarningMuted,
        ImageTransparency = 0.35,
        LayoutOrder = 2,
        Visible = false,
        Parent = tab,
    }, false)
    createInstance("TextLabel", {
        Name = "BannerText",
        Size = UDim2.new(1, -16, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.Warning,
        TextSize = 11,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
        Parent = self.HttpSpyBanner
    })
    
    self.HttpCapabilityBanner = createPanel(Theme.Radius.Small, {
        Size = UDim2.new(1, 0, 0, 26),
        ImageColor3 = Theme.BackgroundTertiary,
        LayoutOrder = 3,
        Visible = false,
        Parent = tab,
    }, false)
    createInstance("TextLabel", {
        Name = "BannerText",
        Size = UDim2.new(1, -16, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.TextMuted,
        TextSize = 10,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
        Parent = self.HttpCapabilityBanner
    })
    
    local listContainer = createPanel(Theme.Radius.Medium, {
        Size = UDim2.new(1, 0, 1, -100),
        ImageColor3 = Theme.BackgroundSecondary,
        LayoutOrder = 4,
        Parent = tab,
    }, true)
    
    local header = createSquircle(Theme.Radius.Medium, "Squircle-TL-TR", {
        Size = UDim2.new(1, 0, 0, 32),
        ImageColor3 = Theme.BackgroundTertiary,
        ZIndex = 2,
        Parent = listContainer,
    }, false)
    
    createInstance("TextLabel", {
        Size = UDim2.new(0, 50, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = "Time",
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
        Parent = header
    })
    
    createInstance("TextLabel", {
        Size = UDim2.new(0, 50, 1, 0),
        Position = UDim2.new(0, 68, 0, 0),
        BackgroundTransparency = 1,
        Text = "Type",
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
        Parent = header
    })
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, -190, 1, 0),
        Position = UDim2.new(0, 124, 0, 0),
        BackgroundTransparency = 1,
        Text = "URL",
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
        Parent = header
    })
    
    createInstance("TextLabel", {
        Size = UDim2.new(0, 50, 1, 0),
        Position = UDim2.new(1, -62, 0, 0),
        BackgroundTransparency = 1,
        Text = "Status",
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 3,
        Parent = header
    })
    
    local scroll = UIComponents.ScrollFrame(listContainer)
    scroll.Size = UDim2.new(1, 0, 1, -32)
    scroll.Position = UDim2.new(0, 0, 0, 32)
    createPadding(scroll, 6)
    createListLayout(scroll, 3)
    
    self.HttpListFrame = scroll
    self.HttpTab = tab
    
    self:_syncHttpSpyButton()
    self:_updateHttpCapabilityBanner()
    
    local pollGen = self._httpPendingPollGen or 0
    task.spawn(function()
        while pollGen == self._httpPendingPollGen
            and not self._destroying
            and self.ScreenGui and self.ScreenGui.Parent do
            local count = HttpInterceptor:GetPendingCount()
            if self.HttpPendingLabel then
                self.HttpPendingLabel.Text = count .. " pending"
                self.HttpPendingLabel.TextColor3 = count > 0 and Theme.Warning or Theme.TextMuted
            end
            if self._setHttpInterceptState and getInterceptState then
                local interceptOn = getInterceptState()
                if interceptOn and count > 0 and self.HttpPendingLabel then
                    self.HttpPendingLabel.TextColor3 = Theme.Danger
                end
            end
            if count > 0 and self.CurrentTab == "HTTP" and not self._destroying then
                pcall(function()
                    self:UpdateHttpPendingRows()
                end)
            end
            task.wait(0.5)
        end
    end)
end

function RemoteSpyUI:CreateSettingsTab()
    local tab = createInstance("Frame", {
        Name = "SettingsTab",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = self.ContentFrame
    })
    createPadding(tab, 12)
    
    local scroll = UIComponents.ScrollFrame(tab)
    createPadding(scroll, 4)
    createListLayout(scroll, 12)
    
    
    local generalCard = createPanel(Theme.Radius.Medium, {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ImageColor3 = Theme.BackgroundSecondary,
        LayoutOrder = 1,
        Parent = scroll,
    }, true)
    createPadding(generalCard, 14)
    createListLayout(generalCard, 10)
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = "General Settings",
        TextColor3 = Theme.TextPrimary,
        TextSize = 13,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        Parent = generalCard
    })
    
    
    local bypassRow = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Parent = generalCard
    })
    
    local bypassText = createInstance("Frame", {
        Size = UDim2.new(1, -55, 1, 0),
        BackgroundTransparency = 1,
        Parent = bypassRow
    })
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "Return Bypass",
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = bypassText
    })
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "Return cached response when blocking",
        TextColor3 = Theme.TextMuted,
        TextSize = 10,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = bypassText
    })
    
    local bypassToggle = createInstance("Frame", {
        Size = UDim2.new(0, 50, 1, 0),
        Position = UDim2.new(1, -50, 0, 0),
        BackgroundTransparency = 1,
        Parent = bypassRow
    })
    
    UIComponents.Toggle(bypassToggle, RemoteScanner.ReturnBypassEnabled, function(state)
        RemoteScanner.ReturnBypassEnabled = state
        self:SaveSettings()
    end)
    
    
    local maxLogsRow = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        LayoutOrder = 3,
        Parent = generalCard
    })
    
    createInstance("TextLabel", {
        Size = UDim2.new(0.6, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "Max Logs Per Arg Group",
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = maxLogsRow
    })
    
    local maxLogsInputContainer = createInstance("Frame", {
        Size = UDim2.new(0, 102, 0, 26),
        Position = UDim2.new(1, -102, 0.5, -13),
        BackgroundTransparency = 1,
        Parent = maxLogsRow
    })
    
    UIComponents.NumberBox(maxLogsInputContainer, 1, 9999, RemoteScanner.MaxLogsPerArgGroup, 1, function(v)
        RemoteScanner.MaxLogsPerArgGroup = v
        self:SaveSettings()
    end)

    
    local logCapRow = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundTransparency = 1,
        LayoutOrder = 4,
        Parent = generalCard
    })

    local logCapText = createInstance("Frame", {
        Size = UDim2.new(1, -186, 1, 0),
        BackgroundTransparency = 1,
        Parent = logCapRow
    })

    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "Max Stored Logs",
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = logCapText
    })

    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "0-1999 on track; drag past mark to confirm infinite",
        TextColor3 = Theme.TextMuted,
        TextSize = 10,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = logCapText
    })

    local logCapSliderContainer = createInstance("Frame", {
        Size = UDim2.new(0, 176, 0, 24),
        Position = UDim2.new(1, -176, 0.5, -12),
        BackgroundTransparency = 1,
        Parent = logCapRow
    })

    UIComponents.Slider(logCapSliderContainer, LOG_CAP_MIN, LOG_CAP_MAX, getLogCapSliderValue(), 1, function(v)
        applyLogCapLimit(decodeLogCapLimit(v))
        self:SaveSettings()
    end, formatLogCapLimit, 56, {
        frictionValue = LOG_CAP_INFINITE - 1,
        confirmValue = LOG_CAP_INFINITE,
        frictionAlpha = 0.9,
        confirmAlpha = 0.97,
    })

    
    local delayRow = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundTransparency = 1,
        LayoutOrder = 5,
        Parent = generalCard
    })
    
    local delayText = createInstance("Frame", {
        Size = UDim2.new(1, -170, 1, 0),
        BackgroundTransparency = 1,
        Parent = delayRow
    })
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "Log Update Delay",
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = delayText
    })
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "Delay between log UI updates (0-1s)",
        TextColor3 = Theme.TextMuted,
        TextSize = 10,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = delayText
    })
    
    local delaySliderContainer = createInstance("Frame", {
        Size = UDim2.new(0, 160, 0, 24),
        Position = UDim2.new(1, -160, 0.5, -12),
        BackgroundTransparency = 1,
        Parent = delayRow
    })
    
    UIComponents.Slider(delaySliderContainer, 0, 1, self.PendingUpdateDelay or 0, 0.01, function(v)
        self.PendingUpdateDelay = v
        self:SaveSettings()
    end, function(v)
        return string.format("%.2fs", v)
    end)
    
    
    local textSizeRow = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundTransparency = 1,
        LayoutOrder = 6,
        Parent = generalCard
    })
    
    local textSizeText = createInstance("Frame", {
        Size = UDim2.new(1, -170, 1, 0),
        BackgroundTransparency = 1,
        Parent = textSizeRow
    })
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "Text Size",
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = textSizeText
    })
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "Scale text size (50% - 150%)",
        TextColor3 = Theme.TextMuted,
        TextSize = 10,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = textSizeText
    })
    
    local textSizeSliderContainer = createInstance("Frame", {
        Size = UDim2.new(0, 160, 0, 24),
        Position = UDim2.new(1, -160, 0.5, -12),
        BackgroundTransparency = 1,
        Parent = textSizeRow
    })
    
    UIComponents.Slider(textSizeSliderContainer, 0.5, 1.5, self.TextScale or 1.0, 0.05, function(v)
        self.TextScale = v
        self:UpdateTextScale()
        self:SaveSettings()
    end, function(v)
        return string.format("%d%%", math.floor(v * 100 + 0.5))
    end)
    
    
    local uiScaleRow = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundTransparency = 1,
        LayoutOrder = 7,
        Parent = generalCard
    })
    
    local uiScaleText = createInstance("Frame", {
        Size = UDim2.new(1, -120, 1, 0),
        BackgroundTransparency = 1,
        Parent = uiScaleRow
    })
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "UI Scale",
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = uiScaleText
    })
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "Scale UI elements (50% - 200%)",
        TextColor3 = Theme.TextMuted,
        TextSize = 10,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = uiScaleText
    })
    
    local uiScaleInputContainer = createInstance("Frame", {
        Size = UDim2.new(0, 102, 0, 26),
        Position = UDim2.new(1, -102, 0.5, -13),
        BackgroundTransparency = 1,
        Parent = uiScaleRow
    })
    
    UIComponents.NumberBox(uiScaleInputContainer, 50, 200, math.floor((self.UIScale or 1.0) * 100 + 0.5), 10, function(v)
        local newScale = v / 100
        local oldScale = self.UIScale or 1.0
        
        
        local currentSize = self.MainFrame.Size
        local visualW = currentSize.X.Offset * oldScale
        local visualH = currentSize.Y.Offset * oldScale
        self.UIScale = newScale
        if self.UIScaleInstance then
            self.UIScaleInstance.Scale = newScale
        end
        local newW, newH = self:ClampWindowSize(
            math.floor(visualW / newScale + 0.5),
            math.floor(visualH / newScale + 0.5)
        )
        self.MainFrame.Size = UDim2.new(0, newW, 0, newH)
        self:SaveWindowGeometry()
    end, function(v)
        return tostring(v) .. "%"
    end)
    
    local remoteAutoStartRow = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        LayoutOrder = 8,
        Parent = generalCard
    })

    local remoteAutoStartText = createInstance("Frame", {
        Size = UDim2.new(1, -55, 1, 0),
        BackgroundTransparency = 1,
        Parent = remoteAutoStartRow
    })

    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "Auto-start Remote Spy",
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = remoteAutoStartText
    })

    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "Start remote logging when the tool finishes startup scan",
        TextColor3 = Theme.TextMuted,
        TextSize = 10,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = remoteAutoStartText
    })

    local remoteAutoStartToggle = createInstance("Frame", {
        Size = UDim2.new(0, 50, 1, 0),
        Position = UDim2.new(1, -50, 0, 0),
        BackgroundTransparency = 1,
        Parent = remoteAutoStartRow
    })

    UIComponents.Toggle(remoteAutoStartToggle, self.RemoteAutoStartSpy, function(state)
        self.RemoteAutoStartSpy = state
        if state and not RemoteScanner.IsSpying then
            pcall(function()
                RemoteScanner:StartSpying()
            end)
            self:_syncRemoteSpyButton()
        end
        self:SaveSettings()
    end)

    local httpAutoStartRow = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        LayoutOrder = 9,
        Parent = generalCard
    })
    
    local httpAutoStartText = createInstance("Frame", {
        Size = UDim2.new(1, -55, 1, 0),
        BackgroundTransparency = 1,
        Parent = httpAutoStartRow
    })
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "Auto-start HTTP Spy",
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = httpAutoStartText
    })
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "Start HTTP logging when the tool finishes startup scan",
        TextColor3 = Theme.TextMuted,
        TextSize = 10,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = httpAutoStartText
    })
    
    local httpAutoStartToggle = createInstance("Frame", {
        Size = UDim2.new(0, 50, 1, 0),
        Position = UDim2.new(1, -50, 0, 0),
        BackgroundTransparency = 1,
        Parent = httpAutoStartRow
    })
    
    UIComponents.Toggle(httpAutoStartToggle, self.HttpAutoStartSpy, function(state)
        self.HttpAutoStartSpy = state
        if state and not HttpInterceptor.IsSpying then
            HttpInterceptor:Start()
            self:_syncHttpSpyButton()
        end
        self:SaveSettings()
    end)
    
    
    local blockedCard = createPanel(Theme.Radius.Medium, {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ImageColor3 = Theme.BackgroundSecondary,
        LayoutOrder = 2,
        Parent = scroll,
    }, true)
    createPadding(blockedCard, 14)
    createListLayout(blockedCard, 6)
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = "Blocked/Ignored Items",
        TextColor3 = Theme.TextPrimary,
        TextSize = 13,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        Parent = blockedCard
    })
    
    self.BlockedListFrame = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 80),
        BackgroundColor3 = Theme.Background,
        LayoutOrder = 2,
        Parent = blockedCard
    })
    createCorner(self.BlockedListFrame, Theme.CornerRadiusSmall)
    
    local blockedScroll = UIComponents.ScrollFrame(self.BlockedListFrame)
    createPadding(blockedScroll, 6)
    createListLayout(blockedScroll, 3)
    
    self.BlockedItemsScroll = blockedScroll
    
    
    local aboutCard = createPanel(Theme.Radius.Medium, {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ImageColor3 = Theme.BackgroundSecondary,
        LayoutOrder = 3,
        Parent = scroll,
    }, true)
    createPadding(aboutCard, 14)
    createListLayout(aboutCard, 6)
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = "About",
        TextColor3 = Theme.TextPrimary,
        TextSize = 13,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        Parent = aboutCard
    })
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = "Spy Tool - Advanced in every way.\nMade by Pro Bacon\n\nFeature:\n- Organised grouping\n- Sorting\n- Remote Spy\n- HTTP Spy\n- Ignore/Block\n- Per-tab spy controls",
        TextColor3 = Theme.TextSecondary,
        TextSize = 11,
        Font = Theme.FontFamily,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 2,
        Parent = aboutCard
    })
    
    self.SettingsTab = tab
end

function RemoteSpyUI:UpdateStatusLabel()
    local remoteSpy = RemoteScanner.IsSpying
    local httpSpy = HttpInterceptor.IsSpying
    
    if remoteSpy and httpSpy then
        self.StatusLabel.Text = "Spying (All)"
        self.StatusLabel.TextColor3 = Theme.Success
    elseif remoteSpy then
        self.StatusLabel.Text = "Spying (Remotes)"
        self.StatusLabel.TextColor3 = Theme.Success
    elseif httpSpy then
        self.StatusLabel.Text = "Spying (HTTP)"
        self.StatusLabel.TextColor3 = Theme.Cyan
    else
        self.StatusLabel.Text = "Ready"
        self.StatusLabel.TextColor3 = Theme.TextMuted
    end
end

function RemoteSpyUI:SwitchTab(tabName)
    
    for name, btn in pairs(self.NavButtons) do
        local isActive = name == tabName
        if isSquircle(btn) then
            tween(btn, {ImageTransparency = isActive and 0 or 1}, 0.15)
        else
            tween(btn, {BackgroundTransparency = isActive and 0 or 1}, 0.15)
        end
        local iconColor = isActive and Theme.Primary or Theme.TextMuted
        for _, child in ipairs(btn:GetChildren()) do
            local role = child:GetAttribute("NavRole")
            if child:IsA("ImageLabel") and role == "icon" then
                child.ImageColor3 = iconColor
            elseif child:IsA("TextLabel") and role == "icon" then
                child.TextColor3 = iconColor
            elseif child:IsA("TextLabel") then
                if role == "hint" then
                    child.TextColor3 = Theme.TextMuted
                elseif role == "title" then
                    child.TextColor3 = isActive and Theme.TextPrimary or Theme.TextSecondary
                end
            end
        end
    end
    
    
    self.RemotesTab.Visible = tabName == "Remotes"
    self.RequireTab.Visible = tabName == "Modules"
    self.HttpTab.Visible = tabName == "HTTP"
    self.SettingsTab.Visible = tabName == "Settings"
    
    self.CurrentTab = tabName
    
    
    if tabName == "Remotes" then
        self._remoteDirty = false
        self:_syncRemoteSpyButton()
        self:RefreshRemoteList()
    elseif tabName == "Modules" then
        self:RefreshModuleList()
    elseif tabName == "HTTP" then
        self._httpDirty = false
        
        self:_syncHttpSpyButton()
        self:_updateHttpSpyBanner()
        self:_updateHttpCapabilityBanner()
        if self._setHttpInterceptState then
            self._setHttpInterceptState(HttpInterceptor.InterceptEnabled)
        end
        self:RefreshHttpList()
    elseif tabName == "Settings" then
        self:RefreshBlockedList()
    end
end

function RemoteSpyUI:_collectVisibleRemoteGroups()
    local sortedGroups = RemoteScanner:GetSortedGroups()
    local visible = {}
    local order = 0
    
    for _, groupData in ipairs(sortedGroups) do
        local path = groupData.Path
        local group = groupData.Group
        local info = group.Info
        
        if not info then continue end
        
        local baseType = info.Type:gsub(" %(Incoming%)", "")
        if not self.TypeFilters[baseType] then continue end
        
        
        
        if self.SearchFilter ~= "" then
            local searchMatch = info.Name:lower():find(self.SearchFilter, 1, true) or
                               path:lower():find(self.SearchFilter, 1, true)
            if not searchMatch then continue end
        end
        
        order = order + 1
        visible[path] = {
            Path = path,
            Group = group,
            Order = order,
        }
    end
    
    return visible
end

local function isRemoteListEntry(child)
    return child and (child:IsA("ImageButton") or child:IsA("TextButton")) and child:GetAttribute("RemotePath") ~= nil
end

local function isArgListEntry(child)
    return child and (child:IsA("ImageButton") or child:IsA("TextButton")) and child:GetAttribute("ArgSelectKey") ~= nil
end

function RemoteSpyUI:_findRemoteEntry(path)
    self._remoteEntryMap = self._remoteEntryMap or {}
    local cached = self._remoteEntryMap[path]
    if cached and cached.Parent then
        return cached
    end
    for _, child in ipairs(self.RemoteListFrame:GetChildren()) do
        if isRemoteListEntry(child) and child:GetAttribute("RemotePath") == path then
            self._remoteEntryMap[path] = child
            return child
        end
    end
    self._remoteEntryMap[path] = nil
    return nil
end

function RemoteSpyUI:_registerRemoteEntry(path, entry)
    self._remoteEntryMap = self._remoteEntryMap or {}
    self._remoteEntryMap[path] = entry
end

function RemoteSpyUI:_unregisterRemoteEntry(path)
    if self._remoteEntryMap then
        self._remoteEntryMap[path] = nil
    end
end

function RemoteSpyUI:_findArgEntry(selectKey)
    local cached = self._argEntryMap and self._argEntryMap[selectKey]
    if cached and cached.Parent then
        return cached
    end
    if not self.ArgsListFrame then
        return nil
    end
    for _, child in ipairs(self.ArgsListFrame:GetChildren()) do
        if isArgListEntry(child) and child:GetAttribute("ArgSelectKey") == selectKey then
            if self._argEntryMap then
                self._argEntryMap[selectKey] = child
            end
            return child
        end
    end
    return nil
end

function RemoteSpyUI:_getArgsPanelStructureSig(path, sortedArgGroups)
    local hashes = {}
    for i, argData in ipairs(sortedArgGroups) do
        hashes[i] = argData.ArgGroup.ArgHash
    end
    return path .. "|" .. table.concat(hashes, ";")
end

function RemoteSpyUI:_setEntryVisualState(entry, stateKey, applyFn)
    if entry:GetAttribute("VisualState") == stateKey then
        return
    end
    entry:SetAttribute("VisualState", stateKey)
    applyFn()
end

function RemoteSpyUI:_getLogArgDisplayText(log, index, arg)
    local snapshot = log.CachedArguments and log.CachedArguments[index]
    if snapshot then
        return getArgDisplayFromSnapshot(snapshot, arg)
    end
    log._DisplayCache = log._DisplayCache or {}
    if log._DisplayCache[index] then
        return log._DisplayCache[index]
    end
    local displayText = getArgDisplayFromSnapshot(nil, arg)
    log._DisplayCache[index] = displayText
    return displayText
end

function RemoteSpyUI:_lightRefreshArgsPanel(group, sortedArgGroups)
    local path = group.Info.Path
    if self.ArgsTitle then
        self.ArgsTitle.Text = "Call patterns (" .. tostring(#sortedArgGroups) .. ")"
    end
    
    for _, argData in ipairs(sortedArgGroups) do
        local argGroup = argData.ArgGroup
        local selectKey = path .. "|" .. argGroup.ArgHash
        local entry = self:_findArgEntry(selectKey)
        if entry then
            local countLabel = entry:FindFirstChild("ArgCallCount")
            if countLabel then
                local newText = "x" .. tostring(argGroup.Count)
                if countLabel.Text ~= newText then
                    countLabel.Text = newText
                end
            end
        end
    end
    
    if self.SelectedArgKey and self._detailsLogId and self.DetailsTitle and self.DetailsTitle.Parent then
        local remotePath, argHash = self.SelectedArgKey:match("^(.-)|([^|]+)$")
        if remotePath and argHash then
            local argGroup = group.ArgGroups[argHash]
            if argGroup and argGroup.Logs[1] and argGroup.Logs[1].Id == self._detailsLogId then
                local totalLabel = self.DetailsTitle.Parent:FindFirstChild("CallCountBadge")
                if totalLabel then
                    totalLabel.Text = "Calls: " .. tostring(argGroup.Count)
                end
            end
        end
    end
end

function RemoteSpyUI:_getRemoteRestTransparency(path)
    if self.SelectedRemotePath == path then
        return 0.7
    end
    if RemoteScanner.IgnoredInstances[path] then
        return 0.7
    end
    if RemoteScanner.BlockedInstances[path] then
        return 0.5
    end
    return 1
end

function RemoteSpyUI:_getArgRestTransparency(remotePath, argHash)
    local selectKey = remotePath .. "|" .. argHash
    if self.SelectedArgKey == selectKey then
        return 0.7
    end
    if RemoteScanner.BlockedArgs[remotePath] and RemoteScanner.BlockedArgs[remotePath][argHash] then
        return 0.3
    end
    if RemoteScanner.IgnoredArgs[remotePath] and RemoteScanner.IgnoredArgs[remotePath][argHash] then
        return 0.5
    end
    return 0.8
end

function RemoteSpyUI:_applyRemoteEntryVisual(entry, path)
    local isSelected = self.SelectedRemotePath == path
    local isIgnored = RemoteScanner.IgnoredInstances[path]
    local isBlocked = RemoteScanner.BlockedInstances[path]
    local stateKey = (isBlocked and "B" or "") .. (isIgnored and "I" or "") .. (isSelected and "S" or "") .. "R"
    
    self:_setEntryVisualState(entry, stateKey, function()
        setSurfaceColor(entry, isSelected and Theme.Primary or Theme.BackgroundTertiary)
        if not entry:GetAttribute("IsHovered") then
            setSurfaceTransparency(entry, self:_getRemoteRestTransparency(path))
        end
        
        if isBlocked then
            setSquircleOutline(entry, Theme.Danger, true)
        elseif isIgnored then
            setSquircleOutline(entry, Theme.Warning, true)
        elseif isSelected then
            
            setSquircleOutline(entry, nil, false)
        else
            setSquircleOutline(entry, nil, false)
        end
    end)
end

function RemoteSpyUI:_updateRemoteEntry(entry, group, order)
    local path = group.Info.Path
    if entry.LayoutOrder ~= order then
        entry.LayoutOrder = order
    end
    
    local countLabel = entry:FindFirstChild("CallCount")
    if countLabel then
        local newText = tostring(group.TotalCalls)
        if countLabel.Text ~= newText then
            countLabel.Text = newText
            countLabel.TextColor3 = group.TotalCalls > 0 and Theme.Success or Theme.TextMuted
        end
    end
    
    self:_applyRemoteEntryVisual(entry, path)
end

function RemoteSpyUI:_applyArgEntryVisual(entry, remotePath, argHash)
    local selectKey = remotePath .. "|" .. argHash
    local isSelected = self.SelectedArgKey == selectKey
    local isArgsBlocked = RemoteScanner.BlockedArgs[remotePath] and RemoteScanner.BlockedArgs[remotePath][argHash]
    local isArgsIgnored = RemoteScanner.IgnoredArgs[remotePath] and RemoteScanner.IgnoredArgs[remotePath][argHash]
    local stateKey = (isArgsBlocked and "B" or "") .. (isArgsIgnored and "I" or "") .. (isSelected and "S" or "") .. "A"
    
    self:_setEntryVisualState(entry, stateKey, function()
        setSurfaceColor(entry, isSelected and Theme.Primary or Theme.BackgroundTertiary)
        if not entry:GetAttribute("IsHovered") then
            setSurfaceTransparency(entry, self:_getArgRestTransparency(remotePath, argHash))
        end
        
        if isArgsBlocked then
            setSquircleOutline(entry, Theme.Danger, true)
        elseif isArgsIgnored then
            setSquircleOutline(entry, Theme.Warning, true)
        else
            setSquircleOutline(entry, nil, false)
        end
    end)
end

function RemoteSpyUI:_updateArgEntry(entry, remotePath, argGroup, order)
    if entry.LayoutOrder ~= order then
        entry.LayoutOrder = order
    end
    
    local countLabel = entry:FindFirstChild("ArgCallCount")
    if countLabel then
        local newText = "x" .. tostring(argGroup.Count)
        if countLabel.Text ~= newText then
            countLabel.Text = newText
        end
    end
    
    self:_applyArgEntryVisual(entry, remotePath, argGroup.ArgHash)
end

function RemoteSpyUI:SelectRemoteGroup(path, group)
    self.SelectedRemotePath = path
    self.SelectedRemoteGroup = group
    self.SelectedArgKey = nil
    self.SelectedArgGroup = nil
    self._detailsLogId = nil
    self:ShowInspectorActiveState()
    self:_syncRemoteDirectionChipVisuals(path)
    
    for _, child in ipairs(self.RemoteListFrame:GetChildren()) do
        if isRemoteListEntry(child) then
            local entryPath = child:GetAttribute("RemotePath")
            if entryPath then
                self:_applyRemoteEntryVisual(child, entryPath)
            end
        end
    end
    
    self:UpdateInspectorChrome()
    
    task.defer(function()
        if self.SelectedRemotePath ~= path then
            return
        end
        self._lastArgsPanelSig = nil
        self:IncrementalRefreshArgsPanel(group, true)
        self:ShowRemoteDetails(group)
        self:UpdateInspectorChrome()
    end)
end

function RemoteSpyUI:SelectArgGroup(selectKey, argGroup, remoteGroup)
    self.SelectedArgKey = selectKey
    self.SelectedArgGroup = argGroup
    if remoteGroup then
        self.SelectedRemoteGroup = remoteGroup
    end
    
    for _, child in ipairs(self.ArgsListFrame:GetChildren()) do
        if isArgListEntry(child) then
            local key = child:GetAttribute("ArgSelectKey")
            if key then
                local remotePath = child:GetAttribute("RemotePath")
                local argHash = child:GetAttribute("ArgHash")
                if remotePath and argHash then
                    self:_applyArgEntryVisual(child, remotePath, argHash)
                end
            end
        end
    end
    
    self:UpdateInspectorChrome()
    
    if argGroup.Logs[1] then
        local log = argGroup.Logs[1]
        task.defer(function()
            if self.SelectedArgKey ~= selectKey then
                return
            end
            if self._detailsLogId ~= log.Id then
                self:ShowLogDetails(log)
            end
            self:UpdateInspectorChrome()
        end)
    end
end

function RemoteSpyUI:IncrementalRefreshRemoteList()
    local visibleGroups = self:_collectVisibleRemoteGroups()
    
    for path, data in pairs(visibleGroups) do
        local entry = self:_findRemoteEntry(path)
        if entry then
            self:_updateRemoteEntry(entry, data.Group, data.Order)
        else
            self:CreateRemoteGroupEntry(data.Group, data.Order)
        end
    end
    
    for _, child in ipairs(self.RemoteListFrame:GetChildren()) do
        if isRemoteListEntry(child) then
            local path = child:GetAttribute("RemotePath")
            if path and not visibleGroups[path] then
                self:_unregisterRemoteEntry(path)
                child:Destroy()
            end
        end
    end
end

function RemoteSpyUI:IncrementalRefreshArgsPanel(group, forceFull)
    if not group or not self.ArgsListFrame then
        return
    end
    
    local path = group.Info.Path
    local dirMode = self:_getRemoteDirectionMode(path)
    local sortedArgGroups = RemoteScanner:GetSortedArgGroups(path)
    local filteredArgGroups = {}
    for _, argData in ipairs(sortedArgGroups) do
        local argGroup = argData.ArgGroup
        local show = true
        if dirMode == "Outgoing" then
            show = argGroup.HasOutgoing == true
        elseif dirMode == "Incoming" then
            show = argGroup.HasIncoming == true
        end
        if show then
            filteredArgGroups[#filteredArgGroups + 1] = argData
        end
    end
    sortedArgGroups = filteredArgGroups

    local maxVisible = 50
    local visibleCount = math.min(#sortedArgGroups, maxVisible)
    local structureSig = self:_getArgsPanelStructureSig(path, sortedArgGroups) .. "|D:" .. tostring(dirMode)
    
    if not forceFull and self._lastArgsPanelSig == structureSig then
        self:_lightRefreshArgsPanel(group, sortedArgGroups)
        return
    end
    self._lastArgsPanelSig = structureSig
    
    if self.ArgsTitle then
        self.ArgsTitle.Text = "Call patterns (" .. tostring(#sortedArgGroups) .. ")"
    end
    self:UpdateInspectorChrome()
    
    local emptyPatternText = "No calls yet — start spy or fire this remote"
    if #sortedArgGroups == 0 then
        local hasEmptyLabel = false
        for _, child in ipairs(self.ArgsListFrame:GetChildren()) do
            if child:IsA("TextLabel") and child:GetAttribute("EmptyPatterns") then
                hasEmptyLabel = true
            elseif isArgListEntry(child) or child:IsA("Frame") then
                child:Destroy()
            end
        end
        if not hasEmptyLabel then
            local emptyLabel = createInstance("TextLabel", {
                Size = UDim2.new(1, 0, 0, 36),
                BackgroundTransparency = 1,
                Text = emptyPatternText,
                TextColor3 = Theme.TextMuted,
                TextSize = 11,
                Font = Theme.FontFamily,
                TextWrapped = true,
                LayoutOrder = 1,
                Parent = self.ArgsListFrame
            })
            emptyLabel:SetAttribute("EmptyPatterns", true)
        end
        return
    end
    
    for _, child in ipairs(self.ArgsListFrame:GetChildren()) do
        if child:IsA("TextLabel") and child:GetAttribute("EmptyPatterns") then
            child:Destroy()
        end
    end
    
    local visibleKeys = {}
    for i = 1, visibleCount do
        local argData = sortedArgGroups[i]
        local argGroup = argData.ArgGroup
        local selectKey = path .. "|" .. argGroup.ArgHash
        visibleKeys[selectKey] = {
            ArgGroup = argGroup,
            Order = i,
        }
        
        local entry = self:_findArgEntry(selectKey)
        if entry then
            self:_updateArgEntry(entry, path, argGroup, i)
        else
            self:CreateArgGroupEntryInPanel(path, argGroup, i, group)
        end
    end
    
    for _, child in ipairs(self.ArgsListFrame:GetChildren()) do
        if isArgListEntry(child) then
            local key = child:GetAttribute("ArgSelectKey")
            if key and not visibleKeys[key] then
                if self._argEntryMap then
                    self._argEntryMap[key] = nil
                end
                child:Destroy()
            end
        end
    end
    
    local overflowLabel = self.ArgsListFrame:FindFirstChild("ArgsOverflowLabel")
    if #sortedArgGroups > maxVisible then
        if not overflowLabel then
            overflowLabel = createInstance("TextLabel", {
                Name = "ArgsOverflowLabel",
                Size = UDim2.new(1, 0, 0, 22),
                BackgroundTransparency = 1,
                Text = "",
                TextColor3 = Theme.TextMuted,
                TextSize = 10,
                Font = Theme.FontFamily,
                LayoutOrder = maxVisible + 1,
                Parent = self.ArgsListFrame
            })
        end
        overflowLabel.Text = "+" .. (#sortedArgGroups - maxVisible) .. " more arg groups (narrow calls or clear logs)"
        overflowLabel.LayoutOrder = maxVisible + 1
    elseif overflowLabel then
        overflowLabel:Destroy()
    end
end

function RemoteSpyUI:RefreshRemoteList(forceFull)
    self:SyncScannerFilters()
    
    if not forceFull and RemoteScanner.IsSpying then
        self:IncrementalRefreshRemoteList()
        if self.SelectedRemotePath then
            local group = RemoteScanner.GroupedLogs[self.SelectedRemotePath]
            if group then
                local argsForceFull = forceFull
                if not argsForceFull and RemoteScanner.SortMode == "calls" then
                    local now = tick()
                    self._argsResortNext = self._argsResortNext or 0
                    if now >= self._argsResortNext then
                        self._argsResortNext = now + 0.5
                        self._lastArgsPanelSig = nil
                        argsForceFull = true
                    end
                end
                self:IncrementalRefreshArgsPanel(group, argsForceFull)
            end
        end
        return
    end
    
    
    self._remoteEntryMap = {}
    for _, child in ipairs(self.RemoteListFrame:GetChildren()) do
        if isRemoteListEntry(child) or child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local sortedGroups = RemoteScanner:GetSortedGroups()
    local order = 0
    
    for _, groupData in ipairs(sortedGroups) do
        local path = groupData.Path
        local group = groupData.Group
        local info = group.Info
        
        if not info then continue end
        
        
        local baseType = info.Type:gsub(" %(Incoming%)", "")
        if not self.TypeFilters[baseType] then continue end
        
        
        
        
        if self.SearchFilter ~= "" then
            local searchMatch = info.Name:lower():find(self.SearchFilter, 1, true) or
                               path:lower():find(self.SearchFilter, 1, true)
            if not searchMatch then continue end
        end
        
        order = order + 1
        self:CreateRemoteGroupEntry(group, order)
    end
end
function RemoteSpyUI:CreateRemoteGroupEntry(group, order)
    local info = group.Info
    local path = info.Path
    local isIgnored = RemoteScanner.IgnoredInstances[path]
    local isBlocked = RemoteScanner.BlockedInstances[path]
    local isSelected = self.SelectedRemotePath == path
    local restTransparency = isSelected and 0.7 or (isIgnored and 0.7 or (isBlocked and 0.5 or 1))

    
    for _, child in ipairs(self.RemoteListFrame:GetChildren()) do
        if isRemoteListEntry(child) and child:GetAttribute("RemotePath") == path then
            child:Destroy()
        end
    end
    self:_unregisterRemoteEntry(path)
    
    
    local header = createSquircle(Theme.Radius.Small, "Squircle", {
        Size = UDim2.new(1, 0, 0, 30),
        ImageColor3 = isSelected and Theme.Primary or Theme.BackgroundTertiary,
        ImageTransparency = restTransparency,
        LayoutOrder = order,
        Parent = self.RemoteListFrame,
    }, true)
    
    if isBlocked then
        setSquircleOutline(header, Theme.Danger, true)
    elseif isIgnored then
        setSquircleOutline(header, Theme.Warning, true)
    else
        setSquircleOutline(header, nil, false)
    end
    
    
    local hasIncoming = group.HasIncomingLogs == true
    local hasOutgoing = group.HasOutgoingLogs == true
    
    createTypeIcon(header, info.Type, 18, UDim2.new(0, 6, 0.5, 0))

    local dirIndicator = ""
    local dirColor = Theme.TextMuted
    if hasIncoming and hasOutgoing then
        dirIndicator = "⇅"
        dirColor = Theme.Purple
    elseif hasIncoming then
        dirIndicator = "▼"
        dirColor = Theme.Cyan
    elseif hasOutgoing then
        dirIndicator = "▲"
        dirColor = Theme.Success
    end
    if dirIndicator ~= "" then
        createInstance("TextLabel", {
            Name = "DirIndicator",
            Size = UDim2.new(0, 12, 1, 0),
            Position = UDim2.new(0, 26, 0, 0),
            BackgroundTransparency = 1,
            Text = dirIndicator,
            TextColor3 = dirColor,
            TextSize = 10,
            Font = Theme.FontFamilyBold,
            ZIndex = 2,
            Parent = header,
        })
    end
    
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, -100, 1, 0),
        Position = UDim2.new(0, dirIndicator ~= "" and 40 or 28, 0, 0),
        BackgroundTransparency = 1,
        Text = info.Name,
        TextColor3 = isIgnored and Theme.TextMuted or Theme.TextPrimary,
        TextSize = 11,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 2,
        Parent = header
    })
    
    
    createInstance("TextLabel", {
        Name = "CallCount",
        Size = UDim2.new(0, 40, 1, 0),
        Position = UDim2.new(1, -50, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(group.TotalCalls),
        TextColor3 = group.TotalCalls > 0 and Theme.Success or Theme.TextMuted,
        TextSize = 11,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 2,
        Parent = header
    })
    
    header:SetAttribute("IsHovered", false)
    header:SetAttribute("RemotePath", path)
    self:_registerRemoteEntry(path, header)
    
    
    header.MouseEnter:Connect(function()
        header:SetAttribute("IsHovered", true)
        if self.SelectedRemotePath ~= path then
            tween(header, {ImageTransparency = 0}, 0.1)
        end
    end)
    
    header.MouseLeave:Connect(function()
        header:SetAttribute("IsHovered", false)
        if self.SelectedRemotePath ~= path then
            tween(header, {ImageTransparency = self:_getRemoteRestTransparency(path)}, 0.1)
        end
    end)
    
    
    header.MouseButton1Click:Connect(function()
        self:SelectRemoteGroup(path, group)
    end)
    
    
    header.MouseButton2Click:Connect(function()
        local mousePos = UserInputService:GetMouseLocation()
        UIComponents.ContextMenu({
            {Text = "Copy Path", Callback = function()
                copyToClipboard(formatRobloxPath(path))
                UIComponents.Notification(self.ScreenGui, "Path copied", "success")
            end},
            {Text = "Copy Fire Script", Callback = function()
                local firstLog = self:GetFirstLogFromGroup(group)
                if firstLog then
                    local script = RemoteScanner:GenerateFireScript(firstLog)
                    copyToClipboard(script)
                    UIComponents.Notification(self.ScreenGui, "Fire script copied", "success")
                else
                    UIComponents.Notification(self.ScreenGui, "No logs available", "warning")
                end
            end},
            {Text = "Copy Intercept Script", Callback = function()
                local firstLog = self:GetFirstLogFromGroup(group)
                if firstLog then
                    local script = RemoteScanner:GenerateInterceptScript(firstLog)
                    copyToClipboard(script)
                    UIComponents.Notification(self.ScreenGui, "Intercept script copied", "success")
                end
            end},
            {Separator = true},
            {Text = isIgnored and "Stop Ignoring" or "Ignore Instance", Callback = function()
                RemoteScanner:SetIgnoreInstance(path, not isIgnored)
                self:RefreshRemoteList(true)
            end},
            {Text = isBlocked and "Unblock Instance" or "Block Instance", Danger = not isBlocked, Callback = function()
                RemoteScanner:SetBlockInstance(path, not isBlocked)
                self:RefreshRemoteList(true)
            end},
            {Separator = true},
            {Text = "Clear Logs", Callback = function()
                RemoteScanner:ClearLogsForRemote(path)
                self:RefreshRemoteList(true)
            end},
        }, mousePos, self.ScreenGui)
    end)
end

function RemoteSpyUI:PopulateArgsPanel(group)
    self._lastArgsPanelSig = nil
    self._argEntryMap = {}
    if self.ArgsListFrame then
        for _, child in ipairs(self.ArgsListFrame:GetChildren()) do
            if isArgListEntry(child) or (child:IsA("TextLabel") and child:GetAttribute("EmptyPatterns")) then
                child:Destroy()
            end
        end
    end
    self:IncrementalRefreshArgsPanel(group, true)
end

function RemoteSpyUI:CreateArgGroupEntryInPanel(remotePath, argGroup, order, remoteGroup)
    local argHash = argGroup.ArgHash
    local selectKey = remotePath .. "|" .. argHash
    local isArgsBlocked = RemoteScanner.BlockedArgs[remotePath] and RemoteScanner.BlockedArgs[remotePath][argHash]
    local isArgsIgnored = RemoteScanner.IgnoredArgs[remotePath] and RemoteScanner.IgnoredArgs[remotePath][argHash]
    local isSelected = self.SelectedArgKey == selectKey
    local restTransparency = isSelected and 0.7 or (isArgsBlocked and 0.3 or (isArgsIgnored and 0.5 or 0.8))

    for _, child in ipairs(self.ArgsListFrame:GetChildren()) do
        if isArgListEntry(child) and child:GetAttribute("ArgSelectKey") == selectKey then
            child:Destroy()
        end
    end
    if self._argEntryMap then
        self._argEntryMap[selectKey] = nil
    end
    
    
    local header = createSquircle(Theme.Radius.Small, "Squircle", {
        Size = UDim2.new(1, 0, 0, 28),
        ImageColor3 = isSelected and Theme.Primary or Theme.BackgroundTertiary,
        ImageTransparency = restTransparency,
        LayoutOrder = order,
        Parent = self.ArgsListFrame,
    }, true)
    
    if isArgsBlocked then
        setSquircleOutline(header, Theme.Danger, true)
    elseif isArgsIgnored then
        setSquircleOutline(header, Theme.Warning, true)
    else
        setSquircleOutline(header, nil, false)
    end
    
    local argHasIncoming = argGroup.HasIncoming
    local argHasOutgoing = argGroup.HasOutgoing
    
    local dirIndicator = ""
    local dirColor = Theme.TextMuted
    if argHasIncoming and argHasOutgoing then
        dirIndicator = "⇅"
        dirColor = Theme.Purple
    elseif argHasIncoming then
        dirIndicator = "▼"
        dirColor = Theme.Cyan
    elseif argHasOutgoing then
        dirIndicator = "▲"
        dirColor = Theme.Success
    end
    
    createInstance("TextLabel", {
        Size = UDim2.new(0, 16, 1, 0),
        Position = UDim2.new(0, 4, 0, 0),
        BackgroundTransparency = 1,
        Text = dirIndicator,
        TextColor3 = dirColor,
        TextSize = 11,
        Font = Theme.FontFamilyBold,
        Parent = header
    })
    
    
    local argsPreview = ""
    local argCount = argGroup.CachedArgs and #argGroup.CachedArgs or #argGroup.Args
    if argCount > 0 then
        local parts = {}
        for i = 1, argCount do
            if i > 3 then
                table.insert(parts, "...")
                break
            end
            local snapshot = argGroup.CachedArgs and argGroup.CachedArgs[i]
            table.insert(parts, getArgPreviewFromSnapshot(snapshot, argGroup.Args[i]))
        end
        argsPreview = "(" .. table.concat(parts, ", ") .. ")"
    else
        argsPreview = "()"
    end
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, -90, 1, 0),
        Position = UDim2.new(0, 22, 0, 0),
        BackgroundTransparency = 1,
        Text = argsPreview,
        TextColor3 = isArgsIgnored and Theme.TextMuted or Theme.TextSecondary,
        TextSize = 10,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = header
    })
    
    
    createInstance("TextLabel", {
        Name = "ArgCallCount",
        Size = UDim2.new(0, 40, 1, 0),
        Position = UDim2.new(1, -50, 0, 0),
        BackgroundTransparency = 1,
        Text = "x" .. tostring(argGroup.Count),
        TextColor3 = Theme.Primary,
        TextSize = 10,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = header
    })
    
    header:SetAttribute("IsHovered", false)
    
    
    header.MouseEnter:Connect(function()
        header:SetAttribute("IsHovered", true)
        if self.SelectedArgKey ~= selectKey then
            tween(header, {ImageTransparency = 0}, 0.1)
        end
    end)
    
    header.MouseLeave:Connect(function()
        header:SetAttribute("IsHovered", false)
        if self.SelectedArgKey ~= selectKey then
            tween(header, {ImageTransparency = self:_getArgRestTransparency(remotePath, argHash)}, 0.1)
        end
    end)
    
    
    header.MouseButton1Click:Connect(function()
        self:SelectArgGroup(selectKey, argGroup, remoteGroup)
    end)
    
    
    header.MouseButton2Click:Connect(function()
        local mousePos = UserInputService:GetMouseLocation()
        UIComponents.ContextMenu({
            {Text = "Fire", Icon = ">", Callback = function()
                if argGroup.Logs[1] then
                    local success, result = RemoteScanner:FireRemote(argGroup.Logs[1])
                    if success then
                        UIComponents.Notification(self.ScreenGui, "Remote fired successfully", "success")
                    else
                        UIComponents.Notification(self.ScreenGui, "Failed to fire remote", "error")
                    end
                end
            end},
            {Text = "Copy Fire Script", Callback = function()
                if argGroup.Logs[1] then
                    local script = RemoteScanner:GenerateFireScript(argGroup.Logs[1])
                    copyToClipboard(script)
                    UIComponents.Notification(self.ScreenGui, "Fire script copied", "success")
                end
            end},
            {Separator = true},
            {Text = isArgsIgnored and "Stop Ignoring Args" or "Ignore These Args", Callback = function()
                RemoteScanner:SetIgnoreArgs(remotePath, argGroup.ArgHash, not isArgsIgnored)
                self:PopulateArgsPanel(remoteGroup)
                UIComponents.Notification(self.ScreenGui, 
                    isArgsIgnored and "Args unignored" or "Args ignored", "info")
            end},
            {Text = isArgsBlocked and "Unblock Args" or "Block These Args", Danger = not isArgsBlocked, Callback = function()
                RemoteScanner:SetBlockArgs(remotePath, argGroup.ArgHash, not isArgsBlocked)
                self:PopulateArgsPanel(remoteGroup)
                UIComponents.Notification(self.ScreenGui, 
                    isArgsBlocked and "Args unblocked" or "Args blocked", "info")
            end},
            {Separator = true},
            {Text = "Clear This Arg Group", Callback = function()
                RemoteScanner:ClearLogsForArgGroup(remotePath, argHash)
                self._lastArgsPanelSig = nil
                self:IncrementalRefreshArgsPanel(remoteGroup, true)
            end},
            {Text = "View Function Info", Callback = function()
                if argGroup.Logs[1] then
                    self:ShowFunctionInfoModal(argGroup.Logs[1])
                end
            end},
        }, mousePos, self.ScreenGui)
    end)
    
    header:SetAttribute("ArgSelectKey", selectKey)
    header:SetAttribute("RemotePath", remotePath)
    header:SetAttribute("ArgHash", argHash)
    
    if self._argEntryMap then
        self._argEntryMap[selectKey] = header
    end
end

function RemoteSpyUI:CreateArgGroupEntry(parent, remotePath, argGroup, order, remoteGroup)
    local argHash = argGroup.ArgHash
    local expandKey = remotePath .. "|" .. argHash
    local isExpanded = self.ExpandedArgGroups[expandKey] or false
    local isArgsBlocked = RemoteScanner.BlockedArgs[remotePath] and RemoteScanner.BlockedArgs[remotePath][argHash]
    local isArgsIgnored = RemoteScanner.IgnoredArgs[remotePath] and RemoteScanner.IgnoredArgs[remotePath][argHash]
    
    local container = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = order,
        Parent = parent
    })
    createListLayout(container, 1)
    
    
    local header = createInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = Theme.BackgroundSecondary,
        BackgroundTransparency = isArgsBlocked and 0.3 or (isArgsIgnored and 0.5 or 0.8),
        Text = "",
        LayoutOrder = 1,
        Parent = container
    })
    createCorner(header, Theme.CornerRadiusSmall)
    if isArgsBlocked then
        header.BackgroundColor3 = Theme.Danger
        header.BackgroundTransparency = 0.75
    elseif isArgsIgnored then
        header.BackgroundColor3 = Theme.Warning
        header.BackgroundTransparency = 0.8
    end
    
    
    local arrow = createInstance("TextLabel", {
        Size = UDim2.new(0, 14, 1, 0),
        Position = UDim2.new(0, 4, 0, 0),
        BackgroundTransparency = 1,
        Text = isExpanded and "v" or ">",
        TextColor3 = Theme.TextMuted,
        TextSize = 8,
        Font = Theme.FontFamilyBold,
        Parent = header
    })
    
    
    local argHasIncoming = false
    local argHasOutgoing = false
    for _, log in ipairs(argGroup.Logs) do
        if log.IsIncoming then
            argHasIncoming = true
        else
            argHasOutgoing = true
        end
        if argHasIncoming and argHasOutgoing then break end
    end
    
    local dirIndicator = ""
    local dirColor = Theme.TextMuted
    if argHasIncoming and argHasOutgoing then
        dirIndicator = "⇅"
        dirColor = Theme.Purple
    elseif argHasIncoming then
        dirIndicator = "▼"
        dirColor = Theme.Cyan
    elseif argHasOutgoing then
        dirIndicator = "▲"
        dirColor = Theme.Success
    end
    
    createInstance("TextLabel", {
        Size = UDim2.new(0, 12, 1, 0),
        Position = UDim2.new(0, 18, 0, 0),
        BackgroundTransparency = 1,
        Text = dirIndicator,
        TextColor3 = dirColor,
        TextSize = 10,
        Font = Theme.FontFamilyBold,
        Parent = header
    })
    
    
    local argsPreview = ""
    local argCount = argGroup.CachedArgs and #argGroup.CachedArgs or #argGroup.Args
    if argCount > 0 then
        local parts = {}
        for i = 1, argCount do
            if i > 3 then
                table.insert(parts, "...")
                break
            end
            local snapshot = argGroup.CachedArgs and argGroup.CachedArgs[i]
            table.insert(parts, getArgPreviewFromSnapshot(snapshot, argGroup.Args[i]))
        end
        argsPreview = "(" .. table.concat(parts, ", ") .. ")"
    else
        argsPreview = "()"
    end
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, -100, 1, 0),
        Position = UDim2.new(0, 32, 0, 0),
        BackgroundTransparency = 1,
        Text = argsPreview,
        TextColor3 = isArgsIgnored and Theme.TextMuted or Theme.TextSecondary,
        TextSize = 10,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = header
    })
    
    
    createInstance("TextLabel", {
        Size = UDim2.new(0, 35, 1, 0),
        Position = UDim2.new(1, -70, 0, 0),
        BackgroundTransparency = 1,
        Text = "x" .. tostring(argGroup.Count),
        TextColor3 = Theme.Primary,
        TextSize = 10,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = header
    })
    
    
    local statusText = ""
    local statusColor = Theme.TextMuted
    if isArgsBlocked then
        statusText = "BLK"
        statusColor = Theme.Danger
    elseif isArgsIgnored then
        statusText = "IGN"
        statusColor = Theme.Warning
    end
    
    if statusText ~= "" then
        createInstance("TextLabel", {
            Size = UDim2.new(0, 30, 1, 0),
            Position = UDim2.new(1, -35, 0, 0),
            BackgroundTransparency = 1,
            Text = statusText,
            TextColor3 = statusColor,
            TextSize = 8,
            Font = Theme.FontFamilyBold,
            Parent = header
        })
    end
    
    
    header.MouseEnter:Connect(function()
        tween(header, {BackgroundTransparency = 0}, 0.1)
    end)
    
    header.MouseLeave:Connect(function()
        tween(header, {BackgroundTransparency = isArgsBlocked and 0.3 or (isArgsIgnored and 0.5 or 0.8)}, 0.1)
    end)
    
    
    header.MouseButton1Click:Connect(function()
        self.ExpandedArgGroups[expandKey] = not self.ExpandedArgGroups[expandKey]
        self:RefreshRemoteList()
        
        
        if argGroup.Logs[1] then
            self:ShowLogDetails(argGroup.Logs[1])
        end
    end)
    
    
    header.MouseButton2Click:Connect(function()
        local mousePos = UserInputService:GetMouseLocation()
        UIComponents.ContextMenu({
            {Text = "Fire", Icon = ">", Callback = function()
                if argGroup.Logs[1] then
                    local success, result = RemoteScanner:FireRemote(argGroup.Logs[1])
                    if success then
                        UIComponents.Notification(self.ScreenGui, "Remote fired successfully", "success")
                    else
                        UIComponents.Notification(self.ScreenGui, "Failed to fire remote", "error")
                    end
                end
            end},
            {Text = "Copy Fire Script", Callback = function()
                if argGroup.Logs[1] then
                    local script = RemoteScanner:GenerateFireScript(argGroup.Logs[1])
                    copyToClipboard(script)
                    UIComponents.Notification(self.ScreenGui, "Fire script copied", "success")
                end
            end},
            {Separator = true},
            {Text = isArgsIgnored and "Stop Ignoring Args" or "Ignore These Args", Callback = function()
                RemoteScanner:SetIgnoreArgs(remotePath, argGroup.ArgHash, not isArgsIgnored)
                self:RefreshRemoteList()
                UIComponents.Notification(self.ScreenGui, 
                    isArgsIgnored and "Args unignored" or "Args ignored", "info")
            end},
            {Text = isArgsBlocked and "Unblock Args" or "Block These Args", Danger = not isArgsBlocked, Callback = function()
                RemoteScanner:SetBlockArgs(remotePath, argGroup.ArgHash, not isArgsBlocked)
                self:RefreshRemoteList()
                UIComponents.Notification(self.ScreenGui, 
                    isArgsBlocked and "Args unblocked" or "Args blocked", "info")
            end},
            {Separator = true},
            {Text = "Clear This Arg Group", Callback = function()
                RemoteScanner:ClearLogsForArgGroup(remotePath, argHash)
                self:RefreshRemoteList()
            end},
            {Text = "View Function Info", Callback = function()
                if argGroup.Logs[1] then
                    self:ShowFunctionInfoModal(argGroup.Logs[1])
                end
            end},
        }, mousePos, self.ScreenGui)
    end)
    
    
    if isExpanded and #argGroup.Logs > 0 then
        local logsContainer = createInstance("Frame", {
            Size = UDim2.new(1, -12, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Position = UDim2.new(0, 12, 0, 0),
            BackgroundTransparency = 1,
            LayoutOrder = 2,
            Parent = container
        })
        createListLayout(logsContainer, 1)
        createPadding(logsContainer, 2, 0, 0, 2, 2)
        
        
        local maxLogs = math.min(#argGroup.Logs, 10)
        for i = 1, maxLogs do
            local log = argGroup.Logs[i]
            self:CreateLogEntry(logsContainer, log, i)
        end
        
        if #argGroup.Logs > maxLogs then
            createInstance("TextLabel", {
                Size = UDim2.new(1, 0, 0, 18),
                BackgroundTransparency = 1,
                Text = "... and " .. (#argGroup.Logs - maxLogs) .. " more calls",
                TextColor3 = Theme.TextMuted,
                TextSize = 9,
                Font = Theme.FontFamily,
                LayoutOrder = maxLogs + 1,
                Parent = logsContainer
            })
        end
    end
end

function RemoteSpyUI:CreateLogEntry(parent, log, order)
    local entry = createInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = log.Blocked and 0.5 or 1,
        Text = "",
        LayoutOrder = order,
        Parent = parent
    })
    createCorner(entry, Theme.CornerRadiusSmall)
    if log.Blocked then
        entry.BackgroundColor3 = Theme.Danger
        entry.BackgroundTransparency = 0.75
    end
    
    
    createInstance("TextLabel", {
        Size = UDim2.new(0, 55, 1, 0),
        Position = UDim2.new(0, 6, 0, 0),
        BackgroundTransparency = 1,
        Text = log.Timestamp,
        TextColor3 = Theme.TextMuted,
        TextSize = 9,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = entry
    })
    
    
    if log.ReturnValue ~= nil then
        createInstance("TextLabel", {
            Size = UDim2.new(0, 40, 1, 0),
            Position = UDim2.new(0, 62, 0, 0),
            BackgroundTransparency = 1,
            Text = "-> " .. formatValue(log.ReturnValue):sub(1, 20),
            TextColor3 = Theme.Success,
            TextSize = 9,
            Font = Theme.FontFamilyMono,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = entry
        })
    end
    
    
    if log.Blocked then
        createInstance("TextLabel", {
            Size = UDim2.new(0, 45, 1, 0),
            Position = UDim2.new(1, -50, 0, 0),
            BackgroundTransparency = 1,
            Text = "BLOCKED",
            TextColor3 = Theme.Danger,
            TextSize = 8,
            Font = Theme.FontFamilyBold,
            Parent = entry
        })
    end
    
    
    if log.IsIncoming then
        createInstance("TextLabel", {
            Size = UDim2.new(0, 30, 1, 0),
            Position = UDim2.new(1, -35, 0, 0),
            BackgroundTransparency = 1,
            Text = "▼ IN",
            TextColor3 = Theme.Cyan,
            TextSize = 8,
            Font = Theme.FontFamilyBold,
            Parent = entry
        })
    else
        createInstance("TextLabel", {
            Size = UDim2.new(0, 30, 1, 0),
            Position = UDim2.new(1, -35, 0, 0),
            BackgroundTransparency = 1,
            Text = "▲ OUT",
            TextColor3 = Theme.Success,
            TextSize = 8,
            Font = Theme.FontFamilyBold,
            Parent = entry
        })
    end
    
    entry:SetAttribute("IsHovered", false)
    
    
    entry.MouseEnter:Connect(function()
        entry:SetAttribute("IsHovered", true)
        tween(entry, {BackgroundTransparency = 0}, 0.1)
    end)
    
    entry.MouseLeave:Connect(function()
        entry:SetAttribute("IsHovered", false)
        tween(entry, {BackgroundTransparency = log.Blocked and 0.5 or 1}, 0.1)
    end)
    
    
    entry.MouseButton1Click:Connect(function()
        task.defer(function()
            self:ShowLogDetails(log)
        end)
    end)
    
    
    entry.MouseButton2Click:Connect(function()
        local mousePos = UserInputService:GetMouseLocation()
        UIComponents.ContextMenu({
            {Text = "Fire", Icon = ">", Callback = function()
                local success, result = RemoteScanner:FireRemote(log)
                if success then
                    UIComponents.Notification(self.ScreenGui, "Remote fired", "success")
                else
                    UIComponents.Notification(self.ScreenGui, "Failed to fire", "error")
                end
            end},
            {Text = "Copy Fire Script", Callback = function()
                local script = RemoteScanner:GenerateFireScript(log)
                copyToClipboard(script)
                UIComponents.Notification(self.ScreenGui, "Script copied", "success")
            end},
            {Separator = true},
            {Text = "View Details", Callback = function()
                self:ShowLogDetails(log)
            end},
            {Text = "View Function Info", Callback = function()
                self:ShowFunctionInfoModal(log)
            end},
        }, mousePos, self.ScreenGui)
    end)
end

function RemoteSpyUI:GetFirstLogFromGroup(group)
    for _, argGroup in pairs(group.ArgGroups) do
        if argGroup.Logs[1] then
            return argGroup.Logs[1]
        end
    end
    return nil
end

function RemoteSpyUI:ShowRemoteDetails(group)
    
    for _, child in ipairs(self.DetailsFrame:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") or child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    local info = group.Info
    self.DetailsTitle.Text = "Remote overview"
    self:UpdateInspectorChrome()
    
    local order = 0
    
    
    order = order + 1
    local pathSection = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Background,
        LayoutOrder = order,
        Parent = self.DetailsFrame
    })
    createCorner(pathSection, Theme.CornerRadiusSmall)
    createPadding(pathSection, 8)
    createListLayout(pathSection, 4)
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = "Path",
        TextColor3 = Theme.TextMuted,
        TextSize = 10,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        Parent = pathSection
    })
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = info.Path,
        TextColor3 = Theme.TextPrimary,
        TextSize = 10,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        LayoutOrder = 2,
        Parent = pathSection
    })
    
    
    order = order + 1
    local statsSection = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Background,
        LayoutOrder = order,
        Parent = self.DetailsFrame
    })
    createCorner(statsSection, Theme.CornerRadiusSmall)
    createPadding(statsSection, 8)
    createListLayout(statsSection, 3)
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = "Statistics",
        TextColor3 = Theme.TextMuted,
        TextSize = 10,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        Parent = statsSection
    })
    
    local argGroupCount = 0
    for _ in pairs(group.ArgGroups) do argGroupCount = argGroupCount + 1 end
    
    UIComponents.PropertyRow(statsSection, "Type", info.Type, 2)
    UIComponents.PropertyRow(statsSection, "Total Calls", group.TotalCalls, 3)
    UIComponents.PropertyRow(statsSection, "Arg Groups", argGroupCount, 4)
    UIComponents.PropertyRow(statsSection, "Connections", info.ConnectionCount, 5)
    UIComponents.PropertyRow(statsSection, "Last Call", group.LastCall or "N/A", 6)
    
    
    order = order + 1
    local actionsSection = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = order,
        Parent = self.DetailsFrame
    })
    createListLayout(actionsSection, 4, Enum.FillDirection.Horizontal)
    
    UIComponents.Button(actionsSection, "Copy Path", nil, function()
        copyToClipboard(formatRobloxPath(info.Path))
        UIComponents.Notification(self.ScreenGui, "Path copied", "success")
    end).LayoutOrder = 1
    
    UIComponents.Button(actionsSection, "Fire Last", "primary", function()
        local firstLog = self:GetFirstLogFromGroup(group)
        if firstLog then
            RemoteScanner:FireRemote(firstLog)
            UIComponents.Notification(self.ScreenGui, "Fired with last args", "success")
        else
            UIComponents.Notification(self.ScreenGui, "No logs available", "warning")
        end
    end).LayoutOrder = 2
    
    local isIgnored = RemoteScanner.IgnoredInstances[info.Path]
    UIComponents.Button(actionsSection, isIgnored and "Unignore" or "Ignore", "warning", function()
        RemoteScanner:SetIgnoreInstance(info.Path, not isIgnored)
        self:RefreshRemoteList()
        self:ShowRemoteDetails(group)
    end).LayoutOrder = 3
    
    local isBlocked = RemoteScanner.BlockedInstances[info.Path]
    UIComponents.Button(actionsSection, isBlocked and "Unblock" or "Block", "danger", function()
        RemoteScanner:SetBlockInstance(info.Path, not isBlocked)
        self:RefreshRemoteList()
        self:ShowRemoteDetails(group)
    end).LayoutOrder = 4
end

function RemoteSpyUI:ShowLogDetails(log)
    self._detailsLogId = log.Id
    
    for _, child in ipairs(self.DetailsFrame:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") or child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    self.DetailsTitle.Text = "Latest call"
    self:UpdateInspectorChrome()
    
    local detailsHeader = self.DetailsTitle.Parent
    local oldBadge = detailsHeader and detailsHeader:FindFirstChild("CallCountBadge")
    if oldBadge then
        oldBadge:Destroy()
    end
    
    local countBadge = createInstance("TextLabel", {
        Name = "CallCountBadge",
        Size = UDim2.new(0, 120, 1, 0),
        Position = UDim2.new(1, -130, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.TextMuted,
        TextSize = 10,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = self.DetailsTitle.Parent
    })
    if self.SelectedArgKey then
        local remotePath, argHash = self.SelectedArgKey:match("^(.-)|([^|]+)$")
        local group = remotePath and RemoteScanner.GroupedLogs[remotePath]
        local argGroup = group and group.ArgGroups[argHash]
        if argGroup then
            countBadge.Text = "Calls: " .. tostring(argGroup.Count)
        end
    end
    
    local order = 0
    
    
    order = order + 1
    local headerSection = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Background,
        LayoutOrder = order,
        Parent = self.DetailsFrame
    })
    createCorner(headerSection, Theme.CornerRadiusSmall)
    createPadding(headerSection, 8)
    createListLayout(headerSection, 3)
    
    UIComponents.PropertyRow(headerSection, "Timestamp", RemoteScanner:EnsureFullTimestamp(log), 1)
    UIComponents.PropertyRow(headerSection, "Remote Type", log.RemoteType, 2)
    UIComponents.PropertyRow(headerSection, "Blocked", log.Blocked and "Yes" or "No", 3)
    if log.IsIncoming then
        UIComponents.PropertyRow(headerSection, "Direction", "Incoming (Server → Client)", 4)
    end
    
    
    if log.ArgumentCount > 0 then
        order = order + 1
        local argsSection = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.Background,
            LayoutOrder = order,
            Parent = self.DetailsFrame
        })
        createCorner(argsSection, Theme.CornerRadiusSmall)
        createPadding(argsSection, 8)
        createListLayout(argsSection, 4)
        
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = "Arguments (" .. log.ArgumentCount .. ")",
            TextColor3 = Theme.TextMuted,
            TextSize = 10,
            Font = Theme.FontFamilyBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 1,
            Parent = argsSection
        })
        
        for i, arg in ipairs(log.Arguments) do
            local snapshot = log.CachedArguments and log.CachedArguments[i]
            local argRow = createInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.BackgroundSecondary,
                LayoutOrder = i + 1,
                Parent = argsSection
            })
            createCorner(argRow, Theme.CornerRadiusSmall)
            createPadding(argRow, 6)
            createListLayout(argRow, 2)
            
            local typeStr = getArgTypeFromSnapshot(snapshot, arg)
            createInstance("TextLabel", {
                Size = UDim2.new(1, 0, 0, 14),
                BackgroundTransparency = 1,
                Text = "[" .. i .. "] " .. typeStr,
                TextColor3 = Theme.Primary,
                TextSize = 10,
                Font = Theme.FontFamilyBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 1,
                Parent = argRow
            })
            
            local displayText = self:_getLogArgDisplayText(log, i, arg)
            
            local lineCount = 1
            for _ in displayText:gmatch("\n") do
                lineCount = lineCount + 1
            end
            
            if lineCount > 8 or #displayText > 500 then
                UIComponents.ClippedScrollText(argRow, displayText, {
                    TextColor = Theme.TextPrimary,
                    LayoutOrder = 2,
                })
            else
                
                local codeContainer = createInstance("Frame", {
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = Theme.Background,
                    LayoutOrder = 2,
                    Parent = argRow
                })
                createCorner(codeContainer, Theme.CornerRadiusSmall)
                createPadding(codeContainer, 6)
                
                createInstance("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    Text = displayText,
                    TextColor3 = Theme.TextPrimary,
                    TextSize = 10,
                    Font = Theme.FontFamilyMono,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    Parent = codeContainer
                })
            end
        end
    end
    
    
    if log.ReturnValue ~= nil then
        order = order + 1
        local returnSection = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.Background,
            LayoutOrder = order,
            Parent = self.DetailsFrame
        })
        createCorner(returnSection, Theme.CornerRadiusSmall)
        createPadding(returnSection, 8)
        createListLayout(returnSection, 4)
        
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = "Return Value (" .. typeof(log.ReturnValue) .. ")",
            TextColor3 = Theme.TextMuted,
            TextSize = 10,
            Font = Theme.FontFamilyBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 1,
            Parent = returnSection
        })
        
        if not log._ReturnDisplayCache then
            if typeof(log.ReturnValue) == "table" then
                local success, result = pcall(function()
                    return parse(log.ReturnValue)
                end)
                log._ReturnDisplayCache = (success and result) or "{...}"
            else
                log._ReturnDisplayCache = serializeValue(log.ReturnValue, 0)
            end
        end
        local displayText = log._ReturnDisplayCache
        
        local lineCount = 1
        for _ in displayText:gmatch("\n") do
            lineCount = lineCount + 1
        end
        
        if lineCount > 8 or #displayText > 500 then
            UIComponents.ClippedScrollText(returnSection, displayText, {
                TextColor = Theme.Success,
                LayoutOrder = 2,
            })
        else
            
            local returnContainer = createInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.Background,
                LayoutOrder = 2,
                Parent = returnSection
            })
            createCorner(returnContainer, Theme.CornerRadiusSmall)
            createPadding(returnContainer, 6)
            
            createInstance("TextLabel", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Text = displayText,
                TextColor3 = Theme.Success,
                TextSize = 10,
                Font = Theme.FontFamilyMono,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
                Parent = returnContainer
            })
        end
    end
    
    
    order = order + 1
    local actionsSection = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = order,
        Parent = self.DetailsFrame
    })
    createListLayout(actionsSection, 4)
    
    
    local row1 = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        Parent = actionsSection
    })
    createListLayout(row1, 4, Enum.FillDirection.Horizontal)
    
    UIComponents.Button(row1, "Fire", "primary", function()
        local success = RemoteScanner:FireRemote(log)
        UIComponents.Notification(self.ScreenGui, 
            success and "Remote fired" or "Failed to fire", 
            success and "success" or "error")
    end).LayoutOrder = 1
    
    UIComponents.Button(row1, "Copy Script", nil, function()
        local script = RemoteScanner:GenerateFireScript(log)
        copyToClipboard(script)
        UIComponents.Notification(self.ScreenGui, "Script copied", "success")
    end).LayoutOrder = 2
    
    UIComponents.Button(row1, "Intercept", nil, function()
        local script = RemoteScanner:GenerateInterceptScript(log)
        copyToClipboard(script)
        UIComponents.Notification(self.ScreenGui, "Intercept copied", "success")
    end).LayoutOrder = 3
    
    
    local row2 = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Parent = actionsSection
    })
    createListLayout(row2, 4, Enum.FillDirection.Horizontal)
    
    UIComponents.Button(row2, "Func Info", nil, function()
        self:ShowFunctionInfoModal(log)
    end).LayoutOrder = 1
    
    UIComponents.Button(row2, "Copy Path", nil, function()
        copyToClipboard(formatRobloxPath(log.RemotePath))
        UIComponents.Notification(self.ScreenGui, "Path copied", "success")
    end).LayoutOrder = 2
    
    local isArgsBlocked = RemoteScanner.BlockedArgs[log.RemotePath] and 
                         RemoteScanner.BlockedArgs[log.RemotePath][log.ArgHash]
    UIComponents.Button(row2, isArgsBlocked and "Unblock" or "Block Args", "danger", function()
        RemoteScanner:SetBlockArgs(log.RemotePath, log.ArgHash, not isArgsBlocked)
        UIComponents.Notification(self.ScreenGui, 
            isArgsBlocked and "Args unblocked" or "Args blocked", "info")
        self:ShowLogDetails(log)
    end).LayoutOrder = 3
end

function RemoteSpyUI:ShowFunctionInfoModal(log)
    local info = RemoteScanner:EnsureCallerInfo(log)
    
    UIComponents.Modal(self.ScreenGui, "Function Information", UDim2.new(0, 550, 0, 420), function(content)
        local scroll = UIComponents.ScrollFrame(content)
        scroll.Size = UDim2.new(1, 0, 1, 0)
        createPadding(scroll, 4)
        createListLayout(scroll, 10)
        
        if info then
            
            local basicCard = createInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.BackgroundSecondary,
                LayoutOrder = 1,
                Parent = scroll
            })
            createCorner(basicCard, Theme.CornerRadius)
            createPadding(basicCard, 10)
            createListLayout(basicCard, 3)
            
            createInstance("TextLabel", {
                Size = UDim2.new(1, 0, 0, 18),
                BackgroundTransparency = 1,
                Text = "Basic Information",
                TextColor3 = Theme.TextPrimary,
                TextSize = 12,
                Font = Theme.FontFamilyBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 1,
                Parent = basicCard
            })
            
            UIComponents.PropertyRow(basicCard, "Address", info.Address, 2)
            UIComponents.PropertyRow(basicCard, "Name", info.Name, 3)
            UIComponents.PropertyRow(basicCard, "Closure Type", info.ClosureType, 4)
            UIComponents.PropertyRow(basicCard, "Source", info.Source, 5)
            UIComponents.PropertyRow(basicCard, "Script Path", info.ScriptPath, 6)
            UIComponents.PropertyRow(basicCard, "Line Defined", info.LineDefined, 7)
            UIComponents.PropertyRow(basicCard, "Num Params", info.NumParams, 8)
            
            
            if info.Constants and #info.Constants > 0 then
                local constCard = createInstance("Frame", {
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = Theme.BackgroundSecondary,
                    LayoutOrder = 2,
                    Parent = scroll
                })
                createCorner(constCard, Theme.CornerRadius)
                createPadding(constCard, 10)
                createListLayout(constCard, 3)
                
                createInstance("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 18),
                    BackgroundTransparency = 1,
                    Text = "Constants (" .. #info.Constants .. ")",
                    TextColor3 = Theme.TextPrimary,
                    TextSize = 12,
                    Font = Theme.FontFamilyBold,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    LayoutOrder = 1,
                    Parent = constCard
                })
                
                local constList = createInstance("Frame", {
                    Size = UDim2.new(1, 0, 0, math.min(#info.Constants * 18, 120)),
                    BackgroundColor3 = Theme.Background,
                    LayoutOrder = 2,
                    Parent = constCard
                })
                createCorner(constList, Theme.CornerRadiusSmall)
                
                local constScroll = UIComponents.ScrollFrame(constList)
                createPadding(constScroll, 4)
                createListLayout(constScroll, 1)
                
                for i, const in ipairs(info.Constants) do
                    if i > 40 then break end
                    createInstance("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 16),
                        BackgroundTransparency = 1,
                        Text = "[" .. i .. "] " .. formatValue(const),
                        TextColor3 = Theme.TextSecondary,
                        TextSize = 10,
                        Font = Theme.FontFamilyMono,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        LayoutOrder = i,
                        Parent = constScroll
                    })
                end
            end
            
            
            if info.Upvalues and next(info.Upvalues) then
                local upvalCard = createInstance("Frame", {
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = Theme.BackgroundSecondary,
                    LayoutOrder = 3,
                    Parent = scroll
                })
                createCorner(upvalCard, Theme.CornerRadius)
                createPadding(upvalCard, 10)
                createListLayout(upvalCard, 3)
                
                local count = 0
                for _ in pairs(info.Upvalues) do count = count + 1 end
                
                createInstance("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 18),
                    BackgroundTransparency = 1,
                    Text = "Upvalues (" .. count .. ")",
                    TextColor3 = Theme.TextPrimary,
                    TextSize = 12,
                    Font = Theme.FontFamilyBold,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    LayoutOrder = 1,
                    Parent = upvalCard
                })
                
                local upvalList = createInstance("Frame", {
                    Size = UDim2.new(1, 0, 0, math.min(count * 18, 120)),
                    BackgroundColor3 = Theme.Background,
                    LayoutOrder = 2,
                    Parent = upvalCard
                })
                createCorner(upvalList, Theme.CornerRadiusSmall)
                
                local upvalScroll = UIComponents.ScrollFrame(upvalList)
                createPadding(upvalScroll, 4)
                createListLayout(upvalScroll, 1)
                
                local idx = 0
                for k, v in pairs(info.Upvalues) do
                    idx = idx + 1
                    if idx > 40 then break end
                    createInstance("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 16),
                        BackgroundTransparency = 1,
                        Text = "[" .. tostring(k) .. "] " .. formatValue(v),
                        TextColor3 = Theme.TextSecondary,
                        TextSize = 10,
                        Font = Theme.FontFamilyMono,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        LayoutOrder = idx,
                        Parent = upvalScroll
                    })
                end
            end
            
            
            local decompileRow = createInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 28),
                BackgroundTransparency = 1,
                LayoutOrder = 4,
                Parent = scroll
            })
            createListLayout(decompileRow, 6, Enum.FillDirection.Horizontal)
            
            UIComponents.Button(decompileRow, "Decompile", "primary", function()
                if log.CallerFunction then
                    local result = FunctionAnalyzer:Decompile(log.CallerFunction)
                    self:ShowCodeModal("Decompiled Function", result)
                else
                    UIComponents.Notification(self.ScreenGui, "No function reference", "error")
                end
            end).LayoutOrder = 1
            
            UIComponents.Button(decompileRow, "Copy Script Path", nil, function()
                copyToClipboard(info.ScriptPath)
                UIComponents.Notification(self.ScreenGui, "Script path copied", "success")
            end).LayoutOrder = 2
            
        else
            createInstance("TextLabel", {
                Size = UDim2.new(1, 0, 0, 50),
                BackgroundTransparency = 1,
                Text = "No function information available.\nThis may happen if the call was made from a C closure\nor if function introspection is not supported.",
                TextColor3 = Theme.TextMuted,
                TextSize = 11,
                Font = Theme.FontFamily,
                TextWrapped = true,
                LayoutOrder = 1,
                Parent = scroll
            })
        end
    end)
end

function RemoteSpyUI:ShowCodeModal(title, code)
    UIComponents.Modal(self.ScreenGui, title, UDim2.new(0, 600, 0, 420), function(content)
        local codeBlock, _ = UIComponents.CodeBlock(content, code, "lua")
        codeBlock.Size = UDim2.new(1, 0, 1, 0)
    end)
end

function RemoteSpyUI:ShowResendModal(log)
    if log.Type ~= "Request" and log.Type ~= "RequestAsync" then
        UIComponents.Notification(self.ScreenGui, "Resend only works for Request types", "warning")
        return
    end
    if log.Type == "Request" and not HttpInterceptor:HasRequestSupport() then
        UIComponents.Notification(self.ScreenGui, "request() is not available on this executor", "warning")
        return
    end
    if log.Type == "RequestAsync" and not HttpInterceptor.HasRequestAsyncApi then
        UIComponents.Notification(self.ScreenGui, "HttpService:RequestAsync is not available", "warning")
        return
    end
    
    UIComponents.Modal(self.ScreenGui, "Resend Request", UDim2.new(0, 700, 0, 600), function(content)
        local scroll = UIComponents.ScrollFrame(content)
        createPadding(scroll, 4)
        createListLayout(scroll, 8)
        
        
        local resendData = {
            Url = log.TamperedUrl or log.Url,
            Method = log.TamperedMethod or log.Method or "GET",
            Headers = log.TamperedHeaders or log.Headers,
            Body = log.TamperedBody or log.Body,
        }
        
        
        
        
        
        local urlCard = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.BackgroundSecondary,
            LayoutOrder = 1,
            Parent = scroll
        })
        createCorner(urlCard, Theme.CornerRadius)
        createPadding(urlCard, 10)
        createListLayout(urlCard, 4)
        
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = "URL",
            TextColor3 = Theme.TextMuted,
            TextSize = 10,
            Font = Theme.FontFamilyBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 1,
            Parent = urlCard
        })
        
        local urlInput = createInstance("TextBox", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.Background,
            Text = resendData.Url,
            TextColor3 = Theme.Primary,
            TextSize = 10,
            Font = Theme.FontFamilyMono,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            MultiLine = true,
            ClearTextOnFocus = false,
            LayoutOrder = 2,
            Parent = urlCard
        })
        createCorner(urlInput, Theme.CornerRadiusSmall)
        createPadding(urlInput, 4)
        
        urlInput.FocusLost:Connect(function()
            resendData.Url = urlInput.Text
        end)
        
        
        
        
        
        local methodCard = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.BackgroundSecondary,
            LayoutOrder = 2,
            Parent = scroll
        })
        createCorner(methodCard, Theme.CornerRadius)
        createPadding(methodCard, 10)
        createListLayout(methodCard, 4)
        
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = "Method",
            TextColor3 = Theme.TextMuted,
            TextSize = 10,
            Font = Theme.FontFamilyBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 1,
            Parent = methodCard
        })
        
        local sendBtn = nil
        local methodDropdown = UIComponents.Dropdown(methodCard, {"GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"}, resendData.Method, function(method)
            resendData.Method = method
            if sendBtn then
                local btnLabel = sendBtn:FindFirstChildOfClass("TextLabel")
                if btnLabel then
                    btnLabel.Text = "  Send " .. method .. "  "
                end
            end
        end)
        methodDropdown.Size = UDim2.new(0, 120, 0, 28)
        methodDropdown.LayoutOrder = 2
        
        
        
        
        
        local headersCard = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.BackgroundSecondary,
            LayoutOrder = 3,
            Parent = scroll
        })
        createCorner(headersCard, Theme.CornerRadius)
        createPadding(headersCard, 10)
        createListLayout(headersCard, 4)
        
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = "Headers (JSON)",
            TextColor3 = Theme.TextMuted,
            TextSize = 10,
            Font = Theme.FontFamilyBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 1,
            Parent = headersCard
        })
        
        local headersStr = ""
        if resendData.Headers then
            local success, result = pcall(function()
                return HttpService:JSONEncode(resendData.Headers)
            end)
            headersStr = success and result or "{}"
        end
        
        local headersContainer = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 70),
            BackgroundColor3 = Theme.Background,
            LayoutOrder = 2,
            Parent = headersCard
        })
        createCorner(headersContainer, Theme.CornerRadiusSmall)
        
        local headersScroll = createInstance("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = Theme.BorderHover,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Parent = headersContainer
        })
        createPadding(headersScroll, 6)
        
        local headersInput = createInstance("TextBox", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Text = headersStr,
            PlaceholderText = '{"Content-Type": "application/json"}',
            TextColor3 = Theme.TextPrimary,
            TextSize = 10,
            Font = Theme.FontFamilyMono,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            MultiLine = true,
            ClearTextOnFocus = false,
            Parent = headersScroll
        })
        
        headersInput.FocusLost:Connect(function()
            pcall(function()
                resendData.Headers = HttpService:JSONDecode(headersInput.Text)
            end)
        end)
        
        
        
        
        
        local bodyCard = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 120),
            BackgroundColor3 = Theme.BackgroundSecondary,
            LayoutOrder = 4,
            Parent = scroll
        })
        createCorner(bodyCard, Theme.CornerRadius)
        createPadding(bodyCard, 10)
        createListLayout(bodyCard, 4)
        
        local bodyStr = ""
        if resendData.Body then
            if type(resendData.Body) == "table" then
                local success, result = pcall(function()
                    return parse(resendData.Body)
                end)
                if success then
                    bodyStr = result
                else
                    pcall(function()
                        bodyStr = HttpService:JSONEncode(resendData.Body)
                    end)
                end
            else
                bodyStr = tostring(resendData.Body)
            end
        end
        
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = "Request Body",
            TextColor3 = Theme.TextMuted,
            TextSize = 10,
            Font = Theme.FontFamilyBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 1,
            Parent = bodyCard
        })
        
        local bodyContainer = createInstance("Frame", {
            Size = UDim2.new(1, 0, 1, -24),
            BackgroundColor3 = Theme.Background,
            LayoutOrder = 2,
            Parent = bodyCard
        })
        createCorner(bodyContainer, Theme.CornerRadiusSmall)
        
        local bodyScroll = createInstance("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = Theme.BorderHover,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Parent = bodyContainer
        })
        createPadding(bodyScroll, 6)
        
        local bodyInput = createInstance("TextBox", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Text = bodyStr,
            PlaceholderText = "Request body...",
            TextColor3 = Theme.TextPrimary,
            TextSize = 10,
            Font = Theme.FontFamilyMono,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            MultiLine = true,
            ClearTextOnFocus = false,
            Parent = bodyScroll
        })
        
        bodyInput.FocusLost:Connect(function()
            resendData.Body = bodyInput.Text
        end)
        
        
        
        
        
        local responseCard = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 160),
            BackgroundColor3 = Theme.BackgroundSecondary,
            LayoutOrder = 5,
            Parent = scroll
        })
        createCorner(responseCard, Theme.CornerRadius)
        createPadding(responseCard, 10)
        createListLayout(responseCard, 4)
        
        local responseHeader = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundTransparency = 1,
            LayoutOrder = 1,
            Parent = responseCard
        })
        
        local responseLabel = createInstance("TextLabel", {
            Size = UDim2.new(0.6, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "Response (send request first)",
            TextColor3 = Theme.TextMuted,
            TextSize = 10,
            Font = Theme.FontFamilyBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = responseHeader
        })
        
        local copyResponseBtn = UIComponents.Button(responseHeader, "Copy", nil, function() end)
        copyResponseBtn.Size = UDim2.new(0, 50, 0, 20)
        copyResponseBtn.Position = UDim2.new(1, -50, 0, 0)
        copyResponseBtn.Visible = false
        
        local responseContainer = createInstance("Frame", {
            Size = UDim2.new(1, 0, 1, -60),
            BackgroundColor3 = Theme.Background,
            LayoutOrder = 2,
            Parent = responseCard
        })
        createCorner(responseContainer, Theme.CornerRadiusSmall)
        
        local chunkedText = nil
        local isFetching = false
        
        local placeholderLabel = createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "No response yet.\nClick Send to make the request.",
            TextColor3 = Theme.TextMuted,
            TextSize = 11,
            Font = Theme.FontFamily,
            Parent = responseContainer
        })
        
        local function updateResponseDisplay(responseData)
            if not responseData then return end
            
            local responseStr
            if type(responseData) == "table" then
                if responseData.Body then
                    responseStr = responseData.Body
                else
                    local success, json = pcall(function()
                        return HttpService:JSONEncode(responseData)
                    end)
                    responseStr = success and json or tostring(responseData)
                end
            else
                responseStr = tostring(responseData)
            end
            
            responseLabel.Text = string.format("Response (%d chars)", #responseStr)
            copyResponseBtn.Visible = true
            
            if placeholderLabel then
                placeholderLabel:Destroy()
                placeholderLabel = nil
            end
            
            if not chunkedText then
                chunkedText = UIComponents.ChunkedTextArea(responseContainer, responseStr, true, nil)
            else
                chunkedText.SetText(responseStr)
            end
            
        end
        
        copyResponseBtn.MouseButton1Click:Connect(function()
            local textToCopy = chunkedText and chunkedText.GetFullText() or ""
            if textToCopy ~= "" then
                copyToClipboard(textToCopy)
                UIComponents.Notification(self.ScreenGui, "Copied " .. #textToCopy .. " chars", "success")
            end
        end)
        
        
        
        
        
        local actionsRow = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundTransparency = 1,
            LayoutOrder = 3,
            Parent = responseCard
        })
        createListLayout(actionsRow, 8, Enum.FillDirection.Horizontal)
        
        
        sendBtn = UIComponents.Button(actionsRow, "Send " .. resendData.Method, "primary", function()
            if isFetching then
                UIComponents.Notification(self.ScreenGui, "Already sending...", "warning")
                return
            end
            
            isFetching = true
            
            
            if placeholderLabel then
                placeholderLabel.Text = "Sending request..."
            end
            responseLabel.Text = "Response (sending...)"
            
            UIComponents.Notification(self.ScreenGui, "Sending " .. resendData.Method .. "...", "info")
            
            task.spawn(function()
                
                local options = {
                    Url = resendData.Url,
                    Method = resendData.Method,
                }
                
                if resendData.Headers then
                    options.Headers = resendData.Headers
                end
                
                if resendData.Body and resendData.Body ~= "" then
                    options.Body = resendData.Body
                end
                
                
                FetchingRequests[resendData.Url] = true
                
                local result = nil
                local success, err = pcall(function()
                    if log.Type == "RequestAsync" then
                        if not ClonedRequestAsync then
                            error("RequestAsync not available")
                        end
                        result = ClonedRequestAsync(HttpService, options)
                    elseif ClonedRequest then
                        result = ClonedRequest(options)
                    else
                        error("request() not available")
                    end
                end)
                
                FetchingRequests[resendData.Url] = nil
                isFetching = false
                
                if success and result then
                    local respLen = 0
                    if type(result) == "table" and result.Body then
                        respLen = #result.Body
                    elseif type(result) == "string" then
                        respLen = #result
                    end
                    
                    UIComponents.Notification(self.ScreenGui, "Success! " .. respLen .. " chars", "success")
                    updateResponseDisplay(result)
                else
                    UIComponents.Notification(self.ScreenGui, "Failed: " .. tostring(err), "error")
                    responseLabel.Text = "Response (failed)"
                    if placeholderLabel then
                        placeholderLabel.Text = "Request failed:\n" .. tostring(err)
                    end
                end
            end)
        end)
        sendBtn.LayoutOrder = 1
        
        
        UIComponents.Button(actionsRow, "Close", nil, function()
            content.Parent.Parent:Destroy()
        end).LayoutOrder = 2
    end)
end

function RemoteSpyUI:QueueRemoteRefresh()
    self._remoteDirty = true
end

function RemoteSpyUI:QueueHttpRefresh()
    self._httpDirty = true
end

function RemoteSpyUI:UpdateRemoteGroup(path, group)
    self:QueueRemoteRefresh()
end

function RemoteSpyUI:_setHttpEntryStroke(entry, log)
    for _, child in ipairs(entry:GetChildren()) do
        if child:IsA("UIStroke") then
            child:Destroy()
        end
    end
    
    if log.Blocked then
        setSurfaceColor(entry, Theme.Danger)
        setSurfaceTransparency(entry, 0.75)
    elseif log.Pending then
        setSurfaceColor(entry, Theme.WarningMuted)
        setSurfaceTransparency(entry, 0.7)
    end
end

function RemoteSpyUI:_updateHttpLogEntryVisual(entry, log, order)
    if not entry or not log then
        return
    end
    
    if order then
        entry.LayoutOrder = order
    end
    
    setSurfaceColor(entry, log.Pending and Theme.WarningMuted or Theme.BackgroundTertiary)
    setSurfaceTransparency(entry, log.Pending and 0.7 or 1)
    self:_setHttpEntryStroke(entry, log)
    
    local timeLabel = entry:FindFirstChild("TimeLabel")
    if timeLabel then
        timeLabel.Text = log.Timestamp
    end
    
    local urlLabel = entry:FindFirstChild("UrlLabel")
    if urlLabel then
        urlLabel.Text = log.TamperedUrl or log.Url
    end
    
    local badgeFrame = entry:FindFirstChild("TypeBadge")
    if badgeFrame then
        local badgeText, badgeColor = self:_getHttpBadgeStyle(log)
        setSurfaceColor(badgeFrame, badgeColor or Theme.Primary)
        local badgeLabel = badgeFrame:FindFirstChildOfClass("TextLabel")
        if badgeLabel then
            badgeLabel.Text = "  " .. badgeText .. "  "
            badgeLabel.TextColor3 = badgeColor or Theme.Primary
        end
    end
    
    local statusLabel = entry:FindFirstChild("StatusLabel")
    if statusLabel then
        local statusText, statusColor = HttpInterceptor:GetLogStatus(log)
        statusLabel.Text = statusText
        statusLabel.TextColor3 = statusColor
    end
end

function RemoteSpyUI:RefreshHttpList()
    local frame = self.HttpListFrame
    if not frame then
        return
    end
    
    self._httpEntriesById = self._httpEntriesById or {}
    
    local scrollY = frame.CanvasPosition.Y
    local seen = {}
    
    for i, log in ipairs(HttpInterceptor.Logs) do
        seen[log.Id] = true
        local entry = self._httpEntriesById[log.Id]
        if entry and entry.Parent then
            self:_updateHttpLogEntryVisual(entry, log, i)
        else
            entry = self:AddHttpLogEntry(log, i)
            self._httpEntriesById[log.Id] = entry
        end
    end
    
    for logId, entry in pairs(self._httpEntriesById) do
        if not seen[logId] then
            if entry and entry.Parent then
                entry:Destroy()
            end
            self._httpEntriesById[logId] = nil
        end
    end
    
    task.defer(function()
        if frame.Parent then
            frame.CanvasPosition = Vector2.new(0, scrollY)
        end
    end)
end

function RemoteSpyUI:UpdateHttpPendingRows()
    if not self._httpEntriesById then
        return
    end
    
    for logId, entry in pairs(self._httpEntriesById) do
        if entry and entry.Parent then
            local log = HttpInterceptor.LogsById[logId]
            if log and log.Pending then
                self:_updateHttpLogEntryVisual(entry, log)
            end
        end
    end
end

function RemoteSpyUI:AddHttpLogEntry(log, order)
    order = order or 1
    
    local entry = createInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = log.Pending and Theme.WarningMuted or Theme.BackgroundTertiary,
        BackgroundTransparency = log.Pending and 0.7 or 1,
        Text = "",
        LayoutOrder = order,
        Parent = self.HttpListFrame
    })
    createCorner(entry, Theme.CornerRadiusSmall)
    self:_setHttpEntryStroke(entry, log)
    
    createInstance("TextLabel", {
        Name = "TimeLabel",
        Size = UDim2.new(0, 50, 1, 0),
        Position = UDim2.new(0, 6, 0, 0),
        BackgroundTransparency = 1,
        Text = log.Timestamp,
        TextColor3 = Theme.TextMuted,
        TextSize = 9,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = entry
    })
    
    local badgeText, badgeColor = self:_getHttpBadgeStyle(log)
    local badge = UIComponents.Badge(entry, badgeText, badgeColor, 8)
    badge.Name = "TypeBadge"
    badge.Position = UDim2.new(0, 58, 0.5, -8)
    
    createInstance("TextLabel", {
        Name = "UrlLabel",
        Size = UDim2.new(1, -200, 1, 0),
        Position = UDim2.new(0, 115, 0, 0),
        BackgroundTransparency = 1,
        Text = log.TamperedUrl or log.Url,
        TextColor3 = Theme.TextPrimary,
        TextSize = 10,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = entry
    })
    
    local statusText, statusColor = HttpInterceptor:GetLogStatus(log)
    
    local menuBtn = UIComponents.IconButton(entry, "⋮", function()
        self:_openHttpContextMenu(log)
    end, 16)
    menuBtn.Position = UDim2.new(1, -88, 0.5, -8)
    
    createInstance("TextLabel", {
        Name = "StatusLabel",
        Size = UDim2.new(0, 55, 1, 0),
        Position = UDim2.new(1, -60, 0, 0),
        BackgroundTransparency = 1,
        Text = statusText,
        TextColor3 = statusColor,
        TextSize = 9,
        Font = Theme.FontFamilyBold,
        Parent = entry
    })
    
    entry.MouseEnter:Connect(function()
        tween(entry, {BackgroundTransparency = 0}, 0.1)
    end)
    
    entry.MouseLeave:Connect(function()
        tween(entry, {BackgroundTransparency = log.Pending and 0.7 or 1}, 0.1)
    end)
    
    entry.MouseButton1Click:Connect(function()
        self:ShowHttpDetailsModal(log)
    end)
    
    entry.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            self:_openHttpContextMenu(log)
        end
    end)
    
    entry:SetAttribute("LogId", log.Id)
    return entry
end

function RemoteSpyUI:UpdateHttpPendingStatus(log)
    self:QueueHttpRefresh()
end

function RemoteSpyUI:ShowHttpDetailsModal(log)
    local isTableRequest = log.Type == "Request" or log.Type == "RequestAsync"
    local isHttpPost = log.Type == "HttpPost" or log.Type == "HttpPostAsync"
    local isHttpGet = log.Type == "HttpGet" or log.Type == "HttpGetAsync"
    local modalTitle = isTableRequest and "Request Details" or "HTTP Details"
    local modalSize = isTableRequest and UDim2.new(0, 700, 0, 650) or UDim2.new(0, 650, 0, 550)
    
    UIComponents.Modal(self.ScreenGui, modalTitle, modalSize, function(content)
        local scroll = UIComponents.ScrollFrame(content)
        createPadding(scroll, 4)
        createListLayout(scroll, 8)
        
        
        local responseCard = nil
        local responseContainer = nil
        local responseLabel = nil
        local chunkedText = nil
        local fetchBtn = nil
        local acceptBtn = nil
        local copyResponseBtn = nil
        local placeholderLabel = nil
        
        local canEditRequest = isTableRequest
        local canEditBeforeFetch = log.Pending and not log.FetchedResponse
        
        
        
        
        
        local infoCard = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.BackgroundSecondary,
            LayoutOrder = 1,
            Parent = scroll
        })
        createCorner(infoCard, Theme.CornerRadius)
        createPadding(infoCard, 10)
        createListLayout(infoCard, 3)
        
        UIComponents.PropertyRow(infoCard, "Timestamp", log.FullTimestamp, 1)
        UIComponents.PropertyRow(infoCard, "Type", log.Type, 2)
        
        local statusCode, _ = HttpInterceptor:GetLogStatus(log)
        local statusText = statusCode
        if statusCode == "TIMEOUT" then
            statusText = "Timed Out"
        elseif statusCode == "OK" and not log.Pending then
            statusText = "Complete"
        elseif statusCode == "PENDING" then
            statusText = "Awaiting Fetch"
        elseif statusCode == "READY" then
            statusText = "Response Ready"
        elseif statusCode == "FETCH..." then
            statusText = "Fetching..."
        end
        UIComponents.PropertyRow(infoCard, "Status", statusText, 3)
        
        if log.Nocache ~= nil and (isHttpGet or isHttpPost) then
            UIComponents.PropertyRow(infoCard, "No Cache", log.Nocache and "Yes" or "No", 4)
        end
        
        
        
        
        
        local urlCard = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.BackgroundSecondary,
            LayoutOrder = 2,
            Parent = scroll
        })
        createCorner(urlCard, Theme.CornerRadius)
        createPadding(urlCard, 10)
        createListLayout(urlCard, 4)
        
        
        local urlEditable = canEditRequest or canEditBeforeFetch
        
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = urlEditable and "URL (editable)" or "URL (click to copy)",
            TextColor3 = Theme.TextMuted,
            TextSize = 10,
            Font = Theme.FontFamilyBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 1,
            Parent = urlCard
        })
        
        local urlInput = nil
        if urlEditable then
            urlInput = createInstance("TextBox", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.Background,
                Text = log.TamperedUrl or log.Url,
                TextColor3 = Theme.Primary,
                TextSize = 10,
                Font = Theme.FontFamilyMono,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
                MultiLine = true,
                ClearTextOnFocus = false,
                LayoutOrder = 2,
                Parent = urlCard
            })
            createCorner(urlInput, Theme.CornerRadiusSmall)
            createPadding(urlInput, 4)
            
            urlInput.FocusLost:Connect(function()
                log.TamperedUrl = urlInput.Text
            end)
        else
            UIComponents.ClickableUrl(urlCard, log.TamperedUrl or log.Url, 2)
        end
        
        if isHttpPost then
            local postBodyStr = tostring(log.TamperedBody or log.Body or "")
            local postBodyCard = createInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 120),
                BackgroundColor3 = Theme.BackgroundSecondary,
                LayoutOrder = 3,
                Parent = scroll
            })
            createCorner(postBodyCard, Theme.CornerRadius)
            createPadding(postBodyCard, 10)
            createListLayout(postBodyCard, 4)
            
            createInstance("TextLabel", {
                Size = UDim2.new(1, 0, 0, 16),
                BackgroundTransparency = 1,
                Text = canEditBeforeFetch and "POST Body (editable)" or ("POST Body (" .. #postBodyStr .. " chars)"),
                TextColor3 = Theme.TextMuted,
                TextSize = 10,
                Font = Theme.FontFamilyBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 1,
                Parent = postBodyCard
            })
            
            local postBodyContainer = createInstance("Frame", {
                Size = UDim2.new(1, 0, 1, -24),
                BackgroundColor3 = Theme.Background,
                LayoutOrder = 2,
                Parent = postBodyCard
            })
            createCorner(postBodyContainer, Theme.CornerRadiusSmall)
            
            if canEditBeforeFetch then
                local postBodyScroll = createInstance("ScrollingFrame", {
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    ScrollBarThickness = 4,
                    ScrollBarImageColor3 = Theme.BorderHover,
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    Parent = postBodyContainer
                })
                createPadding(postBodyScroll, 6)
                
                local postBodyInput = createInstance("TextBox", {
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    Text = postBodyStr,
                    PlaceholderText = "POST body...",
                    TextColor3 = Theme.TextPrimary,
                    TextSize = 10,
                    Font = Theme.FontFamilyMono,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    TextWrapped = true,
                    MultiLine = true,
                    ClearTextOnFocus = false,
                    Parent = postBodyScroll
                })
                
                postBodyInput.FocusLost:Connect(function()
                    log.TamperedBody = postBodyInput.Text
                end)
            else
                UIComponents.ChunkedTextArea(postBodyContainer, postBodyStr, true, nil)
            end
        end
        
        
        
        
        
        if isTableRequest then
            
            local methodCard = createInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.BackgroundSecondary,
                LayoutOrder = 3,
                Parent = scroll
            })
            createCorner(methodCard, Theme.CornerRadius)
            createPadding(methodCard, 10)
            createListLayout(methodCard, 4)
            
            createInstance("TextLabel", {
                Size = UDim2.new(1, 0, 0, 16),
                BackgroundTransparency = 1,
                Text = "Method",
                TextColor3 = Theme.TextMuted,
                TextSize = 10,
                Font = Theme.FontFamilyBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 1,
                Parent = methodCard
            })
            
            
            local methodDropdown = UIComponents.Dropdown(methodCard, {"GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"}, log.TamperedMethod or log.Method or "GET", function(method)
                log.TamperedMethod = method
                
                if fetchBtn then
                    local btnLabel = fetchBtn:FindFirstChildOfClass("TextLabel")
                    if btnLabel then
                        local prefix = log.Pending and "Send " or "Resend "
                        btnLabel.Text = "  " .. prefix .. method .. "  "
                    end
                end
            end)
            methodDropdown.Size = UDim2.new(0, 120, 0, 28)
            methodDropdown.LayoutOrder = 2
            
            
            local headersCard = createInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.BackgroundSecondary,
                LayoutOrder = 4,
                Parent = scroll
            })
            createCorner(headersCard, Theme.CornerRadius)
            createPadding(headersCard, 10)
            createListLayout(headersCard, 4)
            
            createInstance("TextLabel", {
                Size = UDim2.new(1, 0, 0, 16),
                BackgroundTransparency = 1,
                Text = "Headers (JSON)",
                TextColor3 = Theme.TextMuted,
                TextSize = 10,
                Font = Theme.FontFamilyBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 1,
                Parent = headersCard
            })
            
            local headersStr = ""
            local headersToShow = log.TamperedHeaders or log.Headers
            if headersToShow then
                local success, result = pcall(function()
                    return HttpService:JSONEncode(headersToShow)
                end)
                headersStr = success and result or "{}"
            end
            
            local headersContainer = createInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 70),
                BackgroundColor3 = Theme.Background,
                LayoutOrder = 2,
                Parent = headersCard
            })
            createCorner(headersContainer, Theme.CornerRadiusSmall)
            
            local headersScroll = createInstance("ScrollingFrame", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                ScrollBarThickness = 4,
                ScrollBarImageColor3 = Theme.BorderHover,
                CanvasSize = UDim2.new(0, 0, 0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                Parent = headersContainer
            })
            createPadding(headersScroll, 6)
            
            
            local headersInput = createInstance("TextBox", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Text = headersStr,
                PlaceholderText = '{"Content-Type": "application/json"}',
                TextColor3 = Theme.TextPrimary,
                TextSize = 10,
                Font = Theme.FontFamilyMono,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true,
                MultiLine = true,
                ClearTextOnFocus = false,
                Parent = headersScroll
            })
            
            headersInput.FocusLost:Connect(function()
                pcall(function()
                    if headersInput.Text ~= "" then
                        log.TamperedHeaders = HttpService:JSONDecode(headersInput.Text)
                    else
                        log.TamperedHeaders = nil
                    end
                end)
            end)
            
            
            local bodyCard = createInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 120),
                BackgroundColor3 = Theme.BackgroundSecondary,
                LayoutOrder = 5,
                Parent = scroll
            })
            createCorner(bodyCard, Theme.CornerRadius)
            createPadding(bodyCard, 10)
            createListLayout(bodyCard, 4)
            
            local bodyStr = ""
            local bodyToShow = log.TamperedBody or log.Body
            if bodyToShow then
                if type(bodyToShow) == "table" then
                    local success, result = pcall(function()
                        return parse(bodyToShow)
                    end)
                    if success then
                        bodyStr = result
                    else
                        pcall(function()
                            bodyStr = HttpService:JSONEncode(bodyToShow)
                        end)
                    end
                else
                    bodyStr = tostring(bodyToShow)
                end
            end
            
            createInstance("TextLabel", {
                Size = UDim2.new(1, 0, 0, 16),
                BackgroundTransparency = 1,
                Text = "Request Body (" .. #bodyStr .. " chars)",
                TextColor3 = Theme.TextMuted,
                TextSize = 10,
                Font = Theme.FontFamilyBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 1,
                Parent = bodyCard
            })
            
            local bodyContainer = createInstance("Frame", {
                Size = UDim2.new(1, 0, 1, -24),
                BackgroundColor3 = Theme.Background,
                LayoutOrder = 2,
                Parent = bodyCard
            })
            createCorner(bodyContainer, Theme.CornerRadiusSmall)
            
            local bodyScroll = createInstance("ScrollingFrame", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                ScrollBarThickness = 4,
                ScrollBarImageColor3 = Theme.BorderHover,
                CanvasSize = UDim2.new(0, 0, 0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                Parent = bodyContainer
            })
            createPadding(bodyScroll, 6)
            
            
            local bodyInput = createInstance("TextBox", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Text = bodyStr,
                PlaceholderText = "Request body...",
                TextColor3 = Theme.TextPrimary,
                TextSize = 10,
                Font = Theme.FontFamilyMono,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true,
                MultiLine = true,
                ClearTextOnFocus = false,
                Parent = bodyScroll
            })
            
            bodyInput.FocusLost:Connect(function()
                log.TamperedBody = bodyInput.Text
            end)
        end
        
        
        
        
        
        responseCard = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, isTableRequest and 180 or 260),
            BackgroundColor3 = Theme.BackgroundSecondary,
            LayoutOrder = 10,
            Parent = scroll
        })
        createCorner(responseCard, Theme.CornerRadius)
        createPadding(responseCard, 10)
        createListLayout(responseCard, 4)
        
        local responseHeader = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundTransparency = 1,
            LayoutOrder = 1,
            Parent = responseCard
        })
        
        local hasResponse = log.FetchedResponse ~= nil or log.ReturnValue ~= nil
        responseLabel = createInstance("TextLabel", {
            Size = UDim2.new(0.6, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = hasResponse and "Response" or "Response (not fetched)",
            TextColor3 = Theme.TextMuted,
            TextSize = 10,
            Font = Theme.FontFamilyBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = responseHeader
        })
        
        copyResponseBtn = UIComponents.Button(responseHeader, "Copy", nil, function() end)
        copyResponseBtn.Size = UDim2.new(0, 50, 0, 20)
        copyResponseBtn.Position = UDim2.new(1, -50, 0, 0)
        copyResponseBtn.Visible = hasResponse
        
        responseContainer = createInstance("Frame", {
            Size = UDim2.new(1, 0, 1, -60),
            BackgroundColor3 = Theme.Background,
            LayoutOrder = 2,
            Parent = responseCard
        })
        createCorner(responseContainer, Theme.CornerRadiusSmall)
        
        local function getResponseString()
            local responseData = log.FetchedResponse or log.ReturnValue
            if not responseData then return "" end
            
            if type(responseData) == "table" then
                if responseData.Body then
                    return responseData.Body
                else
                    local success, json = pcall(function()
                        return HttpService:JSONEncode(responseData)
                    end)
                    return success and json or tostring(responseData)
                end
            else
                return tostring(responseData)
            end
        end
        
        local function updateResponseDisplay()
            local responseStr = getResponseString()
            
            if #responseStr > 0 then
                responseLabel.Text = string.format("Response (%d chars)", #responseStr)
                copyResponseBtn.Visible = true
                
                if placeholderLabel then
                    placeholderLabel:Destroy()
                    placeholderLabel = nil
                end
                
                if not chunkedText then
                    
                    local responseEditable = log.Pending and log.FetchedResponse
                    chunkedText = UIComponents.ChunkedTextArea(responseContainer, responseStr, not responseEditable, nil)
                else
                    chunkedText.SetText(responseStr)
                end
            else
                responseLabel.Text = log.IsFetching and "Response (fetching...)" or "Response (not fetched)"
                copyResponseBtn.Visible = false
                
                if not placeholderLabel then
                    placeholderLabel = createInstance("TextLabel", {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text = log.IsFetching and "Fetching..." or "No response yet.\nClick Send to fetch.",
                        TextColor3 = Theme.TextMuted,
                        TextSize = 11,
                        Font = Theme.FontFamily,
                        Parent = responseContainer
                    })
                end
            end
        end
        
        updateResponseDisplay()
        
        copyResponseBtn.MouseButton1Click:Connect(function()
            local textToCopy = chunkedText and chunkedText.GetFullText() or getResponseString()
            copyToClipboard(textToCopy)
            UIComponents.Notification(self.ScreenGui, "Copied " .. #textToCopy .. " chars", "success")
        end)
        
        
        if log.Pending then
            task.spawn(function()
                while log.Pending and responseCard.Parent do
                    task.wait(0.2)
                    if log.IsFetching or log.FetchedResponse then
                        updateResponseDisplay()
                    end
                    if log.FetchedResponse then
                        break
                    end
                end
            end)
        end
        
        
        
        
        
        local actionsRow = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundTransparency = 1,
            LayoutOrder = 3,
            Parent = responseCard
        })
        createListLayout(actionsRow, 8, Enum.FillDirection.Horizontal)
        
        if log.Pending then
            
            local fetchMethod = log.TamperedMethod or log.Method or "GET"
            fetchBtn = UIComponents.Button(actionsRow, "Send " .. fetchMethod, "primary", function()
                if log.IsFetching then
                    UIComponents.Notification(self.ScreenGui, "Already fetching...", "warning")
                    return
                end
                
                log.FetchedResponse = nil
                UIComponents.Notification(self.ScreenGui, "Fetching...", "info")
                
                task.spawn(function()
                    local result, err = HttpInterceptor:FetchResponse(log.Id)
                    if result then
                        UIComponents.Notification(self.ScreenGui, "Fetched " .. #tostring(result) .. " chars", "success")
                        updateResponseDisplay()
                    else
                        UIComponents.Notification(self.ScreenGui, "Fetch failed: " .. tostring(err), "error")
                    end
                end)
            end)
            fetchBtn.LayoutOrder = 1
            
            acceptBtn = UIComponents.Button(actionsRow, "Accept", "success", function()
                if not log.FetchedResponse and not (chunkedText and #chunkedText.GetFullText() > 0) then
                    UIComponents.Notification(self.ScreenGui, "Fetch first", "warning")
                    return
                end
                
                local finalResponse = chunkedText and chunkedText.GetFullText() or getResponseString()
                
                if HttpInterceptor:IsTableResponseType(log.Type) then
                    HttpInterceptor:AcceptResponse(log.Id, {
                        Success = true,
                        StatusCode = 200,
                        StatusMessage = "OK",
                        Headers = {},
                        Body = finalResponse,
                    })
                else
                    HttpInterceptor:AcceptResponse(log.Id, finalResponse)
                end
                
                content.Parent.Parent:Destroy()
                self:RefreshHttpList()
                UIComponents.Notification(self.ScreenGui, "Accepted", "success")
            end)
            acceptBtn.LayoutOrder = 2
            
            UIComponents.Button(actionsRow, "Custom Return", "warning", function()
                self:ShowCustomReturnModal(log)
            end).LayoutOrder = 3
            
            if log.FetchedResponse then
                UIComponents.Button(actionsRow, "Edit Response", nil, function()
                    self:ShowHttpEditModal(log)
                end).LayoutOrder = 4
            end
            
            UIComponents.Button(actionsRow, "Block", "danger", function()
                HttpInterceptor:BlockRequest(log.Id)
                content.Parent.Parent:Destroy()
                self:RefreshHttpList()
                UIComponents.Notification(self.ScreenGui, "Blocked", "info")
            end).LayoutOrder = 5
            
        else
            
            
            if isTableRequest then
                local resendMethod = log.TamperedMethod or log.Method or "GET"
                fetchBtn = UIComponents.Button(actionsRow, "Resend " .. resendMethod, "primary", function()
                    if log.IsFetching then
                        UIComponents.Notification(self.ScreenGui, "Already sending...", "warning")
                        return
                    end
                    
                    log.IsFetching = true
                    UIComponents.Notification(self.ScreenGui, "Resending...", "info")
                    
                    
                    if placeholderLabel then
                        placeholderLabel.Text = "Sending request..."
                    end
                    responseLabel.Text = "Response (sending...)"
                    
                    task.spawn(function()
                        local result, err = HttpInterceptor:ResendRequest(log.Id)
                        log.IsFetching = false
                        
                        if result then
                            
                            log.FetchedResponse = result
                            
                            local respLen = 0
                            if type(result) == "table" and result.Body then
                                respLen = #result.Body
                            elseif type(result) == "string" then
                                respLen = #result
                            end
                            
                            UIComponents.Notification(self.ScreenGui, "Resent! " .. respLen .. " chars", "success")
                            updateResponseDisplay()
                        else
                            UIComponents.Notification(self.ScreenGui, "Failed: " .. tostring(err), "error")
                            responseLabel.Text = "Response (failed)"
                            if placeholderLabel then
                                placeholderLabel.Text = "Request failed:\n" .. tostring(err)
                            end
                        end
                    end)
                end)
                fetchBtn.LayoutOrder = 1
            end
            
            UIComponents.Button(actionsRow, "Copy URL", nil, function()
                local urlToCopy = log.TamperedUrl or log.Url
                copyToClipboard(urlToCopy)
                UIComponents.Notification(self.ScreenGui, "URL copied", "success")
            end).LayoutOrder = 2
        end
    end)
end

function RemoteSpyUI:ShowHttpEditModal(log)
    if not log.FetchedResponse then
        UIComponents.Notification(self.ScreenGui, "Fetch the response first", "warning")
        return
    end
    
    UIComponents.Modal(self.ScreenGui, "Edit Response", UDim2.new(0, 520, 0, 380), function(content)
        createListLayout(content, 10)
        
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundTransparency = 1,
            Text = "Edit the response below, then click Accept to return it to the caller.",
            TextColor3 = Theme.TextSecondary,
            TextSize = 11,
            Font = Theme.FontFamily,
            TextWrapped = true,
            LayoutOrder = 1,
            Parent = content
        })
        
        local inputContainer = createInstance("Frame", {
            Size = UDim2.new(1, 0, 1, -70),
            BackgroundTransparency = 1,
            LayoutOrder = 2,
            Parent = content
        })
        
        local responseStr
        if type(log.FetchedResponse) == "table" then
            if log.FetchedResponse.Body then
                responseStr = log.FetchedResponse.Body
            else
                local success, json = pcall(function()
                    return HttpService:JSONEncode(log.FetchedResponse)
                end)
                responseStr = success and json or tostring(log.FetchedResponse)
            end
        else
            responseStr = tostring(log.FetchedResponse)
        end
        
        local _, inputBox = UIComponents.TextArea(inputContainer, responseStr, "Enter response...")
        
        local btnRow = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundTransparency = 1,
            LayoutOrder = 3,
            Parent = content
        })
        createListLayout(btnRow, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right)
        
        UIComponents.Button(btnRow, "Cancel", nil, function()
            content.Parent.Parent:Destroy()
        end).LayoutOrder = 1
        
        UIComponents.Button(btnRow, "Accept", "success", function()
            local editedText = inputBox.Text
            
            if HttpInterceptor:IsTableResponseType(log.Type) then
                HttpInterceptor:AcceptResponse(log.Id, {
                    Success = true,
                    StatusCode = 200,
                    StatusMessage = "OK",
                    Headers = {},
                    Body = editedText,
                })
            else
                HttpInterceptor:AcceptResponse(log.Id, editedText)
            end
            
            content.Parent.Parent:Destroy()
            self:RefreshHttpList()
            UIComponents.Notification(self.ScreenGui, "Edited response returned to caller", "success")
        end).LayoutOrder = 2
    end)
end

function RemoteSpyUI:ShowCustomReturnModal(log)
    UIComponents.Modal(self.ScreenGui, "Custom Return Value", UDim2.new(0, 450, 0, 300), function(content)
        createListLayout(content, 10)
        
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundTransparency = 1,
            Text = "Enter a custom value to return to the script.\nFor request(), this will be set as the Body of the response.",
            TextColor3 = Theme.TextSecondary,
            TextSize = 11,
            Font = Theme.FontFamily,
            TextWrapped = true,
            LayoutOrder = 1,
            Parent = content
        })
        
        local inputContainer = createInstance("Frame", {
            Size = UDim2.new(1, 0, 1, -80),
            BackgroundTransparency = 1,
            LayoutOrder = 2,
            Parent = content
        })
        
        local _, inputBox = UIComponents.TextArea(inputContainer, "", "Enter return value...")
        
        local btnRow = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundTransparency = 1,
            LayoutOrder = 3,
            Parent = content
        })
        createListLayout(btnRow, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right)
        
        UIComponents.Button(btnRow, "Cancel", nil, function()
            content.Parent.Parent:Destroy()
        end).LayoutOrder = 1
        
        UIComponents.Button(btnRow, "Return Empty", "warning", function()
            HttpInterceptor:BlockRequest(log.Id)
            content.Parent.Parent:Destroy()
            self:RefreshHttpList()
            UIComponents.Notification(self.ScreenGui, "Empty response returned", "info")
        end).LayoutOrder = 2
        
        UIComponents.Button(btnRow, "Accept", "success", function()
            local customValue = inputBox.Text
            
            if HttpInterceptor:IsTableResponseType(log.Type) then
                HttpInterceptor:AcceptResponse(log.Id, {
                    Success = true,
                    StatusCode = 200,
                    StatusMessage = "OK",
                    Headers = {},
                    Body = customValue,
                })
            else
                HttpInterceptor:AcceptResponse(log.Id, customValue)
            end
            
            content.Parent.Parent:Destroy()
            self:RefreshHttpList()
            UIComponents.Notification(self.ScreenGui, "Custom response returned", "success")
        end).LayoutOrder = 3
    end)
end

function RemoteSpyUI:RefreshBlockedList()
    for _, child in ipairs(self.BlockedItemsScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local order = 0
    
    
    for path, _ in pairs(RemoteScanner.BlockedInstances) do
        order = order + 1
        local row = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundColor3 = Theme.BackgroundTertiary,
            BackgroundTransparency = 0.5,
            LayoutOrder = order,
            Parent = self.BlockedItemsScroll
        })
        createCorner(row, Theme.CornerRadiusSmall)
        
        local badge = UIComponents.Badge(row, "BLK", Theme.Danger, 8)
        badge.Position = UDim2.new(0, 4, 0.5, -8)
        
        createInstance("TextLabel", {
            Size = UDim2.new(1, -80, 1, 0),
            Position = UDim2.new(0, 42, 0, 0),
            BackgroundTransparency = 1,
            Text = path,
            TextColor3 = Theme.TextPrimary,
            TextSize = 10,
            Font = Theme.FontFamilyMono,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = row
        })
        
        local removeBtn = UIComponents.IconButton(row, "X", function()
            RemoteScanner:SetBlockInstance(path, false)
            self:RefreshBlockedList()
            self:RefreshRemoteList()
        end, 18)
        removeBtn.Position = UDim2.new(1, -22, 0.5, -9)
    end
    
    
    for path, _ in pairs(RemoteScanner.IgnoredInstances) do
        order = order + 1
        local row = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundColor3 = Theme.BackgroundTertiary,
            BackgroundTransparency = 0.5,
            LayoutOrder = order,
            Parent = self.BlockedItemsScroll
        })
        createCorner(row, Theme.CornerRadiusSmall)
        
        local badge = UIComponents.Badge(row, "IGN", Theme.Warning, 8)
        badge.Position = UDim2.new(0, 4, 0.5, -8)
        
        createInstance("TextLabel", {
            Size = UDim2.new(1, -80, 1, 0),
            Position = UDim2.new(0, 44, 0, 0),
            BackgroundTransparency = 1,
            Text = path,
            TextColor3 = Theme.TextPrimary,
            TextSize = 10,
            Font = Theme.FontFamilyMono,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = row
        })
        
        local removeBtn = UIComponents.IconButton(row, "X", function()
            RemoteScanner:SetIgnoreInstance(path, false)
            self:RefreshBlockedList()
            self:RefreshRemoteList()
        end, 18)
        removeBtn.Position = UDim2.new(1, -22, 0.5, -9)
    end
    
    
    for url, _ in pairs(HttpInterceptor.BlockedUrls) do
        order = order + 1
        local row = createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundColor3 = Theme.BackgroundTertiary,
            BackgroundTransparency = 0.5,
            LayoutOrder = order,
            Parent = self.BlockedItemsScroll
        })
        createCorner(row, Theme.CornerRadiusSmall)
        
        local badge = UIComponents.Badge(row, "URL", Theme.Cyan, 8)
        badge.Position = UDim2.new(0, 4, 0.5, -8)
        
        createInstance("TextLabel", {
            Size = UDim2.new(1, -80, 1, 0),
            Position = UDim2.new(0, 44, 0, 0),
            BackgroundTransparency = 1,
            Text = url,
            TextColor3 = Theme.TextPrimary,
            TextSize = 10,
            Font = Theme.FontFamilyMono,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = row
        })
        
        local removeBtn = UIComponents.IconButton(row, "X", function()
            HttpInterceptor:SetUrlBlocked(url, false)
            self:RefreshBlockedList()
        end, 18)
        removeBtn.Position = UDim2.new(1, -22, 0.5, -9)
    end
    
    if order == 0 then
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "No blocked or ignored items",
            TextColor3 = Theme.TextMuted,
            TextSize = 11,
            Font = Theme.FontFamily,
            Parent = self.BlockedItemsScroll
        })
    end
    
    
    self.BlockedListFrame.Size = UDim2.new(1, 0, 0, math.max(80, math.min(order * 27 + 12, 160)))
end

function RemoteSpyUI:_restoreFromMinimized()
    if not self.MainFrame or not self.IsMinimized then
        return
    end
    self.IsMinimized = false
    self.IsMaximized = false
    local restoreSize = self.OriginalSize or self.DefaultSize
    local w, h = self:ClampWindowSize(restoreSize.X.Offset, restoreSize.Y.Offset)
    restoreSize = UDim2.new(0, w, 0, h)
    self.OriginalSize = restoreSize
    tween(self.MainFrame, {Size = restoreSize}, 0.3)
    self:_syncMinimizeButtonIcon()
    task.delay(0.15, function()
        if self._destroying then
            return
        end
        if self.ContentFrame then
            self.ContentFrame.Visible = true
        end
        if self.Sidebar then
            self.Sidebar.Visible = true
        end
        if self.ResizeHandle then
            self.ResizeHandle.Visible = true
        end
    end)
end

function RemoteSpyUI:ToggleMinimize()
    local titleH = Theme.TitleBarHeight or 44
    if not self.MainFrame then
        return
    end
    if self.IsMinimized then
        self:_restoreFromMinimized()
        return
    end
    self.IsMinimized = true
    self.IsMaximized = false
    self.OriginalSize = self.MainFrame.Size
    self.OriginalPosition = self.MainFrame.Position
    tween(self.MainFrame, {Size = UDim2.new(0, 300, 0, titleH)}, 0.3)
    if self.ContentFrame then
        self.ContentFrame.Visible = false
    end
    if self.Sidebar then
        self.Sidebar.Visible = false
    end
    if self.ResizeHandle then
        self.ResizeHandle.Visible = false
    end
    self:_syncMinimizeButtonIcon()
end

function RemoteSpyUI:ToggleMaximize()
    -- Same control as minimize: restore when collapsed (no separate fullscreen).
    self:ToggleMinimize()
end

function RemoteSpyUI:MakeDraggable()
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    self:_trackConnection(self.TitleBar.InputBegan:Connect(function(input)
        if self._destroying or not self.MainFrame then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = self.MainFrame.Position
        end
    end))
    
    self:_trackConnection(self.TitleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                if not self._destroying then
                    self:SaveWindowGeometry()
                end
            end
        end
    end))
    
    self:_trackConnection(UserInputService.InputChanged:Connect(function(input)
        if not dragging or self._destroying or not self.MainFrame or not self.MainFrame.Parent then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement or 
           input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            self.MainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end))
end

function RemoteSpyUI:MakeResizable()
    local windowR = Theme.Radius.Window or 16
    local visualSize = math.max(20, math.floor(windowR * 0.95 + 0.5))
    local hitPad = 16
    -- Gap between window silhouette and the painted arc (independent of hitPad).
    local clearance = 5
    local hostSize = visualSize + hitPad * 2
    local visualOutset = math.floor(visualSize * 0.4 + 0.5) + clearance
    local outset = visualOutset + hitPad
    local resizeHandle = createInstance("Frame", {
        Name = "ResizeHandle",
        Size = UDim2.new(0, hostSize, 0, hostSize),
        Position = UDim2.new(1, outset, 1, outset),
        AnchorPoint = Vector2.new(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 99,
        Active = false,
        Parent = self.MainFrame,
    })
    self.ResizeHandle = resizeHandle

    local gripUrl = getAssetImage("resize.png")
    local grip = createInstance("ImageLabel", {
        Name = "Grip",
        Size = UDim2.new(0, visualSize, 0, visualSize),
        Position = UDim2.new(1, -hitPad, 1, -hitPad),
        AnchorPoint = Vector2.new(1, 1),
        BackgroundTransparency = 1,
        Image = gripUrl or "",
        ImageColor3 = Color3.new(1, 1, 1),
        ImageTransparency = 0.7,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 100,
        Active = false,
        Parent = resizeHandle,
    })

    
    local function pointOnCornerArc(screenX, screenY)
        local absPos = grip.AbsolutePosition
        local absSize = grip.AbsoluteSize
        if absSize.X <= 0 or absSize.Y <= 0 then
            return false
        end
        local pad = absSize.X * (6 / 64)
        local midR = absSize.X * (36 / 64)
        local halfStroke = math.max(14, absSize.X * 0.55)
        local cx = absPos.X + pad
        local cy = absPos.Y + pad
        local dx = screenX - cx
        local dy = screenY - cy
        if dx < -hitPad or dy < -hitPad then
            return false
        end
        local dist = math.sqrt(dx * dx + dy * dy)
        return dist >= math.max(0, midR - halfStroke) and dist <= (midR + halfStroke)
    end

    local resizing = false
    local resizeStart = nil
    local startSize = nil
    local hovering = false

    local function setGripHover(on)
        if hovering == on and not resizing then
            return
        end
        hovering = on
        if resizing then
            return
        end
        tween(grip, {ImageTransparency = on and 0.25 or 0.75}, on and 0.1 or 0.17)
    end

    self:_trackConnection(UserInputService.InputBegan:Connect(function(input)
        if self._destroying or not self.MainFrame then
            return
        end
        if self.IsMaximized or self.IsMinimized or not resizeHandle.Visible then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        if not pointOnCornerArc(input.Position.X, input.Position.Y) then
            return
        end
        resizing = true
        resizeStart = input.Position
        startSize = self.MainFrame.Size
        tween(grip, {ImageTransparency = 0.2}, 0.1)
    end))

    self:_trackConnection(UserInputService.InputChanged:Connect(function(input)
        if self._destroying or not resizeHandle.Parent then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        if resizing then
            local delta = input.Position - resizeStart
            local scale = self.UIScale or 1.0
            local newWidth, newHeight = self:ClampWindowSize(
                startSize.X.Offset + delta.X / scale,
                startSize.Y.Offset + delta.Y / scale
            )
            if self.MainFrame and self.MainFrame.Parent then
                self.MainFrame.Size = UDim2.new(0, newWidth, 0, newHeight)
            end
            return
        end
        if self.IsMaximized or self.IsMinimized or not resizeHandle.Visible then
            setGripHover(false)
            return
        end
        setGripHover(pointOnCornerArc(input.Position.X, input.Position.Y))
    end))

    self:_trackConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        if not resizing then
            return
        end
        resizing = false
        local stillOn = pointOnCornerArc(input.Position.X, input.Position.Y)
        tween(grip, {ImageTransparency = stillOn and 0.25 or 0.75}, 0.17)
        hovering = stillOn
        if not self._destroying then
            self:SaveWindowGeometry()
        end
    end))
end

function RemoteSpyUI:UpdateTextScale()
    local scale = self.TextScale or 1.0
    
    local function updateDescendants(parent)
        for _, child in ipairs(parent:GetDescendants()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                
                if not child:GetAttribute("BaseTextSize") then
                    child:SetAttribute("BaseTextSize", child.TextSize)
                end
                
                local baseSize = child:GetAttribute("BaseTextSize")
                child.TextSize = math.floor(baseSize * scale + 0.5)
            end
        end
    end
    
    if self.MainFrame then
        updateDescendants(self.MainFrame)
    end
end

function RemoteSpyUI:Destroy(options)
    options = options or {}
    if self._destroying and not options.force then
        return
    end
    if options.defer ~= false then
        task.defer(function()
            self:Destroy({ defer = false, force = options.force })
        end)
        return
    end

    self._destroying = true
    self._httpPendingPollGen = (self._httpPendingPollGen or 0) + 1
    HttpInterceptor._shuttingDown = true

    
    self:_clearModuleCallbacks()
    self:_disconnectTrackedConnections()
    if self._remoteRefreshConn then
        pcall(function()
            self._remoteRefreshConn:Disconnect()
        end)
        self._remoteRefreshConn = nil
    end
    if self._httpRefreshConn then
        pcall(function()
            self._httpRefreshConn:Disconnect()
        end)
        self._httpRefreshConn = nil
    end
    self._httpEntriesById = {}
    self._argEntryMap = {}
    self._lastArgsPanelSig = nil
    self._detailsLogId = nil
    self._remoteDirty = false
    self._httpDirty = false
    spyCleanupFrame()

    
    if self.ScreenGui then
        pcall(function()
            self.ScreenGui.Enabled = false
        end)
    end
    spyCleanupFrame()
    self:_destroyFloatedDropdowns()
    if self.ScreenGui then
        pcall(function()
            self.ScreenGui:Destroy()
        end)
        self.ScreenGui = nil
    end
    self.MainFrame = nil
    spyCleanupFrame()

    
    pcall(function()
        HttpInterceptor:Stop()
    end)
    pcall(function()
        RemoteScanner:StopSpying()
    end)
    pcall(function()
        HttpInterceptor:ReleaseAllPending()
    end)
    pcall(function()
        ModuleExplorer:CancelScan()
    end)
    spyCleanupFrame()
    spyCleanupFrame()

    
    pcall(function()
        HttpInterceptor:UninstallHooks()
    end)
    spyCleanupFrame()

    
    pcall(function()
        RemoteScanner:PurgeAll()
    end)
    pcall(function()
        HttpInterceptor:PurgeAll()
    end)
    pcall(function()
        ModuleExplorer:PurgeAll()
    end)
    pcall(function()
        RequireScanner:PurgeAll()
    end)

    HttpInterceptor._shuttingDown = false
    HttpInterceptor._pendingReleased = false
end

local UI = RemoteSpyUI:Create()
if not UI and not Players.LocalPlayer then
    Players.PlayerAdded:Wait()
    UI = RemoteSpyUI:Create()
end

local SpyTool = {
    UI = RemoteSpyUI,
    ScreenGui = UI,
    RemoteScanner = RemoteScanner,
    HttpInterceptor = HttpInterceptor,
    ModuleExplorer = ModuleExplorer,
    RequireScanner = RequireScanner,
    SpyStealth = SpyStealth,
    copyToClipboard = copyToClipboard,
    formatRobloxPath = formatRobloxPath,
    formatInstancePath = formatInstancePath,
    Destroy = function(options)
        options = options or {}
        local function finish()
            RemoteSpyUI:Destroy({ defer = false, force = options.force })
            getSpyGenv()[SPYTOOL_GENV_KEY] = nil
        end
        if options.defer == false then
            finish()
        else
            task.defer(finish)
        end
    end,
}

getSpyGenv()[SPYTOOL_GENV_KEY] = SpyTool

return SpyTool