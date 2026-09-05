if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Env = getgenv and getgenv() or _G
local KEY = "__CatVapeProjectileGuidelineFix"

local previous = Env[KEY]
if type(previous) == "table" and type(previous.Destroy) == "function" then
    previous:Destroy()
end

local Controller = {Destroyed = false, Connections = {}}
Env[KEY] = Controller

local LocalPlayer = Players.LocalPlayer
local Knit = debug.getupvalue(require(LocalPlayer.PlayerScripts.TS.knit).setup, 9)
local ProjectileController = Knit.Controllers.ProjectileController
local class = getmetatable(ProjectileController)
assert(class and type(class.enableTargeting) == "function", "ProjectileController unavailable")

local originalEnableTargeting = class.enableTargeting
Controller.Class = class
Controller.Original = originalEnableTargeting

local function visiblePreviewExists(folder)
    for _, beam in ipairs(CollectionService:GetTagged("projectile-preview-beam")) do
        if beam:IsA("Beam") and beam:IsDescendantOf(folder) then
            return true
        end
    end
    return false
end

class.enableTargeting = function(self, item, projectileSource, animationConfig, input, options)
    local handler = originalEnableTargeting(self, item, projectileSource, animationConfig, input, options)
    task.delay(((options and options.displayBeamDelay) or 0) + 0.06, function()
        if Controller.Destroyed or not self.isTargeting or self.targetingId == 0 then return end
        if not visiblePreviewExists(self.projectileTargetingFolder) then
            pcall(self.enableBeam, self, self.targetingId, handler, nil,
                animationConfig and animationConfig.beamModifier)
        end
    end)
    return handler
end

Controller.Connections[1] = RunService.RenderStepped:Connect(function()
    if Controller.Destroyed then return end
    for _, beam in ipairs(CollectionService:GetTagged("projectile-preview-beam")) do
        if beam:IsA("Beam") then
            beam.Enabled = true
            if beam.Width0 <= 0 then beam.Width0 = 0.08 end
            if beam.Width1 <= 0 then beam.Width1 = 0.08 end
        end
    end
end)

function Controller:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    for _, connection in ipairs(self.Connections) do connection:Disconnect() end
    if self.Class and self.Class.enableTargeting ~= self.Original then
        self.Class.enableTargeting = self.Original
    end
    if Env[KEY] == self then Env[KEY] = nil end
end

