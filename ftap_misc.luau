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
        Size = UDim2.fromOffset(580, 460),
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
    Misc = _G.GradientTabs and _G.GradientTabs.Misc or Window:AddTab({ Title = "Misc & Settings", Icon = "sparkles" }),
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

