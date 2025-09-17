local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))

local CollectGoldTask = {}

function CollectGoldTask:Init(player, task)
    task.Type = 1
    task.Current = 0
    task.Complete = false
end

function CollectGoldTask:Remove(player)
    
end

function CollectGoldTask:UpdateTask(player, task)
    if not task.Current then
        task.Current = 0
    end
    local current = 0
    local toolData = Knit.GetService("InventoryService"):GetToolData(player)
    for _, itemData in ipairs(toolData) do
        local itemInfo = ItemConfig:GetByIndex(itemData.ItemId)
        if itemInfo and itemInfo.Type == GameConfig.ItemType.Collect then
            current += itemInfo.SellPrice
        end
    end

    task.Current = current
    task.Complete = self:IsDone(task)
    Knit.GetService("TaskService").Client.UpdateTask:Fire(player, task)
end

function CollectGoldTask:IsDone(task)
    if not task.Current then
        return false
    end
    return task.Current >= task.Target
end

return CollectGoldTask