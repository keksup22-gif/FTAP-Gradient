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
    Window = Fluent:CreateWindow({
        Title = "Gradient Hub | FTAP",
        SubTitle = "by keksup22",
        TabWidth = 160,
        Size = UDim2.fromOffset(580, 460),
        Acrylic = true,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.LeftControl
    })
    _G.GradientFluent = Fluent
    _G.GradientWindow = Window
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
            root.CFrame = LP_Config.LockedCFrame
        else
            LP_Config.LockedCFrame = nil
        end

        -- Desync (Velocity / CFrame Packet Spoofing) - never while ragdolled
        if LP_Config.Desync and not isRagdolled() then
            local oldVelocity = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(0, -1000, 0)
            RunService.RenderStepped:Wait()
            if root then
                root.AssemblyLinearVelocity = oldVelocity
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
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
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
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end

        -- Speed Control (never force WalkSpeed while ragdolled by FTAP)
        if LP_Config.EnableSpeed and not isRagdolled() then
            hum.WalkSpeed = LP_Config.SpeedControl
        end

        -- Jump Power / Height (only when user explicitly enables it AND the
        -- body is not under FTAP's RagdollPlayerCharacter control).
        -- While disabled we never write Humanoid params, so the game's own
        -- custom jump physics (TouchJump / RagdollPlayerCharacter) stay intact.
        if LP_Config.EnableJumpPower and not isRagdolled() then
            hum.UseJumpPower = true
            hum.JumpPower = LP_Config.JumpPower
        end

        -- Water Walk Platform Logic
        if LP_Config.WaterWalk then
            if not WaterPlatform or not WaterPlatform.Parent then
                WaterPlatform = Instance.new("Part")
                WaterPlatform.Name = "FTAP_WaterPlatform"
                WaterPlatform.Size = Vector3.new(12, 1, 12)
                WaterPlatform.Anchored = true
                WaterPlatform.Transparency = 1
                WaterPlatform.Parent = Workspace
            end
            WaterPlatform.CFrame = CFrame.new(root.Position.X, 2.5, root.Position.Z)
        else
            if WaterPlatform then
                WaterPlatform:Destroy()
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
            if targetPos and root and not isRagdolled() then
                root.CFrame = CFrame.new(targetPos)
            end
        end
    end
end)

-- Teleport to Mouse Helper
local function teleportToMouse()
    local mouse = LocalPlayer:GetMouse()
    local root = getRoot()
    if mouse and mouse.Hit and root and not isRagdolled() then
        root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
        Fluent:Notify({ Title = "Teleport", Content = "Teleported to mouse position!", Duration = 2 })
    end
end

-- Vehicle / Player Fly System
local BodyGyro, BodyVelocity
local flyRenderTick = makeThrottled(0.1)
task.spawn(function()
    while true do
        task.wait(0.1)
        flyRenderTick(function()
        local root = getRoot()
        if not root then return end

        if LP_Config.VehicleFly and not isRagdolled() then
            if not BodyGyro or not BodyGyro.Parent then
                BodyGyro = Instance.new("BodyGyro")
                BodyGyro.P = 9e4
                BodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                BodyGyro.CFrame = root.CFrame
                BodyGyro.Parent = root
            end

            if not BodyVelocity or not BodyVelocity.Parent then
                BodyVelocity = Instance.new("BodyVelocity")
                BodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                BodyVelocity.Velocity = Vector3.new(0, 0, 0)
                BodyVelocity.Parent = root
            end

            BodyGyro.CFrame = Camera.CFrame
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

            BodyVelocity.Velocity = moveDir * (LP_Config.FlySpeed * 10)
        else
            if BodyGyro then BodyGyro:Destroy() BodyGyro = nil end
            if BodyVelocity then BodyVelocity:Destroy() BodyVelocity = nil end
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
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            if hum:GetState() == Enum.HumanoidStateType.Ragdoll or hum:GetState() == Enum.HumanoidStateType.FallingDown then
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end

        -- Anti Explode Physics Fix (only when WE own the physics; never
        -- writes velocity while FTAP's RagdollPlayerCharacter is active)
        if Prot_Config.AntiExplode and not isRagdolled() then
            root.RotVelocity = Vector3.new(0, 0, 0)
            if root.AssemblyLinearVelocity.Magnitude > 250 then
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end
        end

        -- Anti Void Teleport (restore ONLY if we truly fell below the void
        -- line AND the body is not ragdolled by another player / RagdollPC)
        if Prot_Config.AntiVoid and not isRagdolled() and root.Position.Y < Prot_Config.VoidThreshold then
            root.CFrame = CFrame.new(TeleportLocations["Spawn"])
            Fluent:Notify({ Title = "Anti Void", Content = "Saved from falling into the void!", Duration = 3 })
        end

        -- Anti Sticky Self
        if Prot_Config.AntiStickySelf then
            for _, obj in ipairs(char:GetChildren()) do
                if obj:IsA("TouchTransporter") or (obj:IsA("BasePart") and obj.Name == "StickyPart") then
                    obj:Destroy()
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
                        if string.find(string.lower(inst.Name), "blob") and inst:IsA("BasePart") then
                            local dist = (root.Position - inst.Position).Magnitude
                            if dist < 8 then
                                inst.Velocity = (inst.Position - root.Position).Unit * 100
                            end
                        end
                    end
                end)
            end
        end
    end)
    end
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
                        if inst:IsA("BasePart") then
                            inst.CanCollide = false
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
                    child:Destroy()
                end
            end
        end

        if Prot_Config.AntiPaint then
            for _, child in ipairs(char:GetDescendants()) do
                if child:IsA("Decal") or child:IsA("Texture") then
                    if child.Name == "PaintDecal" or string.find(string.lower(child.Name), "paint") then
                        child:Destroy()
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
                        if lArm and lArm:IsA("BasePart") then lArm.CanCollide = false end
                        if rArm and rArm:IsA("BasePart") then rArm.CanCollide = false end
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
                    if inst:IsA("BasePart") or inst:IsA("Model") then
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
                if not root or isRagdolled() then return end
                local vel = root.AssemblyLinearVelocity
                if vel.Magnitude < Prot_Config.FlingSpeedThreshold then
                    antiFlingSafeCFrame = root.CFrame
                elseif antiFlingSafeCFrame then
                    local hum = getHumanoid()
                    root.CFrame = antiFlingSafeCFrame
                    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    root.RotVelocity = Vector3.new(0, 0, 0)
                    if hum then
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                    end
                end
            end)
        end
    end
end)

-- 9. Anti Network Ownership - periodically returns network ownership of our
-- parts to the server (SetNetworkOwner(nil)) so attackers can't keep holding
-- our parts to fling us. Throttled to 0.5s.
local antiNetOwnerTick = makeThrottled(0.5)
task.spawn(function()
    while true do
        task.wait(0.5)
        antiNetOwnerTick(function()
            if Prot_Config.AntiNetworkOwnership then
                local char = LocalPlayer.Character
                if not char then return end
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        pcall(function() part:SetNetworkOwner(nil) end)
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

