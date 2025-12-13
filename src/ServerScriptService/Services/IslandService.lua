local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))

local IslandService = Knit.CreateService({
    Name = 'IslandService',
    Client = {
    },

    IslandId = 0,
})

function IslandService:SetIslandId(islandId)
    self.IslandId = islandId
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
