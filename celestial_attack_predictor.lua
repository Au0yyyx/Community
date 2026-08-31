if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Env = getgenv and getgenv() or _G
local KEY = "__CelestialAttackPredictorV1"

if type(Env[KEY]) == "table" and type(Env[KEY].Destroy) == "function" then
    Env[KEY]:Destroy()
end

local P1 = {
    low = {"FALL", "CRUMBLE"},
    mid = {"FUTILE", "CRUMBLE", "BITTER", "CEASE"},
    high = {"DEATH IN BLOOM", "FUTILE", "CEASE", "BITTER", "FUTILE", "CEASE", "BOOM"},
}
local P2 = {"NO ESCAPE", "FUTILE", "SUPER PIZZA CUTTER", "CEASE", "BITTER", "SILENCE", "FUTILE"}
local ATTACKS = {"DEATH IN BLOOM", "SUPER PIZZA CUTTER", "NO ESCAPE", "SILENCE", "FUTILE", "CRUMBLE", "BITTER", "CEASE", "BOOM", "FALL"}

local App = {Connections = {}, Phase = 1, Band = "low", Index = 1, LastSignal = 0, LastAttack = nil,
    ManualPhase = false, Destroyed = false, GiftPercent = 0}
Env[KEY] = App

local function connect(signal, fn)
    local c = signal:Connect(fn)
    App.Connections[#App.Connections + 1] = c
    return c
end

local function counterValue(counter, attribute)
    if not counter then return 0 end
    local a = counter:GetAttribute(attribute)
    if type(a) == "number" then return a end
    local child = counter:FindFirstChild(attribute)
    if child and child:IsA("ValueBase") then return tonumber(child.Value) or 0 end
    if attribute == "Collected" and counter:IsA("ValueBase") then return tonumber(counter.Value) or 0 end
    return 0
end

local function giftPercent()
    local folder = ReplicatedStorage:FindFirstChild("GiftCounters")
    local counter = folder and (folder:FindFirstChild("Gift") or folder:FindFirstChild("Normal"))
    local got, maximum = counterValue(counter, "Collected"), counterValue(counter, "MaxGifts")
    return maximum > 0 and math.clamp(math.floor(got / maximum * 100 + 0.5), 0, 100) or 0, got, maximum
end

local function sequence()
    if App.Phase == 2 then return P2 end
    return P1[App.Band]
end

local gui = Instance.new("ScreenGui")
gui.Name = "CelestialAttackPredictor"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.Parent = (gethui and gethui()) or CoreGui

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0)
frame.Position = UDim2.new(0.5, 0, 0, 42)
frame.Size = UDim2.fromOffset(410, 105)
frame.BackgroundColor3 = Color3.fromRGB(13, 9, 20)
frame.BackgroundTransparency = 0.08
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", frame)
stroke.Color = Color3.fromRGB(220, 80, 255)
stroke.Thickness = 2

local function label(y, size, color)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Position = UDim2.fromOffset(10, y)
    l.Size = UDim2.new(1, -20, 0, size + 6)
    l.Font = Enum.Font.GothamBold
    l.TextSize = size
    l.TextColor3 = color
    l.TextStrokeTransparency = 0.45
    l.TextXAlignment = Enum.TextXAlignment.Center
    l.Parent = frame
    return l
end

local phaseLabel = label(4, 13, Color3.fromRGB(205, 170, 255))
local currentLabel = label(25, 25, Color3.fromRGB(255, 100, 145))
local nextLabel = label(62, 18, Color3.fromRGB(245, 235, 255))
local helpLabel = label(87, 10, Color3.fromRGB(160, 150, 175))
helpLabel.Text = "←/→ resync   P switch phase   RightShift hide"

local function normalizeAttack(value)
    local upper = tostring(value or ""):upper():gsub("[%._%-]+", " "):gsub("%s+", " ")
    for _, attack in ipairs(ATTACKS) do
        if upper:find(attack, 1, true) then return attack end
    end
end

local function setAttack(attack, source)
    if not attack then return end
    local now = os.clock()
    if App.LastAttack == attack and now - App.LastSignal < 1.25 then return end
    local seq = sequence()
    local found
    for i, candidate in ipairs(seq) do
        if candidate == attack then
            -- Repeated FUTILE appears twice in the high/P2 patterns. Select the
            -- first matching occurrence after the current index when possible.
            local distance = (i - App.Index) % #seq
            if not found or distance < found.Distance then found = {Index = i, Distance = distance} end
        end
    end
    if found then App.Index = found.Index end
    App.LastAttack, App.LastSignal, App.LastSource = attack, now, source
end

local function inspect(value, source)
    local attack = normalizeAttack(value)
    if attack then setAttack(attack, source) end
end

local function watchInstance(inst)
    inspect(inst.Name, "instance")
    if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
        inspect(inst.Text, "dialogue")
        connect(inst:GetPropertyChangedSignal("Text"), function() inspect(inst.Text, "dialogue") end)
    elseif inst:IsA("StringValue") then
        inspect(inst.Value, "value")
        connect(inst.Changed, function(v) inspect(v, "value") end)
    end
end

for _, root in ipairs({Players.LocalPlayer:WaitForChild("PlayerGui"), workspace, ReplicatedStorage}) do
    for _, inst in ipairs(root:GetDescendants()) do
        if inst:IsA("GuiObject") or inst:IsA("StringValue") or normalizeAttack(inst.Name) then watchInstance(inst) end
    end
    connect(root.DescendantAdded, watchInstance)
end

local hidden = false
connect(UserInputService.InputBegan, function(input, processed)
    if processed then return end
    local seq = sequence()
    if input.KeyCode == Enum.KeyCode.Right then
        App.Index = App.Index % #seq + 1
        App.LastAttack = seq[App.Index]
    elseif input.KeyCode == Enum.KeyCode.Left then
        App.Index = (App.Index - 2) % #seq + 1
        App.LastAttack = seq[App.Index]
    elseif input.KeyCode == Enum.KeyCode.P then
        App.Phase = App.Phase == 1 and 2 or 1
        App.ManualPhase, App.Index, App.LastAttack = true, 1, nil
    elseif input.KeyCode == Enum.KeyCode.RightShift then
        hidden = not hidden
        frame.Visible = not hidden
    end
end)

local elapsed = 0
connect(RunService.Heartbeat, function(dt)
    elapsed += dt
    if elapsed < 0.1 then return end
    elapsed = 0
    local percent, got, maximum = giftPercent()
    App.GiftPercent = percent
    if not App.ManualPhase then App.Phase = percent >= 100 and 2 or 1 end
    if App.Phase == 1 then
        local band = percent < 20 and "low" or (percent < 66 and "mid" or "high")
        if band ~= App.Band then
            App.Band, App.Index, App.LastAttack = band, 1, nil
        end
    end

    -- Celestial exposes attack/state strings differently between updates.
    -- Read every replicated attribute and StringValue so the predictor follows
    -- the actual controller whenever those signals are available.
    local enemies = workspace:FindFirstChild("Enemies")
    if enemies then
        for _, enemy in ipairs(enemies:GetChildren()) do
            if enemy.Name:lower():find("celestial", 1, true) then
                for _, v in pairs(enemy:GetAttributes()) do inspect(v, "celestial attribute") end
                for _, d in ipairs(enemy:GetDescendants()) do
                    if d:IsA("StringValue") then inspect(d.Value, "celestial value") end
                end
            end
        end
    end

    local seq = sequence()
    App.Index = math.clamp(App.Index, 1, #seq)
    local current = App.LastAttack or seq[App.Index]
    local nextIndex = App.Index % #seq + 1
    phaseLabel.Text = string.format("PHASE %d  •  GIFTS %d/%d (%d%%)  •  %s", App.Phase, got, maximum, percent,
        App.LastSource and ("SYNC: " .. App.LastSource:upper()) or "PATTERN")
    currentLabel.Text = "CURRENT:  " .. current
    nextLabel.Text = "NEXT:  " .. seq[nextIndex]
end)

function App:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
    if gui then gui:Destroy() end
    if Env[KEY] == self then Env[KEY] = nil end
end

print("[Celestial Predictor] Loaded — Phase 1/2 pattern + live resync")

