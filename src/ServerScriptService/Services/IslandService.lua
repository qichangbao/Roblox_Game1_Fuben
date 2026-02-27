local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))

local IslandService = Knit.CreateService({
    Name = 'IslandService',
    Client = {
    },

    IslandId = 0,
})

local Map = game:GetService("ServerStorage"):WaitForChild("Map")

function IslandService:SetIslandId(islandId)
    if self.IslandId == islandId then return end
    if self.IslandId ~= 0 then
        local landTemp = workspace:FindFirstChild(self.IslandId)
        if landTemp then
            landTemp:Destroy()
        end
    end
    local island = workspace:FindFirstChild(islandId)
    if not island then
        local land = Map:FindFirstChild(islandId)
        if not land then return end
        local newLand = land:Clone()
        newLand.Parent = workspace
        self.IslandId = islandId
    end
end

function IslandService:GetIslandId()
    return self.IslandId
end

function IslandService.Client:GetIslandId()
    return self.Server:GetIslandId()
end

function IslandService:KnitInit()
end

function IslandService:KnitStart()
end

return IslandService
