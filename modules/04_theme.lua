-- spyTool/modules/04_theme.lua

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
        Window = 30,
        Large = 15,
        Medium = 12,
        Small = 9,
        Chip = 12,
    },
    TitleBarHeight = 36,
    
    
    CornerRadius = UDim.new(0, 12),
    CornerRadiusSmall = UDim.new(0, 9),
    CornerRadiusLarge = UDim.new(0, 15),
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
