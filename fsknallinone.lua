if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Environment = getgenv and getgenv() or _G
-- Fartsaken can leave the executor environment's `game` pointing at its Ugc
-- DataModel after a config load. Restore the actual client DataModel first.
if type(getrenv) == "function" and getrenv().game then
    Environment.game = getrenv().game
end
local GUI_KEY = "__ForsakenObsidianSuite"

local function httpGet(url)
    local requestFunction = request or http_request
        or (syn and syn.request) or (http and http.request)
    if type(requestFunction) == "function" then
        local response = requestFunction({ Url = url, Method = "GET" })
        assert(response and (response.Success ~= false)
            and tonumber(response.StatusCode or 200) < 400, "HTTP request failed")
        return response.Body
    end
    return game:HttpGet(url)
end

local legacy = Environment.__ForsakenAllInOneGui
if type(legacy) == "table" and type(legacy.Destroy) == "function" then
    pcall(legacy.Destroy, legacy)
end
Environment.__ForsakenAllInOneGui = nil

local previous = Environment[GUI_KEY]
if type(previous) == "table" and type(previous.Destroy) == "function" then
    pcall(previous.Destroy, previous)
end

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(httpGet(repo .. "Library.lua"))()
local Window = Library:CreateWindow({
    Title = "Forsaken Suite",
    Footer = "Obsidian | RightShift to toggle",
    Center = true,
    AutoShow = true,
    ToggleKeybind = Enum.KeyCode.RightShift
})

local Tabs = {
    Automation = Window:AddTab("Automation"),
    Aim = Window:AddTab("Aim"),
    ESP = Window:AddTab("ESP"),
    Settings = Window:AddTab("Settings")
}

Library.Toggles = Library.Toggles or Toggles or {}
Library.Options = Library.Options or Options or {}

local Controller = {
    Destroyed = false,
    Library = Library,
    FeatureKeys = {
        "__FartHubNosferatuMinigameAddon",
        "__FartHubCharacterReplicationFix",
        "__FartHubAutoGenAddon",
        "__FartHubStandaloneSilentAim",
        "__FartHubAzureAimFix",
        "__FartHubPlantFootprintESP",
        "__FartHubTwoTimeAutoBackstab",
        "__ForsakenStaminaTrackerV2",
        "__ForsakenStaminaChanger"
    }
}
Environment[GUI_KEY] = Controller

local function tabForGroup(title)
    local lower = string.lower(title)
    if lower:find("aim", 1, true) then
        return Tabs.Aim
    end
    if lower:find("esp", 1, true)
        or lower:find("plant", 1, true)
        or lower:find("footprint", 1, true) then
        return Tabs.ESP
    end
    return Tabs.Automation
end

local Router = {}
function Router:AddLeftGroupbox(title)
    return tabForGroup(title):AddLeftGroupbox(title)
end
function Router:AddRightGroupbox(title)
    return tabForGroup(title):AddRightGroupbox(title)
end

Library.Tabs = {
    Addons = Router,
    Generators = Router
}
Library.Toggles["Auto Solve Generator Toggle"] = Library.Toggles["Auto Solve Generator Toggle"] or {
    Value = false,
    SetValue = function(self, value)
        self.Value = value == true
    end
}

local originalLibrary = Environment.Library

local function loadTwoTimeAutoBackstab()
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")

    local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
    local ADDON_KEY = "__FartHubTwoTimeAutoBackstab"

    local previousController = Environment[ADDON_KEY]
    if type(previousController) == "table"
        and type(previousController.Destroy) == "function" then
        pcall(previousController.Destroy, previousController)
    end

    local AddonsTab = Library.Tabs and Library.Tabs.Addons
    assert(type(AddonsTab) == "table", "Forsaken Suite Addons router was not found")

    local Network = require(ReplicatedStorage.Modules.Network.Network)
    local Actors = require(ReplicatedStorage.Modules.Gameplay.Actors)
    local CharacterReplication = require(
        ReplicatedStorage.Systems.Player.Game.CharacterReplication
    )

    local AutoStab = {
        Connections = {},
        Controls = {},
        Destroyed = false,
        LastActivation = 0,
        Attempts = 0,
        LastState = "Waiting",
        Settings = {
            Enabled = false,
            Mode = "Behind",
            Range = 7,
            Guaranteed = false,
            BehindDistance = 2.25,
            CorrectionTiming = 0.03,
            CorrectionHold = 0.28
        }
    }
    Environment[ADDON_KEY] = AutoStab

    local function getRoot(model)
        return model and (
            model:FindFirstChild("HumanoidRootPart")
            or model.PrimaryPart
        )
    end

    local function isAlive(model)
        local humanoid = model and model:FindFirstChildOfClass("Humanoid")
        return humanoid ~= nil and humanoid.Health > 0 and getRoot(model) ~= nil
    end

    local function getTwoTimeActor()
        local actor = Actors.CurrentActors[LocalPlayer]
        local character = LocalPlayer.Character
        if not actor or not character or not isAlive(character) then
            return nil
        end

        local actorName = tostring(actor.ActorName or ""):lower():gsub("[%s_]", "")
        if actorName ~= "twotime" then
            return nil
        end
        return actor
    end

    local function getKillerFolder()
        local playersFolder = workspace:FindFirstChild("Players")
        return playersFolder and playersFolder:FindFirstChild("Killers")
    end

    local function horizontalUnit(vector)
        local flat = Vector3.new(vector.X, 0, vector.Z)
        if flat.Magnitude < 0.001 then
            return nil
        end
        return flat.Unit
    end

    local function isBehindKiller(localRoot, killerRoot)
        local directionToTwoTime = horizontalUnit(
            localRoot.Position - killerRoot.Position
        )
        local killerFacing = horizontalUnit(killerRoot.CFrame.LookVector)
        if not directionToTwoTime or not killerFacing then
            return false
        end

        local backDirection = -killerFacing
        local minimumDot = math.cos(math.rad(70))
        return backDirection:Dot(directionToTwoTime) >= minimumDot
    end

    local function findTarget(localRoot)
        local killerFolder = getKillerFolder()
        if not killerFolder then
            return nil
        end

        local closest
        local closestDistance = AutoStab.Settings.Range
        for _, killer in ipairs(killerFolder:GetChildren()) do
            if isAlive(killer) then
                local killerRoot = getRoot(killer)
                local distance = (killerRoot.Position - localRoot.Position).Magnitude
                local behind = isBehindKiller(localRoot, killerRoot)
                local validAngle = AutoStab.Settings.Guaranteed
                    or AutoStab.Settings.Mode == "Around"
                    or behind
                if distance <= closestDistance and validAngle then
                    closest = killer
                    closestDistance = distance
                end
            end
        end
        return closest
    end

    local function canUseDagger(actor)
        if type(actor.CanUseAbility) ~= "function" then
            return true
        end
        local ok, result = pcall(actor.CanUseAbility, actor, "Dagger")
        return not ok or result ~= false
    end

    local function faceTarget(localRoot, targetRoot)
        local flatTarget = Vector3.new(
            targetRoot.Position.X,
            localRoot.Position.Y,
            targetRoot.Position.Z
        )
        if (flatTarget - localRoot.Position).Magnitude >= 0.001 then
            localRoot.CFrame = CFrame.lookAt(localRoot.Position, flatTarget)
        end
    end

    local function sendCharacterPosition(cframe, velocity)
        local serialized = table.pack(CharacterReplication.Serialize(cframe, velocity))
        Network:FireServerConnection(
            "UpdateCharacterPosition",
            "UREMOTE_EVENT",
            table.unpack(serialized, 1, serialized.n)
        )
    end

    local function getBehindCFrame(target)
        local killerRoot = getRoot(target)
        if not killerRoot then
            return nil
        end

        local facing = horizontalUnit(killerRoot.CFrame.LookVector)
        if not facing then
            return nil
        end

        local position = killerRoot.Position
            - facing * AutoStab.Settings.BehindDistance
        position = Vector3.new(position.X, killerRoot.Position.Y, position.Z)
        return CFrame.lookAt(
            position,
            Vector3.new(killerRoot.Position.X, position.Y, killerRoot.Position.Z)
        )
    end

    local function beginGuaranteedTeleport(target)
        if AutoStab.Destroyed
            or not AutoStab.Settings.Guaranteed
            or not isAlive(target) then
            return nil
        end

        local localRoot = getRoot(LocalPlayer.Character)
        local correctedCFrame = getBehindCFrame(target)
        if not localRoot or not correctedCFrame then
            return nil
        end

        sendCharacterPosition(correctedCFrame, Vector3.zero)
        return {
            Target = target,
            Corrected = true
        }
    end

    local function maintainAndRestoreTeleport(teleportData, activationTime)
        local deadline = os.clock() + AutoStab.Settings.CorrectionHold
        while not AutoStab.Destroyed
            and activationTime == AutoStab.LastActivation
            and os.clock() < deadline do
            local correctedCFrame = getBehindCFrame(teleportData.Target)
            if not correctedCFrame then
                break
            end
            sendCharacterPosition(correctedCFrame, Vector3.zero)
            RunService.Heartbeat:Wait()
        end

        if AutoStab.Destroyed or activationTime ~= AutoStab.LastActivation then
            return
        end
        local localRoot = getRoot(LocalPlayer.Character)
        if localRoot then
            sendCharacterPosition(localRoot.CFrame, localRoot.AssemblyLinearVelocity)
        end
    end

    local function activateDagger(actor, target)
        local now = os.clock()
        if now - AutoStab.LastActivation < 1 or not canUseDagger(actor) then
            return
        end

        AutoStab.LastActivation = now
        AutoStab.Attempts += 1

        local localRoot = getRoot(LocalPlayer.Character)
        local targetRoot = getRoot(target)
        if not localRoot or not targetRoot then
            return
        end
        local teleportData
        if AutoStab.Settings.Guaranteed then
            teleportData = beginGuaranteedTeleport(target)
            if teleportData and teleportData.Corrected then
                task.spawn(maintainAndRestoreTeleport, teleportData, now)
                task.wait(AutoStab.Settings.CorrectionTiming)
            else
                faceTarget(localRoot, targetRoot)
            end
        else
            faceTarget(localRoot, targetRoot)
        end

        Network:FireServerConnection("UseActorAbility", "REMOTE_EVENT", "Dagger")
    end

    local function updateAutoStab()
        if AutoStab.Destroyed or not AutoStab.Settings.Enabled then
            AutoStab.LastState = "Disabled"
            return
        end

        local actor = getTwoTimeActor()
        local localRoot = getRoot(LocalPlayer.Character)
        if not actor or not localRoot then
            AutoStab.LastState = "Waiting for Two Time"
            return
        end

        local target = findTarget(localRoot)
        if target then
            AutoStab.LastState = "Target acquired: " .. target.Name
            activateDagger(actor, target)
        else
            AutoStab.LastState = "Waiting for target in range"
        end
    end

    local Groupbox = AddonsTab:AddRightGroupbox("Two Time Auto Backstab")
    AutoStab.Groupbox = Groupbox

    local enabledToggle = Groupbox:AddToggle("FartHubTwoTimeAutoBackstab", {
        Text = "Auto Backstab",
        Default = AutoStab.Settings.Enabled,
        Callback = function(value)
            AutoStab.Settings.Enabled = value
        end
    })
    table.insert(AutoStab.Controls, enabledToggle)

    local modeDropdown = Groupbox:AddDropdown("FartHubTwoTimeBackstabMode", {
        Text = "Activation Mode",
        Values = { "Around", "Behind" },
        Default = AutoStab.Settings.Mode,
        Multi = false,
        Callback = function(value)
            AutoStab.Settings.Mode = value
        end
    })
    table.insert(AutoStab.Controls, modeDropdown)

    local rangeSlider = Groupbox:AddSlider("FartHubTwoTimeBackstabRange", {
        Text = "Backstab Range",
        Default = AutoStab.Settings.Range,
        Min = 1,
        Max = 20,
        Rounding = 1,
        Suffix = " studs",
        Callback = function(value)
            AutoStab.Settings.Range = value
        end
    })
    table.insert(AutoStab.Controls, rangeSlider)

    local guaranteedToggle = Groupbox:AddToggle("FartHubTwoTimeGuaranteedStab", {
        Text = "Guaranteed Stab (Hitbox TP)",
        Default = AutoStab.Settings.Guaranteed,
        Callback = function(value)
            AutoStab.Settings.Guaranteed = value
        end
    })
    table.insert(AutoStab.Controls, guaranteedToggle)

    local correctionSlider = Groupbox:AddSlider(
        "FartHubTwoTimeCorrectionDistance",
        {
            Text = "Behind Offset",
            Default = AutoStab.Settings.BehindDistance,
            Min = 1.5,
            Max = 5,
            Rounding = 2,
            Suffix = " studs",
            Callback = function(value)
                AutoStab.Settings.BehindDistance = value
            end
        }
    )
    table.insert(AutoStab.Controls, correctionSlider)

    local timingSlider = Groupbox:AddSlider("FartHubTwoTimeCorrectionTiming", {
        Text = "Correction Timing",
        Default = AutoStab.Settings.CorrectionTiming,
        Min = 0,
        Max = 0.12,
        Rounding = 2,
        Suffix = "s",
        Callback = function(value)
            AutoStab.Settings.CorrectionTiming = value
        end
    })
    table.insert(AutoStab.Controls, timingSlider)

    Groupbox:AddLabel(
        "Guaranteed mode holds your server hitbox behind the killer through Dagger startup, then restores it to your real client position.",
        true
    )

    table.insert(
        AutoStab.Connections,
        RunService.Heartbeat:Connect(updateAutoStab)
    )

    function AutoStab:Destroy()
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

    Library:OnUnload(function()
        AutoStab:Destroy()
    end)

end

local function setupRoleAwareStaminaTracker()
    local Groupbox = Tabs.ESP:AddRightGroupbox("Stamina Tracking")
    -- State-aware stamina v4 is embedded directly in fsknallinone.
    local EMBEDDED_STAMINA_SOURCE = [====[
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local StatsService = game:GetService("Stats")
local LocalPlayer = Players.LocalPlayer
local Actors = require(ReplicatedStorage.Modules.Gameplay.Actors)
local Env = getgenv and getgenv() or _G
local KEY = "__ForsakenStaminaTrackerV2"

for _, oldKey in ipairs({"__ForsakenKillerStaminaV1", KEY}) do
    local old = Env[oldKey]
    if type(old) == "table" and type(old.Destroy) == "function" then pcall(old.Destroy, old) end
end

local App = {Connections = {}, Trackers = {}, Destroyed = false, Role = "Unknown", PingSeconds = 0.08, LastPingRead = 0}
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
    -- Prefer the live actor's Config table. This is the game's current runtime
    -- data and correctly handles skins/forms whose model name does not match
    -- an Assets folder. Asset modules are fallback only.
    local liveConfig
    for _, actor in pairs(Actors.CurrentActors) do
        if actor.Rig == model and type(actor.Config) == "table" then
            liveConfig = actor.Config
            break
        end
    end
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local folder = assets and assets:FindFirstChild(actorType .. "s")
    folder = folder and (folder:FindFirstChild(name) or folder:FindFirstChild(model.Name))
    local configModule = folder and folder:FindFirstChild("Config")
    if liveConfig or (configModule and configModule:IsA("ModuleScript")) then
        local ok, config = true, liveConfig
        if not config then ok, config = pcall(require, configModule) end
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
                RunAnimationIds = {},
                AnimationNamesById = {},
            }
            for animationName, animationId in pairs(config.Animations or {}) do
                local lower = string.lower(tostring(animationName))
                if lower == "run" or lower == "injuredrun" then
                    local id = tostring(animationId):match("%d+")
                    if id then defaults.RunAnimationIds[id] = true end
                end
                local anyId = tostring(animationId):match("%d+")
                if anyId then defaults.AnimationNamesById[anyId] = lower end
            end
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
        ActiveAnimations = {}, LastSpecialAnimation = nil,
        LastSprintEvidence = 0,
        NearestDistance = math.huge, PathDistance = math.huge, LastGateScan = 0,
        Gui = gui, Fill = fill, Label = label, Detail = detail,
    }
end

local function actorStateFor(model)
    for _, actor in pairs(Actors.CurrentActors) do
        if actor.Rig == model then return actor.State, actor end
    end
end

local function truthyState(state, ...)
    if type(state) ~= "table" then return false end
    for i = 1, select("#", ...) do
        if state[select(i, ...)] == true then return true end
    end
    return false
end

-- Returns the effective rates used by the live character behaviours. These are
-- not wiki guesses: Guest Charge writes both rates to zero, Veeronica Sk8
-- writes gain=0 and multiplies loss, Nosferatu Flight writes gain=0, and 1x's
-- three AbilityStaminaOverride moves run their own StaminaGain heartbeat.
local function stateRates(t, actor, state, model)
    local name = t.Name:lower()
    local loss, gain = t.Stats.Loss, t.Stats.Gain
    local mode, frozen, customRegen = nil, false, false
    local anim = t.ActiveAnimations or {}
    local function playing(...)
        for i = 1, select("#", ...) do
            local wanted = string.lower(select(i, ...))
            for active in pairs(anim) do
                if active == wanted or active:find(wanted, 1, true) then return true end
            end
        end
        return false
    end

    if name:find("guest", 1, true) and (truthyState(state, "Charging", "isCharging", "InCharge", "isBlockingCharge")
        or playing("charge")) then
        frozen, mode = true, "CHARGE • FROZEN"
    elseif name:find("veeronica", 1, true) and (truthyState(state, "isSkating", "Skating")
        or playing("sk8", "skate", "trick")) then
        local cfg = actor and actor.Config or {}
        local mult = state and state.InZone and tonumber(cfg.Sk8StaminaLoss)
            or tonumber(cfg.Sk8StaminaLossOut)
            or 1.1
        loss, gain, mode = loss * mult, 0, "SK8 • " .. string.format("%.2fx", mult)
    elseif name:find("nosferatu", 1, true) and (truthyState(state, "InFlight", "isFlying")
        or playing("flight", "fly", "ascent", "descent")) then
        gain, mode = 0, "FLIGHT • NO REGEN"
    elseif name:find("azure", 1, true) and (truthyState(state,
        "StaminaFrozen", "isStaminaFrozen", "DoingRitual", "isTransforming", "InTransformation")
        or playing("ritual", "transform")) then
        frozen, mode = true, "ABILITY • FROZEN"
    elseif name:find("noli", 1, true) and (model:GetAttribute("VoidRushState") == "Charging"
        or (state and state.VoidRushState == "Charging") or playing("voidrushcharge", "void rush charge")) then
        frozen, mode = true, "VOID RUSH • CAPPED"
    end

    if model:GetAttribute("AbilityStaminaOverride") == true then
        if name:find("1x1x1x1", 1, true) then
            -- Mass Infection, Entanglement and Unstable Eye all replace normal
            -- regeneration with Config.StaminaGain * 1 after their short windup.
            customRegen, mode = true, "ABILITY REGEN"
        elseif not frozen then
            gain, mode = 0, mode or "ABILITY • NO REGEN"
        end
    end

    -- Exhausted's live StatusEffect mutates both config rates by 10% per level.
    local exhausted = tonumber(model:GetAttribute("ExhaustedLevel") or model:GetAttribute("Exhausted"))
    if exhausted and exhausted > 0 then
        loss *= 1 + 0.1 * exhausted
        gain *= math.max(0, 1 - 0.1 * exhausted)
        mode = (mode and mode .. " • " or "") .. "EXHAUSTED " .. exhausted
    end
    return loss, gain, frozen, customRegen, mode
end

local function sprintState(tracker, humanoid, actorState, now)
    -- Animation-track enumeration is relatively expensive, so sample at 10 Hz.
    if now - tracker.LastAnimCheck >= 0.1 then
        tracker.LastAnimCheck = now
        tracker.SprintAnimation = false
        tracker.EnragedAnimation = false
        table.clear(tracker.ActiveAnimations)
        local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                local name = string.lower(track.Name)
                local animationId = track.Animation and tostring(track.Animation.AnimationId):match("%d+")
                local configuredName = animationId and tracker.Stats.AnimationNamesById
                    and tracker.Stats.AnimationNamesById[animationId]
                if track.WeightCurrent > 0.15 and configuredName then
                    tracker.ActiveAnimations[configuredName] = true
                end
                if track.WeightCurrent > 0.15 and (name:find("enraged", 1, true)
                    or (configuredName and (configuredName:find("enraged", 1, true)
                        or configuredName:find("raging", 1, true)))) then
                    tracker.EnragedAnimation = true
                end
                if track.WeightCurrent > 0.15
                    and (name:find("sprint", 1, true) or name:find("run", 1, true)
                        or (animationId and tracker.Stats.RunAnimationIds
                            and tracker.Stats.RunAnimationIds[animationId])) then
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
    if now - App.LastPingRead >= 1 then
        App.LastPingRead = now
        pcall(function()
            App.PingSeconds = math.clamp(StatsService.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000, 0.02, 1.5)
        end)
    end
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
            local velocity = root.AssemblyLinearVelocity
            rawSpeed = math.max(rawSpeed, Vector3.new(velocity.X, 0, velocity.Z).Magnitude)
            t.LastPosition = position
            t.SmoothedSpeed += (rawSpeed - t.SmoothedSpeed) * math.clamp(dt * 12, 0, 1)
            local state, actor = actorStateFor(model)
            -- Refresh animation evidence before reading EnragedAnimation. The
            -- old order used the previous 0.1s sample and could drain one or
            -- more frames when Raging Pace began.
            local detectedSprint = sprintState(t, humanoidOf(model), state, now)
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
            local sprinting = not enraged and detectedSprint
            if sprinting then
                t.LastSprintEvidence = now
            elseif t.SprintAnimation then
                -- During a replication stall position remains frozen even
                -- though the remote run animation keeps playing. Preserve the
                -- last verified sprint for a ping-scaled grace window instead
                -- of falsely starting regeneration.
                local grace = math.clamp(App.PingSeconds * 2.25 + 0.12, 0.2, 1.5)
                sprinting = now - t.LastSprintEvidence <= grace
            end
            local effectiveLoss, effectiveGain, frozen, customRegen, specialMode = stateRates(t, actor, state, model)
            local draining = sprinting and t.DrainAllowed and not frozen
            if draining then
                t.Estimate = math.max(0, t.Estimate - effectiveLoss * dt)
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
            local penalty = model:GetAttribute("StaminaPenaltyActive") == true
            if not frozen and not draining and t.RecoveryDelay <= 0 and not penalty
                and (not staminaOverride or customRegen) then
                t.Estimate = math.min(staminaCap, t.Estimate + effectiveGain * dt)
            end
            t.WasSprinting = draining
            -- Raging Pace only assigns Sprinting.StaminaCap. It does NOT write
            -- Sprinting.Stamina, and sprinting is disabled for the duration.
            -- Therefore lowering the cap must not lower the current estimate.
            if not enraged then
                t.Estimate = math.min(t.Estimate, staminaCap)
            end
            local ratio = math.clamp(t.Estimate / t.Stats.Max, 0, 1)
            t.Fill.Size = UDim2.fromScale(ratio, 1)
            t.Fill.BackgroundColor3 = Color3.fromHSV(ratio * 0.33, 0.78, 0.95)
            t.Label.Text = string.format("%s: %.1f / %.0f", t.Name, t.Estimate, t.Stats.Max)
            if t.Type == "Killer" then
                t.Detail.Text = enraged
                    and string.format("KILLER • RAGING PACE • CAP %.0f", staminaCap)
                    or string.format("KILLER • %s • %s%.1f/s", specialMode or
                        (sprinting and "SPRINT" or (t.RecoveryDelay > 0 and "RECOVERY WAIT" or "REGEN")),
                        draining and "-" or "+", draining and effectiveLoss or effectiveGain)
            else
                t.Detail.Text = string.format("SURVIVOR • %s • %s%.1f/s", specialMode or
                    (sprinting and "DRAIN" or (t.RecoveryDelay > 0 and "RECOVERY WAIT" or "REGEN")),
                    draining and "-" or "+", draining and effectiveLoss or effectiveGain)
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

    ]====]
    local trackerStatus = Groupbox:AddLabel("Status: Disabled")

    local function unloadTracker()
        local tracker = Environment.__ForsakenStaminaTrackerV2
        if type(tracker) == "table" and type(tracker.Destroy) == "function" then
            pcall(tracker.Destroy, tracker)
        end
        Environment.__ForsakenStaminaTrackerV2 = nil
    end

    Groupbox:AddToggle("ForsakenRoleAwareStamina", {
        Text = "Player stamina counters",
        Default = false,
        Tooltip = "State-aware: sprint animations, recovery delay, abilities and Raging Pace",
        Callback = function(enabled)
            unloadTracker()
            if not enabled then
                trackerStatus:SetText("Status: Disabled")
                return
            end

            trackerStatus:SetText("Status: Loading...")
            local ok, loadError = pcall(function()
                local source = EMBEDDED_STAMINA_SOURCE
                local chunk, compileError = loadstring(source, "=ForsakenStaminaTracker")
                assert(chunk, compileError)
                chunk()
                assert(type(Environment.__ForsakenStaminaTrackerV2) == "table", "tracker did not initialize")
            end)
            if ok then
                trackerStatus:SetText("Status: Active (state-aware v6)")
            else
                trackerStatus:SetText("Status: Failed")
                warn("[Forsaken Suite] Stamina tracker failed:", loadError)
            end
        end,
    })

    Library:OnUnload(unloadTracker)
end

local function setupStaminaChanger()
    local Groupbox = Tabs.Automation:AddRightGroupbox("Local Stamina Changer")
    local Sprinting = require(game:GetService("ReplicatedStorage").Systems.Character.Game.Sprinting)
    local RunService = game:GetService("RunService")
    local settings = {
        Enabled = false,
        MaxStamina = 100,
        MinStamina = 0,
        DrainMultiplier = 1,
        RegenMultiplier = 1,
        SprintSpeed = 26,
        NoDrain = false,
        InstantRecovery = false,
    }
    local original, connection

    local function capture()
        original = {
            MaxStamina = Sprinting.MaxStamina,
            MinStamina = Sprinting.MinStamina,
            StaminaLoss = Sprinting.StaminaLoss,
            StaminaGain = Sprinting.StaminaGain,
            SprintSpeed = Sprinting.SprintSpeed,
            StaminaLossDisabled = Sprinting.StaminaLossDisabled,
        }
    end
    local function restore()
        if not original then return end
        for key, value in pairs(original) do Sprinting[key] = value end
        if Sprinting.Stamina then
            Sprinting.Stamina = math.clamp(Sprinting.Stamina, Sprinting.MinStamina, Sprinting.StaminaCap or Sprinting.MaxStamina)
            if Sprinting.__staminaChangedEvent then Sprinting.__staminaChangedEvent:Fire(Sprinting.Stamina) end
        end
        pcall(Sprinting.Resync, Sprinting)
    end
    local function apply()
        if not settings.Enabled or not Sprinting.DefaultsSet then return end
        if not original then capture() end
        Sprinting.MaxStamina = settings.MaxStamina
        Sprinting.MinStamina = math.min(settings.MinStamina, settings.MaxStamina)
        Sprinting.StaminaLoss = (original.StaminaLoss or 10) * settings.DrainMultiplier
        Sprinting.StaminaGain = (original.StaminaGain or 20) * settings.RegenMultiplier
        Sprinting.SprintSpeed = settings.SprintSpeed
        Sprinting.StaminaLossDisabled = settings.NoDrain
        if settings.InstantRecovery and not Sprinting.IsSprinting then
            Sprinting.timeUntilStaminaRecovers = 0
        end
        if Sprinting.Stamina then
            Sprinting.Stamina = math.clamp(Sprinting.Stamina, Sprinting.MinStamina, Sprinting.StaminaCap or Sprinting.MaxStamina)
        end
    end

    Groupbox:AddToggle("ForsakenStaminaChanger", {Text="Enable stamina changer", Default=false, Callback=function(v)
        if v and not settings.Enabled then capture() end
        settings.Enabled=v
        if v then apply() else restore();original=nil end
    end})
    Groupbox:AddSlider("ForsakenStaminaMax", {Text="Maximum stamina",Default=100,Min=1,Max=500,Rounding=0,Callback=function(v)settings.MaxStamina=v end})
    Groupbox:AddSlider("ForsakenStaminaMin", {Text="Minimum stamina",Default=0,Min=0,Max=100,Rounding=0,Callback=function(v)settings.MinStamina=v end})
    Groupbox:AddSlider("ForsakenStaminaDrain", {Text="Drain multiplier",Default=1,Min=0,Max=3,Rounding=2,Callback=function(v)settings.DrainMultiplier=v end})
    Groupbox:AddSlider("ForsakenStaminaRegen", {Text="Regen multiplier",Default=1,Min=0,Max=5,Rounding=2,Callback=function(v)settings.RegenMultiplier=v end})
    Groupbox:AddSlider("ForsakenSprintSpeed", {Text="Sprint speed",Default=26,Min=16,Max=40,Rounding=1,Callback=function(v)settings.SprintSpeed=v end})
    Groupbox:AddToggle("ForsakenStaminaNoDrain", {Text="Disable stamina drain",Default=false,Callback=function(v)settings.NoDrain=v end})
    Groupbox:AddToggle("ForsakenStaminaInstantRecovery", {Text="Remove recovery delay",Default=false,Callback=function(v)settings.InstantRecovery=v end})
    Groupbox:AddLabel("Changes only your local Sprinting controller and restores every original value when disabled.", true)

    connection=RunService.Heartbeat:Connect(function()
        if settings.Enabled then
            if Sprinting.DefaultsSet and original and Sprinting.MaxStamina ~= settings.MaxStamina then
                -- Init or an ability rewrote the controller. Refresh its genuine defaults.
                capture()
            end
            apply()
        end
    end)
    local function cleanup() settings.Enabled=false;restore();if connection then connection:Disconnect()end end
    if type(Library.OnUnload)=="function"then Library:OnUnload(cleanup)end
    Environment.__ForsakenStaminaChanger={Settings=settings,Destroy=cleanup,Sprinting=Sprinting}
end

local addonPaths = {
    "FartHub/Addons/nosbloodhook.lua",
    "FartHub/Addons/fartfix.lua",
    "FartHub/Addons/farthubautogen.lua",
    "FartHub/Addons/farthubsilentaim.lua",
    "FartHub/Addons/farthubazure.lua",
    "FartHub/Addons/farthubesp.lua"
}

local loadResults = {}
Environment.Library = Library
local addonSources = {}
for _, path in ipairs(addonPaths) do
    local fileName = path:match("[^\\/]+$") or path
    local addonUrl = "https://raw.githubusercontent.com/Au0yyyx/Community/main/"
        .. fileName .. "?t=" .. tostring(os.clock())
    if fileName == "farthubsilentaim.lua" then
        addonUrl = "https://cdn.jsdelivr.net/gh/Au0yyyx/Community@bd0fb176854b931a92a9e14e789c694c367b0674/farthubsilentaim.lua"
    end
    local ok, source = pcall(function()
        return httpGet(addonUrl)
    end)
    addonSources[fileName] = ok and source or nil
end
for _, path in ipairs(addonPaths) do
    local fileName = path:match("[^\\/]+$") or path
    local ok, loadError = pcall(function()
        local source = addonSources[fileName]
        assert(type(source) == "string", "addon source was unavailable")
        source = source:gsub(
            "local Library = findFartHubLibrary%(30%)",
            "local Library = (getgenv and getgenv() or _G).Library"
        )
        local chunk, compileError = loadstring(source, "=" .. fileName)
        assert(chunk, compileError)
        chunk()
    end)
    loadResults[#loadResults + 1] = {
        Name = fileName,
        Ok = ok,
        Error = loadError
    }
end

local autoStabOk, autoStabError = pcall(loadTwoTimeAutoBackstab)
loadResults[#loadResults + 1] = {
    Name = "Two Time Auto Backstab (integrated)",
    Ok = autoStabOk,
    Error = autoStabError
}
local staminaOk, staminaError = pcall(setupRoleAwareStaminaTracker)
loadResults[#loadResults + 1] = {
    Name = "Role-aware stamina tracker (integrated)",
    Ok = staminaOk,
    Error = staminaError
}
local staminaChangerOk, staminaChangerError = pcall(setupStaminaChanger)
loadResults[#loadResults + 1] = {
    Name = "Local stamina changer (integrated)",
    Ok = staminaChangerOk,
    Error = staminaChangerError
}
Environment.Library = originalLibrary

local status = Tabs.Settings:AddLeftGroupbox("Addon Status")
local loadedCount = 0
for _, result in ipairs(loadResults) do
    if result.Ok then
        loadedCount += 1
        status:AddLabel("[LOADED] " .. result.Name)
    else
        status:AddLabel("[FAILED] " .. result.Name .. "\n" .. tostring(result.Error), true)
        warn("[Forsaken Suite] Failed to load", result.Name, result.Error)
    end
end

local interface = Tabs.Settings:AddRightGroupbox("Interface")
interface:AddLabel("All features are routed into this Obsidian window.", true)
interface:AddButton("Unload Suite", function()
    Controller:Destroy()
end)

local saveManager
local saveOk, saveError = pcall(function()
    saveManager = loadstring(httpGet(repo .. "addons/SaveManager.lua"))()
    saveManager:SetLibrary(Library)
    saveManager:IgnoreThemeSettings()
    saveManager:SetFolder("ForsakenObsidianSuite")
    saveManager:BuildConfigSection(Tabs.Settings)
    saveManager:LoadAutoloadConfig()
end)
if not saveOk then
    status:AddLabel("[FAILED] SaveManager\n" .. tostring(saveError), true)
end

function Controller:Destroy()
    if self.Destroyed then
        return
    end
    self.Destroyed = true

    for _, key in ipairs(self.FeatureKeys) do
        local feature = Environment[key]
        if type(feature) == "table" and type(feature.Destroy) == "function" then
            pcall(feature.Destroy, feature)
        end
    end
    if self.Library and type(self.Library.Unload) == "function" then
        pcall(self.Library.Unload, self.Library)
    end
    if Environment[GUI_KEY] == self then
        Environment[GUI_KEY] = nil
    end
end

Library:OnUnload(function()
    if not Controller.Destroyed then
        Controller:Destroy()
    end
end)


