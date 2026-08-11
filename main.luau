--[[
    ================================================================
    Gradient Hub - Main Loader (single window architecture)
    One Fluent window is created here and shared by all modules
    via _G.GradientWindow / _G.GradientFluent.
    File: main.luau
    ================================================================
--]]

print("[Gradient Hub] ЗАПУЩЕНА НОВАЯ ВЕРСИЯ С ФИКСАМИ! " .. os.time())
print("[Gradient] Loader started!")

-- Prior-run cleanup: purge old state + script-created objects before reload
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

-- 1. Disconnect prior registered connections (saved in _G by each module)
if type(_G.GradientConnections) == "table" then
    for _, conn in ipairs(_G.GradientConnections) do
        pcall(function()
            if conn and conn.Connected then conn:Disconnect() end
        end)
    end
end
_G.GradientConnections = {}

-- 2. Remove previously created script objects (Highlights, Decals, platforms, auras)
pcall(function()
    for _, inst in ipairs(Workspace:GetDescendants()) do
        local n = inst.Name or ""
        if string.find(n, "PCLD_Highlight") or string.find(n, "FTAP_ObjectESP")
           or string.find(n, "FTAP_Label_") or string.find(n, "FTAP_WaterPlatform")
           or string.find(n, "PlayerChams") or inst:GetAttribute("FTAP_Script") then
            inst:Destroy()
        end
    end
end)

-- 3. Clean post-processing effects from older shader presets
pcall(function()
    for _, child in ipairs(Lighting:GetChildren()) do
        local cname = child.Name or ""
        if string.find(cname, "FTAP_Shader") or string.find(cname, "FTAP_CustomSky") then
            child:Destroy()
        end
    end
end)

-- Load Fluent UI once
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

-- Single shared window
local Window = Fluent:CreateWindow({
    Title = "Gradient Hub | FTAP",
    SubTitle = "by keksup22",
    Size = UDim2.fromOffset(880, 540),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

_G.GradientFluent = Fluent
_G.GradientWindow = Window
_G.GradientWindows = _G.GradientWindows or {}
table.insert(_G.GradientWindows, Window)

-- Shared 8-tab layout (horizontal, top bar): every module maps its
-- own controls onto these keys. Each tab has a lucide icon.
_G.GradientTabs = {
    Protections = Window:AddTab({ Title = "Protections", Icon = "shield" }),
    Movement = Window:AddTab({ Title = "Movement", Icon = "person-standing" }),
    Combat = Window:AddTab({ Title = "Combat", Icon = "swords" }),
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "sparkles" }),
    Server = Window:AddTab({ Title = "Server", Icon = "server" }),
    Misc = Window:AddTab({ Title = "Misc", Icon = "wrench" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
    Info = Window:AddTab({ Title = "Info", Icon = "info" })
}

local BaseUrl = "https://raw.githubusercontent.com/keksup22-gif/FTAP-Gradient/main/"

local Modules = {
    "ftap_layout.luau",
    "ftap_uisettings.luau",
    "ftap_mercury_visuals.luau",
    "ftap_modules.luau",
    "ftap_target.luau",
    "ftap_grabs.luau",
    "ftap_server.luau",
    "ftap_server_auras.luau",
    "ftap_misc.luau",
    "ftap_watermark.luau",
    "ftap_info.luau"
}

for _, file in ipairs(Modules) do
    print("[Gradient] Loading " .. file)
    pcall(function()
        local code = game:HttpGet(BaseUrl .. file .. "?v=" .. tick(), true)
        if code and code ~= "" then
            loadstring(code)()
            print("[Gradient] OK: " .. file)
        else
            warn("[Gradient] Failed to download: " .. file)
        end
    end)
    task.wait(0.1)
end

print("[Gradient] Finished loading all modules!")

-- Auto-select the first tab once every module finished adding tabs,
-- so the horizontal interface opens ready to use.
task.delay(0.2, function()
    pcall(function()
        if _G.GradientLayout and _G.GradientLayout.selectScreen then
            _G.GradientLayout.selectScreen(1)
        end
    end)
end)