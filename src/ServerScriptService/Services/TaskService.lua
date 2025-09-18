-- TaskService 服务
-- 使用Knit框架管理服务器数据

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))

local TaskService = Knit.CreateService {
	Name = "TaskService",
	Client = {
        UpdateEscapeTask = Knit.CreateSignal(),
	},

    EscapeTask = 0,
    CurEscapeTask = 0,
}

function TaskService:KnitInit()
end

-- 服务启动时的初始化
-- @return void
function TaskService:KnitStart()
end

function TaskService:InitEscapeTask(curEscapeTask, escapeTask)
    self.EscapeTask = escapeTask
    self:UpdateEscapeTask(curEscapeTask)
end

function TaskService:SetEscapeTask(gold)
    self.EscapeTask = gold
end

function TaskService:UpdateEscapeTask(curEscapeTask)
    self.CurEscapeTask += curEscapeTask
    self.Client.UpdateEscapeTask:FireAll(self.CurEscapeTask, self.EscapeTask)
end

return TaskService