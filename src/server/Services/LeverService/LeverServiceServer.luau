local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

type LeverServiceServer = {
    _lastPullTime: { [Player]: number },
    Init: (self: LeverServiceServer) -> (),
}

local LeverServiceServer = {} :: LeverServiceServer & typeof(setmetatable({}, {}))
LeverServiceServer._lastPullTime = {}

-- Configuration – adjust to your needs
local PLATFORM_NAME = "smallPlatform"     -- name of the platform part in Workspace
local SPAWN_OFFSET = Vector3.new(0, 3, 0) -- how high above the platform
local MODEL_NAME = "Toolbox"              -- name of the model in ServerStorage

local function spawnPartOnPlatform()
    local pathNames = { "GameLevel", "Table", "gameLoop", "Player1", PLATFORM_NAME }
    local current: Instance? = Workspace
    for _, name in ipairs(pathNames) do
        if current then
            local nextChild = current:FindFirstChild(name)
            if not nextChild then
                warn("Path broken! Could not find '" .. name .. "' inside of '" .. current.Name .. "'")
                return
            end
            current = nextChild
        end
    end
    
    local platform = current
    if not platform then return end
    
    local platformCFrame
    if platform:IsA("BasePart") then
        platformCFrame = platform.CFrame
    elseif platform:IsA("Model") then
        platformCFrame = platform:GetPivot()
    else
        warn("Platform found, but it is a " .. platform.ClassName .. " (Needs to be a Part or Model!)")
        return
    end

    local originalModel = ServerStorage:FindFirstChild(MODEL_NAME)
    if not originalModel then
        warn("Model not found in ServerStorage:", MODEL_NAME)
        return
    end

    local clonedModel = originalModel:Clone()
    
    if clonedModel:IsA("Model") then
        clonedModel:PivotTo(platformCFrame + SPAWN_OFFSET)
    elseif clonedModel:IsA("BasePart") then
        clonedModel.CFrame = platformCFrame + SPAWN_OFFSET
    end
    
    clonedModel.Parent = Workspace
end

function LeverServiceServer.Init(self: LeverServiceServer)
    local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
    local leverPulledEvent = remotesFolder:WaitForChild("LeverPulled")

    leverPulledEvent.OnServerEvent:Connect(function(player)
        local now = os.clock()
        if self._lastPullTime[player] and now - self._lastPullTime[player] < 3 then
            return -- Too soon
        end
        self._lastPullTime[player] = now

        spawnPartOnPlatform()
    end)

    Players.PlayerRemoving:Connect(function(player)
        self._lastPullTime[player] = nil
    end)
end

return LeverServiceServer :: LeverServiceServer
