-- spyTool/modules/10_ui_components.lua

local UIComponents = {}

local buttonBgState = setmetatable({}, { __mode = "k" })

local function setButtonBgState(button, baseBg, hoverBg)
    if button then
        buttonBgState[button] = { base = baseBg, hover = hoverBg }
    end
end

local function getButtonBaseBg(button, fallback)
    local state = buttonBgState[button]
    return state and state.base or fallback
end

local function getButtonHoverBg(button, fallback)
    local state = buttonBgState[button]
    return state and state.hover or fallback
end

function UIComponents.Badge(parent, text, color, size)
    size = size or 11
    local labelText = "  " .. tostring(text) .. "  "
    local width = measureTextWidth(labelText, size, Theme.FontFamilyBold) + 8
    local badge = createSquircle(Theme.Radius.Small, "Squircle", {
        Size = UDim2.new(0, width, 0, size + 8),
        ImageColor3 = color or Theme.Primary,
        ImageTransparency = 0.85,
        Parent = parent,
    }, false)
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = color or Theme.Primary,
        TextSize = size,
        Font = Theme.FontFamilyBold,
        Parent = badge
    })
    
    return badge
end

function UIComponents.Button(parent, text, variant, callback, icon)
    local bgColor, textColor, hoverColor
    
    if variant == "primary" then
        bgColor = Theme.Primary
        hoverColor = Theme.PrimaryHover
        textColor = Theme.TextPrimary
    elseif variant == "danger" then
        bgColor = Theme.Danger
        hoverColor = Theme.DangerMuted
        textColor = Theme.TextPrimary
    elseif variant == "success" then
        bgColor = Theme.Success
        hoverColor = Theme.SuccessMuted
        textColor = Theme.TextPrimary
    elseif variant == "warning" then
        bgColor = Theme.Warning
        hoverColor = Theme.WarningMuted
        textColor = Theme.Background
    elseif variant == "ghost" then
        bgColor = Theme.Background
        hoverColor = Theme.BackgroundTertiary
        textColor = Theme.TextSecondary
    else 
        bgColor = Theme.BackgroundTertiary
        hoverColor = Theme.BackgroundHover
        textColor = Theme.TextPrimary
    end
    
    local displayText = icon and (icon .. " " .. text) or text
    local labelText = "  " .. displayText .. "  "
    local width = math.max(56, measureTextWidth(labelText, 11, Theme.FontFamily) + 16)

    local button = createSquircle(Theme.Radius.Small, "Squircle", {
        Size = UDim2.new(0, width, 0, 30),
        ImageColor3 = bgColor,
        Parent = parent,
    }, true)
    
    if variant == "ghost" or variant == "secondary" or not variant then
        createSquircle(Theme.Radius.Small, "SquircleOutline", {
            Name = "Outline",
            Size = UDim2.new(1, 0, 1, 0),
            ImageColor3 = Theme.Border,
            ZIndex = 0,
            Parent = button,
        }, false)
    end
    
    createInstance("TextLabel", {
        Name = "Label",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = textColor,
        TextSize = 11,
        Font = Theme.FontFamily,
        ZIndex = 2,
        Parent = button
    })
    
    setButtonBgState(button, bgColor, hoverColor)

    button.MouseEnter:Connect(function()
        if isSquircle(button) then
            tween(button, {ImageColor3 = getButtonHoverBg(button, hoverColor)}, 0.15)
        else
            tween(button, {BackgroundColor3 = getButtonHoverBg(button, hoverColor)}, 0.15)
        end
    end)
    
    button.MouseLeave:Connect(function()
        if isSquircle(button) then
            tween(button, {ImageColor3 = getButtonBaseBg(button, bgColor)}, 0.15)
        else
            tween(button, {BackgroundColor3 = getButtonBaseBg(button, bgColor)}, 0.15)
        end
    end)
    
    button.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)
    
    return button
end

function UIComponents.IconButton(parent, icon, callback, size, tooltip)
    size = size or 28
    local isAssetIcon = type(icon) == "string" and icon:match("%.png$") ~= nil
    local assetUrl = isAssetIcon and getAssetImage(icon) or nil
    local textFallback = ""
    if isAssetIcon then
        if icon == "minimize.png" then
            textFallback = "_"
        elseif icon == "maximize.png" then
            textFallback = "□"
        elseif icon == "close.png" then
            textFallback = "X"
        elseif icon == "play.png" then
            textFallback = ">"
        elseif icon == "pause.png" then
            textFallback = "||"
        elseif icon == "clear.png" then
            textFallback = "C"
        elseif icon == "rescan.png" then
            textFallback = "R"
        elseif icon == "search.png" then
            textFallback = "Q"
        elseif icon == "more.png" then
            textFallback = "…"
        else
            textFallback = "•"
        end
    else
        textFallback = tostring(icon or "")
    end
    
    local button = createSquircle(Theme.Radius.Small, "Squircle", {
        Size = UDim2.new(0, size, 0, size),
        ImageColor3 = Theme.BackgroundTertiary,
        ImageTransparency = 1,
        ZIndex = 12,
        Parent = parent,
    }, true)

    local textLabel = nil
    if not assetUrl then
        textLabel = createInstance("TextLabel", {
            Name = "Glyph",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = textFallback,
            TextColor3 = Theme.TextSecondary,
            TextSize = math.floor(size * 0.5),
            Font = Theme.FontFamily,
            ZIndex = 13,
            Parent = button,
        })
    end

    local iconImage = nil
    if assetUrl then
        iconImage = createInstance("ImageLabel", {
            Name = "IconImage",
            Size = UDim2.new(0, math.floor(size * 0.55), 0, math.floor(size * 0.55)),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Image = assetUrl,
            ImageColor3 = Theme.TextSecondary,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 13,
            Parent = button
        })
    end
    
    if tooltip then
        local tipText = "  " .. tooltip .. "  "
        local tipWidth = measureTextWidth(tipText, 11, Theme.FontFamily) + 12
        local tooltipLabel = createSquircle(Theme.Radius.Small, "Squircle", {
            Name = "Tooltip",
            Size = UDim2.new(0, tipWidth, 0, 24),
            Position = UDim2.new(0.5, 0, 1, 4),
            AnchorPoint = Vector2.new(0.5, 0),
            ImageColor3 = Theme.BackgroundSecondary,
            Visible = false,
            ZIndex = 9999,
            Parent = button,
        }, false)
        createSquircle(Theme.Radius.Small, "SquircleOutline", {
            Size = UDim2.new(1, 0, 1, 0),
            ImageColor3 = Theme.Border,
            ZIndex = 0,
            Parent = tooltipLabel,
        }, false)
        createInstance("TextLabel", {
            Name = "TooltipText",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = tipText,
            TextColor3 = Theme.TextPrimary,
            TextSize = 11,
            Font = Theme.FontFamily,
            ZIndex = 1,
            Parent = tooltipLabel,
        })
        
        button.MouseEnter:Connect(function()
            tooltipLabel.Visible = true
        end)
        
        button.MouseLeave:Connect(function()
            tooltipLabel.Visible = false
        end)
    end
    
    local function resolveIconBaseColor()
        local accent = button:GetAttribute("IconAccent")
        if accent == "danger" then
            return Theme.Danger
        elseif accent == "primary" then
            return Theme.Primary
        end
        return Theme.TextSecondary
    end

    button.MouseEnter:Connect(function()
        tween(button, {ImageTransparency = 0}, 0.15)
        if iconImage then
            tween(iconImage, {ImageColor3 = Theme.TextPrimary}, 0.15)
        end
        if textLabel then
            tween(textLabel, {TextColor3 = Theme.TextPrimary}, 0.15)
        end
    end)
    
    button.MouseLeave:Connect(function()
        tween(button, {ImageTransparency = 1}, 0.15)
        local base = resolveIconBaseColor()
        if iconImage then
            tween(iconImage, {ImageColor3 = base}, 0.15)
        end
        if textLabel then
            tween(textLabel, {TextColor3 = base}, 0.15)
        end
    end)
    
    button.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)
    
    return button
end

function UIComponents.Toggle(parent, initialState, callback, label)
    local state = initialState or false
    local trackW, trackH = 44, 24
    local knobSize = 18
    local knobPad = 3
    local dragging = false
    local didDrag = false
    
    local container = createInstance("Frame", {
        Size = UDim2.new(0, label and 200 or trackW, 0, trackH),
        BackgroundTransparency = 1,
        Parent = parent
    })
    
    if label then
        createInstance("TextLabel", {
            Size = UDim2.new(1, -(trackW + 8), 1, 0),
            BackgroundTransparency = 1,
            Text = label,
            TextColor3 = Theme.TextPrimary,
            TextSize = 13,
            Font = Theme.FontFamily,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = container
        })
    end
    
    local toggleBg = createInstance("Frame", {
        Size = UDim2.new(0, trackW, 0, trackH),
        Position = label and UDim2.new(1, -trackW, 0.5, -trackH / 2) or UDim2.new(0, 0, 0.5, -trackH / 2),
        BackgroundColor3 = state and Theme.Primary or Theme.BackgroundTertiary,
        BorderSizePixel = 0,
        
        ClipsDescendants = false,
        Parent = container
    })
    
    createCorner(toggleBg, Theme.CornerRadiusFull)
    
    
    local function knobPosForState(on)
        if on then
            return UDim2.new(1, -(knobPad + knobSize * 0.5), 0.5, 0)
        end
        return UDim2.new(0, knobPad + knobSize * 0.5, 0.5, 0)
    end

    local knob = createInstance("Frame", {
        Name = "Knob",
        Size = UDim2.new(0, knobSize, 0, knobSize),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = knobPosForState(state),
        BackgroundColor3 = Theme.TextPrimary,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = toggleBg
    })
    createCorner(knob, Theme.CornerRadiusFull)
    local knobScale = createInstance("UIScale", {
        Scale = 1,
        Parent = knob,
    })
    local knobStroke = createStroke(knob, Color3.new(1, 1, 1), 0.5)
    knobStroke.Transparency = 1
    
    local hitbox = createInstance("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 3,
        Parent = toggleBg
    })
    
    local function updateState(newState, animate)
        state = newState == true
        local dur = animate == false and 0 or 0.2
        knobScale.Scale = 1
        knob.BackgroundTransparency = 0
        knobStroke.Transparency = 1
        tween(toggleBg, {BackgroundColor3 = state and Theme.Primary or Theme.BackgroundTertiary}, dur)
        tween(knob, {Position = knobPosForState(state)}, dur)
    end
    
    local function setKnobDragging(active)
        if active then
            tween(knobScale, {Scale = 1.45}, 0.22)
            tween(knob, {
                BackgroundTransparency = 0.65,
                BackgroundColor3 = Color3.new(1, 1, 1),
            }, 0.22)
            tween(knobStroke, {Transparency = 0}, 0.22)
        else
            tween(knobScale, {Scale = 1}, 0.2)
            tween(knob, {
                BackgroundTransparency = 0,
                BackgroundColor3 = Theme.TextPrimary,
            }, 0.2)
            tween(knobStroke, {Transparency = 1}, 0.2)
        end
    end
    
    local function finishDrag()
        if not dragging then
            return
        end
        dragging = false
        setKnobDragging(false)
        if didDrag then
            local centerX = knob.AbsolutePosition.X + knob.AbsoluteSize.X / 2
            local midX = toggleBg.AbsolutePosition.X + toggleBg.AbsoluteSize.X / 2
            local newState = centerX > midX
            updateState(newState, true)
            if callback then
                callback(state)
            end
        else
            updateState(not state, true)
            if callback then
                callback(state)
            end
        end
        didDrag = false
    end
    
    hitbox.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        dragging = true
        didDrag = false
        setKnobDragging(true)
    end)
    
    hitbox.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            finishDrag()
        end
    end)
    
    local dragConn = UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        if not toggleBg.Parent then
            dragging = false
            return
        end
        -- Position is center (AnchorPoint 0.5, 0.5) — do not apply top-left Y offsets.
        local minCenter = knobPad + knobSize * 0.5
        local maxCenter = trackW - knobPad - knobSize * 0.5
        local centerX = input.Position.X - toggleBg.AbsolutePosition.X
        centerX = math.clamp(centerX, minCenter, maxCenter)
        local restCenter = state and maxCenter or minCenter
        if math.abs(centerX - restCenter) > 2 then
            didDrag = true
        end
        knob.Position = UDim2.new(0, centerX, 0.5, 0)
        local pct = (centerX - minCenter) / math.max(1, maxCenter - minCenter)
        toggleBg.BackgroundColor3 = Theme.BackgroundTertiary:Lerp(Theme.Primary, pct)
    end)
    
    container.Destroying:Connect(function()
        dragging = false
        if dragConn then
            pcall(function()
                dragConn:Disconnect()
            end)
            dragConn = nil
        end
    end)
    
    return container, updateState, function() return state end
end

function UIComponents.Checkbox(parent, initialState, callback, label)
    local state = initialState == true
    local interactive = type(callback) == "function"
    
    local container = createInstance("Frame", {
        Size = UDim2.new(0, label and 72 or 16, 0, 16),
        BackgroundTransparency = 1,
        Parent = parent
    })
    createListLayout(container, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
    
    local box = createSquircle(Theme.Radius.Small, "Squircle", {
        Name = "Checkbox",
        Size = UDim2.new(0, 16, 0, 16),
        ImageColor3 = state and Theme.Primary or Theme.BackgroundTertiary,
        LayoutOrder = 1,
        Active = interactive,
        Parent = container,
    }, interactive)
    if not interactive and box:IsA("ImageLabel") then
        
    elseif not interactive then
        box.Active = false
        pcall(function()
            box.AutoButtonColor = false
        end)
    end
    local outline = createSquircle(Theme.Radius.Small, "SquircleOutline", {
        Name = "Outline",
        Size = UDim2.new(1, 0, 1, 0),
        ImageColor3 = state and Theme.Primary or Theme.Border,
        ZIndex = 0,
        Parent = box,
    }, false)
    local checkIcon = createAssetGlyph(box, "check.png", 10, {
        Name = "CheckIcon",
        Position = UDim2.new(0.5, 0, 0.5, 0),
        ImageColor3 = Theme.TextPrimary,
        Visible = state,
        ZIndex = 2,
    })
    
    if label then
        createInstance("TextLabel", {
            Size = UDim2.new(0, 52, 1, 0),
            BackgroundTransparency = 1,
            Text = label,
            TextColor3 = Theme.TextSecondary,
            TextSize = 10,
            Font = Theme.FontFamily,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 2,
            Parent = container
        })
    end
    
    local function updateState(newState)
        state = newState == true
        setSquircleColor(box, state and Theme.Primary or Theme.BackgroundTertiary)
        outline.ImageColor3 = state and Theme.Primary or Theme.Border
        checkIcon.Visible = state
    end
    
    if interactive and box:IsA("GuiButton") then
        box.MouseButton1Click:Connect(function()
            updateState(not state)
            callback(state)
        end)
    end
    
    return container, updateState, function()
        return state
    end
end

function UIComponents.Slider(parent, min, max, initialValue, step, callback, formatValue, labelWidth, frictionOptions)
    min = min or 0
    max = max or 1
    step = step or 0.01
    labelWidth = labelWidth or 40
    local value = initialValue or min
    local dragging = false

    local frictionValue = frictionOptions and frictionOptions.frictionValue
    local confirmValue = frictionOptions and frictionOptions.confirmValue
    local frictionAlpha = frictionOptions and frictionOptions.frictionAlpha or 0.9
    local confirmAlpha = frictionOptions and frictionOptions.confirmAlpha or 1
    local hasFriction = frictionValue ~= nil and confirmValue ~= nil
    
    local container = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Parent = parent
    })
    
    local trackColor = Theme.BackgroundTertiary
    local bar = createInstance("Frame", {
        Size = UDim2.new(1, -(labelWidth + 4), 0, 6),
        Position = UDim2.new(0, 0, 0.5, -3),
        
        BackgroundColor3 = hasFriction and Color3.new(1, 1, 1) or trackColor,
        Parent = container
    })
    createCorner(bar, Theme.CornerRadiusFull)

    if hasFriction then
        local markPos = math.clamp(frictionAlpha, 0.02, 0.98)
        local lineSharp = 0.001
        local lineHalf = 0.004
        local linestart_2 = markPos - lineHalf
        local linestart_1 = linestart_2 - lineSharp
        local lineend_1 = markPos + lineHalf
        local lineend_2 = lineend_1 + lineSharp

        linestart_1 = math.clamp(linestart_1, 0, 1)
        linestart_2 = math.clamp(linestart_2, linestart_1 + 0.0001, 1)
        lineend_1 = math.clamp(lineend_1, linestart_2 + 0.0001, 1)
        lineend_2 = math.clamp(lineend_2, lineend_1 + 0.0001, 1)

        local lineColor = Theme.BorderHover
        createInstance("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, trackColor),
                ColorSequenceKeypoint.new(linestart_1, trackColor),
                ColorSequenceKeypoint.new(linestart_2, lineColor),
                ColorSequenceKeypoint.new(lineend_1, lineColor),
                ColorSequenceKeypoint.new(lineend_2, trackColor),
                ColorSequenceKeypoint.new(1, trackColor),
            }),
            Parent = bar
        })
    end
    
    local fill = createInstance("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.Primary,
        Parent = bar
    })
    createCorner(fill, Theme.CornerRadiusFull)

    local knobBase = 12
    local knob = createInstance("Frame", {
        Size = UDim2.new(0, knobBase, 0, knobBase),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = Theme.TextPrimary,
        BackgroundTransparency = 0,
        ZIndex = 3,
        Parent = bar
    })
    createCorner(knob, Theme.CornerRadiusFull)
    local knobScale = createInstance("UIScale", {
        Scale = 1,
        Parent = knob,
    })
    local knobStroke = createStroke(knob, Color3.new(1, 1, 1), 1)
    knobStroke.Transparency = 1

    local function setSliderKnobDragging(active)
        if active then
            tween(knobScale, {Scale = 1.55}, 0.22)
            tween(knob, {
                BackgroundTransparency = 0.7,
                BackgroundColor3 = Color3.new(1, 1, 1),
            }, 0.22)
            tween(knobStroke, {Transparency = 0}, 0.22)
        else
            tween(knobScale, {Scale = 1}, 0.2)
            tween(knob, {
                BackgroundTransparency = 0,
                BackgroundColor3 = Theme.TextPrimary,
            }, 0.2)
            tween(knobStroke, {Transparency = 1}, 0.2)
        end
    end
    
    local valueLabel = createInstance("TextLabel", {
        Size = UDim2.new(0, labelWidth, 1, 0),
        Position = UDim2.new(1, -labelWidth, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.TextMuted,
        TextSize = 10,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = container
    })
    
    local function format(v)
        if formatValue then
            return formatValue(v)
        end
        if max <= 1 then
            return string.format("%.2fs", v)
        end
        if step and step < 1 then
            return string.format("%.2f", v)
        end
        return tostring(math.floor(v + 0.5))
    end

    local function valueToAlpha(v)
        if not hasFriction then
            return (max == min) and 0 or (v - min) / (max - min)
        end
        if v >= confirmValue then
            return confirmAlpha
        end
        if v >= frictionValue then
            return frictionAlpha
        end
        if frictionValue == min then
            return 0
        end
        local t = (v - min) / (frictionValue - min)
        return t * frictionAlpha
    end

    local function relToValue(rel)
        rel = math.clamp(rel, 0, 1)
        if not hasFriction then
            return min + (max - min) * rel
        end
        if rel >= confirmAlpha then
            return confirmValue
        end
        if rel >= frictionAlpha then
            return frictionValue
        end
        local t = (frictionAlpha > 0) and (rel / frictionAlpha) or 0
        local raw = min + (frictionValue - min) * t
        if step and step > 0 then
            raw = math.floor((raw - min) / step + 0.5) * step + min
        end
        return math.clamp(raw, min, frictionValue)
    end
    
    local function applyValue(v, skipCallback)
        if max == min then
            v = min
        else
            v = math.clamp(v, min, max)
        end
        if not hasFriction then
            if step and step > 0 then
                v = math.floor((v - min) / step + 0.5) * step + min
            end
            value = math.clamp(v, min, max)
        elseif v >= confirmValue then
            value = confirmValue
        elseif v >= frictionValue then
            value = frictionValue
        else
            if step and step > 0 then
                v = math.floor((v - min) / step + 0.5) * step + min
            end
            value = math.clamp(v, min, frictionValue)
        end
        local alpha = valueToAlpha(value)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = format(value)
        if callback and not skipCallback then
            callback(value)
        end
    end
    
    local function updateFromX(x)
        if max == min then
            applyValue(min)
            return
        end
        local rel = (x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
        rel = math.clamp(rel, 0, 1)
        applyValue(relToValue(rel))
    end
    
    local function beginSliderDrag(input)
        dragging = true
        setSliderKnobDragging(true)
        updateFromX(input.Position.X)
    end

    local function endSliderDrag()
        if not dragging then
            return
        end
        dragging = false
        setSliderKnobDragging(false)
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            beginSliderDrag(input)
        end
    end)
    
    bar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            endSliderDrag()
        end
    end)
    
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            beginSliderDrag(input)
        end
    end)
    
    knob.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            endSliderDrag()
        end
    end)

    local endConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            endSliderDrag()
        end
    end)
    
    local dragConn = UserInputService.InputChanged:Connect(function(input)
        if not dragging or input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end
        if not bar.Parent then
            dragging = false
            return
        end
        updateFromX(input.Position.X)
    end)

    container.Destroying:Connect(function()
        dragging = false
        if dragConn then
            pcall(function()
                dragConn:Disconnect()
            end)
            dragConn = nil
        end
        if endConn then
            pcall(function()
                endConn:Disconnect()
            end)
            endConn = nil
        end
    end)
    
    applyValue(value, true)
    return container, function(v) applyValue(v) end, function() return value end
end

function UIComponents.NumberBox(parent, min, max, initialValue, step, callback, formatDisplay)
    min = min or 0
    max = max or 100
    step = step or 1
    local value = initialValue or min
    
    local inputHeight = 26
    local buttonWidth = 26
    local inputWidth = 50
    local totalWidth = buttonWidth + inputWidth + buttonWidth
    
    local container = createInstance("Frame", {
        Size = UDim2.new(0, totalWidth, 0, inputHeight),
        BackgroundColor3 = Theme.BackgroundTertiary,
        Parent = parent
    })
    
    createCorner(container, Theme.CornerRadiusFull)
    
    
    local minusBtn = createInstance("TextButton", {
        Size = UDim2.new(0, buttonWidth, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
        Parent = container
    })
    createCorner(minusBtn, Theme.CornerRadiusSmall)
    
    local minusBtnLabel = createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "-",
        TextColor3 = Theme.TextPrimary,
        TextSize = 14,
        Font = Theme.FontFamilyBold,
        ZIndex = 2,
        Parent = minusBtn
    })
    
    
    local minusBtnHighlight = createInstance("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.BackgroundHover,
        BackgroundTransparency = 1,
        ZIndex = 0,
        Parent = minusBtn
    })
    createCorner(minusBtnHighlight, Theme.CornerRadiusSmall)
    createInstance("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.75, 0),
            NumberSequenceKeypoint.new(0.76, 1),
            NumberSequenceKeypoint.new(1, 1)
        }),
        Parent = minusBtnHighlight
    })
    local minusHighlightExtend = createInstance("Frame", {
        Size = UDim2.new(0.3, 0, 1, 0),
        Position = UDim2.new(0.7, 0, 0, 0),
        BackgroundColor3 = Theme.BackgroundHover,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 0,
        Parent = minusBtn
    })
    
    
    createInstance("Frame", {
        Size = UDim2.new(0, 1, 1, -6),
        Position = UDim2.new(0, buttonWidth, 0, 3),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
        Parent = container
    })
    
    
    local input = createInstance("TextBox", {
        Size = UDim2.new(0, inputWidth, 1, 0),
        Position = UDim2.new(0, buttonWidth, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Theme.FontFamilyMono,
        Parent = container
    })
    
    
    createInstance("Frame", {
        Size = UDim2.new(0, 1, 1, -6),
        Position = UDim2.new(0, buttonWidth + inputWidth, 0, 3),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
        Parent = container
    })
    
    
    local plusBtn = createInstance("TextButton", {
        Size = UDim2.new(0, buttonWidth, 1, 0),
        Position = UDim2.new(0, buttonWidth + inputWidth, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
        Parent = container
    })
    createCorner(plusBtn, Theme.CornerRadiusSmall)
    
    local plusBtnLabel = createInstance("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "+",
        TextColor3 = Theme.TextPrimary,
        TextSize = 14,
        Font = Theme.FontFamilyBold,
        ZIndex = 2,
        Parent = plusBtn
    })
    
    
    local plusBtnHighlight = createInstance("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.BackgroundHover,
        BackgroundTransparency = 1,
        ZIndex = 0,
        Parent = plusBtn
    })
    createCorner(plusBtnHighlight, Theme.CornerRadiusSmall)
    createInstance("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.24, 1),
            NumberSequenceKeypoint.new(0.25, 0),
            NumberSequenceKeypoint.new(1, 0)
        }),
        Parent = plusBtnHighlight
    })
    local plusHighlightExtend = createInstance("Frame", {
        Size = UDim2.new(0.3, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Theme.BackgroundHover,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 0,
        Parent = plusBtn
    })
    
    
    minusBtn.MouseEnter:Connect(function()
        tween(minusBtnHighlight, {BackgroundTransparency = 0}, 0.15)
        tween(minusHighlightExtend, {BackgroundTransparency = 0}, 0.15)
    end)
    minusBtn.MouseLeave:Connect(function()
        tween(minusBtnHighlight, {BackgroundTransparency = 1}, 0.15)
        tween(minusHighlightExtend, {BackgroundTransparency = 1}, 0.15)
    end)
    plusBtn.MouseEnter:Connect(function()
        tween(plusBtnHighlight, {BackgroundTransparency = 0}, 0.15)
        tween(plusHighlightExtend, {BackgroundTransparency = 0}, 0.15)
    end)
    plusBtn.MouseLeave:Connect(function()
        tween(plusBtnHighlight, {BackgroundTransparency = 1}, 0.15)
        tween(plusHighlightExtend, {BackgroundTransparency = 1}, 0.15)
    end)
    
    local function format(v)
        if formatDisplay then
            return formatDisplay(v)
        end
        return tostring(v)
    end
    
    local function updateDisplay()
        input.Text = format(value)
    end
    
    local function applyValue(newValue, skipCallback)
        newValue = math.clamp(newValue, min, max)
        if step and step > 0 then
            newValue = math.floor((newValue - min) / step + 0.5) * step + min
        end
        value = math.clamp(newValue, min, max)
        updateDisplay()
        if callback and not skipCallback then
            callback(value)
        end
    end
    
    minusBtn.MouseButton1Click:Connect(function()
        applyValue(value - step)
    end)
    
    plusBtn.MouseButton1Click:Connect(function()
        applyValue(value + step)
    end)
    
    input.FocusLost:Connect(function()
        local text = input.Text:gsub("[^%d%.%-]", "")
        local num = tonumber(text)
        if num then
            applyValue(num)
        else
            updateDisplay()
        end
    end)
    
    applyValue(value, true)
    return container, function(v) applyValue(v) end, function() return value end
end

function UIComponents.SearchBar(parent, placeholder, callback, opts)
    opts = opts or {}
    local usePill = opts.Pill == true
    local showIcon = opts.Icon ~= false
    local iconFile = opts.IconFile or "search.png"
    local radiusPx = usePill and (tonumber(opts.Radius) or 999) or Theme.Radius.Small
    local showOutline = opts.Outline ~= false and not usePill
    local leftPad = showIcon and 30 or 10
    local fillColor = opts.ImageColor3 or Theme.BackgroundSecondary
    local cornerRadius = usePill and (Theme.CornerRadiusFull or UDim.new(0, 999)) or UDim.new(0, radiusPx)
    local expandable = opts.Expandable == true
    local expandDuration = tonumber(opts.ExpandDuration) or 0.2
    local placeholderText = placeholder or "Search..."

    local container
    do
        local ok, group = pcall(function()
            return createInstance("CanvasGroup", {
                Name = "SearchBar",
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = fillColor,
                BorderSizePixel = 0,
                Parent = parent,
            })
        end)
        if ok and group then
            container = group
        else
            container = createInstance("Frame", {
                Name = "SearchBar",
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = fillColor,
                BorderSizePixel = 0,
                ClipsDescendants = true,
                Parent = parent,
            })
        end
    end
    createInstance("UICorner", {
        CornerRadius = cornerRadius,
        Parent = container,
    })

    local outline = nil
    if showOutline then
        outline = createInstance("UIStroke", {
            Name = "Outline",
            Color = Theme.Border,
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = container,
        })
    end

    local icon = nil
    if showIcon then
        icon = createInstance("ImageLabel", {
            Name = "SearchIcon",
            Size = UDim2.new(0, 14, 0, 14),
            Position = UDim2.new(0, 10, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundTransparency = 1,
            Image = "",
            ImageColor3 = Theme.TextMuted,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 2,
            Parent = container,
        })
        local iconUrl = getAssetImage(iconFile)
        if iconUrl then
            icon.Image = iconUrl
        else
            createInstance("TextLabel", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "Q",
                TextColor3 = Theme.TextMuted,
                TextSize = 11,
                Font = Theme.FontFamilyBold,
                Parent = icon,
            })
        end
    end

    local input = createInstance("TextBox", {
        Size = UDim2.new(1, -(leftPad + 24), 1, 0),
        Position = UDim2.new(0, leftPad, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = placeholderText,
        PlaceholderColor3 = Theme.TextMuted,
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ClearTextOnFocus = false,
        ClipsDescendants = true,
        ZIndex = 1,
        Parent = container,
    })

    local clearBtn = createInstance("ImageButton", {
        Name = "ClearSearch",
        Size = UDim2.new(0, 16, 0, 16),
        Position = UDim2.new(1, -22, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Image = "",
        ImageColor3 = Theme.TextMuted,
        ScaleType = Enum.ScaleType.Fit,
        Visible = false,
        ZIndex = 2,
        AutoButtonColor = false,
        Parent = container,
    })
    local clearUrl = getAssetImage("close.png")
    if clearUrl then
        clearBtn.Image = clearUrl
    else
        createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "×",
            TextColor3 = Theme.TextMuted,
            TextSize = 14,
            Font = Theme.FontFamilyBold,
            ZIndex = 1,
            Parent = clearBtn,
        })
    end

    local function syncClearVisible()
        clearBtn.Visible = (not expandable or container:GetAttribute("SearchExpanded") == true) and input.Text ~= ""
    end

    clearBtn.MouseButton1Click:Connect(function()
        input.Text = ""
        input:CaptureFocus()
        if callback then
            callback("")
        end
        syncClearVisible()
    end)
    clearBtn.MouseEnter:Connect(function()
        clearBtn.ImageColor3 = Theme.TextPrimary
    end)
    clearBtn.MouseLeave:Connect(function()
        clearBtn.ImageColor3 = Theme.TextMuted
    end)

    if expandable then
        local wrap = parent
        local collapsedSize = opts.CollapsedSize or UDim2.new(0, 24, 0, 24)
        local collapsedPos = opts.CollapsedPosition or wrap.Position
        local expandedSize = opts.ExpandedSize or UDim2.new(1, 0, 0, 24)
        local expandedPos = opts.ExpandedPosition or UDim2.new(0, 0, 0.5, 0)
        local isExpanded = false

        local function applyCollapsedChrome()
            if icon then
                icon.Position = UDim2.new(0.5, 0, 0.5, 0)
                icon.AnchorPoint = Vector2.new(0.5, 0.5)
            end
            input.Size = UDim2.new(1, 0, 1, 0)
            input.Position = UDim2.new(0, 0, 0, 0)
            input.TextTransparency = 1
            input.PlaceholderText = ""
            clearBtn.Visible = false
        end

        local function applyExpandedChrome()
            if icon then
                icon.Position = UDim2.new(0, 10, 0.5, 0)
                icon.AnchorPoint = Vector2.new(0, 0.5)
            end
            input.Size = UDim2.new(1, -(leftPad + 24), 1, 0)
            input.Position = UDim2.new(0, leftPad, 0, 0)
            input.TextTransparency = 0
            input.PlaceholderText = placeholderText
            syncClearVisible()
        end

        local function setExpanded(expanded, instant)
            expanded = expanded == true
            if isExpanded == expanded and not instant then
                return
            end
            isExpanded = expanded
            container:SetAttribute("SearchExpanded", expanded)
            local size = expanded and expandedSize or collapsedSize
            local pos = expanded and expandedPos or collapsedPos
            if instant then
                wrap.Size = size
                wrap.Position = pos
            else
                tween(wrap, {Size = size, Position = pos}, expandDuration)
            end
            if expanded then
                applyExpandedChrome()
            else
                applyCollapsedChrome()
            end
        end

        applyCollapsedChrome()
        wrap.Size = collapsedSize
        wrap.Position = collapsedPos
        container:SetAttribute("SearchExpanded", false)

        input.Focused:Connect(function()
            setExpanded(true)
            if outline then
                tween(outline, {Color = Theme.Primary}, 0.15)
            end
        end)

        input.FocusLost:Connect(function()
            if outline then
                tween(outline, {Color = Theme.Border}, 0.15)
            end
            if input.Text == "" then
                setExpanded(false)
            end
        end)

        input:GetPropertyChangedSignal("Text"):Connect(function()
            if isExpanded then
                syncClearVisible()
            end
            if callback then
                callback(input.Text)
            end
            if input.Text ~= "" and not isExpanded then
                setExpanded(true, true)
            end
        end)
    else
        input.Focused:Connect(function()
            if outline then
                tween(outline, {Color = Theme.Primary}, 0.15)
            end
        end)

        input.FocusLost:Connect(function()
            if outline then
                tween(outline, {Color = Theme.Border}, 0.15)
            end
        end)

        input:GetPropertyChangedSignal("Text"):Connect(function()
            syncClearVisible()
            if callback then
                callback(input.Text)
            end
        end)
    end

    return container, input
end

local function findScreenGui(instance)
    local current = instance
    while current and not current:IsA("ScreenGui") do
        current = current.Parent
    end
    return current
end

function UIComponents.Dropdown(parent, options, defaultOption, callback)
    local isOpen = false
    local selectedOption = defaultOption or options[1]
    local menuHeight = #options * 26 + 8
    local dockedMenuPos = UDim2.new(0, 0, 1, 4)
    local dockedMenuSize = UDim2.new(1, 0, 0, menuHeight)
    
    local container = createInstance("Frame", {
        Size = UDim2.new(0, 120, 1, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = false,
        ZIndex = 50,
        Parent = parent
    })
    
    local button = createSquircle(Theme.Radius.Small, "Squircle", {
        Size = UDim2.new(1, 0, 1, 0),
        ImageColor3 = Theme.BackgroundSecondary,
        ZIndex = 50,
        Parent = container,
    }, true)
    createSquircle(Theme.Radius.Small, "SquircleOutline", {
        Size = UDim2.new(1, 0, 1, 0),
        ImageColor3 = Theme.Border,
        ZIndex = 0,
        Parent = button,
    }, false)
    
    local label = createInstance("TextLabel", {
        Size = UDim2.new(1, -28, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        Text = selectedOption,
        TextColor3 = Theme.TextPrimary,
        TextSize = 11,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 51,
        Parent = button
    })
    
    local arrow = createAssetGlyph(button, "chevron.png", 10, {
        Name = "Chevron",
        Position = UDim2.new(1, -14, 0.5, 0),
        ImageColor3 = Theme.TextMuted,
        ZIndex = 51,
    })
    
    local optionsFrame = createSquircle(Theme.Radius.Small, "Squircle", {
        Name = "DropdownMenu",
        Size = dockedMenuSize,
        Position = dockedMenuPos,
        ImageColor3 = Theme.BackgroundSecondary,
        Visible = false,
        ZIndex = 100,
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
        ZIndex = 101,
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

    local function dockOptionsMenu()
        optionsFrame.Parent = container
        optionsFrame.AnchorPoint = Vector2.new(0, 0)
        optionsFrame.Position = dockedMenuPos
        optionsFrame.Size = dockedMenuSize
        bumpMenuZ(100)
    end

    local function floatOptionsMenu()
        local screenGui = findScreenGui(container)
        if not screenGui then
            dockOptionsMenu()
            return
        end
        local absPos = container.AbsolutePosition
        local absSize = container.AbsoluteSize
        optionsFrame.AnchorPoint = Vector2.new(0, 0)
        optionsFrame.Position = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 4)
        optionsFrame.Size = UDim2.new(0, math.max(absSize.X, 120), 0, menuHeight)
        optionsFrame.Parent = screenGui
        bumpMenuZ(300)
    end

    local function setOpen(open)
        isOpen = open
        if isOpen then
            floatOptionsMenu()
        else
            dockOptionsMenu()
        end
        optionsFrame.Visible = isOpen
        tween(arrow, {Rotation = isOpen and 180 or 0}, 0.2)
    end

    local function syncOptionColors()
        for _, child in ipairs(optionsContent:GetChildren()) do
            if child:IsA("TextButton") then
                local optLabel = child:FindFirstChild("Label")
                if optLabel then
                    optLabel.TextColor3 = optLabel.Text == selectedOption and Theme.Primary or Theme.TextPrimary
                end
            end
        end
    end
    
    for i, option in ipairs(options) do
        local optBtn = createInstance("TextButton", {
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundColor3 = Theme.BackgroundTertiary,
            BackgroundTransparency = 1,
            Text = "",
            LayoutOrder = i,
            ZIndex = 102,
            Parent = optionsContent
        })
        createCorner(optBtn, Theme.CornerRadiusSmall)
        createInstance("TextLabel", {
            Name = "Label",
            Size = UDim2.new(1, -12, 1, 0),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = option,
            TextColor3 = option == selectedOption and Theme.Primary or Theme.TextPrimary,
            TextSize = 11,
            Font = Theme.FontFamily,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 103,
            Parent = getG2Content(optBtn),
        })
        
        optBtn.MouseEnter:Connect(function()
            tween(optBtn, {BackgroundTransparency = 0}, 0.1)
        end)
        
        optBtn.MouseLeave:Connect(function()
            tween(optBtn, {BackgroundTransparency = 1}, 0.1)
        end)
        
        optBtn.MouseButton1Click:Connect(function()
            selectedOption = option
            label.Text = option
            syncOptionColors()
            setOpen(false)
            if callback then callback(option) end
        end)
    end

    button.MouseButton1Click:Connect(function()
        setOpen(not isOpen)
    end)

    local function isPointInside(frame, pos)
        local absPos = frame.AbsolutePosition
        local absSize = frame.AbsoluteSize
        return pos.X >= absPos.X and pos.X <= absPos.X + absSize.X
            and pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y
    end

    local outsideClickConn = UserInputService.InputBegan:Connect(function(input)
        if not isOpen or not container.Parent then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local pos = input.Position
        if isPointInside(button, pos) or isPointInside(optionsFrame, pos) then
            return
        end
        setOpen(false)
    end)

    container.Destroying:Connect(function()
        if outsideClickConn then
            outsideClickConn:Disconnect()
            outsideClickConn = nil
        end
        if optionsFrame.Parent and optionsFrame.Parent ~= container then
            optionsFrame:Destroy()
        end
    end)

    return container, function() return selectedOption end
end

function UIComponents.Separator(parent)
    return createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Border,
        Parent = parent
    })
end

function UIComponents.ScrollFrame(parent, autoSize)
    local scroll = createInstance("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.BorderHover,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = autoSize or Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ClipsDescendants = true,
        Parent = parent
    })
    
    return scroll
end

function UIComponents.ClippedScrollText(parent, displayText, options)
    options = options or {}
    local textColor = options.TextColor or Theme.TextPrimary
    local maxHeight = options.MaxHeight or 200
    local layoutOrder = options.LayoutOrder or 0
    local lineHeight = options.LineHeight or 12

    local lineCount = 1
    for _ in displayText:gmatch("\n") do
        lineCount = lineCount + 1
    end

    local scrollContainer = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, math.min(lineCount * lineHeight + 16, maxHeight)),
        BackgroundColor3 = Theme.Background,
        ClipsDescendants = true,
        LayoutOrder = layoutOrder,
        Parent = parent
    })
    createCorner(scrollContainer, Theme.CornerRadiusSmall)

    local contentScroll = createInstance("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.BorderHover,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.XY,
        ScrollingDirection = Enum.ScrollingDirection.XY,
        ClipsDescendants = true,
        Parent = scrollContainer
    })
    createPadding(contentScroll, 6)

    createInstance("TextLabel", {
        Size = UDim2.new(0, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundTransparency = 1,
        Text = displayText,
        TextColor3 = textColor,
        TextSize = 10,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = false,
        Parent = contentScroll
    })

    return scrollContainer
end

function UIComponents.ContextMenu(items, position, parent)
    
    local existing = parent:FindFirstChild("ContextMenu")
    if existing then existing:Destroy() end
    local existingClose = parent:FindFirstChild("ContextMenuClose")
    if existingClose then existingClose:Destroy() end
    
    
    local closeBtn = createInstance("TextButton", {
        Name = "ContextMenuClose",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 500,
        Parent = parent
    })
    
    local menu = createInstance("TextButton", {
        Name = "ContextMenu",
        Size = UDim2.new(0, 180, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.new(0, position.X, 0, position.Y),
        BackgroundColor3 = Theme.BackgroundSecondary,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 501,
        Parent = parent
    })
    createCorner(menu, Theme.CornerRadius)
    createStroke(menu, Theme.Border)
    createPadding(menu, 4)
    createListLayout(menu, 2)
    
    for i, item in ipairs(items) do
        if item.Separator then
            createInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = Theme.Border,
                LayoutOrder = i,
                ZIndex = 502,
                Parent = menu
            })
        else
            local btn = createInstance("TextButton", {
                Size = UDim2.new(1, 0, 0, 26),
                BackgroundColor3 = Theme.BackgroundTertiary,
                BackgroundTransparency = 1,
                Text = "",
                LayoutOrder = i,
                ZIndex = 502,
                Parent = menu
            })
            createCorner(btn, Theme.CornerRadiusSmall)
            
            local icon = item.Icon or ""
            local text = item.Text or ""
            
            createInstance("TextLabel", {
                Size = UDim2.new(1, -16, 1, 0),
                Position = UDim2.new(0, 8, 0, 0),
                BackgroundTransparency = 1,
                Text = icon .. (icon ~= "" and "  " or "") .. text,
                TextColor3 = item.Danger and Theme.Danger or Theme.TextPrimary,
                TextSize = 11,
                Font = Theme.FontFamily,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 503,
                Parent = btn
            })
            
            btn.MouseEnter:Connect(function()
                tween(btn, {BackgroundTransparency = 0}, 0.1)
            end)
            
            btn.MouseLeave:Connect(function()
                tween(btn, {BackgroundTransparency = 1}, 0.1)
            end)
            
            btn.MouseButton1Click:Connect(function()
                menu:Destroy()
                closeBtn:Destroy()
                if item.Callback then item.Callback() end
            end)
        end
    end
    
    closeBtn.MouseButton1Click:Connect(function()
        menu:Destroy()
        closeBtn:Destroy()
    end)
    
    return menu
end

function UIComponents.Modal(parent, title, size, content)
    
    local backdrop = createInstance("Frame", {
        Name = "ModalBackdrop",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.Shadow,
        BackgroundTransparency = 0.7,
        ZIndex = 1000,
        Parent = parent
    })
    
    local modal = createSquircle(Theme.Radius.Large, "Squircle", {
        Name = "Modal",
        Size = size or UDim2.new(0, 500, 0, 400),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ImageColor3 = Theme.Background,
        ZIndex = 1001,
        Parent = backdrop,
    }, true)
    createSquircle(Theme.Radius.Large, "SquircleOutline", {
        Size = UDim2.new(1, 0, 1, 0),
        ImageColor3 = Theme.Border,
        ZIndex = 1001,
        Parent = modal,
    }, false)
    
    local header = createSquircle(Theme.Radius.Large, "Squircle-TL-TR", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 44),
        ImageColor3 = Theme.BackgroundSecondary,
        ZIndex = 1002,
        Parent = modal,
    }, true)
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.new(0, 16, 0, 0),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.TextPrimary,
        TextSize = 14,
        Font = Theme.FontFamilyBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 1003,
        Parent = header
    })
    
    local closeBtn = createSquircle(Theme.Radius.Small, "Squircle", {
        Size = UDim2.new(0, 26, 0, 26),
        Position = UDim2.new(1, -36, 0.5, -13),
        AnchorPoint = Vector2.new(0, 0.5),
        ImageColor3 = Theme.BackgroundTertiary,
        ImageTransparency = 1,
        ZIndex = 1003,
        Parent = header,
    }, true)
    local closeGlyph = createAssetGlyph(closeBtn, "close.png", 12, {
        Name = "Glyph",
        Position = UDim2.new(0.5, 0, 0.5, 0),
        ImageColor3 = Theme.TextSecondary,
        ZIndex = 1004,
    })
    
    closeBtn.MouseEnter:Connect(function()
        tween(closeBtn, {ImageTransparency = 0}, 0.15)
        if closeGlyph then
            tween(closeGlyph, {ImageColor3 = Theme.TextPrimary}, 0.15)
        end
    end)
    
    closeBtn.MouseLeave:Connect(function()
        tween(closeBtn, {ImageTransparency = 1}, 0.15)
        if closeGlyph then
            tween(closeGlyph, {ImageColor3 = Theme.TextSecondary}, 0.15)
        end
    end)
    
    closeBtn.MouseButton1Click:Connect(function()
        backdrop:Destroy()
    end)
    
    
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = modal.Position
        end
    end)
    
    header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    local dragConnection = UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        if not modal.Parent then
            dragging = false
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement or
            input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            modal.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    
    backdrop.Destroying:Connect(function()
        dragConnection:Disconnect()
    end)
    
    
    local contentFrame = createInstance("Frame", {
        Size = UDim2.new(1, 0, 1, -44),
        Position = UDim2.new(0, 0, 0, 44),
        BackgroundTransparency = 1,
        ZIndex = 1002,
        Parent = modal
    })
    createPadding(contentFrame, 14)
    
    if content then
        content(contentFrame)
    end
    
    return backdrop, modal, contentFrame
end

function UIComponents.ChunkedTextArea(parent, initialText, readOnly, onChunkChanged)
    local CHUNK_SIZE = 90000
    
    local container = createInstance("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.BackgroundSecondary,
        Parent = parent
    })
    createCorner(container, Theme.CornerRadiusSmall)
    
    local chunks = {}
    local currentChunkIndex = 1
    local fullText = initialText or ""
    
    local function splitIntoChunks(text)
        chunks = {}
        if #text == 0 then
            chunks[1] = ""
            return
        end
        
        local pos = 1
        while pos <= #text do
            local chunkEnd = math.min(pos + CHUNK_SIZE - 1, #text)
            table.insert(chunks, text:sub(pos, chunkEnd))
            pos = chunkEnd + 1
        end
    end
    
    local function getFullText()
        return table.concat(chunks)
    end
    
    splitIntoChunks(fullText)
    
    
    local header = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = Theme.BackgroundTertiary,
        Parent = container
    })
    createCorner(header, Theme.CornerRadiusSmall)
    
    local infoLabel = createInstance("TextLabel", {
        Size = UDim2.new(0.5, 0, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        Text = string.format("Chunk 1/%d | Total: %d chars", #chunks, #fullText),
        TextColor3 = Theme.TextMuted,
        TextSize = 10,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header
    })
    
    local navContainer = createInstance("Frame", {
        Size = UDim2.new(0, 120, 1, 0),
        Position = UDim2.new(1, -125, 0, 0),
        BackgroundTransparency = 1,
        Parent = header
    })
    createListLayout(navContainer, 4, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
    
    local prevBtn = UIComponents.Button(navContainer, "<", nil, function() end)
    prevBtn.Size = UDim2.new(0, 28, 0, 20)
    prevBtn.LayoutOrder = 1
    
    local chunkLabel = createInstance("TextLabel", {
        Size = UDim2.new(0, 40, 0, 20),
        BackgroundTransparency = 1,
        Text = "1/" .. #chunks,
        TextColor3 = Theme.TextPrimary,
        TextSize = 11,
        Font = Theme.FontFamily,
        LayoutOrder = 2,
        Parent = navContainer
    })
    
    local nextBtn = UIComponents.Button(navContainer, ">", nil, function() end)
    nextBtn.Size = UDim2.new(0, 28, 0, 20)
    nextBtn.LayoutOrder = 3
    
    local textContainer = createInstance("Frame", {
        Size = UDim2.new(1, 0, 1, -32),
        Position = UDim2.new(0, 0, 0, 32),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = container
    })
    
    local scroll = createInstance("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 6,
        ScrollBarImageColor3 = Theme.BorderHover,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.XY,
        ScrollingDirection = Enum.ScrollingDirection.XY,
        ClipsDescendants = true,
        Parent = textContainer
    })
    createPadding(scroll, 8)
    
    local textElement
    if readOnly then
        textElement = createInstance("TextLabel", {
            Size = UDim2.new(0, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.XY,
            BackgroundTransparency = 1,
            Text = chunks[1] or "",
            TextColor3 = Theme.TextPrimary,
            TextSize = 11,
            Font = Theme.FontFamilyMono,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = false,
            Parent = scroll
        })
    else
        textElement = createInstance("TextBox", {
            Size = UDim2.new(0, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.XY,
            BackgroundTransparency = 1,
            Text = chunks[1] or "",
            TextColor3 = Theme.TextPrimary,
            TextSize = 11,
            Font = Theme.FontFamilyMono,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = false,
            MultiLine = true,
            ClearTextOnFocus = false,
            Parent = scroll
        })
        
        textElement.FocusLost:Connect(function()
            chunks[currentChunkIndex] = textElement.Text
            if onChunkChanged then
                onChunkChanged(getFullText())
            end
        end)
    end
    
    local function updateDisplay()
        textElement.Text = chunks[currentChunkIndex] or ""
        chunkLabel.Text = currentChunkIndex .. "/" .. #chunks
        infoLabel.Text = string.format("Chunk %d/%d | Total: %d chars | This: %d chars", 
            currentChunkIndex, #chunks, #getFullText(), #(chunks[currentChunkIndex] or ""))
        scroll.CanvasPosition = Vector2.new(0, 0)
    end
    
    prevBtn.MouseButton1Click:Connect(function()
        if not readOnly then
            chunks[currentChunkIndex] = textElement.Text
        end
        if currentChunkIndex > 1 then
            currentChunkIndex = currentChunkIndex - 1
            updateDisplay()
        end
    end)
    
    nextBtn.MouseButton1Click:Connect(function()
        if not readOnly then
            chunks[currentChunkIndex] = textElement.Text
        end
        if currentChunkIndex < #chunks then
            currentChunkIndex = currentChunkIndex + 1
            updateDisplay()
        end
    end)
    
    return {
        Container = container,
        
        GetFullText = function()
            if not readOnly then
                chunks[currentChunkIndex] = textElement.Text
            end
            return getFullText()
        end,
        
        SetText = function(text)
            fullText = text or ""
            splitIntoChunks(fullText)
            currentChunkIndex = 1
            updateDisplay()
        end,
        
        GetChunkCount = function()
            return #chunks
        end,
    }
end

function UIComponents.TextArea(parent, initialText, placeholder)
    local container = createInstance("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.Background,
        ClipsDescendants = true,
        Parent = parent
    })
    createCorner(container, Theme.CornerRadiusSmall)
    
    local scroll = createInstance("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.BorderHover,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ClipsDescendants = true,
        Parent = container
    })
    createPadding(scroll, 8)
    
    local inputBox = createInstance("TextBox", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = initialText or "",
        PlaceholderText = placeholder or "",
        TextColor3 = Theme.TextPrimary,
        TextSize = 11,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        MultiLine = true,
        ClearTextOnFocus = false,
        Parent = scroll
    })
    
    return container, inputBox
end

function UIComponents.CodeBlock(parent, code, language)
    local container = createInstance("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.Background,
        ClipsDescendants = true,
        Parent = parent
    })
    createCorner(container, Theme.CornerRadiusSmall)
    
    
    local header = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = Theme.BackgroundSecondary,
        Parent = container
    })
    createCorner(header, Theme.CornerRadiusSmall)
    
    createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 8),
        Position = UDim2.new(0, 0, 1, -8),
        BackgroundColor3 = Theme.BackgroundSecondary,
        BorderSizePixel = 0,
        Parent = header
    })
    
    createInstance("TextLabel", {
        Size = UDim2.new(0.5, 0, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = language or "lua",
        TextColor3 = Theme.TextMuted,
        TextSize = 10,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header
    })
    
    local copyBtn = UIComponents.Button(header, "Copy", "ghost", function()
        copyToClipboard(code)
    end)
    copyBtn.Size = UDim2.new(0, 50, 0, 20)
    copyBtn.Position = UDim2.new(1, -55, 0.5, -10)
    
    
    local scroll = createInstance("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, -26),
        Position = UDim2.new(0, 0, 0, 26),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.BorderHover,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.XY,
        ClipsDescendants = true,
        Parent = container
    })
    createPadding(scroll, 10)
    
    local codeLabel = createInstance("TextLabel", {
        Size = UDim2.new(0, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundTransparency = 1,
        Text = code,
        TextColor3 = Theme.TextPrimary,
        TextSize = 11,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        RichText = true,
        Parent = scroll
    })
    
    return container, codeLabel
end

function UIComponents.PropertyRow(parent, label, value, order)
    local row = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        LayoutOrder = order or 0,
        Parent = parent
    })
    
    createInstance("TextLabel", {
        Size = UDim2.new(0, 110, 1, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        Font = Theme.FontFamily,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row
    })
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, -115, 1, 0),
        Position = UDim2.new(0, 115, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(value),
        TextColor3 = Theme.TextPrimary,
        TextSize = 11,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row
    })
    
    return row
end

function UIComponents.Notification(parent, message, type, duration)
    type = type or "info"
    duration = duration or 3
    
    local colors = {
        info = Theme.Primary,
        success = Theme.Success,
        warning = Theme.Warning,
        error = Theme.Danger,
    }
    
    local color = colors[type] or Theme.Primary
    local msg = tostring(message or "")
    local textHeight = 16
    if TextService then
        local ok, bounds = pcall(function()
            return TextService:GetTextSize(msg, 12, Theme.FontFamily, Vector2.new(260, 1000))
        end)
        if ok and bounds then
            textHeight = math.max(16, math.ceil(bounds.Y))
        end
    else
        textHeight = math.max(16, math.ceil(#msg / 36) * 16)
    end
    local notifHeight = textHeight + 20

    local notif = createSquircle(Theme.Radius.Medium, "Squircle", {
        Size = UDim2.new(0, 280, 0, notifHeight),
        Position = UDim2.new(1, -300, 1, 0),
        ImageColor3 = Theme.BackgroundSecondary,
        ZIndex = 500,
        Parent = parent,
    }, false)
    createSquircle(Theme.Radius.Medium, "SquircleOutline", {
        Size = UDim2.new(1, 0, 1, 0),
        ImageColor3 = color,
        ZIndex = 0,
        Parent = notif,
    }, false)
    
    createInstance("TextLabel", {
        Size = UDim2.new(1, -20, 1, -12),
        Position = UDim2.new(0, 10, 0, 6),
        BackgroundTransparency = 1,
        Text = msg,
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Theme.FontFamily,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 501,
        Parent = notif
    })
    
    
    tween(notif, {Position = UDim2.new(1, -300, 1, -(notifHeight + 16))}, 0.3)
    
    
    task.delay(duration, function()
        if not notif.Parent then
            return
        end
        tween(notif, {Position = UDim2.new(1, 0, 1, -(notifHeight + 16))}, 0.3)
        task.delay(0.3, function()
            if notif.Parent then
                notif:Destroy()
            end
        end)
    end)
    
    return notif
end

function UIComponents.ClickableUrl(parent, url, layoutOrder)
    local urlBtn = createInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = url,
        TextColor3 = Theme.Primary,
        TextSize = 10,
        Font = Theme.FontFamilyMono,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        LayoutOrder = layoutOrder or 0,
        Parent = parent
    })
    
    
    urlBtn.MouseEnter:Connect(function()
        urlBtn.TextColor3 = Theme.Cyan
    end)
    
    urlBtn.MouseLeave:Connect(function()
        urlBtn.TextColor3 = Theme.Primary
    end)
    
    
    urlBtn.MouseButton1Click:Connect(function()
        copyToClipboard(url)
        UIComponents.Notification(parent:FindFirstAncestorOfClass("ScreenGui"), "URL copied to clipboard", "success")
    end)
    
    return urlBtn
end
