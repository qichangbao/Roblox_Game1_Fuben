local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))

local IslandService = Knit.CreateService({
    Name = 'IslandService',
    Client = {
    },

    IslandName = "",
})

function IslandService:SetIslandName(islandName)
    self.IslandName = islandName
end

function IslandService:GetIslandName()
    return self.IslandName
end

function IslandService:KnitInit()
end

function IslandService:KnitStart()
end

return IslandService
