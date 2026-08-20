--[[
    ================================================================
    Gradient Hub - Main Loader (single window architecture)
    One Fluent window is created here and shared by all modules
    via _G.GradientWindow / _G.GradientFluent.

    The ENTIRE initialization (Fluent load -> window -> tabs ->
    module loading) runs inside a single outer pcall. There is
    NO unprotected nil-call anywhere at the top level, so even a
    fully-broken environment prints a readable diagnostic instead
    of crashing with "attempt to call a nil value".
    File: main.luau
    ================================================================
--]]

local GradientInitStatus, GradientInitErr = pcall(function()

    print("[Gradient Hub] НОВАЯ ВЕРСИЯ С ПОЛНОЙ ЗАЩИТОЙ ИНИЦИАЛИЗАЦИИ! " .. os.time())
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

    -- ================================================================
    -- 1) Load Fluent UI
    --    Guarded: a rate-limit / network hiccup can make HttpGet return
    --    an HTML error page, loadstring then returns nil, and calling
    --    nil() would throw. Here every step is type-checked instead.
    -- ================================================================
    local Fluent = nil
    if _G.GradientFluent and type(_G.GradientFluent.CreateWindow) == "function" then
        Fluent = _G.GradientFluent
        print("[Gradient] Reusing existing Fluent (rerun/standalone).")
    else
        local sources = {
            "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua",
            "https://raw.githubusercontent.com/disco0001/Fluent/main/main.lua",
        }
        for _, url in ipairs(sources) do
            local ok, lib = pcall(function()
                local src = game:HttpGet(url)
                if type(src) == "string" and #src > 100 then
                    local fn = loadstring(src)
                    if type(fn) == "function" then
                        return fn()
                    end
                end
            end)
            if ok and type(lib) == "table" and type(lib.CreateWindow) == "function" then
                Fluent = lib
                break
            end
            print("[Gradient] Fluent source failed: " .. tostring(url))
        end
    end
    if type(Fluent) ~= "table" or type(Fluent.CreateWindow) ~= "function" then
        print("[Gradient] CRITICAL: Fluent is EMPTY (nil) - network blocked or source changed.")
        return
    end
    _G.GradientFluent = Fluent

    -- ================================================================
    -- 2) Create the single shared window (guarded CreateWindow)
    -- ================================================================
    local Window = nil
    if _G.GradientWindow and type(_G.GradientWindow.AddTab) == "function" then
        Window = _G.GradientWindow
        print("[Gradient] Reusing existing window (rerun/standalone).")
    else
        local okW, win = pcall(Fluent.CreateWindow, Fluent, {
            Title = "Gradient Hub | FTAP",
            SubTitle = "by keksup22",
            Size = UDim2.fromOffset(640, 540),
            TabWidth = 160,
            Acrylic = false,
            Theme = "Dark",
            MinimizeKey = Enum.KeyCode.LeftControl
        })
        Window = (okW and type(win) == "table" and type(win.AddTab) == "function") and win or nil
        if not Window then
            print("[Gradient] CRITICAL: Window is EMPTY (nil) - CreateWindow returned nil/errored.")
            return
        end
    end
    _G.GradientWindow = Window
    _G.GradientWindows = _G.GradientWindows or {}
    table.insert(_G.GradientWindows, Window)

    -- ================================================================
    -- 3) Build the shared 8-tab layout. Each tab is added in its own
    --    pcall so one broken icon name / tab error NEVER aborts the
    --    creation of the remaining tabs. If the attempt with Icon
    --    fails, we retry without Icon as a safe fallback.
    -- ================================================================
    local tabSpecs = {
        { key = "Protections", title = "Protections", icon = "shield" },
        { key = "Movement", title = "Local Player & Protection", icon = "person-standing" },
        { key = "Combat", title = "Combat & Grabs", icon = "swords" },
        { key = "Visuals", title = "Visuals", icon = "eye" },
        { key = "Server", title = "Server & Auras", icon = "server" },
        { key = "Misc", title = "Misc & Settings", icon = "wrench" },
        { key = "Settings", title = "Settings", icon = "settings" },
        { key = "Info", title = "Info", icon = "info" }
    }
    local Tabs = {}
    local tabCount = 0

    for _, spec in ipairs(tabSpecs) do
        local tab = nil
        -- Pre-check icon via Fluent.GetIcon if available
        local safeIcon = spec.icon
        if type(Fluent.GetIcon) == "function" then
            local okIcon, asset = pcall(Fluent.GetIcon, Fluent, spec.icon)
            if not (okIcon and type(asset) == "string") then
                warn("[Tab Error]: GetIcon('" .. tostring(spec.icon) .. "') failed for tab '" .. spec.title .. "' (" .. tostring(asset) .. ") - creating without icon.")
                safeIcon = nil
            end
        end

        -- Attempt 1: with safeIcon (if validated)
        local ok1, t1 = pcall(Window.AddTab, Window, { Title = spec.title, Icon = safeIcon })
        if ok1 and type(t1) == "table" then
            tab = t1
            print("[Gradient] Tab '" .. spec.title .. "' created OK.")
        else
            warn("[Tab Error]: AddTab #1 failed for '" .. spec.title .. "': " .. tostring(t1))
            -- Attempt 2: retry strictly without Icon
            local ok2, t2 = pcall(Window.AddTab, Window, { Title = spec.title })
            if ok2 and type(t2) == "table" then
                tab = t2
                print("[Gradient] Tab '" .. spec.title .. "' added without icon (fallback).")
            else
                warn("[Tab Error]: AddTab #2 failed for '" .. spec.title .. "': " .. tostring(t2))
            end
        end

        if tab then
            Tabs[spec.key] = tab
            tabCount = tabCount + 1
        end
        -- Give Fluent one tick between creations so the tab bar layout
        -- settles before the next AddTab (prevents mid-chain breakage).
        task.wait(0.05)
    end

    -- ================================================================
    -- Verification + retry pass: if any tab is still missing, re-scan
    -- the TabHolder and retry creation of every missing spec.
    -- ================================================================
    local function countTabButtons(holder)
        local n = 0
        for _, child in ipairs(holder:GetChildren()) do
            if child:IsA("TextButton") then
                n = n + 1
            end
        end
        return n
    end

    local holderRef = Window.TabHolder
    local existingButtons = (holderRef and countTabButtons(holderRef)) or 0
    print("[Gradient] TabHolder buttons after first pass: " .. tostring(existingButtons) .. " / " .. tostring(#tabSpecs))

    for _, spec in ipairs(tabSpecs) do
        if not Tabs[spec.key] and holderRef then
            task.wait(0.1)
            local okR, tR = pcall(Window.AddTab, Window, { Title = spec.title })
            if okR and type(tR) == "table" then
                Tabs[spec.key] = tR
                tabCount = tabCount + 1
                print("[Gradient] Retry pass: tab '" .. spec.title .. "' created.")
            else
                warn("[Tab Error]: Retry pass failed for '" .. spec.title .. "': " .. tostring(tR))
            end
        end
    end

    _G.GradientTabs = Tabs
    print("[Gradient] Total tabs successfully added: " .. tostring(tabCount) .. " / " .. tostring(#tabSpecs))

    if not Tabs.Protections then
        print("[Gradient] CRITICAL: 'Protections' tab creation failed. Aborting launch.")
        return
    end

    -- ================================================================
    -- 4) Load all modules (each download/load is individually guarded)
    -- ================================================================
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
end)

-- ================================================================
-- Top-level guard: nothing above is unprotected, so no "attempt to
-- call a nil value" can escape. On failure report which variable is
-- empty / what errored.
-- ================================================================
if not GradientInitStatus then
    print("[Gradient] FATAL init error: " .. tostring(GradientInitErr))
    print(("[Gradient] Diagnostics: GradientFluent=%s | GradientWindow=%s | GradientTabs=%s (all must be 'table')")
        :format(type(_G.GradientFluent), type(_G.GradientWindow), type(_G.GradientTabs)))
end