local gui = Instance.new("ScreenGui")
gui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

local text = Instance.new("TextLabel")
text.Parent = gui
text.Size = UDim2.new(1, 0, 1, 0)
text.Position = UDim2.new(0, 0, 0, 0)
text.Text = "This version is outdated, new version copied to clipboard! <3"
text.TextColor3 = Color3.new(0, 0, 0)
text.BackgroundTransparency = 1
text.TextScaled = true

task.wait(3)

gui:destroy()
setclipboard([[-- the key saves, click M to unlock mouse/close gui!

getgenv().RuHubSettings = {
    UnlockMouse = true, -- set to false to stop unlocking mouse
    LoadLastConfig =  false, -- set to true to load your saved config
    RemoveEndGrabEarly = true -- set to false to not remove endgrabearly
}

loadstring(game:HttpGet("https://gitlab.com/cooldawghaha/gitlabswitch/-/raw/main/RuHubFTAP.lua"))()]])