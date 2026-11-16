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
