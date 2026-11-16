--[[
    Spy Tool first-run installer UI.
    Loaded only from GitHub via HttpGet into memory — never written into spyTool/.
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local BG = Color3.fromRGB(9, 9, 11)
local PANEL = Color3.fromRGB(24, 24, 27)
local PANEL_INSET = Color3.fromRGB(18, 18, 21)
local BORDER = Color3.fromRGB(39, 39, 42)
local TEXT = Color3.fromRGB(250, 250, 250)
local MUTED = Color3.fromRGB(161, 161, 170)
local PRIMARY = Color3.fromRGB(59, 130, 246)
local PRIMARY_HOVER = Color3.fromRGB(37, 99, 235)

local AGREEMENT_TEXT = [[Usage Agreement & Responsibility

Spy Tool is developer tooling for inspecting remotes, modules, and HTTP traffic in experiences you own or have edit access to.

IMPORTANT — OWN GAMES ONLY
• Use this only on places/experiences you own or have edit permissions for.
• Roblox policy allows creators with edit permissions to use a modified client in that place only (for example, to test anti-cheat).
• Using a modified client in someone else’s experience may result in enforcement, up to account termination.

You agree that you will NOT use this project to:
• Access, probe, or interfere with third-party games without authorization
• Circumvent Roblox security or moderation
• Cheat, grief, or gain unauthorized access

By installing, you acknowledge that:
• You are solely responsible for how you use this software
• You will comply with Roblox Terms of Use, Community Standards, and applicable law
• The authors provide this software for legitimate development and testing of your own work, with no warranty

If you do not agree, click Cancel and do not install.]]

local InstallerUI = {}
InstallerUI.__index = InstallerUI

local function resolveParent()
    local ok, hui = pcall(function()
        if type(gethui) == "function" then
            return gethui()
        end
        if getgenv then
            local env = getgenv()
            if type(env) == "table" and type(env.gethui) == "function" then
                return env.gethui()
            end
        end
        return nil
    end)
    if ok and hui then
        return hui
    end
    local lp = Players.LocalPlayer
    if lp then
        local pg = lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui", 2)
        if pg then
            return pg
        end
    end
    return CoreGui
end

local function applyCorner(inst, px)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, px)
    c.Parent = inst
    return c
end

local function applyStroke(inst, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = inst
    return s
end

local function makeButton(parent, text, color, width)
    local btn = Instance.new("TextButton")
    btn.AutoButtonColor = false
    btn.Size = UDim2.fromOffset(width or 100, 32)
    btn.BackgroundColor3 = color
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.TextColor3 = TEXT
    btn.Text = text
    btn.Parent = parent
    applyCorner(btn, 8)
    return btn
end

function InstallerUI.new(opts)
    opts = opts or {}
    local self = setmetatable({}, InstallerUI)
    self._spinConn = nil
    self._tempFiles = {}
    self._tempDirs = {}
    self._accepted = false
    self._cancelled = false
    self._decisionBindable = Instance.new("BindableEvent")
    self._agreed = false

    local parent = resolveParent()
    local gui = Instance.new("ScreenGui")
    gui.Name = "SpyToolInstaller"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 1000000
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function()
        gui.Parent = parent
    end)
    if not gui.Parent then
        gui.Parent = CoreGui
    end
    self.Gui = gui

    local dim = Instance.new("Frame")
    dim.Name = "Dim"
    dim.Size = UDim2.fromScale(1, 1)
    dim.BackgroundColor3 = BG
    dim.BackgroundTransparency = 0.2
    dim.BorderSizePixel = 0
    dim.Parent = gui

    local card = Instance.new("Frame")
    card.Name = "Card"
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.fromOffset(480, 460)
    card.BackgroundColor3 = PANEL
    card.BorderSizePixel = 0
    card.Parent = dim
    applyCorner(card, 14)
    applyStroke(card, BORDER, 1)
    self.Card = card

    -- Agreement page
    local agreementPage = Instance.new("Frame")
    agreementPage.Name = "AgreementPage"
    agreementPage.Size = UDim2.fromScale(1, 1)
    agreementPage.BackgroundTransparency = 1
    agreementPage.Parent = card
    self.AgreementPage = agreementPage

    local header = Instance.new("TextLabel")
    header.Name = "Header"
    header.Position = UDim2.fromOffset(24, 18)
    header.Size = UDim2.new(1, -48, 0, 24)
    header.BackgroundTransparency = 1
    header.Font = Enum.Font.GothamBold
    header.TextSize = 18
    header.TextColor3 = TEXT
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Text = "Spy Tool Setup"
    header.Parent = agreementPage

    local prompt = Instance.new("TextLabel")
    prompt.Name = "Prompt"
    prompt.Position = UDim2.fromOffset(24, 48)
    prompt.Size = UDim2.new(1, -48, 0, 18)
    prompt.BackgroundTransparency = 1
    prompt.Font = Enum.Font.GothamMedium
    prompt.TextSize = 12
    prompt.TextColor3 = MUTED
    prompt.TextXAlignment = Enum.TextXAlignment.Left
    prompt.Text = "Please read the following usage agreement:"
    prompt.Parent = agreementPage

    local agreementBox = Instance.new("Frame")
    agreementBox.Name = "AgreementBox"
    agreementBox.Position = UDim2.fromOffset(24, 74)
    agreementBox.Size = UDim2.new(1, -48, 0, 250)
    agreementBox.BackgroundColor3 = PANEL_INSET
    agreementBox.BorderSizePixel = 0
    agreementBox.ClipsDescendants = true
    agreementBox.Parent = agreementPage
    applyCorner(agreementBox, 8)
    applyStroke(agreementBox, BORDER, 1)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "AgreementScroll"
    scroll.Size = UDim2.fromScale(1, 1)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = BORDER
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = agreementBox

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 12)
    pad.PaddingBottom = UDim.new(0, 12)
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    pad.Parent = scroll

    local agreementLabel = Instance.new("TextLabel")
    agreementLabel.Name = "AgreementText"
    agreementLabel.Size = UDim2.new(1, 0, 0, 0)
    agreementLabel.AutomaticSize = Enum.AutomaticSize.Y
    agreementLabel.BackgroundTransparency = 1
    agreementLabel.Font = Enum.Font.Gotham
    agreementLabel.TextSize = 12
    agreementLabel.TextColor3 = MUTED
    agreementLabel.TextXAlignment = Enum.TextXAlignment.Left
    agreementLabel.TextYAlignment = Enum.TextYAlignment.Top
    agreementLabel.TextWrapped = true
    agreementLabel.Text = opts.agreementText or AGREEMENT_TEXT
    agreementLabel.Parent = scroll

    local checkRow = Instance.new("Frame")
    checkRow.Name = "CheckRow"
    checkRow.Position = UDim2.fromOffset(24, 338)
    checkRow.Size = UDim2.new(1, -48, 0, 28)
    checkRow.BackgroundTransparency = 1
    checkRow.Parent = agreementPage

    local checkBtn = Instance.new("TextButton")
    checkBtn.Name = "Checkbox"
    checkBtn.AutoButtonColor = false
    checkBtn.Size = UDim2.fromOffset(18, 18)
    checkBtn.Position = UDim2.fromOffset(0, 5)
    checkBtn.BackgroundColor3 = PANEL_INSET
    checkBtn.BorderSizePixel = 0
    checkBtn.Text = ""
    checkBtn.Parent = checkRow
    applyCorner(checkBtn, 4)
    applyStroke(checkBtn, BORDER, 1)

    local checkMark = Instance.new("TextLabel")
    checkMark.Name = "Mark"
    checkMark.Size = UDim2.fromScale(1, 1)
    checkMark.BackgroundTransparency = 1
    checkMark.Font = Enum.Font.GothamBold
    checkMark.TextSize = 14
    checkMark.TextColor3 = TEXT
    checkMark.Text = ""
    checkMark.Parent = checkBtn

    local checkLabel = Instance.new("TextButton")
    checkLabel.Name = "CheckLabel"
    checkLabel.AutoButtonColor = false
    checkLabel.Position = UDim2.fromOffset(26, 0)
    checkLabel.Size = UDim2.new(1, -26, 1, 0)
    checkLabel.BackgroundTransparency = 1
    checkLabel.Font = Enum.Font.GothamMedium
    checkLabel.TextSize = 12
    checkLabel.TextColor3 = TEXT
    checkLabel.TextXAlignment = Enum.TextXAlignment.Left
    checkLabel.TextWrapped = true
    checkLabel.Text = "I understand and agree to the usage agreement and my responsibilities."
    checkLabel.Parent = checkRow

    local footer = Instance.new("Frame")
    footer.Name = "Footer"
    footer.AnchorPoint = Vector2.new(0, 1)
    footer.Position = UDim2.new(0, 0, 1, -16)
    footer.Size = UDim2.new(1, 0, 0, 40)
    footer.BackgroundTransparency = 1
    footer.Parent = agreementPage

    local btnRow = Instance.new("Frame")
    btnRow.AnchorPoint = Vector2.new(1, 0.5)
    btnRow.Position = UDim2.new(1, -24, 0.5, 0)
    btnRow.Size = UDim2.fromOffset(220, 32)
    btnRow.BackgroundTransparency = 1
    btnRow.Parent = footer

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.Padding = UDim.new(0, 10)
    layout.Parent = btnRow

    local cancelBtn = makeButton(btnRow, "Cancel", BORDER, 100)
    cancelBtn.Name = "Cancel"
    local installBtn = makeButton(btnRow, "Install", PRIMARY, 110)
    installBtn.Name = "Install"
    installBtn.AutoButtonColor = false

    local function setInstallEnabled(on)
        installBtn.Active = on
        installBtn.BackgroundColor3 = on and PRIMARY or Color3.fromRGB(30, 64, 120)
        installBtn.TextTransparency = on and 0 or 0.45
    end
    setInstallEnabled(false)

    local function setAgreed(on)
        self._agreed = on
        checkMark.Text = on and "✓" or ""
        checkBtn.BackgroundColor3 = on and PRIMARY or PANEL_INSET
        setInstallEnabled(on)
    end

    local function toggleAgreed()
        setAgreed(not self._agreed)
    end

    checkBtn.MouseButton1Click:Connect(toggleAgreed)
    checkLabel.MouseButton1Click:Connect(toggleAgreed)

    installBtn.MouseEnter:Connect(function()
        if self._agreed then
            installBtn.BackgroundColor3 = PRIMARY_HOVER
        end
    end)
    installBtn.MouseLeave:Connect(function()
        if self._agreed then
            installBtn.BackgroundColor3 = PRIMARY
        end
    end)

    installBtn.MouseButton1Click:Connect(function()
        if not self._agreed then
            return
        end
        self._accepted = true
        self._decisionBindable:Fire(true)
    end)

    cancelBtn.MouseButton1Click:Connect(function()
        self._cancelled = true
        self._decisionBindable:Fire(false)
    end)

    -- Progress page (hidden until accepted)
    local progressPage = Instance.new("Frame")
    progressPage.Name = "ProgressPage"
    progressPage.Size = UDim2.fromScale(1, 1)
    progressPage.BackgroundTransparency = 1
    progressPage.Visible = false
    progressPage.Parent = card
    self.ProgressPage = progressPage

    local spinnerHost = Instance.new("Frame")
    spinnerHost.Name = "SpinnerHost"
    spinnerHost.AnchorPoint = Vector2.new(0.5, 0)
    spinnerHost.Position = UDim2.new(0.5, 0, 0, 120)
    spinnerHost.Size = UDim2.fromOffset(44, 44)
    spinnerHost.BackgroundTransparency = 1
    spinnerHost.Parent = progressPage

    local spinner = Instance.new("ImageLabel")
    spinner.Name = "Spinner"
    spinner.AnchorPoint = Vector2.new(0.5, 0.5)
    spinner.Position = UDim2.fromScale(0.5, 0.5)
    spinner.Size = UDim2.fromOffset(40, 40)
    spinner.BackgroundTransparency = 1
    spinner.Image = opts.spinnerImage or ""
    spinner.ImageColor3 = PRIMARY
    spinner.ScaleType = Enum.ScaleType.Fit
    spinner.Parent = spinnerHost
    self.Spinner = spinner

    if not opts.spinnerImage or opts.spinnerImage == "" then
        spinner.Image = ""
        local ring = Instance.new("Frame")
        ring.Name = "FallbackRing"
        ring.AnchorPoint = Vector2.new(0.5, 0.5)
        ring.Position = UDim2.fromScale(0.5, 0.5)
        ring.Size = UDim2.fromOffset(36, 36)
        ring.BackgroundTransparency = 1
        ring.Parent = spinnerHost
        applyCorner(ring, 999)
        local stroke = applyStroke(ring, PRIMARY, 3)
        stroke.Transparency = 0.15
        local tip = Instance.new("Frame")
        tip.Name = "Tip"
        tip.AnchorPoint = Vector2.new(0.5, 0)
        tip.Position = UDim2.new(0.5, 0, 0, -2)
        tip.Size = UDim2.fromOffset(6, 10)
        tip.BackgroundColor3 = PRIMARY
        tip.BorderSizePixel = 0
        tip.Parent = ring
        applyCorner(tip, 3)
        self.Spinner = ring
    end

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.AnchorPoint = Vector2.new(0.5, 0)
    title.Position = UDim2.new(0.5, 0, 0, 190)
    title.Size = UDim2.new(1, -48, 0, 24)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = TEXT
    title.Text = "Installing files"
    title.Parent = progressPage
    self.Title = title

    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.AnchorPoint = Vector2.new(0.5, 0)
    status.Position = UDim2.new(0.5, 0, 0, 222)
    status.Size = UDim2.new(1, -48, 0, 18)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.GothamMedium
    status.TextSize = 12
    status.TextColor3 = MUTED
    status.Text = "Preparing…"
    status.TextTruncate = Enum.TextTruncate.AtEnd
    status.Parent = progressPage
    self.Status = status

    local barBg = Instance.new("Frame")
    barBg.Name = "BarBg"
    barBg.AnchorPoint = Vector2.new(0.5, 0)
    barBg.Position = UDim2.new(0.5, 0, 0, 258)
    barBg.Size = UDim2.new(1, -96, 0, 6)
    barBg.BackgroundColor3 = BORDER
    barBg.BorderSizePixel = 0
    barBg.Parent = progressPage
    applyCorner(barBg, 99)

    local barFill = Instance.new("Frame")
    barFill.Name = "BarFill"
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = PRIMARY
    barFill.BorderSizePixel = 0
    barFill.Parent = barBg
    applyCorner(barFill, 99)
    self.BarFill = barFill

    return self
end

function InstallerUI:WaitForAccept()
    if self._accepted then
        return true
    end
    if self._cancelled then
        return false
    end
    return self._decisionBindable.Event:Wait()
end

function InstallerUI:ShowProgress()
    if self.AgreementPage then
        self.AgreementPage.Visible = false
    end
    if self.ProgressPage then
        self.ProgressPage.Visible = true
    end
    if self.Card then
        self.Card.Size = UDim2.fromOffset(360, 300)
    end
    self:_startSpin()
    self:SetStatus("Installing files")
end

function InstallerUI:_startSpin()
    local spinner = self.Spinner
    if not spinner or self._spinConn then
        return
    end
    spinner.Rotation = 0
    self._spinConn = TweenService:Create(
        spinner,
        TweenInfo.new(0.85, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
        { Rotation = 360 }
    )
    self._spinConn:Play()
end

function InstallerUI:SetStatus(text)
    if self.Status then
        self.Status.Text = tostring(text or "")
    end
end

function InstallerUI:SetProgress(done, total)
    done = math.max(0, tonumber(done) or 0)
    total = math.max(0, tonumber(total) or 0)
    local alpha = 0
    if total > 0 then
        alpha = math.clamp(done / total, 0, 1)
        self:SetStatus(string.format("%d / %d files", done, total))
    end
    if self.BarFill then
        TweenService:Create(
            self.BarFill,
            TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Size = UDim2.new(alpha, 0, 1, 0) }
        ):Play()
    end
end

function InstallerUI:TrackTemp(path, isDir)
    if isDir then
        self._tempDirs[#self._tempDirs + 1] = path
    else
        self._tempFiles[#self._tempFiles + 1] = path
    end
end

function InstallerUI:Destroy()
    if self._spinConn then
        pcall(function()
            self._spinConn:Cancel()
        end)
        self._spinConn = nil
    end
    if self._decisionBindable then
        pcall(function()
            self._decisionBindable:Destroy()
        end)
        self._decisionBindable = nil
    end
    if self.Gui then
        pcall(function()
            self.Gui:Destroy()
        end)
        self.Gui = nil
    end
    for _, path in ipairs(self._tempFiles) do
        if type(delfile) == "function" then
            pcall(delfile, path)
        end
    end
    for _, path in ipairs(self._tempDirs) do
        if type(delfolder) == "function" then
            pcall(delfolder, path)
        elseif type(delfile) == "function" then
            pcall(delfile, path)
        end
    end
    self._tempFiles = {}
    self._tempDirs = {}
end

return InstallerUI
