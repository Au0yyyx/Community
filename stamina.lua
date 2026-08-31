if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Actors = require(ReplicatedStorage.Modules.Gameplay.Actors)
local Env = getgenv and getgenv() or _G
local KEY = "__ForsakenStaminaTrackerV2"

for _, oldKey in ipairs({"__ForsakenKillerStaminaV1", KEY}) do
    local old = Env[oldKey]
    if type(old) == "table" and type(old.Destroy) == "function" then pcall(old.Destroy, old) end
end

local App = {Connections = {}, Trackers = {}, Destroyed = false, Role = "Unknown"}
Env[KEY] = App

local function connect(signal, fn)
    local c = signal:Connect(fn)
    App.Connections[#App.Connections + 1] = c
    return c
end

local function rootOf(model)
    return model and (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart"))
end

local function humanoidOf(model)
    return model and model:FindFirstChildOfClass("Humanoid")
end

local function roleOfLocalPlayer()
    local character = LocalPlayer.Character
    local parentName = character and character.Parent and character.Parent.Name:lower() or ""
    if parentName:find("killer", 1, true) then return "Killer" end
    if parentName:find("survivor", 1, true) then return "Survivor" end
    if parentName:find("spectat", 1, true) then return "Spectating" end
    local role = tostring(LocalPlayer:GetAttribute("Role") or ""):lower()
    if role == "killer" then return "Killer" end
    if role == "survivor" then return "Survivor" end
    return "Spectating"
end

local function actorName(model)
    return tostring(model:GetAttribute("ActorDisplayName")
        or model:GetAttribute("ActorName")
        or model.Name)
end

local ConfigCache = {}
local function statsFor(model, actorType)
    local name = actorName(model)
    local cacheKey = actorType .. ":" .. name
    if ConfigCache[cacheKey] then return ConfigCache[cacheKey] end
    local defaults = actorType == "Killer"
        and {Max = 110, Loss = 9.5, Gain = 21, Walk = 9, Sprint = 27}
        or {Max = 100, Loss = 10, Gain = 20, Walk = 12, Sprint = 26}
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local folder = assets and assets:FindFirstChild(actorType .. "s")
    folder = folder and (folder:FindFirstChild(name) or folder:FindFirstChild(model.Name))
    local configModule = folder and folder:FindFirstChild("Config")
    if configModule and configModule:IsA("ModuleScript") then
        local ok, config = pcall(require, configModule)
        if ok and type(config) == "table" then
            defaults = {
                Max = tonumber(config.MaxStamina) or defaults.Max,
                Loss = tonumber(config.StaminaLoss) or defaults.Loss,
                Gain = tonumber(config.StaminaGain) or defaults.Gain,
                Walk = tonumber(config.Speed) or defaults.Walk,
                Sprint = tonumber(config.SprintSpeed) or defaults.Sprint,
                EnragedCap = tonumber(config.EnragedStaminaCap),
                EnragedCapTime = tonumber(config.EnragedStaminaCapLerpTime),
                EnragedSpeed = tonumber(config.EnragedSpeed),
            }
        end
    end
    -- Azure's Golem is a form swap inside Azure rather than its own asset config.
    if name:lower():find("golem", 1, true) or model:GetAttribute("Golem") == true then
        defaults.Max, defaults.Sprint = 50, 30
    end
    ConfigCache[cacheKey] = defaults
    return defaults
end

local function createDisplay(model, actorType)
    local gui = Instance.new("BillboardGui")
    gui.Name = "ForsakenStamina_" .. model.Name
    gui.AlwaysOnTop = true
    gui.LightInfluence = 0
    gui.MaxDistance = 500
    gui.Size = UDim2.fromOffset(190, 50)
    gui.StudsOffsetWorldSpace = Vector3.new(0, 2.8, 0)
    gui.Adornee = model:FindFirstChild("Head") or rootOf(model)
    gui.Parent = CoreGui

    local back = Instance.new("Frame")
    back.AnchorPoint = Vector2.new(0.5, 0.5)
    back.Position = UDim2.fromScale(0.5, 0.5)
    back.Size = UDim2.fromOffset(155, 12)
    back.BackgroundColor3 = Color3.fromRGB(16, 18, 23)
    back.BorderSizePixel = 0
    back.Parent = gui
    Instance.new("UICorner", back).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale(1, 1)
    fill.BackgroundColor3 = Color3.fromRGB(80, 220, 120)
    fill.BorderSizePixel = 0
    fill.Parent = back
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(-15, -21)
    label.Size = UDim2.new(1, 30, 0, 19)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.25
    label.Parent = back

    local detail = Instance.new("TextLabel")
    detail.BackgroundTransparency = 1
    detail.Position = UDim2.fromOffset(-15, 12)
    detail.Size = UDim2.new(1, 30, 0, 14)
    detail.Font = Enum.Font.GothamMedium
    detail.TextSize = 9
    detail.TextColor3 = actorType == "Killer" and Color3.fromRGB(255, 155, 155) or Color3.fromRGB(150, 205, 255)
    detail.TextStrokeTransparency = 0.45
    detail.Parent = back
    return gui, fill, label, detail
end

local function newTracker(model, actorType)
    local stats = statsFor(model, actorType)
    local gui, fill, label, detail = createDisplay(model, actorType)
    local root = rootOf(model)
    return {
        Model = model, Type = actorType, Name = actorName(model), Stats = stats,
        Estimate = stats.Max, ExhaustUntil = 0, LastPosition = root and root.Position,
        SmoothedSpeed = 0, DrainAllowed = actorType ~= "Killer",
        Enraged = false, EnragedSince = 0,
        WasSprinting = false, RecoveryDelay = 0,
        LastAnimCheck = 0, SprintAnimation = false, EnragedAnimation = false,
        NearestDistance = math.huge, PathDistance = math.huge, LastGateScan = 0,
        Gui = gui, Fill = fill, Label = label, Detail = detail,
    }
end

local function actorStateFor(model)
    for _, actor in pairs(Actors.CurrentActors) do
        if actor.Rig == model then return actor.State end
    end
end

local function sprintState(tracker, humanoid, actorState, now)
    -- Animation-track enumeration is relatively expensive, so sample at 10 Hz.
    if now - tracker.LastAnimCheck >= 0.1 then
        tracker.LastAnimCheck = now
        tracker.SprintAnimation = false
        tracker.EnragedAnimation = false
        local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                local name = string.lower(track.Name)
                if track.WeightCurrent > 0.15 and name:find("enraged", 1, true) then
                    tracker.EnragedAnimation = true
                end
                if track.WeightCurrent > 0.15
                    and (name:find("sprint", 1, true) or name:find("run", 1, true)) then
                    tracker.SprintAnimation = true
                    break
                end
            end
        end
    end

    -- A replicated true is authoritative. A replicated false is not: remote
    -- actor State tables often remain false even while their run replicates.
    if actorState and actorState.isSprinting == true then
        return true
    end
    local walkSpeed = humanoid and humanoid.WalkSpeed or 0
    local fastWalkSpeed = walkSpeed > 20
    local movementSaysSprint = tracker.SmoothedSpeed > tracker.Stats.Walk
        + math.max(3, (tracker.Stats.Sprint - tracker.Stats.Walk) * 0.28)
    -- Require actual movement. Animation/WalkSpeed confirms borderline cases;
    -- displacement still catches games that implement sprint with multipliers.
    return tracker.SmoothedSpeed > 1
        and (movementSaysSprint or (tracker.SprintAnimation and tracker.SmoothedSpeed > tracker.Stats.Walk * 1.08)
            or (fastWalkSpeed and tracker.SprintAnimation))
end

local function destroyTracker(tracker)
    if tracker.Gui then tracker.Gui:Destroy() end
end

local function livingModels(folder)
    local result = {}
    if not folder then return result end
    for _, model in ipairs(folder:GetChildren()) do
        local hum = humanoidOf(model)
        if model:IsA("Model") and rootOf(model) and hum and hum.Health > 0 then result[#result + 1] = model end
    end
    return result
end

local function updateKillerGate(tracker, survivorModels, now)
    if now - tracker.LastGateScan < 0.45 then return end
    tracker.LastGateScan = now
    local killerRoot = rootOf(tracker.Model)
    local nearest = math.huge
    for _, survivor in ipairs(survivorModels) do
        local root = rootOf(survivor)
        local d = root and (root.Position - killerRoot.Position).Magnitude or math.huge
        if d < nearest then nearest = d end
    end
    tracker.NearestDistance = nearest
    -- Forsaken's killer stamina gate is radial, not a navigable-path check.
    -- The previous 85-stud/pathfinding approximation missed real drain from
    -- survivors between 85 and 100 studs and caused most of the visible drift.
    tracker.PathDistance = nearest
    tracker.DrainAllowed = nearest <= 100
end

local function wantedTargets(role, killers, survivors)
    local wanted = {}
    if role == "Survivor" or role == "Spectating" then
        for _, m in ipairs(killers) do wanted[m] = "Killer" end
    end
    if role == "Killer" or role == "Spectating" then
        for _, m in ipairs(survivors) do wanted[m] = "Survivor" end
    end
    return wanted
end

connect(RunService.Heartbeat, function(dt)
    if App.Destroyed then return end
    local playerFolder = workspace:FindFirstChild("Players")
    local killers = livingModels(playerFolder and playerFolder:FindFirstChild("Killers"))
    local survivors = livingModels(playerFolder and playerFolder:FindFirstChild("Survivors"))
    App.Role = roleOfLocalPlayer()
    local wanted = wantedTargets(App.Role, killers, survivors)

    for model, tracker in pairs(App.Trackers) do
        if not wanted[model] or not model.Parent then destroyTracker(tracker); App.Trackers[model] = nil end
    end
    for model, actorType in pairs(wanted) do
        if not App.Trackers[model] then App.Trackers[model] = newTracker(model, actorType) end
    end

    local now = os.clock()
    for model, t in pairs(App.Trackers) do
        local root = rootOf(model)
        if root then
            t.Gui.Adornee = model:FindFirstChild("Head") or root
            if t.Type == "Killer" then updateKillerGate(t, survivors, now) end
            local position, rawSpeed = root.Position, 0
            if t.LastPosition and dt > 0 then
                local delta = position - t.LastPosition
                rawSpeed = Vector3.new(delta.X, 0, delta.Z).Magnitude / dt
                if rawSpeed > 80 then rawSpeed = 0 end
            end
            t.LastPosition = position
            t.SmoothedSpeed += (rawSpeed - t.SmoothedSpeed) * math.clamp(dt * 12, 0, 1)
            local state = t.Type == "Killer" and actorStateFor(model)
            local enraged = t.Stats.EnragedCap ~= nil
                and ((state and state.isEnraged == true) or t.EnragedAnimation)
            if enraged and not t.Enraged then t.EnragedSince = now end
            t.Enraged = enraged
            local staminaCap = t.Stats.Max
            if enraged then
                local alpha = math.clamp((now - t.EnragedSince) / math.max(t.Stats.EnragedCapTime or 6.5, 0.01), 0, 1)
                staminaCap = t.Stats.Max + (t.Stats.EnragedCap - t.Stats.Max) * alpha
            end
            -- Raging Pace disables sprinting. Its fixed EnragedSpeed must never
            -- be mistaken for normal stamina drain.
            local sprinting = not enraged and sprintState(t, humanoidOf(model), state, now)
            local draining = sprinting and t.DrainAllowed
            if draining then
                t.Estimate = math.max(0, t.Estimate - t.Stats.Loss * dt)
                -- Mirrors Systems.Character.Game.Sprinting: the recovery wait
                -- grows slowly while sprinting, from 0.2 up to 2 seconds.
                t.RecoveryDelay = math.clamp(t.RecoveryDelay + dt * 0.05, 0.2, 2)
                if t.Estimate <= 0.01 then t.RecoveryDelay = 2 end
            else
                if t.WasSprinting then
                    t.RecoveryDelay = t.RecoveryDelay > 0.1
                        and math.clamp(t.RecoveryDelay + 0.1, 0, 2) or 0.1
                end
                t.RecoveryDelay = math.max(0, t.RecoveryDelay - dt)
            end
            local staminaOverride = model:GetAttribute("AbilityStaminaOverride") == true
            if not draining and t.RecoveryDelay <= 0 and not staminaOverride then
                t.Estimate = math.min(staminaCap, t.Estimate + t.Stats.Gain * dt)
            end
            t.WasSprinting = draining
            t.Estimate = math.min(t.Estimate, staminaCap)
            local ratio = math.clamp(t.Estimate / t.Stats.Max, 0, 1)
            t.Fill.Size = UDim2.fromScale(ratio, 1)
            t.Fill.BackgroundColor3 = Color3.fromHSV(ratio * 0.33, 0.78, 0.95)
            t.Label.Text = string.format("%s: %.1f / %.0f", t.Name, t.Estimate, t.Stats.Max)
            if t.Type == "Killer" then
                t.Detail.Text = enraged
                    and string.format("KILLER • RAGING PACE • CAP %.0f", staminaCap)
                    or string.format("KILLER • %s • %.1fs", sprinting and "SPRINT" or
                        (t.RecoveryDelay > 0 and "RECOVERY WAIT" or "REGEN"), t.RecoveryDelay)
            else
                t.Detail.Text = string.format("SURVIVOR • %s • %.1f speed", sprinting and "DRAIN" or "REGEN", t.SmoothedSpeed)
            end
        end
    end
end)

function App:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
    for _, tracker in pairs(self.Trackers) do destroyTracker(tracker) end
    table.clear(self.Connections); table.clear(self.Trackers)
    if Env[KEY] == self then Env[KEY] = nil end
end

print("[Forsaken Stamina Tracker V2] Loaded - role-aware")

