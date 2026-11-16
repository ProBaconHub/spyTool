-- spyTool/modules/08_http_interceptor.lua

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
