if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local Environment = getgenv and getgenv() or _G
local ADDON_KEY = "__FartHubPlantFootprintESP"

local previous = Environment[ADDON_KEY]
if type(previous) == "table" and type(previous.Destroy) == "function" then
    pcall(previous.Destroy, previous)
end

local function waitForFartHub(timeout)
    local deadline = os.clock() + timeout
    repeat
        local library = Environment.Library
        local addonsTab = type(library) == "table"
            and type(library.Tabs) == "table" and library.Tabs.Addons
        if type(addonsTab) == "table" then
            return library, addonsTab
        end
        task.wait(0.1)
    until os.clock() >= deadline
end

local Library, AddonsTab = waitForFartHub(30)
assert(Library and AddonsTab, "FartHub Addons tab was not found")

local Controller = {
    Connections = {},
    Controls = {},
    Visuals = {},
    Destroyed = false,
    LastUpdate = 0,
    LastScan = 0,
    Settings = {
        SeekerEnabled = true,
        SeekerColor = Color3.fromRGB(255, 214, 64),
        VineEnabled = true,
        VineColor = Color3.fromRGB(214, 76, 255),
        FootprintEnabled = true,
        FootprintColor = Color3.fromRGB(105, 10, 18),
        ShowDistance = true
    }
}
Environment[ADDON_KEY] = Controller

local OBJECT_TYPES = {
    Seeker = {
        Label = "SEEKER BULB",
        EnabledKey = "SeekerEnabled",
        ColorKey = "SeekerColor"
    },
    Vine = {
        Label = "STIGMATIZE VINE",
        EnabledKey = "VineEnabled",
        ColorKey = "VineColor"
    },
    Footprint = {
        Label = "DIGITAL FOOTPRINT",
        EnabledKey = "FootprintEnabled",
        ColorKey = "FootprintColor"
    }
}

local function getIngameFolder()
    local map = workspace:FindFirstChild("Map")
    return map and map:FindFirstChild("Ingame")
end

local function getAdornee(instance)
    if instance:IsA("BasePart") then
        return instance
    end
    if instance:IsA("Model") then
        return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
    end
end

local function getFootprintHitbox(shadow)
    local container = shadow and shadow.Parent
    if not container then
        return shadow
    end

    for _, candidate in ipairs(container:GetDescendants()) do
        if candidate:IsA("BasePart") and candidate ~= shadow then
            local name = candidate.Name:lower()
            if name:find("hitbox", 1, true)
                or name:find("collision", 1, true)
                or name:find("query", 1, true) then
                return candidate
            end
        end
    end
    return shadow
end

local function classify(instance)
    local ingame = getIngameFolder()
    if not ingame or not instance:IsDescendantOf(ingame) then
        return nil
    end

    if instance:IsA("Model") and instance.Parent == ingame then
        if instance.Name == "GroundBulbModel" then
            return "Seeker"
        elseif instance.Name == "VineModel" then
            return "Vine"
        end
    elseif instance:IsA("BasePart") and instance.Name == "Shadow" then
        local shadowFolder = instance.Parent
        if shadowFolder and shadowFolder.Parent == ingame
            and string.sub(shadowFolder.Name, -7) == "Shadows" then
            return "Footprint"
        end
    end
end

local function removeVisual(instance)
    local visual = Controller.Visuals[instance]
    if not visual then
        return
    end
    Controller.Visuals[instance] = nil
    pcall(function()
        visual.Highlight:Destroy()
    end)
    pcall(function()
        visual.Billboard:Destroy()
    end)
    if visual.HitboxCham then
        pcall(function()
            visual.HitboxCham:Destroy()
        end)
    end
    if visual.HitboxOutline then
        pcall(function()
            visual.HitboxOutline:Destroy()
        end)
    end
end

local function addVisual(instance, objectType)
    if Controller.Destroyed or Controller.Visuals[instance] then
        return
    end

    local hitbox = objectType == "Footprint" and getFootprintHitbox(instance) or nil
    local adornee = hitbox or getAdornee(instance)
    local typeData = OBJECT_TYPES[objectType]
    if not adornee or not typeData then
        return
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "FartHubObjectESP"
    highlight.Adornee = instance
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = objectType == "Footprint" and 0.60 or 0.65
    highlight.OutlineTransparency = 0
    highlight.Parent = instance

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "FartHubObjectESPLabel"
    billboard.Adornee = adornee
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.MaxDistance = 10000
    billboard.Size = UDim2.fromOffset(220, 44)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
    billboard.Parent = adornee

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Code
    label.Size = UDim2.fromScale(1, 1)
    label.TextSize = 14
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0.2
    label.TextWrapped = true
    label.Parent = billboard

    local hitboxCham
    local hitboxOutline
    if false and objectType == "Footprint" and hitbox then
        hitboxCham = Instance.new("BoxHandleAdornment")
        hitboxCham.Name = "FartHubFootprintHitboxCham"
        hitboxCham.Adornee = hitbox
        hitboxCham.AlwaysOnTop = true
        hitboxCham.ZIndex = 10
        hitboxCham.Size = hitbox.Size
        hitboxCham.Transparency = 0.55
        hitboxCham.Parent = hitbox

        hitboxOutline = Instance.new("SelectionBox")
        hitboxOutline.Name = "FartHubFootprintHitboxOutline"
        hitboxOutline.Adornee = hitbox
        hitboxOutline.AlwaysOnTop = true
        hitboxOutline.LineThickness = 0.03
        hitboxOutline.SurfaceTransparency = 1
        hitboxOutline.Parent = hitbox
    end

    Controller.Visuals[instance] = {
        Type = objectType,
        Adornee = adornee,
        Hitbox = hitbox,
        HitboxCham = hitboxCham,
        HitboxOutline = hitboxOutline,
        Highlight = highlight,
        Billboard = billboard,
        Label = label
    }
end

local function consider(instance)
    local objectType = classify(instance)
    if objectType then
        addVisual(instance, objectType)
    end
end

local function scanObjects()
    local ingame = getIngameFolder()
    if not ingame then
        return
    end

    for _, child in ipairs(ingame:GetChildren()) do
        consider(child)
        if string.sub(child.Name, -7) == "Shadows" then
            for _, shadow in ipairs(child:GetChildren()) do
                consider(shadow)
            end
        end
    end
end

local function getLocalPosition()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return root and root.Position
end

local function updateVisuals()
    local localPosition = getLocalPosition()
    for instance, visual in pairs(Controller.Visuals) do
        local typeData = OBJECT_TYPES[visual.Type]
        if not instance.Parent
            or not visual.Adornee.Parent
            or (visual.Hitbox and not visual.Hitbox.Parent)
            or not classify(instance) then
            removeVisual(instance)
        else
            local enabled = Controller.Settings[typeData.EnabledKey]
            local color = Controller.Settings[typeData.ColorKey]
            local distance = localPosition and (visual.Adornee.Position - localPosition).Magnitude or 0
            local inRange = not localPosition or distance <= 350
            enabled = enabled and inRange
            visual.Highlight.Enabled = enabled
            visual.Highlight.FillColor = visual.Type == "Footprint" and Color3.fromRGB(105, 10, 18) or color
            visual.Highlight.OutlineColor = visual.Type == "Footprint" and Color3.fromRGB(255, 255, 255) or color
            visual.Billboard.Enabled = enabled
            visual.Label.TextColor3 = color

            if visual.HitboxCham then
                visual.HitboxCham.Visible = enabled
                visual.HitboxCham.Color3 = color
                visual.HitboxCham.Size = visual.Hitbox.Size
            end
            if visual.HitboxOutline then
                visual.HitboxOutline.Visible = enabled
                visual.HitboxOutline.Color3 = color
            end

            local text = typeData.Label
            if Controller.Settings.ShowDistance and localPosition then
                local distance = (visual.Adornee.Position - localPosition).Magnitude
                text ..= string.format("\n[%d studs]", math.round(distance))
            end
            visual.Label.Text = text
        end
    end
end

local Groupbox = AddonsTab:AddLeftGroupbox("Plant / Footprint ESP")
Controller.Groupbox = Groupbox

local seekerToggle = Groupbox:AddToggle("FartHubSeekerPlantESP", {
    Text = "Seeker Bulb ESP",
    Default = Controller.Settings.SeekerEnabled,
    Callback = function(value)
        Controller.Settings.SeekerEnabled = value
        updateVisuals()
    end
})
table.insert(Controller.Controls, seekerToggle)
local seekerColor = seekerToggle:AddColorPicker("FartHubSeekerPlantColor", {
    Default = Controller.Settings.SeekerColor,
    Title = "Seeker Bulb Color",
    Callback = function(value)
        Controller.Settings.SeekerColor = value
        updateVisuals()
    end
})
table.insert(Controller.Controls, seekerColor)

local vineToggle = Groupbox:AddToggle("FartHubVinePlantESP", {
    Text = "Stigmatize Vine ESP",
    Default = Controller.Settings.VineEnabled,
    Callback = function(value)
        Controller.Settings.VineEnabled = value
        updateVisuals()
    end
})
table.insert(Controller.Controls, vineToggle)
local vineColor = vineToggle:AddColorPicker("FartHubVinePlantColor", {
    Default = Controller.Settings.VineColor,
    Title = "Stigmatize Vine Color",
    Callback = function(value)
        Controller.Settings.VineColor = value
        updateVisuals()
    end
})
table.insert(Controller.Controls, vineColor)

local footprintToggle = Groupbox:AddToggle("FartHubDigitalFootprintESP", {
    Text = "John Doe Digital Footprint ESP",
    Default = Controller.Settings.FootprintEnabled,
    Callback = function(value)
        Controller.Settings.FootprintEnabled = value
        updateVisuals()
    end
})
table.insert(Controller.Controls, footprintToggle)
local footprintColor = footprintToggle:AddColorPicker("FartHubDigitalFootprintColor", {
    Default = Controller.Settings.FootprintColor,
    Title = "Digital Footprint Color",
    Callback = function(value)
        Controller.Settings.FootprintColor = value
        updateVisuals()
    end
})
table.insert(Controller.Controls, footprintColor)

local distanceToggle = Groupbox:AddToggle("FartHubObjectESPDistance", {
    Text = "Show Distance",
    Default = Controller.Settings.ShowDistance,
    Callback = function(value)
        Controller.Settings.ShowDistance = value
        updateVisuals()
    end
})
table.insert(Controller.Controls, distanceToggle)
Groupbox:AddLabel("Tracks Azure's Seeker Bulb and Stigmatize Vine plus John Doe's Digital Footprints.", true)

table.insert(Controller.Connections, workspace.DescendantAdded:Connect(function(instance)
    if instance:IsA("Model") or instance:IsA("BasePart") then
        task.defer(consider, instance)
    end
end))

table.insert(Controller.Connections, RunService.Heartbeat:Connect(function()
    if Controller.Destroyed then
        return
    end
    local now = os.clock()
    if now - Controller.LastUpdate < 0.20 then
        return
    end
    Controller.LastUpdate = now
    if now - Controller.LastScan >= 1 then
        Controller.LastScan = now
        scanObjects()
    end
    updateVisuals()
end))

function Controller:Destroy()
    if self.Destroyed then
        return
    end
    self.Destroyed = true

    for _, connection in ipairs(self.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(self.Connections)

    local instances = {}
    for instance in pairs(self.Visuals) do
        table.insert(instances, instance)
    end
    for _, instance in ipairs(instances) do
        removeVisual(instance)
    end

    if self.Groupbox and type(self.Groupbox.Destroy) == "function" then
        pcall(self.Groupbox.Destroy, self.Groupbox)
    else
        for _, control in ipairs(self.Controls) do
            if type(control) == "table" and type(control.Destroy) == "function" then
                pcall(control.Destroy, control)
            end
        end
    end
    table.clear(self.Controls)

    if Environment[ADDON_KEY] == self then
        Environment[ADDON_KEY] = nil
    end
end

if type(Library.OnUnload) == "function" then
    Library:OnUnload(function()
        Controller:Destroy()
    end)
end

scanObjects()
updateVisuals()

