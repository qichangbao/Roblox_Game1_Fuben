-- TaskService 服务
-- 使用Knit框架管理服务器数据

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local Signal = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Signal"))
local NPCQuestConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("NPCQuestConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))

local TaskService = Knit.CreateService {
	Name = "TaskService",
	Client = {
        UpdateEscapeTask = Knit.CreateSignal(),
        InitEscapeTime = Knit.CreateSignal(),
        OpenTaskUI = Knit.CreateSignal(),
        OpenSubmitUI = Knit.CreateSignal(),
        TaskCompleted = Knit.CreateSignal(),
	},
    -- 服务器间通信使用Signal包
    CompletedTask = Signal.new(),

    EscapeTask = 0,
    CurEscapeTask = 0,
    EscapeTime = 0,
    IsOver = false,
    IsInit = false,
    TaskData = {},
}

local _taskNum = NPCQuestConfig:GetCount()

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
    if not self.TaskData[player.UserId] then
        self.TaskData[player.UserId] = math.random(1, _taskNum)
    end
end

function TaskService:PlayerRemoved(player)
    self.TaskData[player.UserId] = nil
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

function TaskService:OpenSubmitUI(player)
    self.Client.OpenSubmitUI:Fire(player)
end

function TaskService:OpenTaskUI(player)
    if not self.TaskData[player.UserId] then
        self.TaskData[player.UserId] = math.random(1, _taskNum)
    end
	self.Client.OpenTaskUI:Fire(player, self.TaskData[player.UserId])
end

--[[
    完成任务
    @param player Player 玩家对象
    @param taskId number 任务ID
    @return boolean 是否成功完成任务
]]
function TaskService:ComplateTask(player, taskId)
    local task = NPCQuestConfig:GetByQuestId(taskId)
    if not task then
        return false
    end

    local inventoryService = Knit.GetService("InventoryService")
    local toolData = inventoryService:GetToolData(player)
    local bagData = inventoryService:GetBagData(player)
    
    -- 统计所有物品数量
    local allItemList = {}
    for _, v in pairs(toolData) do
        if not allItemList[v.ItemId] then
            allItemList[v.ItemId] = 0
        end
        allItemList[v.ItemId] = allItemList[v.ItemId] + 1
    end
    for _, v in pairs(bagData) do
        if not allItemList[v.ItemId] then
            allItemList[v.ItemId] = 0
        end
        allItemList[v.ItemId] = allItemList[v.ItemId] + 1
    end
    
    -- 检查是否满足任务条件
    local needItemList = {task.NeedItem}
    local needNumList = {task.NeedNum}
    for i, v in ipairs(needItemList) do
        local itemId = v
        local num = needNumList[i]
        if not allItemList[itemId] or allItemList[itemId] < num then
            return false
        end
    end

    -- 条件满足，开始移除物品
    -- 需要移除的物品数量记录
    local itemsToRemove = {}
    for i, itemId in ipairs(needItemList) do
        itemsToRemove[itemId] = needNumList[i]
    end
    
    -- 标记是否有数据变更
    local toolDataChanged = false
    local bagDataChanged = false
    
    -- 从背包中移除剩余的物品（直接操作数据，不调用RemoveBag）
    for i = #bagData, 1, -1 do
        local item = bagData[i]
        local itemId = item.ItemId
        
        if itemsToRemove[itemId] and itemsToRemove[itemId] > 0 then
            -- 直接修改背包数据
             bagData[i] = {
                 ItemId = 0,
                 Attribute = GameConfig.GetItemAttribute()
             }
            itemsToRemove[itemId] = itemsToRemove[itemId] - 1
            bagDataChanged = true
        end
    end
    
    -- 从工具栏中移除物品（直接操作数据，不调用RemoveTool）
    for i = #toolData, 1, -1 do
        local item = toolData[i]
        local itemId = item.ItemId
        
        if itemsToRemove[itemId] and itemsToRemove[itemId] > 0 then
            -- 直接修改工具栏数据
             toolData[i] = {
                 ItemId = 0,
                 Attribute = GameConfig.GetItemAttribute()
             }
            itemsToRemove[itemId] = itemsToRemove[itemId] - 1
            toolDataChanged = true
        end
    end
    
    -- 批量更新客户端数据（只在有变更时才发送）
    if toolDataChanged then
        inventoryService:UpdateToolData(player, toolData)
    end
    
    if bagDataChanged then
        inventoryService:UpdateBagData(player, bagData)
    end
    
    -- 验证是否所有物品都已移除
    local allRemoved = true
    for itemId, remainingCount in pairs(itemsToRemove) do
        if remainingCount > 0 then
            warn("任务物品移除不完整，物品ID:", itemId, "剩余数量:", remainingCount)
            allRemoved = false
        end
    end
    
    if allRemoved then
        -- 发送奖励物品
        self:GiveRewardItem(player, task)
    end
    
    -- 发送任务完成信号（服务器间通信）
    self.CompletedTask:Fire(player, taskId)

    -- 更新下一个任务
    if not self.TaskData[player.UserId] then
        self.TaskData[player.UserId] = math.random(1, _taskNum)
    end
    
    return true
end

function TaskService.Client:ComplateTask(player, taskId)
    return self.Server:ComplateTask(player, taskId)
end

-- 给玩家发送任务奖励物品
-- @param player Player 玩家对象
-- @param task table 任务配置数据
-- @return void
function TaskService:GiveRewardItem(player, task)
    if not player or not task then
        warn("GiveRewardItem: 参数不完整")
        return
    end
    
    local rewardItemId = task.RewardItem
    if not rewardItemId or rewardItemId == 0 then
        warn("任务", task.QuestId, "没有配置奖励物品")
        return
    end
    
    -- 获取物品配置信息
    local itemInfo = ItemConfig:GetByIndex(rewardItemId)
    if not itemInfo then
        warn("奖励物品不存在，物品ID:", rewardItemId)
        return
    end
    
    -- 创建物品数据
    local itemData = {
        ItemId = rewardItemId,
        Attribute = GameConfig.GetItemAttribute()
    }
    
    -- 获取InventoryService
    local inventoryService = Knit.GetService("InventoryService")
    
    -- 尝试添加到工具栏
    local toolData = inventoryService:GetToolData(player)
    local addedToTool = false
    
    for i, slot in ipairs(toolData) do
        if slot.ItemId == 0 then
            toolData[i] = itemData
            inventoryService:UpdateToolData(player, toolData)
            addedToTool = true
            break
        end
    end
    
    -- 如果工具栏满了，尝试添加到背包
    if not addedToTool then
        -- 检查是否有背包
        local hasBag = false
        for _, slot in ipairs(toolData) do
            if slot.ItemId == GameConfig.AdditionalBackpackId then
                hasBag = true
                break
            end
        end
        
        if hasBag then
            local bagData = inventoryService:GetBagData(player)
            local addedToBag = false
            
            for i, slot in ipairs(bagData) do
                if slot.ItemId == 0 then
                    bagData[i] = itemData
                    inventoryService:UpdateBagData(player, bagData)
                    addedToBag = true
                    break
                end
            end
            
            if not addedToBag then
                -- 可以考虑掉落到地面或其他处理方式
                inventoryService:CreateItemToFloor(player.Character, itemInfo, itemData.Attribute)
            end
        else
            -- 可以考虑掉落到地面或其他处理方式
            inventoryService:CreateItemToFloor(player.Character, itemInfo, itemData.Attribute)
        end
    end
    
    -- 通知客户端获得奖励
    Knit.GetService("ClientUIService"):PickUpItem(player, rewardItemId)
end

return TaskService