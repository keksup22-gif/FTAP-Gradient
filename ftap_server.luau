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
        part:SetNetworkOwner(LocalPlayer)
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
        part:SetNetworkOwner(LocalPlayer)
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

