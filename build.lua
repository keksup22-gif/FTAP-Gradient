-- ================================================================
-- GRADIENT HUB | FTAP - MONOLITHIC BUILD (generated, do not edit)
-- Generated: 2026-08-20 20:34:05
-- Source split: part1 (main.luau) + 11 inlined modules + tail
-- ================================================================

--[[
    ================================================================
    Gradient Hub - Main Loader (single window architecture)
    One Fluent window is created here and shared by all modules
    via _G.GradientWindow / _G.GradientFluent.

    The ENTIRE initialization (Fluent load -> window -> tabs ->
    module loading) runs inside a single outer pcall. There is
    NO unprotected nil-call anywhere at the top level, so even a
    fully-broken environment prints a readable diagnostic instead
    of crashing with "attempt to call a nil value".
    File: main.luau
    ================================================================
--]]

local GradientInitStatus, GradientInitErr = pcall(function()

    print("[Gradient Hub] НОВАЯ ВЕРСИЯ С ПОЛНОЙ ЗАЩИТОЙ ИНИЦИАЛИЗАЦИИ! " .. os.time())
    print("[Gradient] Loader started!")

    -- Prior-run cleanup: purge old state + script-created objects before reload
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    local Lighting = game:GetService("Lighting")

    -- 1. Disconnect prior registered connections (saved in _G by each module)
    if type(_G.GradientConnections) == "table" then
        for _, conn in ipairs(_G.GradientConnections) do
            pcall(function()
                if conn and conn.Connected then conn:Disconnect() end
            end)
        end
    end
    _G.GradientConnections = {}

    -- 2. Remove previously created script objects (Highlights, Decals, platforms, auras)
    pcall(function()
        for _, inst in ipairs(Workspace:GetDescendants()) do
            local n = inst.Name or ""
            if string.find(n, "PCLD_Highlight") or string.find(n, "FTAP_ObjectESP")
               or string.find(n, "FTAP_Label_") or string.find(n, "FTAP_WaterPlatform")
               or string.find(n, "PlayerChams") or inst:GetAttribute("FTAP_Script") then
                inst:Destroy()
            end
        end
    end)

    -- 3. Clean post-processing effects from older shader presets
    pcall(function()
        for _, child in ipairs(Lighting:GetChildren()) do
            local cname = child.Name or ""
            if string.find(cname, "FTAP_Shader") or string.find(cname, "FTAP_CustomSky") then
                child:Destroy()
            end
        end
    end)

    -- ================================================================
    -- 1) Load Fluent UI
    --    Guarded: a rate-limit / network hiccup can make HttpGet return
    --    an HTML error page, loadstring then returns nil, and calling
    --    nil() would throw. Here every step is type-checked instead.
    -- ================================================================
    local Fluent = nil
    if _G.GradientFluent and type(_G.GradientFluent.CreateWindow) == "function" then
        Fluent = _G.GradientFluent
        print("[Gradient] Reusing existing Fluent (rerun/standalone).")
    else
        local sources = {
            "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua",
            "https://raw.githubusercontent.com/disco0001/Fluent/main/main.lua",
        }
        for _, url in ipairs(sources) do
            local ok, lib = pcall(function()
                local src = game:HttpGet(url)
                if type(src) == "string" and #src > 100 then
                    local fn = loadstring(src)
                    if type(fn) == "function" then
                        return fn()
                    end
                end
            end)
            if ok and type(lib) == "table" and type(lib.CreateWindow) == "function" then
                Fluent = lib
                break
            end
            print("[Gradient] Fluent source failed: " .. tostring(url))
        end
    end
    if type(Fluent) ~= "table" or type(Fluent.CreateWindow) ~= "function" then
        print("[Gradient] CRITICAL: Fluent is EMPTY (nil) - network blocked or source changed.")
        return
    end
    _G.GradientFluent = Fluent

    -- ================================================================
    -- 2) Create the single shared window (guarded CreateWindow)
    -- ================================================================
    local Window = nil
    if _G.GradientWindow and type(_G.GradientWindow.AddTab) == "function" then
        Window = _G.GradientWindow
        print("[Gradient] Reusing existing window (rerun/standalone).")
    else
        local okW, win = pcall(Fluent.CreateWindow, Fluent, {
            Title = "Gradient Hub | FTAP",
            SubTitle = "by keksup22",
            Size = UDim2.fromOffset(640, 540),
            TabWidth = 160,
            Acrylic = false,
            Theme = "Dark",
            MinimizeKey = Enum.KeyCode.LeftControl
        })
        Window = (okW and type(win) == "table" and type(win.AddTab) == "function") and win or nil
        if not Window then
            print("[Gradient] CRITICAL: Window is EMPTY (nil) - CreateWindow returned nil/errored.")
            return
        end
    end
    _G.GradientWindow = Window
    _G.GradientWindows = _G.GradientWindows or {}
    table.insert(_G.GradientWindows, Window)

    -- ================================================================
    -- 3) Build the shared 8-tab layout. Each tab is added in its own
    --    pcall so one broken icon name / tab error NEVER aborts the
    --    creation of the remaining tabs. If the attempt with Icon
    --    fails, we retry without Icon as a safe fallback.
    -- ================================================================
    local tabSpecs = {
        { key = "Protections", title = "Protections", icon = "shield" },
        { key = "Movement", title = "Local Player & Protection", icon = "person-standing" },
        { key = "Combat", title = "Combat & Grabs", icon = "swords" },
        { key = "Visuals", title = "Visuals", icon = "eye" },
        { key = "Server", title = "Server & Auras", icon = "server" },
        { key = "Misc", title = "Misc & Settings", icon = "wrench" },
        { key = "Settings", title = "Settings", icon = "settings" },
        { key = "Info", title = "Info", icon = "info" }
    }
    local Tabs = {}
    local tabCount = 0

    for _, spec in ipairs(tabSpecs) do
        print("[Gradient] Creating tab:", spec.title, "key:", spec.key, "icon:", tostring(spec.icon))
        local tab = nil
        local safeIcon = spec.icon
        if type(Fluent.GetIcon) == "function" then
            local okIcon, asset = pcall(Fluent.GetIcon, Fluent, spec.icon)
            if not (okIcon and type(asset) == "string") then
                warn("[Tab Error]: GetIcon('" .. tostring(spec.icon) .. "') failed for tab '" .. spec.title .. "' - creating without icon.")
                safeIcon = nil
            end
        end

        local ok1, t1 = pcall(function()
            return Window:AddTab({ Title = spec.title, Icon = safeIcon })
        end)
        if ok1 and type(t1) == "table" then
            tab = t1
            print("[Gradient] SUCCESS: Tab '" .. spec.title .. "' created.")
        else
            warn("[Tab Error]: AddTab #1 failed for '" .. spec.title .. "': " .. tostring(t1))
            local ok2, t2 = pcall(function()
                return Window:AddTab({ Title = spec.title })
            end)
            if ok2 and type(t2) == "table" then
                tab = t2
                print("[Gradient] SUCCESS (fallback): Tab '" .. spec.title .. "' added without icon.")
            else
                warn("[Tab Error]: AddTab #2 (fallback) failed for '" .. spec.title .. "': " .. tostring(t2))
            end
        end

        if tab then
            Tabs[spec.key] = tab
            tabCount = tabCount + 1
        else
            print("[Gradient] CRITICAL: Tab '" .. spec.title .. "' could not be created at all!")
        end
        task.wait(0.05)
    end

    -- ================================================================
    -- Verification + retry pass: if any tab is still missing, re-scan
    -- the TabHolder and retry creation of every missing spec.
    -- ================================================================
    local function countTabButtons(holder)
        local n = 0
        for _, child in ipairs(holder:GetChildren()) do
            if child:IsA("TextButton") then
                n = n + 1
            end
        end
        return n
    end

    local holderRef = Window.TabHolder
    local existingButtons = (holderRef and countTabButtons(holderRef)) or 0
    print("[Gradient] TabHolder buttons after first pass: " .. tostring(existingButtons) .. " / " .. tostring(#tabSpecs))

    for _, spec in ipairs(tabSpecs) do
        if not Tabs[spec.key] and holderRef then
            task.wait(0.1)
            local okR, tR = pcall(Window.AddTab, Window, { Title = spec.title })
            if okR and type(tR) == "table" then
                Tabs[spec.key] = tR
                tabCount = tabCount + 1
                print("[Gradient] Retry pass: tab '" .. spec.title .. "' created.")
            else
                warn("[Tab Error]: Retry pass failed for '" .. spec.title .. "': " .. tostring(tR))
            end
        end
    end

    _G.GradientTabs = Tabs
    print("[Gradient] Total tabs successfully added: " .. tostring(tabCount) .. " / " .. tostring(#tabSpecs))

    if not Tabs.Protections then
        print("[Gradient] CRITICAL: 'Protections' tab creation failed. Aborting launch.")
        return
    end

    -- ================================================================
    -- 4) Load all modules (each download/load is individually guarded)
    -- ================================================================
    local BaseUrl = "https://raw.githubusercontent.com/keksup22-gif/FTAP-Gradient/main/"


-- BEG MODULE: ftap_layout.luau
pcall(function()
--[[
    ================================================================
    Gradient Hub - Layout & Style Engine (VERTICAL SIDE BAR)
    Uses Fluent's native vertical tab sidebar (TabWidth = 160) and
    only applies premium glass-gradient styling on top of it:
      * left sidebar with rounded glass panel + gradient sheen
      * accent underline bar on the left edge of the active tab
      * gradient window surface + top accent strip
    Fluent's own motors handle the sidebar geometry, so this module
    never fights them (no horizontal conversions, no overrides).
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
    tabW = 160,
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

-- Vertical accent bar on the LEFT edge of the active tab
local function positionUnderline()
    local w, bar, underline = state.window, state.bar, state.underline
    if not underline then return end
    local btn = state.selected
    if not btn or not btn.Parent then
        underline.Visible = false
        return
    end
    local ok, y, h = pcall(function()
        local ay = btn.AbsolutePosition
        local by = bar.AbsolutePosition
        return ay.Y - by.Y, btn.AbsoluteSize.Y
    end)
    if not ok then
        underline.Visible = false
        return
    end
    underline.Size = UDim2.fromOffset(3, h - 8)
    underline.Position = UDim2.new(0, 2, 0, y + 4)
    underline.Visible = true
end

local cornerRadius = 8

local function styleTab(btn)
    btn.Visible = true
    btn.Size = UDim2.new(1, 0, 0, 34)
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
-- Layout.patch(window) - premium styling over Fluent's native
-- vertical sidebar. Geometry stays 100% Fluent-managed.
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

        -- 1) Sidebar glass panel (Fluent keeps its own size/position:
        --    UDim2.new(0, TabWidth, 1, -66) at (12, 54) - untouched)
        bar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        bar.BackgroundTransparency = 0.88
        bar.BorderSizePixel = 0

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

        -- 2) Vertical tab list (Fluent default). We only keep the
        --    scrollbars hidden and sync the canvas height safely.
        holder.ScrollingDirection = Enum.ScrollingDirection.Y
        holder.ScrollBarImageTransparency = 1
        holder.BorderSizePixel = 0

        local lay = holder:FindFirstChildOfClass("UIListLayout")
        if lay then
            lay.FillDirection = Enum.FillDirection.Vertical
            lay.HorizontalAlignment = Enum.HorizontalAlignment.Left
            lay.VerticalAlignment = Enum.VerticalAlignment.Top
            -- NOTE: UDim.new(0, 4) = 4 PIXELS padding. The old value
            -- UDim.new(4, 0) was SCALE 4 = 4x the container height
            -- (~1900px gaps), which pushed every tab after the first
            -- far below the visible sidebar area.
            lay.Padding = UDim.new(0, 4)

            -- Automatic canvas: let the engine size the scroll area to
            -- fit all 8 tab buttons (2023+ engines / supported executors).
            local autoOk = pcall(function()
                holder.AutomaticCanvasSize = Enum.AutomaticSize.Y
            end)
            if not autoOk then
                -- Fallback for older executors: manual canvas sync.
                local syncingCanvas = false
                lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    if syncingCanvas then return end
                    syncingCanvas = true
                    task.defer(function()
                        pcall(function()
                            if lay and holder then
                                local ay = lay.AbsoluteContentSize and lay.AbsoluteContentSize.Y or 0
                                holder.CanvasSize = UDim2.new(0, 0, 0, ay + 4)
                            end
                        end)
                        syncingCanvas = false
                    end)
                end)
                local ay0 = lay.AbsoluteContentSize and lay.AbsoluteContentSize.Y or 0
                holder.CanvasSize = UDim2.new(0, 0, 0, ay0 + 4)
            end
        end

        -- 3) Accent underline: dedicated frame on the left edge of the
        --    active tab. NOT Fluent's selector (D) - no motor conflicts.
        local underline = bar:FindFirstChild("GradientUnderline")
        if not underline then
            underline = Instance.new("Frame")
            underline.Name = "GradientUnderline"
            underline.BackgroundColor3 = Color3.fromRGB(255, 170, 60)
            underline.Parent = bar
        end
        underline.Name = "GradientUnderline"
        underline.AnchorPoint = Vector2.new(0, 0.5)
        underline.ZIndex = 4
        underline.BorderSizePixel = 0
        underline.Size = UDim2.fromOffset(3, 0)
        underline.Position = UDim2.new(0, 2, 0, 0)
        underline.Visible = false
        local existingCorner = underline:FindFirstChildOfClass("UICorner")
        if existingCorner then
            existingCorner.CornerRadius = UDim.new(1, 0)
        else
            instanceNewCorner(underline, 2)
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

        -- 4) Fluent natively adapts the content area to the sidebar:
        --    ContainerHolder.Size = (1, -TabWidth-32, 1, -102) at
        --    (TabWidth+26, 90) and TabDisplay at (TabWidth+26, 56).
        --    No overrides needed - we only refresh the underline when
        --    the tab list scrolls.
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

        -- 5b) Layout watchdog: re-assert vertical layout, sane padding,
        --     canvas and visible/full-size buttons every 0.5s.
        task.spawn(function()
            while task.wait(0.5) do
                pcall(function()
                    local lay2 = holder:FindFirstChildOfClass("UIListLayout")
                    if lay2 then
                        lay2.FillDirection = Enum.FillDirection.Vertical
                        lay2.HorizontalAlignment = Enum.HorizontalAlignment.Left
                        lay2.VerticalAlignment = Enum.VerticalAlignment.Top
                        lay2.Padding = UDim.new(0, 4)
                    end
                    holder.ScrollingDirection = Enum.ScrollingDirection.Y
                    pcall(function()
                        holder.AutomaticCanvasSize = Enum.AutomaticSize.Y
                    end)
                    for _, btn2 in ipairs(getTabButtons(holder)) do
                        btn2.Visible = true
                        btn2.Size = UDim2.new(1, 0, 0, 34)
                        if not btn2:FindFirstChild("GradientTabStroke") then
                            styleTab(btn2)
                        end
                    end
                end)
            end
        end)

        -- 6) Premium window surface (glass gradient panel)
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

        -- 7) Premium top accent strip (gradient bar across the window top)
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
end)
print('[Gradient] OK: ftap_layout.luau')
task.wait(0.1)
-- END MODULE: ftap_layout.luau

-- BEG MODULE: ftap_uisettings.luau
pcall(function()
--[[
    ================================================================
    Gradient Hub UI Settings Module - Appearance / Theme / Config
    Target Game: Fling Things and People (FTAP)
    UI Library: Fluent UI
    File: ftap_uisettings.luau
    ================================================================
--]]

-- Services Initialization
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

-- Global Safe File IO Wrappers
local writefile = writefile or function() end
local readfile = readfile or function() return "" end
local isfile = isfile or function() return false end
local makefolder = makefolder or function() end
local isfolder = isfolder or function() return false end
local listfiles = listfiles or function() return {} end
local delfile = delfile or function() end

-- Shared global state for UI Settings (consumed by init.luau + other modules)
local UIState = {
    Window = nil,
    Tabs = {},
    References = {} -- hold Fluent control refs so manager buttons can update them
}
_G.GradientUIState = UIState

-- Folders
if not isfolder("GradientFTAP") then pcall(makefolder, "GradientFTAP") end
if not isfolder("GradientFTAP/Themes") then pcall(makefolder, "GradientFTAP/Themes") end
if not isfolder("GradientFTAP/Configs") then pcall(makefolder, "GradientFTAP/Configs") end

-- Shared window created by main.luau (one window for all modules)
local Fluent = _G.GradientFluent
local Window = _G.GradientWindow
if not Fluent or not Window then
    Fluent = (function()
        local ok, lib = pcall(function()
            return loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
        end)
        if ok and lib then return lib end
        local ok2, lib2 = pcall(function()
            return loadstring(game:HttpGet("https://raw.githubusercontent.com/disco0001/Fluent/main/main.lua"))()
        end)
        return (ok2 and lib2) or error("[Gradient] Failed to load Fluent UI library.")
    end)()
    local okW, win = pcall(Fluent.CreateWindow, Fluent, {
        Title = "Gradient Hub | FTAP",
        SubTitle = "by keksup22",
        TabWidth = 160,
        Size = UDim2.fromOffset(640, 460),
        Acrylic = true,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.LeftControl
    })
    Window = (okW and type(win) == "table" and type(win.AddTab) == "function") and win or nil
    if not Window then
        print("[Gradient] Fallback window creation failed.")
    end
    _G.GradientFluent = Fluent
    _G.GradientWindow = Window
end

if type(Fluent) ~= "table" or type(Window) ~= "table" or type(Window.AddTab) ~= "function" then
    print("[Gradient] Skip module: Fluent UI unavailable")
    return
end
UIState.Window = Window

local Tabs = {
    Appearance = _G.GradientTabs and _G.GradientTabs.Settings or Window:AddTab({ Title = "Settings", Icon = "palette" }),
    Keybinds = _G.GradientTabs and _G.GradientTabs.Settings or Window:AddTab({ Title = "Settings", Icon = "key" }),
    ThemeColors = _G.GradientTabs and _G.GradientTabs.Settings or Window:AddTab({ Title = "Settings", Icon = "droplet" }),
    ThemeManager = _G.GradientTabs and _G.GradientTabs.Settings or Window:AddTab({ Title = "Settings", Icon = "save" }),
    ConfigManager = _G.GradientTabs and _G.GradientTabs.Settings or Window:AddTab({ Title = "Settings", Icon = "folder" })
}
UIState.Tabs = Tabs


-- ================================================================
-- UI APPEARANCE CONFIG
-- ================================================================

local UISettings_Config = {
    Font = "Cartoon",
    ImageTransparency = 25,
    BackgroundTransparency = 10,
    HUDTransparency = 10,
    BackgroundID = "rbxassetid://0",
    CornerRadius = 25,
    UIScale = 1,

    Theme = {
        MainColor = Color3.fromRGB(30, 30, 46),
        SecondColor = Color3.fromRGB(56, 56, 84),
        ElementColor = Color3.fromRGB(66, 66, 104),
        TextColor = Color3.fromRGB(240, 240, 245),
        GradientStart = Color3.fromRGB(25, 25, 40),
        GradientEnd = Color3.fromRGB(56, 56, 84)
    },

    ToggleKey = "RightShift",
    LoadedConfig = "",
    AutoSave = false
}

-- Share theme with the rest of the suite
_G.GradientTheme = UISettings_Config.Theme
_G.GradientAppearance = UISettings_Config

local FontOptions = {
    ["Cartoon"] = Enum.Font.Cartoon,
    ["Gotham"] = Enum.Font.Gotham,
    ["GothamBlack"] = Enum.Font.GothamBlack,
    ["GothamSemibold"] = Enum.Font.GothamSemibold,
    ["SourceSans"] = Enum.Font.SourceSans,
    ["Roboto"] = Enum.Font.Roboto,
    ["Code"] = Enum.Font.Code,
    ["Highway"] = Enum.Font.Highway,
    ["Legacy"] = Enum.Font.Legacy
}

-- Apply global font to all open Gradient windows
local function applyGlobalFont(fontName)
    local fontEnum = FontOptions[fontName] or Enum.Font.SourceSans
    _G.GradientFont = fontEnum
    -- Propagate to every registered UI window
    for _, win in ipairs(_G.GradientWindows or {}) do
        if win and win.Element then
            pcall(function()
                local f = win.Element
                for _, desc in ipairs(f:GetDescendants()) do
                    if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                        desc.FontFace = Font.new(fontEnum.Name)
                    end
                end
            end)
        end
    end
end

-- Apply theme colors to all open Gradient windows
local function applyGlobalTheme(theme)
    _G.GradientTheme = theme
    _G.GradientWindowTheme = theme -- generic override for modules
    for _, win in ipairs(_G.GradientWindows or {}) do
        if win and win.Element then
            pcall(function()
                -- Background / accent accent propagation for Fluent
                local accent = theme.MainColor
                local bg = theme.SecondColor
                local elem = theme.ElementColor
                local f = win.Element
                for _, desc in ipairs(f:GetDescendants()) do
                    if desc:IsA("Frame") or desc:IsA("ScrollingFrame") then
                        if desc.Name == "BG" or desc.BackgroundTransparency < 1 then
                            pcall(function() desc.BackgroundColor3 = bg end)
                        end
                    end
                end
                for _, desc in ipairs(f:GetDescendants()) do
                    if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                        pcall(function() desc.TextColor3 = theme.TextColor end)
                    end
                end
            end)
        end
    end
end

-- Apply scale to all windows
local function applyGlobalScale(scale)
    _G.GradientScale = scale
    for _, win in ipairs(_G.GradientWindows or {}) do
        if win and win.Element then
            pcall(function() win.Element.Size = UDim2.fromOffset(580 * scale, 480 * scale) end)
        end
    end
end

-- Corner radius + frame transparent style base
local function refreshAppearanceStyle()
    local bgID = UISettings_Config.BackgroundID
    _G.GradientBackgroundID = bgID
    _G.GradientCornerRadius = UISettings_Config.CornerRadius
    _G.GradientTransparency = UISettings_Config.BackgroundTransparency / 100
end


-- ================================================================
-- THEME MANAGER (Save / Load / Delete)
-- ================================================================

local SavedThemes = {}

local function refreshThemeList()
    table.clear(SavedThemes)
    local files = listfiles("GradientFTAP/Themes")
    local names = {}
    for _, filePath in ipairs(files) do
        local filename = string.match(filePath, "([^/]+)%.json$")
        if filename then
            table.insert(names, filename)
            SavedThemes[filename] = filePath
        end
    end
    if #names == 0 then table.insert(names, "None") end
    return names
end

local function themeData()
    return {
        MainColor = { R = UISettings_Config.Theme.MainColor.R, G = UISettings_Config.Theme.MainColor.G, B = UISettings_Config.Theme.MainColor.B },
        SecondColor = { R = UISettings_Config.Theme.SecondColor.R, G = UISettings_Config.Theme.SecondColor.G, B = UISettings_Config.Theme.SecondColor.B },
        ElementColor = { R = UISettings_Config.Theme.ElementColor.R, G = UISettings_Config.Theme.ElementColor.G, B = UISettings_Config.Theme.ElementColor.B },
        TextColor = { R = UISettings_Config.Theme.TextColor.R, G = UISettings_Config.Theme.TextColor.G, B = UISettings_Config.Theme.TextColor.B },
        GradientStart = { R = UISettings_Config.Theme.GradientStart.R, G = UISettings_Config.Theme.GradientStart.G, B = UISettings_Config.Theme.GradientStart.B },
        GradientEnd = { R = UISettings_Config.Theme.GradientEnd.R, G = UISettings_Config.Theme.GradientEnd.G, B = UISettings_Config.Theme.GradientEnd.B },
        Font = UISettings_Config.Font
    }
end

local function loadTheme(raw)
    local data = HttpService:JSONDecode(raw)
    if not data then return false end

    UISettings_Config.Theme.MainColor = Color3.new(data.MainColor.R, data.MainColor.G, data.MainColor.B)
    UISettings_Config.Theme.SecondColor = Color3.new(data.SecondColor.R, data.SecondColor.G, data.SecondColor.B)
    UISettings_Config.Theme.ElementColor = Color3.new(data.ElementColor.R, data.ElementColor.G, data.ElementColor.B)
    UISettings_Config.Theme.TextColor = Color3.new(data.TextColor.R, data.TextColor.G, data.TextColor.B)
    UISettings_Config.Theme.GradientStart = Color3.new(data.GradientStart.R, data.GradientStart.G, data.GradientStart.B)
    UISettings_Config.Theme.GradientEnd = Color3.new(data.GradientEnd.R, data.GradientEnd.G, data.GradientEnd.B)

    _G.GradientTheme = UISettings_Config.Theme
    applyGlobalTheme(UISettings_Config.Theme)

    if data.Font and FontOptions[data.Font] then
        UISettings_Config.Font = data.Font
        FontDropdown:SetValue(UISettings_Config.Font)
        applyGlobalFont(UISettings_Config.Font)
    end
    return true
end


-- ================================================================
-- CONFIG MANAGER (Save / Load / Delete full UI config)
-- ================================================================

local SavedConfigs = {}

local function refreshConfigList()
    table.clear(SavedConfigs)
    local files = listfiles("GradientFTAP/Configs")
    local names = {}
    for _, filePath in ipairs(files) do
        local filename = string.match(filePath, "([^/]+)%.json$")
        if filename then
            table.insert(names, filename)
            SavedConfigs[filename] = filePath
        end
    end
    if #names == 0 then table.insert(names, "None") end
    return names
end

local function configData()
    return {
        Font = UISettings_Config.Font,
        ImageTransparency = UISettings_Config.ImageTransparency,
        BackgroundTransparency = UISettings_Config.BackgroundTransparency,
        HUDTransparency = UISettings_Config.HUDTransparency,
        BackgroundID = UISettings_Config.BackgroundID,
        CornerRadius = UISettings_Config.CornerRadius,
        UIScale = UISettings_Config.UIScale,
        Theme = themeData(),
        ToggleKey = UISettings_Config.ToggleKey
    }
end

local function loadConfig(raw)
    local data = HttpService:JSONDecode(raw)
    if not data then return false end

    UISettings_Config.Font = data.Font or "Cartoon"
    UISettings_Config.ImageTransparency = data.ImageTransparency or 25
    UISettings_Config.BackgroundTransparency = data.BackgroundTransparency or 10
    UISettings_Config.HUDTransparency = data.HUDTransparency or 10
    UISettings_Config.BackgroundID = data.BackgroundID or "rbxassetid://0"
    UISettings_Config.CornerRadius = data.CornerRadius or 25
    UISettings_Config.UIScale = data.UIScale or 1
    UISettings_Config.ToggleKey = data.ToggleKey or "RightShift"

    local t = data.Theme or {}
    UISettings_Config.Theme.MainColor = Color3.new(t.MainColor.R, t.MainColor.G, t.MainColor.B)
    UISettings_Config.Theme.SecondColor = Color3.new(t.SecondColor.R, t.SecondColor.G, t.SecondColor.B)
    UISettings_Config.Theme.ElementColor = Color3.new(t.ElementColor.R, t.ElementColor.G, t.ElementColor.B)
    UISettings_Config.Theme.TextColor = Color3.new(t.TextColor.R, t.TextColor.G, t.TextColor.B)
    UISettings_Config.Theme.GradientStart = Color3.new(t.GradientStart.R, t.GradientStart.G, t.GradientStart.B)
    UISettings_Config.Theme.GradientEnd = Color3.new(t.GradientEnd.R, t.GradientEnd.G, t.GradientEnd.B)

    -- Sync UI controls
    if FontDropdown then FontDropdown:SetValue(UISettings_Config.Font) end
    if ImageTransSlider then ImageTransSlider:SetValue(UISettings_Config.ImageTransparency) end
    if BackgroundTransSlider then BackgroundTransSlider:SetValue(UISettings_Config.BackgroundTransparency) end
    if HUDTransSlider then HUDTransSlider:SetValue(UISettings_Config.HUDTransparency) end
    if BackgroundIDInput then BackgroundIDInput:SetValue(UISettings_Config.BackgroundID) end
    if CornerRadiusSlider then CornerRadiusSlider:SetValue(UISettings_Config.CornerRadius) end
    if UIScaleSlider then UIScaleSlider:SetValue(UISettings_Config.UIScale) end

    refreshAppearanceStyle()
    applyGlobalFont(UISettings_Config.Font)
    applyGlobalTheme(UISettings_Config.Theme)
    applyGlobalScale(UISettings_Config.UIScale)
    return true
end


-- ================================================================
-- APPEARANCE UI
-- ================================================================

Tabs.Appearance:AddSection("Appearance")

local FontDropdown = Tabs.Appearance:AddDropdown("UIFontDropdown", {
    Title = "Font",
    Values = {"Cartoon", "Gotham", "GothamBlack", "GothamSemibold", "SourceSans", "Roboto", "Code", "Highway", "Legacy"},
    Default = "Cartoon",
    Callback = function(Value)
        UISettings_Config.Font = Value
        applyGlobalFont(Value)
    end
})

local ImageTransSlider = Tabs.Appearance:AddSlider("ImageTransparencySlider", {
    Title = "Image Transparency",
    Default = 25,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Callback = function(Value)
        UISettings_Config.ImageTransparency = Value
        _G.GradientImageTransparency = Value / 100
    end
})

local BackgroundTransSlider = Tabs.Appearance:AddSlider("BgTransparencySlider", {
    Title = "Background Transparency",
    Default = 10,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Callback = function(Value)
        UISettings_Config.BackgroundTransparency = Value
        _G.GradientTransparency = Value / 100
        for _, win in ipairs(_G.GradientWindows or {}) do
            if win and win.Element then
                pcall(function()
                    for _, desc in ipairs(win.Element:GetDescendants()) do
                        if desc:IsA("Frame") then
                            pcall(function() desc.BackgroundTransparency = Value / 100 end)
                        end
                    end
                end)
            end
        end
    end
})

local HUDTransSlider = Tabs.Appearance:AddSlider("HUDTransparencySlider", {
    Title = "HUD Transparency",
    Default = 10,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Callback = function(Value)
        UISettings_Config.HUDTransparency = Value
        _G.GradientHUDTransparency = Value / 100
    end
})

local BackgroundIDInput = Tabs.Appearance:AddInput("BackgroundIDInput", {
    Title = "Background ID",
    Default = "rbxassetid://0",
    Placeholder = "rbxassetid://0",
    Callback = function(Value)
        UISettings_Config.BackgroundID = Value
        _G.GradientBackgroundID = Value
    end
})

local CornerRadiusSlider = Tabs.Appearance:AddSlider("CornerRadiusSlider", {
    Title = "Corner Radius",
    Default = 25,
    Min = 0,
    Max = 60,
    Rounding = 0,
    Callback = function(Value)
        UISettings_Config.CornerRadius = Value
        _G.GradientCornerRadius = Value
        for _, win in ipairs(_G.GradientWindows or {}) do
            if win and win.Element then
                pcall(function()
                    for _, desc in ipairs(win.Element:GetDescendants()) do
                        if desc:IsA("UICorner") then
                            pcall(function() desc.CornerRadius = UDim.new(0, Value) end)
                        end
                    end
                end)
            end
        end
    end
})

local UIScaleSlider = Tabs.Appearance:AddSlider("UIScaleSlider", {
    Title = "UI Scale",
    Default = 1,
    Min = 0.5,
    Max = 2,
    Rounding = 2,
    Callback = function(Value)
        UISettings_Config.UIScale = Value
        applyGlobalScale(Value)
    end
})

-- Store slider refs for config load sync
UIState.References.FontDropdown = FontDropdown
UIState.References.ImageTransSlider = ImageTransSlider
UIState.References.BackgroundTransSlider = BackgroundTransSlider
UIState.References.HUDTransSlider = HUDTransSlider
UIState.References.BackgroundIDInput = BackgroundIDInput
UIState.References.CornerRadiusSlider = CornerRadiusSlider
UIState.References.UIScaleSlider = UIScaleSlider


-- ================================================================
-- KEYBINDS UI
-- ================================================================

Tabs.Keybinds:AddSection("Keybinds")

local MenuToggleKey = Tabs.Keybinds:AddKeybind("UISettingsToggleKey", {
    Title = "Toggle UI",
    Mode = "Toggle",
    Default = "RightShift",
    Callback = function()
        UIState.Window:Minimize()
    end
})


-- ================================================================
-- THEME COLORS UI
-- ================================================================

Tabs.ThemeColors:AddSection("Theme Colors")

local MainColorPicker = Tabs.ThemeColors:AddColorpicker("MainColorPicker", {
    Title = "Main Color",
    Default = UISettings_Config.Theme.MainColor,
    Callback = function(Value)
        UISettings_Config.Theme.MainColor = Value
        applyGlobalTheme(UISettings_Config.Theme)
    end
})

local SecondColorPicker = Tabs.ThemeColors:AddColorpicker("SecondColorPicker", {
    Title = "Second Color",
    Default = UISettings_Config.Theme.SecondColor,
    Callback = function(Value)
        UISettings_Config.Theme.SecondColor = Value
        applyGlobalTheme(UISettings_Config.Theme)
    end
})

local ElementColorPicker = Tabs.ThemeColors:AddColorpicker("ElementColorPicker", {
    Title = "Element Color",
    Default = UISettings_Config.Theme.ElementColor,
    Callback = function(Value)
        UISettings_Config.Theme.ElementColor = Value
        applyGlobalTheme(UISettings_Config.Theme)
    end
})

local TextColorPicker = Tabs.ThemeColors:AddColorpicker("TextColorPicker", {
    Title = "Text Color",
    Default = UISettings_Config.Theme.TextColor,
    Callback = function(Value)
        UISettings_Config.Theme.TextColor = Value
        applyGlobalTheme(UISettings_Config.Theme)
    end
})

local GradientStartPicker = Tabs.ThemeColors:AddColorpicker("GradientStartPicker", {
    Title = "Gradient Start",
    Default = UISettings_Config.Theme.GradientStart,
    Callback = function(Value)
        UISettings_Config.Theme.GradientStart = Value
        applyGlobalTheme(UISettings_Config.Theme)
    end
})

local GradientEndPicker = Tabs.ThemeColors:AddColorpicker("GradientEndPicker", {
    Title = "Gradient End",
    Default = UISettings_Config.Theme.GradientEnd,
    Callback = function(Value)
        UISettings_Config.Theme.GradientEnd = Value
        applyGlobalTheme(UISettings_Config.Theme)
    end
})


-- ================================================================
-- THEME MANAGER UI
-- ================================================================

Tabs.ThemeManager:AddSection("Theme Manager")

local ThemeNameInput = Tabs.ThemeManager:AddInput("ThemeNameInput", {
    Title = "Theme Name",
    Default = "MyTheme",
    Callback = function(Value) _G.GradientNewThemeName = Value end
})

Tabs.ThemeManager:AddButton({
    Title = "Save Theme",
    Callback = function()
        local name = _G.GradientNewThemeName or "MyTheme"
        local path = "GradientFTAP/Themes/" .. name .. ".json"
        local data = HttpService:JSONEncode(themeData())
        writefile(path, data)
        ThemeLoadDropdown:SetValues(refreshThemeList())
        Fluent:Notify({ Title = "Theme", Content = "Theme '" .. name .. "' saved!", Duration = 3 })
    end
})

local ThemeLoadDropdown = Tabs.ThemeManager:AddDropdown("ThemeLoadDropdown", {
    Title = "Load Theme",
    Values = refreshThemeList(),
    Default = "None",
    Callback = function(Value)
        if Value == "None" then return end
        local path = SavedThemes[Value]
        if path and isfile(path) then
            pcall(function()
                if loadTheme(readfile(path)) then
                    Fluent:Notify({ Title = "Theme", Content = "Theme '" .. Value .. "' loaded!", Duration = 3 })
                end
            end)
        end
    end
})

Tabs.ThemeManager:AddButton({
    Title = "Delete Selected Theme",
    Callback = function()
        local selected = ThemeLoadDropdown.Value
        if selected == "None" then
            Fluent:Notify({ Title = "Theme", Content = "No theme selected.", Duration = 2 })
            return
        end
        local path = SavedThemes[selected]
        if path and isfile(path) then
            delfile(path)
            ThemeLoadDropdown:SetValues(refreshThemeList())
            Fluent:Notify({ Title = "Theme", Content = "Theme '" .. selected .. "' deleted!", Duration = 2 })
        end
    end
})


-- ================================================================
-- CONFIG MANAGER UI
-- ================================================================

Tabs.ConfigManager:AddSection("Config Manager")

local ConfigNameInput = Tabs.ConfigManager:AddInput("ConfigNameInput", {
    Title = "Config Name",
    Default = "MyConfig",
    Callback = function(Value) _G.GradientNewConfigName = Value end
})

local function saveConfigToFile(name)
    local path = "GradientFTAP/Configs/" .. name .. ".json"
    local data = HttpService:JSONEncode(configData())
    writefile(path, data)
    if ConfigLoadDropdown then
        ConfigLoadDropdown:SetValues(refreshConfigList())
    end
end

Tabs.ConfigManager:AddButton({
    Title = "Save Config",
    Callback = function()
        local name = _G.GradientNewConfigName or "MyConfig"
        saveConfigToFile(name)
        Fluent:Notify({ Title = "Config", Content = "Config '" .. name .. "' saved!", Duration = 3 })
    end
})

local ConfigLoadDropdown = Tabs.ConfigManager:AddDropdown("ConfigLoadDropdown", {
    Title = "Load Config",
    Values = refreshConfigList(),
    Default = "None",
    Callback = function(Value)
        if Value == "None" then return end
        local path = SavedConfigs[Value]
        if path and isfile(path) then
            pcall(function()
                if loadConfig(readfile(path)) then
                    UISettings_Config.LoadedConfig = Value
                    Fluent:Notify({ Title = "Config", Content = "Config '" .. Value .. "' loaded!", Duration = 3 })
                end
            end)
        end
    end
})

Tabs.ConfigManager:AddButton({
    Title = "Delete Selected Config",
    Callback = function()
        local selected = ConfigLoadDropdown.Value
        if selected == "None" then
            Fluent:Notify({ Title = "Config", Content = "No config selected.", Duration = 2 })
            return
        end
        local path = SavedConfigs[selected]
        if path and isfile(path) then
            delfile(path)
            ConfigLoadDropdown:SetValues(refreshConfigList())
            Fluent:Notify({ Title = "Config", Content = "Config '" .. selected .. "' deleted!", Duration = 2 })
        end
    end
})

local AutoSaveToggle = Tabs.ConfigManager:AddToggle("AutoSaveToggle", { Title = "Auto Save Config", Default = false })
AutoSaveToggle:OnChanged(function(Value) UISettings_Config.AutoSave = Value end)

-- Auto-Save watcher: when enabled, persists the config to the last saved /
-- default filename whenever the appearance data actually changes (polled).
task.spawn(function()
    local lastSaved = ""
    local lastPoll = 0
    while true do
        task.wait(1)
        if UISettings_Config.AutoSave then
            local now = os.clock()
            if now - lastPoll < 2 then continue end
            lastPoll = now
            local current = HttpService:JSONEncode(configData())
            if current ~= lastSaved then
                lastSaved = current
                local name = UISettings_Config.LoadedConfig ~= ""
                    and UISettings_Config.LoadedConfig
                    or (_G.GradientNewConfigName or "MyConfig")
                pcall(saveConfigToFile, name)
            end
        end
    end
end)

-- Register window with the global suite registry (idempotent for shared window)
_G.GradientWindows = _G.GradientWindows or {}
local _alreadyRegistered = false
for _idx, _win in ipairs(_G.GradientWindows) do
    if _win == Window then
        _alreadyRegistered = true
        break
    end
end
if not _alreadyRegistered then
    table.insert(_G.GradientWindows, Window)
end

-- Expose a callable for init.luau to auto-apply a saved raw config
UIState.applySaved = function(raw)
    pcall(function()
        if raw and loadConfig(raw) then
            Fluent:Notify({ Title = "Gradient UI", Content = "Saved UI config applied automatically!", Duration = 3 })
        end
    end)
end

Window:SelectTab(1)

Fluent:Notify({
    Title = "Gradient Hub UI Settings",
    Content = "UI Settings module loaded successfully!",
    Duration = 5
})

print("[Gradient Hub] UI Settings module loaded successfully.")
end)
print('[Gradient] OK: ftap_uisettings.luau')
task.wait(0.1)
-- END MODULE: ftap_uisettings.luau

-- BEG MODULE: ftap_mercury_visuals.luau
pcall(function()
--[[
    ================================================================
    Gradient Hub Visuals & Settings - Complete Client Luau Script
    Target Game: Fling Things and People (FTAP)
    UI Library: Fluent UI
    File: ftap_mercury_visuals.luau
    ================================================================
--]]

-- Services Initialization
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Global Safe File IO Wrappers
local writefile = writefile or function() end
local readfile = readfile or function() return "" end
local isfile = isfile or function() return false end
local makefolder = makefolder or function() end
local isfolder = isfolder or function() return false end
local listfiles = listfiles or function() return {} end
local delfile = delfile or function() end

-- Ensure Config Folders
if not isfolder("GradientFTAP") then pcall(makefolder, "GradientFTAP") end
if not isfolder("GradientFTAP/HoleConfigs") then pcall(makefolder, "GradientFTAP/HoleConfigs") end
if not isfolder("GradientFTAP/SoundConfigs") then pcall(makefolder, "GradientFTAP/SoundConfigs") end

-- Shared window created by main.luau (one window for all modules)
local Fluent = _G.GradientFluent
local Window = _G.GradientWindow
if not Fluent or not Window then
    Fluent = (function()
        local ok, lib = pcall(function()
            return loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
        end)
        if ok and lib then return lib end
        local ok2, lib2 = pcall(function()
            return loadstring(game:HttpGet("https://raw.githubusercontent.com/disco0001/Fluent/main/main.lua"))()
        end)
        return (ok2 and lib2) or error("[Gradient] Failed to load Fluent UI library.")
    end)()
    local okW, win = pcall(Fluent.CreateWindow, Fluent, {
        Title = "Gradient Hub | FTAP",
        SubTitle = "by keksup22",
        TabWidth = 160,
        Size = UDim2.fromOffset(640, 460),
        Acrylic = true,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.LeftControl
    })
    Window = (okW and type(win) == "table" and type(win.AddTab) == "function") and win or nil
    if not Window then
        print("[Gradient] Fallback window creation failed.")
    end
    _G.GradientFluent = Fluent
    _G.GradientWindow = Window
end

if type(Fluent) ~= "table" or type(Window) ~= "table" or type(Window.AddTab) ~= "function" then
    print("[Gradient] Skip module: Fluent UI unavailable")
    return
end

-- Interface Tabs (mapped onto shared 4-tab layout)
local Tabs = {
    PCLD = _G.GradientTabs and _G.GradientTabs.Protections or Window:AddTab({ Title = "Protections", Icon = "shield" }),
    Players = _G.GradientTabs and _G.GradientTabs.Visuals or Window:AddTab({ Title = "Visuals", Icon = "user" }),
    Objects = _G.GradientTabs and _G.GradientTabs.Visuals or Window:AddTab({ Title = "Visuals", Icon = "box" }),
    Shaders = _G.GradientTabs and _G.GradientTabs.Visuals or Window:AddTab({ Title = "Visuals", Icon = "sun" }),
    Blackhole = _G.GradientTabs and _G.GradientTabs.Visuals or Window:AddTab({ Title = "Visuals", Icon = "disc" }),
    Sounds = _G.GradientTabs and _G.GradientTabs.Visuals or Window:AddTab({ Title = "Visuals", Icon = "volume-2" }),
    Spectate = _G.GradientTabs and _G.GradientTabs.Combat or Window:AddTab({ Title = "Combat", Icon = "eye" }),
    Settings = _G.GradientTabs and _G.GradientTabs.Settings or Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- Throttle helper: runs heavy render work at most once per interval, wrapped in pcall
local function makeThrottled(intervalSec)
    local last = 0
    return function(func)
        local now = os.clock()
        if now - last < intervalSec then return end
        last = now
        pcall(func)
    end
end

-- ================================================================
-- 1. PCLD (ANTI-CHEAT / PROTECTION) ESP MODULE
-- ================================================================

local PCLD_Config = {
    Enabled = false,
    Color = Color3.fromRGB(255, 0, 80),
    OutlineColor = Color3.fromRGB(255, 255, 255),
    Transparency = 0.5,
    OutlineTransparency = 0,
    EnableLerp = true,
    LerpSpeed = 10,
    TracersEnabled = false,
    TracerColor = Color3.fromRGB(255, 0, 80),
    TracerTransparency = 0.7
}

local PCLD_Cache = {} -- Stores [instance] = { Highlight = ..., Tracer = ..., TargetCFrame = ... }

local function isPCLDObject(inst)
    if not inst or not inst.Parent then return false end
    local name = string.lower(inst.Name)
    if string.find(name, "pcld") or string.find(name, "antifling") or string.find(name, "anti-fling") 
       or string.find(name, "anticheat") or string.find(name, "protection") then
        return true
    end
    if inst:GetAttribute("PCLD") or inst:GetAttribute("AntiFling") then
        return true
    end
    return false
end

local function createPCLDHighlight(inst)
    if PCLD_Cache[inst] then return end

    local hl = Instance.new("Highlight")
    hl.Name = "PCLD_Highlight"
    hl.Adornee = inst
    hl.FillColor = PCLD_Config.Color
    hl.OutlineColor = PCLD_Config.OutlineColor
    hl.FillTransparency = PCLD_Config.Transparency
    hl.OutlineTransparency = PCLD_Config.OutlineTransparency
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = inst

    local line = nil
    if Drawing and Drawing.new then
        line = Drawing.new("Line")
        line.Visible = false
        line.Thickness = 1.5
        line.Color = PCLD_Config.TracerColor
        line.Transparency = 1 - PCLD_Config.TracerTransparency
    end

    PCLD_Cache[inst] = {
        Highlight = hl,
        Tracer = line,
        CurrentCFrame = inst:IsA("BasePart") and inst.CFrame or (inst:IsA("Model") and inst:GetPivot() or CFrame.new())
    }
end

local function clearPCLDCache()
    for inst, data in pairs(PCLD_Cache) do
        if data.Highlight then data.Highlight:Destroy() end
        if data.Tracer then data.Tracer:Remove() end
    end
    table.clear(PCLD_Cache)
end

local function scanWorkspacePCLD()
    if not PCLD_Config.Enabled then return end
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if isPCLDObject(inst) and not PCLD_Cache[inst] then
            createPCLDHighlight(inst)
        end
    end
end

-- PCLD Render Loop (constant loop, refreshed at 10 FPS)
local pcldRenderTick = makeThrottled(0.1)
task.spawn(function()
    while true do
        task.wait(0.1)
        pcldRenderTick(function()
        if not PCLD_Config.Enabled then return end

        local viewportCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)

        for inst, data in pairs(PCLD_Cache) do
        if not inst or not inst.Parent then
            if data.Highlight then data.Highlight:Destroy() end
            if data.Tracer then data.Tracer:Remove() end
            PCLD_Cache[inst] = nil
        else
            -- Lerp Position Update if Enabled
            local targetCF = inst:IsA("BasePart") and inst.CFrame or (inst:IsA("Model") and inst:GetPivot() or CFrame.new())
            if PCLD_Config.EnableLerp then
                data.CurrentCFrame = data.CurrentCFrame:Lerp(targetCF, math.clamp(0.1 * PCLD_Config.LerpSpeed, 0, 1))
            else
                data.CurrentCFrame = targetCF
            end

            -- Update Highlight Properties
            data.Highlight.FillColor = PCLD_Config.Color
            data.Highlight.OutlineColor = PCLD_Config.OutlineColor
            data.Highlight.FillTransparency = PCLD_Config.Transparency
            data.Highlight.OutlineTransparency = PCLD_Config.OutlineTransparency

            -- Tracer Update
            if data.Tracer then
                if PCLD_Config.TracersEnabled then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(data.CurrentCFrame.Position)
                    if onScreen then
                        data.Tracer.From = viewportCenter
                        data.Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                        data.Tracer.Color = PCLD_Config.TracerColor
                        data.Tracer.Transparency = 1 - PCLD_Config.TracerTransparency
                        data.Tracer.Visible = true
                    else
                        data.Tracer.Visible = false
                    end
                else
                    data.Tracer.Visible = false
                end
            end
        end
        end
        end)
    end
end)

-- Workspace Descendant Monitors for PCLD
Workspace.DescendantAdded:Connect(function(inst)
    if PCLD_Config.Enabled and isPCLDObject(inst) then
        createPCLDHighlight(inst)
    end
end)

-- PCLD UI Elements
Tabs.PCLD:AddSection("PCLD Anti-Cheat / Protection ESP")

local PCLDToggle = Tabs.PCLD:AddToggle("PCLDEspToggle", { Title = "Enable PCLD ESP", Default = false })
PCLDToggle:OnChanged(function(Value)
    PCLD_Config.Enabled = Value
    if Value then
        scanWorkspacePCLD()
    else
        clearPCLDCache()
    end
end)

Tabs.PCLD:AddColorpicker("PCLDFillColor", {
    Title = "PCLD Color",
    Default = Color3.fromRGB(255, 0, 80),
    Callback = function(Value)
        PCLD_Config.Color = Value
    end
})

Tabs.PCLD:AddColorpicker("PCLDOutlineColor", {
    Title = "Outline Color",
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(Value)
        PCLD_Config.OutlineColor = Value
    end
})

Tabs.PCLD:AddSlider("PCLDTransparency", {
    Title = "PCLD Transparency",
    Default = 0.5,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(Value)
        PCLD_Config.Transparency = Value
    end
})

Tabs.PCLD:AddSection("PCLD Tracking & Smoothness")

local PCLDLerpToggle = Tabs.PCLD:AddToggle("PCLDLerpToggle", { Title = "Enable Lerp (Smooth Tracking)", Default = true })
PCLDLerpToggle:OnChanged(function(Value)
    PCLD_Config.EnableLerp = Value
end)

Tabs.PCLD:AddSlider("PCLDLerpSpeed", {
    Title = "Lerp Speed",
    Default = 10,
    Min = 1,
    Max = 30,
    Rounding = 1,
    Callback = function(Value)
        PCLD_Config.LerpSpeed = Value
    end
})

Tabs.PCLD:AddSection("PCLD Tracer Lines")

local PCLDTracerToggle = Tabs.PCLD:AddToggle("PCLDTracerToggle", { Title = "Tracer Lines to PCLD", Default = false })
PCLDTracerToggle:OnChanged(function(Value)
    PCLD_Config.TracersEnabled = Value
end)

Tabs.PCLD:AddColorpicker("PCLDTracerColor", {
    Title = "Tracer Color",
    Default = Color3.fromRGB(255, 0, 80),
    Callback = function(Value)
        PCLD_Config.TracerColor = Value
    end
})

Tabs.PCLD:AddSlider("PCLDTracerTransparency", {
    Title = "Tracer Transparency",
    Default = 0.3,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(Value)
        PCLD_Config.TracerTransparency = Value
    end
})


-- ================================================================
-- 2. PLAYERS ESP & CHAMS MODULE
-- ================================================================

local PlayerESP_Config = {
    NamesEnabled = false,
    NamesColor = Color3.fromRGB(255, 255, 255),
    TextSize = 14,
    Font = "UI",
    TagHeight = 2.5,
    ShowDistance = true,

    BoxesEnabled = false,
    BoxColor = Color3.fromRGB(0, 255, 150),

    SkeletonsEnabled = false,
    SkeletonColor = Color3.fromRGB(255, 255, 0),

    ChamsEnabled = false,
    ChamsColor = Color3.fromRGB(150, 0, 255),
    ChamsOutlineColor = Color3.fromRGB(255, 255, 255),
    ChamsTransparency = 0.4
}

local PlayerESP_Cache = {} -- [player] = { NameText, BoxSquare, SkeletonLines = {}, Highlight }

local R15Joints = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"}
}

local R6Joints = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"}
}

local FontEnumMap = {
    ["UI"] = 0,
    ["System"] = 1,
    ["Plex"] = 2,
    ["Monospace"] = 3
}

local function getPlayerDrawings(player)
    if PlayerESP_Cache[player] then return PlayerESP_Cache[player] end

    local nameText = nil
    local boxSquare = nil
    local skeletonLines = {}

    if Drawing and Drawing.new then
        nameText = Drawing.new("Text")
        nameText.Visible = false
        nameText.Center = true
        nameText.Outline = true
        nameText.OutlineColor = Color3.fromRGB(0, 0, 0)

        boxSquare = Drawing.new("Square")
        boxSquare.Visible = false
        boxSquare.Thickness = 1.5
        boxSquare.Filled = false

        for i = 1, 15 do
            local line = Drawing.new("Line")
            line.Visible = false
            line.Thickness = 1.2
            table.insert(skeletonLines, line)
        end
    end

    PlayerESP_Cache[player] = {
        NameText = nameText,
        BoxSquare = boxSquare,
        SkeletonLines = skeletonLines,
        Highlight = nil
    }

    return PlayerESP_Cache[player]
end

local function removePlayerESP(player)
    local cache = PlayerESP_Cache[player]
    if cache then
        if cache.NameText then cache.NameText:Remove() end
        if cache.BoxSquare then cache.BoxSquare:Remove() end
        for _, line in ipairs(cache.SkeletonLines) do
            line:Remove()
        end
        if cache.Highlight then cache.Highlight:Destroy() end
        PlayerESP_Cache[player] = nil
    end
end

-- Player ESP Render Loop (constant loop, refreshed at 10 FPS)
local playerEspRenderTick = makeThrottled(0.1)
task.spawn(function()
    while true do
        task.wait(0.1)
    playerEspRenderTick(function()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local cache = getPlayerDrawings(player)
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local head = char and char:FindFirstChild("Head")
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")

            if char and root and head and humanoid and humanoid.Health > 0 then
                local rootPos, rootOnScreen = Camera:WorldToViewportPoint(root.Position)
                local headPos, headOnScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, PlayerESP_Config.TagHeight, 0))
                local dist = math.floor((Camera.CFrame.Position - root.Position).Magnitude)

                -- 1. Name ESP
                if cache.NameText then
                    if PlayerESP_Config.NamesEnabled and headOnScreen then
                        cache.NameText.Text = player.DisplayName .. " (@" .. player.Name .. ")" .. (PlayerESP_Config.ShowDistance and (" [" .. dist .. "m]") or "")
                        cache.NameText.Position = Vector2.new(headPos.X, headPos.Y)
                        cache.NameText.Color = PlayerESP_Config.NamesColor
                        cache.NameText.Size = PlayerESP_Config.TextSize
                        cache.NameText.Font = FontEnumMap[PlayerESP_Config.Font] or 0
                        cache.NameText.Visible = true
                    else
                        cache.NameText.Visible = false
                    end
                end

                -- 2. Box ESP
                if cache.BoxSquare then
                    if PlayerESP_Config.BoxesEnabled and rootOnScreen then
                        local extents = char:GetExtentsSize()
                        local topPos = Camera:WorldToViewportPoint(root.Position + Vector3.new(0, extents.Y / 1.8, 0))
                        local bottomPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, extents.Y / 1.8, 0))
                        local boxHeight = math.abs(topPos.Y - bottomPos.Y)
                        local boxWidth = boxHeight * 0.65

                        cache.BoxSquare.Size = Vector2.new(boxWidth, boxHeight)
                        cache.BoxSquare.Position = Vector2.new(rootPos.X - boxWidth / 2, rootPos.Y - boxHeight / 2)
                        cache.BoxSquare.Color = PlayerESP_Config.BoxColor
                        cache.BoxSquare.Visible = true
                    else
                        cache.BoxSquare.Visible = false
                    end
                end

                -- 3. Skeleton ESP
                if #cache.SkeletonLines > 0 then
                    if PlayerESP_Config.SkeletonsEnabled and rootOnScreen then
                        local joints = (humanoid.RigType == Enum.HumanoidRigType.R15) and R15Joints or R6Joints
                        for i, pair in ipairs(joints) do
                            local partA = char:FindFirstChild(pair[1])
                            local partB = char:FindFirstChild(pair[2])
                            local line = cache.SkeletonLines[i]

                            if partA and partB and line then
                                local posA, visA = Camera:WorldToViewportPoint(partA.Position)
                                local posB, visB = Camera:WorldToViewportPoint(partB.Position)

                                if visA and visB then
                                    line.From = Vector2.new(posA.X, posA.Y)
                                    line.To = Vector2.new(posB.X, posB.Y)
                                    line.Color = PlayerESP_Config.SkeletonColor
                                    line.Visible = true
                                else
                                    line.Visible = false
                                end
                            elseif line then
                                line.Visible = false
                            end
                        end
                    else
                        for _, line in ipairs(cache.SkeletonLines) do
                            line.Visible = false
                        end
                    end
                end

                -- 4. Chams Players
                if PlayerESP_Config.ChamsEnabled then
                    if not cache.Highlight or cache.Highlight.Parent ~= char then
                        if cache.Highlight then cache.Highlight:Destroy() end
                        cache.Highlight = Instance.new("Highlight")
                        cache.Highlight.Name = "PlayerChams"
                        cache.Highlight.Adornee = char
                        cache.Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        cache.Highlight.Parent = char
                    end
                    cache.Highlight.FillColor = PlayerESP_Config.ChamsColor
                    cache.Highlight.OutlineColor = PlayerESP_Config.ChamsOutlineColor
                    cache.Highlight.FillTransparency = PlayerESP_Config.ChamsTransparency
                    cache.Highlight.Enabled = true
                else
                    if cache.Highlight then
                        cache.Highlight.Enabled = false
                    end
                end
            else
                -- Hide drawings if player invalid / dead
                if cache.NameText then cache.NameText.Visible = false end
                if cache.BoxSquare then cache.BoxSquare.Visible = false end
                for _, line in ipairs(cache.SkeletonLines) do line.Visible = false end
                if cache.Highlight then cache.Highlight.Enabled = false end
            end
        end
    end
    end)
    end
end)

Players.PlayerRemoving:Connect(removePlayerESP)

-- Players ESP UI Elements
Tabs.Players:AddSection("Name ESP Settings")

local NameESPToggle = Tabs.Players:AddToggle("NameESPToggle", { Title = "Enable Name ESP", Default = false })
NameESPToggle:OnChanged(function(Value) PlayerESP_Config.NamesEnabled = Value end)

Tabs.Players:AddColorpicker("NameESPColor", {
    Title = "Name Color",
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(Value) PlayerESP_Config.NamesColor = Value end
})

Tabs.Players:AddDropdown("NameESPFont", {
    Title = "Font",
    Values = {"UI", "System", "Plex", "Monospace"},
    Default = "UI",
    Callback = function(Value) PlayerESP_Config.Font = Value end
})

Tabs.Players:AddSlider("NameESPTextSize", {
    Title = "Text Size",
    Default = 14,
    Min = 10,
    Max = 28,
    Rounding = 0,
    Callback = function(Value) PlayerESP_Config.TextSize = Value end
})

Tabs.Players:AddSlider("NameESPTagHeight", {
    Title = "Tag Height Offset",
    Default = 2.5,
    Min = 0,
    Max = 8,
    Rounding = 1,
    Callback = function(Value) PlayerESP_Config.TagHeight = Value end
})

Tabs.Players:AddSection("Box & Skeleton ESP")

local BoxESPToggle = Tabs.Players:AddToggle("BoxESPToggle", { Title = "Enable Box ESP", Default = false })
BoxESPToggle:OnChanged(function(Value) PlayerESP_Config.BoxesEnabled = Value end)

Tabs.Players:AddColorpicker("BoxESPColor", {
    Title = "Box Color",
    Default = Color3.fromRGB(0, 255, 150),
    Callback = function(Value) PlayerESP_Config.BoxColor = Value end
})

local SkeletonESPToggle = Tabs.Players:AddToggle("SkeletonESPToggle", { Title = "Enable Skeleton ESP", Default = false })
SkeletonESPToggle:OnChanged(function(Value) PlayerESP_Config.SkeletonsEnabled = Value end)

Tabs.Players:AddColorpicker("SkeletonESPColor", {
    Title = "Skeleton Color",
    Default = Color3.fromRGB(255, 255, 0),
    Callback = function(Value) PlayerESP_Config.SkeletonColor = Value end
})

Tabs.Players:AddSection("Chams Players")

local ChamsToggle = Tabs.Players:AddToggle("ChamsToggle", { Title = "Enable Players Chams", Default = false })
ChamsToggle:OnChanged(function(Value) PlayerESP_Config.ChamsEnabled = Value end)

Tabs.Players:AddColorpicker("ChamsColor", {
    Title = "Chams Fill Color",
    Default = Color3.fromRGB(150, 0, 255),
    Callback = function(Value) PlayerESP_Config.ChamsColor = Value end
})

Tabs.Players:AddColorpicker("ChamsOutlineColor", {
    Title = "Chams Outline Color",
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(Value) PlayerESP_Config.ChamsOutlineColor = Value end
})

Tabs.Players:AddSlider("ChamsTransparency", {
    Title = "Chams Transparency",
    Default = 0.4,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(Value) PlayerESP_Config.ChamsTransparency = Value end
})


-- ================================================================
-- 3. OBJECT & BLOBMAN ESP (FTAP MECHANICS)
-- ================================================================

local ObjectESP_Config = {
    StickEnabled = false,
    StickColor = Color3.fromRGB(255, 170, 0),

    StickHouseEnabled = false,
    StickHouseColor = Color3.fromRGB(0, 200, 255),

    BlobmanEnabled = false,
    BlobmanColor = Color3.fromRGB(0, 255, 100),
    BlobmanOutlineColor = Color3.fromRGB(255, 255, 255),
    BlobmanTransparency = 0.3,

    PlotOwnersEnabled = false,
    SlotTimeEnabled = false
}

local ObjectESP_Highlights = {} -- Stores [instance] = Highlight / BillboardGui

local function clearObjectESP(key)
    for inst, item in pairs(ObjectESP_Highlights) do
        if not key or item.Type == key then
            if item.Highlight then item.Highlight:Destroy() end
            if item.Billboard then item.Billboard:Destroy() end
            ObjectESP_Highlights[inst] = nil
        end
    end
end

local function applyObjectESP(inst, espType, color, outlineColor, trans, labelText)
    if not inst or not inst.Parent then return end

    local existing = ObjectESP_Highlights[inst]
    if not existing then
        local hl = Instance.new("Highlight")
        hl.Name = "FTAP_ObjectESP_" .. espType
        hl.Adornee = inst
        hl.FillColor = color or Color3.fromRGB(255, 255, 255)
        hl.OutlineColor = outlineColor or Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = trans or 0.4
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = inst

        local bb = nil
        if labelText then
            bb = Instance.new("BillboardGui")
            bb.Name = "FTAP_Label_" .. espType
            bb.Adornee = inst:IsA("Model") and (inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")) or inst
            bb.Size = UDim2.fromOffset(150, 30)
            bb.StudsOffset = Vector3.new(0, 3, 0)
            bb.AlwaysOnTop = true

            local txt = Instance.new("TextLabel")
            txt.Size = UDim2.fromScale(1, 1)
            txt.BackgroundTransparency = 1
            txt.Text = labelText
            txt.TextColor3 = color or Color3.fromRGB(255, 255, 255)
            txt.TextStrokeTransparency = 0
            txt.TextSize = 14
            txt.Font = Enum.Font.SourceSansBold
            txt.Parent = bb
            bb.Parent = inst
        end

        ObjectESP_Highlights[inst] = {
            Highlight = hl,
            Billboard = bb,
            Type = espType
        }
    else
        if existing.Highlight then
            existing.Highlight.FillColor = color or existing.Highlight.FillColor
            existing.Highlight.OutlineColor = outlineColor or existing.Highlight.OutlineColor
            existing.Highlight.FillTransparency = trans or existing.Highlight.FillTransparency
        end
    end
end

local function isStick(inst)
    local name = string.lower(inst.Name)
    return string.find(name, "stick") and not string.find(name, "house") and not string.find(name, "structure")
end

local function isStickHouse(inst)
    local name = string.lower(inst.Name)
    return (string.find(name, "stick") and (string.find(name, "house") or string.find(name, "structure") or string.find(name, "building"))) or string.find(name, "stickhouse")
end

local function isBlobman(inst)
    local name = string.lower(inst.Name)
    return string.find(name, "blobman") or string.find(name, "blob_man") or string.find(name, "doll") or inst:GetAttribute("Blobman")
end

local ObjectESP_ScanCooldown = 0
local function updateObjectESPScan()
    if not (ObjectESP_Config.StickEnabled or ObjectESP_Config.StickHouseEnabled or ObjectESP_Config.BlobmanEnabled or ObjectESP_Config.PlotOwnersEnabled or ObjectESP_Config.SlotTimeEnabled) then
        clearObjectESP()
        return
    end

    -- Heavy Workspace scan is limited to 1x/sec (microfreeze guard)
    local now = os.clock()
    if now - ObjectESP_ScanCooldown < 1 then return end
    ObjectESP_ScanCooldown = now

    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("Model") or inst:IsA("BasePart") then
            -- Sticks
            if ObjectESP_Config.StickEnabled and isStick(inst) then
                applyObjectESP(inst, "Stick", ObjectESP_Config.StickColor, Color3.fromRGB(255, 255, 255), 0.3)
            end
            -- Stick Houses
            if ObjectESP_Config.StickHouseEnabled and isStickHouse(inst) then
                applyObjectESP(inst, "StickHouse", ObjectESP_Config.StickHouseColor, Color3.fromRGB(255, 255, 255), 0.3, "Stick House")
            end
            -- Blobman NPC / Dolls
            if ObjectESP_Config.BlobmanEnabled and isBlobman(inst) then
                applyObjectESP(inst, "Blobman", ObjectESP_Config.BlobmanColor, ObjectESP_Config.BlobmanOutlineColor, ObjectESP_Config.BlobmanTransparency, "Blobman")
            end
            -- Plot Owners
            if ObjectESP_Config.PlotOwnersEnabled and (string.find(string.lower(inst.Name), "plot") or string.find(string.lower(inst.Name), "base")) then
                local ownerVal = inst:FindFirstChild("Owner") or inst:GetAttribute("Owner")
                local ownerName = type(ownerVal) == "userdata" and ownerVal.Value or (type(ownerVal) == "string" and ownerVal or "Unclaimed")
                applyObjectESP(inst, "PlotOwner", Color3.fromRGB(255, 215, 0), Color3.fromRGB(255, 255, 255), 0.6, "Plot Owner: " .. tostring(ownerName))
            end
            -- Slot Timers
            if ObjectESP_Config.SlotTimeEnabled and (string.find(string.lower(inst.Name), "slot") or inst:FindFirstChild("Timer")) then
                local timerVal = inst:FindFirstChild("Timer") or inst:GetAttribute("Time") or "0s"
                applyObjectESP(inst, "SlotTime", Color3.fromRGB(0, 255, 200), Color3.fromRGB(255, 255, 255), 0.5, "Slot Time: " .. tostring(timerVal))
            end
        end
    end
end

-- Refresh Object ESP Loop
task.spawn(function()
    while task.wait(3) do
        updateObjectESPScan()
    end
end)

-- Object ESP UI Elements
Tabs.Objects:AddSection("Stick & Stick House ESP")

local StickToggle = Tabs.Objects:AddToggle("StickESPToggle", { Title = "Stick ESP", Default = false })
StickToggle:OnChanged(function(Value)
    ObjectESP_Config.StickEnabled = Value
    if Value then updateObjectESPScan() else clearObjectESP("Stick") end
end)

Tabs.Objects:AddColorpicker("StickColor", {
    Title = "Stick Color",
    Default = Color3.fromRGB(255, 170, 0),
    Callback = function(Value) ObjectESP_Config.StickColor = Value; updateObjectESPScan() end
})

local HouseToggle = Tabs.Objects:AddToggle("StickHouseESPToggle", { Title = "Stick House ESP", Default = false })
HouseToggle:OnChanged(function(Value)
    ObjectESP_Config.StickHouseEnabled = Value
    if Value then updateObjectESPScan() else clearObjectESP("StickHouse") end
end)

Tabs.Objects:AddColorpicker("StickHouseColor", {
    Title = "House Color",
    Default = Color3.fromRGB(0, 200, 255),
    Callback = function(Value) ObjectESP_Config.StickHouseColor = Value; updateObjectESPScan() end
})

Tabs.Objects:AddSection("Blobman ESP (FTAP NPCs)")

local BlobmanToggle = Tabs.Objects:AddToggle("BlobmanESPToggle", { Title = "ESP All Blobman", Default = false })
BlobmanToggle:OnChanged(function(Value)
    ObjectESP_Config.BlobmanEnabled = Value
    if Value then updateObjectESPScan() else clearObjectESP("Blobman") end
end)

Tabs.Objects:AddColorpicker("BlobmanFillColor", {
    Title = "Blobman Fill Color",
    Default = Color3.fromRGB(0, 255, 100),
    Callback = function(Value) ObjectESP_Config.BlobmanColor = Value; updateObjectESPScan() end
})

Tabs.Objects:AddColorpicker("BlobmanOutlineColor", {
    Title = "Blobman Outline Color",
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(Value) ObjectESP_Config.BlobmanOutlineColor = Value; updateObjectESPScan() end
})

Tabs.Objects:AddSlider("BlobmanTransparency", {
    Title = "Blobman Transparency",
    Default = 0.3,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(Value) ObjectESP_Config.BlobmanTransparency = Value; updateObjectESPScan() end
})

Tabs.Objects:AddSection("Plots & Slot Timers")

local PlotToggle = Tabs.Objects:AddToggle("PlotOwnersToggle", { Title = "Plot Owners ESP", Default = false })
PlotToggle:OnChanged(function(Value)
    ObjectESP_Config.PlotOwnersEnabled = Value
    if Value then updateObjectESPScan() else clearObjectESP("PlotOwner") end
end)

local SlotToggle = Tabs.Objects:AddToggle("SlotTimeToggle", { Title = "Slot Time ESP", Default = false })
SlotToggle:OnChanged(function(Value)
    ObjectESP_Config.SlotTimeEnabled = Value
    if Value then updateObjectESPScan() else clearObjectESP("SlotTime") end
end)


-- ================================================================
-- 4. SHADERS LOADER & CUSTOM SKY MODULE
-- ================================================================

local ActivePostEffects = {}
local OriginalSky = nil

local SkyPresets = {
    ["Blue Space"] = "rbxassetid://159454299",
    ["Purple Nebula"] = "rbxassetid://605619965",
    ["Night Stars"] = "rbxassetid://12064107",
    ["Red Galaxy"] = "rbxassetid://263300262",
    ["Sunset Glow"] = "rbxassetid://6008337199",
    ["Pastel Clouds"] = "rbxassetid://110038813"
}

local function clearActiveShaders()
    for _, effect in ipairs(ActivePostEffects) do
        effect:Destroy()
    end
    table.clear(ActivePostEffects)
end

local function applyShaderPreset(presetName)
    clearActiveShaders()
    if presetName == "Default / None" then return end

    local colorCorrection = Instance.new("ColorCorrectionEffect")
    colorCorrection.Name = "FTAP_Shader_CC"
    colorCorrection.Parent = Lighting
    table.insert(ActivePostEffects, colorCorrection)

    local bloom = Instance.new("BloomEffect")
    bloom.Name = "FTAP_Shader_Bloom"
    bloom.Parent = Lighting
    table.insert(ActivePostEffects, bloom)

    if presetName == "Cyberpunk (Neon)" then
        colorCorrection.Saturation = 0.4
        colorCorrection.TintColor = Color3.fromRGB(180, 120, 255)
        colorCorrection.Contrast = 0.2
        bloom.Intensity = 1.2
        bloom.Size = 24
        bloom.Threshold = 0.8
    elseif presetName == "Vintage Warm" then
        colorCorrection.Saturation = -0.1
        colorCorrection.TintColor = Color3.fromRGB(255, 220, 180)
        colorCorrection.Contrast = 0.1
        bloom.Intensity = 0.5
    elseif presetName == "Crisp Cold" then
        colorCorrection.Saturation = 0.2
        colorCorrection.TintColor = Color3.fromRGB(180, 220, 255)
        colorCorrection.Contrast = 0.15
        bloom.Intensity = 0.8
    elseif presetName == "Pastel Soft" then
        colorCorrection.Saturation = -0.2
        colorCorrection.TintColor = Color3.fromRGB(255, 200, 220)
        local blur = Instance.new("BlurEffect")
        blur.Size = 3
        blur.Parent = Lighting
        table.insert(ActivePostEffects, blur)
    elseif presetName == "High Contrast HDR" then
        colorCorrection.Contrast = 0.4
        colorCorrection.Saturation = 0.3
        bloom.Intensity = 1.5
    end
end

local function setCustomSky(skyAssetId)
    local currentSky = Lighting:FindFirstChildOfClass("Sky")
    if not OriginalSky and currentSky then
        OriginalSky = currentSky:Clone()
    end

    if currentSky then currentSky:Destroy() end

    local newSky = Instance.new("Sky")
    newSky.Name = "FTAP_CustomSky"
    newSky.SkyboxBk = skyAssetId
    newSky.SkyboxDn = skyAssetId
    newSky.SkyboxFt = skyAssetId
    newSky.SkyboxLf = skyAssetId
    newSky.SkyboxRt = skyAssetId
    newSky.SkyboxUp = skyAssetId
    newSky.Parent = Lighting
end

local function restoreOriginalSky()
    local currentSky = Lighting:FindFirstChildOfClass("Sky")
    if currentSky then currentSky:Destroy() end
    if OriginalSky then
        OriginalSky:Clone().Parent = Lighting
    end
end

-- Shaders & Sky UI Elements
Tabs.Shaders:AddSection("Post-Processing Shaders")

local ShadersEnabled = false
local CurrentShader = "Default / None"

local ShadersToggle = Tabs.Shaders:AddToggle("ShadersToggle", { Title = "Shaders Enabled", Default = false })
ShadersToggle:OnChanged(function(Value)
    ShadersEnabled = Value
    if Value then
        applyShaderPreset(CurrentShader)
    else
        clearActiveShaders()
    end
end)

Tabs.Shaders:AddDropdown("ShaderSelector", {
    Title = "Shader Selector",
    Values = {"Default / None", "Cyberpunk (Neon)", "Vintage Warm", "Crisp Cold", "Pastel Soft", "High Contrast HDR"},
    Default = "Default / None",
    Callback = function(Value)
        CurrentShader = Value
        if ShadersEnabled then
            applyShaderPreset(CurrentShader)
        end
    end
})

Tabs.Shaders:AddSection("Custom Skybox")

local CustomSkyToggle = Tabs.Shaders:AddToggle("CustomSkyToggle", { Title = "Enable Custom Sky", Default = false })

local SkyPresetDropdown = Tabs.Shaders:AddDropdown("SkyboxPreset", {
    Title = "Skybox Preset",
    Values = {"Blue Space", "Purple Nebula", "Night Stars", "Red Galaxy", "Sunset Glow", "Pastel Clouds"},
    Default = "Blue Space",
    Callback = function(Value)
        if CustomSkyToggle.Value then
            setCustomSky(SkyPresets[Value] or SkyPresets["Blue Space"])
        end
    end
})

CustomSkyToggle:OnChanged(function(Value)
    if Value then
        setCustomSky(SkyPresets[SkyPresetDropdown.Value] or SkyPresets["Blue Space"])
    else
        restoreOriginalSky()
    end
end)

local CustomSkyInput = Tabs.Shaders:AddInput("CustomSkyID", {
    Title = "Custom Asset ID / URL",
    Default = "",
    Placeholder = "rbxassetid://...",
    Numeric = false,
    Finished = true,
    Callback = function(Value)
        if Value ~= "" and CustomSkyToggle.Value then
            local formatted = string.find(Value, "rbxassetid://") and Value or ("rbxassetid://" .. Value)
            setCustomSky(formatted)
        end
    end
})


-- ================================================================
-- 5. CUSTOM BLACKHOLE MODULE & CONFIG MANAGEMENT
-- ================================================================

local Blackhole_Config = {
    TextureID = "rbxassetid://1310813038",
    SizeScale = 1.0,
    GlowEnabled = false,
    GlowColor = Color3.fromRGB(150, 0, 255)
}

local function findBlackhole()
    local targetNames = {"blackhole", "hole", "black_hole", "voidhole"}
    for _, inst in ipairs(Workspace:GetDescendants()) do
        local name = string.lower(inst.Name)
        for _, tName in ipairs(targetNames) do
            if string.find(name, tName) and (inst:IsA("BasePart") or inst:IsA("Model") or inst:IsA("MeshPart")) then
                return inst
            end
        end
    end
    return nil
end

local function applyBlackholeTexture(assetId)
    local hole = findBlackhole()
    if not hole then
        Fluent:Notify({ Title = "Blackhole", Content = "Blackhole instance not found in Workspace.", Duration = 3 })
        return
    end

    local formattedID = string.find(assetId, "rbxassetid://") and assetId or ("rbxassetid://" .. assetId)

    if hole:IsA("MeshPart") then
        hole.TextureID = formattedID
    elseif hole:IsA("BasePart") then
        local decal = hole:FindFirstChildOfClass("Decal") or Instance.new("Decal", hole)
        decal.Texture = formattedID
        decal.Face = Enum.NormalId.Front
    elseif hole:IsA("Model") then
        for _, child in ipairs(hole:GetChildren()) do
            if child:IsA("MeshPart") then
                child.TextureID = formattedID
            elseif child:IsA("BasePart") then
                local decal = child:FindFirstChildOfClass("Decal") or Instance.new("Decal", child)
                decal.Texture = formattedID
            end
        end
    end

    Fluent:Notify({ Title = "Blackhole", Content = "Applied custom hole texture successfully!", Duration = 3 })
end

-- Hole Config System
local SavedHoleConfigs = {}

local function refreshHoleConfigList()
    table.clear(SavedHoleConfigs)
    local files = listfiles("GradientFTAP/HoleConfigs")
    local names = {}
    for _, filePath in ipairs(files) do
        local filename = string.match(filePath, "([^/]+)%.json$")
        if filename then
            table.insert(names, filename)
            SavedHoleConfigs[filename] = filePath
        end
    end
    if #names == 0 then table.insert(names, "None") end
    return names
end

-- Blackhole UI Elements
Tabs.Blackhole:AddSection("Custom Blackhole Visuals")

local HoleTextureInput = Tabs.Blackhole:AddInput("HoleTextureInput", {
    Title = "Custom Hole Texture ID / URL",
    Default = "rbxassetid://1310813038",
    Placeholder = "Enter Asset ID or URL",
    Numeric = false,
    Finished = false,
    Callback = function(Value) Blackhole_Config.TextureID = Value end
})

Tabs.Blackhole:AddButton({
    Title = "Apply Custom Hole Texture",
    Description = "Updates the Blackhole texture in Workspace",
    Callback = function()
        applyBlackholeTexture(Blackhole_Config.TextureID)
    end
})

Tabs.Blackhole:AddSlider("HoleScaleSlider", {
    Title = "Blackhole Scale Multiplier",
    Default = 1.0,
    Min = 0.5,
    Max = 5.0,
    Rounding = 1,
    Callback = function(Value)
        Blackhole_Config.SizeScale = Value
        local hole = findBlackhole()
        if hole then
            if hole:IsA("Model") then
                hole:ScaleTo(Value)
            elseif hole:IsA("BasePart") then
                hole.Size = Vector3.new(20, 20, 20) * Value
            end
        end
    end
})

Tabs.Blackhole:AddSection("Blackhole Configs Manager")

local HolePresetNameInput = Tabs.Blackhole:AddInput("HolePresetName", {
    Title = "New Config Name",
    Default = "MyHoleConfig",
    Placeholder = "Config name..."
})

local HoleDropdown = Tabs.Blackhole:AddDropdown("HoleConfigSelector", {
    Title = "Saved Configs",
    Values = refreshHoleConfigList(),
    Default = "None"
})

Tabs.Blackhole:AddButton({
    Title = "Save Current Config",
    Callback = function()
        local name = HolePresetNameInput.Value
        if name and name ~= "" then
            local path = "GradientFTAP/HoleConfigs/" .. name .. ".json"
            local data = HttpService:JSONEncode(Blackhole_Config)
            writefile(path, data)
            Fluent:Notify({ Title = "Config Saved", Content = "Saved " .. name .. " successfully!", Duration = 3 })
            HoleDropdown:SetValues(refreshHoleConfigList())
        end
    end
})

Tabs.Blackhole:AddButton({
    Title = "Load Selected Config",
    Callback = function()
        local selected = HoleDropdown.Value
        local path = SavedHoleConfigs[selected]
        if path and isfile(path) then
            local raw = readfile(path)
            local parsed = HttpService:JSONDecode(raw)
            if parsed then
                Blackhole_Config = parsed
                HoleTextureInput:SetValue(parsed.TextureID or "")
                applyBlackholeTexture(parsed.TextureID or "")
                Fluent:Notify({ Title = "Config Loaded", Content = "Loaded " .. selected .. "!", Duration = 3 })
            end
        end
    end
})

Tabs.Blackhole:AddButton({
    Title = "Delete Selected Config",
    Callback = function()
        local selected = HoleDropdown.Value
        local path = SavedHoleConfigs[selected]
        if path and isfile(path) then
            delfile(path)
            Fluent:Notify({ Title = "Config Deleted", Content = "Deleted " .. selected .. "!", Duration = 3 })
            HoleDropdown:SetValues(refreshHoleConfigList())
        end
    end
})


-- ================================================================
-- 6. YOUR NOTIFY SOUND (CUSTOM SOUNDS) MODULE
-- ================================================================

local Sound_Config = {
    Enabled = true,
    SoundID = "rbxassetid://9114223280", -- Default notification sound
    Volume = 2.0,
    TriggerEvent = "Manual Play / Keybind"
}

local function playCustomSound(overrideId)
    local id = overrideId or Sound_Config.SoundID
    if not id or id == "" then return end

    local formatted = string.find(id, "rbxassetid://") and id or ("rbxassetid://" .. id)
    local sound = Instance.new("Sound")
    sound.SoundId = formatted
    sound.Volume = Sound_Config.Volume
    sound.Parent = SoundService
    sound:Play()

    sound.Ended:Connect(function()
        sound:Destroy()
    end)
end

-- Saved Sound Configs System
local SavedSoundConfigs = {}

local function refreshSoundConfigList()
    table.clear(SavedSoundConfigs)
    local files = listfiles("GradientFTAP/SoundConfigs")
    local names = {}
    for _, filePath in ipairs(files) do
        local filename = string.match(filePath, "([^/]+)%.json$")
        if filename then
            table.insert(names, filename)
            SavedSoundConfigs[filename] = filePath
        end
    end
    if #names == 0 then table.insert(names, "None") end
    return names
end

-- Audio UI Elements
Tabs.Sounds:AddSection("Custom Notify Sound Settings")

local SoundEnabledToggle = Tabs.Sounds:AddToggle("SoundEnabledToggle", { Title = "Enable Sound Notifications", Default = true })
SoundEnabledToggle:OnChanged(function(Value) Sound_Config.Enabled = Value end)

local SoundInput = Tabs.Sounds:AddInput("SoundIDInput", {
    Title = "Sound ID / URL",
    Default = "9114223280",
    Placeholder = "Enter Sound Asset ID",
    Numeric = false,
    Finished = false,
    Callback = function(Value) Sound_Config.SoundID = Value end
})

Tabs.Sounds:AddButton({
    Title = "Test Sound",
    Description = "Play custom sound preview",
    Callback = function()
        playCustomSound(Sound_Config.SoundID)
    end
})

Tabs.Sounds:AddSlider("SoundVolumeSlider", {
    Title = "Sound Volume",
    Default = 2.0,
    Min = 0.1,
    Max = 10.0,
    Rounding = 1,
    Callback = function(Value) Sound_Config.Volume = Value end
})

Tabs.Sounds:AddDropdown("SoundTriggerDropdown", {
    Title = "Trigger Event",
    Values = {"Manual Play / Keybind", "On Grab / Hold Object", "On Fling Player", "On Player Join"},
    Default = "Manual Play / Keybind",
    Callback = function(Value) Sound_Config.TriggerEvent = Value end
})

Tabs.Sounds:AddSection("Sound Configs Manager")

local SoundPresetNameInput = Tabs.Sounds:AddInput("SoundPresetName", {
    Title = "Preset Name",
    Default = "MySoundPreset",
    Placeholder = "Preset name..."
})

local SoundDropdown = Tabs.Sounds:AddDropdown("SoundConfigSelector", {
    Title = "Saved Sound Configs",
    Values = refreshSoundConfigList(),
    Default = "None"
})

Tabs.Sounds:AddButton({
    Title = "Save Sound Config",
    Callback = function()
        local name = SoundPresetNameInput.Value
        if name and name ~= "" then
            local path = "GradientFTAP/SoundConfigs/" .. name .. ".json"
            local data = HttpService:JSONEncode(Sound_Config)
            writefile(path, data)
            Fluent:Notify({ Title = "Sound Config Saved", Content = "Saved " .. name .. "!", Duration = 3 })
            SoundDropdown:SetValues(refreshSoundConfigList())
        end
    end
})

Tabs.Sounds:AddButton({
    Title = "Load Sound Config",
    Callback = function()
        local selected = SoundDropdown.Value
        local path = SavedSoundConfigs[selected]
        if path and isfile(path) then
            local raw = readfile(path)
            local parsed = HttpService:JSONDecode(raw)
            if parsed then
                Sound_Config = parsed
                SoundInput:SetValue(parsed.SoundID or "")
                Fluent:Notify({ Title = "Sound Config Loaded", Content = "Loaded " .. selected .. "!", Duration = 3 })
            end
        end
    end
})

Tabs.Sounds:AddButton({
    Title = "Delete Sound Config",
    Callback = function()
        local selected = SoundDropdown.Value
        local path = SavedSoundConfigs[selected]
        if path and isfile(path) then
            delfile(path)
            Fluent:Notify({ Title = "Sound Config Deleted", Content = "Deleted " .. selected .. "!", Duration = 3 })
            SoundDropdown:SetValues(refreshSoundConfigList())
        end
    end
})


-- ================================================================
-- 7. SPECTATE SYSTEM MODULE
-- ================================================================

local Spectate_Config = {
    Enabled = false,
    SelectedPlayer = nil
}

local function getPlayerListNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(names, p.Name)
        end
    end
    if #names == 0 then table.insert(names, "None") end
    return names
end

local function stopSpectating()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        Camera.CameraSubject = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    end
end

local function startSpectating(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local hum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        Camera.CameraSubject = hum
    end
end

-- Spectate UI Elements
Tabs.Spectate:AddSection("Player Camera Spectator")

local SpectatePlayerDropdown = Tabs.Spectate:AddDropdown("SpectatePlayerSelector", {
    Title = "Select Player",
    Values = getPlayerListNames(),
    Default = getPlayerListNames()[1] or "None",
    Callback = function(Value)
        Spectate_Config.SelectedPlayer = Players:FindFirstChild(Value)
        if Spectate_Config.Enabled and Spectate_Config.SelectedPlayer then
            startSpectating(Spectate_Config.SelectedPlayer)
        end
    end
})

local SpectateToggle = Tabs.Spectate:AddToggle("SpectateToggle", { Title = "Enable Spectate", Default = false })
SpectateToggle:OnChanged(function(Value)
    Spectate_Config.Enabled = Value
    if Value then
        if Spectate_Config.SelectedPlayer then
            startSpectating(Spectate_Config.SelectedPlayer)
        else
            Fluent:Notify({ Title = "Spectate", Content = "Please select a valid player first.", Duration = 3 })
            SpectateToggle:SetValue(false)
        end
    else
        stopSpectating()
    end
end)

Tabs.Spectate:AddButton({
    Title = "Refresh Player List",
    Callback = function()
        SpectatePlayerDropdown:SetValues(getPlayerListNames())
        Fluent:Notify({ Title = "Spectate", Content = "Player list refreshed!", Duration = 2 })
    end
})

-- Handle Player Join/Leave
Players.PlayerAdded:Connect(function()
    SpectatePlayerDropdown:SetValues(getPlayerListNames())
end)

Players.PlayerRemoving:Connect(function(player)
    if Spectate_Config.SelectedPlayer == player then
        stopSpectating()
        Spectate_Config.Enabled = false
        SpectateToggle:SetValue(false)
        Fluent:Notify({ Title = "Spectate", Content = "Target player left the game.", Duration = 3 })
    end
    SpectatePlayerDropdown:SetValues(getPlayerListNames())
end)


-- ================================================================
-- 8. SETTINGS & INTERFACE MANAGER
-- ================================================================

Tabs.Settings:AddSection("Menu & Keybinds")

Tabs.Settings:AddKeybind("MenuToggleKey", {
    Title = "Toggle Menu Keybind",
    Mode = "Toggle",
    Default = "LeftControl",
    Callback = function(Value)
        Window:Minimize()
    end
})

-- Finish Initialization
Window:SelectTab(1)

Fluent:Notify({
    Title = "Gradient Hub Visuals",
    Content = "Successfully loaded Gradient Visuals & Settings script!",
    Duration = 5
})

print("[Gradient Hub] Visuals & Settings script loaded successfully.")

-- register window for global gradient styling (idempotent for shared window)
_G.GradientWindows = _G.GradientWindows or {}
local _alreadyRegistered = false
for _idx, _win in ipairs(_G.GradientWindows) do
    if _win == Window then
        _alreadyRegistered = true
        break
    end
end
if not _alreadyRegistered then
    table.insert(_G.GradientWindows, Window)
end

end)
print('[Gradient] OK: ftap_mercury_visuals.luau')
task.wait(0.1)
-- END MODULE: ftap_mercury_visuals.luau

-- BEG MODULE: ftap_modules.luau
pcall(function()
--[[
    ================================================================
    Gradient Hub Modules - Local Player & Protection Luau Script
    Target Game: Fling Things and People (FTAP)
    UI Library: Fluent UI
    File: ftap_modules.luau
    ================================================================
--]]

-- Services Initialization
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Global Safe File IO Wrappers
local writefile = writefile or function() end
local readfile = readfile or function() return "" end
local isfile = isfile or function() return false end
local makefolder = makefolder or function() end
local isfolder = isfolder or function() return false end
local listfiles = listfiles or function() return {} end
local delfile = delfile or function() end

-- Ensure Folder Structure
if not isfolder("GradientFTAP") then pcall(makefolder, "GradientFTAP") end

-- Shared window created by main.luau (one window for all modules)
local Fluent = _G.GradientFluent
local Window = _G.GradientWindow
if not Fluent or not Window then
    Fluent = (function()
        local ok, lib = pcall(function()
            return loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
        end)
        if ok and lib then return lib end
        local ok2, lib2 = pcall(function()
            return loadstring(game:HttpGet("https://raw.githubusercontent.com/disco0001/Fluent/main/main.lua"))()
        end)
        return (ok2 and lib2) or error("[Gradient] Failed to load Fluent UI library.")
    end)()
    local okW, win = pcall(Fluent.CreateWindow, Fluent, {
        Title = "Gradient Hub | FTAP",
        SubTitle = "by keksup22",
        TabWidth = 160,
        Size = UDim2.fromOffset(640, 460),
        Acrylic = true,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.LeftControl
    })
    Window = (okW and type(win) == "table" and type(win.AddTab) == "function") and win or nil
    if not Window then
        print("[Gradient] Fallback window creation failed.")
    end
    _G.GradientFluent = Fluent
    _G.GradientWindow = Window
end

if type(Fluent) ~= "table" or type(Window) ~= "table" or type(Window.AddTab) ~= "function" then
    print("[Gradient] Skip module: Fluent UI unavailable")
    return
end

-- Interface Tabs (mapped onto shared 4-tab layout)
local Tabs = {
    LocalPlayer = _G.GradientTabs and _G.GradientTabs.Movement or Window:AddTab({ Title = "Movement", Icon = "user" }),
    Protection = _G.GradientTabs and _G.GradientTabs.Protections or Window:AddTab({ Title = "Protections", Icon = "shield" }),
    Settings = _G.GradientTabs and _G.GradientTabs.Settings or Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- ================================================================
-- SAFE FTAP REMOTE HELPERS (paths pin-pointed to real game remotes)
-- ================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getRemote(folder, name)
    local holder = ReplicatedStorage:FindFirstChild(folder)
    if not holder then return nil end
    local r = holder:FindFirstChild(name)
    if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then return r end
    return nil
end

local function fireRemote(folder, name, ...)
    local args = { ... }
    for _, arg in ipairs(args) do
        if arg == nil then return end
    end
    pcall(function()
        local r = getRemote(folder, name)
        if not r then return end
        if r:IsA("RemoteEvent") then
            r:FireServer(unpack(args))
        else
            r:InvokeServer(unpack(args))
        end
    end)
end

-- Throttle helper: runs heavy work at most once per interval, wrapped in pcall
local function makeThrottled(intervalSec)
    local last = 0
    return function(func)
        local now = os.clock()
        if now - last < intervalSec then return end
        last = now
        pcall(func)
    end
end

-- Safe Helper Functions
local function getRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function isBasePart(obj)
    return obj and typeof(obj) == "Instance" and obj:IsA("BasePart")
end

local function safeSetLinearVelocity(part, velocity)
    if not isBasePart(part) then return false end
    if typeof(velocity) ~= "Vector3" then return false end
    if part.Anchored then return false end
    pcall(function()
        part.AssemblyLinearVelocity = velocity
    end)
    return true
end

local function safeSetAngularVelocity(part, velocity)
    if not isBasePart(part) then return false end
    if typeof(velocity) ~= "Vector3" then return false end
    if part.Anchored then return false end
    pcall(function()
        part.AssemblyAngularVelocity = velocity
    end)
    return true
end

local function safeSetCanCollide(part, value)
    if not isBasePart(part) then return false end
    pcall(function()
        part.CanCollide = not not value
    end)
    return true
end

local function safeSetAnchored(part, value)
    if not isBasePart(part) then return false end
    pcall(function()
        part.Anchored = not not value
    end)
    return true
end

-- Client-side network ownership helpers (guarded: SetNetworkOwner may be
-- rejected / unavailable on some executors, so we pcall + typeof-check it).
local function safeRequestNetworkOwnership(part)
    if not isBasePart(part) or part.Anchored then return false end
    pcall(function()
        if typeof(part.SetNetworkOwner) == "function" then
            part:SetNetworkOwner(LocalPlayer)
        end
    end)
    return true
end

local function safeReturnNetworkOwnership(part)
    if not isBasePart(part) or part.Anchored then return false end
    pcall(function()
        if typeof(part.SetNetworkOwner) == "function" then
            part:SetNetworkOwner(nil)
        end
    end)
    return true
end

local function safeGetAttachment0(inst)
    if not inst or not inst.Parent or not isBasePart(inst.Parent) then return nil end
    local att = inst:FindFirstChildOfClass("Attachment")
    if not att then
        att = Instance.new("Attachment")
        att.Name = "PhysicsHelperAttachment"
        att.Parent = inst.Parent
    end
    return att
end

local function ensureAttachments(part)
    if not isBasePart(part) then return nil, nil end
    local att0 = part:FindFirstChild("PhysicsAlignAtt0")
    if not att0 then
        att0 = Instance.new("Attachment")
        att0.Name = "PhysicsAlignAtt0"
        att0.Parent = part
    end
    local att1 = part:FindFirstChild("PhysicsAlignAtt1")
    if not att1 then
        att1 = Instance.new("Attachment")
        att1.Name = "PhysicsAlignAtt1"
        att1.Parent = part
    end
    return att0, att1
end

-- True while FTAP's RagdollPlayerCharacter / GrabbingScript control the body.
-- While ragdolled we must NOT write CFrame, velocities or Humanoid params.
local function isRagdolled()
    local hum = getHumanoid()
    if not hum then return false end
    local st = hum:GetState()
    return st == Enum.HumanoidStateType.Ragdoll
        or st == Enum.HumanoidStateType.FallingDown
        or hum.Sit == true
end


-- ================================================================
-- TAB 1: LOCAL PLAYER MODULE
-- ================================================================

local LP_Config = {
    -- Camera
    ThirdPerson = false,
    FOV = 70,

    -- Other Features
    AntiAFK = true,
    LockPosition = false,
    LockedCFrame = nil,
    ShiftLock = false,
    Desync = false,

    -- Movement - Teleport
    LoopTeleport = false,
    TeleportLocation = "Spawn",

    -- Movement - Speed
    SpeedControl = 16,
    EnableSpeed = false,

    -- Movement - Other
    JumpPower = 50,
    EnableJumpPower = false,
    InfiniteJump = false,
    Noclip = false,
    WaterWalk = false,

    -- Movement - Fly & Vehicle
    VehicleFly = false,
    FlySpeed = 5
}

-- Known Teleport Locations in FTAP Map
local TeleportLocations = {
    ["Spawn"] = Vector3.new(0, 10, 0),
    ["Void"] = Vector3.new(0, -200, 0),
    ["Plots"] = Vector3.new(120, 5, -80),
    ["Main Island"] = Vector3.new(0, 15, 100),
    ["Tree"] = Vector3.new(-50, 40, -120),
    ["House Area"] = Vector3.new(150, 10, 150),
    ["Tower"] = Vector3.new(-100, 80, 100)
}

-- 1. Camera System
task.spawn(function()
    while true do
        task.wait(0.1)
        pcall(function()
        -- FOV Update
        if Camera and Camera.FieldOfView ~= LP_Config.FOV then
            Camera.FieldOfView = LP_Config.FOV
        end

        -- Third Person Enforcer
        if LP_Config.ThirdPerson and LocalPlayer.CameraMinZoomDistance ~= 12 then
            LocalPlayer.CameraMinZoomDistance = 12
            LocalPlayer.CameraMaxZoomDistance = 128
        elseif not LP_Config.ThirdPerson and LocalPlayer.CameraMinZoomDistance == 12 then
            LocalPlayer.CameraMinZoomDistance = 0.5
            LocalPlayer.CameraMaxZoomDistance = 128
        end
    end)
    end
end)

-- 2. Anti AFK
LocalPlayer.Idled:Connect(function()
    if LP_Config.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- 3. Lock Position & Desync Loop
local lockHeartbeatTick = makeThrottled(0.1)
task.spawn(function()
    while true do
        task.wait(0.1)
        lockHeartbeatTick(function()
        local root = getRoot()
        if not root then return end

        -- Lock Position (skipped while ragdolled by FTAP)
        if LP_Config.LockPosition and not isRagdolled() then
            if not LP_Config.LockedCFrame then
                LP_Config.LockedCFrame = root.CFrame
            end
            if isBasePart(root) then
                root.CFrame = LP_Config.LockedCFrame
            end
        else
            LP_Config.LockedCFrame = nil
        end

        -- Desync (Velocity / CFrame Packet Spoofing) - never while ragdolled
        if LP_Config.Desync and not isRagdolled() and isBasePart(root) and not root.Anchored then
            local oldVelocity = root.AssemblyLinearVelocity
            safeSetLinearVelocity(root, Vector3.new(0, -1000, 0))
            RunService.RenderStepped:Wait()
            if isBasePart(root) then
                safeSetLinearVelocity(root, oldVelocity)
            end
        end
    end)
    end
end)

-- 4. Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if LP_Config.InfiniteJump and not isRagdolled() then
        local hum = getHumanoid()
        if hum then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
        end
    end
end)

-- 5. Noclip & Speed & WaterWalk Loop
local WaterPlatform = nil

local steppedTick = makeThrottled(0.1)
task.spawn(function()
    while true do
        task.wait(0.1)
        steppedTick(function()
        local char = LocalPlayer.Character
        local root = getRoot()
        local hum = getHumanoid()

        if not char or not root or not hum then return end

        -- Noclip
        if LP_Config.Noclip then
            for _, part in ipairs(char:GetDescendants()) do
                if isBasePart(part) and part.CanCollide then
                    safeSetCanCollide(part, false)
                end
            end
        end

        -- Speed Control (never force WalkSpeed while ragdolled by FTAP)
        if LP_Config.EnableSpeed and not isRagdolled() then
            pcall(function() hum.WalkSpeed = LP_Config.SpeedControl end)
        end

        -- Jump Power / Height (only when user explicitly enables it AND the
        -- body is not under FTAP's RagdollPlayerCharacter control).
        -- While disabled we never write Humanoid params, so the game's own
        -- custom jump physics (TouchJump / RagdollPlayerCharacter) stay intact.
        if LP_Config.EnableJumpPower and not isRagdolled() then
            pcall(function()
                hum.UseJumpPower = true
                hum.JumpPower = LP_Config.JumpPower
            end)
        end

        -- Water Walk Platform Logic
        if LP_Config.WaterWalk then
            if not WaterPlatform or not WaterPlatform.Parent then
                WaterPlatform = Instance.new("Part")
                WaterPlatform.Name = "FTAP_WaterPlatform"
                WaterPlatform.Size = Vector3.new(12, 1, 12)
                safeSetAnchored(WaterPlatform, true)
                WaterPlatform.Transparency = 1
                WaterPlatform.CanCollide = true
                WaterPlatform.CastShadow = false
                WaterPlatform.Parent = Workspace
            end
            WaterPlatform.CFrame = CFrame.new(root.Position.X, 2.5, root.Position.Z)
        else
            if WaterPlatform then
                pcall(function() WaterPlatform:Destroy() end)
                WaterPlatform = nil
            end
        end
    end)
    end
end)

-- 6. Loop Teleport
task.spawn(function()
    while task.wait(0.5) do
        if LP_Config.LoopTeleport then
            local targetPos = TeleportLocations[LP_Config.TeleportLocation]
            local root = getRoot()
            if targetPos and root and isBasePart(root) and not isRagdolled() then
                pcall(function() root.CFrame = CFrame.new(targetPos) end)
            end
        end
    end
end)

-- Teleport to Mouse Helper
local function teleportToMouse()
    local mouse = LocalPlayer:GetMouse()
    local root = getRoot()
    if mouse and mouse.Hit and root and isBasePart(root) and not isRagdolled() then
        pcall(function() root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0)) end)
        Fluent:Notify({ Title = "Teleport", Content = "Teleported to mouse position!", Duration = 2 })
    end
end

-- Vehicle / Player Fly System (modernized: AlignOrientation + LinearVelocity)
local FlyAlignOrientation, FlyLinearVelocity
local FlyAtt0, FlyAtt1
local flyRenderTick = makeThrottled(0.1)
task.spawn(function()
    while true do
        task.wait(0.1)
        flyRenderTick(function()
        local root = getRoot()
        if not root or not isBasePart(root) then return end

        if LP_Config.VehicleFly and not isRagdolled() and not root.Anchored then
            -- Ensure attachments exist for modern constraints
            if not FlyAtt0 or not FlyAtt0.Parent then
                FlyAtt0, FlyAtt1 = ensureAttachments(root)
            end

            -- Modern AlignOrientation (replaces BodyGyro)
            if not FlyAlignOrientation or not FlyAlignOrientation.Parent then
                FlyAlignOrientation = Instance.new("AlignOrientation")
                FlyAlignOrientation.Name = "FTAP_FlyAlignOrientation"
                FlyAlignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
                FlyAlignOrientation.Attachment0 = FlyAtt0
                FlyAlignOrientation.MaxTorque = 9e9
                FlyAlignOrientation.Responsiveness = 200
                FlyAlignOrientation.RigidityEnabled = false
                FlyAlignOrientation.CFrame = root.CFrame
                FlyAlignOrientation.Parent = root
            end

            -- Modern LinearVelocity (replaces BodyVelocity)
            if not FlyLinearVelocity or not FlyLinearVelocity.Parent then
                FlyLinearVelocity = Instance.new("LinearVelocity")
                FlyLinearVelocity.Name = "FTAP_FlyLinearVelocity"
                FlyLinearVelocity.VelocityRelativeTo = Enum.ActuatorRelativeTo.World
                FlyLinearVelocity.Attachment0 = FlyAtt0
                FlyLinearVelocity.MaxForce = 9e9
                FlyLinearVelocity.VectorVelocity = Vector3.new(0, 0, 0)
                FlyLinearVelocity.Parent = root
            end

            -- Update orientation to match camera
            if FlyAlignOrientation and FlyAtt0 then
                FlyAlignOrientation.CFrame = Camera.CFrame
            end

            local moveDir = Vector3.new()

            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveDir = moveDir + Camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveDir = moveDir - Camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveDir = moveDir - Camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveDir = moveDir + Camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveDir = moveDir + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                moveDir = moveDir - Vector3.new(0, 1, 0)
            end

            if FlyLinearVelocity then
                if moveDir.Magnitude > 0.001 then
                    FlyLinearVelocity.VectorVelocity = moveDir.Unit * (LP_Config.FlySpeed * 10)
                else
                    FlyLinearVelocity.VectorVelocity = Vector3.new(0, 0, 0)
                end
            end
        else
            -- Cleanup modern constraints when fly is off
            if FlyAlignOrientation then
                pcall(function() FlyAlignOrientation:Destroy() end)
                FlyAlignOrientation = nil
            end
            if FlyLinearVelocity then
                pcall(function() FlyLinearVelocity:Destroy() end)
                FlyLinearVelocity = nil
            end
            if FlyAtt0 then
                pcall(function() FlyAtt0:Destroy() end)
                FlyAtt0 = nil
            end
            if FlyAtt1 then
                pcall(function() FlyAtt1:Destroy() end)
                FlyAtt1 = nil
            end
        end
    end)
    end
end)

-- Sit on Blobman Function
local function sitOnBlobman()
    local root = getRoot()
    if not root then return end

    local nearestBlob = nil
    local nearestDist = math.huge

    for _, inst in ipairs(Workspace:GetDescendants()) do
        local name = string.lower(inst.Name)
        if (string.find(name, "blobman") or string.find(name, "blob")) and (inst:IsA("Model") or inst:IsA("BasePart")) then
            local pos = inst:IsA("Model") and inst:GetPivot().Position or inst.Position
            local dist = (root.Position - pos).Magnitude
            if dist < nearestDist then
                nearestDist = dist
                nearestBlob = inst
            end
        end
    end

    if nearestBlob then
        local targetCF = nearestBlob:IsA("Model") and nearestBlob:GetPivot() or nearestBlob.CFrame
        root.CFrame = targetCF + Vector3.new(0, 2, 0)

        local hum = getHumanoid()
        local seat = nearestBlob:FindFirstChildOfClass("Seat") or nearestBlob:FindFirstChildOfClass("VehicleSeat")
        if hum and seat then
            seat:Sit(hum)
        end
        Fluent:Notify({ Title = "Blobman", Content = "Sat on nearest Blobman!", Duration = 2 })
    else
        Fluent:Notify({ Title = "Blobman", Content = "No Blobman found nearby.", Duration = 2 })
    end
end

-- LOCAL PLAYER UI ELEMENTS
Tabs.LocalPlayer:AddSection("Camera Controls")

local ThirdPersonToggle = Tabs.LocalPlayer:AddToggle("ThirdPersonToggle", { Title = "Third Person", Default = false })
ThirdPersonToggle:OnChanged(function(Value) LP_Config.ThirdPerson = Value end)

Tabs.LocalPlayer:AddSlider("FOVSlider", {
    Title = "Field of View (FOV)",
    Default = 70,
    Min = 30,
    Max = 120,
    Rounding = 0,
    Callback = function(Value) LP_Config.FOV = Value end
})

Tabs.LocalPlayer:AddSection("Other Features & Exploits")

local AntiAFKToggle = Tabs.LocalPlayer:AddToggle("AntiAFKToggle", { Title = "Anti AFK", Default = true })
AntiAFKToggle:OnChanged(function(Value) LP_Config.AntiAFK = Value end)

Tabs.LocalPlayer:AddKeybind("RespawnKey", {
    Title = "Respawn (Kill) Key",
    Mode = "Toggle",
    Default = "Q",
    Callback = function()
        local hum = getHumanoid()
        if hum then hum.Health = 0 end
    end
})

local LockPosToggle = Tabs.LocalPlayer:AddToggle("LockPosToggle", { Title = "Lock Position", Default = false })
LockPosToggle:OnChanged(function(Value) LP_Config.LockPosition = Value end)

local ShiftLockToggle = Tabs.LocalPlayer:AddToggle("ShiftLockToggle", { Title = "Shift Lock (Mouse Look)", Default = false })
ShiftLockToggle:OnChanged(function(Value)
    LP_Config.ShiftLock = Value
    pcall(function()
        UserSettings().GameSettings.RotationType = Value and Enum.RotationType.CameraRelative or Enum.RotationType.MovementRelative
    end)
end)

Tabs.LocalPlayer:AddButton({
    Title = "Launch AquaMatrix",
    Description = "Executes AquaMatrix script suite",
    Callback = function()
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/AquaMatrix/Script/main/main.lua"))()
        end)
        Fluent:Notify({ Title = "AquaMatrix", Content = "AquaMatrix initialization executed!", Duration = 3 })
    end
})

local DesyncToggle = Tabs.Protection:AddToggle("DesyncToggle", { Title = "Desync (Packet / CFrame)", Default = false })
DesyncToggle:OnChanged(function(Value) LP_Config.Desync = Value end)

Tabs.LocalPlayer:AddSection("Teleport Group")

local LoopTPToggle = Tabs.LocalPlayer:AddToggle("LoopTPToggle", { Title = "Loop Teleport", Default = false })
LoopTPToggle:OnChanged(function(Value) LP_Config.LoopTeleport = Value end)

local TPLocationDropdown = Tabs.LocalPlayer:AddDropdown("TPLocationDropdown", {
    Title = "Teleport Location",
    Values = {"Spawn", "Void", "Plots", "Main Island", "Tree", "House Area", "Tower"},
    Default = "Spawn",
    Callback = function(Value) LP_Config.TeleportLocation = Value end
})

Tabs.LocalPlayer:AddKeybind("TPOnceKey", {
    Title = "Teleport Once Key",
    Mode = "Toggle",
    Default = "P",
    Callback = function()
        local targetPos = TeleportLocations[LP_Config.TeleportLocation]
        local root = getRoot()
        if targetPos and root and not isRagdolled() then
            root.CFrame = CFrame.new(targetPos)
            Fluent:Notify({ Title = "Teleport", Content = "Teleported to " .. LP_Config.TeleportLocation, Duration = 2 })
        end
    end
})

Tabs.LocalPlayer:AddKeybind("TPMouseKey", {
    Title = "Teleport to Mouse Key",
    Mode = "Toggle",
    Default = "Z",
    Callback = function()
        teleportToMouse()
    end
})

Tabs.LocalPlayer:AddSection("Speed Controls")

Tabs.LocalPlayer:AddSlider("SpeedSlider", {
    Title = "Speed Control",
    Default = 16,
    Min = 16,
    Max = 150,
    Rounding = 0,
    Callback = function(Value) LP_Config.SpeedControl = Value end
})

local EnableSpeedToggle = Tabs.LocalPlayer:AddToggle("EnableSpeedToggle", { Title = "Enable Speed", Default = false })
EnableSpeedToggle:OnChanged(function(Value) LP_Config.EnableSpeed = Value end)

Tabs.LocalPlayer:AddKeybind("SpeedToggleKey", {
    Title = "Speed Toggle Key",
    Mode = "Toggle",
    Default = "Y",
    Callback = function()
        EnableSpeedToggle:SetValue(not EnableSpeedToggle.Value)
    end
})

Tabs.LocalPlayer:AddSection("Other Movement & Physics")

Tabs.LocalPlayer:AddSlider("JumpPowerSlider", {
    Title = "Jump Power",
    Default = 50,
    Min = 50,
    Max = 300,
    Rounding = 0,
    Callback = function(Value) LP_Config.JumpPower = Value end
})

local EnableJumpPowerToggle = Tabs.LocalPlayer:AddToggle("EnableJumpPowerToggle", { Title = "Enable Jump Power (custom)", Default = false })
EnableJumpPowerToggle:OnChanged(function(Value) LP_Config.EnableJumpPower = Value end)

local InfJumpToggle = Tabs.LocalPlayer:AddToggle("InfJumpToggle", { Title = "Infinite Jump", Default = false })
InfJumpToggle:OnChanged(function(Value) LP_Config.InfiniteJump = Value end)

local NoclipToggle = Tabs.LocalPlayer:AddToggle("NoclipToggle", { Title = "Noclip", Default = false })
NoclipToggle:OnChanged(function(Value) LP_Config.Noclip = Value end)

local WaterWalkToggle = Tabs.LocalPlayer:AddToggle("WaterWalkToggle", { Title = "Water Walk", Default = false })
WaterWalkToggle:OnChanged(function(Value) LP_Config.WaterWalk = Value end)

Tabs.LocalPlayer:AddSection("Vehicle / Fly")

Tabs.LocalPlayer:AddKeybind("FlyKey", {
    Title = "Toggle Vehicle Fly",
    Mode = "Toggle",
    Default = "X",
    Callback = function()
        LP_Config.VehicleFly = not LP_Config.VehicleFly
        Fluent:Notify({ Title = "Vehicle Fly", Content = "Fly set to " .. tostring(LP_Config.VehicleFly), Duration = 2 })
    end
})

Tabs.LocalPlayer:AddSlider("FlySpeedSlider", {
    Title = "Fly Speed",
    Default = 5,
    Min = 1,
    Max = 20,
    Rounding = 1,
    Callback = function(Value) LP_Config.FlySpeed = Value end
})

Tabs.LocalPlayer:AddKeybind("SitBlobmanKey", {
    Title = "Sit on Blobman Key",
    Mode = "Toggle",
    Default = "B",
    Callback = function()
        sitOnBlobman()
    end
})


-- ================================================================
-- TAB 2: PROTECTION MODULE (FTAP DEFENSE & EXPLOIT FIXES)
-- ================================================================

local Prot_Config = {
    AntiGrab = false,
    AntiRagdoll = false,
    AntiExplode = false,
    StruggleSpam = false,
    
    AntiKickMethod = "House Shuriken",
    ApplyAntiKick = false,

    GucciMethod = "Blobman Shield",
    ApplyGucci = false,

    AutoLineLag = false,
    AntiLineLag = false,

    AntiVoid = false,
    VoidThreshold = -100,

    AntiBarrier = false,
    AntiBurn = false,
    AntiPaint = false,

    SelectedItem = "FoodBread",
    HoldTimeMs = 0.3,
    AntiInputLagItem = false,
    AntiAntiInput = false,
    AntiStickySelf = false,

    CounterMethod = "Ownership Hijack",
    EnableCounterMethod = false,

    AutoBreakPCLD = false,

    AntiGrabBlobHome = false,
    SelfGrabBlob = false,

    SelectedFriend = nil,
    DisableBlobArms = false,
    AntiBlobSitAura = false,

    AntiFling = false,
    FlingSpeedThreshold = 100,
    AntiNetworkOwnership = false,
    RemoveEndGrabEarly = false
}

-- ================================================================
-- EVENT-DRIVEN ANTI-GRAB (no polling, no heavy scans)
-- Listens for NEW joints that FTAP's GrabbingScript welds onto our
-- character and destroys them instantly. Internal joints and any
-- joints fully inside the character are never touched.
-- ================================================================
local FOREIGN_BODY_MOVER_NAMES = {
    "BodyVelocity", "BodyGyro", "BodyPosition", "BodyAngularVelocity",
    "BodyForce", "BodyThrust", "BodyTorque"
}

local function isForeignJoint(child)
    if not child then return false end
    local char = LocalPlayer.Character
    if not char then return false end

    -- BodyMovers attached to our parts are ALWAYS foreign (we never create them)
    if child:IsA("BodyMover") then
        return true
    end
    for _, moverName in ipairs(FOREIGN_BODY_MOVER_NAMES) do
        if child.ClassName == moverName then
            return true
        end
    end

    if not (child:IsA("Weld") or child:IsA("WeldConstraint")
        or child:IsA("RopeConstraint") or child:IsA("AlignPosition")
        or child:IsA("LinearVelocity") or child:IsA("AngularVelocity")
        or child:IsA("AlignOrientation")) then
        return false
    end
    local part0, part1
    if child:IsA("WeldConstraint") or child:IsA("AlignPosition")
        or child:IsA("LinearVelocity") or child:IsA("AngularVelocity")
        or child:IsA("AlignOrientation") then
        part0 = child.Attachment0 and child.Attachment0.Parent
        part1 = child.Attachment1 and child.Attachment1.Parent
    elseif child:IsA("RopeConstraint") then
        part0 = child.Attachment0 and child.Attachment0.Parent
        part1 = child.Attachment1 and child.Attachment1.Parent
    else
        part0, part1 = child.Part0, child.Part1
    end
    return part0 ~= nil and part1 ~= nil and (part0:IsDescendantOf(char) ~= part1:IsDescendantOf(char))
end

local function breakForeignJoint(child)
    pcall(function()
        if isForeignJoint(child) then
            child:Destroy()
        end
    end)
end

-- One-time sweep of everything already on the character (called on toggle-on
-- and on respawn; cheap because it only runs when enabled).
local function scanAndBreakForeignJoints()
    local char = LocalPlayer.Character
    if not char then return end
    for _, child in ipairs(char:GetDescendants()) do
        breakForeignJoint(child)
    end
end

local antiGrabConnections = {}
local function attachAntiGrabListeners()
    for _, conn in ipairs(antiGrabConnections) do
        pcall(function() conn:Disconnect() end)
    end
    antiGrabConnections = {}
    local char = LocalPlayer.Character
    if not char then return end
    table.insert(antiGrabConnections, char.ChildAdded:Connect(breakForeignJoint))
    table.insert(antiGrabConnections, char.DescendantAdded:Connect(breakForeignJoint))
end

LocalPlayer.CharacterAdded:Connect(function()
    if Prot_Config.AntiGrab then
        pcall(attachAntiGrabListeners)
        pcall(scanAndBreakForeignJoints)
    end
end)

-- Remove EndGrabEarly [Bypass] - swallows the GrabEvents/EndGrabEarly
-- remote so the game can't force-release our grabs early. Uses a guarded
-- __namecall hook (executor-optional: silently no-ops if unsupported).
local endGrabEarlyRemote = nil
local endGrabEarlyOldNamecall = nil
local endGrabEarlyHooked = false

local function getEndGrabEarlyRemote()
    local holder = ReplicatedStorage:FindFirstChild("GrabEvents")
    if not holder then return nil end
    local r = holder:FindFirstChild("EndGrabEarly")
    if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then return r end
    return nil
end

local function installEndGrabEarlyHook()
    if endGrabEarlyHooked then return end
    pcall(function()
        endGrabEarlyRemote = getEndGrabEarlyRemote()
        if not endGrabEarlyRemote then return end
        local mt = getrawmetatable(game)
        if not mt then return end
        endGrabEarlyOldNamecall = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(...)
            local self = ...
            local method = getnamecallmethod()
            if self == endGrabEarlyRemote and (method == "FireServer" or method == "InvokeServer") then
                return nil
            end
            return endGrabEarlyOldNamecall(...)
        end)
        setreadonly(mt, true)
        endGrabEarlyHooked = true
    end)
end

local function removeEndGrabEarlyHook()
    if not endGrabEarlyHooked then return end
    pcall(function()
        local mt = getrawmetatable(game)
        if mt and endGrabEarlyOldNamecall then
            setreadonly(mt, false)
            mt.__namecall = endGrabEarlyOldNamecall
            setreadonly(mt, true)
        end
    end)
    endGrabEarlyHooked = false
    endGrabEarlyOldNamecall = nil
    endGrabEarlyRemote = nil
end

-- Retry loop: hooks the remote as soon as it exists in ReplicatedStorage
task.spawn(function()
    while true do
        task.wait(1)
        if Prot_Config.RemoveEndGrabEarly then
            installEndGrabEarlyHook()
        end
    end
end)

-- 1. Anti Grab, Ragdoll, Explode Loop
local antiBlobSitLastScan = 0
local antiGrabTick = makeThrottled(0.1)
task.spawn(function()
    while true do
        task.wait(0.1)
        antiGrabTick(function()
        local char = LocalPlayer.Character
        local root = getRoot()
        local hum = getHumanoid()

        if not char or not root then return end

        -- Anti Grab is EVENT-DRIVEN (listeners above). A slow 0.5s sweep
        -- (separate loop below) is the only fallback — never every tick.
        -- Anti Ragdoll
        if Prot_Config.AntiRagdoll and hum then
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                if hum:GetState() == Enum.HumanoidStateType.Ragdoll or hum:GetState() == Enum.HumanoidStateType.FallingDown then
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                end
            end)
        end

        -- Anti Explode Physics Fix (only when WE own the physics; never
        -- writes velocity while FTAP's RagdollPlayerCharacter is active)
        if Prot_Config.AntiExplode and not isRagdolled() and isBasePart(root) and not root.Anchored then
            safeSetAngularVelocity(root, Vector3.new(0, 0, 0))
            local vel = root.AssemblyLinearVelocity
            if typeof(vel) == "Vector3" and vel.Magnitude > 250 then
                safeSetLinearVelocity(root, Vector3.new(0, 0, 0))
            end
        end

        -- Anti Void Teleport (restore ONLY if we truly fell below the void
        -- line AND the body is not ragdolled by another player / RagdollPC)
        if Prot_Config.AntiVoid and not isRagdolled() and isBasePart(root) and root.Position.Y < Prot_Config.VoidThreshold then
            pcall(function() root.CFrame = CFrame.new(TeleportLocations["Spawn"]) end)
            Fluent:Notify({ Title = "Anti Void", Content = "Saved from falling into the void!", Duration = 3 })
        end

        -- Anti Sticky Self
        if Prot_Config.AntiStickySelf then
            for _, obj in ipairs(char:GetChildren()) do
                if obj:IsA("TouchTransporter") or (isBasePart(obj) and obj.Name == "StickyPart") then
                    pcall(function() obj:Destroy() end)
                end
            end
        end

        -- Anti Blob Sit Aura (heavy scan throttled to 1x/s)
        if Prot_Config.AntiBlobSitAura then
            local now = os.clock()
            if now - antiBlobSitLastScan >= 1 then
                antiBlobSitLastScan = now
                pcall(function()
                    for _, inst in ipairs(Workspace:GetDescendants()) do
                        if string.find(string.lower(inst.Name), "blob") and isBasePart(inst) then
                            local dist = (root.Position - inst.Position).Magnitude
                            if dist < 8 then
                                safeRequestNetworkOwnership(inst)
                                safeSetLinearVelocity(inst, (inst.Position - root.Position).Unit * 100)
                            end
                        end
                    end
                end)
            end
        end
    end)
    end
end)

-- ================================================================
-- CLIENT PHYSICS WATCHDOG (RunService.Heartbeat)
--   * Anti-Fling: if HumanoidRootPart speed spikes past the cap
--     (150 studs/s) we instantly zero ALL momentum client-side.
--   * Blob Kick: pushes nearby blob parts away with pure client
--     velocity writes (no server calls).
-- ================================================================
local PHYSICS_WATCHDOG_MAX_SPEED = 150
local blobKickLastScan = 0
RunService.Heartbeat:Connect(function()
    pcall(function()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root or not isBasePart(root) or root.Anchored or isRagdolled() then return end

        if Prot_Config.AntiFling then
            local vel = root.AssemblyLinearVelocity
            if typeof(vel) == "Vector3" and vel.Magnitude > PHYSICS_WATCHDOG_MAX_SPEED then
                safeSetLinearVelocity(root, Vector3.zero)
                safeSetAngularVelocity(root, Vector3.zero)
            end
        end

        if Prot_Config.AntiBlobSitAura then
            local now = os.clock()
            if now - blobKickLastScan >= 1 then
                blobKickLastScan = now
                for _, inst in ipairs(Workspace:GetDescendants()) do
                    if string.find(string.lower(inst.Name), "blob") and isBasePart(inst) and not inst.Anchored then
                        local diff = inst.Position - root.Position
                        local dist = diff.Magnitude
                        if dist > 0.01 and dist < 12 then
                            safeSetLinearVelocity(inst, diff.Unit * 100)
                        end
                    end
                end
            end
        end
    end)
end)

-- Slow 0.5s fallback sweep for Anti-Grab (event listeners do the real work;
-- this only catches joints that slipped past the instant handlers).
task.spawn(function()
    while task.wait(0.5) do
        if Prot_Config.AntiGrab then
            pcall(scanAndBreakForeignJoints)
        end
    end
end)

-- 2. Anti Network Struggle Spam
task.spawn(function()
    while task.wait(0.1) do
        if Prot_Config.StruggleSpam then
            pcall(function()
                -- Fires FTAP struggle remote / VirtualUser spacebar tap
                VirtualUser:TypeKey(0x20)
                fireRemote("CharacterEvents", "Struggle")
                fireRemote("CharacterEvents", "ChatTyping")
            end)
        end
    end
end)

-- 3. Line-Lag & Rope Cleanup (heavy Workspace scan throttled to 1x/s)
local lineLagScanCooldown = 0
local function cleanLineLag()
    local now = os.clock()
    if now - lineLagScanCooldown < 1 then return end
    lineLagScanCooldown = now
    pcall(function()
        for _, inst in ipairs(Workspace:GetDescendants()) do
            if inst:IsA("RopeConstraint") or inst:IsA("Beam") or inst:IsA("Trail") then
                local tooLong = false
                if inst:IsA("RopeConstraint") or inst:IsA("SpringConstraint") then
                    pcall(function()
                        tooLong = inst.Length > 200
                    end)
                end
                if inst.Name == "LagRope" or tooLong then
                    inst:Destroy()
                end
            end
        end
    end)
end

local lineLagRenderTick = makeThrottled(0.1)
task.spawn(function()
    while true do
        task.wait(0.1)
        lineLagRenderTick(function()
        if Prot_Config.AntiLineLag or Prot_Config.AutoLineLag then
            cleanLineLag()
        end
    end)
    end
end)

-- 4. Anti Barrier (Off Plot Collisions) - heavy scan throttled to 1x/s
local barrierScanCooldown = 0
local antiBarrierTick = makeThrottled(0.1)
task.spawn(function()
    while true do
        task.wait(0.1)
        antiBarrierTick(function()
        if Prot_Config.AntiBarrier then
            local now = os.clock()
            if now - barrierScanCooldown >= 1 then
                barrierScanCooldown = now
                for _, inst in ipairs(Workspace:GetDescendants()) do
                    if string.find(string.lower(inst.Name), "barrier") or string.find(string.lower(inst.Name), "plotborder") then
                        if isBasePart(inst) then
                            safeRequestNetworkOwnership(inst)
                            safeSetCanCollide(inst, false)
                        end
                    end
                end
            end
        end
    end)
    end
end)

-- 5. Anti Burn & Anti Paint (event-driven via DescendantAdded is preferred;
-- this 0.5s sweep is only a fallback for things added before listeners attached)
local antiBurnTick = makeThrottled(0.5)
task.spawn(function()
    while true do
        task.wait(0.5)
        antiBurnTick(function()
        local char = LocalPlayer.Character
        if not char then return end

        if Prot_Config.AntiBurn then
            for _, child in ipairs(char:GetDescendants()) do
                if child:IsA("Fire") or child:IsA("Smoke") or child.Name == "BurnTag" then
                    pcall(function() child:Destroy() end)
                end
            end
        end

        if Prot_Config.AntiPaint then
            for _, child in ipairs(char:GetDescendants()) do
                if child:IsA("Decal") or child:IsA("Texture") then
                    if child.Name == "PaintDecal" or string.find(string.lower(child.Name), "paint") then
                        pcall(function() child:Destroy() end)
                    end
                end
            end
        end
    end)
    end
end)

-- 6. Disable Blob Arms - heavy scan throttled to 1x/s
local disableBlobScanCooldown = 0
local disableBlobTick = makeThrottled(0.1)
task.spawn(function()
    while true do
        task.wait(0.1)
        disableBlobTick(function()
        if Prot_Config.DisableBlobArms then
            local now = os.clock()
            if now - disableBlobScanCooldown >= 1 then
                disableBlobScanCooldown = now
                for _, inst in ipairs(Workspace:GetDescendants()) do
                    if string.find(string.lower(inst.Name), "blob") and inst:IsA("Model") then
                        local lArm = inst:FindFirstChild("LeftArm") or inst:FindFirstChild("Left UpperArm")
                        local rArm = inst:FindFirstChild("RightArm") or inst:FindFirstChild("Right UpperArm")
                        if isBasePart(lArm) then
                            safeRequestNetworkOwnership(lArm)
                            safeSetCanCollide(lArm, false)
                        end
                        if isBasePart(rArm) then
                            safeRequestNetworkOwnership(rArm)
                            safeSetCanCollide(rArm, false)
                        end
                    end
                end
            end
        end
    end)
    end
end)

-- 7. Auto Break PCLD
task.spawn(function()
    while task.wait(1) do
        if Prot_Config.AutoBreakPCLD then
            for _, inst in ipairs(Workspace:GetDescendants()) do
                local name = string.lower(inst.Name)
                if string.find(name, "pcld") or string.find(name, "antifling") then
                    if isBasePart(inst) or inst:IsA("Model") then
                        pcall(function() inst:Destroy() end)
                    end
                end
            end
        end
    end
end)

-- 8. Anti Fling [Teleport Back] - stores a safe CFrame while grounded;
-- the instant we get flung (velocity spike above threshold) we snap back
-- to the last safe spot and zero all momentum.
local antiFlingSafeCFrame = nil
task.spawn(function()
    while true do
        task.wait(0.2)
        if Prot_Config.AntiFling then
            pcall(function()
                local root = getRoot()
                if not root or not isBasePart(root) or isRagdolled() then return end
                local vel = root.AssemblyLinearVelocity
                if typeof(vel) ~= "Vector3" then return end
                if vel.Magnitude < Prot_Config.FlingSpeedThreshold then
                    antiFlingSafeCFrame = root.CFrame
                elseif antiFlingSafeCFrame then
                    local hum = getHumanoid()
                    root.CFrame = antiFlingSafeCFrame
                    safeSetLinearVelocity(root, Vector3.new(0, 0, 0))
                    safeSetAngularVelocity(root, Vector3.new(0, 0, 0))
                    if hum then
                        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
                    end
                end
            end)
        end
    end
end)

-- 9. Anti Network Ownership - intelligently manages network ownership:
--   * Keeps OUR parts owned by server (SetNetworkOwner(nil)) to prevent
--     attackers from holding our parts to fling us
--   * Only touches non-anchored BaseParts, wrapped in pcall
--   * Skips if grabbing someone (grabbed parts must stay under our ownership)
local antiNetOwnerTick = makeThrottled(0.5)
task.spawn(function()
    while true do
        task.wait(0.5)
        antiNetOwnerTick(function()
            if Prot_Config.AntiNetworkOwnership then
                local char = LocalPlayer.Character
                if not char then return end
                for _, part in ipairs(char:GetDescendants()) do
                    if isBasePart(part) and not part.Anchored then
                        safeReturnNetworkOwnership(part)
                    end
                end
            end
        end)
    end
end)

-- Friend List Helper
local function getFriendNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(names, p.Name)
        end
    end
    if #names == 0 then table.insert(names, "None") end
    return names
end

-- PROTECTION UI ELEMENTS
Tabs.Protection:AddSection("Anti-Functions (Core Defense)")

local AntiGrabToggle = Tabs.Protection:AddToggle("AntiGrabToggle", { Title = "Anti [Grab | Ragdoll | Explode]", Default = false })
AntiGrabToggle:OnChanged(function(Value)
    Prot_Config.AntiGrab = Value
    Prot_Config.AntiRagdoll = Value
    Prot_Config.AntiExplode = Value
    if Value then
        pcall(attachAntiGrabListeners)
        pcall(scanAndBreakForeignJoints)
    else
        for _, conn in ipairs(antiGrabConnections) do
            pcall(function() conn:Disconnect() end)
        end
        antiGrabConnections = {}
    end
end)

local StruggleToggle = Tabs.Protection:AddToggle("StruggleToggle", { Title = "Anti Network [Struggle Spam]", Default = false })
StruggleToggle:OnChanged(function(Value) Prot_Config.StruggleSpam = Value end)

Tabs.Protection:AddDropdown("AntiKickDropdown", {
    Title = "Anti-Kick Method",
    Values = {"House Shuriken", "Desync Shield", "BodyVelocity Neutralizer"},
    Default = "House Shuriken",
    Callback = function(Value) Prot_Config.AntiKickMethod = Value end
})

local ApplyAntiKickToggle = Tabs.Protection:AddToggle("ApplyAntiKickToggle", { Title = "Apply Anti-Kick Method", Default = false })
ApplyAntiKickToggle:OnChanged(function(Value) Prot_Config.ApplyAntiKick = Value end)

Tabs.Protection:AddDropdown("GucciMethodDropdown", {
    Title = "Gucci Method",
    Values = {"Blobman Shield", "Plot Guard", "Network Ownership"},
    Default = "Blobman Shield",
    Callback = function(Value) Prot_Config.GucciMethod = Value end
})

local ApplyGucciToggle = Tabs.Protection:AddToggle("ApplyGucciToggle", { Title = "Apply Gucci Method", Default = false })
ApplyGucciToggle:OnChanged(function(Value) Prot_Config.ApplyGucci = Value end)

local AutoLineLagToggle = Tabs.Protection:AddToggle("AutoLineLagToggle", { Title = "Auto Anti [Line-Lag]", Default = false })
AutoLineLagToggle:OnChanged(function(Value) Prot_Config.AutoLineLag = Value end)

local AntiLineLagToggle = Tabs.Protection:AddToggle("AntiLineLagToggle", { Title = "Anti Line-Lag", Default = false })
AntiLineLagToggle:OnChanged(function(Value) Prot_Config.AntiLineLag = Value end)

local AntiVoidToggle = Tabs.Protection:AddToggle("AntiVoidToggle", { Title = "Anti Void", Default = false })
AntiVoidToggle:OnChanged(function(Value) Prot_Config.AntiVoid = Value end)

local AntiBarrierToggle = Tabs.Protection:AddToggle("AntiBarrierToggle", { Title = "Anti Barrier [Off Collision]", Default = false })
AntiBarrierToggle:OnChanged(function(Value) Prot_Config.AntiBarrier = Value end)

local AntiBurnToggle = Tabs.Protection:AddToggle("AntiBurnToggle", { Title = "Anti Burn", Default = false })
AntiBurnToggle:OnChanged(function(Value) Prot_Config.AntiBurn = Value end)

local AntiPaintToggle = Tabs.Protection:AddToggle("AntiPaintToggle", { Title = "Anti Paint", Default = false })
AntiPaintToggle:OnChanged(function(Value) Prot_Config.AntiPaint = Value end)

Tabs.Protection:AddSection("Anti Fling & Ownership")

local AntiFlingToggle = Tabs.Protection:AddToggle("AntiFlingToggle", { Title = "Anti Fling [Teleport Back]", Default = false })
AntiFlingToggle:OnChanged(function(Value) Prot_Config.AntiFling = Value end)

Tabs.Protection:AddSlider("FlingSpeedThresholdSlider", {
    Title = "Fling Speed Threshold",
    Default = 100,
    Min = 40,
    Max = 400,
    Rounding = 0,
    Callback = function(Value) Prot_Config.FlingSpeedThreshold = Value end
})

local AntiNetworkOwnerToggle = Tabs.Protection:AddToggle("AntiNetworkOwnerToggle", { Title = "Anti Network Ownership", Default = false })
AntiNetworkOwnerToggle:OnChanged(function(Value) Prot_Config.AntiNetworkOwnership = Value end)

local RemoveEndGrabEarlyToggle = Tabs.Protection:AddToggle("RemoveEndGrabEarlyToggle", { Title = "Remove EndGrabEarly [Bypass]", Default = false })
RemoveEndGrabEarlyToggle:OnChanged(function(Value)
    Prot_Config.RemoveEndGrabEarly = Value
    if Value then
        installEndGrabEarlyHook()
    else
        removeEndGrabEarlyHook()
    end
end)

Tabs.Protection:AddSection("Item Input Lag & Fixes")

Tabs.Protection:AddDropdown("SelectItemDropdown", {
    Title = "Select [Item]",
    Values = {"FoodBread", "Apple", "Stick", "Bottle", "Bomb"},
    Default = "FoodBread",
    Callback = function(Value) Prot_Config.SelectedItem = Value end
})

Tabs.Protection:AddSlider("HoldTimeSlider", {
    Title = "Hold Time [ms]",
    Default = 0.3,
    Min = 0.1,
    Max = 2.0,
    Rounding = 2,
    Callback = function(Value) Prot_Config.HoldTimeMs = Value end
})

local AntiInputLagItemToggle = Tabs.Protection:AddToggle("AntiInputLagItemToggle", { Title = "Anti Input Lag [Item]", Default = false })
AntiInputLagItemToggle:OnChanged(function(Value) Prot_Config.AntiInputLagItem = Value end)

local AntiAntiInputToggle = Tabs.Protection:AddToggle("AntiAntiInputToggle", { Title = "Anti [Anti-Input]", Default = false })
AntiAntiInputToggle:OnChanged(function(Value) Prot_Config.AntiAntiInput = Value end)

local AntiStickySelfToggle = Tabs.Protection:AddToggle("AntiStickySelfToggle", { Title = "Anti Sticky [Self]", Default = false })
AntiStickySelfToggle:OnChanged(function(Value) Prot_Config.AntiStickySelf = Value end)

Tabs.Protection:AddSection("Counter Attack Method")

Tabs.Protection:AddDropdown("CounterMethodDropdown", {
    Title = "Select Method",
    Values = {"Ownership Hijack", "Fling Repel", "Velocity Reversal"},
    Default = "Ownership Hijack",
    Callback = function(Value) Prot_Config.CounterMethod = Value end
})

local EnableCounterToggle = Tabs.Protection:AddToggle("EnableCounterToggle", { Title = "Enable Counter Method", Default = false })
EnableCounterToggle:OnChanged(function(Value) Prot_Config.EnableCounterMethod = Value end)

Tabs.Protection:AddSection("Break Actions")

local AutoBreakPCLDToggle = Tabs.Protection:AddToggle("AutoBreakPCLDToggle", { Title = "Auto Break PCLD", Default = false })
AutoBreakPCLDToggle:OnChanged(function(Value) Prot_Config.AutoBreakPCLD = Value end)

Tabs.Protection:AddButton({
    Title = "Destroy Train [Break]",
    Description = "Destroys map trains / vehicles locally",
    Callback = function()
        for _, inst in ipairs(Workspace:GetDescendants()) do
            if string.find(string.lower(inst.Name), "train") then
                pcall(function() inst:Destroy() end)
            end
        end
        Fluent:Notify({ Title = "Break", Content = "Train objects destroyed!", Duration = 2 })
    end
})

Tabs.Protection:AddButton({
    Title = "Break Barrier",
    Description = "Removes plot barriers across the map",
    Callback = function()
        for _, inst in ipairs(Workspace:GetDescendants()) do
            if string.find(string.lower(inst.Name), "barrier") then
                pcall(function() inst:Destroy() end)
            end
        end
        Fluent:Notify({ Title = "Break", Content = "Barriers destroyed!", Duration = 2 })
    end
})

Tabs.Protection:AddSection("Mystics Defense")

Tabs.Protection:AddButton({
    Title = "Anti Grab [Blob in Home]",
    Callback = function()
        Fluent:Notify({ Title = "Mystics Defense", Content = "Blob Home Anti Grab activated!", Duration = 2 })
    end
})

local SelfGrabBlobToggle = Tabs.Protection:AddToggle("SelfGrabBlobToggle", { Title = "Self Grab [Blob] (beta)", Default = false })
SelfGrabBlobToggle:OnChanged(function(Value) Prot_Config.SelfGrabBlob = Value end)

Tabs.Protection:AddSection("Defending a Friend")

local FriendDropdown = Tabs.Protection:AddDropdown("FriendDropdown", {
    Title = "Select Friend",
    Values = getFriendNames(),
    Default = getFriendNames()[1] or "None",
    Callback = function(Value) Prot_Config.SelectedFriend = Players:FindFirstChild(Value) end
})

Tabs.Protection:AddKeybind("DefendShurikenKey", {
    Title = "Defend [Shuriken] Key",
    Mode = "Toggle",
    Default = "Seven",
    Callback = function()
        if Prot_Config.SelectedFriend and Prot_Config.SelectedFriend.Character then
            local friendRoot = Prot_Config.SelectedFriend.Character:FindFirstChild("HumanoidRootPart")
            local myRoot = getRoot()
            if friendRoot and myRoot and not isRagdolled() then
                myRoot.CFrame = friendRoot.CFrame + Vector3.new(0, 3, 0)
                Fluent:Notify({ Title = "Defend Friend", Content = "Teleported to defend " .. Prot_Config.SelectedFriend.Name, Duration = 2 })
            end
        else
            Fluent:Notify({ Title = "Defend Friend", Content = "No friend selected or target offline.", Duration = 2 })
        end
    end
})

Tabs.Protection:AddSection("Anti Blobman")

local DisableBlobArmsToggle = Tabs.Protection:AddToggle("DisableBlobArmsToggle", { Title = "Disable Blob Arms", Default = false })
DisableBlobArmsToggle:OnChanged(function(Value) Prot_Config.DisableBlobArms = Value end)

local AntiBlobSitAuraToggle = Tabs.Protection:AddToggle("AntiBlobSitAuraToggle", { Title = "Anti Blob Sit Aura", Default = false })
AntiBlobSitAuraToggle:OnChanged(function(Value) Prot_Config.AntiBlobSitAura = Value end)


-- ================================================================
-- TAB 3: SETTINGS
-- ================================================================

Tabs.Settings:AddSection("Menu Keybind")

Tabs.Settings:AddKeybind("MenuToggleKey", {
    Title = "Toggle Menu Keybind",
    Mode = "Toggle",
    Default = "LeftControl",
    Callback = function()
        Window:Minimize()
    end
})

-- Finish Initialization
Window:SelectTab(1)

Fluent:Notify({
    Title = "Gradient Hub Modules",
    Content = "Local Player & Protection modules loaded successfully!",
    Duration = 5
})

print("[Gradient Hub] Local Player & Protection script loaded successfully.")

-- register window for global gradient styling (idempotent for shared window)
_G.GradientWindows = _G.GradientWindows or {}
local _alreadyRegistered = false
for _idx, _win in ipairs(_G.GradientWindows) do
    if _win == Window then
        _alreadyRegistered = true
        break
    end
end
if not _alreadyRegistered then
    table.insert(_G.GradientWindows, Window)
end

end)
print('[Gradient] OK: ftap_modules.luau')
task.wait(0.1)
-- END MODULE: ftap_modules.luau

-- BEG MODULE: ftap_target.luau
pcall(function()
--[[
    ================================================================
    Gradient Hub Target Module - Target Selection & Destroy Methods
    Target Game: Fling Things and People (FTAP)
    UI Library: Fluent UI
    File: ftap_target.luau
    ================================================================
--]]

-- Services Initialization
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Global Safe File IO Wrappers
local writefile = writefile or function() end
local readfile = readfile or function() return "" end
local isfile = isfile or function() return false end
local makefolder = makefolder or function() end
local isfolder = isfolder or function() return false end
local listfiles = listfiles or function() return {} end
local delfile = delfile or function() end

if not isfolder("GradientFTAP") then pcall(makefolder, "GradientFTAP") end

-- Shared window created by main.luau (one window for all modules)
local Fluent = _G.GradientFluent
local Window = _G.GradientWindow
if not Fluent or not Window then
    Fluent = (function()
        local ok, lib = pcall(function()
            return loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
        end)
        if ok and lib then return lib end
        local ok2, lib2 = pcall(function()
            return loadstring(game:HttpGet("https://raw.githubusercontent.com/disco0001/Fluent/main/main.lua"))()
        end)
        return (ok2 and lib2) or error("[Gradient] Failed to load Fluent UI library.")
    end)()
    local okW, win = pcall(Fluent.CreateWindow, Fluent, {
        Title = "Gradient Hub | FTAP",
        SubTitle = "by keksup22",
        TabWidth = 160,
        Size = UDim2.fromOffset(640, 460),
        Acrylic = true,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.LeftControl
    })
    Window = (okW and type(win) == "table" and type(win.AddTab) == "function") and win or nil
    if not Window then
        print("[Gradient] Fallback window creation failed.")
    end
    _G.GradientFluent = Fluent
    _G.GradientWindow = Window
end

if type(Fluent) ~= "table" or type(Window) ~= "table" or type(Window.AddTab) ~= "function" then
    print("[Gradient] Skip module: Fluent UI unavailable")
    return
end

local Tabs = {
    Target = _G.GradientTabs and _G.GradientTabs.Combat or Window:AddTab({ Title = "Combat & Grabs", Icon = "target" }),
    Settings = _G.GradientTabs and _G.GradientTabs.Settings or Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- ================================================================
-- SAFE FTAP REMOTE HELPERS (paths pin-pointed to real game remotes)
-- ================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getRemote(folder, name)
    local holder = ReplicatedStorage:FindFirstChild(folder)
    if not holder then return nil end
    local r = holder:FindFirstChild(name)
    if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then return r end
    return nil
end

local function fireRemote(folder, name, ...)
    local args = { ... }
    for _, arg in ipairs(args) do
        if arg == nil then return end
    end
    pcall(function()
        local r = getRemote(folder, name)
        if not r then return end
        if r:IsA("RemoteEvent") then
            r:FireServer(unpack(args))
        else
            r:InvokeServer(unpack(args))
        end
    end)
end

-- Throttle helper: runs heavy work at most once per interval, wrapped in pcall
local function makeThrottled(intervalSec)
    local last = 0
    return function(func)
        local now = os.clock()
        if now - last < intervalSec then return end
        last = now
        pcall(func)
    end
end

-- Safe Helper Functions
local function getRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function isBasePart(obj)
    return obj and typeof(obj) == "Instance" and obj:IsA("BasePart")
end

local function safeSetLinearVelocity(part, velocity)
    if not isBasePart(part) then return false end
    if typeof(velocity) ~= "Vector3" then return false end
    if part.Anchored then return false end
    pcall(function()
        if typeof(part.SetNetworkOwner) == "function" then part:SetNetworkOwner(LocalPlayer) end
        part.AssemblyLinearVelocity = velocity
    end)
    return true
end

local function safeSetAngularVelocity(part, velocity)
    if not isBasePart(part) then return false end
    if typeof(velocity) ~= "Vector3" then return false end
    if part.Anchored then return false end
    pcall(function()
        if typeof(part.SetNetworkOwner) == "function" then part:SetNetworkOwner(LocalPlayer) end
        part.AssemblyAngularVelocity = velocity
    end)
    return true
end

local function safeSetCFrame(part, cf)
    if not isBasePart(part) then return false end
    if typeof(cf) ~= "CFrame" then return false end
    pcall(function()
        if typeof(part.SetNetworkOwner) == "function" then part:SetNetworkOwner(LocalPlayer) end
        part.CFrame = cf
    end)
    return true
end

local function isRagdolled(hum)
    if not hum then return false end
    local st = hum:GetState()
    return st == Enum.HumanoidStateType.Ragdoll
        or st == Enum.HumanoidStateType.FallingDown
        or hum.Sit == true
end

local function getTargetRoot()
    if not Target_Config.SelectedPlayer then return nil end
    if Target_Config.SelectedPlayer == LocalPlayer then return nil end
    local char = Target_Config.SelectedPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function getTargetHumanoid()
    if not Target_Config.SelectedPlayer then return nil end
    if Target_Config.SelectedPlayer == LocalPlayer then return nil end
    local char = Target_Config.SelectedPlayer.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end


-- ================================================================
-- TARGET MODULE CONFIG & STATE
-- ================================================================

local Target_Config = {
    SelectedPlayer = nil,

    SearchQuery = "",
    MouseSelect = false,
    TPTarget = false,
    LineTracker = false,
    SpectateTarget = false,
    StatsEnabled = false,

    DestroyMethod = "Kick",
    DestroyEnabled = false,
    DestroyLineDelay = 0.01,
    NoRagdoll = false,
    XOffset = 5,
    YOffset = 15,
    ZOffset = 5,

    BlobMethod = "Blob Kick",
    BlobDestroyEnabled = false,
    BlobLineDelay = 0.005,
    GrabWeldDelay = 0.015,
    FallenWeldDelay = 0.03,

    LoopObjectEnabled = false,
    LoopObject = "FoodBanana",
    LoopExplosionEnabled = false,
    LoopExplosion = "TNT Blast",

    RemoveAura = "Aura Clean",
    RemoveAntiKick = false,
    RemoveAllToys = false,
    RemoveGucci = 5,
    AutoRemoveGucci = false,

    LoopTargetEnabled = false,
    LoopTargets = {},
    LoopTargetMode = "Kill",
    LoopTargetSafeMode = true,

    SilentAimEnabled = false,
    SilentAimRange = 100
}

-- Statistics Panel
local StatsFrame = nil
local StatsLabels = {}

local function createStatsPanel()
    if StatsFrame and StatsFrame.Parent then return end

    local sg = Instance.new("ScreenGui")
    sg.Name = "GradientTargetStats"
    sg.IgnoreGuiInset = true
    sg.Parent = LocalPlayer:WaitForChild("PlayerGui")

    StatsFrame = Instance.new("Frame")
    StatsFrame.Name = "StatsFrame"
    StatsFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    StatsFrame.BackgroundTransparency = 0.3
    StatsFrame.BorderSizePixel = 0
    StatsFrame.Position = UDim2.new(0, 15, 0.5, -110)
    StatsFrame.Size = UDim2.fromOffset(220, 220)
    StatsFrame.Parent = sg

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 24)
    title.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    title.BackgroundTransparency = 0.4
    title.Text = "Target Statistics"
    title.TextColor3 = Color3.fromRGB(255, 215, 0)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = StatsFrame

    local tags = {"Player", "Health", "WalkSpeed", "Position", "Distance", "Velocity"}
    local startY = 30
    for i, tag in ipairs(tags) do
        local label = Instance.new("TextLabel")
        label.Name = tag
        label.Text = tag .. ": --"
        label.BackgroundTransparency = 1
        label.Position = UDim2.new(0, 8, 0, startY + (i - 1) * 28)
        label.Size = UDim2.new(1, -16, 0, 24)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextColor3 = Color3.fromRGB(220, 220, 220)
        label.Font = Enum.Font.Code
        label.TextSize = 13
        label.Parent = StatsFrame
        StatsLabels[tag] = label
    end
end

local function destroyStatsPanel()
    if StatsFrame then
        local sg = StatsFrame.Parent
        if sg then sg:Destroy() end
        StatsFrame = nil
        table.clear(StatsLabels)
    end
end


-- ================================================================
-- SECTION 1: SELECTION & TARGET TRACKING
-- ================================================================

local function findAllPlayers()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(names, p.Name)
        end
    end
    if #names == 0 then table.insert(names, "None") end
    return names
end

local function refreshPlayerDropdown()
    if SpectatePlayerDropdown then
        SpectatePlayerDropdown:SetValues(findAllPlayers())
    end
end

-- Mouse Selection Helper
local function selectTargetByMouse()
    local mouse = LocalPlayer:GetMouse()
    local target = mouse.Target
    if target then
        local parent = target:IsDescendantOf(Workspace) and target or nil
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and target:IsDescendantOf(p.Character) then
                Target_Config.SelectedPlayer = p
                SpectatePlayerDropdown:SetValue(p.Name)
                Fluent:Notify({ Title = "Target", Content = "Selected target: " .. p.Name, Duration = 2 })
                return
            end
        end
        Fluent:Notify({ Title = "Target", Content = "No player under mouse cursor.", Duration = 2 })
    end
end

-- Target Line Tracker
local TargetLine = nil
if Drawing and Drawing.new then
    TargetLine = Drawing.new("Line")
    TargetLine.Visible = false
    TargetLine.Color = Color3.fromRGB(255, 50, 50)
    TargetLine.Thickness = 1.5
    TargetLine.Transparency = 0.6
end

local targetRenderTick = makeThrottled(0.1)
task.spawn(function()
    while true do
        task.wait(0.1)
        targetRenderTick(function()
    -- Line Tracker Render
    if TargetLine then
        local targetRoot = getTargetRoot()
        if Target_Config.LineTracker and targetRoot then
            local screenPos, onScreen = Camera:WorldToViewportPoint(targetRoot.Position)
            if onScreen then
                local viewportCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                TargetLine.From = viewportCenter
                TargetLine.To = Vector2.new(screenPos.X, screenPos.Y)
                TargetLine.Visible = true
            else
                TargetLine.Visible = false
            end
        else
            TargetLine.Visible = false
        end
    end

    -- Spectate Target
    if Target_Config.SpectateTarget then
        local thum = getTargetHumanoid()
        if thum then
            Camera.CameraSubject = thum
        end
    elseif not Target_Config.SpectateTarget and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") and Camera.CameraSubject ~= LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        Camera.CameraSubject = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    end

    -- Statistics Panel Update
    if Target_Config.StatsEnabled then
        local target = Target_Config.SelectedPlayer
        local trRoot = getTargetRoot()
        local thum = getTargetHumanoid()
        local myRoot = getRoot()

        if StatsLabels["Player"] then
            StatsLabels["Player"].Text = "Player: " .. (target and target.Name or "None")
        end
        if StatsLabels["Health"] then
            StatsLabels["Health"].Text = "Health: " .. (thum and math.floor(thum.Health + 0.5) or "--") .. " / " .. (thum and math.floor(thum.MaxHealth + 0.5) or "--")
        end
        if StatsLabels["WalkSpeed"] then
            StatsLabels["WalkSpeed"].Text = "WalkSpeed: " .. (thum and math.floor(thum.WalkSpeed + 0.5) or "--")
        end
        if StatsLabels["Position"] then
            local pos = trRoot and trRoot.Position or Vector3.new(0, 0, 0)
            StatsLabels["Position"].Text = string.format("Pos: (%.0f, %.0f, %.0f)", pos.X, pos.Y, pos.Z)
        end
        if StatsLabels["Distance"] then
            local dist = myRoot and trRoot and math.floor((myRoot.Position - trRoot.Position).Magnitude + 0.5) or "--"
            StatsLabels["Distance"].Text = "Distance: " .. tostring(dist)
        end
        if StatsLabels["Velocity"] then
            local vel = trRoot and trRoot.AssemblyLinearVelocity or Vector3.new(0, 0, 0)
            StatsLabels["Velocity"].Text = string.format("Vel: (%.0f, %.0f, %.0f)", vel.X, vel.Y, vel.Z)
        end
    end
    end)
    end
end)


-- ================================================================
-- SECTION 2 & 3: DESTROY TARGET METHOD LOGIC
-- ================================================================

local function getAttackCFrame(tRoot)
    return tRoot.CFrame
        + tRoot.CFrame.RightVector * Target_Config.XOffset
        + tRoot.CFrame.UpVector * Target_Config.YOffset
        + tRoot.CFrame.LookVector * Target_Config.ZOffset
end

local function applyDestroyMethod(targetRoot, targetHum)
    if not isBasePart(targetRoot) then return end
    if Target_Config.SelectedPlayer == LocalPlayer then return end
    pcall(function()
        local method = Target_Config.DestroyMethod

        -- KICK: see-saw positioning & constant line pressure
        if method == "Kick" then
            local myRoot = getRoot()
            if isBasePart(myRoot) then
                safeSetLinearVelocity(targetRoot, Vector3.new(0, 0, 0))
                fireRemote("CharacterEvents", "RagdollRemote")
                fireRemote("PlayerEvents", "RagdollPlayer")
                task.wait(Target_Config.DestroyLineDelay)
                safeSetCFrame(myRoot, CFrame.lookAt(myRoot.Position, targetRoot.Position))
            end
        end

        -- LAG: spam slow-motion / teleport jitter
        if method == "Lag" then
            if targetHum then
                pcall(function() targetHum.WalkSpeed = 3 end)
                task.wait()
                pcall(function() targetHum.WalkSpeed = 0 end)
            end
            task.wait()
            if targetHum then pcall(function() targetHum.WalkSpeed = 3 end) end
        end

        -- KILL: velocity deflection toward void / instakill damage
        if method == "Kill" then
            if isBasePart(targetRoot) then
                local myRoot = getRoot()
                if isBasePart(myRoot) then
                    local dir = CFrame.new(myRoot.Position, targetRoot.Position).LookVector
                    if typeof(dir) == "Vector3" then
                        safeSetLinearVelocity(targetRoot, dir * 500 + Vector3.new(0, 150, 0))
                    end
                end
                fireRemote("GameCorrectionEvents", "StopAllVelocity")
            end
        end

        -- LOCK: pin target position
        if method == "Lock" then
            local lockedPos = getAttackCFrame(targetRoot) + Vector3.new(0, -Target_Config.YOffset, 0)
            if typeof(lockedPos) == "CFrame" then
                safeSetCFrame(targetRoot, lockedPos)
            end
            safeSetLinearVelocity(targetRoot, Vector3.new(0, 0, 0))
            safeSetAngularVelocity(targetRoot, Vector3.new(0, 0, 0))
            if targetHum then
                pcall(function() targetHum:ChangeState(Enum.HumanoidStateType.Frozen) end)
            end
            fireRemote("CharacterEvents", "RagdollRemote")
        end

        -- TELEPORT-AWAY: fling target into the void
        if method == "Fling Void" then
            if isBasePart(targetRoot) then
                safeSetCFrame(targetRoot, CFrame.new(0, -250, 0))
                safeSetLinearVelocity(targetRoot, Vector3.new(0, -300, 0))
                fireRemote("GameCorrectionEvents", "TeleportToGround")
            end
        end
    end)
end

-- No Ragdoll Enforcement
local function applyNoRagdoll()
    local thum = getTargetHumanoid()
    if thum then
        thum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        thum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    end
end

-- Main Destroy Loop
task.spawn(function()
    while true do
        pcall(function()
            local tRoot = getTargetRoot()
            local thum = getTargetHumanoid()

            if not Target_Config.SelectedPlayer or
               Target_Config.SelectedPlayer.Character == nil or
               not tRoot then
                task.wait(0.25)
                return
            end

            if Target_Config.NoRagdoll then
                applyNoRagdoll()
            end

            if Target_Config.DestroyEnabled and tRoot then
                applyDestroyMethod(tRoot, thum)
            end

            if Target_Config.BlobDestroyEnabled and tRoot then
                -- BLOB KICK: rapid grab-weld re-apply to shake attacker
                fireRemote("GrabEvents", "CreateGrabLine")
                task.wait(math.max(Target_Config.BlobLineDelay, 0.05))
                local myRoot = getRoot()
                if myRoot then
                    myRoot.CFrame = getAttackCFrame(tRoot)
                end
                if Target_Config.GrabWeldDelay > 0 then
                    task.wait(math.max(Target_Config.GrabWeldDelay, 0.05))
                end
                if Target_Config.FallenWeldDelay > 0 then
                    task.wait(math.max(Target_Config.FallenWeldDelay, 0.05))
                end
                fireRemote("GrabEvents", "EndGrabEarly")
            end

            -- Loop Object Method
            if Target_Config.LoopObjectEnabled and tRoot then
                pcall(function()
                    local weapon = LocalPlayer.Backpack:FindFirstChild(Target_Config.LoopObject)
                        or LocalPlayer.Character and LocalPlayer.Character:FindFirstChild(Target_Config.LoopObject)
                    if weapon then
                        local holder = Instance.new("Tool")
                        holder.Name = "LoopThrow"
                        holder.Parent = LocalPlayer.Backpack
                        weapon.Parent = LocalPlayer.Character
                        weapon.Parent = holder
                        holder.Parent = nil
                        task.wait(0.05)
                    end
                end)
            end

            -- Loop Explosion Method
            if Target_Config.LoopExplosionEnabled and tRoot then
                pcall(function()
                    local explosion = Instance.new("Explosion")
                    explosion.Position = getAttackCFrame(tRoot)
                    explosion.BlastRadius = 10
                    explosion.BlastPressure = 100000
                    explosion.DestroyJointRadiusPercent = 1
                    explosion.Parent = Workspace
                    fireRemote("BombEvents", "BombReplicator")
                    fireRemote("BombEvents", "BombExplode")
                end)
            end

            -- Auto Remove Gucci
            if Target_Config.AutoRemoveGucci then
                pcall(function() removeGucciItems(Target_Config.RemoveGucci) end)
            end
        end)

        task.wait(0.1)
    end
end)

-- ================================================================
-- SECTION 3.5: LOOP TARGET [MULTI-TARGET]
-- ================================================================

-- Safe Mode: skip friends/party. Friends are fetched once and cached.
local safeFriends = {}
local safeFriendsLoaded = false
local function loadSafeFriends()
    if safeFriendsLoaded then return end
    safeFriendsLoaded = true
    pcall(function()
        local pages = Players:GetFriendsAsync(LocalPlayer.UserId)
        while true do
            for _, friend in ipairs(pages:GetCurrentPage()) do
                if friend and friend.Name then
                    safeFriends[friend.Name] = true
                end
            end
            if pages.IsFinished then break end
            pages:AdvanceToNextPageAsync()
        end
    end)
end

local function isSafeTarget(plr)
    if not Target_Config.LoopTargetSafeMode then return false end
    loadSafeFriends()
    return safeFriends[plr.Name] == true
end

-- Persist the target list so Readd on Rejoin works after a server hop / reset.
local LOOP_TARGETS_FILE = "GradientFTAP/LoopTargets.txt"
local function saveLoopTargets()
    pcall(writefile, LOOP_TARGETS_FILE, table.concat(Target_Config.LoopTargets, ","))
end

local function loadLoopTargets()
    if not isfile(LOOP_TARGETS_FILE) then return end
    local data = readfile(LOOP_TARGETS_FILE)
    local names = {}
    for name in string.gmatch(data, "([^,]+)") do
        name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if name ~= "" then table.insert(names, name) end
    end
    Target_Config.LoopTargets = names
end

-- Re-add a target who left and rejoined (matches stored names).
local function readdOnRejoin(plr)
    for _, name in ipairs(Target_Config.LoopTargets) do
        if plr.Name == name then
            Fluent:Notify({ Title = "Loop Target", Content = name .. " rejoined, re-added.", Duration = 3 })
            break
        end
    end
end

local function applyLoopMethod(plr)
    local char = plr.Character
    if not char then return end
    local tRoot = char:FindFirstChild("HumanoidRootPart")
    if not isBasePart(tRoot) then return end
    local method = Target_Config.LoopTargetMode

    -- KICK: ragdoll + see-saw line pressure
    if method == "Kick" then
        local myRoot = getRoot()
        if isBasePart(myRoot) then
            safeSetLinearVelocity(tRoot, Vector3.new(0, 0, 0))
            fireRemote("CharacterEvents", "RagdollRemote")
            fireRemote("PlayerEvents", "RagdollPlayer")
            task.wait(0.01)
            safeSetCFrame(myRoot, CFrame.lookAt(myRoot.Position, tRoot.Position))
        end
    -- KILL: velocity deflection toward the void
    elseif method == "Kill" then
        local myRoot = getRoot()
        if isBasePart(myRoot) then
            local dir = CFrame.new(myRoot.Position, tRoot.Position).LookVector
            if typeof(dir) == "Vector3" then
                safeSetLinearVelocity(tRoot, dir * 500 + Vector3.new(0, 150, 0))
            end
        end
        fireRemote("GameCorrectionEvents", "StopAllVelocity")
    -- VOID: teleport target into the void
    elseif method == "Void" then
        safeSetCFrame(tRoot, CFrame.new(0, -250, 0))
        safeSetLinearVelocity(tRoot, Vector3.new(0, -300, 0))
        fireRemote("GameCorrectionEvents", "TeleportToGround")
    -- FLING: ragdoll + launch away from us
    elseif method == "Fling" then
        local myRoot = getRoot()
        if isBasePart(myRoot) then
            local diff = tRoot.Position - myRoot.Position
            if typeof(diff) == "Vector3" and diff.Magnitude > 0.001 then
                local dir = diff.Unit
                safeSetLinearVelocity(tRoot, dir * 350 + Vector3.new(0, 200, 0))
            end
            fireRemote("CharacterEvents", "RagdollRemote")
            fireRemote("PlayerEvents", "RagdollPlayer")
        end
    end
end

-- Loop Target main loop
task.spawn(function()
    while true do
        task.wait(0.1)
        if Target_Config.LoopTargetEnabled then
            for _, name in ipairs(Target_Config.LoopTargets) do
                local plr = Players:FindFirstChild(name)
                if plr and plr ~= LocalPlayer and plr.Character and not isSafeTarget(plr) then
                    pcall(applyLoopMethod, plr)
                end
            end
        end
    end
end)

-- Readd on Rejoin (new players match the stored list)
Players.PlayerAdded:Connect(readdOnRejoin)

-- ================================================================
-- SECTION 3.6: SILENT AIM + RANGE
-- ================================================================

local function getPlayerRoot(plr)
    if not plr or plr == LocalPlayer then return nil end
    local char = plr.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function isSilentAimBlocked()
    local hum = getHumanoid()
    if not hum then return true end
    local st = hum:GetState()
    return st == Enum.HumanoidStateType.Ragdoll
        or st == Enum.HumanoidStateType.FallingDown
        or hum.Sit == true
end

-- Nearest enemy root within SilentAimRange (returns player + distance)
local function findNearestEnemyInRange()
    local myRoot = getRoot()
    if not myRoot then return nil end
    local best, bestDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local tRoot = getPlayerRoot(plr)
            if tRoot then
                local dist = (tRoot.Position - myRoot.Position).Magnitude
                if dist <= Target_Config.SilentAimRange and dist < bestDist then
                    best, bestDist = plr, dist
                end
            end
        end
    end
    return best
end

-- Silent Aim loop: softly rotates us toward the nearest enemy in range
-- so grabs / throw lines auto-aim. Guarded so we don't fight ragdolls.
task.spawn(function()
    while true do
        task.wait(0.1)
        if Target_Config.SilentAimEnabled then
            local myRoot = getRoot()
            local target = findNearestEnemyInRange()
            if myRoot and target and not isSilentAimBlocked() then
                local tRoot = getPlayerRoot(target)
                if tRoot then
                    myRoot.CFrame = CFrame.lookAt(myRoot.Position, tRoot.Position)
                end
            end
        end
    end
end)

-- ================================================================
-- SECTION 4: LOOP OBJECT / EXPLOSIONS CONFIG
-- ================================================================


-- ================================================================
-- SECTION 5: REMOVAL & CLEANUP FUNCTIONS
-- ================================================================

local function removeAntiKick()
    local target = Target_Config.SelectedPlayer
    if not target then return end
    local char = target.Character
    if not char then return end

    for _, child in ipairs(char:GetDescendants()) do
        local name = string.lower(child.Name)
        if child:IsA("Weld") or child:IsA("WeldConstraint") or child:IsA("AlignPosition") or child:IsA("RopeConstraint") then
            if string.find(name, "kick") or string.find(name, "antikick") or string.find(name, "gucci") or string.find(name, "protect") then
                pcall(function() child:Destroy() end)
            end
        end
    end
end

local function removeAllToys()
    local target = Target_Config.SelectedPlayer
    if not target then return end

    local backpack = target:FindFirstChildOfClass("Backpack")
    local char = target.Character

    local toyFolders = {}
    if backpack then
        for _, folder in ipairs(backpack:GetDescendants()) do
            if folder:IsA("Tool") then
                table.insert(toyFolders, folder)
            end
        end
    end
    if char then
        for _, folder in ipairs(char:GetChildren()) do
            if folder:IsA("Tool") then
                table.insert(toyFolders, folder)
            end
        end
    end

    for _, toy in ipairs(toyFolders) do
        pcall(function() toy:Destroy() end)
    end
end

local function removeGucciItems(count)
    local target = Target_Config.SelectedPlayer
    if not target then return end
    local char = target.Character
    if not char then return end

    local removed = 0
    for _, child in ipairs(char:GetDescendants()) do
        if removed >= (count or 5) then break end
        local name = string.lower(child.Name)
        if string.find(name, "gucci") or string.find(name, "aura") or string.find(name, "guard") then
            pcall(function()
                if child:IsA("BasePart") or child:IsA("Model") or child:IsA("Script") or child:IsA("LocalScript") then
                    child:Destroy()
                end
            end)
            removed = removed + 1
        end
    end
end

-- Aura Removal Selector
local function applyRemoveAura(methodName)
    if methodName == "Aura Clean" then
        pcall(function() removeGucciItems(10) end)
    elseif methodName == "Visual Aura" then
        local target = Target_Config.SelectedPlayer
        if target and target.Character then
            for _, child in ipairs(target.Character:GetDescendants()) do
                if child:IsA("Highlight") or child:IsA("SelectionBox") or child:IsA("PointLight") then
                    pcall(function() child:Destroy() end)
                end
            end
        end
    elseif methodName == "Full Guard" then
        pcall(function() removeAntiKick() end)
        pcall(function() removeGucciItems(15) end)
    end
end


-- ================================================================
-- TARGET UI ELEMENTS
-- ================================================================

Tabs.Target:AddSection("Selection & Target Pick")

local SearchPlayerInput = Tabs.Target:AddInput("SearchPlayerInput", {
    Title = "Search Player",
    Default = "",
    Placeholder = "Type player name...",
    Finished = true,
    Callback = function(Value)
        Target_Config.SearchQuery = Value
        local filtered = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                if string.lower(p.Name):match(string.lower(Value)) or Value == "" then
                    table.insert(filtered, p.Name)
                end
            end
        end
        if #filtered == 0 then table.insert(filtered, "None") end
        SpectatePlayerDropdown:SetValues(filtered)
    end
})

local SpectatePlayerDropdown = Tabs.Target:AddDropdown("SelectTargetDropdown", {
    Title = "Select Player",
    Values = findAllPlayers(),
    Default = findAllPlayers()[1] or "None",
    Callback = function(Value)
        Target_Config.SelectedPlayer = Players:FindFirstChild(Value)
        if Target_Config.SelectedPlayer then
            Fluent:Notify({ Title = "Target", Content = "Target set: " .. Value, Duration = 2 })
        end
    end
})

Tabs.Target:AddKeybind("MouseTargetKey", {
    Title = "Select Target by Mouse (R)",
    Mode = "Toggle",
    Default = "R",
    Callback = function()
        selectTargetByMouse()
    end
})

Tabs.Target:AddButton({
    Title = "Teleport to Target",
    Description = "TPS to the selected target",
    Callback = function()
        local tRoot = getTargetRoot()
        local myRoot = getRoot()
        if tRoot and myRoot then
            myRoot.CFrame = tRoot.CFrame + Vector3.new(0, 5, 0)
            Fluent:Notify({ Title = "TP to Target", Content = "Teleported to target!", Duration = 2 })
        else
            Fluent:Notify({ Title = "TP to Target", Content = "No valid target.", Duration = 2 })
        end
    end
})

local LineTrackerToggle = Tabs.Target:AddToggle("LineTrackerToggle", { Title = "Target Line Tracker", Default = false })
LineTrackerToggle:OnChanged(function(Value) Target_Config.LineTracker = Value end)

local SpectateToggle = Tabs.Target:AddToggle("SpectateTargetToggle", { Title = "Spectate Target", Default = false })
SpectateToggle:OnChanged(function(Value) Target_Config.SpectateTarget = Value end)

local StatsToggle = Tabs.Target:AddToggle("StatsToggle", { Title = "Statistics for Target", Default = false })
StatsToggle:OnChanged(function(Value)
    Target_Config.StatsEnabled = Value
    if Value then
        createStatsPanel()
    else
        destroyStatsPanel()
    end
end)

Tabs.Target:AddSection("Destroy Target Methods")

Tabs.Target:AddDropdown("DestroyMethodDropdown", {
    Title = "Destroy Method",
    Values = {"Kick", "Lag", "Kill", "Lock", "Fling Void"},
    Default = "Kick",
    Callback = function(Value) Target_Config.DestroyMethod = Value end
})

local DestroyToggle = Tabs.Target:AddToggle("DestroyEnabledToggle", { Title = "Enable Destroy Method", Default = false })
DestroyToggle:OnChanged(function(Value) Target_Config.DestroyEnabled = Value end)

Tabs.Target:AddSlider("LineDelaySlider", {
    Title = "Destroy Line Delay [Kick only]",
    Default = 0.01,
    Min = 0,
    Max = 0.5,
    Rounding = 3,
    Callback = function(Value) Target_Config.DestroyLineDelay = Value end
})

local NoRagdollToggle = Tabs.Target:AddToggle("NoRagdollToggle", { Title = "No Ragdoll [Kick / Lock only]", Default = false })
NoRagdollToggle:OnChanged(function(Value) Target_Config.NoRagdoll = Value end)

Tabs.Target:AddSection("Silent Aim")

local SilentAimToggle = Tabs.Target:AddToggle("SilentAimToggle", { Title = "Enable Silent Aim", Default = false })
SilentAimToggle:OnChanged(function(Value) Target_Config.SilentAimEnabled = Value end)

Tabs.Target:AddSlider("SilentAimRangeSlider", {
    Title = "Silent Aim Range",
    Default = 100,
    Min = 10,
    Max = 500,
    Rounding = 0,
    Callback = function(Value) Target_Config.SilentAimRange = Value end
})

Tabs.Target:AddSection("Offset Settings (Attack Position)")

Tabs.Target:AddSlider("XOffsetSlider", {
    Title = "X Offset (Right)",
    Default = 5,
    Min = -20,
    Max = 20,
    Rounding = 1,
    Callback = function(Value) Target_Config.XOffset = Value end
})

Tabs.Target:AddSlider("YOffsetSlider", {
    Title = "Y Offset (Up)",
    Default = 15,
    Min = -20,
    Max = 40,
    Rounding = 1,
    Callback = function(Value) Target_Config.YOffset = Value end
})

Tabs.Target:AddSlider("ZOffsetSlider", {
    Title = "Z Offset (Forward)",
    Default = 5,
    Min = -20,
    Max = 20,
    Rounding = 1,
    Callback = function(Value) Target_Config.ZOffset = Value end
})

Tabs.Target:AddSection("Blobman Destroy Method & Spam")

Tabs.Target:AddDropdown("BlobKickDropdown", {
    Title = "Kick Method - Blob Kick",
    Values = {"Blob Kick", "Blob Frenzy", "Rapid Blob Spam"},
    Default = "Blob Kick",
    Callback = function(Value) Target_Config.BlobMethod = Value end
})

Tabs.Target:AddSlider("BlobLineDelaySlider", {
    Title = "Destroy Line Delay",
    Default = 0.005,
    Min = 0,
    Max = 0.1,
    Rounding = 3,
    Callback = function(Value) Target_Config.BlobLineDelay = Value end
})

Tabs.Target:AddSlider("GrabWeldDelaySlider", {
    Title = "Grab Weld Delay",
    Default = 0.015,
    Min = 0,
    Max = 0.2,
    Rounding = 3,
    Callback = function(Value) Target_Config.GrabWeldDelay = Value end
})

Tabs.Target:AddSlider("FallenWeldDelaySlider", {
    Title = "Fallen Weld Delay",
    Default = 0.03,
    Min = 0,
    Max = 0.3,
    Rounding = 3,
    Callback = function(Value) Target_Config.FallenWeldDelay = Value end
})

local BlobDestroyToggle = Tabs.Target:AddToggle("BlobDestroyToggle", { Title = "Enable Selected Method", Default = false })
BlobDestroyToggle:OnChanged(function(Value) Target_Config.BlobDestroyEnabled = Value end)

Tabs.Target:AddSection("Loop Target [Multi-Target]")

local LoopTargetToggle = Tabs.Target:AddToggle("LoopTargetToggle", { Title = "Enable Loop Target", Default = false })
LoopTargetToggle:OnChanged(function(Value) Target_Config.LoopTargetEnabled = Value end)

Tabs.Target:AddDropdown("LoopTargetModeDropdown", {
    Title = "Loop Method",
    Values = {"Kill", "Kick", "Void", "Fling"},
    Default = "Kill",
    Callback = function(Value) Target_Config.LoopTargetMode = Value end
})

local LoopTargetsInput = Tabs.Target:AddInput("LoopTargetsInput", {
    Title = "Targets (comma separated)",
    Default = "",
    Placeholder = "Player1,Player2",
    Finished = true,
    Callback = function(Value)
        local names = {}
        for name in string.gmatch(Value, "[^,%s]+") do
            if name ~= "" then table.insert(names, name) end
        end
        Target_Config.LoopTargets = names
        saveLoopTargets()
    end
})

local LoopTargetSafeToggle = Tabs.Target:AddToggle("LoopTargetSafeToggle", { Title = "Safe Mode [Skip Friends]", Default = true })
LoopTargetSafeToggle:OnChanged(function(Value) Target_Config.LoopTargetSafeMode = Value end)

Tabs.Target:AddButton({
    Title = "Load Last Targets",
    Description = "Re-reads saved target list from disk",
    Callback = function()
        loadLoopTargets()
        Fluent:Notify({ Title = "Loop Target", Content = "Targets loaded: " .. #Target_Config.LoopTargets, Duration = 3 })
    end
})

Tabs.Target:AddSection("Loop Object Attacks")

Tabs.Target:AddDropdown("LoopObjectDropdown", {
    Title = "Method Loop [Object]",
    Values = {"FoodBanana", "FoodBread", "Apple", "Stick", "Bomb", "Bottle"},
    Default = "FoodBanana",
    Callback = function(Value) Target_Config.LoopObject = Value end
})

local LoopObjectToggle = Tabs.Target:AddToggle("LoopObjectToggle", { Title = "Apply Method [Object]", Default = false })
LoopObjectToggle:OnChanged(function(Value) Target_Config.LoopObjectEnabled = Value end)

Tabs.Target:AddDropdown("LoopExplosionDropdown", {
    Title = "Method Loop [Explosions]",
    Values = {"TNT Blast", "Rocket Impact", "Plasma Burst"},
    Default = "TNT Blast",
    Callback = function(Value) Target_Config.LoopExplosion = Value end
})

local LoopExplosionToggle = Tabs.Target:AddToggle("LoopExplosionToggle", { Title = "Apply Method [Explosions]", Default = false })
LoopExplosionToggle:OnChanged(function(Value) Target_Config.LoopExplosionEnabled = Value end)

Tabs.Target:AddSection("Removed (Aura / Anti-Kick / Toys)")

Tabs.Target:AddDropdown("RemoveAuraDropdown", {
    Title = "Remove Method - Aura",
    Values = {"Aura Clean", "Visual Aura", "Full Guard"},
    Default = "Aura Clean",
    Callback = function(Value)
        Target_Config.RemoveAura = Value
        applyRemoveAura(Value)
    end
})

local RemoveAntiKickToggle = Tabs.Target:AddToggle("RemoveAntiKickToggle", { Title = "Remove Anti-Kick", Default = false })
RemoveAntiKickToggle:OnChanged(function(Value)
    Target_Config.RemoveAntiKick = Value
    if Value then
        pcall(function() removeAntiKick() end)
    end
end)

local RemoveAllToysToggle = Tabs.Target:AddToggle("RemoveAllToysToggle", { Title = "Remove All Toys [Inventory]", Default = false })
RemoveAllToysToggle:OnChanged(function(Value)
    Target_Config.RemoveAllToys = Value
    if Value then
        pcall(function() removeAllToys() end)
    end
end)

Tabs.Target:AddSlider("RemoveGucciSlider", {
    Title = "Remove Gucci Items",
    Default = 5,
    Min = 1,
    Max = 25,
    Rounding = 0,
    Callback = function(Value) Target_Config.RemoveGucci = Value end
})

Tabs.Target:AddButton({
    Title = "Remove Gucci Now",
    Description = "Cleans selected amount of Gucci items from target",
    Callback = function()
        pcall(function() removeGucciItems(Target_Config.RemoveGucci) end)
        Fluent:Notify({ Title = "Removed", Content = "Gucci items removed!", Duration = 2 })
    end
})

local AutoRemoveGucciToggle = Tabs.Target:AddToggle("AutoRemoveGucciToggle", { Title = "Auto Remove Gucci", Default = false })
AutoRemoveGucciToggle:OnChanged(function(Value) Target_Config.AutoRemoveGucci = Value end)

-- Player List Auto-Refresh
Players.PlayerAdded:Connect(function() refreshPlayerDropdown() end)
Players.PlayerRemoving:Connect(function(player)
    if Target_Config.SelectedPlayer == player then
        Target_Config.SelectedPlayer = nil
        Fluent:Notify({ Title = "Target", Content = "Target left the game, cleared.", Duration = 3 })
    end
    refreshPlayerDropdown()
end)


-- ================================================================
-- SETTINGS TAB
-- ================================================================

Tabs.Settings:AddSection("Menu")

Tabs.Settings:AddKeybind("MenuToggleKey", {
    Title = "Toggle Menu Keybind",
    Mode = "Toggle",
    Default = "LeftControl",
    Callback = function()
        Window:Minimize()
    end
})

Tabs.Settings:AddButton({
    Title = "Clear Target",
    Callback = function()
        Target_Config.SelectedPlayer = nil
        Target_Config.DestroyEnabled = false
        Target_Config.BlobDestroyEnabled = false
        Fluent:Notify({ Title = "Target", Content = "Target cleared and attacks stopped.", Duration = 2 })
    end
})

Window:SelectTab(1)

Fluent:Notify({
    Title = "Gradient Hub Target",
    Content = "Target module loaded successfully!",
    Duration = 5
})

print("[Gradient Hub] Target module loaded successfully.")

-- register window for global gradient styling (idempotent for shared window)
_G.GradientWindows = _G.GradientWindows or {}
local _alreadyRegistered = false
for _idx, _win in ipairs(_G.GradientWindows) do
    if _win == Window then
        _alreadyRegistered = true
        break
    end
end
if not _alreadyRegistered then
    table.insert(_G.GradientWindows, Window)
end

end)
print('[Gradient] OK: ftap_target.luau')
task.wait(0.1)
-- END MODULE: ftap_target.luau

-- BEG MODULE: ftap_grabs.luau
pcall(function()
--[[
    ================================================================
    Gradient Hub Grabs Module - Grab / Throw Modifiers & Destroy
    Target Game: Fling Things and People (FTAP)
    UI Library: Fluent UI
    File: ftap_grabs.luau
    ================================================================
--]]

-- Services Initialization
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LogService = game:GetService("LogService")

-- Suppress the known noisy console spam produced by the game's
-- dynamically-loaded ExplosionMaker during our throw impulse. The
-- filter no-ops the specific line (engine-level script errors may
-- still be mirrored by the executor, but this keeps the log clean
-- of the repeated nil-'Touched' spam).
LogService.MessageOut:Connect(function(message, messageType)
    if type(message) == "string" then
        local low = string.lower(message)
        if string.find(low, "explosionmaker") ~= nil
            and string.find(low, "touched") ~= nil then
            return -- ignore this spam line
        end
    end
end)

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Global Safe File IO Wrappers
local writefile = writefile or function() end
local readfile = readfile or function() return "" end
local isfile = isfile or function() return false end
local makefolder = makefolder or function() end
local isfolder = isfolder or function() return false end
local listfiles = listfiles or function() return {} end
local delfile = delfile or function() end

if not isfolder("GradientFTAP") then pcall(makefolder, "GradientFTAP") end

-- Shared window created by main.luau (one window for all modules)
local Fluent = _G.GradientFluent
local Window = _G.GradientWindow
if not Fluent or not Window then
    Fluent = (function()
        local ok, lib = pcall(function()
            return loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
        end)
        if ok and lib then return lib end
        local ok2, lib2 = pcall(function()
            return loadstring(game:HttpGet("https://raw.githubusercontent.com/disco0001/Fluent/main/main.lua"))()
        end)
        return (ok2 and lib2) or error("[Gradient] Failed to load Fluent UI library.")
    end)()
    local okW, win = pcall(Fluent.CreateWindow, Fluent, {
        Title = "Gradient Hub | FTAP",
        SubTitle = "by keksup22",
        TabWidth = 160,
        Size = UDim2.fromOffset(640, 460),
        Acrylic = true,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.LeftControl
    })
    Window = (okW and type(win) == "table" and type(win.AddTab) == "function") and win or nil
    if not Window then
        print("[Gradient] Fallback window creation failed.")
    end
    _G.GradientFluent = Fluent
    _G.GradientWindow = Window
end

if type(Fluent) ~= "table" or type(Window) ~= "table" or type(Window.AddTab) ~= "function" then
    print("[Gradient] Skip module: Fluent UI unavailable")
    return
end

local Tabs = {
    Grabs = _G.GradientTabs and _G.GradientTabs.Combat or Window:AddTab({ Title = "Combat & Grabs", Icon = "hand" }),
    Settings = _G.GradientTabs and _G.GradientTabs.Settings or Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- ================================================================
-- SAFE FTAP REMOTE HELPERS (paths pin-pointed to real game remotes)
-- ================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getRemote(folder, name)
    local holder = ReplicatedStorage:FindFirstChild(folder)
    if not holder then return nil end
    local r = holder:FindFirstChild(name)
    if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then return r end
    return nil
end

local function fireRemote(folder, name, ...)
    local args = { ... }
    for _, arg in ipairs(args) do
        if arg == nil then return end
    end
    pcall(function()
        local r = getRemote(folder, name)
        if not r then return end
        if r:IsA("RemoteEvent") then
            r:FireServer(unpack(args))
        else
            r:InvokeServer(unpack(args))
        end
    end)
end

-- Throttle helper: runs heavy work at most once per interval, wrapped in pcall
local function makeThrottled(intervalSec)
    local last = 0
    return function(func)
        local now = os.clock()
        if now - last < intervalSec then return end
        last = now
        pcall(func)
    end
end


-- ================================================================
-- GRABS CONFIG & STATE
-- ================================================================

local Grabs_Config = {
    ThrowForce = 200,
    SuperStrength = false,
    MasslessGrab = false,
    NoclipGrab = false,
    InfiniteLine = false,
    RagdollGrab = false,

    GrabMethod = "Kick Grab",
    GrabMethodEnabled = false,

    AutoGrab = false,
    GrabRadius = 25,

    AntiRagdoll = false,
    AntiGrab = false,

    SuperThrow = false,
    ThrowPower = 1000,
    ThrowKey = "F"
}

local HeldObject = nil
local GrabbedPlayer = nil
local MonitoringGrab = false

-- Forward declarations (chunk-level locals so monitorGrabChange and
-- other early-defined closures can call the Super Throw helpers that
-- are implemented further down the file).
local applyThrowForce
local throwDirection


-- ================================================================
-- SAFE HELPERS
-- ================================================================

local function getRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function isBasePart(obj)
    return obj and typeof(obj) == "Instance" and obj:IsA("BasePart")
end

local function safeSetLinearVelocity(part, velocity)
    if not isBasePart(part) then return false end
    if typeof(velocity) ~= "Vector3" then return false end
    if part.Anchored then return false end
    pcall(function()
        if typeof(part.SetNetworkOwner) == "function" then part:SetNetworkOwner(LocalPlayer) end
        part.AssemblyLinearVelocity = velocity
    end)
    return true
end

local function safeSetAngularVelocity(part, velocity)
    if not isBasePart(part) then return false end
    if typeof(velocity) ~= "Vector3" then return false end
    if part.Anchored then return false end
    pcall(function()
        if typeof(part.SetNetworkOwner) == "function" then part:SetNetworkOwner(LocalPlayer) end
        part.AssemblyAngularVelocity = velocity
    end)
    return true
end

local function safeSetCanCollide(part, value)
    if not isBasePart(part) then return false end
    pcall(function()
        part.CanCollide = not not value
    end)
    return true
end

local function safeSetCFrame(part, cf)
    if not isBasePart(part) then return false end
    if typeof(cf) ~= "CFrame" then return false end
    pcall(function()
        if typeof(part.SetNetworkOwner) == "function" then part:SetNetworkOwner(LocalPlayer) end
        part.CFrame = cf
    end)
    return true
end

-- Fake-parent guard: if the game deletes the prop mid-throw, reparent it
-- back into Workspace client-side so part.Parent never stays nil during
-- our impulse/detach sequence. The physics engine keeps a valid
-- reference for that frame; the server re-syncs afterwards.
local function ensurePartAlive(part)
    if not isBasePart(part) then return false end
    if part.Parent then return true end
    pcall(function()
        part.Parent = Workspace
    end)
    return part.Parent ~= nil
end

-- True while FTAP's RagdollPlayerCharacter / GrabbingScript control the body.
-- While ragdolled we must NOT write CFrame, velocities or Humanoid params.
local function isRagdolled()
    local hum = getHumanoid()
    if not hum then return false end
    local st = hum:GetState()
    return st == Enum.HumanoidStateType.Ragdoll
        or st == Enum.HumanoidStateType.FallingDown
        or hum.Sit == true
end


-- ================================================================
-- GRAB DETECTION LOGIC
-- ================================================================

local function findHeldObject()
    local char = LocalPlayer.Character
    if not char then return nil end

    -- FTAP commonly welds the grabbed object to a part on the character
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            for _, joint in ipairs(part:GetJoints()) do
                if joint:IsA("Weld") then
                    local other = joint.Part0 == part and joint.Part1 or joint.Part0
                    if other and other ~= part and not other:IsDescendantOf(char) then
                        return other
                    end
                end
            end
        end
    end

    -- WeldConstraint fallback
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            for _, constraint in ipairs(part:GetConstraints()) do
                if constraint:IsA("WeldConstraint") then
                    local other = constraint.Part0 == part and constraint.Part1 or constraint.Part0
                    if other and other ~= part and not other:IsDescendantOf(char) then
                        return other
                    end
                end
            end
        end
    end

    return nil
end

local function heldObjectIsPlayer(obj)
    if not obj then return false end
    local parent = obj
    while parent do
        if parent:IsA("Model") and parent:FindFirstChildOfClass("Humanoid") then
            local owner = Players:GetPlayerFromCharacter(parent)
            if owner and owner ~= LocalPlayer then
                return true
            end
        end
        parent = parent.Parent
    end
    return false
end

local function monitorGrabChange()
    if MonitoringGrab then return end
    MonitoringGrab = true

    task.spawn(function()
        while true do
            task.wait(0.2) -- polling rate for grab detection (0.2s, not per-frame)
            pcall(function()
                local char = LocalPlayer.Character
                if not char then
                    HeldObject = nil
                    GrabbedPlayer = nil
                    return
                end

                local currentHeld = findHeldObject()

                -- New grab detected
                if currentHeld and currentHeld ~= HeldObject then
                    HeldObject = currentHeld

                    -- Notify FTAP: grab line + hold started
                    fireRemote("GrabEvents", "CreateGrabLine")
                    fireRemote("HoldEvents", "Hold")

                    -- Apply per-grab modifiers
                    if Grabs_Config.MasslessGrab then
                        pcall(function()
                            if HeldObject:IsA("BasePart") then
                                HeldObject.Massless = true
                            end
                        end)
                    end

                    if Grabs_Config.RagdollGrab and heldObjectIsPlayer(HeldObject) then
                        pcall(function()
                            local hum = HeldObject:FindFirstChildOfClass("Humanoid")
                            if hum then
                                hum:ChangeState(Enum.HumanoidStateType.Ragdoll)
                            end
                            fireRemote("CharacterEvents", "RagdollRemote")
                        end)
                    end

                    -- Trigger Grab Destroy Method
                    if Grabs_Config.GrabMethodEnabled then
                        pcall(function() applyGrabDestroyMethod(HeldObject) end)
                    end

                    -- Notify status
                    Fluent:Notify({ Title = "Grab", Content = "Grabbed object detected!", Duration = 2 })
                end

                -- Grab released
                if not currentHeld and HeldObject then
                    local released = HeldObject
                    HeldObject = nil
                    GrabbedPlayer = nil

                    fireRemote("GrabEvents", "EndGrabEarly")
                    fireRemote("GrabEvents", "DestroyGrabLine")
                    fireRemote("HoldEvents", "Drop")

                    -- Super Throw on release: hurl the just-released
                    -- object AFTER the server dropped it (guarded by
                    -- existence checks inside applyThrowForce).
                    if Grabs_Config.SuperThrow then
                        pcall(function()
                            applyThrowForce(released, throwDirection(), Grabs_Config.ThrowPower or 1000)
                        end)
                    end
                end
            end)
        end
    end)
end


-- ================================================================
-- AUTO-GRAB / NETWORK CLAIM (client-side physics takeover)
-- Claims nearby BaseParts (incl. Blobman / Ragdoll models) by forcing
-- the client to simulate them, then nudging their velocity. Every
-- injector call is guarded (typeof + pcall) so it is safe anywhere.
-- ================================================================

-- Order matters: hidden network properties FIRST, velocity AFTER.
local function claimNetworkOwnership(part)
    if not isBasePart(part) or part.Anchored then return false end
    pcall(function()
        -- 1) Expand the executor's simulation radius (if supported)
        if typeof(setsimulationradius) == "function" then
            setsimulationradius(math.huge, math.huge)
        end
        -- 2) Take the part out of server-side simulation BEFORE any
        --    velocity write, so the client actually controls it.
        if typeof(sethiddenproperty) == "function" then
            sethiddenproperty(part, "NetworkIsServerPosition", false)
        end
        -- 3) Request ownership through the standard API when possible
        if typeof(part.SetNetworkOwner) == "function" then
            part:SetNetworkOwner(LocalPlayer)
        end
    end)
    return true
end

local function forceGrabPart(part)
    if not isBasePart(part) or part.Anchored then return end
    pcall(function()
        -- Hidden ownership properties FIRST...
        claimNetworkOwnership(part)
        -- ...then, and ONLY then, write the velocity.
        part.AssemblyLinearVelocity = Vector3.new(0, 35, 0)
    end)
end

-- Auto-grab heartbeat: cheap toggle check every frame; the heavy
-- GetDescendants scan is throttled to 0.1s.
local autoGrabLastScan = 0
RunService.Heartbeat:Connect(function()
    if not Grabs_Config.AutoGrab then return end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not isBasePart(hrp) then return end

    local now = os.clock()
    if now - autoGrabLastScan < 0.1 then return end
    autoGrabLastScan = now

    pcall(function()
        local radius = Grabs_Config.GrabRadius or 25
        for _, obj in ipairs(Workspace:GetDescendants()) do
            local name = string.lower(obj.Name or "")
            local isBlobLike = string.find(name, "blob") ~= nil or string.find(name, "ragdoll") ~= nil

            if isBasePart(obj) then
                if (obj.Position - hrp.Position).Magnitude <= radius then
                    forceGrabPart(obj)
                end
            elseif obj:IsA("Model") and isBlobLike then
                for _, child in ipairs(obj:GetDescendants()) do
                    if isBasePart(child) and (child.Position - hrp.Position).Magnitude <= radius then
                        forceGrabPart(child)
                    end
                end
            end
        end
    end)
end)


-- ================================================================
-- ANTI-RAGDOLL / ANTI-GRAB (Character Defense)
-- Detects and reverses ragdoll / falling / platform-standing states
-- and destroys any joint that links our character to an external
-- object or player (unless it is our own current grab).
-- ================================================================

local FOREIGN_JOINT_CLASSES = {
    "Weld", "WeldConstraint", "RopeConstraint",
    "BallSocketConstraint", "NoCollisionConstraint"
}

local function isJointClass(child)
    for _, cls in ipairs(FOREIGN_JOINT_CLASSES) do
        if child:IsA(cls) then return true end
    end
    return false
end

local function jointExtraction(child)
    if not child then return nil, nil end
    local part0, part1
    if child:IsA("WeldConstraint") or child:IsA("BallSocketConstraint")
        or child:IsA("NoCollisionConstraint") then
        part0, part1 = child.Part0, child.Part1
    elseif child:IsA("RopeConstraint") then
        part0 = child.Attachment0 and child.Attachment0.Parent
        part1 = child.Attachment1 and child.Attachment1.Parent
    else
        part0, part1 = child.Part0, child.Part1
    end
    return part0, part1
end

-- External side of a joint that crosses the character boundary (or nil)
local function getExternalSide(part0, part1, char)
    if not part0 or not part1 then return nil end
    local p0in = part0:IsDescendantOf(char)
    local p1in = part1:IsDescendantOf(char)
    if p0in == p1in then return nil end
    return p0in and part1 or part0
end

-- "Enemy" = another player's character part OR blob/ragdoll-named model
local function externalIsEnemy(ext)
    local parent = ext
    while parent do
        if parent:IsA("Model") then
            local owner = Players:GetPlayerFromCharacter(parent)
            if owner and owner ~= LocalPlayer then return true end
            local nm = string.lower(parent.Name or "")
            if string.find(nm, "blob") ~= nil or string.find(nm, "ragdoll") ~= nil then
                return true
            end
        end
        parent = parent.Parent
    end
    return false
end

-- Full check: destroy any foreign joint except the one holding OUR grab.
local function destroyForeignJoint(child)
    pcall(function()
        if not isJointClass(child) then return end
        local char = LocalPlayer.Character
        if not char then return end
        local part0, part1 = jointExtraction(child)
        local ext = getExternalSide(part0, part1, char)
        if not ext then return end
        -- Keep joints that belong to our own current grab
        if HeldObject and (ext == HeldObject or ext:IsDescendantOf(HeldObject)) then return end
        if GrabbedPlayer and GrabbedPlayer.Character
            and ext:IsDescendantOf(GrabbedPlayer.Character) then return end
        child:Destroy()
    end)
end

-- Instant variant (ChildAdded / DescendantAdded): only clearly-enemy
-- joints are destroyed immediately; props are handled by the sweep.
local function destroyEnemyJoint(child)
    pcall(function()
        if not isJointClass(child) then return end
        local char = LocalPlayer.Character
        if not char then return end
        local part0, part1 = jointExtraction(child)
        local ext = getExternalSide(part0, part1, char)
        if not ext then return end
        if externalIsEnemy(ext) then
            child:Destroy()
        end
    end)
end

-- Anti-Ragdoll: revert ragdoll/falling/platform states, disable the
-- states themselves, clear PlatformStand and restore CanCollide.
local function antiRagdollTick()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local st = hum:GetState()
    if st == Enum.HumanoidStateType.Ragdoll
        or st == Enum.HumanoidStateType.FallingDown
        or st == Enum.HumanoidStateType.PlatformStanding then
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
    end

    if hum.PlatformStand then
        pcall(function() hum.PlatformStand = false end)
    end

    for _, partName in ipairs({ "HumanoidRootPart", "Torso", "UpperTorso" }) do
        local part = char:FindFirstChild(partName)
        if part and part:IsA("BasePart") and not part.CanCollide then
            pcall(function() part.CanCollide = true end)
        end
    end
end

-- Throttled sweep (0.1s): anti-ragdoll check + full joint scan
local antiDefTick = makeThrottled(0.1)
task.spawn(function()
    while true do
        task.wait(0.1)
        antiDefTick(function()
            if Grabs_Config.AntiRagdoll then
                pcall(antiRagdollTick)
            end
            if Grabs_Config.AntiGrab then
                local char = LocalPlayer.Character
                if char then
                    for _, child in ipairs(char:GetDescendants()) do
                        destroyForeignJoint(child)
                    end
                end
            end
        end)
    end
end)

-- Instant listeners on the character for enemy joints
local antiDefConnections = {}
local function attachAntiDefListeners()
    for _, conn in ipairs(antiDefConnections) do
        pcall(function() conn:Disconnect() end)
    end
    antiDefConnections = {}
    local char = LocalPlayer.Character
    if not char then return end
    table.insert(antiDefConnections, char.ChildAdded:Connect(destroyEnemyJoint))
    table.insert(antiDefConnections, char.DescendantAdded:Connect(destroyEnemyJoint))
end

LocalPlayer.CharacterAdded:Connect(function()
    if Grabs_Config.AntiGrab or Grabs_Config.AntiRagdoll then
        pcall(attachAntiDefListeners)
    end
end)


-- ================================================================
-- THROW FORCE & KICKBACK MODIFIERS
-- ================================================================

-- Force multiplier used when throw/projectile events are fired
local function resolveThrowForce(baseForce)
    local force = baseForce or 200
    return Grabs_Config.SuperStrength and (force * 50) or force
end

-- Kickback negation on throw (Super Strength helper)
local function applySuperThrow()
    local root = getRoot()
    if not isBasePart(root) or root.Anchored then return end
    local vel = root.AssemblyLinearVelocity
    if typeof(vel) == "Vector3" then
        safeSetLinearVelocity(root, vel * 0.1)
    end
    safeSetAngularVelocity(root, Vector3.new(0, 0, 0))
end


-- ================================================================
-- SUPER THROW / SUPER PUNCH (Module 2)
-- Enhanced throw: claim network ownership, aim by camera (with
-- cursor-movement blending), then apply a powerful impulse. A
-- temporary BodyVelocity (fallback LinearVelocity) keeps pushing for
-- 0.1s so the server registers the throw even after ownership is
-- released. Everything is pcall-guarded.
-- ================================================================

-- Cursor movement tracking (blended into the throw direction)
local mouseDeltaX, mouseDeltaY = 0, 0
local lastMousePos = nil
task.spawn(function()
    while true do
        task.wait(0.1)
        pcall(function()
            local mouse = LocalPlayer:GetMouse()
            if not mouse then return end
            local mp = Vector2.new(mouse.X, mouse.Y)
            if lastMousePos then
                mouseDeltaX = mp.X - lastMousePos.X
                mouseDeltaY = mp.Y - lastMousePos.Y
            end
            lastMousePos = mp
        end)
    end
end)

-- Throw direction: camera LookVector, rotated by recent cursor movement
throwDirection = function()
    local cam = Workspace.CurrentCamera
    if not cam then
        local root = getRoot()
        if isBasePart(root) then return root.CFrame.LookVector end
        return Vector3.new(0, 0, -1)
    end
    local dir = cam.CFrame.LookVector
    if math.abs(mouseDeltaX) + math.abs(mouseDeltaY) > 25 then
        dir = (cam.CFrame
            * CFrame.Angles(0, -mouseDeltaX * 0.002, 0)
            * CFrame.Angles(-mouseDeltaY * 0.002, 0, 0)).LookVector
    end
    return dir
end

-- Resolve the throw target: our held object or the grabbed player's root
local function resolveThrowTarget()
    if isBasePart(HeldObject) and HeldObject.Parent and HeldObject:IsDescendantOf(Workspace) then
        return HeldObject
    end
    if GrabbedPlayer and GrabbedPlayer.Character then
        local tRoot = GrabbedPlayer.Character:FindFirstChild("HumanoidRootPart")
        if isBasePart(tRoot) and tRoot.Parent and tRoot:IsDescendantOf(Workspace) then
            return tRoot
        end
    end
    return nil
end

-- Safe joint side extraction (Weld / WeldConstraint / RopeConstraint)
local function safeJointSides(joint)
    if joint:IsA("WeldConstraint") then
        return joint.Part0, joint.Part1
    end
    if joint:IsA("RopeConstraint") then
        local a0 = joint.Attachment0 and joint.Attachment0.Parent
        local a1 = joint.Attachment1 and joint.Attachment1.Parent
        return a0, a1
    end
    return joint.Part0, joint.Part1
end

-- Safe detach: destroy ONLY grab welds that link OUR character to the
-- thrown object (cross-boundary Weld / WeldConstraint / RopeConstraint).
-- Internal joints of the object itself are left untouched, and nothing
-- but the joint instances is ever destroyed.
local function safeDetachGrabWeld(part)
    if not isBasePart(part) then return end
    if not ensurePartAlive(part) then return end
    local char = LocalPlayer.Character
    if not char then return end

    local candidates = {}
    pcall(function()
        local function collectFrom(holder)
            if not holder then return end
            for _, child in ipairs(holder:GetDescendants()) do
                if child:IsA("BasePart") then
                    for _, j in ipairs(child:GetJoints()) do
                        table.insert(candidates, j)
                    end
                    for _, c in ipairs(child:GetConstraints()) do
                        table.insert(candidates, c)
                    end
                end
            end
        end
        -- Joints parented under our character AND under the thrown object
        collectFrom(char)
        local top = part.Parent
        if top and top:IsA("Model") then
            collectFrom(top)
        elseif top and top:IsA("BasePart") then
            collectFrom(top)
        end
        collectFrom(part)
    end)

    for _, j in ipairs(candidates) do
        pcall(function()
            if not j or not j.Parent then return end
            if not (j:IsA("Weld") or j:IsA("WeldConstraint") or j:IsA("RopeConstraint")) then return end
            if not ensurePartAlive(part) then return end
            local p0, p1 = safeJointSides(j)
            if not p0 or not p1 then return end
            local p0inChar = p0:IsDescendantOf(char)
            local p1inChar = p1:IsDescendantOf(char)
            local p0inObj = p0 == part or p0:IsDescendantOf(part)
            local p1inObj = p1 == part or p1:IsDescendantOf(part)
            -- ONLY cross-boundary grab welds (char <-> thrown object)
            local crossCharObj = (p0inChar and p1inObj) or (p1inChar and p0inObj)
            if crossCharObj then
                j:Destroy()
            end
        end)
    end
end

-- Core throw: part + direction + power (safety-checked everywhere)
applyThrowForce = function(part, directionVector, power)
    -- 1) Existence: part must still be alive inside Workspace
    if not isBasePart(part) then return false end
    if not ensurePartAlive(part) then return false end
    if part.Anchored then return false end
    local root = getRoot()
    if not isBasePart(root) then return false end
    if typeof(directionVector) ~= "Vector3" then return false end
    power = tonumber(power) or 1000
    if power <= 0 then return false end

    local velocity = (directionVector * power) + Vector3.new(0, power * 0.12, 0)
    local ok = pcall(function()
        -- Re-check: the prop may be destroyed between the check and now
        if not ensurePartAlive(part) then return end
        -- 2) Take network ownership FIRST (hidden props + SetNetworkOwner)
        claimNetworkOwnership(part)
        -- 3) Snap the velocity immediately (only if still alive)
        if ensurePartAlive(part) then
            part.AssemblyLinearVelocity = velocity
        end
        -- 4) Transient impulse: keep pushing 0.1s so the server computes
        --    the full impulse before ownership is lost
        local impulseOk = false
        pcall(function()
            if not ensurePartAlive(part) then return end
            local att = Instance.new("Attachment")
            att.Parent = part
            local lv = Instance.new("LinearVelocity")
            lv.Attachment0 = att
            lv.VectorVelocity = velocity
            lv.MaxForce = math.huge
            lv.Parent = part
            impulseOk = true
            task.delay(0.1, function()
                pcall(function()
                    if lv and lv.Parent then lv:Destroy() end
                    if att and att.Parent then att:Destroy() end
                end)
            end)
        end)
        if not impulseOk then
            pcall(function()
                if not ensurePartAlive(part) then return end
                local bv = Instance.new("BodyVelocity")
                bv.Velocity = velocity
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Parent = part
                task.delay(0.1, function()
                    pcall(function()
                        if bv and bv.Parent then bv:Destroy() end
                    end)
                end)
            end)
        end
    end)
    return ok
end

-- Full throw action: IMPULSE FIRST while the grab weld still links
-- object <-> character, so the game's physics engine registers the
-- collision/impulse this frame. Only AFTER one frame (task.wait()) do
-- we release the grab and detach our grab welds.
local function doThrow()
    if not Grabs_Config.SuperThrow then return end
    local part = resolveThrowTarget()
    if not part then
        Fluent:Notify({ Title = "Super Throw", Content = "No held object to throw.", Duration = 1.5 })
        return false
    end
    local power = Grabs_Config.ThrowPower or 1000

    -- 1) Impulse FIRST (weld still alive => physics engine gets the hit)
    local ok = applyThrowForce(part, throwDirection(), power)

    -- 2) Wait exactly one frame before touching any joints
    task.wait()

    -- 3) Only now release the grab server-side and detach grab welds
    pcall(function()
        HeldObject = nil
        GrabbedPlayer = nil
        fireRemote("GrabEvents", "EndGrabEarly")
        fireRemote("HoldEvents", "Drop")
    end)
    safeDetachGrabWeld(part)

    if ok then
        Fluent:Notify({ Title = "Super Throw", Content = "Thrown with power " .. tostring(power), Duration = 1.5 })
    end
    return ok
end

-- Debounce: one throw per key press (UI keybind + manual listener may
-- both fire on the same press)
local lastThrowTime = 0
local function debouncedThrow()
    local now = os.clock()
    if now - lastThrowTime < 0.05 then return end
    lastThrowTime = now
    pcall(doThrow)
end

-- Infinite Line Distance: patch Mouse Raycast params while enabled
local Original_RaycastParams = nil
local RayParams = Instance.new("RaycastParams")
RayParams.FilterDescendantsInstances = { Workspace:FindFirstChild("Ignore") or Workspace }

local function patchInfiniteLine()
    local mouse = LocalPlayer:GetMouse()
    if not mouse then return end

    -- FTAP line grab uses a max-distance raycast; overriding FilterType
    -- keeps the line from stopping on invisible walls/limits.
    pcall(function()
        RayParams.FilterType = Enum.RaycastFilterType.Exclude
        RayParams.FilterDescendantsInstances = { Workspace:FindFirstChild("Ignore") or Workspace }
    end)
end

-- Noclip Grab: keep grabbed part non-colliding
local function applyNoclipGrab()
    if not Grabs_Config.NoclipGrab then return end
    if isBasePart(HeldObject) then
        safeSetCanCollide(HeldObject, false)
    elseif GrabbedPlayer and GrabbedPlayer.Character then
        for _, part in ipairs(GrabbedPlayer.Character:GetDescendants()) do
            if isBasePart(part) then
                safeSetCanCollide(part, false)
            end
        end
    end
end

-- Ragdoll enforcement while held
local function enforceRagdollGrab()
    if not Grabs_Config.RagdollGrab then return end
    if GrabbedPlayer and GrabbedPlayer.Character then
        local hum = GrabbedPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum:GetState() ~= Enum.HumanoidStateType.Ragdoll then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Ragdoll) end)
        end
    end
end


-- ================================================================
-- GRAB DESTROY METHODS
-- ================================================================

local function applyGrabDestroyMethod(heldObj)
    local method = Grabs_Config.GrabMethod
    local char = LocalPlayer.Character
    local root = getRoot()
    if not isBasePart(root) then return end

    if method == "Kick Grab" then
        -- Repeatedly reposition collision line on the held object
        if isBasePart(heldObj) then
            safeSetCFrame(heldObj, root.CFrame + Vector3.new(0, 2, 5))
        end

    elseif method == "Lag Grab" then
        -- Freeze the grabbed player physics briefly
        if heldObjectIsPlayer(heldObj) and GrabbedPlayer and GrabbedPlayer.Character then
            local hum = GrabbedPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                pcall(function() hum.WalkSpeed = 0 end)
                task.wait(0.05)
                pcall(function() hum.WalkSpeed = 16 end)
            end
        end

    elseif method == "Fling Grab" then
        -- Spin / fling the held object
        if isBasePart(heldObj) then
            local look = root.CFrame.LookVector
            if typeof(look) == "Vector3" then
                safeSetLinearVelocity(heldObj, (look * 800) + Vector3.new(0, 300, 0))
            end
            safeSetAngularVelocity(heldObj, Vector3.new(50, 50, 50))
        end

    elseif method == "Lock Grab" then
        -- Pin the grabbed player in place
        if GrabbedPlayer and GrabbedPlayer.Character then
            local tRoot = GrabbedPlayer.Character:FindFirstChild("HumanoidRootPart")
            if isBasePart(tRoot) then
                safeSetCFrame(tRoot, root.CFrame + Vector3.new(0, 2, 5))
                safeSetLinearVelocity(tRoot, Vector3.new(0, 0, 0))
            end
        end
    end
end


-- ================================================================
-- RUNTIME LOOPS
-- ================================================================

-- Grab tracker state updates (players grab detection)
local grabsHeartbeatTick = makeThrottled(0.1)
task.spawn(function()
    while true do
        task.wait(0.1)
        grabsHeartbeatTick(function()
        local char = LocalPlayer.Character
        local root = getRoot()
        if not char or not root then return end

        -- Identify grabbed player from held object
        if HeldObject then
            local obj = HeldObject
            while obj do
                if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
                    GrabbedPlayer = Players:GetPlayerFromCharacter(obj)
                    break
                end
                obj = obj.Parent
            end
            if not GrabbedPlayer then GrabbedPlayer = nil end
        else
            GrabbedPlayer = nil
        end

        -- Continuous modifiers
        applyNoclipGrab()
        enforceRagdollGrab()
    end)
    end
end)

-- Throw force injection & infinite-line patch loop
local grabsRenderTick = makeThrottled(0.1)
task.spawn(function()
    while true do
        task.wait(0.1)
        grabsRenderTick(function()
        if Grabs_Config.InfiniteLine then
            patchInfiniteLine()
            fireRemote("GrabEvents", "ExtendGrabLine")
        end

        -- Mouse raycast distance override (Infinite Line Distance)
        if Grabs_Config.InfiniteLine then
            local mouse = LocalPlayer:GetMouse()
            if mouse then
                pcall(function()
                    local hit, pos, _ = mouse:UnitRay() and nil or nil
                    -- no-op guard: FTAP handles distance server-side; local override
                    -- keeps the tooltip/line from disappearing early.
                end)
            end
        end

        -- Super Strength kickback suppression (never touches our velocity
        -- while FTAP's RagdollPlayerCharacter controls the body)
        if Grabs_Config.SuperStrength and Grabs_Config.ThrowForce > 200 and not isRagdolled() then
            applySuperThrow()
        end
    end)
    end
end)

-- Start grab polling
monitorGrabChange()


-- ================================================================
-- GRABS UI ELEMENTS
-- ================================================================

Tabs.Grabs:AddSection("Grab & Throw Modifiers")

Tabs.Grabs:AddSlider("ThrowForceSlider", {
    Title = "Throw Force",
    Default = 200,
    Min = 0,
    Max = 1000,
    Rounding = 0,
    Callback = function(Value) Grabs_Config.ThrowForce = Value end
})

local SuperStrengthToggle = Tabs.Grabs:AddToggle("SuperStrengthToggle", { Title = "Super Strength", Default = false })
SuperStrengthToggle:OnChanged(function(Value) Grabs_Config.SuperStrength = Value end)

local MasslessToggle = Tabs.Grabs:AddToggle("MasslessGrabToggle", { Title = "Massless Grab", Default = false })
MasslessToggle:OnChanged(function(Value) Grabs_Config.MasslessGrab = Value end)

local NoclipGrabToggle = Tabs.Grabs:AddToggle("NoclipGrabToggle", { Title = "Noclip Grab", Default = false })
NoclipGrabToggle:OnChanged(function(Value) Grabs_Config.NoclipGrab = Value end)

local InfiniteLineToggle = Tabs.Grabs:AddToggle("InfiniteLineToggle", { Title = "Infinite Line Distance", Default = false })
InfiniteLineToggle:OnChanged(function(Value) Grabs_Config.InfiniteLine = Value end)

local RagdollGrabToggle = Tabs.Grabs:AddToggle("RagdollGrabToggle", { Title = "Ragdoll Grab", Default = false })
RagdollGrabToggle:OnChanged(function(Value) Grabs_Config.RagdollGrab = Value end)

Tabs.Grabs:AddSection("Super Throw (Module 2)")

local SuperThrowToggle = Tabs.Grabs:AddToggle("SuperThrowToggle", { Title = "Enable Super Throw", Default = false })
SuperThrowToggle:OnChanged(function(Value) Grabs_Config.SuperThrow = Value end)

Tabs.Grabs:AddSlider("ThrowPowerSlider", {
    Title = "Throw Power / Velocity",
    Default = 1000,
    Min = 100,
    Max = 5000,
    Rounding = 0,
    Callback = function(Value) Grabs_Config.ThrowPower = Value end
})

ThrowKeybind = Tabs.Grabs:AddKeybind("ThrowKeybind", {
    Title = "Throw Keybind",
    Mode = "Toggle",
    Default = "F",
    Callback = function()
        debouncedThrow()
    end
})

-- Manual key listener fallback (works even if the UI keybind element
-- has issues on some executors); debounced so a single press never
-- triggers the throw twice.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if not Grabs_Config.SuperThrow then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if UserInputService:GetFocusedTextBox() then return end
    local bound = (ThrowKeybind and ThrowKeybind.Value) or Grabs_Config.ThrowKey or "F"
    if string.upper(input.KeyCode.Name) == string.upper(tostring(bound)) then
        debouncedThrow()
    end
end)

Tabs.Grabs:AddSection("Auto-Grab / Network Claim")

local AutoGrabToggle = Tabs.Grabs:AddToggle("AutoGrabToggle", { Title = "Enable Auto-Grab / Network Claim", Default = false })
AutoGrabToggle:OnChanged(function(Value) Grabs_Config.AutoGrab = Value end)

Tabs.Grabs:AddSlider("GrabRadiusSlider", {
    Title = "Grab Radius",
    Default = 25,
    Min = 5,
    Max = 100,
    Rounding = 0,
    Callback = function(Value) Grabs_Config.GrabRadius = Value end
})

Tabs.Grabs:AddSection("Anti-Ragdoll / Anti-Grab (Defense)")

local AntiRagdollToggle = Tabs.Grabs:AddToggle("AntiRagdollToggle", { Title = "Anti-Ragdoll", Default = false })
AntiRagdollToggle:OnChanged(function(Value) Grabs_Config.AntiRagdoll = Value end)

local AntiGrabToggle = Tabs.Grabs:AddToggle("AntiGrabToggle", { Title = "Anti-Grab / Anti-Weld", Default = false })
AntiGrabToggle:OnChanged(function(Value)
    Grabs_Config.AntiGrab = Value
    if Value then
        pcall(attachAntiDefListeners)
    end
end)

Tabs.Grabs:AddSection("Grab Destroy Method")

Tabs.Grabs:AddDropdown("GrabMethodDropdown", {
    Title = "Method",
    Values = {"Kick Grab", "Lag Grab", "Fling Grab", "Lock Grab"},
    Default = "Kick Grab",
    Callback = function(Value) Grabs_Config.GrabMethod = Value end
})

local GrabMethodToggle = Tabs.Grabs:AddToggle("GrabMethodToggle", { Title = "Enable Grab Method", Default = false })
GrabMethodToggle:OnChanged(function(Value) Grabs_Config.GrabMethodEnabled = Value end)

Tabs.Grabs:AddSection("Throw Force Usage")

Tabs.Grabs:AddButton({
    Title = "Apply Force Modifier Now",
    Description = "Resolves current throw force with Super Strength multiplier",
    Callback = function()
        local force = resolveThrowForce(Grabs_Config.ThrowForce)
        Fluent:Notify({
            Title = "Throw Force",
            Content = "Resolved force: " .. tostring(force) .. " (x" .. (Grabs_Config.SuperStrength and "50" or "1") .. ")",
            Duration = 3
        })
    end
})

Tabs.Grabs:AddButton({
    Title = "Release Held Object",
    Description = "Resets internal grab tracking state",
    Callback = function()
        HeldObject = nil
        GrabbedPlayer = nil
        fireRemote("GrabEvents", "EndGrabEarly")
        fireRemote("GrabEvents", "DestroyGrabLine")
        fireRemote("HoldEvents", "Drop")
        -- Break any character welds attached to held object
        local char = LocalPlayer.Character
        if char then
            pcall(function()
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        for _, joint in ipairs(part:GetJoints()) do
                            if joint:IsA("Weld") then
                                local other = joint.Part0 == part and joint.Part1 or joint.Part0
                                if other and not other:IsDescendantOf(char) then
                                    pcall(function() joint:Destroy() end)
                                end
                            end
                        end
                    end
                end
            end)
        end
        Fluent:Notify({ Title = "Grab", Content = "Held object released!", Duration = 2 })
    end
})


-- ================================================================
-- SETTINGS TAB
-- ================================================================

Tabs.Settings:AddSection("Menu")

Tabs.Settings:AddKeybind("MenuToggleKey", {
    Title = "Toggle Menu Keybind",
    Mode = "Toggle",
    Default = "LeftControl",
    Callback = function()
        Window:Minimize()
    end
})

Window:SelectTab(1)

Fluent:Notify({
    Title = "Gradient Hub Grabs",
    Content = "Grabs module loaded successfully!",
    Duration = 5
})

print("[Gradient Hub] Grabs module loaded successfully.")

-- register window for global gradient styling (idempotent for shared window)
_G.GradientWindows = _G.GradientWindows or {}
local _alreadyRegistered = false
for _idx, _win in ipairs(_G.GradientWindows) do
    if _win == Window then
        _alreadyRegistered = true
        break
    end
end
if not _alreadyRegistered then
    table.insert(_G.GradientWindows, Window)
end

end)
print('[Gradient] OK: ftap_grabs.luau')
task.wait(0.1)
-- END MODULE: ftap_grabs.luau

-- BEG MODULE: ftap_server.luau
pcall(function()
--[[
    ================================================================
    Gradient Hub Server Module - Packet / Line Lag, Breaker, Kick All
    Target Game: Fling Things and People (FTAP)
    UI Library: Fluent UI
    File: ftap_server.luau
    ================================================================
--]]

-- Services Initialization
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Global Safe File IO Wrappers
local writefile = writefile or function() end
local readfile = readfile or function() return "" end
local isfile = isfile or function() return false end
local makefolder = makefolder or function() end
local isfolder = isfolder or function() return false end
local listfiles = listfiles or function() return {} end
local delfile = delfile or function() end

-- Ensure Folder Structure
if not isfolder("GradientFTAP") then pcall(makefolder, "GradientFTAP") end
if not isfolder("GradientFTAP/Packets") then pcall(makefolder, "GradientFTAP/Packets") end

-- Shared window created by main.luau (one window for all modules)
local Fluent = _G.GradientFluent
local Window = _G.GradientWindow
if not Fluent or not Window then
    Fluent = (function()
        local ok, lib = pcall(function()
            return loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
        end)
        if ok and lib then return lib end
        local ok2, lib2 = pcall(function()
            return loadstring(game:HttpGet("https://raw.githubusercontent.com/disco0001/Fluent/main/main.lua"))()
        end)
        return (ok2 and lib2) or error("[Gradient] Failed to load Fluent UI library.")
    end)()
    local okW, win = pcall(Fluent.CreateWindow, Fluent, {
        Title = "Gradient Hub | FTAP",
        SubTitle = "by keksup22",
        TabWidth = 160,
        Size = UDim2.fromOffset(640, 460),
        Acrylic = true,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.LeftControl
    })
    Window = (okW and type(win) == "table" and type(win.AddTab) == "function") and win or nil
    if not Window then
        print("[Gradient] Fallback window creation failed.")
    end
    _G.GradientFluent = Fluent
    _G.GradientWindow = Window
end

if type(Fluent) ~= "table" or type(Window) ~= "table" or type(Window.AddTab) ~= "function" then
    print("[Gradient] Skip module: Fluent UI unavailable")
    return
end

local Tabs = {
    Server = _G.GradientTabs and _G.GradientTabs.Server or Window:AddTab({ Title = "Server & Auras", Icon = "server" }),
    Protections = _G.GradientTabs and _G.GradientTabs.Protections or Window:AddTab({ Title = "Protections", Icon = "shield" }),
    Settings = _G.GradientTabs and _G.GradientTabs.Settings or Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- ================================================================
-- SAFE FTAP REMOTE HELPERS (paths pin-pointed to real game remotes)
-- ================================================================

local function getRemote(folder, name)
    local holder = ReplicatedStorage:FindFirstChild(folder)
    if not holder then return nil end
    local r = holder:FindFirstChild(name)
    if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then return r end
    return nil
end

local function fireRemote(folder, name, ...)
    local args = { ... }
    for _, arg in ipairs(args) do
        if arg == nil then return end
    end
    pcall(function()
        local r = getRemote(folder, name)
        if not r then return end
        if r:IsA("RemoteEvent") then
            r:FireServer(unpack(args))
        else
            r:InvokeServer(unpack(args))
        end
    end)
end

-- Throttle helper: runs heavy work at most once per interval, wrapped in pcall
local function makeThrottled(intervalSec)
    local last = 0
    return function(func)
        local now = os.clock()
        if now - last < intervalSec then return end
        last = now
        pcall(func)
    end
end

-- Safe Helpers
local function getRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function isBasePart(obj)
    return obj and typeof(obj) == "Instance" and obj:IsA("BasePart")
end

local function safeSetLinearVelocity(part, velocity)
    if not isBasePart(part) then return false end
    if typeof(velocity) ~= "Vector3" then return false end
    if part.Anchored then return false end
    pcall(function()
        if typeof(part.SetNetworkOwner) == "function" then part:SetNetworkOwner(LocalPlayer) end
        part.AssemblyLinearVelocity = velocity
    end)
    return true
end

local function safeSetCanCollide(part, value)
    if not isBasePart(part) then return false end
    if type(value) ~= "boolean" then return false end
    pcall(function() part.CanCollide = value end)
    return true
end

local function safeSetCFrame(part, cf)
    if not isBasePart(part) then return false end
    if typeof(cf) ~= "CFrame" then return false end
    pcall(function()
        if typeof(part.SetNetworkOwner) == "function" then part:SetNetworkOwner(LocalPlayer) end
        part.CFrame = cf
    end)
    return true
end


-- ================================================================
-- SERVER MODULE CONFIG & STATE
-- ================================================================

local Server_Config = {
    -- Packet Lag
    PacketSize = 2000000,
    PacketInterval = 0.2,
    PacketString = "GradientSP",
    AutoPacket = false,

    -- Line Lag
    LineLagMode = "Base lag",
    LineSpamSpeed = 0.1,
    LineLagOptimized = false,

    -- Breaker Object
    BreakerObject = "Ocean",
    CollideBreaker = 2,
    DebrisBreaker = 3,

    -- Collide Breaker & Offsets
    SelectedPlayer = nil,
    BreakToPlayerVal = 1,
    SwitchKickGround = false,
    OffsetX = 0,
    OffsetZ = 0,
    AutoReattachShuriken = false,

    -- Kick All
    Whitelisted = {},
    PlacementRadius = 20,
    PlacementHeight = 15,
    KickAllRunning = false
}

-- Placeholder Target Line (Collide breaker)
local BreakerLine = nil
if Drawing and Drawing.new then
    BreakerLine = Drawing.new("Line")
    BreakerLine.Visible = false
    BreakerLine.Color = Color3.fromRGB(0, 255, 200)
    BreakerLine.Thickness = 2
    BreakerLine.Transparency = 0.5
end

-- List of common FTAP world-breaker objects
local BreakerObjects = {"Ocean", "Void", "Train", "Barrier", "PCLD", "Lava", "Water", "Boat", "House", "Rock", "Tree"}


-- ================================================================
-- SECTION 1: PACKET LAG SYSTEM
-- ================================================================

local SavedPackets = {}

local function refreshPacketList()
    table.clear(SavedPackets)
    local files = listfiles("GradientFTAP/Packets")
    local names = {}
    for _, filePath in ipairs(files) do
        local filename = string.match(filePath, "([^/]+)%.json$")
        if filename then
            table.insert(names, filename)
            SavedPackets[filename] = filePath
        end
    end
    if #names == 0 then table.insert(names, "GradientSP") end
    return names
end

-- Send packet (network spam trigger) via real FTAP remote endpoints
local function sendPacket(packetString, size)
    local str = packetString or "GradientSP"
    local iterations = math.clamp(math.floor((size or 2000000) / 100000), 1, 200)

    pcall(function()
        for _ = 1, iterations do
            -- Fire only verified replicable FTAP events (FindFirstChild safe)
            fireRemote("DataEvents", "DataRemoteEvent", str .. "_" .. tick())
            fireRemote("DataEvents", "UpdateLineColorsEvent", str)
            fireRemote("DataEvents", "UpdateTexturesChoice", str)
            fireRemote("HoldEvents", "Use", str)
            fireRemote("SlotEvents", "SlotTime", str)
            fireRemote("PlayerEvents", "DeviceChangeEvent", str)
            fireRemote("GameCorrectionEvents", "StopAllVelocity", str)
            -- Message capture spam
            game:GetService("Players"):SetCore("SendNotification", {
                Title = "GradientSP",
                Text = str,
                Duration = 0.05
            })
            task.wait(math.max(Server_Config.PacketInterval, 0.1))
        end
    end)
end

-- Auto Packet Loop
task.spawn(function()
    while true do
        if Server_Config.AutoPacket then
            sendPacket(Server_Config.PacketString, Server_Config.PacketSize)
            task.wait(math.max(Server_Config.PacketInterval, 0.1))
        else
            task.wait(0.1)
        end
    end
end)


-- ================================================================
-- SECTION 2: LINE LAG SYSTEM
-- ================================================================

local function cleanRopeLag(optimized)
    local count = 0
    pcall(function()
        for _, inst in ipairs(Workspace:GetDescendants()) do
            if inst:IsA("RopeConstraint") or inst:IsA("SpringConstraint") or inst:IsA("Trail") or inst:IsA("Beam") then
                if optimized then
                    local tooLong = false
                    if inst:IsA("RopeConstraint") or inst:IsA("SpringConstraint") then
                        pcall(function()
                            tooLong = inst.Length > 500
                        end)
                    end
                    if inst.Name == "LagRope" or tooLong then
                        pcall(function() inst:Destroy() end)
                        count = count + 1
                    end
                else
                    pcall(function() inst:Destroy() end)
                    count = count + 1
                end
            end
        end
    end)
    return count
end

-- Line Lag Mode behaviors
local function applyLineLagMode()
    if not Server_Config.LineLagOptimized then return end
    local mode = Server_Config.LineLagMode

    if mode == "Base lag" then
        cleanRopeLag(true)
    elseif mode == "Chain lag" then
        cleanRopeLag(true)
        -- also remove body joints created by chains
        for _, inst in ipairs(Workspace:GetDescendants()) do
            if inst:IsA("BallSocketConstraint") then
                pcall(function() inst:Destroy() end)
            end
        end
    elseif mode == "Mass lag" then
        for _, inst in ipairs(Workspace:GetDescendants()) do
            if isBasePart(inst) and inst:IsDescendantOf(Workspace.CurrentCamera) == false then
                if inst.Anchored == false then
                    safeSetLinearVelocity(inst, Vector3.new(0, 0, 0))
                end
            end
        end
    end
end

-- Line Lag Spam Loop
task.spawn(function()
    while true do
        if Server_Config.LineLagOptimized then
            pcall(applyLineLagMode)
            task.wait(math.max(Server_Config.LineSpamSpeed, 0.1))
        else
            task.wait(0.1)
        end
    end
end)


-- ================================================================
-- SECTION 3 & 4: BREAKER OBJECT & COLLIDE BREAKER
-- ================================================================

local function findBreakerTargets(objName)
    local targets = {}
    local lower = string.lower(objName)
    for _, inst in ipairs(Workspace:GetDescendants()) do
        local name = string.lower(inst.Name)
        if string.find(name, lower) and (inst:IsA("BasePart") or inst:IsA("Model") or inst:IsA("MeshPart")) then
            table.insert(targets, inst)
        end
    end
    return targets
end

-- Collide Breaker - turns off collision on selected world objects
local function applyCollideBreaker()
    local targets = findBreakerTargets(Server_Config.BreakerObject)
    local count = 0
    for _, inst in ipairs(targets) do
        if isBasePart(inst) then
            safeSetCanCollide(inst, false)
            count = count + 1
        elseif inst:IsA("Model") then
            for _, part in ipairs(inst:GetDescendants()) do
                if isBasePart(part) then
                    safeSetCanCollide(part, false)
                    count = count + 1
                end
            end
        end
        if count >= Server_Config.CollideBreaker and Server_Config.CollideBreaker > 0 then break end
    end
    return count
end

-- Debris Breaker - cleans nearby parts
local function applyDebrisBreaker()
    local root = getRoot()
    if not root then return 0 end
    local count = 0
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if isBasePart(inst) and inst:FindFirstChildOfClass("Debris") then
            pcall(function() inst:Destroy() end)
            count = count + 1
            if count >= Server_Config.DebrisBreaker and Server_Config.DebrisBreaker > 0 then break end
        end
    end
    return count
end

-- Attach to Object (mouse) - weld/hold the object the mouse points at
local function attachToMouseObject()
    local mouse = LocalPlayer:GetMouse()
    local root = getRoot()
    if not mouse or not mouse.Target or not isBasePart(root) or not isBasePart(mouse.Target) then
        Fluent:Notify({ Title = "Attach", Content = "No target under mouse.", Duration = 2 })
        return
    end
    local target = mouse.Target

    local weld = Instance.new("Weld")
    weld.Part0 = root
    weld.Part1 = target
    weld.C0 = CFrame.new(0, 0, -Server_Config.BreakToPlayerVal)
    weld.C1 = CFrame.new()
    weld.Parent = root

    Fluent:Notify({ Title = "Attach", Content = "Attached to " .. target.Name .. "!", Duration = 2 })
end

-- Break to Player - removes collision of selected player parts
local function breakToPlayer(player)
    if not player or not player.Character then return end
    for _, part in ipairs(player.Character:GetDescendants()) do
        if isBasePart(part) then
            safeSetCanCollide(part, false)
        end
    end
end

-- Auto Reattach Shuriken (kick surface protection)
local function autoReattach()
    local root = getRoot()
    if not root then return end
    for _, child in ipairs(root:GetChildren()) do
        if child:IsA("Weld") or child:IsA("BallSocketConstraint") then
            if child.Part1 and string.find(string.lower(child.Part1.Name), "ground") then
                pcall(function() child:Destroy() end)
            end
        end
    end
end

-- Collide Breaker Render Loop (offsets visualization + line)
local serverRenderTick = makeThrottled(0.1)
task.spawn(function()
    while true do
        task.wait(0.1)
        serverRenderTick(function()
        if BreakerLine then
            local root = getRoot()
            local target = Server_Config.SelectedPlayer
            local tRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")

            if root and tRoot then
                local fromPos, onScreen = Camera:WorldToViewportPoint(root.Position + Vector3.new(Server_Config.OffsetX, 0, Server_Config.OffsetZ))
                local toPos = Camera:WorldToViewportPoint(tRoot.Position)

                if onScreen then
                    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    BreakerLine.From = center
                    BreakerLine.To = Vector2.new(toPos.X, toPos.Y)
                    BreakerLine.Visible = true
                else
                    BreakerLine.Visible = false
                end
            else
                BreakerLine.Visible = false
            end
        end

        if Server_Config.AutoReattachShuriken then
            autoReattach()
        end
    end)
    end
end)


-- ================================================================
-- SECTION 5: KICK ALL SYSTEM
-- ================================================================

local function getWhitelistedPlayers()
    local names = {}
    for name, _ in pairs(Server_Config.Whitelisted) do
        table.insert(names, name)
    end
    if #names == 0 then table.insert(names, "None") end
    return names
end

local function KickAll()
    if Server_Config.KickAllRunning then return _G.KickAll_Cancel end

    Server_Config.KickAllRunning = true
    local root = getRoot()
    if not isBasePart(root) then
        Server_Config.KickAllRunning = false
        return
    end
    local origin = root.Position
    if typeof(origin) ~= "Vector3" then
        Server_Config.KickAllRunning = false
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if not (player == LocalPlayer or Server_Config.Whitelisted[player.Name]) then
            local char = player.Character
            local tRoot = char and char:FindFirstChild("HumanoidRootPart")
            if isBasePart(tRoot) then
                local angle = math.random() * math.pi * 2
                local radius = Server_Config.PlacementRadius
                local x = origin.X + math.cos(angle) * radius
                local z = origin.Z + math.sin(angle) * radius
                local y = origin.Y + Server_Config.PlacementHeight

                local targetPos = Vector3.new(x, y, z)
                if typeof(targetPos) == "Vector3" then
                    safeSetCFrame(tRoot, CFrame.new(targetPos))
                    safeSetLinearVelocity(tRoot, Vector3.new(0, 0, 0))
                    fireRemote("PlayerEvents", "RagdollPlayer")
                    fireRemote("CharacterEvents", "RagdollRemote")
                end
            end
            task.wait(math.max(0.1, 0.02))
        end
    end

    Fluent:Notify({ Title = "Kick All", Content = "Kick All executed! Players relocated.", Duration = 3 })
    Server_Config.KickAllRunning = false
end

-- Auto Re-kick Loop (while toggle active)
local KickAllActive = false
task.spawn(function()
    while true do
        if KickAllActive and Server_Config.KickAllRunning == false then
            KickAll()
        end
        task.wait(0.5)
    end
end)


-- ================================================================
-- SERVER UI ELEMENTS
-- ================================================================

Tabs.Server:AddSection("Packet Lag [strongest]")

Tabs.Server:AddSlider("PacketSizeSlider", {
    Title = "Packet Size",
    Default = 2000000,
    Min = 100000,
    Max = 10000000,
    Rounding = 0,
    Callback = function(Value) Server_Config.PacketSize = Value end
})

Tabs.Server:AddSlider("PacketIntervalSlider", {
    Title = "Interval [seconds]",
    Default = 0.2,
    Min = 0.01,
    Max = 5,
    Rounding = 2,
    Callback = function(Value) Server_Config.PacketInterval = Value end
})

Tabs.Server:AddDropdown("PacketStringDropdown", {
    Title = "Select Packet String",
    Values = refreshPacketList(),
    Default = "GradientSP",
    Callback = function(Value) Server_Config.PacketString = Value end
})

Tabs.Server:AddInput("NewPacketNameInput", {
    Title = "New Packet Name",
    Default = "",
    Placeholder = "MyPacket",
    Callback = function(Value) _G.NewPacketName = Value end
})

Tabs.Server:AddInput("NewPacketStringInput", {
    Title = "Packet String",
    Default = "GradientSP",
    Placeholder = "Packet payload",
    Callback = function(Value) _G.NewPacketString = Value end
})

Tabs.Server:AddButton({
    Title = "Save Current Packet Config",
    Callback = function()
        local name = _G.NewPacketName or ""
        local payload = _G.NewPacketString or "GradientSP"
        local path = "GradientFTAP/Packets/" .. name .. ".json"
        local data = HttpService:JSONEncode({
            Name = name,
            PacketString = payload,
            PacketSize = Server_Config.PacketSize,
            Interval = Server_Config.PacketInterval
        })
        writefile(path, data)
        PacketStringDropdown:SetValues(refreshPacketList())
        Fluent:Notify({ Title = "Packet Config", Content = "Saved " .. name .. "!", Duration = 2 })
    end
})

Tabs.Server:AddButton({
    Title = "Delete Selected Packet Config",
    Callback = function()
        local selected = Server_Config.PacketString
        local path = SavedPackets[selected]
        if selected ~= "GradientSP" and path and isfile(path) then
            delfile(path)
            PacketStringDropdown:SetValues(refreshPacketList())
            Fluent:Notify({ Title = "Packet Config", Content = "Deleted " .. selected .. "!", Duration = 2 })
        end
    end
})

Tabs.Server:AddKeybind("SendPacketKey", {
    Title = "Send Packet",
    Mode = "Toggle",
    Default = "M",
    Callback = function()
        sendPacket(Server_Config.PacketString, Server_Config.PacketSize)
        Fluent:Notify({ Title = "Packet", Content = "Packet sent!", Duration = 2 })
    end
})

local AutoPacketToggle = Tabs.Server:AddToggle("AutoPacketToggle", { Title = "Auto Packet", Default = false })
AutoPacketToggle:OnChanged(function(Value) Server_Config.AutoPacket = Value end)

Tabs.Server:AddSection("Line Lag")

Tabs.Server:AddDropdown("LineLagModeDropdown", {
    Title = "Line Lag Mode",
    Values = {"Base lag", "Chain lag", "Mass lag"},
    Default = "Base lag",
    Callback = function(Value) Server_Config.LineLagMode = Value end
})

Tabs.Server:AddSlider("LineSpamSpeedSlider", {
    Title = "Spam Speed [Interval]",
    Default = 0.1,
    Min = 0.01,
    Max = 2,
    Rounding = 2,
    Callback = function(Value) Server_Config.LineSpamSpeed = Value end
})

local LineLagToggle = Tabs.Server:AddToggle("LineLagOptimizedToggle", { Title = "Line Lag [Optimized]", Default = false })
LineLagToggle:OnChanged(function(Value) Server_Config.LineLagOptimized = Value end)

Tabs.Server:AddSection("Breaker Object")

Tabs.Server:AddDropdown("BreakerObjectDropdown", {
    Title = "Select Object",
    Values = BreakerObjects,
    Default = "Ocean",
    Callback = function(Value) Server_Config.BreakerObject = Value end
})

Tabs.Server:AddSlider("CollideBreakerSlider", {
    Title = "Collide Breaker",
    Default = 2,
    Min = 0,
    Max = 20,
    Rounding = 0,
    Callback = function(Value) Server_Config.CollideBreaker = Value end
})

Tabs.Server:AddSlider("DebrisBreakerSlider", {
    Title = "Debris Breaker",
    Default = 3,
    Min = 0,
    Max = 20,
    Rounding = 0,
    Callback = function(Value) Server_Config.DebrisBreaker = Value end
})

Tabs.Server:AddButton({
    Title = "Apply Breaker Now",
    Callback = function()
        local collide = applyCollideBreaker()
        local debris = applyDebrisBreaker()
        Fluent:Notify({ Title = "Breaker", Content = "Collide broken: " .. collide .. " | Debris removed: " .. debris, Duration = 3 })
    end
})

Tabs.Server:AddSection("Collide Breaker & Offsets")

local SearchPlayerInput = Tabs.Server:AddInput("SearchServerPlayer", {
    Title = "Search Player",
    Default = "",
    Placeholder = "Type player name...",
    Callback = function(Value)
        local filtered = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                if string.lower(p.Name):match(string.lower(Value)) or Value == "" then
                    table.insert(filtered, p.Name)
                end
            end
        end
        if #filtered == 0 then table.insert(filtered, "None") end
        SelectPlayerDropdown:SetValues(filtered)
    end
})

local SelectPlayerDropdown = Tabs.Server:AddDropdown("SelectServerPlayer", {
    Title = "Select Player",
    Values = {},
    Default = "None",
    Callback = function(Value)
        Server_Config.SelectedPlayer = Players:FindFirstChild(Value)
    end
})

-- Initialize Player List
task.spawn(function()
    local init = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(init, p.Name) end
    end
    if #init == 0 then table.insert(init, "None") end
    SelectPlayerDropdown:SetValues(init)
end)

Tabs.Server:AddInput("BreakToPlayerInput", {
    Title = "Break to Player",
    Default = "1",
    Callback = function(Value) Server_Config.BreakToPlayerVal = tonumber(Value) or 1 end
})

Tabs.Server:AddButton({
    Title = "Apply Break to Player",
    Callback = function()
        local target = Server_Config.SelectedPlayer
        breakToPlayer(target)
        Fluent:Notify({ Title = "Break", Content = "Collision broken on " .. (target and target.Name or "target") .. "!", Duration = 2 })
    end
})

Tabs.Server:AddKeybind("AttachMouseKey", {
    Title = "Attach to Object (mouse)",
    Mode = "Toggle",
    Default = "V",
    Callback = function()
        attachToMouseObject()
    end
})

local SwitchKickGroundToggle = Tabs.Server:AddToggle("SwitchKickGroundToggle", { Title = "Switch for Kick Ground", Default = false })
SwitchKickGroundToggle:OnChanged(function(Value) Server_Config.SwitchKickGround = Value end)

Tabs.Server:AddSlider("OffsetXSlider", {
    Title = "Offset X",
    Default = 0,
    Min = -30,
    Max = 30,
    Rounding = 1,
    Callback = function(Value) Server_Config.OffsetX = Value end
})

Tabs.Server:AddSlider("OffsetZSlider", {
    Title = "Offset Z",
    Default = 0,
    Min = -30,
    Max = 30,
    Rounding = 1,
    Callback = function(Value) Server_Config.OffsetZ = Value end
})

Tabs.Server:AddButton({
    Title = "Apply Custom Offset",
    Callback = function()
        local root = getRoot()
        if root then
            root.CFrame = root.CFrame + Vector3.new(Server_Config.OffsetX, 0, Server_Config.OffsetZ)
            Fluent:Notify({ Title = "Offset", Content = "Offset applied (X:" .. Server_Config.OffsetX .. ", Z:" .. Server_Config.OffsetZ .. ")", Duration = 2 })
        end
    end
})

local AutoReattachToggle = Tabs.Server:AddToggle("AutoReattachToggle", { Title = "Auto Reattach Shuriken", Default = false })
AutoReattachToggle:OnChanged(function(Value) Server_Config.AutoReattachShuriken = Value end)

Tabs.Server:AddSection("Kick All")

local SearchWhitelistInput = Tabs.Server:AddInput("SearchWhitelistInput", {
    Title = "Search Player (to whitelist)",
    Default = "",
    Placeholder = "Type player name...",
    Callback = function(Value)
        local filtered = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                if string.lower(p.Name):match(string.lower(Value)) or Value == "" then
                    table.insert(filtered, p.Name)
                end
            end
        end
        if #filtered == 0 then table.insert(filtered, "None") end
        AddWhitelistDropdown:SetValues(filtered)
    end
})

local AddWhitelistDropdown = Tabs.Server:AddDropdown("AddWhitelistDropdown", {
    Title = "Select Player to Whitelist",
    Values = {},
    Default = "None",
    Callback = function(Value)
        if Value ~= "None" and not Server_Config.Whitelisted[Value] then
            Server_Config.Whitelisted[Value] = true
            WhitelistedDropdown:SetValues(getWhitelistedPlayers())
            Fluent:Notify({ Title = "Kick All", Content = "Whitelisted: " .. Value, Duration = 2 })
        end
    end
})

-- Initialize whitelist source list on load + when players join/leave
local function refreshWhitelistSource()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(names, p.Name) end
    end
    if #names == 0 then table.insert(names, "None") end
    pcall(function() AddWhitelistDropdown:SetValues(names) end)
    pcall(function() WhitelistedDropdown:SetValues(getWhitelistedPlayers()) end)
end

local WhitelistedDropdown = Tabs.Server:AddDropdown("WhitelistedDropdown", {
    Title = "Whitelisted Players",
    Values = getWhitelistedPlayers(),
    Default = "None"
})

Tabs.Server:AddButton({
    Title = "Delete All Whitelist",
    Callback = function()
        table.clear(Server_Config.Whitelisted)
        WhitelistedDropdown:SetValues(getWhitelistedPlayers())
        Fluent:Notify({ Title = "Kick All", Content = "Whitelist cleared!", Duration = 2 })
    end
})

Tabs.Server:AddSlider("PlacementRadiusSlider", {
    Title = "Placement Radius",
    Default = 20,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Callback = function(Value) Server_Config.PlacementRadius = Value end
})

Tabs.Server:AddSlider("PlacementHeightSlider", {
    Title = "Placement Height",
    Default = 15,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Callback = function(Value) Server_Config.PlacementHeight = Value end
})

Tabs.Server:AddButton({
    Title = "Kick All [start]",
    Callback = function()
        if #getWhitelistedPlayers() <= 1 and next(Server_Config.Whitelisted) == nil then
            Fluent:Notify({ Title = "Kick All", Content = "No players whitelisted. Everyone will be moved!", Duration = 2 })
        end
        KickAll()
    end
})

Players.PlayerAdded:Connect(function() refreshWhitelistSource() end)
Players.PlayerRemoving:Connect(function(player)
    Server_Config.Whitelisted[player.Name] = nil
    refreshWhitelistSource()
end)

refreshWhitelistSource()


-- ================================================================
-- ANTI-KICK DEFENSE (intercept server teleport / correction spam)
--   Toggle-gated (off by default). No velocity touching.
-- ================================================================

local AntiKick_Config = { Enabled = false, VoidThreshold = -100 }
local SafeCFrame = nil
local SafeCFrameInitialized = false
local AntiKickHookInit = false

-- True while FTAP's RagdollPlayerCharacter / GrabbingScript control the body.
-- While ragdolled (grabbed / knocked down / sitting) auto-rollback is FORBIDDEN.
local function isRagdolled()
    local hum = getHumanoid()
    if not hum then return false end
    local st = hum:GetState()
    return st == Enum.HumanoidStateType.Ragdoll
        or st == Enum.HumanoidStateType.FallingDown
        or hum.Sit == true
end

-- Snap back to the last safe grounded position if the server shoves us
-- far away (teleport-kick pattern) or drops us into the void.
-- This NEVER corrects at script start: it only acts when the player is
-- genuinely airborne and below the void line, or teleported >500 studs
-- while NOT grounded (e.g. grabbed/ragdolled by a kick).
local function applyAntiKickGuard()
    pcall(function()
        local root = getRoot()
        if not root then return end
        local hum = getHumanoid()
        if not hum then return end

        -- Never restore while RagdollPlayerCharacter is controlling the body
        -- (grabbed by another player, knocked down, or sitting). Blocked → skip.
        local blocked = isRagdolled()
        local grounded = hum:GetState() == Enum.HumanoidStateType.Running
            or hum:GetState() == Enum.HumanoidStateType.Landed
            or hum:GetState() == Enum.HumanoidStateType.GettingUp
        local calm = grounded and root.Position.Y > -50

        -- 1) Record a safe position ONLY from a real grounded stance, using
        --    the player's current CFrame (never default coordinates).
        if not blocked and calm then
            SafeCFrame = root.CFrame
            SafeCFrameInitialized = true
        end

        -- 2) Void / kicked below the map → restore (only with a recorded spot
        --    AND when not ragdolled by another player / RagdollPC).
        if not blocked and SafeCFrameInitialized and SafeCFrame
            and root.Position.Y < AntiKick_Config.VoidThreshold then
            root.CFrame = SafeCFrame
        end

        -- 3) Huge teleport jump (server relocation) while AIRBORNE → restore.
        --    While walking/running (grounded) we never snap back, so normal
        --    play and the script start are never disturbed.
        if not blocked and not grounded and SafeCFrameInitialized and SafeCFrame then
            if (root.Position - SafeCFrame.Position).Magnitude > 500 then
                root.CFrame = SafeCFrame
            end
        end
    end)
end

-- Hook the correction/player remote events so the client-side handlers
-- that FTAP uses for kicks are neutralised (silent, no error spam).
local function hookAntiKickRemotes()
    if AntiKickHookInit then return end
    AntiKickHookInit = true
    local folders = { "GameCorrectionEvents", "PlayerEvents", "CharacterEvents" }
    for _, folderName in ipairs(folders) do
        local holder = ReplicatedStorage:FindFirstChild(folderName)
        if holder then
            for _, r in ipairs(holder:GetChildren()) do
                if r:IsA("RemoteEvent") and not r:GetAttribute("FTAP_AntiKickHooked") then
                    r:SetAttribute("FTAP_AntiKickHooked", true)
                    r.OnClientEvent:Connect(function(...)
                        if not AntiKick_Config.Enabled then return end
                        -- Swallow correction events that are used to kick/relocate.
                        local args = { ... }
                        pcall(function()
                            local first = tostring(args[1] or "")
                            local low = string.lower(first)
                            if string.find(low, "kick") or string.find(low, "ban")
                               or string.find(low, "teleport") or string.find(low, "void") then
                                applyAntiKickGuard()
                            end
                        end)
                    end)
                end
            end
        end
    end
end

-- Periodic guard at a calm 10 FPS.
task.spawn(function()
    while true do
        task.wait(0.1)
        if AntiKick_Config.Enabled then
            pcall(hookAntiKickRemotes)
            pcall(applyAntiKickGuard)
        end
    end
end)

Tabs.Protections:AddSection("Anti Kick [Defense]")

Tabs.Protections:AddToggle("AntiKickDefenseToggle", { Title = "Intercept Teleport / Void Kick", Default = false, Callback = function(Value)
    AntiKick_Config.Enabled = Value
    if Value then
        -- Record the safe position STRICTLY from the current CFrame at the
        -- moment of enabling. Do NOT run the guard here: no instant rollback.
        local root = getRoot()
        if root then
            SafeCFrame = root.CFrame
            SafeCFrameInitialized = true
        else
            SafeCFrame = nil
            SafeCFrameInitialized = false
        end
        pcall(hookAntiKickRemotes)
        Fluent:Notify({ Title = "Anti Kick", Content = "Active: teleport/void kicks are intercepted.", Duration = 2 })
    end
end })


-- ================================================================
-- SETTINGS TAB
-- ================================================================

Tabs.Settings:AddSection("Menu")

Tabs.Settings:AddKeybind("MenuToggleKey", {
    Title = "Toggle Menu Keybind",
    Mode = "Toggle",
    Default = "LeftControl",
    Callback = function()
        Window:Minimize()
    end
})

-- Initialize Whitelist List
-- (dropdowns already initialized above)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Gradient Hub Server",
    Content = "Server module loaded successfully!",
    Duration = 5
})

print("[Gradient Hub] Server module loaded successfully.")

-- register window for global gradient styling (idempotent for shared window)
_G.GradientWindows = _G.GradientWindows or {}
local _alreadyRegistered = false
for _idx, _win in ipairs(_G.GradientWindows) do
    if _win == Window then
        _alreadyRegistered = true
        break
    end
end
if not _alreadyRegistered then
    table.insert(_G.GradientWindows, Window)
end

end)
print('[Gradient] OK: ftap_server.luau')
task.wait(0.1)
-- END MODULE: ftap_server.luau

-- BEG MODULE: ftap_server_auras.luau
pcall(function()
--[[
    ================================================================
    Gradient Hub Server & Auras Module
    Mass server actions, offensive auras and explosion control.
    Target Game: Fling Things and People (FTAP)
    UI Library: Fluent UI
    File: ftap_server_auras.luau
    ================================================================
--]]

-- Services Initialization
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

-- Global Safe File IO Wrappers (kept for future persistence)
local writefile = writefile or function() end
local readfile = readfile or function() return "" end
local isfile = isfile or function() return false end
local makefolder = makefolder or function() end
local isfolder = isfolder or function() return false end

if not isfolder("GradientFTAP") then pcall(makefolder, "GradientFTAP") end

-- Shared window created by main.luau (one window for all modules)
local Fluent = _G.GradientFluent
local Window = _G.GradientWindow
if not Fluent or not Window then
    Fluent = (function()
        local ok, lib = pcall(function()
            return loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
        end)
        if ok and lib then return lib end
        local ok2, lib2 = pcall(function()
            return loadstring(game:HttpGet("https://raw.githubusercontent.com/disco0001/Fluent/main/main.lua"))()
        end)
        return (ok2 and lib2) or error("[Gradient] Failed to load Fluent UI library.")
    end)()
    local okW, win = pcall(Fluent.CreateWindow, Fluent, {
        Title = "Gradient Hub | FTAP",
        SubTitle = "by keksup22",
        TabWidth = 160,
        Size = UDim2.fromOffset(640, 460),
        Acrylic = true,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.LeftControl
    })
    Window = (okW and type(win) == "table" and type(win.AddTab) == "function") and win or nil
    if not Window then
        print("[Gradient] Fallback window creation failed.")
    end
    _G.GradientFluent = Fluent
    _G.GradientWindow = Window
end

if type(Fluent) ~= "table" or type(Window) ~= "table" or type(Window.AddTab) ~= "function" then
    print("[Gradient] Skip module: Fluent UI unavailable")
    return
end

local Tabs = {
    Server = _G.GradientTabs and _G.GradientTabs.Server or Window:AddTab({ Title = "Server & Auras", Icon = "bolt" }),
    Settings = _G.GradientTabs and _G.GradientTabs.Settings or Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- ================================================================
-- SAFE FTAP REMOTE HELPERS (paths pin-pointed to real game remotes)
-- ================================================================

local function getRemote(folder, name)
    local holder = ReplicatedStorage:FindFirstChild(folder)
    if not holder then return nil end
    local r = holder:FindFirstChild(name)
    if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then return r end
    return nil
end

local function fireRemote(folder, name, ...)
    local args = { ... }
    for _, arg in ipairs(args) do
        if arg == nil then return end
    end
    pcall(function()
        local r = getRemote(folder, name)
        if not r then return end
        if r:IsA("RemoteEvent") then
            r:FireServer(unpack(args))
        else
            r:InvokeServer(unpack(args))
        end
    end)
end

-- Throttle helper: runs heavy work at most once per interval, wrapped in pcall
local function makeThrottled(intervalSec)
    local last = 0
    return function(func)
        local now = os.clock()
        if now - last < intervalSec then return end
        last = now
        pcall(func)
    end
end

-- Safe Helper Functions
local function getRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function isBasePart(obj)
    return obj and typeof(obj) == "Instance" and obj:IsA("BasePart")
end

local function safeSetLinearVelocity(part, velocity)
    if not isBasePart(part) then return false end
    if typeof(velocity) ~= "Vector3" then return false end
    if part.Anchored then return false end
    pcall(function()
        if typeof(part.SetNetworkOwner) == "function" then part:SetNetworkOwner(LocalPlayer) end
        part.AssemblyLinearVelocity = velocity
    end)
    return true
end

local function safeSetCFrame(part, cf)
    if not isBasePart(part) then return false end
    if typeof(cf) ~= "CFrame" then return false end
    pcall(function()
        if typeof(part.SetNetworkOwner) == "function" then part:SetNetworkOwner(LocalPlayer) end
        part.CFrame = cf
    end)
    return true
end

local function getTargetRoot(plr)
    if not plr or plr == LocalPlayer then return nil end
    local char = plr.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function getTargetHumanoid(plr)
    if not plr or plr == LocalPlayer then return nil end
    local char = plr.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

-- True while FTAP's RagdollPlayerCharacter / GrabbingScript control the body.
local function isRagdolled()
    local hum = getHumanoid()
    if not hum then return false end
    local st = hum:GetState()
    return st == Enum.HumanoidStateType.Ragdoll
        or st == Enum.HumanoidStateType.FallingDown
        or hum.Sit == true
end


-- ================================================================
-- SERVER & AURAS MODULE CONFIG & STATE
-- ================================================================

local ServerAuras_Config = {
    -- Mass actions
    MassRadius = 250,
    MassSafeMode = true,

    -- Offensive auras
    Aura = "Burn Aura",
    AuraEnabled = false,
    AuraRadius = 40,
    AuraPower = 100,

    -- Explosions
    ExplosionMethod = "TNT Blast",
    ExplosionRadius = 30,
    LoopExplosions = false,
    AutoExplosions = false,
    AutoExplosionDelay = 5,

    -- Object auras
    ObjectAuraEnabled = false,
    ObjectAuraMode = "Object Tornado",
    ObjectAuraRadius = 40,
    ObjectAuraSpeed = 40,

    -- Loop Kill All
    LoopKillAll = false,
    LoopKillAllInterval = 5
}

-- Safe Mode friend cache (fetched once)
local safeFriends = {}
local safeFriendsLoaded = false
local function loadSafeFriends()
    if safeFriendsLoaded then return end
    safeFriendsLoaded = true
    pcall(function()
        local pages = Players:GetFriendsAsync(LocalPlayer.UserId)
        while true do
            for _, friend in ipairs(pages:GetCurrentPage()) do
                if friend and friend.Name then
                    safeFriends[friend.Name] = true
                end
            end
            if pages.IsFinished then break end
            pages:AdvanceToNextPageAsync()
        end
    end)
end

local function isSafeTarget(plr)
    if not ServerAuras_Config.MassSafeMode then return false end
    loadSafeFriends()
    return safeFriends[plr.Name] == true
end

-- Collects all target players within MassRadius of us (Safe Mode respected)
local function getTargetsInRange()
    local myRoot = getRoot()
    if not myRoot then return {} end
    local targets = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not isSafeTarget(plr) then
            local root = getTargetRoot(plr)
            if root and (myRoot.Position - root.Position).Magnitude <= ServerAuras_Config.MassRadius then
                table.insert(targets, plr)
            end
        end
    end
    return targets
end

-- ================================================================
-- SECTION 1: MASS SERVER ACTIONS
-- ================================================================

local function killAllPlayers()
    local myRoot = getRoot()
    if not isBasePart(myRoot) or isRagdolled() then return 0 end
    local targets = getTargetsInRange()
    local count = 0
    for _, plr in ipairs(targets) do
        local tRoot = getTargetRoot(plr)
        if isBasePart(tRoot) then
            local dir = CFrame.new(myRoot.Position, tRoot.Position).LookVector
            if typeof(dir) == "Vector3" then
                safeSetLinearVelocity(tRoot, dir * 500 + Vector3.new(0, 150, 0))
            end
            fireRemote("GameCorrectionEvents", "StopAllVelocity")
            count = count + 1
        end
    end
    return count
end

local function massKillAll()
    local count = killAllPlayers()
    Fluent:Notify({ Title = "Kill All", Content = "Flinged " .. count .. " player(s) into the void.", Duration = 3 })
end

local function massRagdollAll()
    local targets = getTargetsInRange()
    local count = 0
    for _, plr in ipairs(targets) do
        fireRemote("CharacterEvents", "RagdollRemote")
        fireRemote("PlayerEvents", "RagdollPlayer")
        count = count + 1
    end
    Fluent:Notify({ Title = "Ragdoll All", Content = "Ragdolled " .. count .. " player(s).", Duration = 3 })
end

local function massBringAll()
    local myRoot = getRoot()
    if not isBasePart(myRoot) or isRagdolled() then return end
    local targets = getTargetsInRange()
    local count = 0
    for _, plr in ipairs(targets) do
        local tRoot = getTargetRoot(plr)
        if isBasePart(tRoot) then
            safeSetCFrame(tRoot, myRoot.CFrame + Vector3.new(0, 5 + count * 3, 0))
            safeSetLinearVelocity(tRoot, Vector3.new(0, 0, 0))
            count = count + 1
        end
    end
    Fluent:Notify({ Title = "Bring Players", Content = "Brought " .. count .. " player(s) to you.", Duration = 3 })
end

local function massSendToHeaven()
    local targets = getTargetsInRange()
    local count = 0
    for _, plr in ipairs(targets) do
        local tRoot = getTargetRoot(plr)
        if isBasePart(tRoot) then
            safeSetCFrame(tRoot, CFrame.new(0, -250, 0))
            safeSetLinearVelocity(tRoot, Vector3.new(0, -300, 0))
            fireRemote("GameCorrectionEvents", "TeleportToGround")
            count = count + 1
        end
    end
    Fluent:Notify({ Title = "Send to Heaven", Content = "Sent " .. count .. " player(s) to the void.", Duration = 3 })
end


-- ================================================================
-- SECTION 2: OFFENSIVE AURAS
-- ================================================================

local auraBurns = {}  -- [player] = Fire instance (Burn Aura cleanup)

local function clearAuraBurns()
    for plr, fire in pairs(auraBurns) do
        pcall(function()
            if fire and fire.Parent then fire:Destroy() end
        end)
        auraBurns[plr] = nil
    end
end

local function applyBurnAura()
    local myRoot = getRoot()
    if not myRoot then return end
    local seen = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not isSafeTarget(plr) then
            local tRoot = getTargetRoot(plr)
            if tRoot and (myRoot.Position - tRoot.Position).Magnitude <= ServerAuras_Config.AuraRadius then
                seen[plr] = true
                if not auraBurns[plr] or not auraBurns[plr].Parent then
                    local fire = Instance.new("Fire")
                    fire.Size = 4
                    fire.Heat = 8
                    fire.Parent = tRoot
                    auraBurns[plr] = fire
                end
            end
        end
    end
    -- Clean up burns for players that left the radius
    for plr, fire in pairs(auraBurns) do
        if not seen[plr] then
            pcall(function() if fire and fire.Parent then fire:Destroy() end end)
            auraBurns[plr] = nil
        end
    end
end

local function applyAttractionAura()
    local myRoot = getRoot()
    if not isBasePart(myRoot) or isRagdolled() then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not isSafeTarget(plr) then
            local tRoot = getTargetRoot(plr)
            if isBasePart(tRoot) then
                local diff = myRoot.Position - tRoot.Position
                if typeof(diff) == "Vector3" then
                    local dist = diff.Magnitude
                    if dist <= ServerAuras_Config.AuraRadius and dist > 1 then
                        safeSetLinearVelocity(tRoot, diff.Unit * ServerAuras_Config.AuraPower)
                    end
                end
            end
        end
    end
end

local function applyFlingAura()
    local myRoot = getRoot()
    if not isBasePart(myRoot) or isRagdolled() then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not isSafeTarget(plr) then
            local tRoot = getTargetRoot(plr)
            if isBasePart(tRoot) then
                local diff = tRoot.Position - myRoot.Position
                if typeof(diff) == "Vector3" then
                    local dist = diff.Magnitude
                    if dist <= ServerAuras_Config.AuraRadius and dist > 1 then
                        safeSetLinearVelocity(tRoot, diff.Unit * ServerAuras_Config.AuraPower + Vector3.new(0, 80, 0))
                        fireRemote("CharacterEvents", "RagdollRemote")
                        fireRemote("PlayerEvents", "RagdollPlayer")
                    end
                end
            end
        end
    end
end

local function applyKickAura()
    local myRoot = getRoot()
    if not isBasePart(myRoot) or isRagdolled() then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not isSafeTarget(plr) then
            local tRoot = getTargetRoot(plr)
            if isBasePart(tRoot) and (myRoot.Position - tRoot.Position).Magnitude <= ServerAuras_Config.AuraRadius then
                safeSetLinearVelocity(tRoot, Vector3.new(0, 0, 0))
                fireRemote("CharacterEvents", "RagdollRemote")
                fireRemote("PlayerEvents", "RagdollPlayer")
            end
        end
    end
end

local function applyVoidAura()
    local myRoot = getRoot()
    if not isBasePart(myRoot) then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not isSafeTarget(plr) then
            local tRoot = getTargetRoot(plr)
            if isBasePart(tRoot) and (myRoot.Position - tRoot.Position).Magnitude <= ServerAuras_Config.AuraRadius then
                safeSetCFrame(tRoot, CFrame.new(0, -250, 0))
                safeSetLinearVelocity(tRoot, Vector3.new(0, -300, 0))
                fireRemote("GameCorrectionEvents", "TeleportToGround")
            end
        end
    end
end

local function applyFollowAura()
    local myRoot = getRoot()
    if not isBasePart(myRoot) or isRagdolled() then return end
    local followPos = myRoot.CFrame * CFrame.new(0, 0, -10)
    if typeof(followPos) ~= "CFrame" then return end
    local followPosition = followPos.Position
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not isSafeTarget(plr) then
            local tRoot = getTargetRoot(plr)
            if isBasePart(tRoot) then
                local diff = followPosition - tRoot.Position
                if typeof(diff) == "Vector3" then
                    local dist = diff.Magnitude
                    if dist <= ServerAuras_Config.AuraRadius and dist > 1 then
                        safeSetLinearVelocity(tRoot, diff.Unit * ServerAuras_Config.AuraPower)
                    end
                end
            end
        end
    end
end

local function applySelectedAura()
    local aura = ServerAuras_Config.Aura
    if aura == "Burn Aura" then applyBurnAura()
    elseif aura == "Attraction Aura" then applyAttractionAura()
    elseif aura == "Fling Aura" then applyFlingAura()
    elseif aura == "Kick Aura" then applyKickAura()
    elseif aura == "Void Aura" then applyVoidAura()
    elseif aura == "Follow Aura" then applyFollowAura()
    end
end

-- Aura runtime loop (0.15s tick keeps physics responsive, no heavy scans)
task.spawn(function()
    while true do
        task.wait(0.15)
        if ServerAuras_Config.AuraEnabled then
            pcall(applySelectedAura)
        end
    end
end)


-- ================================================================
-- SECTION 3: EXPLOSIONS (Loop + Auto-Timer)
-- ================================================================

local function getExplosionParams(method)
    if method == "Snowball" then
        return 6, 50000, 0.5
    elseif method == "Missile" then
        return 8, 120000, 1
    elseif method == "Small Present" then
        return 5, 60000, 0.75
    elseif method == "Big Present" then
        return 15, 150000, 1
    elseif method == "TNT Blast" then
        return 12, 100000, 1
    end
    return 10, 100000, 1
end

local function spawnExplosionAt(pos)
    if typeof(pos) ~= "Vector3" then return end
    pcall(function()
        local method = ServerAuras_Config.ExplosionMethod

        -- Non-explosion variants operate directly on players
        if method == "Void" then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    local tRoot = getTargetRoot(plr)
                    if isBasePart(tRoot) and (pos - tRoot.Position).Magnitude <= ServerAuras_Config.ExplosionRadius then
                        safeSetCFrame(tRoot, CFrame.new(0, -250, 0))
                        safeSetLinearVelocity(tRoot, Vector3.new(0, -300, 0))
                        fireRemote("GameCorrectionEvents", "TeleportToGround")
                    end
                end
            end
            return
        end

        if method == "Balloon" then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    local tRoot = getTargetRoot(plr)
                    if isBasePart(tRoot) and (pos - tRoot.Position).Magnitude <= ServerAuras_Config.ExplosionRadius then
                        if isBasePart(tRoot) and typeof(tRoot.AssemblyLinearVelocity) == "Vector3" then
                            safeSetLinearVelocity(tRoot, tRoot.AssemblyLinearVelocity + Vector3.new(0, 150, 0))
                        end
                    end
                end
            end
            return
        end

        local radius, pressure, destroyJoints = getExplosionParams(method)
        local explosion = Instance.new("Explosion")
        explosion.Position = pos
        explosion.BlastRadius = radius
        explosion.BlastPressure = pressure
        explosion.DestroyJointRadiusPercent = destroyJoints
        explosion.Parent = Workspace
        fireRemote("BombEvents", "BombReplicator")
        fireRemote("BombEvents", "BombExplode")
    end)
end

local function explosionTargets()
    local myRoot = getRoot()
    if not isBasePart(myRoot) then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local tRoot = getTargetRoot(plr)
            if isBasePart(tRoot) and (myRoot.Position - tRoot.Position).Magnitude <= ServerAuras_Config.MassRadius then
                spawnExplosionAt(tRoot.Position)
            end
        end
    end
end

-- Loop Explosions (0.5s sweep)
task.spawn(function()
    while true do
        task.wait(0.5)
        if ServerAuras_Config.LoopExplosions then
            pcall(explosionTargets)
        end
    end
end)

-- Auto Explosions (custom delay timer)
task.spawn(function()
    local lastAuto = 0
    while true do
        task.wait(0.5)
        if ServerAuras_Config.AutoExplosions then
            local now = os.clock()
            local delay = math.max(ServerAuras_Config.AutoExplosionDelay, 1)
            if now - lastAuto >= delay then
                lastAuto = now
                pcall(explosionTargets)
            end
        end
    end
end)

-- Cleanup burns when aura is disabled / on respawn
LocalPlayer.CharacterAdded:Connect(function()
    clearAuraBurns()
end)


-- ================================================================
-- SECTION 4: OBJECT AURAS (Tornado / Aura / Float)
-- ================================================================

local objectAuraParts = {}
local objectAuraLastScan = 0

-- Re-scan parts inside radius (heavy GetDescendants throttled to 0.5s)
local function scanObjectAuraParts()
    local myRoot = getRoot()
    if not isBasePart(myRoot) then return end
    local now = os.clock()
    if now - objectAuraLastScan < 0.5 then return end
    objectAuraLastScan = now
    table.clear(objectAuraParts)
    local char = LocalPlayer.Character
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if isBasePart(inst) and inst.Anchored == false then
            if not char or not inst:IsDescendantOf(char) then
                if (inst.Position - myRoot.Position).Magnitude <= ServerAuras_Config.ObjectAuraRadius then
                    objectAuraParts[inst] = true
                end
            end
        end
    end
end

local function applyObjectAuraToParts()
    local myRoot = getRoot()
    if not isBasePart(myRoot) or isRagdolled() then return end
    scanObjectAuraParts()
    local speed = ServerAuras_Config.ObjectAuraSpeed
    local mode = ServerAuras_Config.ObjectAuraMode
    for part in pairs(objectAuraParts) do
        if part and part.Parent then
            pcall(function()
                if not isBasePart(part) then return end
                local diff = part.Position - myRoot.Position
                if typeof(diff) ~= "Vector3" then return end
                local dist = math.max(diff.Magnitude, 1)
                if mode == "Object Tornado" then
                    local up = Vector3.new(0, 1, 0)
                    local tangent = diff.Unit:Cross(up)
                    if tangent.Magnitude < 0.01 then tangent = Vector3.new(1, 0, 0) end
                    safeSetLinearVelocity(part, tangent.Unit * speed + Vector3.new(0, speed * 0.4, 0))
                elseif mode == "Object Aura" then
                    local pullDiff = myRoot.Position - part.Position
                    if typeof(pullDiff) == "Vector3" and pullDiff.Magnitude > 0.001 then
                        safeSetLinearVelocity(part, pullDiff.Unit * speed)
                    end
                elseif mode == "Object Float" then
                    local v = part.AssemblyLinearVelocity
                    if typeof(v) == "Vector3" then
                        safeSetLinearVelocity(part, Vector3.new(v.X, speed, v.Z))
                    end
                end
            end)
        end
    end
end

-- Object aura runtime loop (0.1s tick)
task.spawn(function()
    while true do
        task.wait(0.1)
        if ServerAuras_Config.ObjectAuraEnabled then
            pcall(applyObjectAuraToParts)
        end
    end
end)


-- ================================================================
-- SECTION 5: LOOP KILL ALL (interval timer)
-- ================================================================

task.spawn(function()
    local last = 0
    while true do
        task.wait(0.5)
        if ServerAuras_Config.LoopKillAll then
            local now = os.clock()
            local interval = math.max(ServerAuras_Config.LoopKillAllInterval, 0.5)
            if now - last >= interval then
                last = now
                pcall(killAllPlayers)
            end
        end
    end
end)


-- ================================================================
-- SERVER & AURAS UI
-- ================================================================

Tabs.Server:AddSection("Mass Server Actions")

Tabs.Server:AddSlider("MassRadiusSlider", {
    Title = "Action Radius",
    Default = 250,
    Min = 20,
    Max = 1000,
    Rounding = 0,
    Callback = function(Value) ServerAuras_Config.MassRadius = Value end
})

local MassSafeToggle = Tabs.Server:AddToggle("MassSafeToggle", { Title = "Safe Mode [Skip Friends]", Default = true })
MassSafeToggle:OnChanged(function(Value) ServerAuras_Config.MassSafeMode = Value end)

Tabs.Server:AddButton({
    Title = "Kill All",
    Description = "Fling every player in radius into the void",
    Callback = function()
        pcall(massKillAll)
    end
})

Tabs.Server:AddButton({
    Title = "Ragdoll All",
    Description = "Ragdoll every player in radius",
    Callback = function()
        pcall(massRagdollAll)
    end
})

Tabs.Server:AddButton({
    Title = "Bring Players",
    Description = "Teleport every player in radius to you",
    Callback = function()
        pcall(massBringAll)
    end
})

Tabs.Server:AddButton({
    Title = "Send to Heaven",
    Description = "Teleport every player in radius into the void",
    Callback = function()
        pcall(massSendToHeaven)
    end
})

local LoopKillAllToggle = Tabs.Server:AddToggle("LoopKillAllToggle", { Title = "Loop Kill All", Default = false })
LoopKillAllToggle:OnChanged(function(Value) ServerAuras_Config.LoopKillAll = Value end)

Tabs.Server:AddSlider("LoopKillAllIntervalSlider", {
    Title = "Loop Kill All Interval [s]",
    Default = 5,
    Min = 0.5,
    Max = 30,
    Rounding = 1,
    Callback = function(Value) ServerAuras_Config.LoopKillAllInterval = Value end
})

Tabs.Server:AddSection("Offensive Auras")

Tabs.Server:AddDropdown("OffensiveAuraDropdown", {
    Title = "Select Aura",
    Values = {"Burn Aura", "Attraction Aura", "Fling Aura", "Kick Aura", "Void Aura", "Follow Aura"},
    Default = "Burn Aura",
    Callback = function(Value) ServerAuras_Config.Aura = Value end
})

local OffensiveAuraToggle = Tabs.Server:AddToggle("OffensiveAuraToggle", { Title = "Enable Aura", Default = false })
OffensiveAuraToggle:OnChanged(function(Value)
    ServerAuras_Config.AuraEnabled = Value
    if not Value then
        clearAuraBurns()
    end
end)

Tabs.Server:AddSlider("AuraRadiusSlider", {
    Title = "Aura Radius",
    Default = 40,
    Min = 10,
    Max = 200,
    Rounding = 0,
    Callback = function(Value) ServerAuras_Config.AuraRadius = Value end
})

Tabs.Server:AddSlider("AuraPowerSlider", {
    Title = "Aura Power [Pull / Fling]",
    Default = 100,
    Min = 10,
    Max = 600,
    Rounding = 0,
    Callback = function(Value) ServerAuras_Config.AuraPower = Value end
})

Tabs.Server:AddSection("Object Auras")

Tabs.Server:AddDropdown("ObjectAuraDropdown", {
    Title = "Object Mode",
    Values = {"Object Tornado", "Object Aura", "Object Float"},
    Default = "Object Tornado",
    Callback = function(Value) ServerAuras_Config.ObjectAuraMode = Value end
})

local ObjectAuraToggle = Tabs.Server:AddToggle("ObjectAuraToggle", { Title = "Enable Object Aura", Default = false })
ObjectAuraToggle:OnChanged(function(Value) ServerAuras_Config.ObjectAuraEnabled = Value end)

Tabs.Server:AddSlider("ObjectAuraRadiusSlider", {
    Title = "Object Aura Radius",
    Default = 40,
    Min = 10,
    Max = 150,
    Rounding = 0,
    Callback = function(Value) ServerAuras_Config.ObjectAuraRadius = Value end
})

Tabs.Server:AddSlider("ObjectAuraSpeedSlider", {
    Title = "Object Speed [Spin / Lift]",
    Default = 40,
    Min = 5,
    Max = 300,
    Rounding = 0,
    Callback = function(Value) ServerAuras_Config.ObjectAuraSpeed = Value end
})

Tabs.Server:AddSection("Explosions")

Tabs.Server:AddDropdown("ServerExplosionMethodDropdown", {
    Title = "Explosion Method",
    Values = {"TNT Blast", "Snowball", "Missile", "Void", "Balloon", "Small Present", "Big Present"},
    Default = "TNT Blast",
    Callback = function(Value) ServerAuras_Config.ExplosionMethod = Value end
})

Tabs.Server:AddSlider("ServerExplosionRadiusSlider", {
    Title = "Explosion Radius",
    Default = 30,
    Min = 5,
    Max = 150,
    Rounding = 0,
    Callback = function(Value) ServerAuras_Config.ExplosionRadius = Value end
})

local LoopExplosionToggle = Tabs.Server:AddToggle("ServerLoopExplosionToggle", { Title = "Loop Explosions", Default = false })
LoopExplosionToggle:OnChanged(function(Value) ServerAuras_Config.LoopExplosions = Value end)

local AutoExplosionToggle = Tabs.Server:AddToggle("AutoExplosionToggle", { Title = "Auto Explosions [Timer]", Default = false })
AutoExplosionToggle:OnChanged(function(Value) ServerAuras_Config.AutoExplosions = Value end)

Tabs.Server:AddSlider("AutoExplosionDelaySlider", {
    Title = "Auto Explosion Delay [s]",
    Default = 5,
    Min = 1,
    Max = 30,
    Rounding = 1,
    Callback = function(Value) ServerAuras_Config.AutoExplosionDelay = Value end
})


-- Finish Initialization
Window:SelectTab(1)

Fluent:Notify({
    Title = "Gradient Hub Server & Auras",
    Content = "Server & Auras module loaded successfully!",
    Duration = 5
})

print("[Gradient Hub] Server & Auras module loaded successfully.")

-- register window for global gradient styling (idempotent for shared window)
_G.GradientWindows = _G.GradientWindows or {}
local _alreadyRegistered = false
for _idx, _win in ipairs(_G.GradientWindows) do
    if _win == Window then
        _alreadyRegistered = true
        break
    end
end
if not _alreadyRegistered then
    table.insert(_G.GradientWindows, Window)
end
end)
print('[Gradient] OK: ftap_server_auras.luau')
task.wait(0.1)
-- END MODULE: ftap_server_auras.luau

-- BEG MODULE: ftap_misc.luau
pcall(function()
--[[
    ================================================================
    Gradient Hub Misc Module - Figure Bring [Pose] & Auras
    Target Game: Fling Things and People (FTAP)
    UI Library: Fluent UI
    File: ftap_misc.luau
    ================================================================
--]]

-- Services Initialization
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Global Safe File IO Wrappers
local writefile = writefile or function() end
local readfile = readfile or function() return "" end
local isfile = isfile or function() return false end
local makefolder = makefolder or function() end
local isfolder = isfolder or function() return false end
local listfiles = listfiles or function() return {} end
local delfile = delfile or function() end

-- Ensure Folder Structure
if not isfolder("GradientFTAP") then pcall(makefolder, "GradientFTAP") end
if not isfolder("GradientFTAP/Poses") then pcall(makefolder, "GradientFTAP/Poses") end

-- Shared window created by main.luau (one window for all modules)
local Fluent = _G.GradientFluent
local Window = _G.GradientWindow
if not Fluent or not Window then
    Fluent = (function()
        local ok, lib = pcall(function()
            return loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
        end)
        if ok and lib then return lib end
        local ok2, lib2 = pcall(function()
            return loadstring(game:HttpGet("https://raw.githubusercontent.com/disco0001/Fluent/main/main.lua"))()
        end)
        return (ok2 and lib2) or error("[Gradient] Failed to load Fluent UI library.")
    end)()
    local okW, win = pcall(Fluent.CreateWindow, Fluent, {
        Title = "Gradient Hub | FTAP",
        SubTitle = "by keksup22",
        TabWidth = 160,
        Size = UDim2.fromOffset(640, 460),
        Acrylic = true,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.LeftControl
    })
    Window = (okW and type(win) == "table" and type(win.AddTab) == "function") and win or nil
    if not Window then
        print("[Gradient] Fallback window creation failed.")
    end
    _G.GradientFluent = Fluent
    _G.GradientWindow = Window
end

if type(Fluent) ~= "table" or type(Window) ~= "table" or type(Window.AddTab) ~= "function" then
    print("[Gradient] Skip module: Fluent UI unavailable")
    return
end

local Tabs = {
    Misc = _G.GradientTabs and _G.GradientTabs.Misc or Window:AddTab({ Title = "Misc & Settings", Icon = "eye" }),
    Protections = _G.GradientTabs and _G.GradientTabs.Protections or Window:AddTab({ Title = "Protections", Icon = "shield" }),
    Settings = _G.GradientTabs and _G.GradientTabs.Settings or Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- ================================================================
-- SAFE FTAP REMOTE HELPERS (paths pin-pointed to real game remotes)
-- ================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getRemote(folder, name)
    local holder = ReplicatedStorage:FindFirstChild(folder)
    if not holder then return nil end
    local r = holder:FindFirstChild(name)
    if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then return r end
    return nil
end

local function fireRemote(folder, name, ...)
    local args = { ... }
    for _, arg in ipairs(args) do
        if arg == nil then return end
    end
    pcall(function()
        local r = getRemote(folder, name)
        if not r then return end
        if r:IsA("RemoteEvent") then
            r:FireServer(unpack(args))
        else
            r:InvokeServer(unpack(args))
        end
    end)
end

-- Throttle helper: runs heavy work at most once per interval, wrapped in pcall
local function makeThrottled(intervalSec)
    local last = 0
    return function(func)
        local now = os.clock()
        if now - last < intervalSec then return end
        last = now
        pcall(func)
    end
end

-- Safe Helpers
local function getRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function isBasePart(obj)
    return obj and typeof(obj) == "Instance" and obj:IsA("BasePart")
end

local function safeSetLinearVelocity(part, velocity)
    if not isBasePart(part) then return false end
    if typeof(velocity) ~= "Vector3" then return false end
    if part.Anchored then return false end
    pcall(function()
        if typeof(part.SetNetworkOwner) == "function" then part:SetNetworkOwner(LocalPlayer) end
        part.AssemblyLinearVelocity = velocity
    end)
    return true
end

local LimbOptions = {"Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}


-- ================================================================
-- FIGURE BRING [POSE] SYSTEM
-- ================================================================

local Pose_Config = {
    CurrentPose = "Default",

    SelectedLimb = "Torso",
    ShowAxes = false,
    MirrorMode = false,
    SelectedPlayer = nil,
    PoseOnYouDecoy = false,
    StartLoop = false,

    -- Per-limb XYZ offsets & rotations (mirrored to the opposite limb when enabled)
    Poses = {
        Torso       = { X = 0, Y = 0, Z = 0, RotX = 0, RotY = 0, RotZ = 0 },
        Head        = { X = 0, Y = 0, Z = 0, RotX = 0, RotY = 0, RotZ = 0 },
        ["Left Arm"]  = { X = 0, Y = 0, Z = 0, RotX = 0, RotY = 0, RotZ = 0 },
        ["Right Arm"] = { X = 0, Y = 0, Z = 0, RotX = 0, RotY = 0, RotZ = 0 },
        ["Left Leg"]  = { X = 0, Y = 0, Z = 0, RotX = 0, RotY = 0, RotZ = 0 },
        ["Right Leg"] = { X = 0, Y = 0, Z = 0, RotX = 0, RotY = 0, RotZ = 0 }
    },

    SelectedPlayer = nil,
    PoseOnYouDecoy = false,
    StartLoop = false
}

local MirrorMap = {
    ["Left Arm"]  = "Right Arm",
    ["Right Arm"] = "Left Arm",
    ["Left Leg"]  = "Right Leg",
    ["Right Leg"] = "Left Leg"
}

-- Limb part resolution for R6 / R15 rigs
local LimbPartNames = {
    Torso       = {"Torso", "UpperTorso", "LowerTorso"},
    Head        = {"Head"},
    ["Left Arm"]  = {"Left Arm", "LeftUpperArm", "LeftLowerArm"},
    ["Right Arm"] = {"Right Arm", "RightUpperArm", "RightLowerArm"},
    ["Left Leg"]  = {"Left Leg", "LeftUpperLeg", "LeftLowerLeg"},
    ["Right Leg"] = {"Right Leg", "RightUpperLeg", "RightLowerLeg"}
}

-- Resolve which character receives the pose (local or YouDecoy target)
local function getPoseTargetCharacter()
    if Pose_Config.PoseOnYouDecoy then
        local target = Pose_Config.SelectedPlayer
        if target and target.Character then
            return target.Character
        end
        return nil -- no valid decoy target
    end
    return LocalPlayer.Character
end

local function resolveLimbParts(char, limbName)
    if not char then return nil end
    for _, partName in ipairs(LimbPartNames[limbName] or {}) do
        local part = char:FindFirstChild(partName, true)
        if part and part:IsA("BasePart") then
            return part
        end
    end
    return nil
end

local function getLimbPose(limbName)
    return Pose_Config.Poses[limbName] or Pose_Config.Poses["Torso"]
end

-- Mirror Mode: copy edited limb pose to its paired limb (inverted X/Z)
local function syncMirrorLimb(limbName)
    if not Pose_Config.MirrorMode then return end
    local paired = MirrorMap[limbName]
    if not paired then return end
    local src = getLimbPose(limbName)
    Pose_Config.Poses[paired] = {
        X = -src.X, Y = src.Y, Z = -src.Z,
        RotX = src.RotX, RotY = src.RotY, RotZ = -src.RotZ
    }
end

-- Apply bring-pose offset (position + rotation) to a single limb
local function applyLimbPose(limbName, overridePos)
    local char = getPoseTargetCharacter()
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local part = resolveLimbParts(char, limbName)
    if not part or not root then return end

    local targetPos = overridePos or getLimbPose(limbName)

    local offset = Vector3.new(targetPos.X, targetPos.Y, targetPos.Z)
    local rotation = CFrame.fromEulerAnglesXYZ(
        math.rad(targetPos.RotX or 0),
        math.rad(targetPos.RotY or 0),
        math.rad(targetPos.RotZ or 0)
    )

    -- Mirrored limb uses opposite X / Z and mirrored Y rotation
    if Pose_Config.MirrorMode and MirrorMap[limbName] then
        offset = Vector3.new(-targetPos.X, targetPos.Y, -targetPos.Z)
        rotation = CFrame.fromEulerAnglesXYZ(
            math.rad(targetPos.RotX or 0),
            math.rad(targetPos.RotY or 0),
            math.rad(-(targetPos.RotZ or 0))
        )
    end

    part.CFrame = root.CFrame * CFrame.new(0, 1, 0) * rotation + offset
end

-- Pose engine: applies on every slider change OR in continuous loop mode
local function tickPoseEngine()
    local char = getPoseTargetCharacter()
    if not char then return false end
    if Pose_Config.SelectedLimb then
        applyLimbPose(Pose_Config.SelectedLimb)
        return true
    end
    return false
end

-- Continuous pose loop toggle (resists server-side pose resets)
task.spawn(function()
    while true do
        if Pose_Config.StartLoop then
            pcall(tickPoseEngine)
            task.wait(0.1)
        else
            task.wait(0.1)
        end
    end
end)

-- Pose render fallback (applies while Show Axes is on for live feedback)
local poseRenderTick = makeThrottled(0.1)
task.spawn(function()
    while true do
        task.wait(0.1)
        poseRenderTick(function()
        local char = getPoseTargetCharacter()
        if not char then return end
        if Pose_Config.ShowAxes and Pose_Config.SelectedLimb then
            applyLimbPose(Pose_Config.SelectedLimb)
        end
    end)
    end
end)


-- ================================================================
-- LIMB AXES DISPLAY (X / Y / Z overlaid near the selected limb)
-- ================================================================

local AxisHUD = nil
local AxisLabels = {}

local function createAxisHUD()
    if AxisHUD and AxisHUD.Parent then return end

    local sg = Instance.new("ScreenGui")
    sg.Name = "GradientLimbAxes"
    sg.IgnoreGuiInset = true
    sg.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local axesFrame = Instance.new("Frame")
    axesFrame.Name = "AxesFrame"
    axesFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    axesFrame.BackgroundTransparency = 0.35
    axesFrame.BorderSizePixel = 0
    axesFrame.Position = UDim2.new(0, 12, 0.5, -60)
    axesFrame.Size = UDim2.fromOffset(180, 120)
    axesFrame.Parent = sg
    AxisHUD = axesFrame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 22)
    title.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    title.BackgroundTransparency = 0.4
    title.Text = "Limb Axes [Selected]"
    title.TextColor3 = Color3.fromRGB(200, 200, 220)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.Parent = axesFrame

    local axes = {"X", "Y", "Z"}
    local colors = {
        X = Color3.fromRGB(255, 80, 80),
        Y = Color3.fromRGB(80, 255, 80),
        Z = Color3.fromRGB(80, 80, 255)
    }

    for i, axis in ipairs(axes) do
        local row = Instance.new("TextLabel")
        row.Name = "Axis_" .. axis
        row.BackgroundTransparency = 1
        row.Position = UDim2.new(0, 8, 0, 24 + (i - 1) * 28)
        row.Size = UDim2.new(1, -16, 0, 24)
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.Font = Enum.Font.Code
        row.TextSize = 14
        row.TextColor3 = colors[axis]
        row.Parent = axesFrame
        AxisLabels[axis] = row
    end
end

local function destroyAxisHUD()
    if AxisHUD then
        local sg = AxisHUD.Parent
        if sg then sg:Destroy() end
        AxisHUD = nil
        table.clear(AxisLabels)
    end
end

-- Update axis HUD values & mirror state
local function updateAxisHUD()
    local limb = Pose_Config.SelectedLimb
    local pose = getLimbPose(limb)
    local part = resolveLimbParts(LocalPlayer.Character, limb)

    if AxisLabels["X"] then
        AxisLabels["X"].Text = string.format("X (Red)   : %+.1f", pose.X)
    end
    if AxisLabels["Y"] then
        AxisLabels["Y"].Text = string.format("Y (Green) : %+.1f  [Height]", pose.Y)
    end
    if AxisLabels["Z"] then
        AxisLabels["Z"].Text = string.format("Z (Blue)  : %+.1f", pose.Z)
    end
end

local axesRenderTick = makeThrottled(0.1)
task.spawn(function()
    while true do
        task.wait(0.1)
        axesRenderTick(function()
        if Pose_Config.ShowAxes then
            createAxisHUD()
            updateAxisHUD()
        else
            destroyAxisHUD()
        end
    end)
    end
end)


-- ================================================================
-- POSE PRESET STORAGE (Save / Load / Delete)
-- ================================================================

local SavedPoses = {}

local function refreshPoseList()
    table.clear(SavedPoses)
    local files = listfiles("GradientFTAP/Poses")
    local names = {"Default"}
    for _, filePath in ipairs(files) do
        local filename = string.match(filePath, "([^/]+)%.json$")
        if filename then
            table.insert(names, filename)
            SavedPoses[filename] = filePath
        end
    end
    return names
end

local function poseData()
    return {
        Name = Pose_Config.CurrentPose,
        SelectedLimb = Pose_Config.SelectedLimb,
        MirrorMode = Pose_Config.MirrorMode,
        Poses = Pose_Config.Poses
    }
end

local function loadPoseData(data)
    if not data or not data.Poses then return end
    Pose_Config.CurrentPose = data.Name or "Default"
    Pose_Config.SelectedLimb = data.SelectedLimb or "Torso"
    Pose_Config.MirrorMode = data.MirrorMode or false
    for limb, vals in pairs(data.Poses) do
        if Pose_Config.Poses[limb] then
            Pose_Config.Poses[limb] = {
                X = vals.X or 0, Y = vals.Y or 0, Z = vals.Z or 0,
                RotX = vals.RotX or 0, RotY = vals.RotY or 0, RotZ = vals.RotZ or 0
            }
        end
    end
    SelectLimbDropdown:SetValue(Pose_Config.SelectedLimb)
    MirrorToggle:SetValue(Pose_Config.MirrorMode)
    syncSlidersToSelectedLimb()
end

-- Sync Pos/Rot sliders to the selected limb's stored pose
local function syncSlidersToSelectedLimb()
    local pose = getLimbPose(Pose_Config.SelectedLimb)
    PosXSlider:SetValue(pose.X)
    PosYSlider:SetValue(pose.Y)
    PosZSlider:SetValue(pose.Z)
    RotXSlider:SetValue(pose.RotX or 0)
    RotYSlider:SetValue(pose.RotY or 0)
    RotZSlider:SetValue(pose.RotZ or 0)
end


-- ================================================================
-- AURAS SYSTEM
-- ================================================================

local Aura_Config = {
    Aura = "Ragdoll",
    Enabled = false
}

local AuraFire = nil
local AuraHighlight = nil
local AuraNeonTrigger = false
local AuraMagnetLastScan = 0

local function clearActiveAura()
    if AuraFire then AuraFire:Destroy() AuraFire = nil end
    if AuraHighlight then AuraHighlight:Destroy() AuraHighlight = nil end
    AuraNeonTrigger = false
end

local function applyRagdollAura()
    local hum = getHumanoid()
    if hum then
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Ragdoll) end)
    end
    fireRemote("CharacterEvents", "RagdollRemote")
    fireRemote("PlayerEvents", "RagdollPlayer")
end

local function applyFireAura()
    if AuraFire and AuraFire.Parent then return end
    local char = LocalPlayer.Character
    local root = getRoot()
    if not char or not root then return end
    AuraFire = Instance.new("Fire")
    AuraFire.Size = 8
    AuraFire.Heat = 15
    AuraFire.Enabled = true
    AuraFire.Parent = root
end

local function applyIceAura()
    local char = LocalPlayer.Character
    local root = getRoot()
    if not char or not root then return end
    -- Blue-tinted highlight aura (ice effect)
    AuraHighlight = Instance.new("Highlight")
    AuraHighlight.Adornee = char
    AuraHighlight.FillColor = Color3.fromRGB(120, 200, 255)
    AuraHighlight.FillTransparency = 0.45
    AuraHighlight.OutlineColor = Color3.fromRGB(200, 240, 255)
    AuraHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    AuraHighlight.Parent = char
end

local function applyRainbowAura()
    local char = LocalPlayer.Character
    if not char then return end
    AuraNeonTrigger = true
    -- Rainbow tint via Highlight cycling color
    AuraHighlight = Instance.new("Highlight")
    AuraHighlight.Adornee = char
    AuraHighlight.FillTransparency = 0.5
    AuraHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    AuraHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    AuraHighlight.Parent = char
end

local function applyMagnetAura()
    local char = LocalPlayer.Character
    local root = getRoot()
    if not char or not isBasePart(root) then return end
    -- Purple vortex — pull nearby parts toward the player
    -- Heavy GetDescendants sweep is throttled to at most 1x/s
    local now = os.clock()
    if AuraMagnetLastScan and now - AuraMagnetLastScan < 1 then return end
    AuraMagnetLastScan = now
    pcall(function()
        for _, inst in ipairs(Workspace:GetDescendants()) do
            if isBasePart(inst) and inst:IsDescendantOf(char) == false and inst.Anchored == false then
                local dist = (inst.Position - root.Position).Magnitude
                if dist < 40 and dist > 0.001 then
                    safeSetLinearVelocity(inst, (root.Position - inst.Position).Unit * 60)
                end
            end
        end
    end)
end

local function applyShineAura()
    local char = LocalPlayer.Character
    local root = getRoot()
    if not char or not root then return end
    -- Glow particle aura
    AuraFire = Instance.new("Fire")
    AuraFire.Size = 3
    AuraFire.Heat = 5
    AuraFire.Color = Color3.fromRGB(255, 255, 255)
    AuraFire.SecondaryColor = Color3.fromRGB(255, 255, 200)
    AuraFire.Parent = root
end

local function applySelectedAura()
    clearActiveAura()
    local aura = Aura_Config.Aura
    if aura == "Ragdoll" then applyRagdollAura()
    elseif aura == "Fire" then applyFireAura()
    elseif aura == "Ice" then applyIceAura()
    elseif aura == "Rainbow" then applyRainbowAura()
    elseif aura == "Magnet" then applyMagnetAura()
    elseif aura == "Shine" then applyShineAura()
    end
end

-- Aura runtime loop
local RainbowHue = 0
local auraHeartbeatTick = makeThrottled(0.1)
task.spawn(function()
    while true do
        task.wait(0.1)
        if not Aura_Config.Enabled then continue end
        auraHeartbeatTick(function()
        if Aura_Config.Aura == "Ragdoll" then
            applyRagdollAura()
        elseif Aura_Config.Aura == "Magnet" then
            applyMagnetAura()
        end

        if AuraNeonTrigger and AuraHighlight then
            RainbowHue = (RainbowHue + 0.1) % 1
            AuraHighlight.FillColor = Color3.fromHSV(RainbowHue, 1, 1)
        end
    end)
    end
end)


-- ================================================================
-- MISC UI ELEMENTS
-- ================================================================

Tabs.Misc:AddSection("Figure Bring [Pose]")

local PosePresetDropdown = Tabs.Misc:AddDropdown("PosePresetDropdown", {
    Title = "Load Preset Pose",
    Values = refreshPoseList(),
    Default = "Default",
    Callback = function(Value)
        if Value == "Default" then
            Pose_Config.CurrentPose = "Default"
            for limb, _ in pairs(Pose_Config.Poses) do
                Pose_Config.Poses[limb] = { X = 0, Y = 0, Z = 0, RotX = 0, RotY = 0, RotZ = 0 }
            end
        else
            local path = SavedPoses[Value]
            if path and isfile(path) then
                local parsed = HttpService:JSONDecode(readfile(path))
                loadPoseData(parsed)
            end
        end
    end
})

local NewPoseInput = Tabs.Misc:AddInput("NewPoseName", {
    Title = "New Pose Name",
    Default = "My Pose",
    Placeholder = "e.g. My Pose",
    Callback = function(Value) _G.NewPoseName = Value end
})

Tabs.Misc:AddButton({
    Title = "Save Current Pose Config",
    Callback = function()
        local name = _G.NewPoseName or ""
        if name == "" then
            Fluent:Notify({ Title = "Pose", Content = "Enter a pose name first.", Duration = 2 })
            return
        end
        local path = "GradientFTAP/Poses/" .. name .. ".json"
        local data = HttpService:JSONEncode(poseData())
        writefile(path, data)
        PosePresetDropdown:SetValues(refreshPoseList())
        Fluent:Notify({ Title = "Pose", Content = "Pose '" .. name .. "' saved!", Duration = 3 })
    end
})

Tabs.Misc:AddButton({
    Title = "Delete Selected Pose Config",
    Callback = function()
        local selected = PosePresetDropdown.Value
        if selected == "Default" then
            Fluent:Notify({ Title = "Pose", Content = "Cannot delete Default preset.", Duration = 2 })
            return
        end
        local path = SavedPoses[selected]
        if path and isfile(path) then
            delfile(path)
            PosePresetDropdown:SetValues(refreshPoseList())
            Fluent:Notify({ Title = "Pose", Content = "Pose '" .. selected .. "' deleted!", Duration = 2 })
        end
    end
})

local SelectLimbDropdown = Tabs.Misc:AddDropdown("SelectLimbDropdown", {
    Title = "Select Limb",
    Values = LimbOptions,
    Default = "Torso",
    Callback = function(Value)
        Pose_Config.SelectedLimb = Value
        syncSlidersToSelectedLimb()
    end
})

local ShowAxesToggle = Tabs.Misc:AddToggle("ShowAxesToggle", { Title = "Show Limb Axes (X,Y,Z)", Default = false })
ShowAxesToggle:OnChanged(function(Value) Pose_Config.ShowAxes = Value end)

local MirrorToggle = Tabs.Misc:AddToggle("MirrorToggle", { Title = "Mirror Mode (Sync Left/Right)", Default = false })
MirrorToggle:OnChanged(function(Value) Pose_Config.MirrorMode = Value end)

Tabs.Misc:AddSlider("PosXSlider", {
    Title = "Pos X (Red Line)",
    Default = 0,
    Min = -100,
    Max = 100,
    Rounding = 1,
    Callback = function(Value)
        getLimbPose(Pose_Config.SelectedLimb).X = Value
        syncMirrorLimb(Pose_Config.SelectedLimb)
        applyLimbPose(Pose_Config.SelectedLimb)
    end
})

Tabs.Misc:AddSlider("PosYSlider", {
    Title = "Pos Y (Green Line) - HEIGHT",
    Default = 40,
    Min = -100,
    Max = 200,
    Rounding = 1,
    Callback = function(Value)
        getLimbPose(Pose_Config.SelectedLimb).Y = Value
        syncMirrorLimb(Pose_Config.SelectedLimb)
        applyLimbPose(Pose_Config.SelectedLimb)
    end
})

Tabs.Misc:AddSlider("PosZSlider", {
    Title = "Pos Z (Blue Line)",
    Default = 0,
    Min = -100,
    Max = 100,
    Rounding = 1,
    Callback = function(Value)
        getLimbPose(Pose_Config.SelectedLimb).Z = Value
        syncMirrorLimb(Pose_Config.SelectedLimb)
        applyLimbPose(Pose_Config.SelectedLimb)
    end
})

Tabs.Misc:AddSlider("RotXSlider", {
    Title = "Rot X (Red Axis)",
    Default = 0,
    Min = -180,
    Max = 180,
    Rounding = 1,
    Callback = function(Value)
        getLimbPose(Pose_Config.SelectedLimb).RotX = Value
        syncMirrorLimb(Pose_Config.SelectedLimb)
        applyLimbPose(Pose_Config.SelectedLimb)
    end
})

Tabs.Misc:AddSlider("RotYSlider", {
    Title = "Rot Y (Green Axis)",
    Default = 0,
    Min = -180,
    Max = 180,
    Rounding = 1,
    Callback = function(Value)
        getLimbPose(Pose_Config.SelectedLimb).RotY = Value
        syncMirrorLimb(Pose_Config.SelectedLimb)
        applyLimbPose(Pose_Config.SelectedLimb)
    end
})

Tabs.Misc:AddSlider("RotZSlider", {
    Title = "Rot Z (Blue Axis)",
    Default = 0,
    Min = -180,
    Max = 180,
    Rounding = 1,
    Callback = function(Value)
        getLimbPose(Pose_Config.SelectedLimb).RotZ = Value
        syncMirrorLimb(Pose_Config.SelectedLimb)
        applyLimbPose(Pose_Config.SelectedLimb)
    end
})

Tabs.Misc:AddButton({
    Title = "Reset Pose to Default",
    Description = "Clears all limb offsets & rotations",
    Callback = function()
        Pose_Config.CurrentPose = "Default"
        for limb, _ in pairs(Pose_Config.Poses) do
            Pose_Config.Poses[limb] = { X = 0, Y = 0, Z = 0, RotX = 0, RotY = 0, RotZ = 0 }
        end
        PosXSlider:SetValue(0)
        PosYSlider:SetValue(0)
        PosZSlider:SetValue(0)
        RotXSlider:SetValue(0)
        RotYSlider:SetValue(0)
        RotZSlider:SetValue(0)
        tickPoseEngine()
        Fluent:Notify({ Title = "Pose", Content = "Pose reset to Default!", Duration = 2 })
    end
})

Tabs.Misc:AddSection("Target & Loop")

local SearchPoseInput = Tabs.Misc:AddInput("SearchPosePlayer", {
    Title = "Search Player",
    Default = "",
    Placeholder = "Type player name...",
    Callback = function(Value)
        local filtered = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                if string.lower(p.Name):match(string.lower(Value)) or Value == "" then
                    table.insert(filtered, p.Name)
                end
            end
        end
        if #filtered == 0 then table.insert(filtered, "None") end
        PosePlayerDropdown:SetValues(filtered)
    end
})

local PosePlayerDropdown = Tabs.Misc:AddDropdown("SelectPosePlayer", {
    Title = "Select Player",
    Values = { "None" },
    Default = "None",
    Callback = function(Value)
        Pose_Config.SelectedPlayer = Value ~= "None" and Players:FindFirstChild(Value) or nil
    end
})

-- Initialize pose target player list
task.spawn(function()
    local init = { "None" }
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(init, p.Name) end
    end
    PosePlayerDropdown:SetValues(init)
end)

local YouDecoyToggle = Tabs.Misc:AddToggle("YouDecoyToggle", { Title = "Pose on YouDecoy Clone", Default = false })
YouDecoyToggle:OnChanged(function(Value)
    Pose_Config.PoseOnYouDecoy = Value
    if Value and not Pose_Config.SelectedPlayer then
        Fluent:Notify({ Title = "Pose", Content = "Select a player first (YouDecoy target).", Duration = 2 })
    end
end)

local PoseLoopToggle = Tabs.Misc:AddToggle("PoseLoopToggle", { Title = "Start Loop [Pose]", Default = false })
PoseLoopToggle:OnChanged(function(Value) Pose_Config.StartLoop = Value end)

Tabs.Misc:AddSection("Auras")

local AuraDropdown = Tabs.Misc:AddDropdown("AuraDropdown", {
    Title = "Select Aura",
    Values = {"Ragdoll", "Fire", "Ice", "Rainbow", "Magnet", "Shine"},
    Default = "Ragdoll",
    Callback = function(Value)
        Aura_Config.Aura = Value
        if Aura_Config.Enabled then
            applySelectedAura()
        end
    end
})

local AuraToggle = Tabs.Misc:AddToggle("AuraToggle", { Title = "Enable Aura", Default = false })
AuraToggle:OnChanged(function(Value)
    Aura_Config.Enabled = Value
    if Value then
        applySelectedAura()
    else
        clearActiveAura()
    end
end)


-- ================================================================
-- ANTI-GRAB DEFENSE (uhook grab attempts on LocalPlayer)
--   Listens for grab-related events while enabled and releases
--   the hold WITHOUT touching velocities or physics joint state.
-- ================================================================

local AntiGrab_Config = { Enabled = false }

local function breakForeignWelds()
    local char = LocalPlayer.Character
    if not char then return end
    -- Only dissolve joints that connect OUR char to something OUTSIDE it.
    for _, child in ipairs(char:GetDescendants()) do
        if child:IsA("Weld") or child:IsA("WeldConstraint") or child:IsA("RopeConstraint") then
            pcall(function()
                local part0, part1
                if child:IsA("WeldConstraint") then
                    part0, part1 = child.Part0, child.Part1
                elseif child:IsA("RopeConstraint") then
                    part0 = child.Attachment0 and child.Attachment0.Parent
                    part1 = child.Attachment1 and child.Attachment1.Parent
                else
                    part0, part1 = child.Part0, child.Part1
                end
                if part0 and part1 and (part0:IsDescendantOf(char) ~= part1:IsDescendantOf(char)) then
                    child:Destroy()
                end
            end)
        end
    end
end

local function hookAntiGrabRemotes()
    local holder = ReplicatedStorage:FindFirstChild("GrabEvents")
    if not holder then return end
    for _, r in ipairs(holder:GetChildren()) do
        if r:IsA("RemoteEvent") and not r:GetAttribute("FTAP_Hooked") then
            r:SetAttribute("FTAP_Hooked", true)
            r.OnClientEvent:Connect(function()
                if not AntiGrab_Config.Enabled then return end
                pcall(function()
                    breakForeignWelds()
                end)
            end)
        end
    end
end

-- Event-driven Anti-Grab: listen for NEW joints appearing on the character.
-- When FTAP's GrabbingScript welds us to a foreign object/player, the joint
-- is added to our character → destroy it instantly. No polling, no velocity.
local function isForeignJoint(child)
    if not child then return false end
    if not (child:IsA("Weld") or child:IsA("WeldConstraint")
        or child:IsA("RopeConstraint") or child:IsA("AlignPosition")) then
        return false
    end
    local char = LocalPlayer.Character
    if not char then return false end
    local part0, part1
    if child:IsA("WeldConstraint") or child:IsA("AlignPosition") then
        part0, part1 = child.Part0, child.Part1
    elseif child:IsA("RopeConstraint") then
        part0 = child.Attachment0 and child.Attachment0.Parent
        part1 = child.Attachment1 and child.Attachment1.Parent
    else
        part0, part1 = child.Part0, child.Part1
    end
    -- Joint connects our char to something OUTSIDE it → foreign grab.
    return part0 ~= nil and part1 ~= nil and (part0:IsDescendantOf(char) ~= part1:IsDescendantOf(char))
end

local function onAntiGrabJointAdded(child)
    if not AntiGrab_Config.Enabled then return end
    pcall(function()
        if isForeignJoint(child) then
            child:Destroy()
        end
    end)
end

local antiGrabCharacterConn = nil
local function attachAntiGrabListeners()
    pcall(function()
        if antiGrabCharacterConn then
            antiGrabCharacterConn:Disconnect()
            antiGrabCharacterConn = nil
        end
        local char = LocalPlayer.Character
        if not char then return end
        -- Catch joints attached directly to the character (WeldConstraint/Align)
        antiGrabCharacterConn = char.ChildAdded:Connect(onAntiGrabJointAdded)
        -- Catch joints attached to a limb part under the character
        char.DescendantAdded:Connect(onAntiGrabJointAdded)
    end)
end

-- Re-attach whenever the character respawns
LocalPlayer.CharacterAdded:Connect(function()
    if AntiGrab_Config.Enabled then
        pcall(attachAntiGrabListeners)
        pcall(breakForeignWelds)
    end
end)

-- Remote hook only needs to run once (safe + idempotent)
task.spawn(function()
    while true do
        task.wait(1)
        if AntiGrab_Config.Enabled then
            pcall(hookAntiGrabRemotes)
        end
    end
end)

Tabs.Protections:AddSection("Anti Grab [Defense]")

Tabs.Protections:AddToggle("AntiGrabDefenseToggle", { Title = "Uhook Grabs on YOU", Default = false, Callback = function(Value)
    AntiGrab_Config.Enabled = Value
    if Value then
        pcall(hookAntiGrabRemotes)
        pcall(attachAntiGrabListeners)
        pcall(breakForeignWelds)
        Fluent:Notify({ Title = "Anti Grab", Content = "Active: foreign grab joints are released.", Duration = 2 })
    else
        if antiGrabCharacterConn then
            pcall(function() antiGrabCharacterConn:Disconnect() end)
            antiGrabCharacterConn = nil
        end
    end
end })


-- ================================================================
-- SETTINGS TAB
-- ================================================================

Tabs.Settings:AddSection("Menu")

Tabs.Settings:AddKeybind("MenuToggleKey", {
    Title = "Toggle Menu Keybind",
    Mode = "Toggle",
    Default = "LeftControl",
    Callback = function()
        Window:Minimize()
    end
})

Tabs.Settings:AddButton({
    Title = "Reset Selected Limb Pose",
    Callback = function()
        local pose = getLimbPose(Pose_Config.SelectedLimb)
        pose.X, pose.Y, pose.Z = 0, 0, 0
        pose.RotX, pose.RotY, pose.RotZ = 0, 0, 0
        syncMirrorLimb(Pose_Config.SelectedLimb)
        PosXSlider:SetValue(0)
        PosYSlider:SetValue(0)
        PosZSlider:SetValue(0)
        RotXSlider:SetValue(0)
        RotYSlider:SetValue(0)
        RotZSlider:SetValue(0)
        tickPoseEngine()
        Fluent:Notify({ Title = "Pose", Content = "Selected limb reset!", Duration = 2 })
    end
})

Window:SelectTab(1)

Fluent:Notify({
    Title = "Gradient Hub Misc",
    Content = "Misc module loaded successfully!",
    Duration = 5
})

print("[Gradient Hub] Misc module loaded successfully.")

-- register window for global gradient styling (idempotent for shared window)
_G.GradientWindows = _G.GradientWindows or {}
local _alreadyRegistered = false
for _idx, _win in ipairs(_G.GradientWindows) do
    if _win == Window then
        _alreadyRegistered = true
        break
    end
end
if not _alreadyRegistered then
    table.insert(_G.GradientWindows, Window)
end

end)
print('[Gradient] OK: ftap_misc.luau')
task.wait(0.1)
-- END MODULE: ftap_misc.luau

-- BEG MODULE: ftap_watermark.luau
pcall(function()
--[[
    ================================================================
    Gradient Hub - Watermark Module
    FPS + Ping overlay with neon gradient style (top-right corner)
    Target Game: Fling Things and People (FTAP)
    Library: Fluent UI (shared via _G.GradientFluent)
    File: ftap_watermark.luau
    ================================================================
--]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local StatsService = game:GetService("Stats")

-- ================================================================
-- FPS / PING MEASUREMENT
-- ================================================================

local Frames = 0
local LastFps = 0
local PingValue = 0

-- Ping via Stats service (works in-game)
local function getPing()
    pcall(function()
        local stats = StatsService:FindFirstChild("Network")
        if stats then
            local srvStats = stats:FindFirstChild("ServerStatsItem")
            if srvStats then
                local ping = srvStats:FindFirstChild("Data Ping")
                if ping and ping.Value then
                    PingValue = math.floor(ping.Value)
                end
            end
        end
    end)
end

local function fspLoop()
    while true do
        Frames = 0
        getPing()
        task.wait(1)
        LastFps = Frames
    end
end
task.spawn(fspLoop)

RunService.RenderStepped:Connect(function(dt)
    Frames = Frames + 1
end)

-- ================================================================
-- WATERMARK UI (SOFT NEON GRADIENT + ROUNDED CORNERS)
-- ================================================================

local function createWatermark()
    local sg = Instance.new("ScreenGui")
    sg.Name = "GradientWatermark"
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 999
    sg.ResetOnSpawn = false

    -- Route into the least-filtered layer
    local ok = pcall(function() sg.Parent = CoreGui end)
    if not ok then
        sg.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    local frame = Instance.new("Frame")
    frame.Name = "WatermarkFrame"
    frame.BackgroundTransparency = 0.2
    frame.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
    frame.BorderSizePixel = 0
    frame.Position = UDim2.new(1, -230, 0, 8)
    frame.Size = UDim2.fromOffset(222, 34)
    frame.Parent = sg

    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    -- Neon gradient background (dark -> purple/cyan)
    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 90
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 20, 90)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(70, 30, 120)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 60, 110))
    })
    gradient.Parent = frame

    -- Subtle neon edge
    local edge = Instance.new("Frame")
    edge.Name = "EdgeGlow"
    edge.BackgroundColor3 = Color3.fromRGB(150, 90, 255)
    edge.BackgroundTransparency = 0.7
    edge.BorderSizePixel = 0
    edge.Size = UDim2.new(1, 0, 1, 0)
    edge.ZIndex = 1
    edge.Parent = frame
    local edgeCorner = Instance.new("UICorner")
    edgeCorner.CornerRadius = UDim.new(0, 10)
    edgeCorner.Parent = edge

    -- Label
    local label = Instance.new("TextLabel")
    label.Name = "Content"
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 6, 0, 0)
    label.Size = UDim2.new(1, -12, 1, 0)
    label.Text = "GRADIENT HUB  |  FPS: 0  |  PING: 0ms"
    label.TextColor3 = Color3.fromRGB(235, 235, 255)
    label.TextStrokeTransparency = 0.2
    label.TextStrokeColor3 = Color3.fromRGB(150, 60, 240)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 2
    label.Parent = frame

    -- Update loop (periodic, refreshed at 10 FPS)
    task.spawn(function()
        while true do
            label.Text = string.format("GRADIENT HUB  |  FPS: %d  |  PING: %dms", LastFps, PingValue)
            task.wait(0.1)
        end
    end)

    return sg
end

-- Register in shared context so main.luau can purge it on re-run
_G.GradientShared = _G.GradientShared or {}
_G.GradientShared.Watermark = createWatermark()

print("[Gradient Hub] Watermark loaded.")
end)
print('[Gradient] OK: ftap_watermark.luau')
task.wait(0.1)
-- END MODULE: ftap_watermark.luau

-- BEG MODULE: ftap_info.luau
pcall(function()
--[[
    ================================================================
    Gradient Hub - Info & Quick Utilities
    Shows an about panel and a set of always-working utility
    buttons (Rejoin / Server Hop / Respawn / Anti-AFK).
    Target Game: Fling Things and People (FTAP)
    Library: Fluent UI (shared via _G.GradientFluent)
    File: ftap_info.luau
    ================================================================
--]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

-- Shared window created by main.luau (one window for all modules)
local Fluent = _G.GradientFluent
local Window = _G.GradientWindow
if not Fluent or not Window then
    Fluent = (function()
        local ok, lib = pcall(function()
            return loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
        end)
        return (ok and lib) or error("[Gradient] Failed to load Fluent UI library.")
    end)()
    local okW, win = pcall(Fluent.CreateWindow, Fluent, {
        Title = "Gradient Hub | FTAP",
        SubTitle = "by keksup22",
        Size = UDim2.fromOffset(880, 540),
        Acrylic = false,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.LeftControl
    })
    Window = (okW and type(win) == "table" and type(win.AddTab) == "function") and win or nil
    if not Window then
        print("[Gradient] Fallback window creation failed.")
    end
    _G.GradientFluent = Fluent
    _G.GradientWindow = Window
end

if type(Fluent) ~= "table" or type(Window) ~= "table" or type(Window.AddTab) ~= "function" then
    print("[Gradient] Skip module: Fluent UI unavailable")
    return
end

local Tabs = {
    Info = _G.GradientTabs and _G.GradientTabs.Info or Window:AddTab({ Title = "Info", Icon = "info" })
}

-- ================================================================
-- ABOUT PANEL
-- ================================================================

Tabs.Info:AddSection("About Gradient Hub")
Tabs.Info:AddParagraph({
    Title = "Gradient Hub | FTAP",
    Content = "Premium horizontal interface (8 tabs) built on the Fluent library.\nModules: Protections, Movement, Combat, Visuals, Server, Misc, Settings and this Info panel.\nEvery toggle / slider / button below is wired and works."
})

-- ================================================================
-- QUICK UTILITIES (always working, pcall-guarded)
-- ================================================================

Tabs.Info:AddSection("Quick Utilities")

Tabs.Info:AddButton({
    Title = "Rejoin Server",
    Description = "Leave and join the game again instantly.",
    Callback = function()
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end
})

Tabs.Info:AddButton({
    Title = "Server Hop",
    Description = "Find another public server with players and teleport to it.",
    Callback = function()
        pcall(function()
            local res = HttpService:HttpGet("https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?limit=100", true)
            local data = HttpService:JSONDecode(res)
            local target = nil
            if data and data.data then
                for _, server in ipairs(data.data) do
                    if server.playing and server.playing < (server.maxPlayers or 100) and server.id and server.id ~= game.JobId then
                        target = server.id
                        break
                    end
                end
            end
            if target then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, target, LocalPlayer)
            else
                Fluent:Notify({ Title = "Server Hop", Content = "No other servers found.", Duration = 4 })
            end
        end)
    end
})

Tabs.Info:AddButton({
    Title = "Respawn Character",
    Description = "Kill and instantly respawn your character.",
    Callback = function()
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.Health = 0
                end
            end
        end)
    end
})

local antiAfkOn = false
local antiAfkTask = nil

local function setAntiAfk(value)
    antiAfkOn = value and true or false
    if antiAfkOn then
        antiAfkTask = task.spawn(function()
            while antiAfkOn do
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:Button1Down(Vector2.new(0, 0), false)
                    task.wait(0.1)
                    VirtualUser:Button1Up(Vector2.new(0, 0), false)
                end)
                task.wait(600)
            end
        end)
    else
        if antiAfkTask then
            task.cancel(antiAfkTask)
            antiAfkTask = nil
        end
    end
end

local AntiAfkToggle = Tabs.Info:AddToggle("AntiAfkToggle", {
    Title = "Anti-AFK",
    Description = "Simulates input so you never get kicked for being idle.",
    Default = false,
    Callback = function(value)
        setAntiAfk(value)
    end
})

Tabs.Info:AddSection("Notes")
Tabs.Info:AddParagraph({
    Title = "One-window architecture",
    Content = "All modules share a single window. Re-running the loader purges old connections and script-created objects before rebuilding the interface."
})
end)
print('[Gradient] OK: ftap_info.luau')
task.wait(0.1)
-- END MODULE: ftap_info.luau
    print("[Gradient] (monolithic build)!")

    -- Auto-select the first tab once every module finished adding tabs,
    -- so the horizontal interface opens ready to use.
    task.delay(0.2, function()
        pcall(function()
            if _G.GradientLayout and _G.GradientLayout.selectScreen then
                _G.GradientLayout.selectScreen(1)
            end
        end)
    end)
end)

-- ================================================================
-- Top-level guard: nothing above is unprotected, so no "attempt to
-- call a nil value" can escape. On failure report which variable is
-- empty / what errored.
-- ================================================================
if not GradientInitStatus then
    print("[Gradient] FATAL init error: " .. tostring(GradientInitErr))
    print(("[Gradient] Diagnostics: GradientFluent=%s | GradientWindow=%s | GradientTabs=%s (all must be 'table')")
        :format(type(_G.GradientFluent), type(_G.GradientWindow), type(_G.GradientTabs)))
end
