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
