if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Environment = getgenv and getgenv() or _G
local ADDON_KEY = "__FartHubNosferatuMinigameAddon"

local previous = Environment[ADDON_KEY]
if type(previous) == "table" and type(previous.Destroy) == "function" then
    pcall(previous.Destroy, previous)
end

local function findFartHub(timeout)
    local deadline = os.clock() + timeout
    repeat
        local direct = Environment.Library
        if type(direct) == "table"
            and type(direct.Tabs) == "table"
            and type(direct.Toggles) == "table"
            and type(direct.Options) == "table"
            and direct.Tabs.Addons then
            return direct, direct.Tabs.Addons
        end

        for _, candidate in ipairs(getgc(true)) do
            if type(candidate) == "table"
                and type(rawget(candidate, "Tabs")) == "table"
                and type(rawget(candidate, "Toggles")) == "table"
                and type(rawget(candidate, "Options")) == "table"
                and candidate.Tabs.Addons then
                return candidate, candidate.Tabs.Addons
            end
        end
        task.wait(0.1)
    until os.clock() >= deadline
end

local Library, AddonsTab = findFartHub(30)
assert(Library and AddonsTab, "FartHub Addons tab was not found")

local Controller = {
    Connections = {},
    Controls = {},
    Candidates = setmetatable({}, { __mode = "k" }),
    Destroyed = false,
    PendingToken = 0,
    PendingInstance = nil,
    PendingKey = nil,
    LastInstance = nil,
    LastKey = nil,
    LastFingerprint = nil,
    Settings = {
        Enabled = false,
        InputDelay = 0.025
    }
}
Environment[ADDON_KEY] = Controller

local KEY_BY_NAME = {}
local KEY_BY_VALUE = {}
for _, keyCode in ipairs(Enum.KeyCode:GetEnumItems()) do
    KEY_BY_NAME[string.lower(keyCode.Name)] = keyCode
    KEY_BY_VALUE[keyCode.Value] = keyCode
end

local KEY_ALIASES = {
    ["spacebar"] = "Space",
    ["space"] = "Space",
    ["up"] = "Up",
    ["uparrow"] = "Up",
    ["arrowup"] = "Up",
    ["down"] = "Down",
    ["downarrow"] = "Down",
    ["arrowdown"] = "Down",
    ["left"] = "Left",
    ["leftarrow"] = "Left",
    ["arrowleft"] = "Left",
    ["right"] = "Right",
    ["rightarrow"] = "Right",
    ["arrowright"] = "Right",
    ["a_button"] = "ButtonA",
    ["abutton"] = "ButtonA",
    ["b_button"] = "ButtonB",
    ["bbutton"] = "ButtonB",
    ["x_button"] = "ButtonX",
    ["xbutton"] = "ButtonX",
    ["y_button"] = "ButtonY",
    ["ybutton"] = "ButtonY",
    ["l1"] = "ButtonL1",
    ["l2"] = "ButtonL2",
    ["l3"] = "ButtonL3",
    ["r1"] = "ButtonR1",
    ["r2"] = "ButtonR2",
    ["r3"] = "ButtonR3",
    ["dpadup"] = "DPadUp",
    ["dpaddown"] = "DPadDown",
    ["dpadleft"] = "DPadLeft",
    ["dpadright"] = "DPadRight"
}

local ATTRIBUTE_HINTS = {
    expectedkey = true,
    requiredkey = true,
    currentkey = true,
    promptkey = true,
    keycode = true,
    expectedinput = true,
    requiredinput = true,
    currentinput = true
}

local SCOPE_HINTS = {
    "nosferatu",
    "minigame",
    "qte",
    "quicktime",
    "skillcheck",
    "keyprompt",
    "inputprompt",
    "keysequence"
}

local function compact(value)
    return string.lower(tostring(value)):gsub("enum%.keycode%.", ""):gsub("[^%w_]", "")
end

local function toKeyCode(value)
    if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
        return value
    end
    if type(value) == "number" then
        return KEY_BY_VALUE[value]
    end
    if type(value) ~= "string" then
        return nil
    end

    local normalized = compact(value)
    local alias = KEY_ALIASES[normalized]
    if alias then
        normalized = string.lower(alias)
    end
    return KEY_BY_NAME[normalized]
end

local function keyFromText(text)
    if type(text) ~= "string" then
        return nil
    end

    local trimmed = text:match("^%s*(.-)%s*$")
    local function displayKey(value)
        local normalized = compact(value)
        local lastInputType = UserInputService:GetLastInputType()
        local usingGamepad = string.sub(lastInputType.Name, 1, 7) == "Gamepad"
        if usingGamepad and normalized:match("^[abxy]$") then
            return KEY_BY_NAME["button" .. normalized]
        end
        return toKeyCode(value)
    end

    if trimmed == utf8.char(0x2191) then
        return Enum.KeyCode.Up
    elseif trimmed == utf8.char(0x2193) then
        return Enum.KeyCode.Down
    elseif trimmed == utf8.char(0x2190) then
        return Enum.KeyCode.Left
    elseif trimmed == utf8.char(0x2192) then
        return Enum.KeyCode.Right
    end

    local direct = displayKey(trimmed)
    if direct then
        return direct
    end

    local token = trimmed:match("^[Pp][Rr][Ee][Ss][Ss]%s+[%[%(<]?([%w_]+)[%]%)>!%.]?")
        or trimmed:match("^[Hh][Ii][Tt]%s+[%[%(<]?([%w_]+)[%]%)>!%.]?")
        or trimmed:match("^[Tt][Aa][Pp]%s+[%[%(<]?([%w_]+)[%]%)>!%.]?")
        or trimmed:match("^%[([%w_]+)%]$")
        or trimmed:match("^%(([%w_]+)%)$")
    return token and displayKey(token) or nil
end

local function isVisible(instance)
    local current = instance
    while current and current ~= PlayerGui do
        if current:IsA("GuiObject") and not current.Visible then
            return false
        end
        if current:IsA("LayerCollector") and not current.Enabled then
            return false
        end
        current = current.Parent
    end
    return current == PlayerGui
end

local function isPromptScope(instance)
    local current = instance
    while current and current ~= PlayerGui do
        local name = compact(current.Name)
        if name:find("generator", 1, true) or name:find("flowgame", 1, true) then
            return false
        end
        for _, hint in ipairs(SCOPE_HINTS) do
            if name:find(hint, 1, true) then return true end
        end
        if current:IsA("TextLabel") and compact(current.Text):find("reelitin", 1, true) then return true end
        current = current.Parent
    end
    return false
end

local function fingerprint(instance, keyCode)
    local parts = { keyCode.Name, instance:GetFullName() }
    if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
        table.insert(parts, instance.Text)
    end
    for name, value in pairs(instance:GetAttributes()) do
        if ATTRIBUTE_HINTS[compact(name)] then
            table.insert(parts, tostring(name))
            table.insert(parts, tostring(value))
        end
    end
    return table.concat(parts, "|")
end

local function inspectInstance(instance)
    if not isVisible(instance) or not isPromptScope(instance) then
        return nil
    end

    for name, value in pairs(instance:GetAttributes()) do
        if ATTRIBUTE_HINTS[compact(name)] then
            local keyCode = toKeyCode(value)
            if keyCode then
                return keyCode
            end
        end
    end

    if instance:IsA("ValueBase") and ATTRIBUTE_HINTS[compact(instance.Name)] then
        local keyCode = toKeyCode(instance.Value)
        if keyCode then
            return keyCode
        end
    end

    if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
        return keyFromText(instance.Text)
    end

    return toKeyCode(instance.Name)
end

local function findPrompt()
    local temporary = PlayerGui:FindFirstChild("TemporaryUI")
    if temporary then
        for _, instance in ipairs(temporary:GetDescendants()) do
            if (instance:IsA("TextLabel") or instance:IsA("TextButton")) and isVisible(instance) then
                local keyCode = keyFromText(instance.Text)
                if keyCode and isPromptScope(instance) then
                    return instance, keyCode, fingerprint(instance, keyCode)
                end
            end
        end
    end
    for instance in pairs(Controller.Candidates) do
        if not instance.Parent then
            Controller.Candidates[instance] = nil
            continue
        end
        local keyCode = inspectInstance(instance)
        if keyCode then
            return instance, keyCode, fingerprint(instance, keyCode)
        end
    end
end

local function cacheCandidate(instance)
    if isPromptScope(instance) then
        Controller.Candidates[instance] = true
    end
end

for _, instance in ipairs(PlayerGui:GetDescendants()) do
    cacheCandidate(instance)
end

table.insert(Controller.Connections, PlayerGui.DescendantAdded:Connect(cacheCandidate))

local function cancelPending()
    Controller.PendingToken += 1
    Controller.PendingInstance = nil
    Controller.PendingKey = nil
end

local function pulseKey(keyCode)
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    if type(keypress) == "function" then pcall(keypress, keyCode.Value) end
    task.wait(0.045)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    if type(keyrelease) == "function" then pcall(keyrelease, keyCode.Value) end
end

local function scheduleInput(instance, keyCode, promptFingerprint)
    cancelPending()
    Controller.PendingInstance = instance
    Controller.PendingKey = keyCode
    local token = Controller.PendingToken

    task.delay(Controller.Settings.InputDelay, function()
        if Controller.Destroyed
            or not Controller.Settings.Enabled
            or token ~= Controller.PendingToken
            or Controller.PendingInstance ~= instance
            or Controller.PendingKey ~= keyCode
            or not instance.Parent
            or not isVisible(instance) then
            return
        end

        local currentKey = inspectInstance(instance)
        if currentKey ~= keyCode then
            return
        end

        Controller.LastInstance = instance
        Controller.LastKey = keyCode
        Controller.LastFingerprint = promptFingerprint
        Controller.PendingInstance = nil
        Controller.PendingKey = nil

        local succeeded, inputError = pcall(pulseKey, keyCode)
        if not succeeded then
            warn("[FartHub Nosferatu] Input failed:", inputError)
        end
    end)
end

local function update()
    if Controller.Destroyed or not Controller.Settings.Enabled then
        return
    end

    local instance, keyCode, promptFingerprint = findPrompt()
    if not instance then
        if Controller.PendingInstance then
            cancelPending()
        end
        Controller.LastInstance = nil
        Controller.LastKey = nil
        Controller.LastFingerprint = nil
        return
    end

    if instance == Controller.LastInstance
        and keyCode == Controller.LastKey
        and promptFingerprint == Controller.LastFingerprint then
        return
    end

    if instance ~= Controller.PendingInstance or keyCode ~= Controller.PendingKey then
        scheduleInput(instance, keyCode, promptFingerprint)
    end
end

local Groupbox = AddonsTab:AddRightGroupbox("Nosferatu Bloodhook QTE")
Controller.Groupbox = Groupbox

local enabledToggle = Groupbox:AddToggle("FartHubAutoNosferatuMinigame", {
    Text = "Auto Bloodhook QTE",
    Default = Controller.Settings.Enabled,
    Callback = function(value)
        Controller.Settings.Enabled = value
        cancelPending()
        Controller.LastInstance = nil
        Controller.LastKey = nil
        Controller.LastFingerprint = nil
    end
})
table.insert(Controller.Controls, enabledToggle)

local delaySlider = Groupbox:AddSlider("FartHubNosferatuInputDelay", {
    Text = "Input Delay",
    Default = Controller.Settings.InputDelay,
    Min = 0,
    Max = 2,
    Rounding = 3,
    Suffix = "s",
    Callback = function(value)
        Controller.Settings.InputDelay = value
        cancelPending()
    end
})
table.insert(Controller.Controls, delaySlider)

Groupbox:AddLabel("Presses each detected Nosferatu prompt once after the selected delay.", true)

table.insert(Controller.Connections, task.spawn(function()
    while not Controller.Destroyed do
        update()
        task.wait(0.03)
    end
end))

function Controller:Destroy()
    if self.Destroyed then
        return
    end
    self.Destroyed = true
    cancelPending()

    for _, connection in ipairs(self.Connections) do
        if typeof(connection) == "RBXScriptConnection" then
            pcall(connection.Disconnect, connection)
        elseif typeof(connection) == "thread" then
            pcall(task.cancel, connection)
        end
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

print("[FartHub Addon] Auto Nosferatu Minigame loaded")

