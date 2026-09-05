if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local Environment = getgenv and getgenv() or _G
local ADDON_KEY = "__FartHubAzureAimFix"

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
local Network = require(ReplicatedStorage.Modules.Network.Network)
local AzureConfig = require(ReplicatedStorage.Assets.Killers.Azure.Config)

local Controller = {
    Connections = {},
    Controls = {},
    Destroyed = false,
    Settings = {
        Enabled = false,
        Prediction = 2.5,
        AimPart = "Torso",
        WallCheck = true
    }
}
Environment[ADDON_KEY] = Controller

local function getRoot(model)
    return model and (
        model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
    )
end

local function getAzureActor()
    local actor = Actors.CurrentActors[LocalPlayer]
    if actor and actor.ActorName == "Azure" and actor.Rig and actor.Rig.Parent then
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

local function findTarget(actor, origin)
    local camera = workspace.CurrentCamera
    local playersFolder = workspace:FindFirstChild("Players")
    local survivors = playersFolder and playersFolder:FindFirstChild("Survivors")
    if not camera or not survivors then
        return nil
    end

    local maximumDistance = AzureConfig.Grab.HookRange
    local cursor = UserInputService:GetMouseLocation()
    local bestModel
    local bestScore = math.huge

    for _, survivor in ipairs(survivors:GetChildren()) do
        if survivor ~= LocalPlayer.Character and isAlive(survivor) then
            local position = getAimPoint(survivor)
            if position then
                local distance = (position - origin).Magnitude
                local screenPoint, visible = camera:WorldToViewportPoint(position)
                if distance <= maximumDistance
                    and visible
                    and hasLineOfSight(actor.Rig, survivor, origin, position) then
                    local score = (Vector2.new(screenPoint.X, screenPoint.Y) - cursor).Magnitude
                    if score < bestScore then
                        bestModel = survivor
                        bestScore = score
                    end
                end
            end
        end
    end
    return bestModel
end

local function getEnstranglePosition()
    if Controller.Destroyed or not Controller.Settings.Enabled then
        return nil
    end

    local actor = getAzureActor()
    local actorState = actor and actor.State
    local originPart = actorState and actorState.GrabbedRoot
        or actor and getRoot(actor.Rig)
    if not actor or not originPart then
        return nil
    end

    local target = findTarget(actor, originPart.Position)
    local position, velocity = target and getAimPoint(target)
    if not position then
        return nil
    end

    local hookSpeed = AzureConfig.Grab.HookSpeed
    local travelTime = hookSpeed > 0
        and (position - originPart.Position).Magnitude / hookSpeed or 0
    return position + velocity * travelTime * Controller.Settings.Prediction
end

local originalFireServerConnection
originalFireServerConnection = hookfunction(
    Network.FireServerConnection,
    newcclosure(function(self, connectionName, connectionType, ...)
        if not Controller.Destroyed
            and type(connectionName) == "string"
            and connectionName:sub(-27) == "AzureUpdateCameraLookVector" then
            local position = getEnstranglePosition()
            if position then
                local actor = getAzureActor()
                if actor and actor.State then
                    actor.State.CameraLookPosition = position
                end
                return originalFireServerConnection(
                    self,
                    connectionName,
                    connectionType,
                    position
                )
            end
        end
        return originalFireServerConnection(self, connectionName, connectionType, ...)
    end)
)
Controller.OriginalFireServerConnection = originalFireServerConnection

local Groupbox = Library.Tabs.Addons:AddRightGroupbox("Azure Enstrangle Silent Aim")
Controller.Groupbox = Groupbox

local enabledToggle = Groupbox:AddToggle("FartHubAzureStandaloneSilentAim", {
    Text = "Enstrangle Silent Aim",
    Default = Controller.Settings.Enabled,
    Callback = function(value)
        Controller.Settings.Enabled = value
    end
})
table.insert(Controller.Controls, enabledToggle)

local predictionSlider = Groupbox:AddSlider("FartHubAzureStandalonePrediction", {
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

local partDropdown = Groupbox:AddDropdown("FartHubAzureStandaloneAimPart", {
    Text = "Aim Part",
    Values = { "Top", "Head", "Torso", "HumanoidRootPart", "Bottom" },
    Default = Controller.Settings.AimPart,
    Multi = false,
    Callback = function(value)
        Controller.Settings.AimPart = value
    end
})
table.insert(Controller.Controls, partDropdown)

local wallCheckToggle = Groupbox:AddToggle("FartHubAzureStandaloneWallCheck", {
    Text = "Wall Check",
    Default = Controller.Settings.WallCheck,
    Callback = function(value)
        Controller.Settings.WallCheck = value
    end
})
table.insert(Controller.Controls, wallCheckToggle)

Groupbox:AddLabel(
    "Original Enstrangle vector targeting. No FOV and no FartHub Silent Aim integration.",
    true
)

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

    if self.OriginalFireServerConnection then
        pcall(
            hookfunction,
            Network.FireServerConnection,
            self.OriginalFireServerConnection
        )
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


