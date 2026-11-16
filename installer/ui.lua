--[[
    Spy Tool first-run installer UI.
    Loaded only from GitHub via HttpGet into memory — never written into spyTool/.
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local BG = Color3.fromRGB(9, 9, 11)
local PANEL = Color3.fromRGB(24, 24, 27)
local BORDER = Color3.fromRGB(39, 39, 42)
local TEXT = Color3.fromRGB(250, 250, 250)
local MUTED = Color3.fromRGB(161, 161, 170)
local PRIMARY = Color3.fromRGB(59, 130, 246)

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
    s.Parent = inst
    return s
end

function InstallerUI.new(opts)
    opts = opts or {}
    local self = setmetatable({}, InstallerUI)
    self._spinConn = nil
    self._tempFiles = {}
    self._tempDirs = {}

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
    dim.BackgroundTransparency = 0.25
    dim.BorderSizePixel = 0
    dim.Parent = gui

    local card = Instance.new("Frame")
    card.Name = "Card"
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.fromOffset(320, 168)
    card.BackgroundColor3 = PANEL
    card.BorderSizePixel = 0
    card.Parent = dim
    applyCorner(card, 14)
    applyStroke(card, BORDER, 1)

    local spinnerHost = Instance.new("Frame")
    spinnerHost.Name = "SpinnerHost"
    spinnerHost.AnchorPoint = Vector2.new(0.5, 0)
    spinnerHost.Position = UDim2.new(0.5, 0, 0, 28)
    spinnerHost.Size = UDim2.fromOffset(44, 44)
    spinnerHost.BackgroundTransparency = 1
    spinnerHost.Parent = card

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
        -- Fallback ring if remote spinner asset failed.
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
    title.Position = UDim2.new(0.5, 0, 0, 86)
    title.Size = UDim2.new(1, -32, 0, 22)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = TEXT
    title.Text = "Installing files"
    title.Parent = card
    self.Title = title

    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.AnchorPoint = Vector2.new(0.5, 0)
    status.Position = UDim2.new(0.5, 0, 0, 112)
    status.Size = UDim2.new(1, -32, 0, 18)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.GothamMedium
    status.TextSize = 12
    status.TextColor3 = MUTED
    status.Text = "Preparing…"
    status.TextTruncate = Enum.TextTruncate.AtEnd
    status.Parent = card
    self.Status = status

    local barBg = Instance.new("Frame")
    barBg.Name = "BarBg"
    barBg.AnchorPoint = Vector2.new(0.5, 0)
    barBg.Position = UDim2.new(0.5, 0, 0, 140)
    barBg.Size = UDim2.new(1, -48, 0, 6)
    barBg.BackgroundColor3 = BORDER
    barBg.BorderSizePixel = 0
    barBg.Parent = card
    applyCorner(barBg, 99)

    local barFill = Instance.new("Frame")
    barFill.Name = "BarFill"
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = PRIMARY
    barFill.BorderSizePixel = 0
    barFill.Parent = barBg
    applyCorner(barFill, 99)
    self.BarFill = barFill

    self:_startSpin()
    return self
end

function InstallerUI:_startSpin()
    local spinner = self.Spinner
    if not spinner then
        return
    end
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
