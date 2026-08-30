-- BedWars AutoBank v5
-- Fixes:
-- 1. Drops now scatter to unique sky positions so the server doesn't merge them.
-- 2. UI is completely dynamic and recalculates from physical drops (no more lying/desync).
-- 3. Inventory replication guard replaced isAlreadyBanked to allow picking up more items.

local ClientStore, Remotes, GetItemMeta
for _, mod in ipairs(getloadedmodules and getloadedmodules() or {}) do
    if mod.Name == "store" and mod.Parent and mod.Parent.Name == "ui" then
        ClientStore = require(mod).ClientStore
    elseif mod.Name == "remotes" and mod.Parent and mod.Parent.Name == "TS" then
        Remotes = require(mod).default
    elseif mod.Name == "item-meta" and mod.Parent and mod.Parent.Name == "item" then
        GetItemMeta = require(mod).getItemMeta
    end
end

if not ClientStore then ClientStore = require(game.Players.LocalPlayer.PlayerScripts.TS.ui.store).ClientStore end
if not Remotes then Remotes = require(game.ReplicatedStorage.TS.remotes).default end
if not GetItemMeta then GetItemMeta = require(game.ReplicatedStorage.TS.item["item-meta"]).getItemMeta end

do
    local old = getgenv().BedwarsAutoBank
    if type(old) == "table" and type(old.Destroy) == "function" then
        -- Never restore poisoned/non-finite stacks from an older build.
        for drop,data in pairs(old.Drops or {}) do
            local amount=tonumber(data.Amount)
            if not amount or amount~=amount or amount==math.huge or amount==-math.huge then
                old.Drops[drop]=nil
                pcall(function() drop:Destroy() end)
            end
        end
        pcall(old.Destroy, old)
    end
    local guiParent
    pcall(function() guiParent = (gethui and gethui()) or game:GetService("CoreGui") end)
    guiParent = guiParent or game.Players.LocalPlayer:WaitForChild("PlayerGui")
    local oldGui = guiParent:FindFirstChild("BedwarsAutoBankHUD")
    if oldGui then oldGui:Destroy() end
end

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local UIS               = game:GetService("UserInputService")
local LocalPlayer       = Players.LocalPlayer

local DropRemote  = Remotes.Client:Get("DropItem")
local PickupRemote = Remotes.Client:Get("PickupItemDrop")

local Bank = {
    Enabled       = true,
    DepositDelay  = 3.0, 
    ReturnRadius  = 17,
    Drops         = {},
    ItemAges      = {},
    LastDropTime  = {},
    Connections   = {},
    Busy          = false,
    Pending       = {},
    Destroyed     = false,
    ResourceNames = { iron = true, diamond = true, emerald = true, gold = true },
}
-- Inventory Tool instances are replaced frequently; weak keys prevent stale
-- tools from accumulating forever across pickups/respawns.
Bank.ItemAges = setmetatable({}, { __mode = "k" })
Bank.LastDropTime = setmetatable({}, { __mode = "k" })
getgenv().BedwarsAutoBank = Bank

local iconCache = {}
local function getIcon(name)
    if iconCache[name] then return iconCache[name] end
    local ok, meta = pcall(GetItemMeta, name)
    local img = (ok and type(meta) == "table" and meta.image) or ""
    iconCache[name] = img
    return img
end

local function neutralize(inst, saved)
    local function kill(p)
        if p:IsA("BasePart") then
            saved[p] = saved[p] or {p.Anchored,p.CanCollide,p.CanTouch,p.Transparency}
            -- Anchoring locally prevents physics ownership updates from
            -- reaching the server and creates ghost, unpickable drops.
            p.Anchored = false
            p.CanCollide = false
            p.CanTouch = true
            p.Transparency = 1
            p.AssemblyLinearVelocity = Vector3.zero
            p.AssemblyAngularVelocity = Vector3.zero
        elseif p:IsA("Decal") or p:IsA("Texture") then
            saved[p] = saved[p] or {p.Transparency}
            p.Transparency = 1
        elseif p:IsA("ParticleEmitter") or p:IsA("Trail") or p:IsA("Beam") then
            saved[p] = saved[p] or {p.Enabled}
            p.Enabled = false
        elseif p:IsA("BillboardGui") or p:IsA("SurfaceGui") then
            saved[p] = saved[p] or {p.Enabled}
            p.Enabled = false
        elseif p:IsA("Light") then
            saved[p] = saved[p] or {p.Enabled}
            p.Enabled = false
        end
    end
    if inst:IsA("Model") then
        for _, d in inst:GetDescendants() do kill(d) end
    end
    kill(inst)
end

local function moveTo(inst, pos)
    if not inst or not inst.Parent then return end
    local data = Bank.Drops[inst]
    data.Saved = data.Saved or {}
    neutralize(inst, data.Saved)
    if inst:IsA("Model") then
        inst:PivotTo(CFrame.new(pos))
    else
        local p = inst:IsA("BasePart") and inst or inst:FindFirstChildWhichIsA("BasePart", true)
        if p then p.CFrame = CFrame.new(pos) end
    end
end

local function getSafeGuiParent()
    local ok, res = pcall(function() return gethui and gethui() end)
    if ok and res then return res end
    ok, res = pcall(function() return game:GetService("CoreGui") end)
    if ok and res then return res end
    return game.Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- ── UI ──────────────────────────────────────────────────────────────────────
local guiParent = getSafeGuiParent()
local gui = Instance.new("ScreenGui")
gui.Name           = "BedwarsAutoBankHUD"
gui.ResetOnSpawn   = false
gui.DisplayOrder   = 15
gui.Enabled        = true
gui.Parent         = guiParent

local frame = Instance.new("Frame", gui)
frame.AnchorPoint = Vector2.new(0.5, 1)
frame.Position    = UDim2.new(0.5, 0, 0.95, -20)
frame.Size        = UDim2.fromOffset(200, 36)
frame.BackgroundColor3 = Color3.fromRGB(20, 22, 27)
frame.BackgroundTransparency = 0.22
frame.BorderSizePixel = 0
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 7)

local timerLabel = Instance.new("TextLabel", gui)
timerLabel.BackgroundTransparency = 1
timerLabel.AnchorPoint = Vector2.new(0.5, 1)
timerLabel.Position    = UDim2.new(0.5, 0, 0.95, -60)
timerLabel.Size        = UDim2.fromOffset(200, 18)
timerLabel.Font        = Enum.Font.GothamBold
timerLabel.TextSize    = 11
timerLabel.TextColor3  = Color3.fromRGB(210, 220, 235)
timerLabel.TextStrokeTransparency = 0.3
timerLabel.Text        = "AUTOBANK RUNNING"

local layout = Instance.new("UIListLayout", frame)
layout.FillDirection       = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment   = Enum.VerticalAlignment.Center
layout.Padding             = UDim.new(0, 4)

local slots = {}
for _, rn in ipairs({"emerald", "diamond", "iron", "gold"}) do
    local s = Instance.new("Frame", frame)
    s.Name = rn
    s.Size = UDim2.fromOffset(42, 30)
    s.BackgroundColor3 = Color3.fromRGB(55, 58, 66)
    s.BackgroundTransparency = 0.15
    s.BorderSizePixel = 0
    Instance.new("UICorner", s).CornerRadius = UDim.new(0, 4)

    local ic = Instance.new("ImageLabel", s)
    ic.BackgroundTransparency = 1
    ic.Position = UDim2.fromOffset(2, 2)
    ic.Size = UDim2.fromOffset(26, 26)
    ic.ScaleType = Enum.ScaleType.Fit
    ic.Image = getIcon(rn)

    local ct = Instance.new("TextLabel", s)
    ct.BackgroundTransparency = 1
    ct.AnchorPoint = Vector2.new(1, 1)
    ct.Position = UDim2.new(1, -2, 1, -2)
    ct.Size = UDim2.fromOffset(26, 16)
    ct.Font = Enum.Font.GothamBold
    ct.TextSize = 11
    ct.TextColor3 = Color3.new(1, 1, 1)
    ct.TextStrokeTransparency = 0.15
    ct.Text = "0"

    slots[rn] = { Count = ct }
end

local panel = Instance.new("Frame", gui)
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -20, 0.5, 0)
panel.Size = UDim2.fromOffset(210, 115)
panel.BackgroundColor3 = Color3.fromRGB(18, 20, 25)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Visible = true
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

local ptt = Instance.new("TextLabel", panel)
ptt.BackgroundTransparency = 1
ptt.Size = UDim2.new(1, 0, 0, 30)
ptt.Font = Enum.Font.GothamBold
ptt.TextSize = 14
ptt.TextColor3 = Color3.new(1, 1, 1)
ptt.Text = "AutoBank Settings"

local toggleBtn = Instance.new("TextButton", panel)
toggleBtn.Position = UDim2.fromOffset(10, 34)
toggleBtn.Size = UDim2.fromOffset(90, 28)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 12
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.BorderSizePixel = 0

local delayBox = Instance.new("TextBox", panel)
delayBox.Position = UDim2.fromOffset(110, 34)
delayBox.Size = UDim2.fromOffset(90, 28)
delayBox.BackgroundColor3 = Color3.fromRGB(45, 48, 57)
delayBox.BorderSizePixel = 0
delayBox.ClearTextOnFocus = false
delayBox.Font = Enum.Font.GothamBold
delayBox.TextSize = 12
delayBox.TextColor3 = Color3.new(1, 1, 1)
delayBox.Text = tostring(Bank.DepositDelay)

local hn = Instance.new("TextLabel", panel)
hn.BackgroundTransparency = 1
hn.Position = UDim2.fromOffset(8, 70)
hn.Size = UDim2.fromOffset(194, 40)
hn.Font = Enum.Font.Gotham
hn.TextSize = 11
hn.TextWrapped = true
hn.TextColor3 = Color3.fromRGB(180, 185, 198)
hn.Text = "Bank Delay (Seconds)\nWait time before banking items.\nRightShift = Toggle UI"

local returnDrops
local isNear

local function paintToggle()
    toggleBtn.Text = Bank.Enabled and "ENABLED" or "DISABLED"
    toggleBtn.BackgroundColor3 = Bank.Enabled and Color3.fromRGB(40, 165, 92) or Color3.fromRGB(165, 55, 55)
    timerLabel.Text = Bank.Enabled and "AUTOBANK RUNNING" or "AUTOBANK PAUSED"
end
paintToggle()

toggleBtn.MouseButton1Click:Connect(function()
    Bank.Enabled = not Bank.Enabled
    paintToggle()
    if not Bank.Enabled then
        returnDrops()
    end
end)

delayBox.FocusLost:Connect(function()
    Bank.DepositDelay = math.clamp(tonumber(delayBox.Text) or Bank.DepositDelay, 0.1, 30)
    delayBox.Text = string.format("%.1f", Bank.DepositDelay)
end)

Bank.Connections[#Bank.Connections+1] = UIS.InputBegan:Connect(function(i, gpe)
    if not gpe and i.KeyCode == Enum.KeyCode.RightShift then
        panel.Visible = not panel.Visible
    end
end)

-- ── Logic ────────────────────────────────────────────────────────────────────
local function getHead()
    local char = LocalPlayer.Character
    return char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
end

local function getItems()
    local state = ClientStore:getState()
    local inv = state.Inventory and state.Inventory.observedInventory and state.Inventory.observedInventory.inventory
    return inv and inv.items or {}
end

local function getResourceName(item)
    if not item then return nil end
    local n = string.lower(item.itemType or (item.tool and item.tool.Name) or "")
    return Bank.ResourceNames[n] and n or nil
end

local function updateHud()
    local realCounts = { iron = 0, diamond = 0, emerald = 0, gold = 0 }
    for dropped, data in pairs(Bank.Drops) do
        if dropped.Parent and data.Confirmed and not data.Returning then
            local actual = tonumber(dropped:GetAttribute("Amount"))
                or tonumber(dropped:GetAttribute("ItemAmount")) or data.Amount
            if actual~=actual or actual==math.huge or actual==-math.huge then actual=data.Amount end
            realCounts[data.Name] = (realCounts[data.Name] or 0) + actual
        end
    end
    for rn, sData in pairs(slots) do
        sData.Count.Text = tostring(realCounts[rn] or 0)
    end
end

local function cleanDrops()
    local changed = false
    for dropped, data in pairs(Bank.Drops) do
        if not dropped.Parent then
            Bank.Drops[dropped] = nil
            changed = true
        end
    end
    if changed then updateHud() end
end

local function depositResources()
    if not Bank.Enabled or Bank.Busy then return end
    local head = getHead()
    if not head then return end
    if isNear and isNear(head.Position) then return end
    Bank.Busy = true

    task.spawn(function()
        local currentTime = tick()
        for _, item in pairs(getItems()) do
            local liveHead = getHead()
            if not liveHead or (isNear and isNear(liveHead.Position)) then break end
            local rn = getResourceName(item)
            local amt = tonumber(item.amount) or 0
            local finite = amt == amt and amt ~= math.huge and amt ~= -math.huge
            if rn and finite and amt > 0 and item.tool and not Bank.Pending[rn] then
                
                if not Bank.ItemAges[item.tool] then
                    Bank.ItemAges[item.tool] = currentTime
                end
                
                local lastDrop = Bank.LastDropTime[item.tool] or 0
                if currentTime - lastDrop < 1.5 then continue end

                if currentTime - Bank.ItemAges[item.tool] >= Bank.DepositDelay then
                    Bank.LastDropTime[item.tool] = currentTime
                    Bank.Pending[rn] = true
                    
                    local ok, dropped = pcall(function()
                        return DropRemote:CallServer({ item = item.tool, amount = amt })
                    end)
                    
                    if ok and typeof(dropped) == "Instance" then
                        -- Random pos so drops don't merge on the server
                        -- Keep drops above the current map rather than at Y=5000,
                        -- where streaming/void cleanup can destroy them.
                        local skyPos = head.Position + Vector3.new(math.random(-80,80), 550 + math.random(0,35), math.random(-80,80))
                        Bank.Drops[dropped] = { Name = rn, Amount = amt, SkyPos = skyPos, Confirmed = false }
                        moveTo(dropped, skyPos)
                        -- Only advertise loot as banked after the physical drop
                        -- survives and this client actually owns its physics.
                        task.delay(0.75,function()
                            local data=Bank.Drops[dropped]
                            Bank.Pending[rn]=nil
                            if not data or not dropped.Parent then return end
                            local part=dropped:IsA("BasePart") and dropped or dropped:FindFirstChildWhichIsA("BasePart",true)
                            local owns=part and (type(isnetworkowner)~="function" or isnetworkowner(part))
                            -- Leaving it unpinned during verification exposes a
                            -- server snapback instead of counting a local ghost.
                            local stayed = part and (part.Position-data.SkyPos).Magnitude < 120
                            data.Confirmed = owns == true and stayed == true
                            if not data.Confirmed then
                                Bank.Drops[dropped]=nil
                                local h=getHead()
                                if h and part then part.CFrame=h.CFrame end
                                pcall(function() PickupRemote:CallServerAsync({itemDrop=dropped}) end)
                            end
                            updateHud()
                        end)
                    else
                        Bank.Pending[rn]=nil
                    end
                end
            end
        end
        task.wait(0.2)
        Bank.Busy = false
    end)
end

local targets = {}
local function refreshTargets()
    table.clear(targets)
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("Model") or d:IsA("BasePart") then
            local n = string.lower(d.Name):gsub("[%s_%-]", "")
            if n:find("itemshop",1,true) or n:find("teamupgrade",1,true) or n:find("personalchest",1,true) or n:find("teamchest",1,true) or n=="amir" then
                local p = (d:IsA("BasePart") and d) or d:FindFirstChildWhichIsA("BasePart", true)
                if p then targets[p] = true end
            end
        end
    end
end

isNear = function(pos)
    for p in pairs(targets) do
        if not p.Parent then
            targets[p] = nil
        elseif (p.Position - pos).Magnitude <= Bank.ReturnRadius then
            return true
        end
    end
    return false
end

function returnDrops()
    local head = getHead()
    if not head then return end
    local changed = false
    for dropped, data in pairs(Bank.Drops) do
        if dropped.Parent then
            for obj, values in pairs(data.Saved or {}) do
                if obj.Parent then
                    if obj:IsA("BasePart") then
                        obj.Anchored, obj.CanCollide, obj.CanTouch, obj.Transparency = values[1], values[2], values[3], values[4]
                    elseif obj:IsA("Decal") or obj:IsA("Texture") then
                        obj.Transparency = values[1]
                    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")
                        or obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") or obj:IsA("Light") then
                        obj.Enabled = values[1]
                    end
                end
            end
            local dropPart = dropped:IsA("BasePart") and dropped or dropped:FindFirstChildWhichIsA("BasePart", true)
            if dropPart then
                if not data.Returning then changed = true end
                data.Returning = true
                dropPart.Anchored = false
                dropPart.CanCollide = false
                dropPart.AssemblyLinearVelocity = Vector3.zero
                dropPart.AssemblyAngularVelocity = Vector3.zero
                dropPart.CFrame = head.CFrame * CFrame.new(0, 2.5, 0)

                -- Keep physically pinning it until the server removes it.
                -- A bounded retry avoids both void loss and per-frame requests.
                local now=tick()
                if now >= (data.NextPickup or 0) then
                    data.NextPickup=now+0.75
                    pcall(function() PickupRemote:CallServerAsync({itemDrop=dropped}) end)
                end
            end
        else
            Bank.Drops[dropped] = nil
            changed = true
        end
    end
    if changed then updateHud() end
end

local el, tel = 0, 0
Bank.Connections[#Bank.Connections+1] = RunService.Heartbeat:Connect(function(dt)
    el += dt; tel += dt
    if tel >= 15 then tel = 0; refreshTargets() end
    
    cleanDrops()

    if el < 0.1 then return end
    el = 0

    if Bank.Enabled then
        local remaining = Bank.DepositDelay
        local now = tick()
        local found = false
        for _, item in pairs(getItems()) do
            local rn = getResourceName(item)
            local amount=tonumber(item.amount) or 0
            if rn and amount>0 and amount==amount and amount~=math.huge and amount~=-math.huge and item.tool then
                found = true
                local age = Bank.ItemAges[item.tool]
                remaining = math.min(remaining, age and math.max(0, Bank.DepositDelay-(now-age)) or Bank.DepositDelay)
            end
        end
        timerLabel.Text = found and string.format("BANKING IN %.1fs",remaining) or "WAITING FOR RESOURCES"
    else
        timerLabel.Text = "AUTOBANK PAUSED"
    end

    local head = getHead()
    if not head then return end

    if not Bank.Enabled or isNear(head.Position) then
        local now = tick()
        for _, item in pairs(getItems()) do
            if item.tool and getResourceName(item) then Bank.ItemAges[item.tool] = now end
        end
        returnDrops()
        return
    end

    for dropped, data in pairs(Bank.Drops) do
        if dropped.Parent and data.Confirmed and not data.Returning then
            moveTo(dropped, data.SkyPos)
        end
    end
end)

task.spawn(function()
    while not Bank.Destroyed do
        task.wait(0.25)
        depositResources()
    end
end)

function Bank:Destroy()
    self.Destroyed = true
    self.Enabled = false
    for _, c in ipairs(self.Connections) do c:Disconnect() end
    table.clear(self.Connections)
    returnDrops()
    gui:Destroy()
    if getgenv().BedwarsAutoBank == self then getgenv().BedwarsAutoBank = nil end
end

refreshTargets()
updateHud()
print("[BedWars AutoBank v5] loaded - Desync fixes")

