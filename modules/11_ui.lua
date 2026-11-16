-- spyTool/modules/11_ui.lua

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

-- Usable ScreenGui area (IgnoreGuiInset=false): viewport minus GuiService insets.
function RemoteSpyUI:GetSafeDisplaySize()
    local display = self:GetDisplaySize()
    local insetTopLeft = Vector2.zero
    local insetBottomRight = Vector2.zero
    if GuiService then
        pcall(function()
            insetTopLeft, insetBottomRight = GuiService:GetGuiInset()
        end)
    end
    local w = math.max(1, math.floor(display.X - insetTopLeft.X - insetBottomRight.X))
    local h = math.max(1, math.floor(display.Y - insetTopLeft.Y - insetBottomRight.Y))
    return Vector2.new(w, h)
end

function RemoteSpyUI:GetMaxWindowSize()
    local display = self:GetSafeDisplaySize()
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

-- Top-left so the window's visual center matches the display center.
function RemoteSpyUI:GetCenteredWindowPosition(width, height)
    local display = self:GetSafeDisplaySize()
    local scale = self.UIScale or 1
    if scale < 0.01 then
        scale = 1
    end
    local visualW = math.max(0, (tonumber(width) or 0) * scale)
    local visualH = math.max(0, (tonumber(height) or 0) * scale)
    local x = math.floor((display.X - visualW) * 0.5 + 0.5)
    local y = math.floor((display.Y - visualH) * 0.5 + 0.5)
    return UDim2.new(0, x, 0, y)
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
    local initialPosition = self:GetCenteredWindowPosition(startW, startH)
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
        Size = UDim2.new(0.30, -10, 1, 0),
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
            contentsPanel.Size = UDim2.new(self._contentsPanelWidth, -10, 1, 0)
            contentsPanel.Position = UDim2.new(self._modulePanelWidth, 5, 0, 0)
            resizer2.Position = UDim2.new(self._modulePanelWidth + self._contentsPanelWidth, -5, 0, 0)
            local detailsWidth = 1 - self._modulePanelWidth - self._contentsPanelWidth
            detailsPanel.Size = UDim2.new(detailsWidth, -5, 1, 0)
            detailsPanel.Position = UDim2.new(self._modulePanelWidth + self._contentsPanelWidth, 5, 0, 0)
        elseif draggingResizer2 then
            
            local minX = self._modulePanelWidth + 0.1
            relX = math.clamp(relX, minX, 0.85)
            
            self._contentsPanelWidth = relX - self._modulePanelWidth
            
            contentsPanel.Size = UDim2.new(self._contentsPanelWidth, -10, 1, 0)
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
