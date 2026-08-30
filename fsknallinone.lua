if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Environment = getgenv and getgenv() or _G
local GUI_KEY = "__ForsakenObsidianSuite"

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
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
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
        "__ForsakenStaminaTrackerV2"
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

    print("[Forsaken Suite] Integrated Two Time Auto Backstab loaded")
end

local function setupRoleAwareStaminaTracker()
    local Groupbox = Tabs.ESP:AddRightGroupbox("Stamina Tracking")
    local SOURCE_URL = "https://raw.githubusercontent.com/Au0yyyx/Community/main/stamina.lua"
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
        Tooltip = "Survivor: killer stamina | Killer: survivor stamina | Spectator: both",
        Callback = function(enabled)
            unloadTracker()
            if not enabled then
                trackerStatus:SetText("Status: Disabled")
                return
            end

            trackerStatus:SetText("Status: Loading...")
            local ok, loadError = pcall(function()
                local source = game:HttpGet(SOURCE_URL .. "?t=" .. tostring(os.time()))
                local chunk, compileError = loadstring(source, "=ForsakenStaminaTracker")
                assert(chunk, compileError)
                chunk()
                assert(type(Environment.__ForsakenStaminaTrackerV2) == "table", "tracker did not initialize")
            end)
            if ok then
                trackerStatus:SetText("Status: Active (role-aware)")
            else
                trackerStatus:SetText("Status: Failed")
                warn("[Forsaken Suite] Stamina tracker failed:", loadError)
            end
        end,
    })

    Library:OnUnload(unloadTracker)
end

local addonPaths = {
    "FartHub/Addons/fartfix.lua",
    "FartHub/Addons/nosbloodhook.lua",
    "FartHub/Addons/farthubautogen.lua",
    "FartHub/Addons/farthubsilentaim.lua",
    "FartHub/Addons/farthubazure.lua",
    "FartHub/Addons/farthubesp.lua"
}

local loadResults = {}
Environment.Library = Library
for _, path in ipairs(addonPaths) do
    local fileName = path:match("[^\\/]+$") or path
    local ok, loadError = pcall(function()
        local source = readfile(path)
        assert(type(source) == "string", "readfile returned no source")
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
    saveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
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

print(("[Forsaken Suite] Obsidian GUI loaded %d/%d addons"):format(loadedCount, #loadResults))

