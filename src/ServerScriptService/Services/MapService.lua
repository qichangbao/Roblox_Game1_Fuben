local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))

local MapService = Knit.CreateService({
    Name = 'MapService',
    Client = {
        SendShowFlag = Knit.CreateSignal(),
    },
})

function MapService:ShowFlag(player, flagType, flagPosition)
    self.Client.SendShowFlag:FireAll({Type = flagType, Position = flagPosition})
end

function MapService.Client:ShowFlag(player, flagType, flagPosition)
    return self.Server:ShowFlag(player, flagType, flagPosition)
end

function MapService:KnitInit()
end

function MapService:KnitStart()
end

return MapService
