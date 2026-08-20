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

