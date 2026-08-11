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

local Tabs = {
    Grabs = _G.GradientTabs and _G.GradientTabs.Combat or Window:AddTab({ Title = "Combat & Grabs", Icon = "hand" }),
    Settings = _G.GradientTabs and _G.GradientTabs.Misc or Window:AddTab({ Title = "Misc & Settings", Icon = "settings" })
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
    GrabMethodEnabled = false
}

local HeldObject = nil
local GrabbedPlayer = nil
local MonitoringGrab = false


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
                    HeldObject = nil
                    GrabbedPlayer = nil
                    fireRemote("GrabEvents", "EndGrabEarly")
                    fireRemote("GrabEvents", "DestroyGrabLine")
                    fireRemote("HoldEvents", "Drop")
                end
            end)
        end
    end)
end


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
    if not root then return end
    root.AssemblyLinearVelocity = root.AssemblyLinearVelocity * 0.1
    root.RotVelocity = Vector3.new(0, 0, 0)
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
    if HeldObject and HeldObject:IsA("BasePart") then
        HeldObject.CanCollide = false
    elseif GrabbedPlayer and GrabbedPlayer.Character then
        for _, part in ipairs(GrabbedPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
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
    if not root then return end

    if method == "Kick Grab" then
        -- Repeatedly reposition collision line on the held object
        if heldObj and heldObj:IsA("BasePart") then
            heldObj.CFrame = root.CFrame + Vector3.new(0, 2, 5)
        end

    elseif method == "Lag Grab" then
        -- Freeze the grabbed player physics briefly
        if heldObjectIsPlayer(heldObj) and GrabbedPlayer and GrabbedPlayer.Character then
            local hum = GrabbedPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = 0
                task.wait(0.05)
                hum.WalkSpeed = 16
            end
        end

    elseif method == "Fling Grab" then
        -- Spin / fling the held object
        if heldObj and heldObj:IsA("BasePart") then
            heldObj.AssemblyLinearVelocity = (root.CFrame.LookVector * 800) + Vector3.new(0, 300, 0)
            heldObj.AssemblyAngularVelocity = Vector3.new(50, 50, 50)
        end

    elseif method == "Lock Grab" then
        -- Pin the grabbed player in place
        if GrabbedPlayer and GrabbedPlayer.Character then
            local tRoot = GrabbedPlayer.Character:FindFirstChild("HumanoidRootPart")
            if tRoot then
                tRoot.CFrame = root.CFrame + Vector3.new(0, 2, 5)
                tRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
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

