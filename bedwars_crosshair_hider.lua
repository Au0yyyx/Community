-- BedWars / Roblox crosshair and cursor hider (client-side)
if not game:IsLoaded() then game.Loaded:Wait() end

local env = getgenv and getgenv() or _G
if env.__CrosshairHider and env.__CrosshairHider.Destroy then
    env.__CrosshairHider:Destroy()
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()

local Hider = {
    Connections = {},
    Hidden = setmetatable({}, {__mode = "k"}),
    OldMouseIconEnabled = UIS.MouseIconEnabled,
    OldMouseIcon = Mouse.Icon
}
env.__CrosshairHider = Hider

local exact = {
    crosshair=true, cursor=true, reticle=true, cross=true,
    mousecursor=true, mouseicon=true, aimcursor=true, aimreticle=true,
    firstpersoncrosshair=true, mobilecrosshair=true
}

local function compact(value)
    return tostring(value):lower():gsub("[^%w]", "")
end

local function isCrosshair(instance)
    if not instance:IsA("GuiObject") then return false end
    local current = instance
    for _ = 1, 5 do
        if not current then break end
        local name = compact(current.Name)
        if exact[name]
            or name:find("crosshair", 1, true)
            or name:find("reticle", 1, true)
            or name:find("aimcursor", 1, true)
            or name:find("mousecursor", 1, true) then
            return true
        end
        current = current.Parent
    end
    return false
end

local function hide(instance)
    if not isCrosshair(instance) then return end
    if Hider.Hidden[instance] == nil then
        Hider.Hidden[instance] = instance.Visible
    end
    instance.Visible = false
    Hider.Connections[#Hider.Connections + 1] = instance:GetPropertyChangedSignal("Visible"):Connect(function()
        if instance.Parent and instance.Visible then instance.Visible = false end
    end)
end

local function scan(root)
    pcall(function()
        for _, instance in ipairs(root:GetDescendants()) do
            hide(instance)
        end
    end)
end

UIS.MouseIconEnabled = false
Mouse.Icon = ""

scan(LP:WaitForChild("PlayerGui"))
scan(CoreGui)

Hider.Connections[#Hider.Connections + 1] = LP.PlayerGui.DescendantAdded:Connect(function(instance)
    task.defer(hide, instance)
end)

pcall(function()
    Hider.Connections[#Hider.Connections + 1] = CoreGui.DescendantAdded:Connect(function(instance)
        task.defer(hide, instance)
    end)
end)

Hider.Connections[#Hider.Connections + 1] = UIS:GetPropertyChangedSignal("MouseIconEnabled"):Connect(function()
    if UIS.MouseIconEnabled then UIS.MouseIconEnabled = false end
end)

Hider.Connections[#Hider.Connections + 1] = Mouse:GetPropertyChangedSignal("Icon"):Connect(function()
    if Mouse.Icon ~= "" then Mouse.Icon = "" end
end)

function Hider:Destroy()
    for _, connection in ipairs(self.Connections) do
        pcall(connection.Disconnect, connection)
    end
    table.clear(self.Connections)

    for instance, wasVisible in pairs(self.Hidden) do
        if instance.Parent then
            pcall(function() instance.Visible = wasVisible end)
        end
    end
    table.clear(self.Hidden)

    UIS.MouseIconEnabled = self.OldMouseIconEnabled
    Mouse.Icon = self.OldMouseIcon

    if env.__CrosshairHider == self then
        env.__CrosshairHider = nil
    end
end

