-- TaskService 服务
-- 使用Knit框架管理服务器数据

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local CollectGoldTask = require(script.Parent.Parent:WaitForChild("Task"):WaitForChild("CollectGoldTask"))

local TaskService = Knit.CreateService {
	Name = "TaskService",
	Client = {
        UpdateTask = Knit.CreateSignal(),
	},

    Task = {},
}

function TaskService:KnitInit()
end

-- 服务启动时的初始化
-- @return void
function TaskService:KnitStart()
end

function TaskService:playerAdd(player, task)
    self.Task[player.UserId] = task
    for _, v in pairs(task) do
        if v.Type == 1 then
            CollectGoldTask:Init(player, v)
        end
    end
end

function TaskService:playerRemoved(player)
    for _, v in pairs(self.Task[player.UserId]) do
        if v.Type == 1 then
            CollectGoldTask:Remove(player)
        end
    end
    self.Task[player.UserId] = nil
end

function TaskService:GetTaskData(player)
    return self.Task[player.UserId]
end

function TaskService:AddTask(player, task)
    table.insert(self.Task[player.UserId], task)
end

function TaskService:RemoveTask(player, taskId)
    for i, task in ipairs(self.Task[player.UserId]) do
        if i == taskId then
            table.remove(self.Task[player.UserId], i)
            break
        end
    end
end

function TaskService:CheckTask(player, taskId)
    local task = self.Task[player.UserId][taskId]
    if not task then
        return
    end

    if task.Type == 1 then  -- 收集金币
        return CollectGoldTask:IsDone(task)
    end
end

function TaskService:UpdateTask(player, taskType)
    for _, v in pairs(self.Task[player.UserId]) do
        if v.Type == taskType then
            CollectGoldTask:UpdateTask(player, v)
        end
    end
end

return TaskService