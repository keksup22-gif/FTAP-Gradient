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
        part:SetNetworkOwner(LocalPlayer)
        part.AssemblyLinearVelocity = velocity
    end)
    return true
end

local function safeSetAngularVelocity(part, velocity)
    if not isBasePart(part) then return false end
    if typeof(velocity) ~= "Vector3" then return false end
    if part.Anchored then return false end
    pcall(function()
        part:SetNetworkOwner(LocalPlayer)
        part.AssemblyAngularVelocity = velocity
    end)
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

