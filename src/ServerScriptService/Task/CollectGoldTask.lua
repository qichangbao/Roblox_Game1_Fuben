local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))

local CollectGoldTask = {}

function CollectGoldTask:Init(player, task)
    task.Current = 0
    task.Complete = false
end

function CollectGoldTask:Remove(player)
    
end

function CollectGoldTask:UpdateTask(player, task)
    if not task.Current then
        task.Current = 0
    end
    local toolData = Knit.GetService("InventoryService"):GetToolData(player)
    for _, itemId in ipairs(toolData) do
        local itemInfo = ItemConfig:GetByIndex(itemId)
        if itemInfo and itemInfo.Type == GameConfig.ItemType.Collect then
            task.Current = task.Current + itemInfo.SellPrice
        end
    end

    task.Complete = self:IsDone(task)
    Knit.GetService("TaskService").Client.UpdateTask:Fire(player, {Current = task.Current, Target = task.Target, Complete = task.Complete})
end

function CollectGoldTask:IsDone(task)
    if not task.Current then
        return false
    end
    return task.Current >= task.Target
end

return CollectGoldTask