-- TaskService 服务
-- 使用Knit框架管理服务器数据

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))

local TaskService = Knit.CreateService {
	Name = "TaskService",
	Client = {
        UpdateEscapeTask = Knit.CreateSignal(),
        InitEscapeTime = Knit.CreateSignal(),
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

function TaskService:InitEscapeTime(escapeTime)
    self.EscapeTime = escapeTime
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
end

function TaskService:GetEscapeTime()
    return self.EscapeTime
end

function TaskService:UpdateEscapeTime(curEscapeTime)
    if self.IsOver  then
        return
    end

    self.EscapeTime -= curEscapeTime
    if self.EscapeTime <= 0 then
        self.IsOver = true

        local SettleService = Knit.GetService("SettleService")
        for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
            SettleService:Settle(player, false)
        end
    end
end

return TaskService