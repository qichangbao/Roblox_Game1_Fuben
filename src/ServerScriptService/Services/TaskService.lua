-- TaskService 服务
-- 使用Knit框架管理服务器数据

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))
local DesignConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("DesignConfig"))
local ConstantConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ConstantConfig"))

local TaskService = Knit.CreateService {
	Name = "TaskService",
	Client = {
        UpdateEscapeTask = Knit.CreateSignal(),
        UpdateEscapeTime = Knit.CreateSignal(),
        GotoNextIsland = Knit.CreateSignal(),
	},

    EscapeTask = 0,
    CurEscapeTask = 0,
    EscapeTime = 0,
    IsOver = false,
    IsInit = false,
}

function TaskService:KnitInit()
end

-- 服务启动时的初始化
-- @return void
function TaskService:KnitStart()
    game:GetService("RunService").Heartbeat:Connect(function(dt)
        if self.IsInit and self.EscapeTime > 0 then
            self:UpdateEscapeTime(dt)
        end
    end)
end

function TaskService:PlayerAdded(player)
end

function TaskService:PlayerRemoved(player)
end

function TaskService:GetIsInit()
    return self.IsInit
end

function TaskService:InitEscapeTask(escapeTask)
    self.EscapeTask = escapeTask
    self.IsInit = true
end

function TaskService:SetEscapeTask(gold)
    self.EscapeTask = gold
end

function TaskService:GetEscapeTask()
    return self.EscapeTask
end

function TaskService:UpdateEscapeTask(curEscapeTask)
    self.CurEscapeTask += curEscapeTask
    self.Client.UpdateEscapeTask:FireAll(self.CurEscapeTask, self.EscapeTask)
end

function TaskService:IsSuccess()
    return self.CurEscapeTask >= self.EscapeTask
end

function TaskService:SetEscapeTime(time)
    self.EscapeTime = time
    self.Client.UpdateEscapeTime:FireAll(self.EscapeTime)
end

function TaskService:GetEscapeTime()
    return self.EscapeTime
end

function TaskService:GetNextIslandId()
    local curIslandId = Knit.GetService("IslandService"):GetIslandId()
    local configs = DesignConfig:GetAll()

    for i = 1, #configs do
        local config = configs[i]
        if config.MapId == curIslandId then
            if configs[i + 1] then
                return configs[i + 1].MapId
            else
                return
            end
        end
    end
end

function TaskService:UpdateEscapeTime(curEscapeTime)
    if self.IsOver  then
        return
    end

    self.EscapeTime -= curEscapeTime
    if self.EscapeTime <= 0 then
        self.IsOver = true

        local isGotoNextIsland = false
        local SettleService = Knit.GetService("SettleService")
        local nextIslandId = self:GetNextIslandId()
        local gotoNextIslandPlayers = Knit.GetService("BoatService"):GetNextIslandPlayers()
        for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
            if not Interface.isPlayerOnBoat(player) then
                SettleService:Settle(player, false, true)
            else
                local isEscape = Knit.GetService("BoatService"):GetPlayerChoose(player) == 1
                if isEscape then
                    SettleService:Settle(player, true, false)
                else
                    if nextIslandId then
                        self.Client.GotoNextIsland:Fire(player, gotoNextIslandPlayers)
                        isGotoNextIsland = true
                    else
                        SettleService:Settle(player, false, true)
                    end
                end
            end
        end

        if isGotoNextIsland then
            task.delay(1, function()
                Knit.GetService("ItemService"):DestroyAllItems()
                Knit.GetService("MonsterService"):DestroyAllMonsters()
                Knit.GetService("IslandService"):SetIslandId(nextIslandId)
                Knit.GetService("ItemService"):InitItems()
                Knit.GetService("MonsterService"):InitMonsters()

                local mapConfig = DesignConfig:GetByMapId(nextIslandId)
                self:SetEscapeTime(mapConfig.EvacuateTime)
                self.IsOver = false
            end)
        end
    end
end

return TaskService