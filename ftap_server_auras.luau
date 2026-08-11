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
    if not myRoot or isRagdolled() then return 0 end
    local targets = getTargetsInRange()
    local count = 0
    for _, plr in ipairs(targets) do
        local tRoot = getTargetRoot(plr)
        if tRoot then
            tRoot.AssemblyLinearVelocity = CFrame.new(myRoot.Position, tRoot.Position).LookVector * 500 + Vector3.new(0, 150, 0)
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
    if not myRoot or isRagdolled() then return end
    local targets = getTargetsInRange()
    local count = 0
    for _, plr in ipairs(targets) do
        local tRoot = getTargetRoot(plr)
        if tRoot then
            tRoot.CFrame = myRoot.CFrame + Vector3.new(0, 5 + count * 3, 0)
            tRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
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
        if tRoot then
            tRoot.CFrame = CFrame.new(0, -250, 0)
            tRoot.AssemblyLinearVelocity = Vector3.new(0, -300, 0)
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
    if not myRoot or isRagdolled() then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not isSafeTarget(plr) then
            local tRoot = getTargetRoot(plr)
            if tRoot then
                local dist = (myRoot.Position - tRoot.Position).Magnitude
                if dist <= ServerAuras_Config.AuraRadius and dist > 1 then
                    tRoot.AssemblyLinearVelocity = (myRoot.Position - tRoot.Position).Unit * ServerAuras_Config.AuraPower
                end
            end
        end
    end
end

local function applyFlingAura()
    local myRoot = getRoot()
    if not myRoot or isRagdolled() then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not isSafeTarget(plr) then
            local tRoot = getTargetRoot(plr)
            if tRoot then
                local dist = (myRoot.Position - tRoot.Position).Magnitude
                if dist <= ServerAuras_Config.AuraRadius and dist > 1 then
                    tRoot.AssemblyLinearVelocity = (tRoot.Position - myRoot.Position).Unit * ServerAuras_Config.AuraPower + Vector3.new(0, 80, 0)
                    fireRemote("CharacterEvents", "RagdollRemote")
                    fireRemote("PlayerEvents", "RagdollPlayer")
                end
            end
        end
    end
end

local function applyKickAura()
    local myRoot = getRoot()
    if not myRoot or isRagdolled() then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not isSafeTarget(plr) then
            local tRoot = getTargetRoot(plr)
            if tRoot and (myRoot.Position - tRoot.Position).Magnitude <= ServerAuras_Config.AuraRadius then
                tRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                fireRemote("CharacterEvents", "RagdollRemote")
                fireRemote("PlayerEvents", "RagdollPlayer")
            end
        end
    end
end

local function applyVoidAura()
    local myRoot = getRoot()
    if not myRoot then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not isSafeTarget(plr) then
            local tRoot = getTargetRoot(plr)
            if tRoot and (myRoot.Position - tRoot.Position).Magnitude <= ServerAuras_Config.AuraRadius then
                tRoot.CFrame = CFrame.new(0, -250, 0)
                tRoot.AssemblyLinearVelocity = Vector3.new(0, -300, 0)
                fireRemote("GameCorrectionEvents", "TeleportToGround")
            end
        end
    end
end

local function applyFollowAura()
    local myRoot = getRoot()
    if not myRoot or isRagdolled() then return end
    local followPos = myRoot.CFrame * CFrame.new(0, 0, -10)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not isSafeTarget(plr) then
            local tRoot = getTargetRoot(plr)
            if tRoot then
                local dist = (followPos.Position - tRoot.Position).Magnitude
                if dist <= ServerAuras_Config.AuraRadius and dist > 1 then
                    tRoot.AssemblyLinearVelocity = (followPos.Position - tRoot.Position).Unit * ServerAuras_Config.AuraPower
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
    pcall(function()
        local method = ServerAuras_Config.ExplosionMethod

        -- Non-explosion variants operate directly on players
        if method == "Void" then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    local tRoot = getTargetRoot(plr)
                    if tRoot and (pos - tRoot.Position).Magnitude <= ServerAuras_Config.ExplosionRadius then
                        tRoot.CFrame = CFrame.new(0, -250, 0)
                        tRoot.AssemblyLinearVelocity = Vector3.new(0, -300, 0)
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
                    if tRoot and (pos - tRoot.Position).Magnitude <= ServerAuras_Config.ExplosionRadius then
                        tRoot.AssemblyLinearVelocity = tRoot.AssemblyLinearVelocity + Vector3.new(0, 150, 0)
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
    if not myRoot then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local tRoot = getTargetRoot(plr)
            if tRoot and (myRoot.Position - tRoot.Position).Magnitude <= ServerAuras_Config.MassRadius then
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
    if not myRoot then return end
    local now = os.clock()
    if now - objectAuraLastScan < 0.5 then return end
    objectAuraLastScan = now
    table.clear(objectAuraParts)
    local char = LocalPlayer.Character
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("BasePart") and inst.Anchored == false then
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
    if not myRoot or isRagdolled() then return end
    scanObjectAuraParts()
    local speed = ServerAuras_Config.ObjectAuraSpeed
    local mode = ServerAuras_Config.ObjectAuraMode
    for part in pairs(objectAuraParts) do
        if part and part.Parent then
            pcall(function()
                local diff = part.Position - myRoot.Position
                local dist = math.max(diff.Magnitude, 1)
                if mode == "Object Tornado" then
                    local up = Vector3.new(0, 1, 0)
                    local tangent = diff.Unit:Cross(up)
                    if tangent.Magnitude < 0.01 then tangent = Vector3.new(1, 0, 0) end
                    part.AssemblyLinearVelocity = tangent.Unit * speed + Vector3.new(0, speed * 0.4, 0)
                elseif mode == "Object Aura" then
                    part.AssemblyLinearVelocity = (myRoot.Position - part.Position).Unit * speed
                elseif mode == "Object Float" then
                    part.AssemblyLinearVelocity = Vector3.new(part.AssemblyLinearVelocity.X, speed, part.AssemblyLinearVelocity.Z)
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
