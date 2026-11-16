-- spyTool/modules/05_ui_kit.lua

local function getUIParent()
    local ok, hui = pcall(function()
        if getgenv then
            local env = getgenv()
            if type(env) == "table" and type(env.gethui) == "function" then
                return env.gethui()
            end
        end
        
        if type(gethui) == "function" then
            return gethui()
        end
        return nil
    end)
    if ok and hui then
        return safeCloneref(hui)
    end
    local coreGui = safeService("CoreGui")
    if coreGui then
        return coreGui
    end
    local player = LocalPlayer or (Players and safeCloneref(Players.LocalPlayer))
    if player then
        local playerGui = player:FindFirstChild("PlayerGui")
        if playerGui then
            return safeCloneref(playerGui)
        end
    end
    return nil
end

local function createInstance(className, properties, children)
    local instance = Instance.new(className)
    
    pcall(function()
        if instance:IsA("GuiObject") then
            instance.BorderSizePixel = 0
        end
    end)
    
    for prop, value in pairs(properties or {}) do
        if prop ~= "Parent" then
            instance[prop] = value
        end
    end
    
    for _, child in ipairs(children or {}) do
        child.Parent = instance
    end
    
    if properties and properties.Parent then
        instance.Parent = properties.Parent
    end
    
    return instance
end

local createCorner
local createSquircle

local function createStroke(parent, color, thickness)
    return createInstance("UIStroke", {
        Color = color or Theme.Border,
        Thickness = thickness or 1,
        Parent = parent
    })
end

local function setSquircleOutline(entry, color, visible)
    if not entry then
        return
    end
    local outline = entry:FindFirstChild("SelectOutline")
    if not visible or not color then
        if outline then
            outline.Visible = false
        end
        local stroke = entry:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke:Destroy()
        end
        return
    end
    local stroke = entry:FindFirstChildOfClass("UIStroke")
    if stroke then
        stroke:Destroy()
    end
    if not outline then
        local radius = entry:GetAttribute("SquircleRadius") or Theme.Radius.Small
        outline = createSquircle(radius, "SquircleOutline", {
            Name = "SelectOutline",
            Size = UDim2.new(1, 0, 1, 0),
            ImageColor3 = color,
            ZIndex = 0,
            Parent = entry,
        }, false)
    else
        outline.ImageColor3 = color
        outline.Visible = true
    end
end

local SquircleShapeDefs = {
    Circle = {
        File = "squircle/circle.png",
        Fallback = "rbxassetid://111665032676235",
        LocalRect = Rect.new(310, 310, 714, 714),
        FallbackRect = Rect.new(310, 310, 714, 714),
        LocalRadius = 310,
        FallbackRadius = 310,
    },
    Squircle = {
        File = "squircle/squircle.png",
        Fallback = "rbxassetid://89641024074289",
        LocalRect = Rect.new(310, 310, 714, 714),
        FallbackRect = Rect.new(310, 310, 714, 714),
        LocalRadius = 310,
        FallbackRadius = 310,
    },
    SquircleOutline = {
        File = "squircle/squircle-outline.png",
        Fallback = "rbxassetid://74029063732681",
        LocalRect = Rect.new(310, 310, 714, 714),
        FallbackRect = Rect.new(310, 310, 714, 714),
        LocalRadius = 310,
        FallbackRadius = 310,
    },
    ["Squircle-TL-TR"] = {
        File = "squircle/squircle-tl-tr.png",
        Fallback = "rbxassetid://75712142040725",
        LocalRect = Rect.new(310, 310, 714, 714),
        FallbackRect = Rect.new(310, 310, 714, 714),
        LocalRadius = 310,
        FallbackRadius = 310,
    },
    ["Squircle-BL-BR"] = {
        File = "squircle/squircle-bl-br.png",
        Fallback = "rbxassetid://83676684425544",
        LocalRect = Rect.new(310, 310, 714, 714),
        FallbackRect = Rect.new(310, 310, 714, 714),
        LocalRadius = 310,
        FallbackRadius = 310,
    },
    
    Window = {
        File = "squircle/window.png",
        Fallback = "rbxassetid://89641024074289",
        LocalRect = Rect.new(420, 420, 604, 604),
        FallbackRect = Rect.new(310, 310, 714, 714),
        LocalRadius = 420,
        FallbackRadius = 310,
    },
    WindowOutline = {
        File = "squircle/window-outline.png",
        Fallback = "rbxassetid://74029063732681",
        LocalRect = Rect.new(420, 420, 604, 604),
        FallbackRect = Rect.new(310, 310, 714, 714),
        LocalRadius = 420,
        FallbackRadius = 310,
    },
    ["Window-TL-TR"] = {
        File = "squircle/window-tl-tr.png",
        Fallback = "rbxassetid://75712142040725",
        LocalRect = Rect.new(420, 420, 604, 604),
        FallbackRect = Rect.new(310, 310, 714, 714),
        LocalRadius = 420,
        FallbackRadius = 310,
    },
    ["Window-BL-BR"] = {
        File = "squircle/window-bl-br.png",
        Fallback = "rbxassetid://83676684425544",
        LocalRect = Rect.new(420, 420, 604, 604),
        FallbackRect = Rect.new(310, 310, 714, 714),
        LocalRadius = 420,
        FallbackRadius = 310,
    },
}

local SquircleShapes = {} 

local function resolveRadiusPx(radius)
    if typeof(radius) == "UDim" then
        return radius.Offset
    end
    return tonumber(radius) or Theme.Radius.Medium
end

local function getSquircleShape(shapeType)
    local cached = SquircleShapes[shapeType]
    if cached then
        return cached
    end
    local def = SquircleShapeDefs[shapeType] or SquircleShapeDefs.Squircle
    
    
    local localImage = getAssetImage(def.File)
    local useLocal = type(localImage) == "string" and localImage ~= ""
    if not useLocal and (type(def.Fallback) ~= "string" or def.Fallback == "") then
        useLocal = false
    end
    cached = {
        Image = useLocal and localImage or def.Fallback,
        Rect = useLocal and def.LocalRect or def.FallbackRect,
        Radius = useLocal and def.LocalRadius or def.FallbackRadius,
        File = def.File,
        Source = useLocal and "local" or "cdn",
    }
    SquircleShapes[shapeType] = cached
    return cached
end

local function measureTextWidth(text, textSize, font)
    text = tostring(text or "")
    textSize = textSize or 11
    font = font or Theme.FontFamily
    if TextService then
        local ok, bounds = pcall(function()
            return TextService:GetTextSize(text, textSize, font, Vector2.new(10000, textSize + 8))
        end)
        if ok and bounds then
            return math.ceil(bounds.X)
        end
    end
    return math.max(8, math.ceil(#text * textSize * 0.55))
end

createSquircle = function(radius, shapeType, props, interactive)
    props = props or {}
    shapeType = shapeType or "Squircle"
    local shape = getSquircleShape(shapeType)
    local radiusPx = math.clamp(resolveRadiusPx(radius), 0.5, shape.Radius)
    local className = interactive and "ImageButton" or "ImageLabel"
    local sliceScale = math.clamp(radiusPx / shape.Radius, 0.0001, 1)

    local defaults = {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = shape.Image,
        ImageColor3 = props.ImageColor3 or Theme.BackgroundTertiary,
        ImageTransparency = props.ImageTransparency or 0,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = shape.Rect,
        SliceScale = sliceScale,
    }
    if interactive then
        defaults.AutoButtonColor = false
        defaults.Active = true
    end

    for key, value in pairs(props) do
        if key ~= "Parent"
            and key ~= "OutlineColor"
            and key ~= "OutlineTransparency"
            and key ~= "Interactive"
            and key ~= "AutomaticSize" 
        then
            defaults[key] = value
        end
    end

    
    local parent = props.Parent
    defaults.Parent = nil

    local ok, inst = pcall(function()
        return createInstance(className, defaults)
    end)
    if not ok or not inst then
        
        local fallbackProps = {
            BackgroundColor3 = props.ImageColor3 or Theme.BackgroundTertiary,
            BackgroundTransparency = props.ImageTransparency or 0,
            BorderSizePixel = 0,
            Size = props.Size or UDim2.new(0, 40, 0, 40),
            Position = props.Position,
            AnchorPoint = props.AnchorPoint,
            ZIndex = props.ZIndex,
            Name = props.Name,
        }
        if interactive then
            fallbackProps.Text = ""
            fallbackProps.AutoButtonColor = false
            inst = createInstance("TextButton", fallbackProps)
        else
            inst = createInstance("Frame", fallbackProps)
        end
        createCorner(inst, UDim.new(0, math.floor(radiusPx)))
    end

    pcall(function()
        inst:SetAttribute("SquircleRadius", radiusPx)
        inst:SetAttribute("SquircleType", shapeType)
    end)

    if parent then
        inst.Parent = parent
    end
    return inst
end

local function createPanel(radius, props, withOutline)
    props = props or {}
    local autoSize = props.AutomaticSize
    local parent = props.Parent
    local plateProps = {}
    for k, v in pairs(props) do
        plateProps[k] = v
    end
    plateProps.AutomaticSize = nil

    local contentParent
    if autoSize then
        local wrap = createInstance("Frame", {
            Name = props.Name and (props.Name .. "Wrap") or "PanelWrap",
            Size = props.Size or UDim2.new(1, 0, 0, 0),
            AutomaticSize = autoSize,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = props.LayoutOrder,
            ZIndex = props.ZIndex,
            Parent = parent,
        })
        plateProps.Parent = wrap
        plateProps.Size = UDim2.new(1, 0, 1, 0)
        plateProps.Position = nil
        plateProps.LayoutOrder = nil
        local plate = createSquircle(radius, "Squircle", plateProps, props.Interactive == true)
        local outline = nil
        if withOutline ~= false then
            outline = createSquircle(radius, "SquircleOutline", {
                Name = "Outline",
                Size = UDim2.new(1, 0, 1, 0),
                ImageColor3 = props.OutlineColor or Theme.Border,
                ImageTransparency = props.OutlineTransparency or 0,
                ZIndex = 0,
                Parent = plate,
            }, false)
        end
        contentParent = createInstance("Frame", {
            Name = "Content",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = autoSize,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 2,
            Parent = wrap,
        })
        
        contentParent:SetAttribute("SquircleType", "PanelContent")
        plate:SetAttribute("SquirclePanel", true)
        return contentParent, outline, plate
    end

    local plate = createSquircle(radius, "Squircle", plateProps, props.Interactive == true)
    local outline = nil
    if withOutline ~= false then
        outline = createSquircle(radius, "SquircleOutline", {
            Name = "Outline",
            Size = UDim2.new(1, 0, 1, 0),
            ImageColor3 = props.OutlineColor or Theme.Border,
            ImageTransparency = props.OutlineTransparency or 0,
            ZIndex = props.ZIndex or 1,
            Parent = plate,
        }, false)
    end
    return plate, outline
end

local function setSquircleRadius(inst, radius)
    if not inst then
        return
    end
    local shapeType = inst:GetAttribute("SquircleType") or "Squircle"
    local shape = getSquircleShape(shapeType)
    local radiusPx = math.max(resolveRadiusPx(radius), 0.0001)
    inst.SliceScale = radiusPx / shape.Radius
    inst:SetAttribute("SquircleRadius", radiusPx)
end

local function setSquircleColor(inst, color)
    if inst and (inst:IsA("ImageLabel") or inst:IsA("ImageButton")) then
        inst.ImageColor3 = color
    elseif inst then
        inst.BackgroundColor3 = color
    end
end

local function isSquircle(inst)
    return inst ~= nil and inst:GetAttribute("SquircleType") ~= nil
end

local function getSurfaceFill(inst)
    if not inst then
        return nil, false
    end
    if isSquircle(inst) then
        return inst, true
    end
    local fill = inst:FindFirstChild("G2Fill")
    if fill and (fill:IsA("ImageLabel") or fill:IsA("ImageButton")) then
        return fill, true
    end
    return inst, false
end

local function setSurfaceColor(inst, color)
    local fill, isImage = getSurfaceFill(inst)
    if not fill then
        return
    end
    if isImage then
        fill.ImageColor3 = color
    else
        fill.BackgroundColor3 = color
    end
end

local function setSurfaceTransparency(inst, transparency)
    local fill, isImage = getSurfaceFill(inst)
    if not fill then
        return
    end
    if isImage then
        fill.ImageTransparency = transparency
    else
        fill.BackgroundTransparency = transparency
    end
end

local function isLayoutChromeChild(child)
    if not child then
        return true
    end
    local name = child.Name
    if name == "G2Fill" or name == "G2Content" then
        return true
    end
    return child:IsA("UIStroke")
        or child:IsA("UIGradient")
        or child:IsA("UICorner")
        or child:IsA("UIAspectRatioConstraint")
        or child:IsA("UISizeConstraint")
        or child:IsA("UIScale")
end

local function getG2Content(parent)
    if not parent then
        return nil
    end
    local host = parent:FindFirstChild("G2Content")
    if host then
        return host
    end
    return parent
end

local function _resolveCornerSize(parent)
    local w = parent.Size and parent.Size.X.Offset or 0
    local h = parent.Size and parent.Size.Y.Offset or 0
    if w <= 0 or h <= 0 then
        local abs = parent.AbsoluteSize
        if abs then
            if w <= 0 and abs.X > 0 then
                w = abs.X
            end
            if h <= 0 and abs.Y > 0 then
                h = abs.Y
            end
        end
    end
    return w, h
end

createCorner = function(parent, radius)
    if not parent then
        return nil
    end
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("UICorner") or child.Name == "G2Fill" or child.Name == "G2Content" then
            child:Destroy()
        end
    end

    local radiusPx = resolveRadiusPx(radius or Theme.CornerRadius)
    local w, h = _resolveCornerSize(parent)
    local minSide = math.min(w > 0 and w or 1e9, h > 0 and h or 1e9)
    local isSquare = w > 0 and h > 0 and math.abs(w - h) <= 1
    
    local isPillOrCircle = radiusPx >= 64
        or (isSquare and radiusPx >= minSide * 0.45)
        or (w > 0 and h > 0 and radiusPx >= minSide * 0.5 - 0.5)

    local autoSize = Enum.AutomaticSize.None
    pcall(function()
        autoSize = parent.AutomaticSize
    end)

    if isPillOrCircle or autoSize ~= Enum.AutomaticSize.None then
        parent:SetAttribute("HasG2Fill", false)
        local uiR = isPillOrCircle and 999 or math.floor(math.clamp(radiusPx, 1, 64))
        return createInstance("UICorner", {
            CornerRadius = UDim.new(0, uiR),
            Parent = parent,
        })
    end

    local color = parent.BackgroundColor3
    local transparency = parent.BackgroundTransparency
    parent.BackgroundTransparency = 1

    local plate = createSquircle(radiusPx, "Squircle", {
        Name = "G2Fill",
        Size = UDim2.new(1, 0, 1, 0),
        ImageColor3 = color,
        ImageTransparency = transparency,
        ZIndex = 0,
        Parent = parent,
    }, false)

    local host = createInstance("Frame", {
        Name = "G2Content",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = math.max(1, parent.ZIndex or 1),
        Parent = parent,
    })

    for _, child in ipairs(parent:GetChildren()) do
        if child ~= plate and child ~= host and not isLayoutChromeChild(child) then
            child.Parent = host
        end
    end

    if not parent:GetAttribute("G2ReparentHooked") then
        parent:SetAttribute("G2ReparentHooked", true)
        parent.ChildAdded:Connect(function(child)
            if child.Parent ~= parent or isLayoutChromeChild(child) then
                return
            end
            local content = parent:FindFirstChild("G2Content")
            if not content then
                return
            end
            if child:IsA("UIListLayout")
                or child:IsA("UIGridLayout")
                or child:IsA("UIPageLayout")
                or child:IsA("UITableLayout")
                or child:IsA("UIPadding")
                or child:IsA("GuiObject")
            then
                task.defer(function()
                    if child.Parent == parent and content.Parent == parent then
                        child.Parent = content
                    end
                end)
            end
        end)
    end

    parent:SetAttribute("HasG2Fill", true)
    return plate, host
end

local function createAssetGlyph(parent, fileName, sizePx, props)
    props = props or {}
    sizePx = sizePx or 12
    local icon = createInstance("ImageLabel", {
        Name = props.Name or "AssetGlyph",
        Size = UDim2.new(0, sizePx, 0, sizePx),
        Position = props.Position,
        AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Image = "",
        ImageColor3 = props.ImageColor3 or Color3.new(1, 1, 1),
        ImageTransparency = props.ImageTransparency or 0,
        ScaleType = Enum.ScaleType.Fit,
        Rotation = props.Rotation or 0,
        Visible = props.Visible ~= false,
        ZIndex = props.ZIndex or 2,
        Parent = parent,
    })
    local url = getAssetImage(fileName)
    if url then
        icon.Image = url
    end
    return icon
end

-- DexPlusPlus NewDark class icons live in asset/instance/<ClassName>.png
local DEX_NEWDARK = {
    Image = "rbxassetid://135148380892747", -- source sheet id (tiles extracted locally)
    IconSize = 32,
    Columns = 18,
    Dir = "instance",
}

local DEX_NEWDARK_INDEX = {
    Accessory = 1,
    Actor = 2,
    AdGui = 3,
    AdPortal = 4,
    AirController = 5,
    AlignOrientation = 6,
    AlignPosition = 7,
    AngularVelocity = 8,
    Animation = 9,
    AnimationConstraint = 10,
    AnimationController = 11,
    AnimationFromVideoCreatorService = 12,
    Animator = 13,
    ArcHandles = 14,
    Atmosphere = 15,
    Attachment = 16,
    AudioAnalyzer = 17,
    AudioChannelMixer = 18,
    AudioChannelSplitter = 19,
    AudioChorus = 20,
    AudioCompressor = 21,
    AudioDeviceInput = 22,
    AudioDeviceOutput = 23,
    AudioDistortion = 24,
    AudioEcho = 25,
    AudioEmitter = 26,
    AudioEqualizer = 27,
    AudioFader = 28,
    AudioFilter = 29,
    AudioFlanger = 30,
    AudioGate = 31,
    AudioLimiter = 32,
    AudioListener = 33,
    AudioPitchShifter = 34,
    AudioPlayer = 35,
    AudioRecorder = 36,
    AudioReverb = 37,
    AudioTextToSpeech = 38,
    AuroraScript = 39,
    AvatarEditorService = 40,
    AvatarSettings = 41,
    Backpack = 42,
    BallSocketConstraint = 43,
    BasePlate = 44,
    Beam = 45,
    BillboardGui = 46,
    BindableEvent = 47,
    BindableFunction = 48,
    BlockMesh = 49,
    BloomEffect = 50,
    BlurEffect = 51,
    BodyAngularVelocity = 52,
    BodyColors = 53,
    BodyForce = 54,
    BodyGyro = 55,
    BodyPosition = 56,
    BodyThrust = 57,
    BodyVelocity = 58,
    Bone = 59,
    BoolValue = 60,
    BoxHandleAdornment = 61,
    Breakpoint = 62,
    BrickColorValue = 63,
    BubbleChatConfiguration = 64,
    Buggaroo = 65,
    CFrameValue = 68,
    Camera = 66,
    CanvasGroup = 67,
    ChannelTabsConfiguration = 69,
    CharacterControllerManager = 70,
    CharacterMesh = 71,
    Chat = 72,
    ChatInputBarConfiguration = 73,
    ChatWindowConfiguration = 74,
    ChorusSoundEffect = 75,
    Class = 76,
    Cleanup = 77,
    ClickDetector = 78,
    ClientReplicator = 79,
    ClimbController = 80,
    Clouds = 81,
    Color = 82,
    Color3Value = 284,
    ColorCorrectionEffect = 83,
    CompressorSoundEffect = 84,
    ConeHandleAdornment = 85,
    Configuration = 86,
    Constant = 87,
    Constructor = 88,
    Controller = 89,
    CoreGui = 90,
    CornerWedgePart = 91,
    CylinderHandleAdornment = 92,
    CylindricalConstraint = 93,
    Decal = 94,
    DepthOfFieldEffect = 95,
    Dialog = 96,
    DialogChoice = 97,
    DistortionSoundEffect = 98,
    DragDetector = 99,
    EchoSoundEffect = 100,
    EditableImage = 101,
    EditableMesh = 102,
    Enum = 103,
    EnumMember = 104,
    EqualizerSoundEffect = 105,
    Event = 106,
    Explosion = 107,
    FaceControls = 108,
    Field = 109,
    File = 110,
    Fire = 111,
    FlangeSoundEffect = 112,
    Folder = 113,
    ForceField = 114,
    Frame = 115,
    Function = 116,
    GameSettings = 117,
    GroundController = 118,
    Handles = 119,
    HapticEffect = 120,
    HapticService = 121,
    HeightmapImporterService = 122,
    Highlight = 123,
    HingeConstraint = 124,
    Humanoid = 125,
    HumanoidDescription = 126,
    IKControl = 127,
    ImageButton = 128,
    ImageHandleAdornment = 129,
    ImageLabel = 130,
    InputAction = 131,
    InputBinding = 132,
    InputContext = 133,
    IntValue = 284,
    Interface = 134,
    IntersectOperation = 135,
    Keyword = 136,
    Lighting = 137,
    LineForce = 139,
    LineHandleAdornment = 140,
    LinearVelocity = 138,
    LocalFile = 141,
    LocalScript = 144,
    LocalizationService = 142,
    LocalizationTable = 143,
    MaterialService = 145,
    MaterialVariant = 146,
    MemoryStoreService = 147,
    MeshPart = 148,
    Meshparts = 149,
    MessagingService = 150,
    Method = 151,
    Model = 152,
    Modelgroups = 153,
    Module = 154,
    ModuleScript = 155,
    Motor6D = 156,
    NegateOperation = 157,
    NetworkClient = 158,
    NoCollisionConstraint = 159,
    NumberValue = 284,
    ObjectValue = 284,
    Operator = 160,
    PackageLink = 161,
    Pants = 162,
    Part = 163,
    ParticleEmitter = 164,
    Path2D = 165,
    PathfindingLink = 166,
    PathfindingModifier = 167,
    PathfindingService = 168,
    PitchShiftSoundEffect = 169,
    Place = 170,
    Placeholder = 171,
    Plane = 172,
    PlaneConstraint = 173,
    Player = 174,
    Players = 175,
    PluginGuiService = 176,
    PointLight = 177,
    PrismaticConstraint = 178,
    Property = 179,
    ProximityPrompt = 180,
    PublishService = 181,
    RayValue = 284,
    Reference = 182,
    RemoteEvent = 183,
    RemoteFunction = 184,
    RenderingTest = 185,
    ReplicatedFirst = 186,
    ReplicatedScriptService = 187,
    ReplicatedStorage = 188,
    ReverbSoundEffect = 189,
    RigidConstraint = 190,
    RobloxPluginGuiService = 191,
    RocketPropulsion = 192,
    RodConstraint = 193,
    RopeConstraint = 194,
    Rotate = 195,
    ScreenGui = 196,
    Script = 197,
    ScrollingFrame = 198,
    Seat = 199,
    Selected_Workspace = 200,
    SelectionBox = 201,
    SelectionSphere = 202,
    ServerScriptService = 203,
    ServerStorage = 204,
    Service = 205,
    Shirt = 206,
    ShirtGraphic = 207,
    SkinnedMeshPart = 208,
    Sky = 209,
    Smoke = 210,
    Snap = 211,
    Snippet = 212,
    SocialService = 213,
    Sound = 214,
    SoundEffect = 215,
    SoundGroup = 216,
    SoundService = 217,
    Sparkles = 218,
    SpawnLocation = 219,
    SpecialMesh = 220,
    SphereHandleAdornment = 221,
    SpotLight = 222,
    SpringConstraint = 223,
    StandalonePluginScripts = 224,
    StarterCharacterScripts = 225,
    StarterGui = 226,
    StarterPack = 227,
    StarterPlayer = 228,
    StarterPlayerScripts = 229,
    StringValue = 284,
    Struct = 230,
    StyleDerive = 231,
    StyleLink = 232,
    StyleRule = 233,
    StyleSheet = 234,
    SunRaysEffect = 235,
    SurfaceAppearance = 236,
    SurfaceGui = 237,
    SurfaceLight = 238,
    SurfaceSelection = 239,
    SwimController = 240,
    TaskScheduler = 241,
    Team = 242,
    Teams = 243,
    Terrain = 244,
    TerrainDetail = 245,
    TestService = 246,
    TextBox = 247,
    TextBoxService = 248,
    TextButton = 249,
    TextChannel = 250,
    TextChatCommand = 251,
    TextChatService = 252,
    TextLabel = 253,
    TextString = 254,
    Texture = 255,
    Tool = 256,
    Torque = 257,
    TorsionSpringConstraint = 258,
    Trail = 259,
    TremoloSoundEffect = 260,
    TrussPart = 261,
    TypeParameter = 262,
    UGCValidationService = 263,
    UIAspectRatioConstraint = 264,
    UICorner = 265,
    UIDragDetector = 266,
    UIFlexItem = 267,
    UIGradient = 268,
    UIGridLayout = 269,
    UIListLayout = 270,
    UIPadding = 271,
    UIPageLayout = 272,
    UIScale = 273,
    UISizeConstraint = 274,
    UIStroke = 275,
    UITableLayout = 276,
    UITextSizeConstraint = 277,
    UnionOperation = 278,
    Unit = 279,
    UniversalConstraint = 280,
    UnreliableRemoteEvent = 281,
    UpdateAvailable = 282,
    UserService = 283,
    VRService = 296,
    Value = 284,
    Variable = 285,
    Vector3Value = 284,
    VectorForce = 286,
    VehicleSeat = 287,
    VideoDisplay = 288,
    VideoFrame = 289,
    VideoPlayer = 290,
    ViewportFrame = 291,
    VirtualUser = 292,
    VoiceChannel = 293,
    VoiceChatService = 295,
    Voicechat = 294,
    WedgePart = 297,
    Weld = 298,
    WeldConstraint = 299,
    Wire = 300,
    WireframeHandleAdornment = 301,
    Workspace = 302,
    WorldModel = 303,
    WrapDeformer = 304,
    WrapLayer = 305,
    WrapTarget = 306,
}

local function classIconFile(className)
    local name = className
    if type(name) ~= "string" or name == "" or not DEX_NEWDARK_INDEX[name] then
        name = "Placeholder"
    end
    return DEX_NEWDARK.Dir .. "/" .. name .. ".png"
end

local function createClassIcon(parent, className, sizePx, props)
    props = props or {}
    sizePx = sizePx or 14
    local fileName = classIconFile(className)
    local url = getAssetImage(fileName) or getAssetImage(classIconFile("Placeholder"))
    local icon = createInstance("ImageLabel", {
        Name = props.Name or "ClassIcon",
        Size = UDim2.new(0, sizePx, 0, sizePx),
        Position = props.Position,
        AnchorPoint = props.AnchorPoint or Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Image = url or "",
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = props.ZIndex or 2,
        Parent = parent,
    })
    return icon
end

local MODULE_TREE_ARROW_WIDTH = 12

local function moduleTreeArrowRotation(isExpanded)
    return isExpanded and 180 or 90
end

local function createModuleTreeArrow(parent, isExpanded, layout)
    
    local host = createInstance("Frame", {
        Name = "TreeArrow",
        Size = UDim2.new(0, 8, 0, 8),
        Position = UDim2.new(0, layout.arrow + MODULE_TREE_ARROW_WIDTH * 0.5, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Rotation = moduleTreeArrowRotation(isExpanded),
        ZIndex = 2,
        Parent = parent,
    })
    createAssetGlyph(host, "triangle.png", 8, {
        Name = "Glyph",
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ImageColor3 = Theme.TextMuted,
        Rotation = 0,
        ZIndex = 2,
    })
    return host
end

local function setModuleTreeArrowExpanded(arrow, isExpanded)
    if not arrow or not arrow:IsA("GuiObject") then
        return
    end
    arrow.Rotation = moduleTreeArrowRotation(isExpanded)
end

local function createTypeIcon(parent, typeName, sizePx, position)
    sizePx = sizePx or 18
    local assetFile = TypeAssets[typeName]
    local icon = createInstance("ImageLabel", {
        Name = "TypeIcon",
        Size = UDim2.new(0, sizePx, 0, sizePx),
        Position = position or UDim2.new(0, 6, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Image = "",
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 2,
        Parent = parent,
    })
    local fallback = createInstance("TextLabel", {
        Name = "TypeFallback",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = (TypeLabels[typeName] or tostring(typeName or "?")):gsub("[▲▼⇅]", ""),
        TextColor3 = TypeColors[typeName] or Theme.TextMuted,
        TextSize = math.max(8, sizePx - 8),
        Font = Theme.FontFamilyBold,
        Visible = false,
        ZIndex = 3,
        Parent = icon,
    })
    if assetFile then
        applyAssetIcon(icon, assetFile, fallback)
    else
        fallback.Visible = true
    end
    return icon
end

local function createPadding(parent, padding, left, right, top, bottom)
    parent = getG2Content(parent)
    return createInstance("UIPadding", {
        PaddingTop = UDim.new(0, top or padding or 12),
        PaddingBottom = UDim.new(0, bottom or padding or 12),
        PaddingLeft = UDim.new(0, left or padding or 12),
        PaddingRight = UDim.new(0, right or padding or 12),
        Parent = parent
    })
end

local function createListLayout(parent, padding, direction, hAlign, vAlign)
    parent = getG2Content(parent)
    return createInstance("UIListLayout", {
        Padding = UDim.new(0, padding or 8),
        FillDirection = direction or Enum.FillDirection.Vertical,
        HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
        VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = parent
    })
end

local function createGridLayout(parent, cellSize, padding)
    return createInstance("UIGridLayout", {
        CellSize = cellSize or UDim2.new(0, 100, 0, 30),
        CellPadding = UDim2.new(0, padding or 8, 0, padding or 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = parent
    })
end

local function tween(instance, properties, duration, style, direction)
    local tweenInfo = TweenInfo.new(
        duration or 0.2,
        style or Enum.EasingStyle.Quart,
        direction or Enum.EasingDirection.Out
    )
    if not instance or type(properties) ~= "table" then
        return nil
    end

    local fill, isImage = getSurfaceFill(instance)
    if isImage and fill then
        local mapped = {}
        for key, value in pairs(properties) do
            if key == "BackgroundTransparency" then
                mapped.ImageTransparency = value
            elseif key == "BackgroundColor3" then
                mapped.ImageColor3 = value
            else
                mapped[key] = value
            end
        end

        if fill ~= instance then
            local fillProps, hostProps = {}, {}
            for key, value in pairs(mapped) do
                if key == "ImageTransparency" or key == "ImageColor3" then
                    fillProps[key] = value
                else
                    hostProps[key] = value
                end
            end
            local lastTween = nil
            if next(fillProps) then
                lastTween = TweenService:Create(fill, tweenInfo, fillProps)
                lastTween:Play()
            end
            if next(hostProps) then
                lastTween = TweenService:Create(instance, tweenInfo, hostProps)
                lastTween:Play()
            end
            return lastTween
        end

        local t = TweenService:Create(instance, tweenInfo, mapped)
        t:Play()
        return t
    end

    local t = TweenService:Create(instance, tweenInfo, properties)
    t:Play()
    return t
end

local function createSplitResizer(parent, orientation, position, zIndex)
    local isVertical = orientation == "vertical"
    local hit = createInstance("TextButton", {
        Name = isVertical and "VerticalResizer" or "HorizontalResizer",
        Size = isVertical and UDim2.new(0, 10, 1, 0) or UDim2.new(1, 0, 0, 10),
        Position = position,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = zIndex or 5,
        Parent = parent,
    })
    local grip = createSquircle(Theme.Radius.Chip, "Squircle", {
        Name = "Grip",
        Size = isVertical and UDim2.new(0, 3, 0, 48) or UDim2.new(0, 48, 0, 3),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ImageColor3 = Theme.Border,
        ImageTransparency = 0.25,
        Parent = hit,
    }, false)
    hit.MouseEnter:Connect(function()
        tween(grip, {ImageColor3 = Theme.Primary, ImageTransparency = 0}, 0.15)
    end)
    hit.MouseLeave:Connect(function()
        tween(grip, {ImageColor3 = Theme.Border, ImageTransparency = 0.25}, 0.15)
    end)
    return hit, grip
end

local function deepCopy(original)
    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            copy[k] = deepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

if not parse then
    parse = function(value)
        local t = typeof(value)
        if t == "table" then
            local success, result = pcall(function()
                return HttpService:JSONEncode(value)
            end)
            if success then
                return result
            end
            return "{...}"
        else
            return tostring(value)
        end
    end
end

local resolveModuleByPath

local function isUsablePathExpr(path)
    return type(path) == "string"
        and path ~= ""
        and not path:find("nil %-%-%[%[", 1, false)
end

local function buildPathFromDottedName(fullName)
    if type(fullName) ~= "string" or fullName == "" then
        return nil
    end
    if fullName:sub(1, 4) == "game" then
        return fullName
    end
    local parts = {}
    for part in fullName:gmatch("[^%.]+") do
        parts[#parts + 1] = part
    end
    if #parts == 0 then
        return nil
    end
    local expr = 'game:GetService("' .. parts[1] .. '")'
    for i = 2, #parts do
        local part = parts[i]
        if part:match("^[%a_][%w_]*$") then
            expr = expr .. "." .. part
        else
            expr = expr .. '["' .. part:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"]'
        end
    end
    return expr
end

local function resolveInstanceFromDottedName(fullName)
    if type(fullName) ~= "string" or fullName == "" then
        return nil
    end
    local parts = {}
    for part in fullName:gmatch("[^%.]+") do
        parts[#parts + 1] = part
    end
    if #parts == 0 then
        return nil
    end
    local current
    local okSvc, svc = pcall(function()
        return game:GetService(parts[1])
    end)
    if okSvc and typeof(svc) == "Instance" then
        current = svc
    else
        current = game:FindFirstChild(parts[1])
    end
    if not current then
        return nil
    end
    for i = 2, #parts do
        local child = current:FindFirstChild(parts[i])
        if not child then
            return nil
        end
        current = child
    end
    return current
end

local function formatRobloxPath(pathOrInstance)
    if typeof(pathOrInstance) == "Instance" then
        if getInstancePathFromParser then
            local ok, path = pcall(getInstancePathFromParser, pathOrInstance)
            if ok and isUsablePathExpr(path) then
                return path
            end
        end
        local fullName
        pcall(function()
            fullName = pathOrInstance:GetFullName()
        end)
        return buildPathFromDottedName(fullName) or "nil"
    end

    if type(pathOrInstance) == "string" and pathOrInstance ~= "" then
        if pathOrInstance:sub(1, 4) == "game" then
            return pathOrInstance
        end
        if resolveModuleByPath then
            local mod = resolveModuleByPath(pathOrInstance)
            if mod and typeof(mod.Module) == "Instance" then
                return formatRobloxPath(mod.Module)
            end
        end
        local live = resolveInstanceFromDottedName(pathOrInstance)
        if live then
            return formatRobloxPath(live)
        end
        return buildPathFromDottedName(pathOrInstance) or "nil"
    end

    return "nil"
end

local function formatInstancePath(instance)
    if typeof(instance) == "Instance" then
        return formatRobloxPath(instance)
    end
    if type(instance) == "string" then
        return formatRobloxPath(instance)
    end
    return "nil"
end

local function serializeValue(value, depth)
    depth = depth or 0
    if depth > 5 then return "..." end
    
    local t = typeof(value)
    
    if t == "table" then
        local success, result = pcall(function()
            return parse(value)
        end)
        if success and result then
            return result
        end
        return "{...}"
    end
    
    if t == "string" then
        local escaped = value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
        return '"' .. escaped .. '"'
    elseif t == "number" then
        if value == math.huge then return "math.huge"
        elseif value == -math.huge then return "-math.huge"
        elseif value ~= value then return "0/0"
        else return tostring(value) end
    elseif t == "boolean" then
        return tostring(value)
    elseif t == "nil" then
        return "nil"
    elseif t == "Instance" then
        if getInstancePathFromParser then
            local ok, pathStr = pcall(getInstancePathFromParser, value)
            if ok and pathStr and pathStr ~= "" then
                return pathStr
            end
        end
        return formatRobloxPath(value)
    elseif t == "Vector3" then
        return string.format("Vector3.new(%s, %s, %s)", value.X, value.Y, value.Z)
    elseif t == "Vector2" then
        return string.format("Vector2.new(%s, %s)", value.X, value.Y)
    elseif t == "CFrame" then
        local components = {value:GetComponents()}
        return string.format("CFrame.new(%s)", table.concat(components, ", "))
    elseif t == "Color3" then
        return string.format("Color3.fromRGB(%d, %d, %d)", 
            math.floor(value.R * 255), 
            math.floor(value.G * 255), 
            math.floor(value.B * 255))
    elseif t == "BrickColor" then
        return string.format('BrickColor.new("%s")', value.Name)
    elseif t == "UDim" then
        return string.format("UDim.new(%s, %s)", value.Scale, value.Offset)
    elseif t == "UDim2" then
        return string.format("UDim2.new(%s, %s, %s, %s)", 
            value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset)
    elseif t == "Rect" then
        return string.format("Rect.new(%s, %s, %s, %s)", 
            value.Min.X, value.Min.Y, value.Max.X, value.Max.Y)
    elseif t == "Ray" then
        return string.format("Ray.new(Vector3.new(%s, %s, %s), Vector3.new(%s, %s, %s))",
            value.Origin.X, value.Origin.Y, value.Origin.Z,
            value.Direction.X, value.Direction.Y, value.Direction.Z)
    elseif t == "Region3" then
        return "Region3.new(...)"
    elseif t == "NumberSequence" then
        local keypoints = {}
        for _, kp in ipairs(value.Keypoints) do
            table.insert(keypoints, string.format("NumberSequenceKeypoint.new(%s, %s)", kp.Time, kp.Value))
        end
        return "NumberSequence.new({" .. table.concat(keypoints, ", ") .. "})"
    elseif t == "ColorSequence" then
        local keypoints = {}
        for _, kp in ipairs(value.Keypoints) do
            table.insert(keypoints, string.format("ColorSequenceKeypoint.new(%s, %s)", 
                kp.Time, serializeValue(kp.Value)))
        end
        return "ColorSequence.new({" .. table.concat(keypoints, ", ") .. "})"
    elseif t == "NumberRange" then
        return string.format("NumberRange.new(%s, %s)", value.Min, value.Max)
    elseif t == "Enum" then
        return tostring(value)
    elseif t == "EnumItem" then
        return tostring(value)
    elseif t == "function" then
        return "function() end"
    elseif t == "thread" then
        return "coroutine.create(function() end)"
    elseif t == "userdata" then
        return "newproxy(true)"
    elseif t == "buffer" then
        return "buffer.create(0)"
    else
        return "nil --[[ " .. t .. " ]]"
    end
end

local function formatValue(value)
    local t = typeof(value)
    
    if t == "string" then
        local display = value:sub(1, 60)
        if value:len() > 60 then display = display .. "..." end
        return '"' .. display:gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t") .. '"'
    elseif t == "Instance" then
        return value.Name .. " (" .. value.ClassName .. ")"
    elseif t == "table" then
        local count = 0
        for _ in pairs(value) do count = count + 1 end
        return "{" .. count .. " items}"
    elseif t == "function" then
        return "function()"
    elseif t == "Vector3" then
        return string.format("Vector3(%.1f, %.1f, %.1f)", value.X, value.Y, value.Z)
    elseif t == "CFrame" then
        return string.format("CFrame(%.1f, %.1f, %.1f)", value.X, value.Y, value.Z)
    elseif t == "Color3" then
        return string.format("RGB(%d, %d, %d)", 
            math.floor(value.R * 255), 
            math.floor(value.G * 255), 
            math.floor(value.B * 255))
    else
        local str = tostring(value)
        if #str > 50 then
            return str:sub(1, 47) .. "..."
        end
        return str
    end
end

local SNAPSHOT_MAX_DEPTH = 8
local FINGERPRINT_MAX_DEPTH = 4
local FINGERPRINT_MAX_KEYS = 24
local FINGERPRINT_MAX_STRING = 96

local InstancePathCache = setmetatable({}, {__mode = "k"})

local function getCachedInstancePath(inst)
    if typeof(inst) ~= "Instance" then
        return ""
    end
    local cached = InstancePathCache[inst]
    if cached ~= nil then
        return cached
    end
    local path = ""
    local ok, fullName = pcall(function()
        return inst:GetFullName()
    end)
    if ok and type(fullName) == "string" then
        path = fullName
    end
    InstancePathCache[inst] = path
    return path
end

local function captureArgumentSnapshot(value, depth, eager)
    depth = depth or 0
    local t = typeof(value)
    local snapshot = {
        Type = t,
        Display = nil,
        Preview = nil,
        Serialized = nil,
        _eager = eager and true or nil,
    }

    if t == "Instance" then
        local name, className
        local fullName = getCachedInstancePath(value)
        pcall(function()
            name = value.Name
            className = value.ClassName
        end)
        snapshot.Path = fullName
        snapshot.Name = name
        snapshot.ClassName = className
        snapshot.Preview = (name and className) and (name .. " (" .. className .. ")") or "Instance"
        if eager then
            snapshot.Display = serializeValue(value, 0)
            snapshot.Serialized = snapshot.Display
        end
    elseif t == "table" then
        if depth >= SNAPSHOT_MAX_DEPTH then
            snapshot.Preview = "{...}"
            if eager then
                snapshot.Display = "{...}"
                snapshot.Serialized = "{}"
            end
        else
            local count = 0
            for _ in pairs(value) do
                count = count + 1
                if count > 999 then
                    break
                end
            end
            snapshot.Preview = "{" .. count .. (count > 999 and "+" or "") .. " items}"
            if eager then
                local success, result = pcall(function()
                    return parse(value)
                end)
                snapshot.Display = (success and result) or "{...}"
                snapshot.Serialized = snapshot.Display
            end
        end
    else
        snapshot.Preview = formatValue(value)
        if eager then
            snapshot.Display = serializeValue(value, 0)
            snapshot.Serialized = snapshot.Display
        end
    end

    return snapshot
end

local function snapshotArguments(args, eager)
    local snapshots = {}
    for i, v in ipairs(args) do
        snapshots[i] = captureArgumentSnapshot(v, 0, eager)
    end
    return snapshots
end

local function ensureSnapshotMaterialized(snapshot, fallbackArg)
    if not snapshot then
        return
    end
    if snapshot.Display and snapshot.Serialized then
        return
    end
    local value = fallbackArg
    local t = snapshot.Type or typeof(value)
    if t == "Instance" then
        if typeof(value) == "Instance" then
            snapshot.Display = serializeValue(value, 0)
        elseif snapshot.Path and snapshot.Path ~= "" then
            snapshot.Display = snapshot.Path
        else
            snapshot.Display = snapshot.Preview or "Instance"
        end
        snapshot.Serialized = snapshot.Display
    elseif t == "table" then
        if type(value) == "table" then
            local success, result = pcall(function()
                return parse(value)
            end)
            snapshot.Display = (success and result) or (snapshot.Preview or "{...}")
        else
            snapshot.Display = snapshot.Preview or "{...}"
        end
        snapshot.Serialized = snapshot.Display
    else
        if value ~= nil then
            snapshot.Display = serializeValue(value, 0)
        else
            snapshot.Display = snapshot.Preview or "nil"
        end
        snapshot.Serialized = snapshot.Display
    end
end

local function getArgPreviewFromSnapshot(snapshot, fallbackArg)
    if snapshot and snapshot.Preview then
        return snapshot.Preview
    end
    if fallbackArg ~= nil then
        return formatValue(fallbackArg)
    end
    return "?"
end

local function getArgDisplayFromSnapshot(snapshot, fallbackArg)
    if snapshot then
        ensureSnapshotMaterialized(snapshot, fallbackArg)
        if snapshot.Display then
            return snapshot.Display
        end
    end
    if fallbackArg == nil then
        return "nil"
    end
    local typeStr = typeof(fallbackArg)
    if typeStr == "table" then
        local success, result = pcall(function()
            return parse(fallbackArg)
        end)
        return (success and result) or "{...}"
    end
    return serializeValue(fallbackArg, 0)
end

local function getArgTypeFromSnapshot(snapshot, fallbackArg)
    if snapshot and snapshot.Type then
        return snapshot.Type
    end
    if fallbackArg ~= nil then
        return typeof(fallbackArg)
    end
    return "unknown"
end

local function appendFingerprint(parts, value, depth, seen)
    local t = typeof(value)
    if t == "Instance" then
        parts[#parts + 1] = "I:"
        parts[#parts + 1] = getCachedInstancePath(value)
        return
    end
    if t == "table" then
        if depth >= FINGERPRINT_MAX_DEPTH then
            parts[#parts + 1] = "{...}"
            return
        end
        if seen[value] then
            parts[#parts + 1] = "{cyc}"
            return
        end
        seen[value] = true
        parts[#parts + 1] = "{"
        local n = 0
        local maxKey = 0
        local isArray = true
        for k in pairs(value) do
            n = n + 1
            if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
                isArray = false
            elseif k > maxKey then
                maxKey = k
            end
        end
        if n == 0 then
            parts[#parts + 1] = "}"
            return
        end
        if isArray and maxKey == n then
            local limit = math.min(n, FINGERPRINT_MAX_KEYS)
            for i = 1, limit do
                if i > 1 then
                    parts[#parts + 1] = ","
                end
                appendFingerprint(parts, value[i], depth + 1, seen)
            end
            if n > FINGERPRINT_MAX_KEYS then
                parts[#parts + 1] = ",+#"
                parts[#parts + 1] = tostring(n)
            end
        else
            local keys = {}
            local keyCount = 0
            for k in pairs(value) do
                keyCount = keyCount + 1
                keys[keyCount] = k
            end
            table.sort(keys, function(a, b)
                local ta, tb = type(a), type(b)
                if ta == tb then
                    return tostring(a) < tostring(b)
                end
                return ta < tb
            end)
            local limit = math.min(#keys, FINGERPRINT_MAX_KEYS)
            for i = 1, limit do
                if i > 1 then
                    parts[#parts + 1] = ","
                end
                parts[#parts + 1] = tostring(keys[i])
                parts[#parts + 1] = "="
                appendFingerprint(parts, value[keys[i]], depth + 1, seen)
            end
            if #keys > FINGERPRINT_MAX_KEYS then
                parts[#parts + 1] = ",+#"
                parts[#parts + 1] = tostring(#keys)
            end
        end
        parts[#parts + 1] = "}"
        return
    end
    if t == "string" then
        parts[#parts + 1] = "s:"
        if #value > FINGERPRINT_MAX_STRING then
            parts[#parts + 1] = value:sub(1, FINGERPRINT_MAX_STRING)
            parts[#parts + 1] = "#"
            parts[#parts + 1] = tostring(#value)
        else
            parts[#parts + 1] = value
        end
        return
    end
    if t == "number" or t == "boolean" or t == "nil" then
        parts[#parts + 1] = t:sub(1, 1)
        parts[#parts + 1] = ":"
        parts[#parts + 1] = tostring(value)
        return
    end
    if t == "Vector3" then
        parts[#parts + 1] = "V3:"
        parts[#parts + 1] = string.format("%.4f,%.4f,%.4f", value.X, value.Y, value.Z)
        return
    end
    if t == "Vector2" then
        parts[#parts + 1] = "V2:"
        parts[#parts + 1] = string.format("%.4f,%.4f", value.X, value.Y)
        return
    end
    if t == "CFrame" then
        parts[#parts + 1] = "CF:"
        parts[#parts + 1] = string.format("%.4f,%.4f,%.4f", value.X, value.Y, value.Z)
        return
    end
    if t == "EnumItem" then
        parts[#parts + 1] = "E:"
        parts[#parts + 1] = tostring(value)
        return
    end
    parts[#parts + 1] = t
    parts[#parts + 1] = ":"
    parts[#parts + 1] = tostring(value)
end

local function stableArgFingerprint(value)
    local parts = {}
    appendFingerprint(parts, value, 0, {})
    return table.concat(parts)
end

local function hashArgs(args)
    local parts = {}
    for i, v in ipairs(args) do
        if i > 1 then
            parts[#parts + 1] = "||"
        end
        appendFingerprint(parts, v, 0, {})
    end
    return table.concat(parts)
end

local function shallowCopyArgs(args)
    local copy = {}
    for i, v in ipairs(args) do
        copy[i] = v
    end
    return copy
end

local function nextLogId(counterHolder)
    local id = (counterHolder._nextLogId or 0) + 1
    counterHolder._nextLogId = id
    return id
end

local function getTimestamp()
    return os.date("%H:%M:%S")
end

local function getFullTimestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end
