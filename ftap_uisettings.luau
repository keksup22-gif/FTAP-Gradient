--[[
    ================================================================
    Gradient Hub UI Settings Module - Appearance / Theme / Config
    Target Game: Fling Things and People (FTAP)
    UI Library: Fluent UI
    File: ftap_uisettings.luau
    ================================================================
--]]

-- Services Initialization
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

-- Global Safe File IO Wrappers
local writefile = writefile or function() end
local readfile = readfile or function() return "" end
local isfile = isfile or function() return false end
local makefolder = makefolder or function() end
local isfolder = isfolder or function() return false end
local listfiles = listfiles or function() return {} end
local delfile = delfile or function() end

-- Shared global state for UI Settings (consumed by init.luau + other modules)
local UIState = {
    Window = nil,
    Tabs = {},
    References = {} -- hold Fluent control refs so manager buttons can update them
}
_G.GradientUIState = UIState

-- Folders
if not isfolder("GradientFTAP") then pcall(makefolder, "GradientFTAP") end
if not isfolder("GradientFTAP/Themes") then pcall(makefolder, "GradientFTAP/Themes") end
if not isfolder("GradientFTAP/Configs") then pcall(makefolder, "GradientFTAP/Configs") end

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
UIState.Window = Window

local Tabs = {
    Appearance = _G.GradientTabs and _G.GradientTabs.Misc or Window:AddTab({ Title = "Misc & Settings", Icon = "palette" }),
    Keybinds = _G.GradientTabs and _G.GradientTabs.Misc or Window:AddTab({ Title = "Misc & Settings", Icon = "key" }),
    ThemeColors = _G.GradientTabs and _G.GradientTabs.Misc or Window:AddTab({ Title = "Misc & Settings", Icon = "droplet" }),
    ThemeManager = _G.GradientTabs and _G.GradientTabs.Misc or Window:AddTab({ Title = "Misc & Settings", Icon = "save" }),
    ConfigManager = _G.GradientTabs and _G.GradientTabs.Misc or Window:AddTab({ Title = "Misc & Settings", Icon = "folder" })
}
UIState.Tabs = Tabs


-- ================================================================
-- UI APPEARANCE CONFIG
-- ================================================================

local UISettings_Config = {
    Font = "Cartoon",
    ImageTransparency = 25,
    BackgroundTransparency = 10,
    HUDTransparency = 10,
    BackgroundID = "rbxassetid://0",
    CornerRadius = 25,
    UIScale = 1,

    Theme = {
        MainColor = Color3.fromRGB(30, 30, 46),
        SecondColor = Color3.fromRGB(56, 56, 84),
        ElementColor = Color3.fromRGB(66, 66, 104),
        TextColor = Color3.fromRGB(240, 240, 245),
        GradientStart = Color3.fromRGB(25, 25, 40),
        GradientEnd = Color3.fromRGB(56, 56, 84)
    },

    ToggleKey = "RightShift",
    LoadedConfig = "",
    AutoSave = false
}

-- Share theme with the rest of the suite
_G.GradientTheme = UISettings_Config.Theme
_G.GradientAppearance = UISettings_Config

local FontOptions = {
    ["Cartoon"] = Enum.Font.Cartoon,
    ["Gotham"] = Enum.Font.Gotham,
    ["GothamBlack"] = Enum.Font.GothamBlack,
    ["GothamSemibold"] = Enum.Font.GothamSemibold,
    ["SourceSans"] = Enum.Font.SourceSans,
    ["Roboto"] = Enum.Font.Roboto,
    ["Code"] = Enum.Font.Code,
    ["Highway"] = Enum.Font.Highway,
    ["Legacy"] = Enum.Font.Legacy
}

-- Apply global font to all open Gradient windows
local function applyGlobalFont(fontName)
    local fontEnum = FontOptions[fontName] or Enum.Font.SourceSans
    _G.GradientFont = fontEnum
    -- Propagate to every registered UI window
    for _, win in ipairs(_G.GradientWindows or {}) do
        if win and win.Element then
            pcall(function()
                local f = win.Element
                for _, desc in ipairs(f:GetDescendants()) do
                    if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                        desc.FontFace = Font.new(fontEnum.Name)
                    end
                end
            end)
        end
    end
end

-- Apply theme colors to all open Gradient windows
local function applyGlobalTheme(theme)
    _G.GradientTheme = theme
    _G.GradientWindowTheme = theme -- generic override for modules
    for _, win in ipairs(_G.GradientWindows or {}) do
        if win and win.Element then
            pcall(function()
                -- Background / accent accent propagation for Fluent
                local accent = theme.MainColor
                local bg = theme.SecondColor
                local elem = theme.ElementColor
                local f = win.Element
                for _, desc in ipairs(f:GetDescendants()) do
                    if desc:IsA("Frame") or desc:IsA("ScrollingFrame") then
                        if desc.Name == "BG" or desc.BackgroundTransparency < 1 then
                            pcall(function() desc.BackgroundColor3 = bg end)
                        end
                    end
                end
                for _, desc in ipairs(f:GetDescendants()) do
                    if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                        pcall(function() desc.TextColor3 = theme.TextColor end)
                    end
                end
            end)
        end
    end
end

-- Apply scale to all windows
local function applyGlobalScale(scale)
    _G.GradientScale = scale
    for _, win in ipairs(_G.GradientWindows or {}) do
        if win and win.Element then
            pcall(function() win.Element.Size = UDim2.fromOffset(580 * scale, 480 * scale) end)
        end
    end
end

-- Corner radius + frame transparent style base
local function refreshAppearanceStyle()
    local bgID = UISettings_Config.BackgroundID
    _G.GradientBackgroundID = bgID
    _G.GradientCornerRadius = UISettings_Config.CornerRadius
    _G.GradientTransparency = UISettings_Config.BackgroundTransparency / 100
end


-- ================================================================
-- THEME MANAGER (Save / Load / Delete)
-- ================================================================

local SavedThemes = {}

local function refreshThemeList()
    table.clear(SavedThemes)
    local files = listfiles("GradientFTAP/Themes")
    local names = {}
    for _, filePath in ipairs(files) do
        local filename = string.match(filePath, "([^/]+)%.json$")
        if filename then
            table.insert(names, filename)
            SavedThemes[filename] = filePath
        end
    end
    if #names == 0 then table.insert(names, "None") end
    return names
end

local function themeData()
    return {
        MainColor = { R = UISettings_Config.Theme.MainColor.R, G = UISettings_Config.Theme.MainColor.G, B = UISettings_Config.Theme.MainColor.B },
        SecondColor = { R = UISettings_Config.Theme.SecondColor.R, G = UISettings_Config.Theme.SecondColor.G, B = UISettings_Config.Theme.SecondColor.B },
        ElementColor = { R = UISettings_Config.Theme.ElementColor.R, G = UISettings_Config.Theme.ElementColor.G, B = UISettings_Config.Theme.ElementColor.B },
        TextColor = { R = UISettings_Config.Theme.TextColor.R, G = UISettings_Config.Theme.TextColor.G, B = UISettings_Config.Theme.TextColor.B },
        GradientStart = { R = UISettings_Config.Theme.GradientStart.R, G = UISettings_Config.Theme.GradientStart.G, B = UISettings_Config.Theme.GradientStart.B },
        GradientEnd = { R = UISettings_Config.Theme.GradientEnd.R, G = UISettings_Config.Theme.GradientEnd.G, B = UISettings_Config.Theme.GradientEnd.B },
        Font = UISettings_Config.Font
    }
end

local function loadTheme(raw)
    local data = HttpService:JSONDecode(raw)
    if not data then return false end

    UISettings_Config.Theme.MainColor = Color3.new(data.MainColor.R, data.MainColor.G, data.MainColor.B)
    UISettings_Config.Theme.SecondColor = Color3.new(data.SecondColor.R, data.SecondColor.G, data.SecondColor.B)
    UISettings_Config.Theme.ElementColor = Color3.new(data.ElementColor.R, data.ElementColor.G, data.ElementColor.B)
    UISettings_Config.Theme.TextColor = Color3.new(data.TextColor.R, data.TextColor.G, data.TextColor.B)
    UISettings_Config.Theme.GradientStart = Color3.new(data.GradientStart.R, data.GradientStart.G, data.GradientStart.B)
    UISettings_Config.Theme.GradientEnd = Color3.new(data.GradientEnd.R, data.GradientEnd.G, data.GradientEnd.B)

    _G.GradientTheme = UISettings_Config.Theme
    applyGlobalTheme(UISettings_Config.Theme)

    if data.Font and FontOptions[data.Font] then
        UISettings_Config.Font = data.Font
        FontDropdown:SetValue(UISettings_Config.Font)
        applyGlobalFont(UISettings_Config.Font)
    end
    return true
end


-- ================================================================
-- CONFIG MANAGER (Save / Load / Delete full UI config)
-- ================================================================

local SavedConfigs = {}

local function refreshConfigList()
    table.clear(SavedConfigs)
    local files = listfiles("GradientFTAP/Configs")
    local names = {}
    for _, filePath in ipairs(files) do
        local filename = string.match(filePath, "([^/]+)%.json$")
        if filename then
            table.insert(names, filename)
            SavedConfigs[filename] = filePath
        end
    end
    if #names == 0 then table.insert(names, "None") end
    return names
end

local function configData()
    return {
        Font = UISettings_Config.Font,
        ImageTransparency = UISettings_Config.ImageTransparency,
        BackgroundTransparency = UISettings_Config.BackgroundTransparency,
        HUDTransparency = UISettings_Config.HUDTransparency,
        BackgroundID = UISettings_Config.BackgroundID,
        CornerRadius = UISettings_Config.CornerRadius,
        UIScale = UISettings_Config.UIScale,
        Theme = themeData(),
        ToggleKey = UISettings_Config.ToggleKey
    }
end

local function loadConfig(raw)
    local data = HttpService:JSONDecode(raw)
    if not data then return false end

    UISettings_Config.Font = data.Font or "Cartoon"
    UISettings_Config.ImageTransparency = data.ImageTransparency or 25
    UISettings_Config.BackgroundTransparency = data.BackgroundTransparency or 10
    UISettings_Config.HUDTransparency = data.HUDTransparency or 10
    UISettings_Config.BackgroundID = data.BackgroundID or "rbxassetid://0"
    UISettings_Config.CornerRadius = data.CornerRadius or 25
    UISettings_Config.UIScale = data.UIScale or 1
    UISettings_Config.ToggleKey = data.ToggleKey or "RightShift"

    local t = data.Theme or {}
    UISettings_Config.Theme.MainColor = Color3.new(t.MainColor.R, t.MainColor.G, t.MainColor.B)
    UISettings_Config.Theme.SecondColor = Color3.new(t.SecondColor.R, t.SecondColor.G, t.SecondColor.B)
    UISettings_Config.Theme.ElementColor = Color3.new(t.ElementColor.R, t.ElementColor.G, t.ElementColor.B)
    UISettings_Config.Theme.TextColor = Color3.new(t.TextColor.R, t.TextColor.G, t.TextColor.B)
    UISettings_Config.Theme.GradientStart = Color3.new(t.GradientStart.R, t.GradientStart.G, t.GradientStart.B)
    UISettings_Config.Theme.GradientEnd = Color3.new(t.GradientEnd.R, t.GradientEnd.G, t.GradientEnd.B)

    -- Sync UI controls
    if FontDropdown then FontDropdown:SetValue(UISettings_Config.Font) end
    if ImageTransSlider then ImageTransSlider:SetValue(UISettings_Config.ImageTransparency) end
    if BackgroundTransSlider then BackgroundTransSlider:SetValue(UISettings_Config.BackgroundTransparency) end
    if HUDTransSlider then HUDTransSlider:SetValue(UISettings_Config.HUDTransparency) end
    if BackgroundIDInput then BackgroundIDInput:SetValue(UISettings_Config.BackgroundID) end
    if CornerRadiusSlider then CornerRadiusSlider:SetValue(UISettings_Config.CornerRadius) end
    if UIScaleSlider then UIScaleSlider:SetValue(UISettings_Config.UIScale) end

    refreshAppearanceStyle()
    applyGlobalFont(UISettings_Config.Font)
    applyGlobalTheme(UISettings_Config.Theme)
    applyGlobalScale(UISettings_Config.UIScale)
    return true
end


-- ================================================================
-- APPEARANCE UI
-- ================================================================

Tabs.Appearance:AddSection("Appearance")

local FontDropdown = Tabs.Appearance:AddDropdown("UIFontDropdown", {
    Title = "Font",
    Values = {"Cartoon", "Gotham", "GothamBlack", "GothamSemibold", "SourceSans", "Roboto", "Code", "Highway", "Legacy"},
    Default = "Cartoon",
    Callback = function(Value)
        UISettings_Config.Font = Value
        applyGlobalFont(Value)
    end
})

local ImageTransSlider = Tabs.Appearance:AddSlider("ImageTransparencySlider", {
    Title = "Image Transparency",
    Default = 25,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Callback = function(Value)
        UISettings_Config.ImageTransparency = Value
        _G.GradientImageTransparency = Value / 100
    end
})

local BackgroundTransSlider = Tabs.Appearance:AddSlider("BgTransparencySlider", {
    Title = "Background Transparency",
    Default = 10,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Callback = function(Value)
        UISettings_Config.BackgroundTransparency = Value
        _G.GradientTransparency = Value / 100
        for _, win in ipairs(_G.GradientWindows or {}) do
            if win and win.Element then
                pcall(function()
                    for _, desc in ipairs(win.Element:GetDescendants()) do
                        if desc:IsA("Frame") then
                            pcall(function() desc.BackgroundTransparency = Value / 100 end)
                        end
                    end
                end)
            end
        end
    end
})

local HUDTransSlider = Tabs.Appearance:AddSlider("HUDTransparencySlider", {
    Title = "HUD Transparency",
    Default = 10,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Callback = function(Value)
        UISettings_Config.HUDTransparency = Value
        _G.GradientHUDTransparency = Value / 100
    end
})

local BackgroundIDInput = Tabs.Appearance:AddInput("BackgroundIDInput", {
    Title = "Background ID",
    Default = "rbxassetid://0",
    Placeholder = "rbxassetid://0",
    Callback = function(Value)
        UISettings_Config.BackgroundID = Value
        _G.GradientBackgroundID = Value
    end
})

local CornerRadiusSlider = Tabs.Appearance:AddSlider("CornerRadiusSlider", {
    Title = "Corner Radius",
    Default = 25,
    Min = 0,
    Max = 60,
    Rounding = 0,
    Callback = function(Value)
        UISettings_Config.CornerRadius = Value
        _G.GradientCornerRadius = Value
        for _, win in ipairs(_G.GradientWindows or {}) do
            if win and win.Element then
                pcall(function()
                    for _, desc in ipairs(win.Element:GetDescendants()) do
                        if desc:IsA("UICorner") then
                            pcall(function() desc.CornerRadius = UDim.new(0, Value) end)
                        end
                    end
                end)
            end
        end
    end
})

local UIScaleSlider = Tabs.Appearance:AddSlider("UIScaleSlider", {
    Title = "UI Scale",
    Default = 1,
    Min = 0.5,
    Max = 2,
    Rounding = 2,
    Callback = function(Value)
        UISettings_Config.UIScale = Value
        applyGlobalScale(Value)
    end
})

-- Store slider refs for config load sync
UIState.References.FontDropdown = FontDropdown
UIState.References.ImageTransSlider = ImageTransSlider
UIState.References.BackgroundTransSlider = BackgroundTransSlider
UIState.References.HUDTransSlider = HUDTransSlider
UIState.References.BackgroundIDInput = BackgroundIDInput
UIState.References.CornerRadiusSlider = CornerRadiusSlider
UIState.References.UIScaleSlider = UIScaleSlider


-- ================================================================
-- KEYBINDS UI
-- ================================================================

Tabs.Keybinds:AddSection("Keybinds")

local MenuToggleKey = Tabs.Keybinds:AddKeybind("UISettingsToggleKey", {
    Title = "Toggle UI",
    Mode = "Toggle",
    Default = "RightShift",
    Callback = function()
        UIState.Window:Minimize()
    end
})


-- ================================================================
-- THEME COLORS UI
-- ================================================================

Tabs.ThemeColors:AddSection("Theme Colors")

local MainColorPicker = Tabs.ThemeColors:AddColorpicker("MainColorPicker", {
    Title = "Main Color",
    Default = UISettings_Config.Theme.MainColor,
    Callback = function(Value)
        UISettings_Config.Theme.MainColor = Value
        applyGlobalTheme(UISettings_Config.Theme)
    end
})

local SecondColorPicker = Tabs.ThemeColors:AddColorpicker("SecondColorPicker", {
    Title = "Second Color",
    Default = UISettings_Config.Theme.SecondColor,
    Callback = function(Value)
        UISettings_Config.Theme.SecondColor = Value
        applyGlobalTheme(UISettings_Config.Theme)
    end
})

local ElementColorPicker = Tabs.ThemeColors:AddColorpicker("ElementColorPicker", {
    Title = "Element Color",
    Default = UISettings_Config.Theme.ElementColor,
    Callback = function(Value)
        UISettings_Config.Theme.ElementColor = Value
        applyGlobalTheme(UISettings_Config.Theme)
    end
})

local TextColorPicker = Tabs.ThemeColors:AddColorpicker("TextColorPicker", {
    Title = "Text Color",
    Default = UISettings_Config.Theme.TextColor,
    Callback = function(Value)
        UISettings_Config.Theme.TextColor = Value
        applyGlobalTheme(UISettings_Config.Theme)
    end
})

local GradientStartPicker = Tabs.ThemeColors:AddColorpicker("GradientStartPicker", {
    Title = "Gradient Start",
    Default = UISettings_Config.Theme.GradientStart,
    Callback = function(Value)
        UISettings_Config.Theme.GradientStart = Value
        applyGlobalTheme(UISettings_Config.Theme)
    end
})

local GradientEndPicker = Tabs.ThemeColors:AddColorpicker("GradientEndPicker", {
    Title = "Gradient End",
    Default = UISettings_Config.Theme.GradientEnd,
    Callback = function(Value)
        UISettings_Config.Theme.GradientEnd = Value
        applyGlobalTheme(UISettings_Config.Theme)
    end
})


-- ================================================================
-- THEME MANAGER UI
-- ================================================================

Tabs.ThemeManager:AddSection("Theme Manager")

local ThemeNameInput = Tabs.ThemeManager:AddInput("ThemeNameInput", {
    Title = "Theme Name",
    Default = "MyTheme",
    Callback = function(Value) _G.GradientNewThemeName = Value end
})

Tabs.ThemeManager:AddButton({
    Title = "Save Theme",
    Callback = function()
        local name = _G.GradientNewThemeName or "MyTheme"
        local path = "GradientFTAP/Themes/" .. name .. ".json"
        local data = HttpService:JSONEncode(themeData())
        writefile(path, data)
        ThemeLoadDropdown:SetValues(refreshThemeList())
        Fluent:Notify({ Title = "Theme", Content = "Theme '" .. name .. "' saved!", Duration = 3 })
    end
})

local ThemeLoadDropdown = Tabs.ThemeManager:AddDropdown("ThemeLoadDropdown", {
    Title = "Load Theme",
    Values = refreshThemeList(),
    Default = "None",
    Callback = function(Value)
        if Value == "None" then return end
        local path = SavedThemes[Value]
        if path and isfile(path) then
            pcall(function()
                if loadTheme(readfile(path)) then
                    Fluent:Notify({ Title = "Theme", Content = "Theme '" .. Value .. "' loaded!", Duration = 3 })
                end
            end)
        end
    end
})

Tabs.ThemeManager:AddButton({
    Title = "Delete Selected Theme",
    Callback = function()
        local selected = ThemeLoadDropdown.Value
        if selected == "None" then
            Fluent:Notify({ Title = "Theme", Content = "No theme selected.", Duration = 2 })
            return
        end
        local path = SavedThemes[selected]
        if path and isfile(path) then
            delfile(path)
            ThemeLoadDropdown:SetValues(refreshThemeList())
            Fluent:Notify({ Title = "Theme", Content = "Theme '" .. selected .. "' deleted!", Duration = 2 })
        end
    end
})


-- ================================================================
-- CONFIG MANAGER UI
-- ================================================================

Tabs.ConfigManager:AddSection("Config Manager")

local ConfigNameInput = Tabs.ConfigManager:AddInput("ConfigNameInput", {
    Title = "Config Name",
    Default = "MyConfig",
    Callback = function(Value) _G.GradientNewConfigName = Value end
})

local function saveConfigToFile(name)
    local path = "GradientFTAP/Configs/" .. name .. ".json"
    local data = HttpService:JSONEncode(configData())
    writefile(path, data)
    if ConfigLoadDropdown then
        ConfigLoadDropdown:SetValues(refreshConfigList())
    end
end

Tabs.ConfigManager:AddButton({
    Title = "Save Config",
    Callback = function()
        local name = _G.GradientNewConfigName or "MyConfig"
        saveConfigToFile(name)
        Fluent:Notify({ Title = "Config", Content = "Config '" .. name .. "' saved!", Duration = 3 })
    end
})

local ConfigLoadDropdown = Tabs.ConfigManager:AddDropdown("ConfigLoadDropdown", {
    Title = "Load Config",
    Values = refreshConfigList(),
    Default = "None",
    Callback = function(Value)
        if Value == "None" then return end
        local path = SavedConfigs[Value]
        if path and isfile(path) then
            pcall(function()
                if loadConfig(readfile(path)) then
                    UISettings_Config.LoadedConfig = Value
                    Fluent:Notify({ Title = "Config", Content = "Config '" .. Value .. "' loaded!", Duration = 3 })
                end
            end)
        end
    end
})

Tabs.ConfigManager:AddButton({
    Title = "Delete Selected Config",
    Callback = function()
        local selected = ConfigLoadDropdown.Value
        if selected == "None" then
            Fluent:Notify({ Title = "Config", Content = "No config selected.", Duration = 2 })
            return
        end
        local path = SavedConfigs[selected]
        if path and isfile(path) then
            delfile(path)
            ConfigLoadDropdown:SetValues(refreshConfigList())
            Fluent:Notify({ Title = "Config", Content = "Config '" .. selected .. "' deleted!", Duration = 2 })
        end
    end
})

local AutoSaveToggle = Tabs.ConfigManager:AddToggle("AutoSaveToggle", { Title = "Auto Save Config", Default = false })
AutoSaveToggle:OnChanged(function(Value) UISettings_Config.AutoSave = Value end)

-- Auto-Save watcher: when enabled, persists the config to the last saved /
-- default filename whenever the appearance data actually changes (polled).
task.spawn(function()
    local lastSaved = ""
    local lastPoll = 0
    while true do
        task.wait(1)
        if UISettings_Config.AutoSave then
            local now = os.clock()
            if now - lastPoll < 2 then continue end
            lastPoll = now
            local current = HttpService:JSONEncode(configData())
            if current ~= lastSaved then
                lastSaved = current
                local name = UISettings_Config.LoadedConfig ~= ""
                    and UISettings_Config.LoadedConfig
                    or (_G.GradientNewConfigName or "MyConfig")
                pcall(saveConfigToFile, name)
            end
        end
    end
end)

-- Register window with the global suite registry (idempotent for shared window)
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

-- Expose a callable for init.luau to auto-apply a saved raw config
UIState.applySaved = function(raw)
    pcall(function()
        if raw and loadConfig(raw) then
            Fluent:Notify({ Title = "Gradient UI", Content = "Saved UI config applied automatically!", Duration = 3 })
        end
    end)
end

Window:SelectTab(1)

Fluent:Notify({
    Title = "Gradient Hub UI Settings",
    Content = "UI Settings module loaded successfully!",
    Duration = 5
})

print("[Gradient Hub] UI Settings module loaded successfully.")