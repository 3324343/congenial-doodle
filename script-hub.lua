E3repeat task.wait() until game:IsLoaded()

-- CONFIG
getgenv().Image = "rbxassetid://7229442422"
getgenv().ToggleUIKey = "E"

local Window
local Minimized = false

--====================================================
-- MOBILE BUTTON
--====================================================
task.spawn(function()
    if getgenv().LoadedMobileUI then return end
    getgenv().LoadedMobileUI = true

    local CoreGui = game:GetService("CoreGui")
    local OpenUI = Instance.new("ScreenGui")
    OpenUI.Name = "OpenUI_Toggle"
    OpenUI.Parent = CoreGui
    OpenUI.ResetOnSpawn = false

    local Btn = Instance.new("ImageButton", OpenUI)
    Btn.Size = UDim2.new(0, 50, 0, 50)
    Btn.Position = UDim2.new(0.9, 0, 0.1, 0)
    Btn.Image = getgenv().Image
    Btn.BackgroundTransparency = 0.6
    Btn.Active = true
    Btn.Draggable = true

    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 200)

    Btn.MouseButton1Click:Connect(function()
        if not Window then return end
        Minimized = not Minimized

        if Minimized then
            Window:Minimize()
        else
            Window:Maximize(false) -- ❗ DIBUAT TIDAK FULLSCREEN
        end
    end)
end)

--====================================================
-- LOAD FLUENT
--====================================================
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

Window = Fluent:CreateWindow({
    Title = "Fluent " .. Fluent.Version,
    SubTitle = "by Dawid",
    Size = UDim2.fromOffset(580, 460), -- ❗ TIDAK FULLSCREEN
    TabWidth = 160,
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode[getgenv().ToggleUIKey]
})

Tabs.Main:AddButton({
    Title = "Infinite Yield",
    Description = "FE Admin commands",
    Callback = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
    end
})

--====================================================
-- KEYBOARD TOGGLE
--====================================================
game:GetService("UserInputService").InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode[getgenv().ToggleUIKey] then
        Minimized = not Minimized
        if Minimized then
            Window:Minimize()
        else
            Window:Maximize(false) -- ❗ TIDAK FULLSCREEN
        end
    end
end)

--====================================================
-- TABS + BUTTON
--====================================================
local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "home" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

Tabs.Main:AddButton({
    Title = "Test Button",
    Description = "contoh",
    Callback = function()
        Fluent:Notify({ Title = "OK", Content = "Button pressed", Duration = 3 })
    end
})

--====================================================
-- SAVE + INTERFACE
--====================================================
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

InterfaceManager:SetFolder("FluentConfig")
SaveManager:SetFolder("FluentConfig/Settings")

SaveManager:IgnoreThemeSettings()
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

Fluent:Notify({
    Title = "Loaded",
    Content = "Fluent UI berhasil dimuat.",
    Duration = 4
})
