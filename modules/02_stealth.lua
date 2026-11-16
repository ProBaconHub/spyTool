-- spyTool/modules/02_stealth.lua

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
