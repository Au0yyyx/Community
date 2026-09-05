if not game:IsLoaded() then
    game.Loaded:Wait()
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Environment = getgenv and getgenv() or _G
local ADDON_KEY = "__FartHubAutoGenAddon"

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
                and candidate.Tabs.Generators
                and candidate.Toggles["Auto Solve Generator Toggle"] then
                return candidate
            end
        end
        task.wait(0.1)
    until os.clock() >= deadline
end

local Library = findFartHubLibrary(30)
assert(Library, "Active FartHub generator tab was not found")

local FlowGameManager

local function getFlowGameManager()
    if FlowGameManager then
        return FlowGameManager
    end

    local succeeded, manager = pcall(
        require,
        ReplicatedStorage.Modules.Minigames.FlowGameManager
    )
    if succeeded then
        FlowGameManager = manager
    end
    return FlowGameManager
end

local Controller = {
    Connections = {},
    Controls = {},
    Destroyed = false,
    PendingToken = 0,
    PendingGame = nil,
    CompletedGames = setmetatable({}, { __mode = "k" }),
    Random = Random.new(),
    Settings = {
        Enabled = false,
        Delay = 2.5,
        Randomness = 0
    }
}
Environment[ADDON_KEY] = Controller

local function disableFartHubAutoGen()
    local oldToggle = Library.Toggles["Auto Solve Generator Toggle"]
    if oldToggle and oldToggle.Value == true then
        pcall(oldToggle.SetValue, oldToggle, false)
    end
end

local function cancelPending()
    Controller.PendingToken += 1
    Controller.PendingGame = nil
end

local function scheduleCompletion(activeGame)
    if Controller.PendingGame == activeGame
        or Controller.CompletedGames[activeGame] then
        return
    end

    cancelPending()
    Controller.PendingGame = activeGame
    local token = Controller.PendingToken
    local delayTime = Controller.Settings.Delay
        + Controller.Random:NextNumber(0, Controller.Settings.Randomness)

    task.delay(delayTime, function()
        local manager = getFlowGameManager()
        if Controller.Destroyed
            or not Controller.Settings.Enabled
            or token ~= Controller.PendingToken
            or Controller.PendingGame ~= activeGame
            or not manager
            or manager.activeGame ~= activeGame then
            return
        end

        Controller.PendingGame = nil
        if activeGame.gameEnded or not activeGame.completedEvent then
            return
        end

        Controller.CompletedGames[activeGame] = true
        local succeeded, completionError = pcall(
            activeGame.EndGame,
            activeGame,
            true
        )
        if not succeeded then
            Controller.CompletedGames[activeGame] = nil
            warn("[FartHub AutoGen] Completion failed:", completionError)
        end
    end)
end

local function update()
    if Controller.Destroyed then
        return
    end

    if not Controller.Settings.Enabled then
        if Controller.PendingGame then
            cancelPending()
        end
        return
    end

    disableFartHubAutoGen()
    local manager = getFlowGameManager()
    local activeGame = manager and manager.activeGame
    if not activeGame or activeGame.gameEnded then
        if Controller.PendingGame then
            cancelPending()
        end
        return
    end

    scheduleCompletion(activeGame)
end

local Groupbox = Library.Tabs.Generators:AddLeftGroupbox("AutoGen")
Controller.Groupbox = Groupbox

local enabledToggle = Groupbox:AddToggle("FartHubNewAutoGen", {
    Text = "AutoGen",
    Default = Controller.Settings.Enabled,
    Callback = function(value)
        Controller.Settings.Enabled = value
        if value then
            disableFartHubAutoGen()
        else
            cancelPending()
        end
    end
})
table.insert(Controller.Controls, enabledToggle)

local delaySlider = Groupbox:AddSlider("FartHubAutoGenDelay", {
    Text = "Auto Complete Delay",
    Default = Controller.Settings.Delay,
    Min = 0,
    Max = 10,
    Rounding = 2,
    Suffix = "s",
    Callback = function(value)
        Controller.Settings.Delay = value
        if Controller.PendingGame then
            local activeGame = Controller.PendingGame
            cancelPending()
            scheduleCompletion(activeGame)
        end
    end
})
table.insert(Controller.Controls, delaySlider)

local randomnessSlider = Groupbox:AddSlider("FartHubAutoGenRandomness", {
    Text = "Auto Complete Delay Randomness",
    Default = Controller.Settings.Randomness,
    Min = 0,
    Max = 10,
    Rounding = 2,
    Suffix = "s",
    Callback = function(value)
        Controller.Settings.Randomness = value
        if Controller.PendingGame then
            local activeGame = Controller.PendingGame
            cancelPending()
            scheduleCompletion(activeGame)
        end
    end
})
table.insert(Controller.Controls, randomnessSlider)

Groupbox:AddLabel(
    "Completion time = delay + a random value from 0 to the selected randomness.",
    true
)

table.insert(Controller.Connections, RunService.Heartbeat:Connect(update))

function Controller:Destroy()
    if self.Destroyed then
        return
    end
    self.Destroyed = true
    cancelPending()

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

if type(Library.OnUnload) == "function" then
    Library:OnUnload(function()
        Controller:Destroy()
    end)
end


