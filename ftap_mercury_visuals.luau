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

