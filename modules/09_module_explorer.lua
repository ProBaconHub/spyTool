-- spyTool/modules/09_module_explorer.lua

local ModuleExplorer = {
    AllModules = {},
    LoadedModules = {},
    SearchFilter = "",
    SortMode = "name",
    DeepSearch = true,
    OnModulesRefreshed = nil,
    _scanId = 0,
    _scanRunning = false,
    _sourceIndexRunning = false,
    _sourceIndexGen = 0,
}

local MODULE_SCAN_BATCH_SIZE = 100
local MODULE_SCAN_TRAVERSE_YIELD_EVERY = 800
local MODULE_UI_YIELD_EVERY = 12
local MODULE_SOURCE_INDEX_YIELD_EVERY = 8
local MODULE_CONSTANT_MAX = 80
local MODULE_CONSTANT_MAX_LEN = 120
local MODULE_SOURCE_BLOB_MAX = 24000
local MODULE_BACKGROUND_DECOMPILE = false

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
    self._sourceIndexGen = (self._sourceIndexGen or 0) + 1
    self._sourceIndexRunning = false
    self.AllModules = {}
    self.LoadedModules = {}
    self.OnModulesRefreshed = nil
end

local function appendUniqueLower(list, seen, value, maxLen)
    if type(value) ~= "string" then
        return
    end
    if #value < 2 or #value > (maxLen or MODULE_CONSTANT_MAX_LEN) then
        return
    end
    local lower = value:lower()
    if seen[lower] then
        return
    end
    seen[lower] = true
    list[#list + 1] = lower
end

local function collectFunctionStringConstants(func, into, seen, budget)
    if type(func) ~= "function" or budget.left <= 0 then
        return
    end
    if not debug.getconstants then
        return
    end
    local ok, consts = pcall(debug.getconstants, func)
    if not ok or type(consts) ~= "table" then
        return
    end
    for _, constant in ipairs(consts) do
        if budget.left <= 0 then
            break
        end
        if type(constant) == "string" then
            local before = #into
            appendUniqueLower(into, seen, constant, MODULE_CONSTANT_MAX_LEN)
            if #into > before then
                budget.left -= 1
            end
        end
    end
end

function ModuleExplorer:BuildResultSearchIndex(result)
    local keys = {}
    local keySeen = {}
    local constants = {}
    local constSeen = {}
    local budget = {left = MODULE_CONSTANT_MAX}
    local returnType = type(result)

    if returnType == "table" then
        pcall(function()
            for key, value in pairs(result) do
                if type(key) == "string" and key:sub(1, 2) == "__" then
                    continue
                end
                appendUniqueLower(keys, keySeen, tostring(key), MODULE_CONSTANT_MAX_LEN)
                if type(value) == "function" then
                    collectFunctionStringConstants(value, constants, constSeen, budget)
                elseif type(value) == "string" then
                    appendUniqueLower(constants, constSeen, value, MODULE_CONSTANT_MAX_LEN)
                    budget.left -= 1
                end
            end
        end)
    elseif returnType == "function" then
        collectFunctionStringConstants(result, constants, constSeen, budget)
    elseif returnType == "string" then
        appendUniqueLower(constants, constSeen, result, MODULE_CONSTANT_MAX_LEN)
    end

    return {
        KeysBlob = table.concat(keys, "\n"),
        ConstantsBlob = table.concat(constants, "\n"),
        SourceBlob = nil,
        ReturnType = returnType,
        IndexedAt = os.clock(),
    }
end

function ModuleExplorer:BuildSourceSearchIndex(moduleData, opts)
    opts = opts or {}
    if not moduleData then
        return nil
    end
    local allowDecompile = opts.AllowDecompile == true or MODULE_BACKGROUND_DECOMPILE
    local sourceText = nil
    local mod = moduleData.Module
    if mod then
        pcall(function()
            local src = mod.Source
            if type(src) == "string" and #src > 0 then
                sourceText = src
            end
        end)
        if (not sourceText or sourceText == "") and allowDecompile and decompile then
            local ok, result = pcall(decompile, mod)
            if ok and type(result) == "string" and #result > 0 then
                sourceText = result
            end
        end
    end
    if not sourceText or sourceText == "" then
        return {
            SourceBlob = "",
            SourceReady = true,
            IndexedAt = os.clock(),
        }
    end
    local lower = sourceText:lower()
    if #lower > MODULE_SOURCE_BLOB_MAX then
        lower = string.sub(lower, 1, MODULE_SOURCE_BLOB_MAX)
    end
    return {
        SourceBlob = lower,
        SourceReady = true,
        IndexedAt = os.clock(),
    }
end

function ModuleExplorer:AttachSearchIndex(moduleData, index)
    if not moduleData or not index then
        return
    end
    local existing = moduleData.SearchIndex or {}
    for key, value in pairs(index) do
        existing[key] = value
    end
    moduleData.SearchIndex = existing
end

function ModuleExplorer:EnsureSourceIndex(moduleData, opts)
    if not moduleData then
        return nil
    end
    local index = moduleData.SearchIndex
    if index and index.SourceReady then
        return index
    end
    local sourceIndex = self:BuildSourceSearchIndex(moduleData, opts)
    self:AttachSearchIndex(moduleData, sourceIndex)
    return moduleData.SearchIndex
end

function ModuleExplorer:GetSearchMatchTier(moduleData, filter)
    if not filter or filter == "" then
        return 1
    end
    filter = filter:lower()
    local nameLower = (moduleData.Name or ""):lower()
    local pathLower = (moduleData.Path or ""):lower()
    if nameLower:find(filter, 1, true) or pathLower:find(filter, 1, true) then
        return 1
    end

    local index = moduleData.SearchIndex
    if not index then
        return nil
    end
    if (index.KeysBlob and index.KeysBlob ~= "" and index.KeysBlob:find(filter, 1, true))
        or (index.ConstantsBlob and index.ConstantsBlob ~= "" and index.ConstantsBlob:find(filter, 1, true)) then
        return 2
    end
    if self.DeepSearch and index.SourceBlob and index.SourceBlob ~= ""
        and index.SourceBlob:find(filter, 1, true) then
        return 3
    end
    return nil
end

function ModuleExplorer:ModuleMatchesFilter(moduleData)
    if self.SearchFilter == "" then
        return true
    end
    return self:GetSearchMatchTier(moduleData, self.SearchFilter) ~= nil
end

function ModuleExplorer:StartBackgroundSourceIndexing()
    if self._sourceIndexRunning then
        return
    end
    self._sourceIndexGen = (self._sourceIndexGen or 0) + 1
    local gen = self._sourceIndexGen
    self._sourceIndexRunning = true
    task.spawn(function()
        local processed = 0
        for _, moduleData in ipairs(self.AllModules) do
            if self._sourceIndexGen ~= gen then
                break
            end
            if moduleData and not (moduleData.SearchIndex and moduleData.SearchIndex.SourceReady) then
                self:EnsureSourceIndex(moduleData, {AllowDecompile = false})
                processed += 1
                if processed % MODULE_SOURCE_INDEX_YIELD_EVERY == 0 then
                    RunService.Heartbeat:Wait()
                end
            end
        end
        if self._sourceIndexGen == gen then
            self._sourceIndexRunning = false
        end
    end)
end

function ModuleExplorer:ResolveInGC(moduleData, opts)
    opts = opts or {}
    local entry = moduleData and self.LoadedModules[moduleData.Path]
    if not entry or not entry.LoadSuccess then
        return {
            Ok = false,
            Error = "Module is not loaded",
            Matches = {},
        }
    end
    if type(getgc) ~= "function" then
        return {
            Ok = false,
            Error = "getgc is not available",
            Matches = {},
        }
    end

    local target = entry.Result
    local includeTables = opts.IncludeTables ~= false
    local maxMatches = math.clamp(tonumber(opts.MaxMatches) or 32, 1, 128)
    local matches = {}
    local ok, err = pcall(function()
        for _, obj in ipairs(getgc(true)) do
            if #matches >= maxMatches then
                break
            end
            if rawequal(obj, target) then
                matches[#matches + 1] = {
                    Kind = "exact",
                    Type = type(obj),
                    Value = obj,
                }
            elseif includeTables and type(target) == "table" and type(obj) == "table" and obj ~= target then
                local shared = 0
                local checked = 0
                for key, value in pairs(target) do
                    checked += 1
                    if checked > 24 then
                        break
                    end
                    local okIndex, other = pcall(function()
                        return obj[key]
                    end)
                    if okIndex and rawequal(other, value) then
                        shared += 1
                    end
                end
                if shared >= 3 or (checked > 0 and shared == checked) then
                    matches[#matches + 1] = {
                        Kind = "similar",
                        Type = "table",
                        Value = obj,
                        SharedKeys = shared,
                    }
                end
            end
        end
    end)

    if not ok then
        return {
            Ok = false,
            Error = tostring(err),
            Matches = {},
        }
    end
    return {
        Ok = true,
        Error = nil,
        Matches = matches,
        TargetType = type(target),
    }
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

        self:StartBackgroundSourceIndexing()
        
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
    local tierBuckets = {
        [1] = {},
        [2] = {},
        [3] = {},
    }

    for _, mod in ipairs(self.AllModules) do
        local tier = self:GetSearchMatchTier(mod, filter)
        if tier and tierBuckets[tier] then
            table.insert(tierBuckets[tier], mod)
            mod.LastSearchTier = tier
        end
    end

    local filtered = {}
    for tier = 1, 3 do
        for _, mod in ipairs(tierBuckets[tier]) do
            table.insert(filtered, mod)
        end
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
        SearchIndex = nil,
    }
    
    local success, result = pcall(function()
        return require(moduleData.Module)
    end)
    
    entry.LoadSuccess = success
    if success then
        entry.Result = result
        entry.Contents = self:AnalyzeModuleContents(result)
        local resultIndex = self:BuildResultSearchIndex(result)
        entry.SearchIndex = resultIndex
        self:AttachSearchIndex(moduleData, resultIndex)
        if not (moduleData.SearchIndex and moduleData.SearchIndex.SourceReady) then
            task.spawn(function()
                self:EnsureSourceIndex(moduleData, {AllowDecompile = true})
                if entry.SearchIndex and moduleData.SearchIndex then
                    entry.SearchIndex.SourceBlob = moduleData.SearchIndex.SourceBlob
                    entry.SearchIndex.SourceReady = moduleData.SearchIndex.SourceReady
                end
            end)
        end
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

local function moduleKeyAccess(key)
    if type(key) == "string" then
        if key:match("^[%a_][%w_]*$") then
            return "." .. key
        end
        return '["' .. key:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"]'
    end
    if type(key) == "number" then
        return "[" .. tostring(key) .. "]"
    end
    return "[" .. tostring(key) .. "]"
end

function ModuleExplorer:GenerateModulePath(moduleData)
    local expr
    if typeof(moduleData.Module) == "Instance" then
        expr = formatRobloxPath(moduleData.Module)
    else
        expr = formatRobloxPath(moduleData.Path)
    end
    if not isUsablePathExpr(expr) then
        return 'error("module path unavailable")'
    end
    return "require(" .. expr .. ")"
end

function ModuleExplorer:GenerateCallingCode(moduleData, contentData)
    local keyAccess = moduleKeyAccess(contentData.Key)
    local lines = {
        "local module = " .. self:GenerateModulePath(moduleData),
    }

    if contentData.IsFunction then
        local funcInfo = contentData.FuncInfo or {}
        local argCount = funcInfo.NumArgs or 0
        local placeholders = table.create(argCount)
        for i = 1, argCount do
            placeholders[i] = "nil"
        end
        if funcInfo.IsVariadic then
        end
        local call = "module" .. keyAccess .. "(" .. table.concat(placeholders, ", ") .. ")"
        table.insert(lines, "local results = table.pack(" .. call .. ")")
        table.insert(lines, "print(table.unpack(results, 1, results.n))")
    else
        table.insert(lines, "print(module" .. keyAccess .. ")")
    end

    return table.concat(lines, "\n")
end

function ModuleExplorer:GenerateSetCode(moduleData, contentData, newValue)
    local keyAccess = moduleKeyAccess(contentData.Key)
    return table.concat({
        "local module = " .. self:GenerateModulePath(moduleData),
        "module" .. keyAccess .. " = " .. (newValue or "nil"),
    }, "\n")
end

function ModuleExplorer:GenerateInterceptCode(moduleData, contentData)
    if not contentData.IsFunction then
        return "", false
    end

    local usesHookfunction = isHookfunctionSupported()
    local keyAccess = moduleKeyAccess(contentData.Key)
    local tag = tostring(contentData.KeyStr or contentData.Key or "fn")
    local lines = {
        "local module = " .. self:GenerateModulePath(moduleData),
        "local original = module" .. keyAccess,
        "",
        [[local function dump(tag, args)
    local n = args.n or #args
    local parts = table.create(n)
    for i = 1, n do
        local ok, text = pcall(tostring, args[i])
        parts[i] = ok and text or typeof(args[i])
    end
    print(tag, table.concat(parts, ", "))
end]],
        "",
    }
    appendInterceptHookHeader(lines, usesHookfunction and "hookfunction" or "wrapper")

    if usesHookfunction then
        table.insert(lines, string.format([[
local old
old = hookfunction(original, function(...)
    local args = table.pack(...)
    dump("[Spy] " .. %q, args)
    return old(table.unpack(args, 1, args.n))
end)
]], tag))
    else
        table.insert(lines, string.format([[
module%s = function(...)
    local args = table.pack(...)
    dump("[Spy] " .. %q, args)
    return original(table.unpack(args, 1, args.n))
end
]], keyAccess, tag))
    end

    return table.concat(lines, "\n"):gsub("\n+$", ""), usesHookfunction
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
