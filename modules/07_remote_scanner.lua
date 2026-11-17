-- spyTool/modules/07_remote_scanner.lua

local RemoteScanner = {
    FoundRemotes = {},
    GroupedLogs = {},  
    SpyConnections = {},
    HookBackups = {},
    
    IsSpying = false,
    MaxLogs = 1000,
    MaxLogsPerRemote = 200,
    MaxLogsPerArgGroup = 50,
    
    SortMode = "calls", 
    
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
    if type(safeGetconnections) == "function" and signal ~= nil then
        local ok, connections = pcall(safeGetconnections, signal)
        if ok and type(connections) == "table" then
            return connections
        end
    end
    return {}
end

local function isBindableType(remoteType)
    return remoteType == "BindableEvent" or remoteType == "BindableFunction"
end

local function isDirectionalType(remoteType)
    return remoteType == "RemoteEvent"
        or remoteType == "UnreliableRemoteEvent"
        or remoteType == "RemoteFunction"
end

function RemoteScanner:RefreshConnectionInfo(data)
    if not data or typeof(data.Instance) ~= "Instance" then
        return data
    end
    local remote = data.Instance
    local connections = {}
    local listeners = {}
    if data.Type == "RemoteEvent" or data.Type == "UnreliableRemoteEvent" then
        connections = self:GetConnections(remote.OnClientEvent)
    elseif data.Type == "BindableEvent" then
        connections = self:GetConnections(remote.Event)
    end
    for index, connection in ipairs(connections) do
        local fn = connection and connection.Function
        local listener = {
            Index = index,
            Enabled = connection.Enabled,
            ForeignState = connection.ForeignState,
            Function = typeof(fn) == "function" and fn or nil,
            Info = nil,
        }
        if typeof(fn) == "function" then
            listener.Info = FunctionAnalyzer:GetInfo(fn)
        end
        listeners[#listeners + 1] = listener
    end
    data.Connections = connections
    data.Listeners = listeners
    data.ConnectionCount = #listeners
    return data
end

function RemoteScanner.CaptureCallerFunction()
    local rawInfo = (SpyStealth and SpyStealth.DebugInfoBypass) or debug.info
    if type(rawInfo) ~= "function" then
        return nil
    end
    -- pcall(rawInfo, level, "f") makes level 1 = CaptureCallerFunction.
    -- Skip our own frames / chunk, then return the first real game caller.
    for level = 2, 18 do
        local ok, fn = pcall(rawInfo, level, "f")
        if not ok or typeof(fn) ~= "function" then
            break
        end
        local okSrc, source = pcall(rawInfo, fn, "s")
        source = (okSrc and source) or ""
        if type(source) == "string" then
            local lower = source:lower()
            local isInternal = source == ""
                or lower:find("spytool", 1, true) ~= nil
                or lower:find("probaconhub", 1, true) ~= nil
            if not isInternal then
                return fn
            end
        end
    end
    return nil
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
    if isDirectionalType(baseType) then
        if isIncoming then
            if not self.DirectionFilters.Incoming then
                return nil
            end
        elseif not self.DirectionFilters.Outgoing then
            return nil
        end
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
    local remotes = self:GetAllRemotes()
    local nextFound = {}

    for _, data in ipairs(remotes) do
        local remote = data.Instance
        local remoteType = data.Type
        local path = getCachedInstancePath(remote)

        local remoteInfo = {
            Instance = remote,
            Path = path,
            Name = remote.Name,
            Type = remoteType,
            ConnectionCount = 0,
            Connections = {},
            Listeners = {},
        }
        self:RefreshConnectionInfo(remoteInfo)
        nextFound[path] = remoteInfo

        local group = self.GroupedLogs[path]
        if group then
            group.Info = remoteInfo
        else
            self.GroupedLogs[path] = {
                Info = remoteInfo,
                ArgGroups = {},
                TotalCalls = 0,
                FirstCall = nil,
                LastCall = nil,
                LastCallTick = 0,
                Expanded = false,
            }
        end
    end

    self.FoundRemotes = nextFound

    -- Rescan while spying must re-arm hooks for newly discovered remotes.
    if self.IsSpying then
        self:RebindIncomingHooks()
    end

    return self.FoundRemotes
end

function RemoteScanner:RebindIncomingHooks()
    local hook = self._hookIncoming
    if type(hook) ~= "function" or not self.IsSpying then
        return
    end
    for path, data in pairs(self.FoundRemotes) do
        pcall(hook, data.Instance, data, path)
        if self.BlockedInstances[path] then
            self:ApplyIncomingBlockState(path)
        end
    end
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
                local property = backup.Property
                    or (backup.Type == "OnClientInvoke" and "OnClientInvoke")
                    or (backup.Type == "OnInvoke" and "OnInvoke")
                if property and data.Instance[property] == backup.Wrapper then
                    data.Instance[property] = backup.Original
                elseif property and backup.Original ~= nil then
                    -- Only restore if still our wrapper or original was non-nil.
                    if data.Instance[property] == backup.Wrapper then
                        data.Instance[property] = backup.Original
                    end
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
    local bindable = isBindableType(baseType)
    local directional = isDirectionalType(baseType)
    
    
    if self.IgnoredInstances[path] then
        return nil
    end
    
    if self.IgnoredArgs[path] and self.IgnoredArgs[path][argHash] then
        return nil
    end
    
    if not self.EnabledFilters[baseType] then
        return nil
    end
    
    if directional then
        if isIncoming and not self.DirectionFilters.Incoming then
            return nil
        end
        if not isIncoming and not self.DirectionFilters.Outgoing then
            return nil
        end
    end
    
    local now = tick()
    local timestamp = getTimestamp()
    
    -- Bindables are local signals/calls — never label them Incoming/Outgoing.
    local displayType = baseType
    if directional and isIncoming then
        displayType = baseType .. " (Incoming)"
    end
    
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
        ArgumentCount = (type(args) == "table" and (args.n or #args)) or 0,
        ArgHash = argHash,
        CallerFunction = callerFunc,
        CallerInfo = nil, 
        ReturnValue = returnValue,
        Blocked = (queuedInfo and queuedInfo.Blocked) == true,
        IsIncoming = (not bindable) and (isIncoming or false) or false,
        IsBindable = bindable,
    }
    
    if not self.GroupedLogs[path] then
        local info = self.FoundRemotes[path]
        if not info then
            info = {
                Instance = remote,
                Path = path,
                Name = remoteName,
                Type = baseType,
                ConnectionCount = 0,
                Connections = {},
                Listeners = {},
            }
            self:RefreshConnectionInfo(info)
        end
        self.GroupedLogs[path] = {
            Info = info,
            ArgGroups = {},
            TotalCalls = 0,
            FirstCall = nil,
            LastCall = nil,
            LastCallTick = 0,
            Expanded = false,
        }
    end
    
    local group = self.GroupedLogs[path]
    
    group.TotalCalls = group.TotalCalls + 1
    group.LastCall = timestamp
    group.LastCallTick = now
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
            LastCallTick = 0,
            Expanded = false,
            HasIncoming = false,
            HasOutgoing = false,
        }
        group._argGroupsDirty = true
    end
    
    local argGroup = group.ArgGroups[argHash]
    argGroup.CachedArgs = cachedArguments
    
    if directional then
        if isIncoming then
            argGroup.HasIncoming = true
            group.HasIncomingLogs = true
        else
            argGroup.HasOutgoing = true
            group.HasOutgoingLogs = true
        end
    end
    
    table.insert(argGroup.Logs, 1, log)
    argGroup.Count = argGroup.Count + 1
    argGroup.LastCall = timestamp
    argGroup.LastCallTick = now
    
    -- Latest sort depends on LastCallTick; keep cache fresh for both modes.
    group._argGroupsDirty = true
    group._sortedArgGroupsCache = nil
    
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
                LastCallTick = group.LastCallTick or group.FirstCall or 0,
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

    local infoType = group.Info and group.Info.Type or ""
    local bindable = isBindableType(infoType)
    
    local argGroups = {}
    for argHash, argGroup in pairs(group.ArgGroups) do
        local hasVisibleLog = false
        if bindable then
            hasVisibleLog = argGroup.Count > 0
        elseif self.DirectionFilters.Incoming and self.DirectionFilters.Outgoing then
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
                LastCallTick = argGroup.LastCallTick or argGroup.FirstCall or 0,
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
    local hash = argHash or (args and hashArgs(args)) or nil
    if not hash then
        return false
    end
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
    local hash = argHash or (args and hashArgs(args)) or nil
    if not hash then
        return nil
    end
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
    local blocked = self:ShouldBlock(path, args, argHash)
    return path, blocked, argHash, false
end

function RemoteScanner:ApplyIncomingBlockState(path)
    local data = self.FoundRemotes[path]
    if not data or typeof(data.Instance) ~= "Instance" then
        return
    end
    local blocked = self.BlockedInstances[path] == true
    local remote = data.Instance
    local signal
    if data.Type == "RemoteEvent" or data.Type == "UnreliableRemoteEvent" then
        signal = remote.OnClientEvent
    elseif data.Type == "BindableEvent" then
        signal = remote.Event
    else
        return
    end

    local spyConns = {}
    local state = self.RemoteConnectionStates and self.RemoteConnectionStates[remote]
    if state and state.Connections then
        for _, conn in ipairs(state.Connections) do
            spyConns[conn] = true
        end
    end

    for _, connection in ipairs(self:GetConnections(signal)) do
        if not spyConns[connection] then
            pcall(function()
                if blocked then
                    if connection.Disable then
                        connection:Disable()
                    end
                elseif connection.Enable then
                    connection:Enable()
                end
            end)
        end
    end
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
    
    
    local function installCallbackHook(remote, data, path, propertyName, backupType)
        local scanner = self
        local remoteName = remote.Name
        local function makeWrapper(currentOriginal)
            local wrapper
            wrapper = function(...)
                local backup = scanner.HookBackups[path]
                local original = currentOriginal
                if backup then
                    original = backup.Original or currentOriginal
                end
                local args = table.pack(...)
                local blocked = scanner:ShouldBlock(path, args)
                if scanner.IsSpying and (scanner.IncomingLogSuppressDepth or 0) == 0 then
                    -- RemoteFunction is directional incoming; BindableFunction is local.
                    local asIncoming = data.Type == "RemoteFunction"
                    scanner:QueueLog(
                        remote,
                        data.Type,
                        args,
                        nil,
                        nil,
                        asIncoming,
                        blocked,
                        path,
                        remoteName
                    )
                end
                if blocked then
                    return scanner:GetBypassReturn(path, args)
                end
                if type(original) == "function" then
                    return original(table.unpack(args, 1, args.n))
                end
            end
            return wrapper
        end

        local original = remote[propertyName]
        local wrapper = makeWrapper(original)
        self.HookBackups[path] = {
            Type = backupType,
            Original = original,
            Wrapper = wrapper,
            Property = propertyName,
        }
        remote[propertyName] = wrapper
    end

    local function hookIncoming(remote, data, path)
        if not remote or not remote.Parent then
            return
        end
        local state = ensureRemoteState(remote, path)
        local remoteName = remote.Name

        -- BindableEvent: no incoming/outgoing taps. Listeners are listed in info.
        if data.Type == "BindableEvent" then
            self:RefreshConnectionInfo(data)
            return
        end

        if data.Type == "RemoteEvent" or data.Type == "UnreliableRemoteEvent" then
            if state.IncomingConnected then
                return
            end
            local signal = remote.OnClientEvent
            local success, conn = pcall(function()
                return signal:Connect(function(...)
                    if not self.IsSpying then
                        return
                    end
                    local args = table.pack(...)
                    local blocked = self:ShouldBlock(path, args)
                    self:QueueLog(remote, data.Type, args, nil, nil, true, blocked, path, remoteName)
                    if blocked then
                        -- Other listeners are disabled via ApplyIncomingBlockState when instance-blocked.
                        return
                    end
                end)
            end)
            if success and conn then
                state.Connections[#state.Connections + 1] = conn
                state.IncomingConnected = true
                -- Keep our spy connection enabled if the executor exposes Enable.
                pcall(function()
                    if conn.Enable then
                        conn:Enable()
                    end
                end)
            end
            self:RefreshConnectionInfo(data)
        elseif data.Type == "RemoteFunction" then
            local backup = self.HookBackups[path]
            if not (backup and remote.OnClientInvoke == backup.Wrapper) then
                installCallbackHook(remote, data, path, "OnClientInvoke", "OnClientInvoke")
            end
        elseif data.Type == "BindableFunction" then
            local backup = self.HookBackups[path]
            if not (backup and remote.OnInvoke == backup.Wrapper) then
                installCallbackHook(remote, data, path, "OnInvoke", "OnInvoke")
            end
        end
    end

    self._hookIncoming = hookIncoming
    
    
    for path, data in pairs(self.FoundRemotes) do
        hookIncoming(data.Instance, data, path)
        if self.BlockedInstances[path] then
            self:ApplyIncomingBlockState(path)
        end
    end

    -- Re-apply callback hooks if games overwrite OnClientInvoke / OnInvoke after us.
    local maintainConn = RunService.Heartbeat:Connect(function()
        if not self.IsSpying then
            return
        end
        self._incomingMaintainAccum = (self._incomingMaintainAccum or 0) + 1
        if self._incomingMaintainAccum < 30 then
            return
        end
        self._incomingMaintainAccum = 0
        for path, data in pairs(self.FoundRemotes) do
            if data.Type == "RemoteFunction" or data.Type == "BindableFunction" then
                local backup = self.HookBackups[path]
                local property = data.Type == "RemoteFunction" and "OnClientInvoke" or "OnInvoke"
                local current = data.Instance and data.Instance[property]
                if not backup or current ~= backup.Wrapper then
                    hookIncoming(data.Instance, data, path)
                end
            end
        end
    end)
    table.insert(self.SpyConnections, maintainConn)
    
    
    
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
                    local data = {
                        Instance = descendant,
                        Path = path,
                        Name = descendant.Name,
                        Type = remoteType,
                        ConnectionCount = 0,
                        Connections = {},
                        Listeners = {},
                    }
                    self:RefreshConnectionInfo(data)
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
    self:ApplyIncomingBlockState(path)
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
    local args = log.Arguments or {}
    local argc = args.n or log.ArgumentCount or #args
    local remoteType = log.RemoteType:gsub(" %(Incoming%)", "")
    local isIncoming = log.IsIncoming
    
    local success, result = pcall(function()
        if isIncoming then
            return self:WithIncomingLogSuppressed(function()
                if remoteType == "RemoteEvent" or remoteType == "UnreliableRemoteEvent" then
                    if firesignal then
                        return firesignal(remote.OnClientEvent, table.unpack(args, 1, argc))
                    end
                    return nil
                elseif remoteType == "BindableEvent" then
                    if firesignal then
                        return firesignal(remote.Event, table.unpack(args, 1, argc))
                    end
                    return nil
                elseif remoteType == "RemoteFunction" then
                    if type(remote.OnClientInvoke) == "function" then
                        return remote.OnClientInvoke(table.unpack(args, 1, argc))
                    end
                    return nil
                elseif remoteType == "BindableFunction" then
                    if type(remote.OnInvoke) == "function" then
                        return remote.OnInvoke(table.unpack(args, 1, argc))
                    end
                    return nil
                end
            end)
        else
            
            if remoteType == "RemoteEvent" or remoteType == "UnreliableRemoteEvent" then
                return remote:FireServer(table.unpack(args, 1, argc))
            elseif remoteType == "RemoteFunction" then
                return remote:InvokeServer(table.unpack(args, 1, argc))
            elseif remoteType == "BindableEvent" then
                return remote:Fire(table.unpack(args, 1, argc))
            elseif remoteType == "BindableFunction" then
                return remote:Invoke(table.unpack(args, 1, argc))
            end
        end
    end)
    
    return success, result
end

local function resolveGeneratedRemoteExpr(log)
    if not log then
        return nil
    end
    if typeof(log.Remote) == "Instance" then
        local expr = formatRobloxPath(log.Remote)
        if isUsablePathExpr(expr) then
            return expr
        end
    end
    local expr = formatRobloxPath(log.RemotePath)
    if isUsablePathExpr(expr) then
        return expr
    end
    return nil
end

local function resolveGeneratedArgCount(log)
    if type(log.Arguments) == "table" and type(log.Arguments.n) == "number" then
        return log.Arguments.n
    end
    if type(log.CachedArguments) == "table" and type(log.CachedArguments.n) == "number" then
        return log.CachedArguments.n
    end
    if type(log.CachedArguments) == "table" then
        return #log.CachedArguments
    end
    return log.ArgumentCount or 0
end

local GENERATED_DUMP_HELPER = [[
local function dump(tag, args)
    local n = args.n or #args
    local parts = table.create(n)
    for i = 1, n do
        local ok, text = pcall(tostring, args[i])
        parts[i] = ok and text or typeof(args[i])
    end
    print(tag, table.concat(parts, ", "))
end
]]

function RemoteScanner:GenerateFireScript(log)
    if not log then
        return ""
    end

    local remoteExpr = resolveGeneratedRemoteExpr(log)
    if not remoteExpr then
        return ""
    end

    local remoteType = log.RemoteType:gsub(" %(Incoming%)", "")
    local isIncoming = log.IsIncoming
    local argc = resolveGeneratedArgCount(log)
    local lines = {
        "local remote = " .. remoteExpr,
    }

    if argc > 0 then
        table.insert(lines, "local args = {")
        for i = 1, argc do
            local arg = log.Arguments and log.Arguments[i]
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
                    serialized = (success and result and result:gsub("\n", "\n    ")) or "{}"
                else
                    serialized = serializeValue(arg, 1)
                end
            end
            if serialized == nil then
                serialized = "nil"
            end
            table.insert(lines, "    " .. serialized .. (i < argc and "," or ""))
        end
        table.insert(lines, "}")
        table.insert(lines, "local argc = " .. tostring(argc))
    end

    local unpackExpr = argc > 0 and "table.unpack(args, 1, argc)" or ""

    if isIncoming then
        if remoteType == "RemoteEvent" or remoteType == "UnreliableRemoteEvent" then
            table.insert(lines, argc > 0 and ([[
local signal = remote.OnClientEvent
if firesignal then
    firesignal(signal, ]] .. unpackExpr .. [[)
elseif typeof(getconnections) == "function" then
    for _, connection in ipairs(getconnections(signal)) do
        local fn = connection.Function
        if typeof(fn) == "function" then
            task.spawn(fn, ]] .. unpackExpr .. [[)
        end
    end
end]]) or ([[
local signal = remote.OnClientEvent
if firesignal then
    firesignal(signal)
elseif typeof(getconnections) == "function" then
    for _, connection in ipairs(getconnections(signal)) do
        local fn = connection.Function
        if typeof(fn) == "function" then
            task.spawn(fn)
        end
    end
end]]))
        elseif remoteType == "BindableEvent" then
            table.insert(lines, argc > 0 and ([[
local signal = remote.Event
if firesignal then
    firesignal(signal, ]] .. unpackExpr .. [[)
elseif typeof(getconnections) == "function" then
    for _, connection in ipairs(getconnections(signal)) do
        local fn = connection.Function
        if typeof(fn) == "function" then
            task.spawn(fn, ]] .. unpackExpr .. [[)
        end
    end
end]]) or ([[
local signal = remote.Event
if firesignal then
    firesignal(signal)
elseif typeof(getconnections) == "function" then
    for _, connection in ipairs(getconnections(signal)) do
        local fn = connection.Function
        if typeof(fn) == "function" then
            task.spawn(fn)
        end
    end
end]]))
        elseif remoteType == "RemoteFunction" then
            table.insert(lines, argc > 0
                and ("local cb = remote.OnClientInvoke\nif typeof(cb) == \"function\" then\n    return cb(" .. unpackExpr .. ")\nend")
                or "local cb = remote.OnClientInvoke\nif typeof(cb) == \"function\" then\n    return cb()\nend")
        elseif remoteType == "BindableFunction" then
            table.insert(lines, argc > 0
                and ("local cb = remote.OnInvoke\nif typeof(cb) == \"function\" then\n    return cb(" .. unpackExpr .. ")\nend")
                or "local cb = remote.OnInvoke\nif typeof(cb) == \"function\" then\n    return cb()\nend")
        end
    else
        if remoteType == "RemoteEvent" or remoteType == "UnreliableRemoteEvent" then
            table.insert(lines, argc > 0
                and ("remote:FireServer(" .. unpackExpr .. ")")
                or "remote:FireServer()")
        elseif remoteType == "RemoteFunction" then
            table.insert(lines, argc > 0
                and ("local results = table.pack(remote:InvokeServer(" .. unpackExpr .. "))\nprint(table.unpack(results, 1, results.n))")
                or "local results = table.pack(remote:InvokeServer())\nprint(table.unpack(results, 1, results.n))")
        elseif remoteType == "BindableEvent" then
            table.insert(lines, argc > 0
                and ("remote:Fire(" .. unpackExpr .. ")")
                or "remote:Fire()")
        elseif remoteType == "BindableFunction" then
            table.insert(lines, argc > 0
                and ("local results = table.pack(remote:Invoke(" .. unpackExpr .. "))\nprint(table.unpack(results, 1, results.n))")
                or "local results = table.pack(remote:Invoke())\nprint(table.unpack(results, 1, results.n))")
        end
    end

    return table.concat(lines, "\n")
end

function RemoteScanner:GenerateInterceptScript(log)
    if not log then
        return "", false
    end

    local remoteExpr = resolveGeneratedRemoteExpr(log)
    if not remoteExpr then
        return "", false
    end

    local remoteType = log.RemoteType:gsub(" %(Incoming%)", "")
    local isIncoming = log.IsIncoming == true
    local useNamecall = isHookmetamethodSupported()
    local useHookfunction = isHookfunctionSupported()

    local mode
    if isIncoming then
        if remoteType == "RemoteFunction" or remoteType == "BindableFunction" then
            mode = "callback"
        else
            mode = "getconnections"
        end
    elseif useNamecall then
        mode = "hookmetamethod"
    elseif useHookfunction then
        mode = "hookfunction"
    else
        mode = "wrapper"
    end

    local lines = {
        "local remote = " .. remoteExpr,
        "",
        GENERATED_DUMP_HELPER,
    }
    appendInterceptHookHeader(lines, mode)

    local function outgoingMethods()
        if remoteType == "RemoteEvent" or remoteType == "UnreliableRemoteEvent" then
            return { namecall = "FireServer", index = "FireServer" }
        elseif remoteType == "RemoteFunction" then
            return { namecall = "InvokeServer", index = "InvokeServer" }
        elseif remoteType == "BindableEvent" then
            return { namecall = "Fire", index = "Fire" }
        elseif remoteType == "BindableFunction" then
            return { namecall = "Invoke", index = "Invoke" }
        end
        return nil
    end

    if isIncoming then
        if remoteType == "RemoteEvent" or remoteType == "UnreliableRemoteEvent" then
            table.insert(lines, [[
assert(typeof(getconnections) == "function", "getconnections required")
local signal = remote.OnClientEvent
local originals = {}
for _, connection in ipairs(getconnections(signal)) do
    local fn = connection.Function
    if typeof(fn) == "function" then
        originals[#originals + 1] = fn
        pcall(function()
            if connection.Disable then
                connection:Disable()
            elseif connection.Disconnect then
                connection:Disconnect()
            end
        end)
    end
end

signal:Connect(function(...)
    local args = table.pack(...)
    dump("[Spy]", args)
    for i = 1, #originals do
        task.spawn(originals[i], table.unpack(args, 1, args.n))
    end
end)
]])
        elseif remoteType == "BindableEvent" then
            table.insert(lines, [[
assert(typeof(getconnections) == "function", "getconnections required")
local signal = remote.Event
local originals = {}
for _, connection in ipairs(getconnections(signal)) do
    local fn = connection.Function
    if typeof(fn) == "function" then
        originals[#originals + 1] = fn
        pcall(function()
            if connection.Disable then
                connection:Disable()
            elseif connection.Disconnect then
                connection:Disconnect()
            end
        end)
    end
end

signal:Connect(function(...)
    local args = table.pack(...)
    dump("[Spy]", args)
    for i = 1, #originals do
        task.spawn(originals[i], table.unpack(args, 1, args.n))
    end
end)
]])
        elseif remoteType == "RemoteFunction" then
            table.insert(lines, [[
local original = remote.OnClientInvoke
remote.OnClientInvoke = function(...)
    local args = table.pack(...)
    dump("[Spy]", args)
    if typeof(original) ~= "function" then
        return
    end
    return original(table.unpack(args, 1, args.n))
end
]])
        elseif remoteType == "BindableFunction" then
            table.insert(lines, [[
local original = remote.OnInvoke
remote.OnInvoke = function(...)
    local args = table.pack(...)
    dump("[Spy]", args)
    if typeof(original) ~= "function" then
        return
    end
    return original(table.unpack(args, 1, args.n))
end
]])
        else
            return "", false
        end
    else
        local methods = outgoingMethods()
        if not methods then
            return "", false
        end

        if mode == "hookmetamethod" then
            -- __namecall only: covers remote:Method(...) without taxing every __index
            table.insert(lines, string.format([[
local METHOD = %q
local wrap = newcclosure or function(fn)
    return fn
end

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", wrap(function(self, ...)
    if self ~= remote or getnamecallmethod() ~= METHOD or (checkcaller and checkcaller()) then
        return oldNamecall(self, ...)
    end
    local args = table.pack(...)
    dump("[Spy] " .. METHOD, args)
    return oldNamecall(self, table.unpack(args, 1, args.n))
end))
]], methods.namecall))
        elseif mode == "hookfunction" then
            table.insert(lines, string.format([[
local proxy = Instance.new(%q)
local oldMethod
oldMethod = hookfunction(proxy[%q], function(self, ...)
    if self ~= remote then
        return oldMethod(self, ...)
    end
    local args = table.pack(...)
    dump("[Spy] " .. %q, args)
    return oldMethod(self, table.unpack(args, 1, args.n))
end)
proxy:Destroy()
]], remoteType, methods.index, methods.namecall))
        else
            table.insert(lines, string.format([[
local function %s(...)
    local args = table.pack(...)
    dump("[Spy] " .. %q, args)
    return remote[%q](remote, table.unpack(args, 1, args.n))
end
]], methods.namecall, methods.namecall, methods.index))
        end
    end

    return table.concat(lines, "\n"):gsub("\n+$", ""), mode == "hookmetamethod" or mode == "hookfunction"
end
