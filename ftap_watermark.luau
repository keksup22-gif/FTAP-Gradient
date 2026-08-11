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