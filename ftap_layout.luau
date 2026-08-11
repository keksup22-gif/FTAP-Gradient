--[[
    ================================================================
    Gradient Hub - Layout & Style Engine
    Converts the shared Fluent window to a HORIZONTAL top tab bar
    (Fluid-style) and applies a premium glass-gradient theme:
      * 8 tab pills laid out in one row on top of the window
      * custom gradient accent colors, strokes, rounded glass panels
      * animated accent underline under the active tab
      * clean spacing + re-positioned page header / content area
    Runs from main.luau right after the window is created.
    File: ftap_layout.luau
    ================================================================
--]]

local RunService = game:GetService("RunService")

local Layout = {}

local state = {
    window = nil,
    bar = nil,
    underline = nil,
    selected = nil,
    selectedIndex = 1,
    tabW = 102,
    tabH = 32,
    barH = 38,
}

local function getTabButtons(holder)
    local out = {}
    for _, child in ipairs(holder:GetChildren()) do
        if child:IsA("TextButton") then
            table.insert(out, child)
        end
    end
    return out
end

local function applySelectedStroke()
    local w = state.window
    if not w then return end
    for _, btn in ipairs(getTabButtons(w.TabHolder)) do
        local stroke = btn:FindFirstChild("GradientTabStroke")
        if stroke then
            stroke.Transparency = if btn == state.selected then 0.25 else 1
        end
    end
end

local function positionUnderline()
    local w, bar, underline = state.window, state.bar, state.underline
    if not underline then return end
    local btn = state.selected
    if not btn or not btn.Parent then
        underline.Visible = false
        return
    end
    local ok, x, wid = pcall(function()
        local ax = btn.AbsolutePosition
        local bx = bar.AbsolutePosition
        return ax.X - bx.X, btn.AbsoluteSize.X
    end)
    if not ok then
        underline.Visible = false
        return
    end
    underline.Size = UDim2.fromOffset(wid, 4)
    underline.Position = UDim2.new(0, x, 0, state.barH - 3)
    underline.Visible = wid > 4
end

local cornerRadius = 8

local function styleTab(btn)
    btn.Size = UDim2.fromOffset(state.tabW, state.tabH)
    btn.ZIndex = 3
    btn.AutoButtonColor = false
    for _, child in ipairs(btn:GetChildren()) do
        if child:IsA("UICorner") then
            child.CornerRadius = UDim.new(0, cornerRadius)
        end
    end
    if not btn:FindFirstChild("GradientTabStroke") then
        local stroke = Instance.new("UIStroke")
        stroke.Name = "GradientTabStroke"
        stroke.Thickness = 1.2
        stroke.Transparency = 1
        stroke.Color = Color3.fromRGB(150, 110, 255)
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = btn
    end
    btn.MouseButton1Click:Connect(function()
        state.selected = btn
        applySelectedStroke()
        positionUnderline()
    end)
end

local function makeGradientImpl(gradient, keys)
    local pts = {}
    for i, key in ipairs(keys) do
        table.insert(pts, ColorSequenceKeypoint.new(key[1], key[2]))
    end
    gradient.Color = ColorSequence.new(pts)
end

local function instanceNewCorner(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = instance
    return corner
end

-- ================================================================
-- Layout.patch(window) - core conversion + premium styling
-- ================================================================

function Layout.patch(window)
    return pcall(function()
        local w = window
        local holder = w.TabHolder
        assert(holder, "[Layout] Missing TabHolder")
        local bar = holder.Parent
        assert(bar, "[Layout] Missing tab bar")

        state.window = w
        state.bar = bar

        -- 1) Tab bar moved to the TOP of the window
        bar.Size = UDim2.new(1, -24, 0, state.barH)
        bar.Position = UDim2.new(0, 12, 0, 52)
        bar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        bar.BackgroundTransparency = 0.88
        bar.BorderSizePixel = 0

        -- glass bar: rounded corners + gradient sheen + soft stroke
        local barCorner = Instance.new("UICorner")
        barCorner.CornerRadius = UDim.new(0, 12)
        barCorner.Name = "GradientBarCorner"
        barCorner.Parent = bar

        local barGrad = Instance.new("UIGradient")
        barGrad.Name = "GradientBarGradient"
        barGrad.Rotation = 90
        barGrad.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.55),
            NumberSequenceKeypoint.new(1, 0.88),
        })
        barGrad.Parent = bar

        local barStroke = Instance.new("UIStroke")
        barStroke.Name = "GradientBarStroke"
        barStroke.Thickness = 1
        barStroke.Transparency = 0.9
        barStroke.Color = Color3.fromRGB(255, 255, 255)
        barStroke.Parent = bar

        -- 2) Horizontal scrolling tab holder (proper Fluent properties)
        holder.ScrollingDirection = Enum.ScrollingDirection.X
        holder.ScrollBarImageTransparency = 1
        holder.BorderSizePixel = 0

        local lay = holder:FindFirstChildOfClass("UIListLayout")
        if lay then
            lay.FillDirection = Enum.FillDirection.Horizontal
            lay.HorizontalAlignment = Enum.HorizontalAlignment.Left
            lay.VerticalAlignment = Enum.VerticalAlignment.Center
            lay.Padding = UDim.new(4, 0)
            lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                holder.CanvasSize = UDim2.new(0, lay.AbsoluteContentSize.X + 4, 0, 0)
            end)
            holder.CanvasSize = UDim2.new(0, lay.AbsoluteContentSize.X + 4, 0, 0)
        end

        -- 3) Accent underline (bottom of active tab)
        local underline
        for _, child in ipairs(bar:GetChildren()) do
            if child:IsA("Frame") then
                underline = child
                break
            end
        end
        if not underline then
            underline = Instance.new("Frame")
            underline.Name = "GradientUnderline"
            underline.BackgroundColor3 = Color3.fromRGB(255, 170, 60)
            underline.Parent = bar
        end
        underline.Name = "GradientUnderline"
        underline.AnchorPoint = Vector2.new(0, 1)
        underline.ZIndex = 4
        underline.BorderSizePixel = 0
        underline.Size = UDim2.fromOffset(0, 4)
        underline.Position = UDim2.new(0, 0, 0, state.barH - 3)
        underline.Visible = false
        local existingCorner = underline:FindFirstChildOfClass("UICorner")
        if existingCorner then
            existingCorner.CornerRadius = UDim.new(0, 4)
        else
            instanceNewCorner(underline, 4)
        end
        local underlineGrad = Instance.new("UIGradient")
        underlineGrad.Name = "GradientUnderlineGradient"
        makeGradientImpl(underlineGrad, {
            { 0, Color3.fromRGB(124, 92, 255) },
            { 0.5, Color3.fromRGB(140, 92, 255) },
            { 1, Color3.fromRGB(90, 190, 255) },
        })
        underlineGrad.Parent = underline
        state.underline = underline

        -- 4) Override Fluent's animated motors so they respect the
        --    horizontal layout (our onStep callbacks run last).
        w.SelectorPosMotor:onStep(function()
            positionUnderline()
        end)
        w.SelectorSizeMotor:onStep(function()
            positionUnderline()
        end)
        w.ContainerPosMotor:onStep(function(K)
            w.ContainerHolder.Position = UDim2.fromOffset(12, K + 34)
        end)
        w.TabHolder:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
            positionUnderline()
        end)

        -- 5) Restyle already-existing tabs + hook future ones
        for _, btn in ipairs(getTabButtons(holder)) do
            styleTab(btn)
        end
        holder.ChildAdded:Connect(function(child)
            if child:IsA("TextButton") then
                styleTab(child)
            end
        end)

        -- 6) Content area below the tab bar + header
        w.ContainerHolder.Size = UDim2.new(1, -24, 1, -156)
        w.ContainerHolder.Position = UDim2.fromOffset(12, 128)

        w.TabDisplay.Position = UDim2.fromOffset(14, 98)
        w.TabDisplay.Size = UDim2.new(1, -28, 0, 22)
        w.TabDisplay.TextSize = 22
        w.TabDisplay.TextTransparency = 0.12
        w.TabDisplay.TextXAlignment = Enum.TextXAlignment.Left
        w.TabDisplay.ZIndex = 2

        -- 7) Premium window surface (glass gradient panel)
        local bg = Instance.new("Frame")
        bg.Name = "GradientWindowSurface"
        bg.AnchorPoint = Vector2.new(0.5, 0.5)
        bg.Position = UDim2.fromScale(0.5, 0.5)
        bg.Size = UDim2.fromScale(1, 1)
        bg.BackgroundColor3 = Color3.fromRGB(26, 28, 46)
        bg.BackgroundTransparency = 0.03
        bg.BorderSizePixel = 0
        bg.ZIndex = -5
        instanceNewCorner(bg, 16)
        local bgGrad = Instance.new("UIGradient")
        bgGrad.Name = "GradientSurfaceGradient"
        bgGrad.Rotation = 68
        makeGradientImpl(bgGrad, {
            { 0, Color3.fromRGB(34, 32, 62) },
            { 0.45, Color3.fromRGB(24, 24, 44) },
            { 1, Color3.fromRGB(14, 14, 26) },
        })
        bgGrad.Parent = bg
        local bgStroke = Instance.new("UIStroke")
        bgStroke.Name = "GradientSurfaceStroke"
        bgStroke.Thickness = 1.3
        bgStroke.Transparency = 0.55
        bgStroke.Color = Color3.fromRGB(150, 100, 255)
        bgStroke.Parent = bg
        bg.Parent = w.Root

        -- 8) Premium top accent strip (gradient bar across the window top)
        local strip = Instance.new("Frame")
        strip.Name = "GradientTopStrip"
        strip.AnchorPoint = Vector2.new(0.5, 0)
        strip.Position = UDim2.fromScale(0.5, 0)
        strip.Size = UDim2.new(1, 0, 0, 3)
        strip.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        strip.BackgroundTransparency = 1
        strip.BorderSizePixel = 0
        strip.ZIndex = 10
        local stripGrad = Instance.new("UIGradient")
        stripGrad.Rotation = 90
        makeGradientImpl(stripGrad, {
            { 0, Color3.fromRGB(124, 92, 255) },
            { 0.5, Color3.fromRGB(140, 120, 255) },
            { 1, Color3.fromRGB(90, 190, 255) },
        })
        stripGrad.Parent = strip
        strip.Parent = w.Root

        w.Root.ClipsDescendants = true

        _G.GradientLayout = Layout
        return true
    end)
end

-- ================================================================
-- Layout.selectScreen(index) - programmatic tab select (first tab)
-- ================================================================

function Layout.selectScreen(index)
    if not state.window then return end
    local buttons = getTabButtons(state.window.TabHolder)
    local btn = buttons[index or state.selectedIndex]
    if not btn then return end
    state.selected = btn
    state.selectedIndex = index or 1
    applySelectedStroke()
    positionUnderline()
    pcall(function()
        btn:Fire("MouseButton1Click")
    end)
    -- Fallback: make sure the target container is visible even if the
    -- synthetic click above did not propagate on the current executor.
    task.delay(0.1, function()
        pcall(function()
            local containers = {}
            for _, child in ipairs(state.window.ContainerHolder:GetChildren()) do
                if child:IsA("ScrollingFrame") then
                    table.insert(containers, child)
                end
            end
            for i, container in ipairs(containers) do
                container.Visible = (i == state.selectedIndex)
            end
        end)
    end)
end

-- Auto-patch the shared window as soon as this module loads.
if _G.GradientWindow then
    Layout.patch(_G.GradientWindow)
end

return Layout