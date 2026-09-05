if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local Environment = getgenv and getgenv() or _G
local ADDON_KEY = "__FartHubStandaloneSilentAim"

local legacy = Environment.__FartHubSilentAimExtension
if type(legacy) == "table" and type(legacy.Destroy) == "function" then
    pcall(legacy.Destroy, legacy)
end
Environment.__FartHubSilentAimExtension = nil

local previous = Environment[ADDON_KEY]
if type(previous) == "table" and type(previous.Destroy) == "function" then
    pcall(previous.Destroy, previous)
end

local function findFartHubLibrary(timeout)
    local deadline = os.clock() + timeout
    repeat
        for _, candidate in ipairs(getgc(true)) do
            if type(candidate) == "table"
                and type(rawget(candidate, "Tabs")) == "table"
                and type(rawget(candidate, "Options")) == "table"
                and type(rawget(candidate, "Toggles")) == "table"
                and candidate.Tabs.Addons then
                return candidate
            end
        end
        task.wait(0.1)
    until os.clock() >= deadline
end

local Library = findFartHubLibrary(30)
assert(Library, "Active FartHub library was not found")

local Actors = require(ReplicatedStorage.Modules.Gameplay.Actors)
local MouseProvider = require(
    ReplicatedStorage.Systems.Player.Miscellaneous.GetPlayerMousePosition
)
local Controller = {
    Connections = {},
    Controls = {},
    Destroyed = false,
    Settings = {
        Enabled = false,
        Characters = {
            c00lkidd = true,
            Dusekkar = true,
            Noli = true,
            JaneDoe = true,            Nosferatwo = true,
            Azure = true,
            ["1x1x1x1"] = true,            Nova = true
        },
        Prediction = 2.5,
        AimPart = "Torso",
        UseFOV = true,
        ShowFOV = true,
        FOVRadius = 150,
        WallCheck = true,
        HighNovaHeight = 5,
        AutoDetonate = false,
        AutoDetonateRadius = 17.25,
        AimSurvivors = true,
        AimKillers = false
    }
}
Environment[ADDON_KEY] = Controller

local function getRoot(model)
    return model and (
        model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
    )
end

local function getActor()
    local actor = Actors.CurrentActors[LocalPlayer]
    if actor and actor.Rig and actor.Rig.Parent then
        return actor
    end
end

local function isAlive(model)
    local humanoid = model and model:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0 and getRoot(model) ~= nil
end

local partAliases = {
    Torso = { "Torso", "UpperTorso", "LowerTorso", "HumanoidRootPart" },
    Head = { "Head" },
    HumanoidRootPart = { "HumanoidRootPart", "Torso", "UpperTorso" }
}

local function getAimPoint(model)
    local root = getRoot(model)
    if not root then
        return nil
    end

    local selected = Controller.Settings.AimPart
    if selected == "High Nova" then
        local boxCFrame, boxSize = model:GetBoundingBox()
        local top = boxCFrame.Position + Vector3.yAxis * boxSize.Y * 0.5
        return top + Vector3.yAxis * Controller.Settings.HighNovaHeight,
            root.AssemblyLinearVelocity
    end
    if selected == "Top" or selected == "Bottom" then
        local boxCFrame, boxSize = model:GetBoundingBox()
        local direction = selected == "Top" and 1 or -1
        return boxCFrame.Position + Vector3.yAxis * boxSize.Y * 0.5 * direction,
            root.AssemblyLinearVelocity
    end

    for _, partName in ipairs(partAliases[selected] or { selected }) do
        local part = model:FindFirstChild(partName, true)
        if part and part:IsA("BasePart") then
            return part.Position, part.AssemblyLinearVelocity
        end
    end
    return root.Position, root.AssemblyLinearVelocity
end

local function getTargetFolders(actor)
    local playersFolder = workspace:FindFirstChild("Players")
    if not playersFolder then return {} end
    local folders = {}
    if Controller.Settings.AimSurvivors then
        local survivors = playersFolder:FindFirstChild("Survivors")
        if survivors then table.insert(folders, survivors) end
    end
    -- Only Dusekkar has a projectile that can validly use killer targets.
    if Controller.Settings.AimKillers and actor.ActorName == "Dusekkar" then
        local killers = playersFolder:FindFirstChild("Killers")
        if killers then table.insert(folders, killers) end
    end
    return folders
end

local function hasLineOfSight(actorRig, targetModel, origin, targetPosition)
    if not Controller.Settings.WallCheck then
        return true
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { actorRig, targetModel }
    params.RespectCanCollide = true
    return workspace:Raycast(origin, targetPosition - origin, params) == nil
end

local function findTarget(actor, projectileSpeed)
    local camera = workspace.CurrentCamera
    local originPart = getRoot(actor.Rig)
    local targetFolders = getTargetFolders(actor)
    if not camera or not originPart then
        return nil
    end

    local cursor = UserInputService:GetMouseLocation()
    local bestModel
    local bestPosition
    local bestVelocity
    local bestScore = math.huge

    for _, targetFolder in ipairs(targetFolders) do
      for _, model in ipairs(targetFolder:GetChildren()) do
        if model ~= LocalPlayer.Character and model ~= actor.Rig and isAlive(model) then
            local position, velocity = getAimPoint(model)
            if position then
                local screenPoint, visible = camera:WorldToScreenPoint(position)
                local score = (Vector2.new(screenPoint.X, screenPoint.Y) - cursor).Magnitude
                if visible
                    and (not Controller.Settings.UseFOV
                        or score <= Controller.Settings.FOVRadius)
                    and hasLineOfSight(actor.Rig, model, originPart.Position, position)
                    and score < bestScore then
                    bestModel = model
                    bestPosition = position
                    bestVelocity = velocity
                    bestScore = score
                end
            end
        end
    end
    end
    return bestModel, bestPosition, bestVelocity
end

local function getSilentAimPosition(projectileSpeed)
    if Controller.Destroyed or not Controller.Settings.Enabled then
        return nil
    end

    local actor = getActor()
    if not actor or Controller.Settings.Characters[actor.ActorName] == false then
        return nil
    end

    local _, position, velocity = findTarget(actor, projectileSpeed)
    local originPart = getRoot(actor.Rig)
    if not position or not originPart then
        return nil
    end

    -- Most Forsaken aim requests omit projectile speed. Keep a real linear lead
    -- in that path instead of silently reducing every slider value to zero.
    local travelTime = type(projectileSpeed) == "number" and projectileSpeed > 0
        and (position - originPart.Position).Magnitude / projectileSpeed or 0.2
    return position + velocity * travelTime * Controller.Settings.Prediction
end

local originalGetMousePos = MouseProvider.GetMousePos
local replacementGetMousePos
replacementGetMousePos = function(self, projectileSpeed, ...)
    local position = getSilentAimPosition(projectileSpeed)
    if position then
        return position
    end
    return originalGetMousePos(self, projectileSpeed, ...)
end
MouseProvider.GetMousePos = replacementGetMousePos
Controller.OriginalGetMousePos = originalGetMousePos
Controller.ReplacementGetMousePos = replacementGetMousePos

-- Current Forsaken routes many abilities through Util:GetPlayerMousePosition.
-- Hook that public wrapper too, and keep both hooks alive if another addon reloads.
-- The current Util export is readonly. MouseProvider is the writable public provider
-- used by ability code, so avoid mutating Util and keep the addon compatible.
local Util = nil

local voidstars = setmetatable({}, { __mode = "k" })
local function trackVoidstar(instance)
    if instance.Name == "Voidstar" and instance:IsA("BasePart") then
        voidstars[instance] = true
    end
end
for _, instance in ipairs(workspace:GetDescendants()) do trackVoidstar(instance) end
table.insert(Controller.Connections, workspace.DescendantAdded:Connect(trackVoidstar))
table.insert(Controller.Connections, workspace.DescendantRemoving:Connect(function(instance)
    voidstars[instance] = nil
end))

local lastDetonate = 0
local function pressNovaKey()
    if type(keypress) == "function" and type(keyrelease) == "function" then
        keypress(0x45)
        task.delay(0.035, function() pcall(keyrelease, 0x45) end)
    else
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.delay(0.035, function()
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end)
    end
end

table.insert(Controller.Connections, RunService.Heartbeat:Connect(function()
    if Controller.Destroyed or not Controller.Settings.Enabled
        or not Controller.Settings.AutoDetonate or os.clock() - lastDetonate < 0.35 then return end
    local actor = getActor()
    if not actor or actor.ActorName ~= "Noli" then return end
    local target, targetPosition = findTarget(actor, actor.Config and actor.Config.NovaProjectileSpeed or 80)
    if not target or not targetPosition then return end
    local radius = Controller.Settings.AutoDetonateRadius
    for star in pairs(voidstars) do
        if not star.Parent then
            voidstars[star] = nil
        elseif not star:IsDescendantOf(actor.Rig)
            and (star.Position - targetPosition).Magnitude <= radius then
            lastDetonate = os.clock()
            pressNovaKey()
            break
        end
      end
    end
end))

local fovCircle
if type(Drawing) == "table" and type(Drawing.new) == "function" then
    local succeeded, circle = pcall(Drawing.new, "Circle")
    if succeeded then
        fovCircle = circle
        fovCircle.Color = Color3.fromRGB(221, 190, 50)
        fovCircle.Filled = false
        fovCircle.NumSides = 64
        fovCircle.Thickness = 1
        fovCircle.Transparency = 0.8
        fovCircle.Visible = false
    end
end
Controller.FOVCircle = fovCircle

table.insert(Controller.Connections, RunService.RenderStepped:Connect(function()
    if not fovCircle then
        return
    end
    fovCircle.Position = UserInputService:GetMouseLocation()
    fovCircle.Radius = Controller.Settings.FOVRadius
    fovCircle.Visible = not Controller.Destroyed
        and Controller.Settings.Enabled
        and Controller.Settings.UseFOV
        and Controller.Settings.ShowFOV
end))

local MainGroup = Library.Tabs.Addons:AddLeftGroupbox("Standalone Silent Aim")
Controller.MainGroup = MainGroup

local enabledToggle = MainGroup:AddToggle("FartHubStandaloneSilentAim", {
    Text = "Silent Aim",
    Default = Controller.Settings.Enabled,
    Callback = function(value)
        Controller.Settings.Enabled = value
    end
})
table.insert(Controller.Controls, enabledToggle)

for _, characterName in ipairs({ "c00lkidd", "Dusekkar", "Noli", "JaneDoe", "Nosferatwo", "Azure", "1x1x1x1", "Nova" }) do
    local toggle = MainGroup:AddToggle("FartHubStandaloneSilentAim_" .. characterName, {
        Text = characterName,
        Default = Controller.Settings.Characters[characterName],
        Callback = function(value)
            Controller.Settings.Characters[characterName] = value
        end
    })
    table.insert(Controller.Controls, toggle)
end

local predictionSlider = MainGroup:AddSlider("FartHubStandaloneSilentAimPrediction", {
    Text = "Prediction Strength",
    Default = Controller.Settings.Prediction,
    Min = 0,
    Max = 5,
    Rounding = 2,
    Callback = function(value)
        Controller.Settings.Prediction = value
    end
})
table.insert(Controller.Controls, predictionSlider)

local partDropdown = MainGroup:AddDropdown("FartHubStandaloneSilentAimPart", {
    Text = "Aim Part",
    Values = {
        "Top",
        "High Nova",
        "Head",
        "Torso",
        "HumanoidRootPart",
        "Bottom"
    },
    Default = Controller.Settings.AimPart,
    Multi = false,
    Callback = function(value)
        Controller.Settings.AimPart = value
    end
})
table.insert(Controller.Controls, partDropdown)

local highNovaSlider = MainGroup:AddSlider("FartHubStandaloneHighNovaHeight", {
    Text = "High Nova Height",
    Default = Controller.Settings.HighNovaHeight,
    Min = 1,
    Max = 10,
    Rounding = 1,
    Suffix = " studs",
    Callback = function(value)
        Controller.Settings.HighNovaHeight = value
    end
})
table.insert(Controller.Controls, highNovaSlider)

local useFOVToggle = MainGroup:AddToggle("FartHubStandaloneSilentAimUseFOV", {
    Text = "Use FOV",
    Default = Controller.Settings.UseFOV,
    Callback = function(value)
        Controller.Settings.UseFOV = value
    end
})
table.insert(Controller.Controls, useFOVToggle)

local radiusSlider = MainGroup:AddSlider("FartHubStandaloneSilentAimFOVRadius", {
    Text = "FOV Radius",
    Default = Controller.Settings.FOVRadius,
    Min = 20,
    Max = 300,
    Rounding = 0,
    Suffix = " px",
    Callback = function(value)
        Controller.Settings.FOVRadius = value
    end
})
table.insert(Controller.Controls, radiusSlider)

local showFOVToggle = MainGroup:AddToggle("FartHubStandaloneSilentAimShowFOV", {
    Text = "Show FOV Circle",
    Default = Controller.Settings.ShowFOV,
    Callback = function(value)
        Controller.Settings.ShowFOV = value
    end
})
table.insert(Controller.Controls, showFOVToggle)

local wallCheckToggle = MainGroup:AddToggle("FartHubStandaloneSilentAimWallCheck", {
    Text = "Wall Check",
    Default = Controller.Settings.WallCheck,
    Callback = function(value)
        Controller.Settings.WallCheck = value
    end
})
table.insert(Controller.Controls, wallCheckToggle)

local aimSurvivorsToggle = MainGroup:AddToggle("FartHubSilentAimSurvivors", {
    Text = "Aim at survivors", Default = Controller.Settings.AimSurvivors,
    Callback = function(value) Controller.Settings.AimSurvivors = value end
})
table.insert(Controller.Controls, aimSurvivorsToggle)
local aimKillersToggle = MainGroup:AddToggle("FartHubSilentAimKillers", {
    Text = "Aim at killers (Dusekkar only)", Default = Controller.Settings.AimKillers,
    Callback = function(value) Controller.Settings.AimKillers = value end
})
table.insert(Controller.Controls, aimKillersToggle)

local autoDetonateToggle = MainGroup:AddToggle("FartHubStandaloneAutoDetonate", {
    Text = "Auto Detonate Nova",
    Default = Controller.Settings.AutoDetonate,
    Callback = function(value) Controller.Settings.AutoDetonate = value end
})
table.insert(Controller.Controls, autoDetonateToggle)

local detonateRadiusSlider = MainGroup:AddSlider("FartHubStandaloneAutoDetonateRadius", {
    Text = "Nova Detonate Range",
    Default = Controller.Settings.AutoDetonateRadius,
    Min = 5,
    Max = 26,
    Rounding = 2,
    Suffix = " studs",
    Callback = function(value) Controller.Settings.AutoDetonateRadius = value end
})
table.insert(Controller.Controls, detonateRadiusSlider)

MainGroup:AddLabel(
    "High Nova aims the selected height above the model's exact top.",
    true
)

function Controller:Destroy()
    if self.Destroyed then
        return
    end
    self.Destroyed = true

    if MouseProvider.GetMousePos == self.ReplacementGetMousePos then
        MouseProvider.GetMousePos = self.OriginalGetMousePos
    end

    for _, connection in ipairs(self.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(self.Connections)

    if self.FOVCircle then
        pcall(function()
            self.FOVCircle:Remove()
        end)
        self.FOVCircle = nil
    end

    for _, control in ipairs(self.Controls) do
        if type(control) == "table" and type(control.Destroy) == "function" then
            pcall(control.Destroy, control)
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


