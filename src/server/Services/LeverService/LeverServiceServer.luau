local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

type LeverServiceServer = {
    _lastPullTime: { [Player]: number },
    _spawnCounts: { [Player]: number },
    _lastSpawnedItem: { [Player]: string },
    Init: (self: LeverServiceServer) -> (),
}

local LeverServiceServer = {} :: LeverServiceServer & typeof(setmetatable({}, {}))
LeverServiceServer._lastPullTime = {}
LeverServiceServer._spawnCounts = {}
LeverServiceServer._lastSpawnedItem = {}

-- Configuration – adjust to your needs
local PLATFORM_NAME = "smallPlatform"     -- name of the platform part in Workspace
local SPAWN_OFFSET = Vector3.new(0, 3, 0) -- how high above the platform
local ITEMS_FOLDER_NAME = "Items"         -- name of the folder in ServerStorage containing items to spawn

local function spawnPartOnPlatform(spawnCount: number, lastItemName: string?)
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
        return nil
    end

    local itemsFolder = ServerStorage:FindFirstChild(ITEMS_FOLDER_NAME)
    if not itemsFolder then
        warn("Items folder not found in ServerStorage:", ITEMS_FOLDER_NAME)
        return nil
    end

    local availableItems = itemsFolder:GetChildren()
    if #availableItems == 0 then
        warn("No items found inside the folder:", ITEMS_FOLDER_NAME)
        return nil
    end

    local originalModel
    if spawnCount == 0 then
        originalModel = itemsFolder:FindFirstChild("Bread Slice")
        if not originalModel then
            -- Fallback just in case they haven't added the bread slice yet
            originalModel = availableItems[Random.new():NextInteger(1, #availableItems)]
        end
    else
        -- Only prevent "Bread Slice" from spawning twice in a row
        local filteredItems = {}
        for _, item in ipairs(availableItems) do
            if #availableItems <= 1 or not (item.Name == "Bread Slice" and lastItemName == "Bread Slice") then
                table.insert(filteredItems, item)
            end
        end
        
        originalModel = filteredItems[Random.new():NextInteger(1, #filteredItems)]
    end
    local clonedModel = originalModel:Clone()
    
    -- Increase the Y height by 1.5 studs for every item spawned so they stack on top of each other!
    local stackedOffset = SPAWN_OFFSET + Vector3.new(0, spawnCount * 1.5, 0)
    
    -- Rotate the Bread Slice by -90 degrees on the X axis
    local isBread = originalModel.Name == "Bread Slice"
    local rotationOffset = isBread and CFrame.Angles(math.rad(-90), 0, 0) or CFrame.Angles(0, 0, 0)
    
    local targetCFrame = (platformCFrame + stackedOffset) * rotationOffset
    
    -- Ensure physics are applied without the model falling apart
    if clonedModel:IsA("Model") then
        clonedModel:PivotTo(targetCFrame)
        
        -- Find a root part to weld everything to
        local rootPart = clonedModel.PrimaryPart or clonedModel:FindFirstChildWhichIsA("BasePart", true)
        
        if rootPart then
            -- Weld all parts to the root part and unanchor them
            for _, descendant in clonedModel:GetDescendants() do
                if descendant:IsA("BasePart") and descendant ~= rootPart then
                    local weld = Instance.new("WeldConstraint")
                    weld.Part0 = rootPart
                    weld.Part1 = descendant
                    weld.Parent = weld.Part0
                    descendant.Anchored = false
                end
            end
            rootPart.Anchored = false
        end
    elseif clonedModel:IsA("BasePart") then
        clonedModel.CFrame = targetCFrame
        clonedModel.Anchored = false
    end
    
    clonedModel.Parent = Workspace
    return originalModel.Name
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
        
        local currentCount = self._spawnCounts[player] or 0
        self._spawnCounts[player] = currentCount + 1

        local lastItem = self._lastSpawnedItem[player]
        local spawnedItemName = spawnPartOnPlatform(currentCount, lastItem)
        if spawnedItemName then
            self._lastSpawnedItem[player] = spawnedItemName
        end
    end)

    Players.PlayerRemoving:Connect(function(player)
        self._lastPullTime[player] = nil
        self._spawnCounts[player] = nil
    end)
end

return LeverServiceServer :: LeverServiceServer
