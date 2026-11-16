-- spyTool/modules/09_module_explorer.lua

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
