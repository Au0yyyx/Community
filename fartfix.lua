if not game:IsLoaded() then
    game.Loaded:Wait()
end

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Environment = getgenv and getgenv() or _G
local CONTROLLER_KEY = "__FartHubCharacterReplicationFix"

local previous = Environment[CONTROLLER_KEY]
if type(previous) == "table" and type(previous.Destroy) == "function" then
    pcall(previous.Destroy, previous)
end

local Network = require(ReplicatedStorage.Modules.Network.Network)
local ConnectionRegistry = require(ReplicatedStorage.ConnectionRegistry)
local unreliableRemote = ReplicatedStorage.Modules.Network.Network:WaitForChild(
    "UnreliableRemoteEvent"
)

local function restoreIfHooked(callback)
    if type(callback) ~= "function"
        or type(isfunctionhooked) ~= "function"
        or type(restorefunction) ~= "function" then
        return
    end

    local ok, hooked = pcall(isfunctionhooked, callback)
    if ok and hooked then
        pcall(restorefunction, callback)
    end
end

-- Start from the game's line-703 implementation, not a FartHub hook.
restoreIfHooked(Network.FireServerConnection)
local baseFireServerConnection = Network.FireServerConnection
local safeFireServerConnection = type(clonefunction) == "function"
    and clonefunction(baseFireServerConnection)
    or baseFireServerConnection

local Controller = {
    Connections = {},
    Destroyed = false,
    PacketsSent = 0,
    LastHookRepair = 0,
    BaseFireServerConnection = baseFireServerConnection,
    OriginalFireServerConnection = safeFireServerConnection
}
Environment[CONTROLLER_KEY] = Controller

-- Network.__decompressValue understands this JSON-backed buffer wrapper.
local function compressBufferValue(value)
    local encoded = HttpService:JSONEncode(value)
    local compressed = buffer.create(5 + #encoded)
    buffer.writeu8(compressed, 0, 10)
    buffer.writeu32(compressed, 1, #encoded)
    buffer.writestring(compressed, 5, encoded)
    return compressed
end

local function replacement(self, connectionName, connectionType, ...)
    if not Controller.Destroyed
        and connectionName == "UpdateCharacterPosition"
        and connectionType == "UREMOTE_EVENT" then
        local arguments = table.pack(...)
        if arguments.n == 1 and typeof(arguments[1]) == "buffer" then
            local encodedName = ConnectionRegistry[connectionName] or connectionName
            unreliableRemote:FireServer(encodedName, {
                [1] = compressBufferValue(arguments[1])
            })
            Controller.PacketsSent += 1
            return
        end
    end

    return safeFireServerConnection(
        self,
        connectionName,
        connectionType,
        ...
    )
end

Controller.ReplacementFireServerConnection = type(newcclosure) == "function"
    and newcclosure(replacement)
    or replacement
Network.FireServerConnection = Controller.ReplacementFireServerConnection

local function repairRecursiveHooks()
    if Controller.Destroyed then
        return
    end

    -- FartHub may hook both the exported wrapper and the original closure.
    -- Restoring both prevents wrapper -> hook -> wrapper recursion.
    restoreIfHooked(Controller.BaseFireServerConnection)
    restoreIfHooked(Controller.ReplacementFireServerConnection)

    if Network.FireServerConnection ~= Controller.ReplacementFireServerConnection then
        restoreIfHooked(Network.FireServerConnection)
        Network.FireServerConnection = Controller.ReplacementFireServerConnection
    end
end

table.insert(Controller.Connections, RunService.Heartbeat:Connect(function()
    local now = os.clock()
    if now - Controller.LastHookRepair >= 0.25 then
        Controller.LastHookRepair = now
        repairRecursiveHooks()
    end
end))

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

    restoreIfHooked(self.BaseFireServerConnection)
    restoreIfHooked(self.ReplacementFireServerConnection)
    if Network.FireServerConnection == self.ReplacementFireServerConnection then
        Network.FireServerConnection = self.BaseFireServerConnection
    end
    if Environment[CONTROLLER_KEY] == self then
        Environment[CONTROLLER_KEY] = nil
    end
end

repairRecursiveHooks()


