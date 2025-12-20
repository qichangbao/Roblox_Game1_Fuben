local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local ConstantConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ConstantConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local _escapeTime = ConstantConfig:GetByIndex(4).Effect1

local BoatService = Knit.CreateService({
    Name = 'BoatService',
    Client = {
        ChooseEscape = Knit.CreateSignal(),
        ChooseNextIsland = Knit.CreateSignal(),
        ResetBoat = Knit.CreateSignal(),
    },

    ChooseVote = {},    -- 1 选择逃生 2 选择下一个岛屿
})

local _boat = workspace:WaitForChild(GameConfig.TeleportPartNames)

-- 获取投票结果
function BoatService:GetChooseVote()
    local escapeVote = 0
    local nextIslandVote = 0
    for _, vote in pairs(self.ChooseVote) do
        if vote == 1 then
            escapeVote += 1
        elseif vote == 2 then
            nextIslandVote += 1
        end
    end
    return escapeVote, nextIslandVote
end

function BoatService:CheckVote()
    local playerCount = Knit.GetService("PlayerService"):GetPlayerCount()
    local escapeVote, nextIslandVote = self:GetChooseVote()
    local totalVote = escapeVote + nextIslandVote
    if totalVote > playerCount / 2 then
        local escapeTime = Knit.GetService("TaskService"):GetEscapeTime()
        if escapeTime > _escapeTime then
            Knit.GetService("TaskService"):SetEscapeTime(_escapeTime)
        end
    end
end

function BoatService:GetPlayerChoose(player)
    return self.ChooseVote[player.UserId]
end

function BoatService:GetNextIslandPlayers()
    local gotoNextIslandPlayers = {}
    for userId, v in pairs(self.ChooseVote) do
        if v == 2 then
            table.insert(gotoNextIslandPlayers, userId)
        end
    end
    return gotoNextIslandPlayers
end

function BoatService:ChooseEscape(player)
    if self.ChooseVote[player.UserId] then return end
    self.ChooseVote[player.UserId] = 1
    self.Client.ChooseEscape:Fire(player)

    self:CheckVote()
end

function BoatService:ChooseNextIsland(player)
    if self.ChooseVote[player.UserId] then return end
    self.ChooseVote[player.UserId] = 2
    self.Client.ChooseNextIsland:Fire(player)
    
    self:CheckVote()
end

function BoatService:Reset(player, cframe)
    _boat:PivotTo(cframe)
    player.Character:PivotTo(cframe)

    self.ChooseVote = {}
end

function BoatService.Client:Reset(player, cframe)
    self.Server:Reset(player, cframe)
end

function BoatService:KnitInit()
end

function BoatService:KnitStart()
end

return BoatService
