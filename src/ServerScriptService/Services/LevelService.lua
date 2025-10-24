-- LevelService 服务
-- 使用Knit框架管理服务器数据

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))


local LevelService = Knit.CreateService {
	Name = "LevelService",
	Client = {
	},

    DuanWeiData = {},
}

function LevelService:KnitInit()
end

-- 服务启动时的初始化
-- @return void
function LevelService:KnitStart()
end

function LevelService:PlayerAdded(player, levelData)
    self.DuanWeiData[player.UserId] = {}
    self.DuanWeiData[player.UserId].duanWei = levelData.duanWei or 1
    self.DuanWeiData[player.UserId].level = levelData.level or 1
    self.DuanWeiData[player.UserId].star = levelData.star or 0
    self.DuanWeiData[player.UserId].duanWei = tonumber(self.DuanWeiData[player.UserId].duanWei)
    self.DuanWeiData[player.UserId].level = tonumber(self.DuanWeiData[player.UserId].level)
    self.DuanWeiData[player.UserId].star = tonumber(self.DuanWeiData[player.UserId].star)
end

function LevelService:playerRemoved(player)
    self.DuanWeiData[player.UserId] = nil
end

function LevelService:GetLevelData(player)
    return self.DuanWeiData[player.UserId]
end

return LevelService